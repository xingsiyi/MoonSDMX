///|
test "revisions separate added removed changed and missing numeric zero" {
  let s = example_structure()
  let old = Dataset::new(s, [
    metric_row(s, "N", "2026-01", None, "kWh"),
    metric_row(s, "S", "2026-01", Some("1"), "kWh"),
  ])
  let next = Dataset::new(s, [
    metric_row(s, "N", "2026-01", Some("0"), "kWh"),
    metric_row(s, "N", "2026-02", Some("4"), "kWh"),
  ])
  let revision = old.revisions_to(next)
  assert_eq(revision.added().length(), 1)
  assert_eq(revision.removed().length(), 1)
  assert_eq(revision.changed().length(), 1)
  let field = revision.changed()[0].measures()[0]
  assert_eq(field.component(), "OBS_VALUE")
  assert_eq(field.before(), None)
  assert_eq(field.after(), Some("0"))
  let json = @json.parse(revision.to_json())
  assert_true(json is Object(_))
  assert_true(!revision.is_empty())
  assert_true(old.revisions_to(old).is_empty())
}

///|
test "revision attribute detail and detached outputs" {
  let s = example_structure()
  let a = Observation::new(s, ["N", "2026-01"], [Some("1")], [Some("kWh"), None])
  let b = Observation::new(s, ["N", "2026-01"], [Some("1.0")], [Some("kWh"), Some("P")])
  let old = Dataset::new(s, [a])
  let next = Dataset::new(s, [b])
  let revision = old.revisions_to(next)
  let change = revision.changed()[0]
  assert_eq(change.measures()[0].before(), Some("1"))
  assert_eq(change.measures()[0].after(), Some("1.0"))
  assert_eq(change.attributes()[0].component(), "STATUS")
  assert_eq(change.attributes()[0].before(), None)
  assert_eq(change.attributes()[0].after(), Some("P"))
  let exported = change.key()
  exported[0] = "S"
  assert_eq(revision.changed()[0].key()[0], "N")
  let removed = next.revisions_to(Dataset::new(s, [])).removed()
  let values = removed[0].measures()
  values[0] = Some("900")
  assert_eq(next.observations()[0].measures()[0], Some("1.0"))
}

///|
test "revision rejects representation requirement label and attachment changes" {
  let s = example_structure()
  let original = Dataset::new(s, [])
  let variants : Array[Structure] = []
  let names = s.components()
  names[0] = Component::new(names[0].id, names[0].role, names[0].representation, name="changed")
  variants.push(Structure::new(s.reference, names))
  let required = s.components()
  required[2] = Component::new(required[2].id, required[2].role, required[2].representation, required=true)
  variants.push(Structure::new(s.reference, required))
  let represented = s.components()
  represented[2] = Component::new(represented[2].id, represented[2].role, Integer)
  variants.push(Structure::new(s.reference, represented))
  let attached = s.components()
  attached[3] = Component::new(attached[3].id, Attribute([]), attached[3].representation)
  variants.push(Structure::new(s.reference, attached))
  for changed in variants {
    let rejected = try {
      ignore(original.revisions_to(Dataset::new(changed, [])))
      false
    } catch { _ => true }
    assert_true(rejected)
  }
}

///|
test "revision order is independent from input row order" {
  let s = example_structure()
  let a = metric_row(s, "N", "2026-01", Some("1"), "kWh")
  let b = metric_row(s, "S", "2026-01", Some("2"), "kWh")
  let x = Dataset::new(s, [a, b])
  let y = Dataset::new(s, [b, a])
  assert_eq(x.snapshot_signature(), y.snapshot_signature())
  assert_eq(Dataset::new(s, []).revisions_to(x).to_json(), Dataset::new(s, []).revisions_to(y).to_json())
}

