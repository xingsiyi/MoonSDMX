///|
test "reference parsing and identity" {
  let r = StructureRef::parse("DEMO:INDICATORS(1.0)")
  assert_eq(r.agency(), "DEMO")
  assert_eq(r.format(), "DEMO:INDICATORS(1.0)")
  let invalid = try {
    ignore(StructureRef::parse("DEMO:X(1)extra"))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
  assert_true(framed_key(["a", "bc"]) != framed_key(["ab", "c"]))
}

///|
test "limits reject unsafe resource requests" {
  let invalid = try {
    ignore(Limits::new(max_rows=0))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
  assert_eq(Limits::standard().max_rows(), 100000)
}
