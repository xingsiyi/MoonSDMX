///|
fn total_fixture() -> Structure raise SdmxError {
  Structure::new(StructureRef::new("DEMO", "TOTALS", "1"), [
    Component::new("AREA", Dimension, Text),
    Component::new("TIME_PERIOD", TimeDimension, Period),
    Component::new("OBS_VALUE", Measure, Decimal),
    Component::new("UNIT", Attribute(["AREA"]), Text),
  ])
}

///|
test "partition merge checks duplicate values and attachment consistency atomically" {
  let s = total_fixture()
  let a = Dataset::new(s, [
    Observation::new(s, ["A", "2026-01"], [Some("1.20")], [Some("kWh")]),
  ])
  let b = Dataset::new(s, [
    Observation::new(s, ["A", "2026-02"], [Some("2.30")], [Some("kWh")]),
  ])
  assert_eq(a.merge_partition(b).observations().length(), 2)
  assert_true(
    try {
      ignore(a.merge_partition(a))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    a.merge_partition(a, allow_identical=true).observations().length(),
    1,
  )
  let bad = Dataset::new(s, [
    Observation::new(s, ["A", "2026-03"], [Some("2")], [Some("MWh")]),
  ])
  assert_true(
    try {
      ignore(a.merge_partition(bad))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(a.observations().length(), 1)
}

///|
test "exact totals separate units and frequencies and preserve missingness" {
  let s = total_fixture()
  let rows = [
    Observation::new(s, ["A", "2026-01"], [Some("0.1")], [Some("kWh")]),
    Observation::new(s, ["A", "2026-02"], [Some("0.2")], [Some("kWh")]),
    Observation::new(s, ["A", "2026-03"], [None], [Some("kWh")]),
    Observation::new(s, ["A", "2026-Q1"], [Some("9")], [Some("kWh")]),
    Observation::new(s, ["B", "2026-01"], [Some("2")], [Some("MWh")]),
    Observation::new(s, ["C", "2026-01"], [None], [None]),
  ]
  let totals = Dataset::new(s, rows).grouped_totals("OBS_VALUE", [])
  assert_eq(totals.length(), 4)
  assert_eq(totals[0].total, Some("0.3"))
  assert_eq(totals[0].reported, 2)
  assert_eq(totals[0].missing, 1)
  assert_eq(totals[3].total, None)
  assert_true(
    try {
      ignore(Dataset::new(s, rows).grouped_totals("OBS_VALUE", ["UNIT"]))
      false
    } catch {
      _ => true
    },
  )
}
