///|
test "CSV lexical state preserves commas quotes and line breaks" {
  let expected = [["A", "B"], ["comma,value", "quoted \"value\"\r\nnext"]]
  let text = csv_document(expected, Limits::standard())
  assert_eq(csv_rows(text, Limits::standard()), expected)
  assert_eq(csv_rows("A,B\n1,\n", Limits::standard())[1], ["1", ""])
}

///|
test "CSV lexical state rejects malformed or excessive input" {
  for text in ["", "A,B\n1", "A\rB", "A\n\"unclosed", "A\n\"x\"z", "A\nab\"c"] {
    let failed = try {
      ignore(csv_rows(text, Limits::standard()))
      false
    } catch {
      _ => true
    }
    assert_true(failed, msg=text)
  }
  let limits = Limits::new(max_field=2)
  let failed = try {
    ignore(csv_rows("A\nabc", limits))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
