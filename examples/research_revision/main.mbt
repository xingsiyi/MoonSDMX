///|
fn main raise {
  let s = @sdmx.Structure::new(
    @sdmx.StructureRef::new("DEMO", "RESEARCH", "1.0"),
    [
      @sdmx.Component::new("REGION", @sdmx.Dimension, @sdmx.Text),
      @sdmx.Component::new("TIME_PERIOD", @sdmx.TimeDimension, @sdmx.Period),
      @sdmx.Component::new("OBS_VALUE", @sdmx.Measure, @sdmx.Decimal),
      @sdmx.Component::new(
        "UNIT",
        @sdmx.Attribute(["REGION"]),
        @sdmx.Text,
        required=true,
      ),
      @sdmx.Component::new(
        "STATUS",
        @sdmx.Attribute(["REGION", "TIME_PERIOD"]),
        @sdmx.Text,
      ),
    ],
  )
  let old = @sdmx.Dataset::new(s, [
    @sdmx.Observation::new(s, ["N", "2025"], [Some("1.20")], [
      Some("PCT"),
      Some("P"),
    ]),
    @sdmx.Observation::new(s, ["S", "2025"], [None], [Some("PCT"), None]),
    @sdmx.Observation::new(s, ["W", "2025"], [Some("4")], [Some("PCT"), None]),
  ])
  let operations = [
    @sdmx.LocalOperation::merge_present(old, ["N", "2025"], [Some("1.25")], [
      None,
      Some("F"),
    ]),
    @sdmx.LocalOperation::replace_observation(old, ["S", "2025"], [Some("0")], [
      Some("PCT"),
      Some("F"),
    ]),
    @sdmx.LocalOperation::replace_observation(
      old,
      ["N", "2026"],
      [Some("1.10")],
      [Some("PCT"), Some("P")],
    ),
    @sdmx.LocalOperation::delete_exact(old, ["W", "2025"]),
  ]
  let plan = @sdmx.LocalPlan::new(old, operations)
  let updated = old.apply_local_plan(plan)
  let changes = old.revisions_to(updated)
  assert_eq(changes.added().length(), 1)
  assert_eq(changes.removed().length(), 1)
  assert_eq(changes.changed().length(), 2)
  assert_eq(updated.get(["S", "2025"]).unwrap().measures()[0], Some("0"))
  assert_eq(old.get(["S", "2025"]).unwrap().measures()[0], None)
  let stale = try {
    ignore(updated.apply_local_plan(plan))
    false
  } catch {
    _ => true
  }
  assert_true(stale)
  assert_eq(old.get(["N", "2025"]).unwrap().measures()[0], Some("1.20"))
  println(changes.to_json())
  println(
    "research-revision: 1 added, 1 withdrawn, 2 revised; null-to-zero is explicit; stale plan rejected; old snapshot unchanged",
  )
}
