///|
test "dimension reordering preserves named attribute attachment and original data" {
  let s = example_structure()
  let target = Structure::new(
    StructureRef::new("TEST", "REORDERED", "1"),
    [s.dimensions[1], s.dimensions[0], ..s.measures, ..s.attributes],
  )
  let data = Dataset::new(s, [metric_row(s, "N", "2026-01", Some("1"), "kWh")])
  let result = data.reorder_dimensions(target)
  assert_eq(result.observations()[0].key(), ["2026-01", "N"])
  assert_eq(data.observations()[0].key(), ["N", "2026-01"])
  assert_eq(result.structure.reference.format(), "TEST:REORDERED(1)")
  assert_eq(
    result.observations()[0].attributes(),
    data.observations()[0].attributes(),
  )
}

///|
test "dimension reordering rejects deleted identity and changed attachment" {
  let s = example_structure()
  let data = Dataset::new(s, [])
  let reduced = Structure::new(s.reference, [s.dimensions[0], ..s.measures])
  assert_true(
    try {
      ignore(data.reorder_dimensions(reduced))
      false
    } catch {
      _ => true
    },
  )
  let attrs = s.attributes()
  attrs[0] = Component::new(
    attrs[0].id,
    Attribute([]),
    attrs[0].representation,
    name=attrs[0].name,
    required=attrs[0].required,
  )
  let changed = Structure::new(
    s.reference,
    [..s.dimensions, ..s.measures, ..attrs],
  )
  assert_true(
    try {
      ignore(data.reorder_dimensions(changed))
      false
    } catch {
      _ => true
    },
  )
}

///|
fn recode_target(s : Structure) -> Structure raise SdmxError {
  let codes = CodeList::new("REGION2", [("NORTH", "North"), ("S", "South")])
  let region = Component::new(
    s.dimensions[0].id,
    Dimension,
    Coded(codes),
    name=s.dimensions[0].name,
    required=s.dimensions[0].required,
  )
  Structure::new(
    StructureRef::new("TEST", "RECODED", "2"),
    [region, s.dimensions[1], ..s.measures, ..s.attributes],
  )
}

///|
fn recode_source() -> Structure raise SdmxError {
  let s = example_structure()
  let region = Component::new("REGION", Dimension, Coded(CodeList::new("REGION1", [("N", "North"), ("S", "South")])))
  Structure::new(s.reference, [region, s.dimensions[1], ..s.measures, ..s.attributes])
}

///|
test "code recoding changes explicit dimension codes and preserves values and units" {
  let s = recode_source()
  let data = Dataset::new(s, [
    metric_row(s, "N", "2026-01", Some("1.20"), "kWh"),
  ])
  let mapping = CodeMapping::new(s.dimensions[0].id, [("N", "NORTH")])
  let result = data.recode(recode_target(s), [mapping])
  assert_eq(result.observations()[0].key(), ["NORTH", "2026-01"])
  assert_eq(result.observations()[0].measures(), [Some("1.20")])
  assert_eq(
    result.observations()[0].attributes(),
    data.observations()[0].attributes(),
  )
  assert_eq(data.observations()[0].key()[0], "N")
}

///|
test "code recoding rejects collisions even when colliding code is not observed" {
  let s = recode_source()
  let data = Dataset::new(s, [metric_row(s, "N", "2026-01", Some("1"), "kWh")])
  let merge = CodeMapping::new(s.dimensions[0].id, [("N", "S")])
  assert_true(
    try {
      ignore(data.recode(s, [merge]))
      false
    } catch {
      _ => true
    },
  )
  let absent = CodeMapping::new(s.dimensions[0].id, [("UNKNOWN", "NORTH")])
  assert_true(
    try {
      ignore(data.recode(recode_target(s), [absent]))
      false
    } catch {
      _ => true
    },
  )
  let unit = CodeMapping::new(s.attributes[0].id, [("kWh", "MWh")])
  assert_true(
    try {
      ignore(data.recode(s, [unit]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(CodeMapping::new("REGION", [("N", "X"), ("N", "Y")]))
      false
    } catch {
      _ => true
    },
  )
}
