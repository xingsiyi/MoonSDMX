///|
test "native structure profile roundtrip preserves attachments and code labels" {
  let s = example_structure()
  let text = s.to_profile_json()
  let restored = Structure::from_profile_json(text)
  assert_eq(restored.to_profile_json(), text)
  assert_eq(restored.time_index(), Some(1))
  let invalid = try {
    ignore(
      Structure::from_profile_json(
        "{\"profile\":\"bad\",\"reference\":\"X:Y(1)\",\"components\":[]}",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "JSON parser rejects repeated properties and preserves decimal spelling" {
  let failed = try {
    ignore(parse_bounded_json("{\"a\":1,\"a\":2}", Limits::standard()))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(
    j_scalar(parse_bounded_json("1.2300", Limits::standard()), "number"),
    Some("1.2300"),
  )
}
