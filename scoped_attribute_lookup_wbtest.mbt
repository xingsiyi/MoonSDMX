///|
test "scope lookup distinguishes a missing group from a malformed key" {
  let data = attached_example().dataset()
  assert_eq(data.attached_value("UNIT", [("AREA", "B")]), Some("MW"))
  assert_eq(data.attached_value("UNIT", [("AREA", "C")]), None)
  let rejected = try {
    ignore(data.attached_value("UNIT", [("TIME_PERIOD", "2026-01")]))
    false
  } catch {
    Invalid(..) => true
    _ => false
  }
  assert_true(rejected)
}
