///|
test "local merge patch preserves omission and replace clears" {
  let s = example_structure()
  let base = Dataset::new(s, [
    Observation::new(s, ["N", "2026-01"], [Some("1")], [Some("kWh"), Some("P")]),
  ])
  let patch = LocalOperation::merge_present(
    base,
    ["N", "2026-01"],
    [Some("0")],
    [None, None],
  )
  assert_eq(patch.kind(), "merge_present")
  let plan = LocalPlan::new(base, [patch])
  assert_eq(plan.length(), 1)
  assert_eq(plan.base_signature(), base.fingerprint())
  let next = base.apply_local_plan(plan)
  assert_eq(next.observations()[0].measures()[0], Some("0"))
  assert_eq(next.observations()[0].attributes()[1], Some("P"))
  assert_eq(base.observations()[0].measures()[0], Some("1"))
  let replacement = LocalOperation::replace_observation(
    next,
    ["N", "2026-01"],
    [None],
    [Some("kWh"), None],
  )
  let cleared = next.apply_local_plan(LocalPlan::new(next, [replacement]))
  assert_eq(cleared.observations()[0].measures()[0], None)
  assert_eq(cleared.observations()[0].attributes()[1], None)
  assert_true(@json.parse(plan.to_json()) is Object(_))
}

///|
test "local plan inserts and deletes exact full keys atomically" {
  let s = example_structure()
  let base = Dataset::new(s, [metric_row(s, "N", "2026-01", Some("1"), "kWh")])
  let insert = LocalOperation::merge_present(
    base,
    ["S", "2026-02"],
    [Some("4")],
    [Some("MWh"), None],
  )
  let remove = LocalOperation::delete_exact(base, ["N", "2026-01"])
  let next = base.apply_local_plan(LocalPlan::new(base, [insert, remove]))
  assert_eq(next.length(), 1)
  assert_eq(next.get(["S", "2026-02"]).unwrap().measures()[0], Some("4"))
  assert_eq(next.get(["N", "2026-01"]), None)
  assert_eq(base.length(), 1)
  let missing = try {
    ignore(LocalOperation::delete_exact(base, ["S", "2026-02"]))
    false
  } catch {
    _ => true
  }
  assert_true(missing)
  let partial = try {
    ignore(LocalOperation::delete_exact(base, ["N"]))
    false
  } catch {
    _ => true
  }
  assert_true(partial)
}

///|
test "local plan rejects stale base duplicate keys and stale expected rows" {
  let s = example_structure()
  let base = Dataset::new(s, [metric_row(s, "N", "2026-01", Some("1"), "kWh")])
  let patch = LocalOperation::merge_present(
    base,
    ["N", "2026-01"],
    [Some("2")],
    [None, None],
  )
  let plan = LocalPlan::new(base, [patch])
  let duplicate = try {
    ignore(LocalPlan::new(base, [patch, patch]))
    false
  } catch {
    _ => true
  }
  assert_true(duplicate)
  let changed = Dataset::new(s, [
    metric_row(s, "N", "2026-01", Some("3"), "kWh"),
  ])
  let stale = try {
    ignore(changed.apply_local_plan(plan))
    false
  } catch {
    _ => true
  }
  assert_true(stale)
  let expected = try {
    ignore(LocalPlan::new(changed, [patch]))
    false
  } catch {
    _ => true
  }
  assert_true(expected)
  let inserted_elsewhere = Dataset::new(s, [
    metric_row(s, "N", "2026-01", Some("1"), "kWh"),
    metric_row(s, "S", "2026-01", Some("1"), "kWh"),
  ])
  let global_stale = try {
    ignore(inserted_elsewhere.apply_local_plan(plan))
    false
  } catch {
    _ => true
  }
  assert_true(global_stale)
}

///|
test "local attached metadata is checked after simultaneous updates" {
  let s = example_structure()
  let base = Dataset::new(s, [
    metric_row(s, "N", "2026-01", Some("1"), "kWh"),
    metric_row(s, "N", "2026-02", Some("2"), "kWh"),
  ])
  let first = LocalOperation::merge_present(base, ["N", "2026-01"], [None], [
    Some("MWh"),
    None,
  ])
  let only_one = LocalPlan::new(base, [first])
  let before = base.snapshot_signature()
  let conflict = try {
    ignore(base.apply_local_plan(only_one))
    false
  } catch {
    _ => true
  }
  assert_true(conflict)
  assert_eq(base.snapshot_signature(), before)
  let second = LocalOperation::merge_present(base, ["N", "2026-02"], [None], [
    Some("MWh"),
    None,
  ])
  let next = base.apply_local_plan(LocalPlan::new(base, [first, second]))
  for row in next.observations() {
    assert_eq(row.attributes()[0], Some("MWh"))
  }
}

///|
test "local constructors validate values and detach caller arrays" {
  let s = example_structure()
  let base = Dataset::new(s, [])
  let empty = try {
    ignore(
      LocalOperation::merge_present(base, ["N", "2026-01"], [None], [None, None]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(empty)
  let invalid = try {
    ignore(
      LocalOperation::merge_present(base, ["N", "2026-01"], [Some("NaN")], [
        None,
        None,
      ]),
    )
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
  let key = ["N", "2026-01"]
  let measure = [Some("5")]
  let op = LocalOperation::replace_observation(base, key, measure, [
    Some("kWh"),
    None,
  ])
  let plan = LocalPlan::new(base, [op])
  key[0] = "S"
  measure[0] = Some("6")
  let exported_key = plan.operations()[0].key()
  exported_key[0] = "S"
  let next = base.apply_local_plan(plan)
  assert_eq(next.observations()[0].key()[0], "N")
  assert_eq(next.observations()[0].measures()[0], Some("5"))
}

///|
test "local plan accepts equal content reordered base but rejects structure change" {
  let s = example_structure()
  let a = metric_row(s, "N", "2026-01", Some("1"), "kWh")
  let b = metric_row(s, "S", "2026-01", Some("2"), "kWh")
  let base = Dataset::new(s, [a, b])
  let plan = LocalPlan::new(base, [LocalOperation::delete_exact(base, a.key())])
  assert_eq(Dataset::new(s, [b, a]).apply_local_plan(plan).length(), 1)
  let components = s.components()
  components[2] = Component::new("OBS_VALUE", Measure, Integer)
  let changed_structure = Structure::new(s.reference, components)
  let incompatible = Dataset::new(changed_structure, [a, b])
  let rejected = try {
    ignore(incompatible.apply_local_plan(plan))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "local empty plans are identity and exported omitted values are null" {
  let s = example_structure()
  let base = Dataset::new(s, [metric_row(s, "N", "2026-01", None, "kWh")])
  let empty = LocalPlan::new(base, [])
  assert_eq(
    base.apply_local_plan(empty).snapshot_signature(),
    base.snapshot_signature(),
  )
  let operation = LocalOperation::replace_observation(
    base,
    ["N", "2026-01"],
    [Some("0")],
    [Some("kWh"), None],
  )
  let plan = LocalPlan::new(base, [operation])
  let exported = j_object(@json.parse(plan.to_json()), "plan")
  assert_eq(j_string(exported["profile"], "profile"), "moonsdmx.local-plan/1")
  let operation_json = j_object(
    j_array(exported["operations"], "operations")[0],
    "operation",
  )
  assert_true(j_array(operation_json["attributes"], "attributes")[1] is Null)
  let old = j_object(operation_json["expected"], "expected")
  assert_true(j_array(old["measures"], "measures")[0] is Null)
}
