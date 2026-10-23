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
  assert_eq(result.observations()[0].attributes(), data.observations()[0].attributes())
}

///|
test "dimension reordering rejects deleted identity and changed attachment" {
  let s = example_structure()
  let data = Dataset::new(s, [])
  let reduced = Structure::new(s.reference, [s.dimensions[0], ..s.measures])
  assert_true(try { ignore(data.reorder_dimensions(reduced)); false } catch { _ => true })
  let attrs = s.attributes()
  attrs[0] = Component::new(attrs[0].id, Attribute([]), attrs[0].representation, name=attrs[0].name, required=attrs[0].required)
  let changed = Structure::new(s.reference, [..s.dimensions, ..s.measures, ..attrs])
  assert_true(try { ignore(data.reorder_dimensions(changed)); false } catch { _ => true })
}
