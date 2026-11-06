///|
fn main raise {
  let s = @sdmx.Structure::new(@sdmx.StructureRef::new("DEMO", "SERIES", "1"), [
    @sdmx.Component::new("AREA", Dimension, Text),
    @sdmx.Component::new("TIME_PERIOD", TimeDimension, Period),
    @sdmx.Component::new("OBS_VALUE", Measure, Decimal),
    @sdmx.Component::new("UNIT", Attribute(["AREA"]), Text),
  ])
  let original = @sdmx.Dataset::new(s, [
    @sdmx.Observation::new(s, ["A", "2026-01"], [Some("0.00")], [Some("kWh")]),
  ])
  let dense = original.densify_periods(["2026-01", "2026-02"], [Some("kWh")])
  assert_eq(dense.inserted_keys, [["A", "2026-02"]])
  let pivot = dense.dataset.pivot_measure("OBS_VALUE", "TIME_PERIOD")
  assert_eq(pivot.rows[0].cells[0].unwrap().value, Some("0.00"))
  assert_eq(pivot.rows[0].cells[1].unwrap().value, None)
  assert_eq(pivot.rows[0].cells[1].unwrap().attributes, [Some("kWh")])
  println(
    "Explicit missing-period completion and semantic pivots retain unit and reported-missing evidence",
  )
}
