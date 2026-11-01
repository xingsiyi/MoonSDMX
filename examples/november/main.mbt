///|
fn main raise {
  let s = @sdmx.Structure::new(@sdmx.StructureRef::new("DEMO", "KPI", "1"), [
    @sdmx.Component::new("AREA", Dimension, Text),
    @sdmx.Component::new("TIME_PERIOD", TimeDimension, Period),
    @sdmx.Component::new("OBS_VALUE", Measure, Decimal),
    @sdmx.Component::new("UNIT", Attribute(["AREA"]), Text),
  ])
  let a = @sdmx.Dataset::new(s, [
    @sdmx.Observation::new(s, ["A", "2026-01"], [Some("0.1")], [Some("kWh")]),
  ])
  let b = @sdmx.Dataset::new(s, [
    @sdmx.Observation::new(s, ["A", "2026-02"], [Some("0.2")], [Some("kWh")]),
  ])
  let merged = a.merge_partition(b)
  let total = merged.grouped_totals("OBS_VALUE", ["AREA"])
  assert_eq(total[0].total, Some("0.3"))
  assert_eq(total[0].reported, 2)
  assert_eq(total[0].attributes, [Some("kWh")])
  println(
    "SDMX partitions merge with attachment checks; exact totals retain unit, frequency and missingness",
  )
}
