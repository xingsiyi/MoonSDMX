///|
test "CSV2 decodes shuffled components and optional action" {
  let s = example_structure()
  let text = "STRUCTURE,STRUCTURE_ID,UNIT,TIME_PERIOD,REGION,OBS_VALUE\n" +
    "dataflow,DEMO:FLOW(1.0),kWh,2026-01,N,0\n" +
    "dataflow,DEMO:FLOW(1.0),kWh,2026-02,N,\n"
  let message = decode_csv2(s, text)
  assert_eq(message.kind(), Dataflow)
  assert_eq(message.reference().id(), "FLOW")
  assert_eq(message.dataset().observations()[0].measures()[0], Some("0"))
  assert_eq(message.dataset().observations()[1].measures()[0], None)
}

///|
test "CSV2 rejects mutation actions and mismatched DSD" {
  let s = example_structure()
  for
    text in [
      "STRUCTURE,STRUCTURE_ID,ACTION,REGION,TIME_PERIOD,OBS_VALUE,UNIT\ndatastructure,DEMO:METRICS(1.0),D,N,2026,1,x\n",
      "STRUCTURE,STRUCTURE_ID,REGION,TIME_PERIOD,OBS_VALUE,UNIT\ndatastructure,DEMO:OTHER(1.0),N,2026,1,x\n",
    ] {
    let failed = try {
      ignore(decode_csv2(s, text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
test "CSV2 writer preserves source scope exact text and quality metadata" {
  let s = example_structure()
  let row = Observation::new(s, ["north,west", "2026-Q1"], [Some("1.2300")], [
    Some("kWh"),
    Some("estimated \"x\""),
  ])
  let message = DataMessage::new(
    Dataflow,
    StructureRef::new("DEMO", "FLOW", "1.0"),
    Dataset::new(s, [row]),
  )
  let text = message.encode_csv2()
  let restored = decode_csv2(s, text)
  assert_eq(restored.kind(), Dataflow)
  assert_eq(restored.reference(), message.reference())
  assert_eq(restored.dataset().observations(), [row])
  assert_true(
    text.has_prefix(
      "STRUCTURE,STRUCTURE_ID,ACTION,REGION,TIME_PERIOD,OBS_VALUE,UNIT,STATUS\r\n",
    ),
  )
}
