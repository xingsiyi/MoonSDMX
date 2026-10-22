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
test "decimal ordering agrees with independent scaled integer oracle" {
  for a = -20; a <= 20; a = a + 1 {
    for b = -20; b <= 20; b = b + 1 {
      for scale = 0; scale <= 3; scale = scale + 1 {
        let x = normalized_decimal(a.to_int64(), scale)
        let y = normalized_decimal(b.to_int64(), 0)
        let mut factor = 1L
        for i = 0; i < scale; i = i + 1 {
          factor *= 10L
        }
        assert_eq(
          x.compare_value(y),
          a.to_int64().compare(b.to_int64() * factor),
        )
      }
    }
  }
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
