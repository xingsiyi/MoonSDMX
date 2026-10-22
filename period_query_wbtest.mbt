///|
test "period queries distinguish overlap and full containment" {
  let s = example_structure()
  let data = Dataset::new(s, [
    metric_row(s, "N", "2026-Q1", Some("3"), "x"),
    metric_row(s, "N", "2026-02", Some("1"), "x"),
  ])
  let window = PeriodWindow::new(
    PeriodValue::parse("2026-02"),
    PeriodValue::parse("2026-02"),
  )
  assert_eq(data.periods_overlapping(window).length(), 2)
  assert_eq(data.periods_contained(window).length(), 1)
  assert_eq(
    data.periods_contained(window).observations()[0].key()[1],
    "2026-02",
  )
}
