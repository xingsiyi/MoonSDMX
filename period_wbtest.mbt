///|
test "calendar periods retain their granularity" {
  let q = PeriodValue::parse("2024-Q1")
  assert_true(q.contains_period(PeriodValue::parse("2024-02-29")))
  assert_false(q.overlaps(PeriodValue::parse("2024-04")))
  assert_eq(q.day_bounds().1 - q.day_bounds().0, 91)
  assert_eq(
    PeriodValue::parse("2024").day_bounds().1 -
    PeriodValue::parse("2024").day_bounds().0,
    366,
  )
  assert_eq(PeriodValue::parse("9999-12-31").frequency(), "D")
  assert_true(
    PeriodValue::parse("2026-S2").contains_period(PeriodValue::parse("2026-Q4")),
  )
}

///|
test "invalid and unsupported calendar periods fail explicitly" {
  for
    value in [
      "0000", "2023-02-29", "2026-Q5", "2026-S0", "2026-13", "2026-W01", "2026-01-32",
    ] {
    let failed = try {
      ignore(PeriodValue::parse(value))
      false
    } catch {
      _ => true
    }
    assert_true(failed, msg=value)
  }
}
