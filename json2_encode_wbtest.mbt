///|
test "JSON2 writer roundtrips exact values and attachment meaning" {
  let s = example_structure()
  let rows = [
    metric_row(s, "N", "2026-02", None, "kWh"),
    metric_row(s, "N", "2026-01", Some("0.1000"), "kWh"),
  ]
  let message = DataMessage::new(
    Datastructure,
    s.reference(),
    Dataset::new(s, rows),
  )
  let text = message.encode_json2(
    id="fixture",
    sender="DEMO",
    prepared="2026-10-22T00:00:00Z",
  )
  let restored = decode_json2(text, expected=Some(s))
  assert_eq(
    restored.dataset().sorted().observations(),
    message.dataset().sorted().observations(),
  )
  assert_eq(restored.reference(), s.reference())
  let bad = try {
    ignore(
      message.encode_json2(
        id="x",
        sender="DEMO",
        prepared="2026-10-22T00:00:00",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}

///|
test "uncoded dimension text uses value rather than coded id" {
  let s = example_structure()
  let message = DataMessage::new(
    Datastructure,
    s.reference(),
    Dataset::new(s, [metric_row(s, "north, west", "2026", Some("1"), "x")]),
  )
  let text = message.encode_json2(
    id="text",
    sender="DEMO",
    prepared="2026-10-22T00:00:00Z",
  )
  assert_true(text.contains("\"value\":\"north, west\""))
  assert_eq(
    decode_json2(text, expected=Some(s)).dataset().observations()[0].key()[0],
    "north, west",
  )
  let twice = decode_json2(text).encode_json2(
    id="again",
    sender="DEMO",
    prepared="2026-10-22T00:00:00Z",
  )
  assert_eq(
    decode_json2(twice).dataset().observations()[0].key()[0],
    "north, west",
  )
}
