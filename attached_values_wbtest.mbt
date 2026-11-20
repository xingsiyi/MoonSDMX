///|
fn attached_example() -> DataMessage raise SdmxError {
  let structure = Structure::new(StructureRef::new("DEMO", "UNIT", "1.0"), [
    Component::new("AREA", Dimension, Text),
    Component::new("TIME_PERIOD", TimeDimension, Period),
    Component::new("POWER", Measure, Decimal),
    Component::new("UNIT", Attribute(["AREA"]), Text, measure_ids=["POWER"]),
  ])
  let dataset = Dataset::new(structure, [
    Observation::new(structure, ["A", "2026-01"], [Some("1.0")], [Some("kW")]),
    Observation::new(structure, ["A", "2026-02"], [Some("2.0")], [Some("kW")]),
    Observation::new(structure, ["B", "2026-01"], [Some("3.0")], [Some("MW")]),
  ])
  DataMessage::new(Datastructure, structure.reference(), dataset)
}

///|
test "scope inventory does not duplicate unit values across months" {
  assert_eq(attached_example().dataset().attached_values("UNIT"), [
    { key: [("AREA", "A")], value: "kW", },
    { key: [("AREA", "B")], value: "MW", },
  ])
}
