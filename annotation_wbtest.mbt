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
