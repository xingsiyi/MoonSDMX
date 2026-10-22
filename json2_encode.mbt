///|
fn json_identifier(value : String, component : Bool) -> Unit raise SdmxError {
  if value.is_empty() || value.length() > 128 {
    raise Unsupported(feature="JSON2 identifier length")
  }
  for i, ch in value.to_array() {
    let letter = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
    let ordinary = letter || (ch >= '0' && ch <= '9') || ch == '_' || ch == '-'
    if (component && i == 0 && !letter) ||
      (!ordinary && (component || (ch != '@' && ch != '$'))) {
      raise Unsupported(feature="identifier outside JSON2 grammar: \{value}")
    }
  }
}

///|
fn utc_timestamp(text : String) -> Unit raise SdmxError {
  if text.length() != 20 ||
    text[10] != 'T' ||
    text[13] != ':' ||
    text[16] != ':' ||
    text[19] != 'Z' {
    raise Invalid(path="prepared", reason="expected YYYY-MM-DDTHH:MM:SSZ")
  }
  ignore(PeriodValue::parse(text[:10].to_owned()))
  if period_digits(text, 11, 13) > 23 ||
    period_digits(text, 14, 16) > 59 ||
    period_digits(text, 17, 19) > 59 {
    raise Invalid(path="prepared", reason="clock field out of range")
  }
}

///|
fn wire_format(component : Component) -> Json {
  let data_type = match component.representation {
    Text | Coded(_) => "String"
    Decimal => "Decimal"
    Integer => "Integer"
    Period => "ObservationalTimePeriod"
  }
  { "dataType": data_type }
}

///|
fn wire_relationship(component : Component, structure : Structure) -> Json {
  match component.role {
    Attribute(keys) => {
      if keys.is_empty() {
        return { "dataflow": {} }
      }
      if keys == structure.dimensions.map(c => c.id) {
        return { "observation": {} }
      }
      { "dimensions": keys.map(Json::string) }
    }
    _ => abort("attribute required")
  }
}

///|
fn wire_component_json(
  component : Component,
  structure : Structure,
) -> Map[String, Json] {
  let object : Map[String, Json] = Map([])
  object["id"] = Json::string(component.id)
  if !component.name.is_empty() {
    object["name"] = Json::string(component.name)
  }
  match component.representation {
    Coded(codes) => {
      let values : Array[Json] = codes
        .entries()
        .map(pair => {
          "id": pair.0,
          "name": if pair.1.is_empty() {
            pair.0
          } else {
            pair.1
          },
        })
      object["values"] = Json::array(values)
    }
    _ => object["format"] = wire_format(component)
  }
  match component.role {
    Attribute(_) =>
      object["relationship"] = wire_relationship(component, structure)
    Measure => ()
    _ => return object
  }
  object["isMandatory"] = Json::boolean(component.required)
  object
}

///|
fn wire_indexed_value(
  component : Component,
  value : String?,
  indexes : Map[String, Int32],
) -> Json {
  match value {
    None => Json::null()
    Some(text) =>
      match component.representation {
        Coded(_) => Json::number(indexes[text].to_double())
        _ => Json::string(text)
      }
  }
}

///|
fn code_indexes(component : Component) -> Map[String, Int32] {
  let indexes : Map[String, Int32] = Map([])
  if component.representation is Coded(codes) {
    for i, pair in codes.entries() {
      indexes[pair.0] = i
    }
  }
  indexes
}

///|
pub fn DataMessage::encode_json2(
  self : DataMessage,
  id~ : String,
  sender~ : String,
  prepared~ : String,
) -> String raise SdmxError {
  json_identifier(id, false)
  json_identifier(sender, false)
  utc_timestamp(prepared)
  let structure = self.dataset.structure
  for component in structure.components() {
    json_identifier(component.id, true)
    if component.representation is Coded(codes) {
      for pair in codes.entries() {
        json_identifier(pair.0, false)
      }
    }
  }
  let dimension_indexes : Array[Map[String, Int32]] = []
  let dimensions : Array[Json] = []
  for position, component in structure.dimensions {
    let object = wire_component_json(component, structure)
    let entries = match component.representation {
      Coded(codes) => codes.entries()
      _ => self.dataset.dimension_values(component.id).map(code => (code, code))
    }
    let values : Array[Json] = entries.map(pair => {
      match component.representation {
        Coded(_) =>
          {
            "id": pair.0,
            "name": if pair.1.is_empty() {
              pair.0
            } else {
              pair.1
            },
          }
        _ => { "value": pair.0 }
      }
    })
    object["values"] = Json::array(values)
    object["keyPosition"] = Json::number(position.to_double())
    dimensions.push(Json::object(object))
    let indexes : Map[String, Int32] = Map([])
    for i, pair in entries {
      indexes[pair.0] = i
    }
    dimension_indexes.push(indexes)
  }
  let measures : Array[Json] = structure.measures.map(c => {
    Json::object(wire_component_json(c, structure))
  })
  let attributes : Array[Json] = structure.attributes.map(c => {
    Json::object(wire_component_json(c, structure))
  })
  let measure_indexes = structure.measures.map(code_indexes)
  let attribute_indexes = structure.attributes.map(code_indexes)
  let observations : Map[String, Json] = Map([])
  for row in self.dataset.rows {
    let key = row.key
      .mapi((i, value) => dimension_indexes[i][value].to_string())
      .join(":")
    let tuple : Array[Json] = []
    for i, component in structure.measures {
      tuple.push(
        wire_indexed_value(component, row.measures[i], measure_indexes[i]),
      )
    }
    for i, component in structure.attributes {
      tuple.push(
        wire_indexed_value(component, row.attributes[i], attribute_indexes[i]),
      )
    }
    for index in self.row_notes.get(row.key_token()).unwrap_or([]) {
      tuple.push(Json::number(index.to_double()))
    }
    observations[key] = Json::array(tuple)
  }
  let (class_name, relation) = match self.kind {
    Dataflow => ("datastructure.Dataflow", "dataflow")
    Datastructure => ("datastructure.DataStructure", "datastructure")
    Dataprovision =>
      ("provisionagreement.ProvisionAgreement", "provisionagreement")
  }
  let urn = "urn:sdmx:org.sdmx.infomodel.\{class_name}=\{self.reference.format()}"
  let annotation_values : Array[Json] = self.notes.map(note => {
    parse_bounded_json(note.content, structure.limits)
  })
  let embedded : Map[String, Json] = Map([
    ("links", Json::array([{ "urn": urn, "rel": relation }])),
    ("dimensions", { "observation": dimensions }),
    ("measures", { "observation": measures }),
    ("attributes", { "observation": attributes }),
  ])
  if !annotation_values.is_empty() {
    embedded["annotations"] = Json::array(annotation_values)
  }
  let document : Json = {
    "meta": {
      "schema": "https://json.sdmx.org/2.0.0/sdmx-json-data-schema.json",
      "id": id,
      "sender": { "id": sender },
      "prepared": prepared,
    },
    "data": {
      "structures": [Json::object(embedded)],
      "dataSets": [
        {
          "structure": 0,
          "links": [{ "urn": urn, "rel": relation }],
          "action": "Information",
          "observations": Json::object(observations),
        },
      ],
    },
  }
  canonical_json(document, structure.limits)
}
