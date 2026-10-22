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
  for c in structure.dimensions {
    if !positions.contains(c.id) {
      raise Invalid(path="CSV header", reason="missing dimension: \{c.id}")
    }
  }
  let mut kind : ExchangeKind? = None
  let mut reference : StructureRef? = None
  let observations : Array[Observation] = []
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
    let key : Array[String] = []
    for c in structure.dimensions {
      let value = record[positions[c.id]]
      if value.is_empty() || value == "~" {
        raise Unsupported(feature="partial or wildcard observation key")
      }
      key.push(value)
    }
    let measures = csv_values(structure.measures, positions, record)
    let attributes = csv_values(structure.attributes, positions, record)
    observations.push(Observation::new(structure, key, measures, attributes)) catch {
      error => raise Invalid(path="CSV row \{n + 1}", reason=error.message())
    }
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
