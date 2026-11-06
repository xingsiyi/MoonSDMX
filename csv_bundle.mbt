///|
/// Decode contiguous CSV2 source/action groups in original order. Resolve DSDs
/// from a standard StructureCatalog; heterogeneous columns must be empty when
/// not part of the current DSD. Complete keys only, labels=id, scalar values.
pub fn decode_csv2_bundle(
  text : String,
  catalog : StructureCatalog,
  limits~ : Limits = Limits::standard(),
) -> ExchangeBundle raise SdmxError {
  let records = csv_rows(text, limits)
  let header = records[0]
  if header.length() < 2 ||
    header[0] != "STRUCTURE" ||
    header[1] != "STRUCTURE_ID" {
    raise Unsupported(feature="CSV2 STRUCTURE,STRUCTURE_ID header required")
  }
  let positions : Map[String, Int32] = Map([])
  for i, name in header {
    if positions.contains(name) {
      raise Invalid(path="CSV header", reason="duplicate column")
    }
    positions[name] = i
  }
  let action_index = positions.get("ACTION")
  if action_index is Some(i) && i != 2 {
    raise Unsupported(feature="ACTION must be third column")
  }
  let items : Array[ExchangeDataset] = []
  let mut at = 1
  while at < records.length() {
    let first = records[at]
    let kind = ExchangeKind::parse(first[0])
    let reference = StructureRef::parse(first[1])
    let action = DataAction::parse(
      match action_index {
        Some(i) => first[i]
        None => "I"
      },
    )
    let structure = catalog.resolve(kind, reference)
    let components = structure.components()
    let next_header = ["STRUCTURE", "STRUCTURE_ID", "ACTION"]
    for c in components {
      next_header.push(c.id)
    }
    let group = [next_header]
    while at < records.length() {
      let row = records[at]
      let next_action = DataAction::parse(
        match action_index {
          Some(i) => row[i]
          None => "I"
        },
      )
      if row[0] != first[0] || row[1] != first[1] || next_action != action {
        break
      }
      let normalized = [row[0], row[1], "I"]
      for i, name in header {
        if i >= 2 &&
          name != "ACTION" &&
          structure.component(name) is None &&
          !row[i].is_empty() {
          raise Invalid(path=name, reason="nonempty column outside current DSD")
        }
      }
      for c in components {
        normalized.push(
          match positions.get(c.id) {
            Some(i) => row[i]
            None =>
              if c.role is Dimension || c.role is TimeDimension {
                raise Invalid(path=c.id, reason="missing CSV dimension")
              } else {
                ""
              }
          },
        )
      }
      group.push(normalized)
      at += 1
    }
    let message = decode_csv2(structure, csv_document(group, limits))
    items.push({ action, message, valid_from: None, valid_to: None, })
    ignore(bundle_check(items, limits))
  }
  if items.is_empty() {
    raise Invalid(
      path="CSV bundle",
      reason="header-only input has no resolvable source; use decode_csv2 with explicit DSD",
    )
  }
  bundle_check(items, limits)
}
