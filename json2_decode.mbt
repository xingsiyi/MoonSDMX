///|
fn json_index_key(
  text : String,
  wires : Array[WireComponent],
  key : Array[String],
) -> Unit raise SdmxError {
  if wires.is_empty() {
    if !text.is_empty() {
      raise Invalid(
        path="index key",
        reason="expected empty key for zero dimensions",
      )
    }
    return
  }
  let parts = text.split(":").collect()
  if parts.length() != wires.length() {
    raise Invalid(path="index key", reason="wrong dimension count")
  }
  for i, wire in wires {
    let part = parts[i]
    if part.is_empty() || part.length() > 7 {
      raise Invalid(path="index", reason="invalid index length")
    }
    let mut n = 0
    for ch in part {
      if ch < '0' || ch > '9' {
        raise Invalid(path="index", reason="expected unsigned decimal index")
      }
      n = n * 10 + ch.to_int() - 48
    }
    let values = wire.values.unwrap()
    if n >= values.length() {
      raise Invalid(
        path=wire.component.id,
        reason="dictionary index out of range",
      )
    }
    key[wire.position] = values[n]
  }
}

///|
fn json_component_value(
  value : Json,
  wire : WireComponent,
) -> String? raise SdmxError {
  if value is Null {
    return None
  }
  match wire.values {
    Some(values) => {
      if values.is_empty() {
        raise Invalid(
          path=wire.component.id,
          reason="index into empty dictionary",
        )
      }
      Some(values[j_int(value, wire.component.id, values.length() - 1)])
    }
    None => j_scalar(value, wire.component.id)
  }
}

///|
fn json_attribute_values(
  object : Map[String, Json],
  wires : Array[WireComponent],
) -> Array[String?] raise SdmxError {
  let values = match object.get("attributes") {
    None | Some(Null) => []
    Some(v) => j_array(v, "attributes")
  }
  if values.length() > wires.length() {
    raise Invalid(path="attributes", reason="too many values")
  }
  wires.mapi((i, wire) => {
    if i < values.length() {
      json_component_value(values[i], wire)
    } else {
      None
    }
  })
}

///|
fn json_note_indices(
  object : Map[String, Json],
  notes : Array[Annotation],
) -> Array[Int32] raise SdmxError {
  if object.get("dimensionGroupAttributes") is Some(value) &&
    !j_object(value, "dimensionGroupAttributes").is_empty() {
    raise Unsupported(feature="dimensionGroupAttributes")
  }
  let values = json_level(object, "annotations")
  if values.length() > 1024 {
    raise Limit(resource="annotation references", maximum=1024)
  }
  values.map(value => {
    if notes.is_empty() {
      raise Invalid(path="annotation index", reason="no annotation dictionary")
    }
    j_int(value, "annotation index", notes.length() - 1)
  })
}

///|
fn merge_note_indices(
  left : Array[Int32],
  right : Array[Int32],
) -> Array[Int32] raise SdmxError {
  let result : Array[Int32] = []
  let seen : Map[Int32, Bool] = Map([])
  for group in [left, right] {
    for i in group {
      if !seen.contains(i) {
        seen[i] = true
        result.push(i)
      }
    }
  }
  if result.length() > 1024 {
    raise Limit(resource="annotations per observation", maximum=1024)
  }
  result
}

///|
fn json_observations(
  object : Map[String, Json],
  layout : JsonLayout,
  prefix : Array[String],
  inherited : Array[String?],
  rows : Array[Observation],
  inherited_notes : Array[Int32],
  bindings : Array[(Array[String], Array[Int32])],
  references : Array[Int32],
  limits : Limits,
) -> Unit raise SdmxError {
  let observations = match object.get("observations") {
    None | Some(Null) => Map([])
    Some(value) => j_object(value, "observations")
  }
  for encoded_key, value in observations {
    if rows.length() >= limits.max_rows {
      raise Limit(resource="observations", maximum=limits.max_rows)
    }
    let key = prefix.copy()
    json_index_key(encoded_key, layout.observation_dimensions, key)
    let tuple = j_array(value, "observation tuple")
    let measure_count = layout.measures.length()
    if tuple.length() < measure_count {
      raise Invalid(path=encoded_key, reason="missing measure positions")
    }
    let note_start = measure_count + layout.observation_attributes.length()
    let extra : Array[Int32] = []
    for i = note_start; i < tuple.length(); i = i + 1 {
      if layout.notes.is_empty() {
        raise Invalid(path="annotation", reason="no annotation dictionary")
      }
      extra.push(j_int(tuple[i], "annotation index", layout.notes.length() - 1))
      if extra.length() > 1024 {
        raise Limit(resource="annotation references", maximum=1024)
      }
    }
    let row_notes = merge_note_indices(inherited_notes, extra)
    references[0] += row_notes.length()
    if references[0] > 1000000 {
      raise Limit(resource="annotation references", maximum=1000000)
    }
    if !row_notes.is_empty() {
      bindings.push((key.copy(), row_notes))
    }
    let measures = layout.measures.mapi((i, wire) => {
      json_component_value(tuple[i], wire)
    })
    let attributes = inherited.copy()
    for i, wire in layout.observation_attributes {
      let position = measure_count + i
      attributes.push(
        if position < tuple.length() {
          json_component_value(tuple[position], wire)
        } else {
          None
        },
      )
    }
    rows.push(Observation::new(layout.structure, key, measures, attributes))
  }
}

///|
pub fn decode_json2(
  text : String,
  expected~ : Structure? = None,
  limits~ : Limits = Limits::standard(),
) -> DataMessage raise SdmxError {
  let root = j_object(parse_bounded_json(text, limits), "message")
  if root.contains("errors") {
    raise Unsupported(feature="SDMX error message")
  }
  let meta = j_object(j_required(root, "meta"), "meta")
  ignore(j_string(j_required(meta, "id"), "meta.id"))
  ignore(j_object(j_required(meta, "sender"), "meta.sender"))
  if meta.get("schema") is Some(value) {
    let schema = j_string(value, "meta.schema")
    if !schema.contains("/2.0") {
      raise Unsupported(feature="JSON message version other than 2.0")
    }
  }
  let data = j_object(j_required(root, "data"), "data")
  let structures = j_array(j_required(data, "structures"), "structures")
  if structures.length() != 1 {
    raise Unsupported(feature="multiple or absent embedded structures")
  }
  let layout = json_layout(structures[0], expected, limits)
  let datasets = j_array(j_required(data, "dataSets"), "dataSets")
  if datasets.length() != 1 {
    raise Unsupported(feature="multiple or absent data sets")
  }
  let object = j_object(datasets[0], "dataSet")
  if object.get("structure") is Some(value) &&
    j_int(value, "dataSet.structure", 0) != 0 {
    raise Invalid(path="dataSet.structure", reason="index out of range")
  }
  if j_optional_string(object, "action", "Information") != "Information" {
    raise Unsupported(
      feature="JSON mutating action: only Information is accepted",
    )
  }
  let dataset_notes = json_note_indices(object, layout.notes)
  let prefix = Array::make(layout.structure.dimensions.length(), "")
  for wire in layout.dataset_dimensions {
    prefix[wire.position] = wire.values.unwrap()[0]
  }
  let inherited = json_attribute_values(object, layout.dataset_attributes)
  let rows : Array[Observation] = []
  let bindings : Array[(Array[String], Array[Int32])] = []
  let references = [0]
  match object.get("series") {
    Some(value) if !(value is Null) => {
      if object.contains("observations") {
        raise Invalid(
          path="dataSet",
          reason="series and flat observations cannot coexist",
        )
      }
      let series = j_object(value, "series")
      if series.length() > limits.max_rows {
        raise Limit(resource="series", maximum=limits.max_rows)
      }
      for encoded_key, value in series {
        let key = prefix.copy()
        json_index_key(encoded_key, layout.series_dimensions, key)
        let object = j_object(value, "series")
        let notes = merge_note_indices(
          dataset_notes,
          json_note_indices(object, layout.notes),
        )
        let attributes = inherited.copy()
        for v in json_attribute_values(object, layout.series_attributes) {
          attributes.push(v)
        }
        json_observations(
          object, layout, key, attributes, rows, notes, bindings, references, limits,
        )
      }
    }
    _ => {
      if !layout.series_dimensions.is_empty() ||
        !layout.series_attributes.is_empty() {
        raise Invalid(
          path="dataSet",
          reason="series components require series data layout",
        )
      }
      json_observations(
        object, layout, prefix, inherited, rows, dataset_notes, bindings, references,
        limits,
      )
    }
  }
  let dataset = Dataset::new(layout.structure, rows)
  let validated = match expected {
    None => dataset
    Some(s) => dataset.validate_with(s)
  }
  DataMessage::new(layout.kind, layout.reference, validated).with_annotations(
    layout.notes,
    bindings,
  )
}
