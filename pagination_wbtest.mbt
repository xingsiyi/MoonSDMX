///|
test "keyset pages preserve time ordering and consume each observation exactly once" {
  let s = example_structure()
  let data = Dataset::new(s, [
    metric_row(s, "S", "2026-01", Some("3"), "kWh"),
    metric_row(s, "N", "2026-02", Some("2"), "kWh"),
    metric_row(s, "N", "2026-01", Some("1"), "kWh"),
  ])
  let snapshot = PageSnapshot::new(data)
  let first = snapshot.page(page_size=2)
  assert_eq(first.observations().map(r => r.key()), [
    ["N", "2026-01"],
    ["N", "2026-02"],
  ])
  let token = first.next_cursor().unwrap().to_json()
  let cursor = PageCursor::from_json(token)
  let last = snapshot.page(page_size=2, after=Some(cursor))
  assert_eq(last.observations()[0].key(), ["S", "2026-01"])
  assert_true(last.next_cursor() is None)
  assert_eq(snapshot.length(), 3)
  let keys = cursor.after_key()
  keys[0] = "mutated"
  assert_eq(cursor.after_key()[0], "N")
}

///|
test "page cursor rejects changed content query page size and invalid key" {
  let s = example_structure()
  let a = metric_row(s, "N", "2026-01", Some("1"), "kWh")
  let b = metric_row(s, "N", "2026-02", Some("2"), "kWh")
  let data = Dataset::new(s, [a, b])
  let cursor = PageSnapshot::new(data).page(page_size=1).next_cursor().unwrap()
  let changed = PageSnapshot::new(
    Dataset::new(s, [metric_row(s, "N", "2026-01", Some("9"), "kWh"), b]),
  )
  assert_true(
    try {
      ignore(changed.page(page_size=1, after=Some(cursor)))
      false
    } catch {
      _ => true
    },
  )
  let snapshot = PageSnapshot::new(data)
  assert_true(
    try {
      ignore(snapshot.page(page_size=2, after=Some(cursor)))
      false
    } catch {
      _ => true
    },
  )
  let bad = { ..cursor, after_key: ["N", "2026-03"], }
  assert_true(
    try {
      ignore(snapshot.page(page_size=1, after=Some(bad)))
      false
    } catch {
      _ => true
    },
  )
  let filtered = PageSnapshot::new(Dataset::new(s, [b]))
  assert_true(
    try {
      ignore(filtered.page(page_size=1, after=Some(cursor)))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(
    snapshot.page(page_size=1, after=Some(cursor)).observations()[0].key(),
    b.key(),
  )
}

///|
test "pagination permits empty snapshots and equivalent input order but rejects malformed tokens" {
  let s = example_structure()
  let empty = PageSnapshot::new(Dataset::new(s, []))
  assert_eq(empty.page().observations(), [])
  assert_true(empty.page().next_cursor() is None)
  assert_true(
    try {
      ignore(empty.page(page_size=0))
      false
    } catch {
      _ => true
    },
  )
  let a = metric_row(s, "N", "2026-01", Some("1"), "kWh")
  let b = metric_row(s, "N", "2026-02", Some("2"), "kWh")
  let first = PageSnapshot::new(Dataset::new(s, [b, a]))
  let second = PageSnapshot::new(Dataset::new(s, [a, b]))
  let cursor = first.page(page_size=1).next_cursor().unwrap()
  assert_eq(
    second.page(page_size=1, after=Some(cursor)).observations()[0].key(),
    b.key(),
  )
  assert_true(
    try {
      ignore(PageCursor::from_json("{}"))
      false
    } catch {
      _ => true
    },
  )
  let bad = { ..cursor, snapshot: "wrong", }
  assert_true(
    try {
      ignore(bad.to_json())
      false
    } catch {
      _ => true
    },
  )
}
