///|
test "decimal preserves exact values and exponents" {
  assert_eq(DecimalValue::parse("+001.2300").format(), "1.23")
  assert_eq(DecimalValue::parse("12e-2").format(), "0.12")
  assert_eq(DecimalValue::parse("-0.000").format(), "0")
  assert_eq(
    DecimalValue::parse("0.1").add(DecimalValue::parse("0.2")).format(),
    "0.3",
  )
  assert_eq(
    DecimalValue::parse("1.2").compare_value(DecimalValue::parse("1.20")),
    0,
  )
  assert_true(
    DecimalValue::parse("-1.23").compare_value(DecimalValue::parse("-1.2")) < 0,
  )
}

///|
test "decimal rejects overflow and invalid input" {
  for
    value in [
      "", "NaN", "1e", "--1", "1.2.3", "1e129", "9000000000000000001", "1e-19",
    ] {
    let failed = try {
      ignore(DecimalValue::parse(value))
      false
    } catch {
      _ => true
    }
    assert_true(failed, msg=value)
  }
  let overflow = try {
    ignore(
      DecimalValue::parse("9000000000000000000").add(DecimalValue::parse("1")),
    )
    false
  } catch {
    _ => true
  }
  assert_true(overflow)
}
