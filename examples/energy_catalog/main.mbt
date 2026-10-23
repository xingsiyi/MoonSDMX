///|
fn main raise {
  let old_regions = @sdmx.CodeList::new("REGIONS", [
    ("N", "North"),
    ("S", "South"),
    ("W", "West"),
  ])
  let components = [
    @sdmx.Component::new("REGION", @sdmx.Dimension, @sdmx.Coded(old_regions)),
    @sdmx.Component::new("TIME_PERIOD", @sdmx.TimeDimension, @sdmx.Period),
    @sdmx.Component::new("OBS_VALUE", @sdmx.Measure, @sdmx.Decimal),
    @sdmx.Component::new(
      "UNIT",
      @sdmx.Attribute(["REGION"]),
      @sdmx.Text,
      required=true,
    ),
    @sdmx.Component::new(
      "QUALITY",
      @sdmx.Attribute(["REGION", "TIME_PERIOD"]),
      @sdmx.Text,
    ),
  ]
  let s = @sdmx.Structure::new(
    @sdmx.StructureRef::new("DEMO", "ENERGY", "1.0"),
    components,
  )
  let data = @sdmx.Dataset::new(s, [
    @sdmx.Observation::new(s, ["N", "2026-01"], [Some("120.50")], [
      Some("kWh"),
      Some("E"),
    ]),
    @sdmx.Observation::new(s, ["N", "2026-02"], [None], [Some("kWh"), Some("M")]),
    @sdmx.Observation::new(s, ["S", "2026-Q1"], [Some("0.80")], [
      Some("MWh"),
      Some("F"),
    ]),
  ])
  let new_regions = @sdmx.CodeList::new("REGIONS2", [
    ("NORTH", "North"),
    ("SOUTH", "South"),
    ("WEST", "West"),
  ])
  let target_components = components.copy()
  target_components[0] = @sdmx.Component::new(
    "REGION",
    @sdmx.Dimension,
    @sdmx.Coded(new_regions),
  )
  let target = @sdmx.Structure::new(
    @sdmx.StructureRef::new("DEMO", "ENERGY", "2.0"),
    target_components,
  )
  let recoded = data.recode(target, [
    @sdmx.CodeMapping::new("REGION", [
      ("N", "NORTH"),
      ("S", "SOUTH"),
      ("W", "WEST"),
    ]),
  ])
  assert_eq(
    recoded.get(["NORTH", "2026-01"]).unwrap().measures()[0],
    Some("120.50"),
  )
  assert_eq(
    recoded.get(["SOUTH", "2026-Q1"]).unwrap().attributes()[0],
    Some("MWh"),
  )
  let snapshot = @sdmx.PageSnapshot::new(recoded)
  let first = snapshot.page(page_size=2)
  let cursor = @sdmx.PageCursor::from_json(
    first.next_cursor().unwrap().to_json(),
  )
  let last = snapshot.page(page_size=2, after=Some(cursor))
  assert_eq(first.observations().length() + last.observations().length(), 3)
  assert_true(last.next_cursor() is None)
  let changed = recoded.select(
    @sdmx.Selection::new(target, [("REGION", ["NORTH"])]),
  )
  let rejected = try {
    ignore(
      @sdmx.PageSnapshot::new(changed).page(page_size=2, after=Some(cursor)),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let coverage = data.coverage()
  assert_eq(coverage.dimensions()[0].unseen_codes, ["W"])
  assert_eq(coverage.measures()[0].omitted, 1)
  assert_eq(coverage.attributes()[0].distinct_values, 2)
  println(coverage.to_json())
  println(
    "energy-catalog: whole vocabulary recoded without changing values/units; 2 pages; cross-snapshot cursor refused; kWh/MWh never silently aggregated",
  )
}
