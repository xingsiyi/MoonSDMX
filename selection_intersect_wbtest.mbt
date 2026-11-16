///|
test "selection intersection keeps both independent and disjoint dimensions" {
  let structure = example_structure()
  let dataset = Dataset::new(structure, [
    Observation::new(structure, ["US", "2024"], [Some("1")], [Some("USD"), None]),
    Observation::new(structure, ["US", "2025"], [Some("2")], [Some("USD"), None]),
    Observation::new(structure, ["DE", "2024"], [Some("3")], [Some("EUR"), None]),
  ])
  let us = Selection::new(structure, [("REGION", ["US"])])
  let de = Selection::new(structure, [("REGION", ["DE"])])
  let y2024 = Selection::new(structure, [("TIME_PERIOD", ["2024"])])
  let unrestricted = Selection::new(structure, [])
  assert_eq(dataset.select(us.intersect(y2024)).length(), 1)
  assert_eq(dataset.select(us.intersect(unrestricted)).length(), 2)
  let empty = us.intersect(de)
  assert_eq(dataset.select(empty).length(), 0)
  assert_eq(dataset.plan_delete_selection(empty).length(), 0)
}
