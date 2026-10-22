///|
test "dimension selection validates codes and never drops metadata" {
  let s = example_structure()
  let data = Dataset::new(s, [
    metric_row(s, "N", "2026-01", Some("1"), "kWh"),
    metric_row(s, "S", "2026-01", None, "MWh"),
  ])
  let selected = data.select(Selection::new(s, [("REGION", ["S"])]))
  assert_eq(selected.length(), 1)
  assert_eq(selected.observations()[0].attributes()[0], Some("MWh"))
  assert_eq(selected.observations()[0].measures()[0], None)
  assert_eq(data.select(Selection::new(s, [("REGION", [])])).length(), 0)
  assert_eq(data.dimension_values("REGION"), ["N", "S"])
}
