///|
test "snapshot fingerprints are stable under row order and sensitive to omission" {
  let s = example_structure()
  let a = metric_row(s, "N", "2026-01", Some("0"), "kWh")
  let b = metric_row(s, "S", "2026-01", None, "MWh")
  let x = Dataset::new(s, [a, b])
  let y = Dataset::new(s, [b, a])
  assert_eq(x.fingerprint(), y.fingerprint())
  assert_eq(x.fingerprint().length(), 64)
  let z = Dataset::new(s, [metric_row(s, "N", "2026-01", None, "kWh"), b])
  assert_true(z.fingerprint() != x.fingerprint())
  assert_true(s.fingerprint() != x.fingerprint())
}
