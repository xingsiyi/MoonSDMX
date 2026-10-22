///|
fn metric_row(
  s : Structure,
  region : String,
  period : String,
  value : String?,
  unit : String,
) -> Observation raise SdmxError {
  Observation::new(s, [region, period], [value], [Some(unit), None])
}

///|
test "dataset enforces complete keys and attached unit consistency" {
  let s = example_structure()
  let a = metric_row(s, "N", "2026-01", Some("1"), "kWh")
  let b = metric_row(s, "N", "2026-02", None, "kWh")
  let data = Dataset::new(s, [b, a])
  assert_eq(data.sorted().observations()[0].key()[1], "2026-01")
  assert_eq(data.get(["N", "2026-02"]).unwrap().measures()[0], None)
  let duplicate = try {
    ignore(Dataset::new(s, [a, a]))
    false
  } catch {
    _ => true
  }
  assert_true(duplicate)
  let conflict = try {
    ignore(
      Dataset::new(s, [a, metric_row(s, "N", "2026-02", Some("2"), "MWh")]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(conflict)
}
