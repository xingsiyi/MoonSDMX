///|
test "annotations require valid keys and explicit lossy CSV conversion" {
  let s = example_structure()
  let row = metric_row(s, "N", "2026", Some("1"), "x")
  let source = DataMessage::new(
    Datastructure,
    s.reference(),
    Dataset::new(s, [row]),
  )
  let note = Annotation::from_json("{\"text\":\"provisional\",\"id\":\"N1\"}")
  let message = source.with_annotations([note], [(["N", "2026"], [0])])
  assert_eq(message.annotations_for(["N", "2026"]), [note])
  let rejected = try {
    ignore(message.encode_csv2())
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(message.without_annotations().encode_csv2().contains("2026"))
  let invalid = try {
    ignore(source.with_annotations([note], [(["N", "2026"], [1])]))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "JSON2 inherits series annotations and retains observation annotations" {
  let value = fixture_json_message()
  let root = j_object(value, "root")
  let data = j_object(root["data"], "data")
  let structure = j_object(
    j_array(data["structures"], "structures")[0],
    "structure",
  )
  structure["annotations"] = Json::array([
    { "id": "S", "text": "series" },
    { "id": "O", "text": "observation" },
  ])
  let dataset = j_object(j_array(data["dataSets"], "datasets")[0], "dataset")
  let series = j_object(j_object(dataset["series"], "series")["0"], "series0")
  series["annotations"] = Json::array([Json::number(0.0)])
  let observations = j_object(series["observations"], "observations")
  j_array(observations["0"], "tuple").push(Json::number(1.0))
  let message = decode_json2(canonical_json(value, Limits::standard()))
  assert_eq(message.annotations_for(["2026-01", "N"]).length(), 2)
  assert_eq(message.annotations_for(["2026-02", "N"]).length(), 1)
  let encoded = message.encode_json2(
    id="annotation",
    sender="DEMO",
    prepared="2026-10-22T00:00:00Z",
  )
  let restored = decode_json2(encoded)
  assert_eq(
    restored.annotations_for(["2026-01", "N"]),
    message.annotations_for(["2026-01", "N"]),
  )
}
