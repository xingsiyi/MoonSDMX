///|
test "message selection retains and renumbers annotations used by surviving rows" {
  let message = attached_example().with_annotations(
    [
      Annotation::from_json("{\"id\":\"a\"}"),
      Annotation::from_json("{\"id\":\"b\"}"),
    ],
    [(["A", "2026-01"], [0]), (["B", "2026-01"], [1])],
  )
  let selection = Selection::new(message.dataset().structure(), [
    ("AREA", ["B"]),
  ])
  let output = message.select(selection)
  assert_eq(output.dataset().length(), 1)
  assert_eq(output.annotations().length(), 1)
  assert_eq(
    output.annotations_for(["B", "2026-01"])[0].to_json(),
    "{\"id\":\"b\"}",
  )
}
