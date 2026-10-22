///|
test "observations distinguish missing and zero and detach arrays" {
  let s = example_structure()
  let key = ["NORTH", "2026-01"]
  let row = Observation::new(s, key, [Some("0")], [Some("kWh"), None])
  key[0] = "SOUTH"
  assert_eq(row.key()[0], "NORTH")
  assert_eq(row.value(s, "OBS_VALUE"), Some("0"))
  assert_eq(row.value(s, "STATUS"), None)
  let missing = Observation::new(s, ["NORTH", "2026-02"], [None], [
    Some("kWh"),
    None,
  ])
  assert_eq(missing.measures()[0], None)
}

///|
test "observations enforce shape and required metadata" {
  let s = example_structure()
  let failed = try {
    ignore(Observation::new(s, ["N", "2026"], [Some("1")], [None, None]))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let bad_number = try {
    ignore(Observation::new(s, ["N", "2026"], [Some("NaN")], [Some("x"), None]))
    false
  } catch {
    _ => true
  }
  assert_true(bad_number)
}
