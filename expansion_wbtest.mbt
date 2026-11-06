///|
test "pivot preserves lexical decimals, units, absent versus reported missing" {
  let s = total_fixture()
  let d = Dataset::new(s, [
    Observation::new(s, ["A", "2026-01"], [Some("0.00")], [Some("kWh")]),
    Observation::new(s, ["A", "2026-02"], [None], [Some("kWh")]),
    Observation::new(s, ["B", "2026-01"], [Some("2.30")], [Some("MWh")]),
  ])
  let p = d.pivot_measure("OBS_VALUE", "TIME_PERIOD")
  assert_eq(p.row_dimensions, ["AREA"])
  assert_eq(p.column_values, ["2026-01", "2026-02"])
  assert_eq(p.rows[0].cells[0].unwrap().value, Some("0.00"))
  assert_eq(p.rows[0].cells[1].unwrap().value, None)
  assert_true(p.rows[1].cells[1] is None)
  assert_eq(p.rows[1].cells[0].unwrap().attributes, [Some("MWh")])
  p.rows[0].cells[0].unwrap().attributes.clear()
  assert_eq(d.observations()[0].attributes, [Some("kWh")])
  assert_true(
    try {
      ignore(d.pivot_measure("UNIT", "AREA"))
      false
    } catch {
      _ => true
    },
  )
  let tiny = Structure::new(
    s.reference,
    s.components(),
    limits=Limits::new(max_rows=3),
  )
  assert_true(
    try {
      ignore(d.validate_with(tiny).pivot_measure("OBS_VALUE", "TIME_PERIOD"))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "densify is explicit, retains old observations and enforces attachment" {
  let s = total_fixture()
  let d = Dataset::new(s, [
    Observation::new(s, ["A", "2025-12"], [Some("1.20")], [Some("kWh")]),
  ])
  let out = d.densify_periods(["2026-02", "2026-01"], [Some("kWh")])
  assert_eq(out.dataset.length(), 3)
  assert_eq(out.inserted_keys, [["A", "2026-02"], ["A", "2026-01"]])
  assert_eq(out.dataset.get(["A", "2026-01"]).unwrap().measures, [None])
  out.inserted_keys[0].clear()
  assert_eq(out.dataset.observations()[1].key, ["A", "2026-02"])
  assert_eq(d.length(), 1)
  assert_true(
    try {
      ignore(d.densify_periods(["2026-01"], [Some("MWh")]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(d.densify_periods(["2026-01", "2026-01"], [Some("kWh")]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(d.densify_periods(["2026-Q1"], [Some("kWh")]))
      false
    } catch {
      _ => true
    },
  )
  let tiny = Structure::new(
    s.reference,
    s.components(),
    limits=Limits::new(max_rows=1),
  )
  assert_true(
    try {
      ignore(d.validate_with(tiny).densify_periods(["2026-01"], [Some("kWh")]))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    Dataset::new(s, []).densify_periods(["2026-01"], [Some("kWh")]).dataset.length(),
    0,
  )
  let required = Structure::new(s.reference, [
    Component::new("AREA", Dimension, Text),
    Component::new("TIME_PERIOD", TimeDimension, Period),
    Component::new("OBS_VALUE", Measure, Decimal, required=true),
  ])
  let r = Dataset::new(required, [
    Observation::new(required, ["A", "2026-01"], [Some("1")], []),
  ])
  assert_true(
    try {
      ignore(r.densify_periods(["2026-02"], []))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "dense multi-series pivot retains row and caller period order" {
  let s = total_fixture()
  let rows = Array::makei(40, i => {
    Observation::new(s, ["area" + i.to_string(), "2026-01"], [Some("1.00")], [
      Some("kWh"),
    ])
  })
  let d = Dataset::new(s, rows).densify_periods(["2026-03", "2026-02"], [
    Some("kWh"),
  ])
  assert_eq(d.inserted_keys.length(), 80)
  let pivot = d.dataset.pivot_measure("OBS_VALUE", "TIME_PERIOD")
  assert_eq(pivot.rows.length(), 40)
  assert_eq(pivot.column_values, ["2026-01", "2026-03", "2026-02"])
  assert_eq(pivot.rows[39].key, ["area39"])
  assert_eq(pivot.rows[39].cells[0].unwrap().value, Some("1.00"))
  assert_eq(pivot.rows[39].cells[2].unwrap().value, None)
}
