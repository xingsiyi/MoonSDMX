///|
test "code lists are unique and deterministic" {
  let codes = CodeList::new("REGION", [("ZZ", "Z"), ("A", "A")])
  assert_eq(codes.entries()[0].0, "A")
  assert_eq(codes.label("ZZ"), Some("Z"))
  assert_false(codes.contains("missing"))
  let bad = try {
    ignore(CodeList::new("X", [("A", "1"), ("A", "2")]))
    false
  } catch {
    _ => true
  }
  assert_true(bad)
}

///|
test "attribute constructor detaches caller attachment" {
  let keys = ["REGION"]
  let c = Component::new("UNIT", Attribute(keys), Text)
  keys[0] = "OTHER"
  match c.role() {
    Attribute(k) => assert_eq(k[0], "REGION")
    _ => fail("attribute expected")
  }
}
