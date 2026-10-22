///|
priv struct WireComponent {
  component : Component
  position : Int32
  values : Array[String]?
  fallback : String?
}

///|
priv struct JsonLayout {
  structure : Structure
  kind : ExchangeKind
  reference : StructureRef
  dataset_dimensions : Array[WireComponent]
  series_dimensions : Array[WireComponent]
  observation_dimensions : Array[WireComponent]
  measures : Array[WireComponent]
  dataset_attributes : Array[WireComponent]
  series_attributes : Array[WireComponent]
  observation_attributes : Array[WireComponent]
  notes : Array[Annotation]
}

///|
fn json_level(
  object : Map[String, Json],
  name : String,
) -> Array[Json] raise SdmxError {
  match object.get(name) {
    None | Some(Null) => []
    Some(value) => j_array(value, name)
  }
}

///|
fn json_format(object : Map[String, Json]) -> Representation raise SdmxError {
  let format = match object.get("format") {
    None | Some(Null) => return Text
    Some(value) => j_object(value, "format")
  }
  j_known(
    format,
    ["dataType", "minOccurs", "maxOccurs", "isMultiLingual"],
    "format",
  )
  for name in ["minOccurs", "maxOccurs"] {
    if format.get(name) is Some(value) && j_int(value, name, 1) > 1 {
      raise Unsupported(feature="multi-valued format")
    }
  }
  if j_optional_bool(format, "isMultiLingual", false) {
    raise Unsupported(feature="multilingual values")
  }
  let kind = j_optional_string(format, "dataType", "String")
  match kind {
    "String" => Text
    "Integer" | "Long" | "Short" | "BigInteger" => Integer
    "Decimal" | "Double" | "Float" => Decimal
    "ObservationalTimePeriod"
    | "ReportingTimePeriod"
    | "StandardTimePeriod"
    | "GregorianTimePeriod"
    | "Date" => Period
    _ => raise Unsupported(feature="format dataType: \{kind}")
  }
}

///|
fn json_relationship(
  value : Json,
  dimensions : Array[String],
) -> Role raise SdmxError {
  let object = j_object(value, "relationship")
  j_known(
    object,
    ["dataflow", "dimensions", "observation", "primaryMeasure", "measures"],
    "relationship",
  )
  if object.get("measures") is Some(value) &&
    !j_array(value, "measures").is_empty() {
    raise Unsupported(feature="measure-specific attribute relationship")
  }
  let mut keys : Array[String]? = None
  if object.contains("dataflow") {
    if !j_object(object["dataflow"], "relationship.dataflow").is_empty() {
      raise Invalid(
        path="relationship.dataflow",
        reason="expected empty object",
      )
    }
    keys = Some([])
  }
  if object.get("dimensions") is Some(value) {
    if keys is Some(_) {
      raise Invalid(path="relationship", reason="multiple attachment kinds")
    }
    let names = j_strings(value, "relationship.dimensions")
    if names.is_empty() {
      raise Invalid(path="relationship.dimensions", reason="empty attachment")
    }
    keys = Some(names)
  }
  if object.contains("observation") || object.contains("primaryMeasure") {
    if keys is Some(_) {
      raise Invalid(path="relationship", reason="multiple attachment kinds")
    }
    if object.contains("observation") && object.contains("primaryMeasure") {
      raise Invalid(
        path="relationship",
        reason="multiple observation attachment forms",
      )
    }
    if object.get("observation") is Some(value) &&
      !j_object(value, "relationship.observation").is_empty() {
      raise Invalid(
        path="relationship.observation",
        reason="expected empty object",
      )
    }
    keys = Some(dimensions.copy())
  }
  match keys {
    Some(keys) => Attribute(keys)
    None => raise Invalid(path="relationship", reason="missing attachment kind")
  }
}

///|
fn json_wire_component(
  value : Json,
  role : Role,
  limits : Limits,
) -> WireComponent raise SdmxError {
  let object = j_object(value, "component")
  let id = j_string(j_required(object, "id"), "component.id")
  let fallback = match object.get("default") {
    None | Some(Null) => None
    Some(value) => {
      if !(role is Attribute(_)) {
        raise Invalid(path=id, reason="only attributes may have defaults")
      }
      j_scalar(value, "default")
    }
  }
  if object.get("annotations") is Some(value) &&
    !j_array(value, "component.annotations").is_empty() {
    raise Unsupported(feature="component annotations")
  }
  let position = match role {
    Dimension | TimeDimension =>
      j_int(
        j_required(object, "keyPosition"),
        "keyPosition",
        limits.max_columns - 1,
      )
    _ => {
      if object.contains("keyPosition") {
        raise Invalid(path=id, reason="keyPosition only belongs to dimensions")
      }
      -1
    }
  }
  let mut representation = json_format(object)
  let mut actual_role = role
  if role is Dimension && (id == "TIME_PERIOD" || representation is Period) {
    actual_role = TimeDimension
    representation = Period
  }
  let values = match object.get("values") {
    None | Some(Null) => None
    Some(value) => {
      let array = j_array(value, "component.values")
      if array.length() > limits.max_codes {
        raise Limit(resource="component values", maximum=limits.max_codes)
      }
      let entries : Array[(String, String)] = array.map(value => {
        let entry = j_object(value, "component value")
        if entry.contains("values") {
          raise Unsupported(feature="multi-valued component dictionary")
        }
        let text = match (entry.get("id"), entry.get("value")) {
          (Some(value), None) => j_string(value, "value.id")
          (None, Some(value)) => j_scalar(value, "value").unwrap_or("")
          _ =>
            raise Invalid(
              path="component value",
              reason="expected exactly one id or scalar value",
            )
        }
        if text.is_empty() {
          raise Invalid(path="component value", reason="empty dictionary value")
        }
        (text, j_optional_string(entry, "name", ""))
      })
      // This is a message vocabulary, not a claim about a registry's full DSD.
      let vocabulary = CodeList::new(id, entries, limits~)
      if !(actual_role is TimeDimension) && representation is Text {
        representation = Coded(vocabulary)
      }
      Some(entries.map(pair => pair.0))
    }
  }
  if (actual_role is Dimension || actual_role is TimeDimension) &&
    values is None {
    raise Invalid(path=id, reason="dimension values are mandatory")
  }
  let component = Component::new(
    id,
    actual_role,
    representation,
    name=j_optional_string(object, "name", ""),
    required=j_optional_bool(object, "isMandatory", false),
  )
  if fallback is Some(text) {
    validate_value(component, text, limits)
  }
  { component, position, values, fallback, }
}

///|
fn json_exchange_reference(
  object : Map[String, Json],
) -> (ExchangeKind, StructureRef) raise SdmxError {
  let links = j_array(j_required(object, "links"), "structure.links")
  if links.is_empty() {
    raise Invalid(
      path="structure.links",
      reason="need identified source structure",
    )
  }
  let first = j_object(links[0], "structure link")
  let urn = j_string(j_required(first, "urn"), "structure link urn")
  let prefixes = [
    ("urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=", Datastructure),
    ("urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=", Dataflow),
    (
      "urn:sdmx:org.sdmx.infomodel.provisionagreement.ProvisionAgreement=",
      Dataprovision,
    ),
  ]
  for (prefix, kind) in prefixes {
    if urn.has_prefix(prefix) {
      return (kind, StructureRef::parse(urn[prefix.length():].to_owned()))
    }
  }
  raise Unsupported(feature="source structure URN")
}

///|
fn json_layout(
  value : Json,
  expected : Structure?,
  limits : Limits,
) -> JsonLayout raise SdmxError {
  let object = j_object(value, "structure")
  let note_values = json_level(object, "annotations")
  if note_values.length() > limits.max_codes {
    raise Limit(resource="annotations", maximum=limits.max_codes)
  }
  let notes = note_values.map(value => {
    ignore(j_object(value, "annotation"))
    { content: canonical_json(value, limits), }
  })
  let (kind, reference) = json_exchange_reference(object)
  let dimension_object = j_object(
    j_required(object, "dimensions"),
    "dimensions",
  )
  j_known(dimension_object, ["dataSet", "series", "observation"], "dimensions")
  let dataset_dimensions = json_level(dimension_object, "dataSet").map(v => {
    json_wire_component(v, Dimension, limits)
  })
  let series_dimensions = json_level(dimension_object, "series").map(v => {
    json_wire_component(v, Dimension, limits)
  })
  let observation_dimensions = json_level(dimension_object, "observation").map(v => {
    json_wire_component(v, Dimension, limits)
  })
  let all_dimensions = dataset_dimensions.copy()
  for wire in series_dimensions {
    all_dimensions.push(wire)
  }
  for wire in observation_dimensions {
    all_dimensions.push(wire)
  }
  if all_dimensions.length() > limits.max_columns {
    raise Limit(resource="dimensions", maximum=limits.max_columns)
  }
  all_dimensions.sort_by((a, b) => a.position.compare(b.position))
  for i, wire in all_dimensions {
    if wire.position != i {
      raise Invalid(
        path="keyPosition",
        reason="positions must be contiguous and unique from zero",
      )
    }
  }
  for wire in dataset_dimensions {
    if wire.values.unwrap().length() != 1 {
      raise Invalid(
        path=wire.component.id,
        reason="dataset dimension must have one value",
      )
    }
  }
  let measures = match object.get("measures") {
    None =>
      [
        {
          component: Component::new("OBS_VALUE", Measure, Decimal),
          position: -1,
          values: None,
          fallback: None,
        },
      ]
    Some(value) => {
      let object = j_object(value, "measures")
      j_known(object, ["observation"], "measures")
      json_level(object, "observation").map(v => {
        json_wire_component(v, Measure, limits)
      })
    }
  }
  let attribute_object = match object.get("attributes") {
    None | Some(Null) => Map([])
    Some(value) => j_object(value, "attributes")
  }
  j_known(
    attribute_object,
    ["dataSet", "dimensionGroup", "series", "observation"],
    "attributes",
  )
  if !json_level(attribute_object, "dimensionGroup").is_empty() {
    raise Unsupported(feature="dimensionGroup attributes")
  }
  let dimension_names = all_dimensions.map(w => w.component.id)
  fn read_attribute(value : Json) -> WireComponent raise SdmxError {
    let object = j_object(value, "attribute")
    json_wire_component(
      value,
      json_relationship(j_required(object, "relationship"), dimension_names),
      limits,
    )
  }
  let dataset_attributes = json_level(attribute_object, "dataSet").map(
    read_attribute,
  )
  let series_attributes = json_level(attribute_object, "series").map(
    read_attribute,
  )
  let observation_attributes = json_level(attribute_object, "observation").map(
    read_attribute,
  )
  let components = all_dimensions.map(w => w.component)
  for w in measures {
    components.push(w.component)
  }
  for group in [dataset_attributes, series_attributes, observation_attributes] {
    for w in group {
      components.push(w.component)
    }
  }
  let structure_ref = match expected {
    Some(s) => s.reference
    None => reference
  }
  let structure = Structure::new(structure_ref, components, limits~)
  {
    structure,
    kind,
    reference,
    dataset_dimensions,
    series_dimensions,
    observation_dimensions,
    measures,
    dataset_attributes,
    series_attributes,
    observation_attributes,
    notes,
  }
}
