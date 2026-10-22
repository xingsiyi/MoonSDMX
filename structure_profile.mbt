///|
fn representation_json(value : Representation) -> Json {
  match value {
    Text => { "type": "text" }
    Decimal => { "type": "decimal" }
    Integer => { "type": "integer" }
    Period => { "type": "period" }
    Coded(codes) => {
      let values : Array[Json] = codes
        .entries()
        .map(pair => { "id": pair.0, "label": pair.1 })
      { "type": "coded", "id": codes.id, "codes": values }
    }
  }
}

///|
pub fn Structure::to_profile_json(self : Structure) -> String raise SdmxError {
  let components : Array[Json] = self
    .components()
    .map(c => {
      let (role, attachment) = match c.role {
        Dimension => ("dimension", [])
        TimeDimension => ("time", [])
        Measure => ("measure", [])
        Attribute(keys) => ("attribute", keys)
      }
      {
        "id": c.id,
        "name": c.name,
        "role": role,
        "attachment": attachment.map(Json::string),
        "required": Json::boolean(c.required),
        "representation": representation_json(c.representation),
      }
    })
  canonical_json(
    {
      "profile": "moonsdmx.structure/1",
      "reference": self.reference.format(),
      "components": components,
    },
    self.limits,
  )
}

///|
fn read_representation(
  value : Json,
  limits : Limits,
) -> Representation raise SdmxError {
  let object = j_object(value, "representation")
  j_known(object, ["type", "id", "codes"], "representation")
  let tag = j_string(j_required(object, "type"), "representation.type")
  match tag {
    "text" => Text
    "decimal" => Decimal
    "integer" => Integer
    "period" => Period
    "coded" => {
      let values = j_array(j_required(object, "codes"), "codes")
      if values.length() > limits.max_codes {
        raise Limit(resource="codes", maximum=limits.max_codes)
      }
      let entries : Array[(String, String)] = values.map(v => {
        let entry = j_object(v, "code")
        j_known(entry, ["id", "label"], "code")
        (
          j_string(j_required(entry, "id"), "code.id"),
          j_optional_string(entry, "label", ""),
        )
      })
      Coded(
        CodeList::new(
          j_string(j_required(object, "id"), "codelist.id"),
          entries,
          limits~,
        ),
      )
    }
    _ => raise Unsupported(feature="representation: \{tag}")
  }
}

///|
pub fn Structure::from_profile_json(
  text : String,
  limits~ : Limits = Limits::standard(),
) -> Structure raise SdmxError {
  let object = j_object(parse_bounded_json(text, limits), "structure profile")
  j_known(object, ["profile", "reference", "components"], "structure profile")
  if j_string(j_required(object, "profile"), "profile") !=
    "moonsdmx.structure/1" {
    raise Unsupported(feature="structure profile version")
  }
  let reference = StructureRef::parse(
    j_string(j_required(object, "reference"), "reference"),
  )
  let values = j_array(j_required(object, "components"), "components")
  if values.length() > limits.max_columns {
    raise Limit(resource="components", maximum=limits.max_columns)
  }
  let components = values.map(value => {
    let object = j_object(value, "component")
    j_known(
      object,
      ["id", "name", "role", "attachment", "required", "representation"],
      "component",
    )
    let tag = j_string(j_required(object, "role"), "role")
    let attachment = match object.get("attachment") {
      Some(value) => j_strings(value, "attachment")
      None => []
    }
    if tag != "attribute" && !attachment.is_empty() {
      raise Invalid(
        path="attachment",
        reason="only attributes have attachments",
      )
    }
    let role = match tag {
      "dimension" => Dimension
      "time" => TimeDimension
      "measure" => Measure
      "attribute" => Attribute(attachment)
      _ => raise Unsupported(feature="component role: \{tag}")
    }
    Component::new(
      j_string(j_required(object, "id"), "id"),
      role,
      read_representation(j_required(object, "representation"), limits),
      name=j_optional_string(object, "name", ""),
      required=j_optional_bool(object, "required", false),
    )
  })
  Structure::new(reference, components, limits~)
}
