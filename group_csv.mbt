///|
/// Write selected non-observation attributes as partial-key Information rows.
pub fn DataMessage::encode_grouped_csv2(
  self : DataMessage,
) -> String raise SdmxError {
  if !self.notes.is_empty() {
    raise Unsupported(feature="CSV cannot preserve annotation bindings")
  }
  let structure = self.dataset.structure
  if self.dataset.rows.is_empty() {
    return self.encode_csv2()
  }
  let prefix = [self.kind.format(), self.reference.format(), "I"]
  let header = ["STRUCTURE", "STRUCTURE_ID", "ACTION"]
  header.append(structure.components().map(c => c.id))
  let rows : Array[Array[String]] = [header]
  let attr_start = 3 +
    structure.dimensions.length() +
    structure.measures.length()
  let partial : Array[Bool] = []
  for i, component in structure.attributes {
    let positions = attachment_positions(structure, component)
    let scoped = positions.length() < structure.dimensions.length()
    partial.push(scoped)
    if scoped {
      for item in self.dataset.attached_values(component.id) {
        if rows.length() - 1 >= structure.limits.max_rows {
          raise Limit(resource="CSV rows", maximum=structure.limits.max_rows)
        }
        let row = Array::make(header.length(), "")
        for j, value in prefix {
          row[j] = value
        }
        for (d, value) in item.key {
          row[3 + structure.positions[d]] = value
        }
        row[attr_start + i] = item.value
        rows.push(row)
      }
    }
  }
  for observation in self.dataset.rows {
    if rows.length() - 1 >= structure.limits.max_rows {
      raise Limit(resource="CSV rows", maximum=structure.limits.max_rows)
    }
    let row = prefix.copy()
    row.append(observation.key)
    row.append(observation.measures.map(value => value.unwrap_or("")))
    for i, value in observation.attributes {
      row.push(if partial[i] { "" } else { value.unwrap_or("") })
    }
    rows.push(row)
  }
  csv_document(rows, structure.limits)
}
