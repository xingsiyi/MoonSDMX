///|
test "aggregate code list and dataset text is bounded" {
  let limits = Limits::new(max_text=5)
  let failed = try {
    ignore(CodeList::new("X", [("A", "12345")], limits~))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let s = Structure::new(
    StructureRef::new("X", "Y", "1"),
    [Component::new("D", Dimension, Text), Component::new("V", Measure, Text)],
    limits~,
  )
  let rows = [
    Observation::new(s, ["a"], [Some("abc")], []),
    Observation::new(s, ["b"], [Some("def")], []),
  ]
  let excessive = try {
    ignore(Dataset::new(s, rows))
    false
  } catch {
    _ => true
  }
  assert_true(excessive)
}

///|
test "unsupported value annotations are rejected without silent loss" {
  let value = fixture_json_message()
  let data = j_object(j_object(value, "message")["data"], "data")
  let structure = j_object(
    j_array(data["structures"], "structures")[0],
    "structure",
  )
  let dimensions = j_object(structure["dimensions"], "dimensions")
  let c = j_object(j_array(dimensions["series"], "series")[0], "component")
  j_object(j_array(c["values"], "values")[0], "value")["annotations"] = Json::array([
      Json::number(0.0),
    ],
  )
  let failed = try {
    ignore(decode_json2(canonical_json(value, Limits::standard())))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
