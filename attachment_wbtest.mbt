///|
fn attachment_fixture() -> Structure raise SdmxError {
  Structure::new(
    StructureRef::new("DEMO", "ENERGY", "1.0"),
    [
      Component::new("AREA", Dimension, Text),
      Component::new("TIME_PERIOD", TimeDimension, Period),
      Component::new("POWER", Measure, Decimal),
      Component::new("ENERGY", Measure, Decimal),
      Component::new(
        "POWER_UNIT",
        Attribute(["AREA"]),
        Text,
        group=Some("AreaGroup"),
        measure_ids=["POWER"],
        required=true,
      ),
      Component::new("QUALITY", Attribute(["AREA", "TIME_PERIOD"]), Text, measure_ids=[
        "ENERGY",
      ]),
    ],
    groups=[{ id: "AreaGroup", dimensions: ["AREA"], }],
  )
}

///|
test "measure views and totals use only applicable attributes" {
  let structure = attachment_fixture()
  let csv =
    #|STRUCTURE,STRUCTURE_ID,ACTION,AREA,TIME_PERIOD,POWER,ENERGY,POWER_UNIT,QUALITY
    #|datastructure,DEMO:ENERGY(1.0),I,A,2026-01,12.50,300.00,,P
    #|datastructure,DEMO:ENERGY(1.0),I,A,2026-02,13.00,310.00,,E
    #|datastructure,DEMO:ENERGY(1.0),I,A,,,,kW,
  let source = decode_csv2(structure, csv).dataset()
  let row = source.observations()[0]
  assert_eq(row.attributes_for_measure(structure, "POWER"), [
    ("POWER_UNIT", Some("kW")),
  ])
  assert_eq(row.attributes_for_measure(structure, "ENERGY"), [
    ("QUALITY", Some("P")),
  ])
  let power = source.grouped_totals("POWER", ["AREA"])
  assert_eq(power.length(), 1)
  assert_eq(power[0].total, Some("25.5"))
  assert_eq(power[0].attributes, [Some("kW"), None])
  assert_eq(source.grouped_totals("ENERGY", ["AREA"]).length(), 2)

  let profile = structure.to_profile_json()
  let restored = Structure::from_profile_json(profile)
  assert_eq(restored.to_profile_json(), profile)
  restored.groups()[0].dimensions.clear()
  restored.attributes()[0].measure_ids().clear()
  assert_eq(restored.groups()[0].dimensions, ["AREA"])
  assert_eq(restored.attributes()[0].measure_ids(), ["POWER"])

  let encoded = decode_csv2(restored, csv).encode_json2(
    id="test",
    sender="DEMO",
    prepared="2026-11-18T00:00:00Z",
  )
  let decoded = decode_json2(encoded, expected=Some(restored)).dataset()
  assert_eq(decoded.observations(), source.observations())

  let message = decode_csv2(restored, csv)
  let bundle = bundle_check(
    [{ action: Information, message, valid_from: None, valid_to: None, }],
    Limits::standard(),
  )
  let applied = bundle.apply(Map([]))
  let result = applied["datastructure:DEMO:ENERGY(1.0)"]
  assert_eq(result.observations(), source.observations())
  assert_eq(result.structure().groups()[0].id, "AreaGroup")
}

///|
test "invalid group or measure references fail before reading data" {
  let structure = attachment_fixture()
  let parts = structure.components()
  for (id, scope) in [("Unknown", ["POWER"]), ("AreaGroup", ["NOT_A_MEASURE"])] {
    parts[4] = Component::new(
      "POWER_UNIT",
      Attribute(["AREA"]),
      Text,
      group=Some(id),
      measure_ids=scope,
    )
    let rejected = try {
      ignore(
        Structure::new(structure.reference(), parts, groups=structure.groups()),
      )
      false
    } catch {
      Invalid(..) => true
      _ => false
    }
    assert_true(rejected)
  }
}
