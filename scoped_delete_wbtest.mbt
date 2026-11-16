///|
test "scoped deletion protects count, schema and original data" {
  let structure = example_structure()
  let dataset = Dataset::new(structure, [
    Observation::new(structure, ["US", "2024"], [Some("1")], [Some("USD"), None]),
    Observation::new(structure, ["US", "2025"], [Some("2")], [Some("USD"), None]),
    Observation::new(structure, ["DE", "2024"], [Some("3")], [Some("EUR"), None]),
  ])
  let selection = Selection::new(dataset.structure(), [("REGION", ["US"])])
  assert_eq(dataset.select(selection).length(), 2)
  assert_true(
    try {
      ignore(dataset.delete_selection(selection, expected_count=1))
      false
    } catch {
      Conflict(..) => true
      _ => false
    },
  )
  let updated = dataset.delete_selection(selection, expected_count=2)
  assert_eq(updated.length(), 1)
  assert_eq(dataset.length(), 3)
  assert_true(updated.get(["US", "2024"]) is None)
  let unrestricted = Selection::new(dataset.structure(), [])
  assert_true(
    try {
      ignore(dataset.delete_selection(unrestricted, expected_count=3))
      false
    } catch {
      _ => true
    },
  )
}
