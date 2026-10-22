///|
fn example_structure() -> Structure raise SdmxError {
  Structure::new(StructureRef::new("DEMO", "METRICS", "1.0"), [
    Component::new("REGION", Dimension, Text),
    Component::new("TIME_PERIOD", TimeDimension, Period),
    Component::new("OBS_VALUE", Measure, Decimal),
    Component::new("UNIT", Attribute(["REGION"]), Text, required=true),
    Component::new("STATUS", Attribute(["REGION", "TIME_PERIOD"]), Text),
  ])
}

///|
test "structure indexes dimensions and validates attachments" {
  let s = example_structure()
  assert_eq(s.dimension_index("REGION"), Some(0))
  assert_eq(s.time_index(), Some(1))
  assert_eq(s.measures()[0].id(), "OBS_VALUE")
  assert_eq(attachment_key(s, s.attributes[0], ["A", "2026"]), "1:A")
  let invalid = try {
    ignore(
      Structure::new(s.reference(), [
        Component::new("X", Dimension, Text),
        Component::new("V", Measure, Decimal),
        Component::new("UNIT", Attribute(["UNKNOWN"]), Text),
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}
