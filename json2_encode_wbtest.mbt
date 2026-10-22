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
