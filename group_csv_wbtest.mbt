///|
test "grouped CSV emits independent unit rows and reads back lexical values" {
  let message = attached_example()
  let text = message.encode_grouped_csv2()
  assert_true(text.contains(",I,A,,,kW"))
  assert_true(text.contains(",I,A,2026-01,1.0,"))
  let restored = decode_csv2(message.dataset().structure(), text)
  assert_eq(restored.dataset().observations(), message.dataset().observations())
}
