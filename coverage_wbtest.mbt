///|
test "coverage counts omission and missing codes without unsafe unit aggregation" {
  let base = example_structure()
  let codes = CodeList::new("REGIONS", [
    ("N", "North"),
    ("S", "South"),
    ("W", "West"),
  ])
  let s = Structure::new(
    base.reference(),
    [
      Component::new("REGION", Dimension, Coded(codes)),
      base.dimensions[1],
      ..base.measures,
      ..base.attributes,
    ],
  )
  let data = Dataset::new(s, [
    metric_row(s, "N", "2026", Some("0"), "kWh"),
    metric_row(s, "S", "2026-01", None, "MWh"),
  ])
  let report = data.coverage()
  assert_eq(report.observation_count(), 2)
  assert_eq(report.dimensions()[0].unseen_codes, ["W"])
  assert_eq(report.measures()[0].reported, 1)
  assert_eq(report.measures()[0].omitted, 1)
  assert_eq(report.attributes()[0].distinct_values, 2)
  assert_eq(report.period_frequencies(), [("A", 1), ("M", 1)])
  assert_true(report.to_json().contains("unseenCodes"))
  let detached = report.dimensions()
  detached[0].unseen_codes[0] = "tampered"
  assert_eq(report.dimensions()[0].unseen_codes, ["W"])
}
