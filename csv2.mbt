///|
pub fn decode_csv2(
  structure : Structure,
  text : String,
) -> DataMessage raise SdmxError {
  let records = csv_rows(text, structure.limits)
  let header = records[0]
  if header.length() < 2 ||
    header[0] != "STRUCTURE" ||
    header[1] != "STRUCTURE_ID" {
    raise Unsupported(
      feature="expected CSV2 labels=id, scalar STRUCTURE,STRUCTURE_ID header",
    )
  }
  let positions : Map[String, Int32] = Map([])
  for i, name in header {
    if positions.contains(name) {
      raise Invalid(path="CSV header", reason="duplicate column: \{name}")
    }
    positions[name] = i
    if i >= 2 && name != "ACTION" && structure.component(name) is None {
      raise Unsupported(
        feature="unknown, labelled or multi-valued column: \{name}",
      )
    }
  }
  if positions.get("ACTION") is Some(i) && i != 2 {
    raise Unsupported(feature="ACTION must follow STRUCTURE_ID")
  }
  let keys = structure.dimensions.map(c => positions.get(c.id))
  let scoped = structure.attributes.map(c => attachment_index(structure, c))
  let payloads : Array[(Array[String], Array[String?], Array[String?])] = []
  let mut kind : ExchangeKind? = None
  let mut reference : StructureRef? = None
  for n = 1; n < records.length(); n = n + 1 {
    let record = records[n]
    let row_kind = ExchangeKind::parse(record[0])
    let row_ref = StructureRef::parse(record[1])
    match (kind, reference) {
      (None, None) => {
        kind = Some(row_kind)
        reference = Some(row_ref)
      }
      (Some(k), Some(r)) if k == row_kind && r == row_ref => ()
      _ => raise Unsupported(feature="multiple structures in one CSV2 message")
    }
    if positions.get("ACTION") is Some(i) && record[i] != "I" {
      raise Unsupported(
        feature="CSV action \{record[i]}: only Information is accepted",
      )
    }
    let key = keys.map(i => i.map(p => record[p]).unwrap_or(""))
    for i, value in key {
      if value == "~" {
        raise Unsupported(feature="wildcard observation key")
      }
      if !value.is_empty() {
        validate_value(structure.dimensions[i], value, structure.limits)
      }
    }
    let complete = key.all(v => !v.is_empty())
    let measures = csv_values(structure.measures, positions, record)
    let attributes = csv_values(structure.attributes, positions, record)
    if !complete && measures.any(v => v is Some(_)) {
      raise Invalid(
        path="CSV row \{n + 1}",
        reason="measure requires a complete key",
      )
    }
    let mut found = false
    let covered = Array::make(key.length(), false)
    for i, value in attributes {
      if value is Some(text) {
        let index = scoped[i]
        if index.positions.length() != key.length() || !complete {
          if !index.positions.all(p => !key[p].is_empty()) {
            raise Invalid(
              path=index.component.id,
              reason="attribute missing a binding dimension",
            )
          }
          index.put(key, text, structure.limits)
          for p in index.positions {
            covered[p] = true
          }
          found = true
        }
      }
    }
    if complete {
      payloads.push((key, measures, attributes))
    } else if !found ||
      key.mapi((i, v) => !v.is_empty() && !covered[i]).any(v => v) {
      raise Invalid(
        path="CSV row \{n + 1}",
        reason="partial key must identify the supplied attributes",
      )
    }
  }
  let observations = payloads.map(payload => {
    let (key, measures, attributes) = payload
    for i, index in scoped {
      if index.positions.length() != key.length() {
        attributes[i] = index.get(key)
      }
    }
    Observation::new(structure, key, measures, attributes)
  })
  for index in scoped {
    index.check_used()
  }
  // A header-only exchange has no source reference; use the caller's DSD.
  DataMessage::new(
    kind.unwrap_or(Datastructure),
    reference.unwrap_or(structure.reference),
    Dataset::new(structure, observations),
  )
}

///|
fn csv_values(
  components : Array[Component],
  positions : Map[String, Int32],
  row : Array[String],
) -> Array[String?] {
  components.map(c => {
    match positions.get(c.id) {
      None => None
      Some(i) => if row[i].is_empty() { None } else { Some(row[i]) }
    }
  })
}

///|
pub fn DataMessage::encode_csv2(self : DataMessage) -> String raise SdmxError {
  if !self.notes.is_empty() {
    raise Unsupported(
      feature="CSV profile cannot preserve annotations; call without_annotations explicitly",
    )
  }
  if self.dataset.rows.is_empty() &&
    (
      !(self.kind is Datastructure) ||
      self.reference != self.dataset.structure.reference
    ) {
    raise Unsupported(
      feature="CSV cannot preserve source reference of a header-only dataflow",
    )
  }
  let components = self.dataset.structure.components()
  let header = ["STRUCTURE", "STRUCTURE_ID", "ACTION"]
  for component in components {
    header.push(component.id)
  }
  let records = [header]
  for row in self.dataset.rows {
    let record = [self.kind.format(), self.reference.format(), "I"]
    for value in row.key {
      record.push(value)
    }
    for value in row.measures {
      record.push(value.unwrap_or(""))
    }
    for value in row.attributes {
      record.push(value.unwrap_or(""))
    }
    records.push(record)
  }
  csv_document(records, self.dataset.structure.limits)
}
