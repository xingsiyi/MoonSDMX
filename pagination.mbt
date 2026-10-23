///|
pub struct PageCursor {
  priv snapshot : String
  priv after_key : Array[String]
  priv page_size : Int32
}

///|
pub fn PageCursor::snapshot(self : PageCursor) -> String {
  self.snapshot
}

///|
pub fn PageCursor::after_key(self : PageCursor) -> Array[String] {
  self.after_key.copy()
}

///|
pub fn PageCursor::page_size(self : PageCursor) -> Int32 {
  self.page_size
}

///|
fn validate_cursor(
  cursor : PageCursor,
  limits : Limits,
) -> Unit raise SdmxError {
  if cursor.snapshot.length() != 64 {
    raise Invalid(
      path="cursor.snapshot",
      reason="expected SHA-256 hex snapshot fingerprint",
    )
  }
  for ch in cursor.snapshot {
    if !((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f')) {
      raise Invalid(path="cursor.snapshot", reason="expected lowercase hex")
    }
  }
  if cursor.page_size < 1 || cursor.page_size > limits.max_rows {
    raise Invalid(path="cursor.page_size", reason="outside positive row budget")
  }
  if cursor.after_key.is_empty() ||
    cursor.after_key.length() > limits.max_columns {
    raise Invalid(path="cursor.after_key", reason="outside dimension budget")
  }
  for value in cursor.after_key {
    check_field(value, limits, "cursor.after_key")
    if value.is_empty() {
      raise Invalid(path="cursor.after_key", reason="empty dimension value")
    }
  }
}

///|
/// A bounded transport token, not an authorization credential or signed receipt.
pub fn PageCursor::to_json(
  self : PageCursor,
  limits~ : Limits = Limits::standard(),
) -> String raise SdmxError {
  validate_cursor(self, limits)
  let value : Json = {
    "profile": "moonsdmx.cursor/1",
    "snapshot": self.snapshot,
    "after_key": self.after_key.map(Json::string),
    "page_size": self.page_size,
  }
  canonical_json(value, limits)
}

///|
pub fn PageCursor::from_json(
  text : String,
  limits~ : Limits = Limits::standard(),
) -> PageCursor raise SdmxError {
  let object = j_object(parse_bounded_json(text, limits), "cursor")
  j_known(object, ["profile", "snapshot", "after_key", "page_size"], "cursor")
  if j_string(j_required(object, "profile"), "cursor.profile") !=
    "moonsdmx.cursor/1" {
    raise Unsupported(feature="cursor version")
  }
  let raw_keys = j_array(j_required(object, "after_key"), "cursor.after_key")
  if raw_keys.length() > limits.max_columns {
    raise Limit(resource="cursor dimensions", maximum=limits.max_columns)
  }
  let key = raw_keys.map(value => j_string(value, "cursor.after_key"))
  let size = j_int(
    j_required(object, "page_size"),
    "cursor.page_size",
    limits.max_rows,
  )
  let cursor = {
    snapshot: j_string(j_required(object, "snapshot"), "cursor.snapshot"),
    after_key: key,
    page_size: size,
  }
  validate_cursor(cursor, limits)
  cursor
}

///|
pub struct DatasetPage {
  priv rows : Array[Observation]
  priv next_cursor : PageCursor?
  priv snapshot : String
}

///|
pub fn DatasetPage::observations(self : DatasetPage) -> Array[Observation] {
  self.rows.map(detached_observation)
}

///|
pub fn DatasetPage::next_cursor(self : DatasetPage) -> PageCursor? {
  self.next_cursor.map(cursor => {
    ..cursor,
    after_key: cursor.after_key.copy(),
  })
}

///|
pub fn DatasetPage::snapshot(self : DatasetPage) -> String {
  self.snapshot
}

///|
pub struct PageSnapshot {
  priv structure : Structure
  priv rows : Array[Observation]
  priv fingerprint : String
}

///|
/// Cache one immutable sorted index and one fingerprint. Rows are shared with
/// the immutable dataset internally; pages detach only their selected records.
pub fn PageSnapshot::new(data : Dataset) -> PageSnapshot raise SdmxError {
  let rows = data.rows.copy()
  rows.sort_by((a, b) => compare_keys(a, b, data.structure))
  { structure: data.structure, rows, fingerprint: data.fingerprint(), }
}

///|
pub fn PageSnapshot::fingerprint(self : PageSnapshot) -> String {
  self.fingerprint
}

///|
pub fn PageSnapshot::length(self : PageSnapshot) -> Int32 {
  self.rows.length()
}

///|
fn page_after_position(
  snapshot : PageSnapshot,
  cursor : PageCursor,
) -> Int32 raise SdmxError {
  validate_cursor(cursor, snapshot.structure.limits)
  if cursor.snapshot != snapshot.fingerprint {
    raise Conflict(
      key="cursor",
      reason="cursor belongs to another dataset snapshot or query",
    )
  }
  if cursor.after_key.length() != snapshot.structure.dimensions.length() {
    raise Invalid(path="cursor.after_key", reason="wrong dimension count")
  }
  for i, component in snapshot.structure.dimensions {
    validate_value(component, cursor.after_key[i], snapshot.structure.limits)
  }
  let probe : Observation = {
    key: cursor.after_key,
    measures: [],
    attributes: [],
  }
  let mut lo = 0
  let mut hi = snapshot.rows.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if compare_keys(snapshot.rows[mid], probe, snapshot.structure) < 0 {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo == snapshot.rows.length() || snapshot.rows[lo].key != cursor.after_key {
    raise Invalid(
      path="cursor.after_key",
      reason="continuation key is not in this snapshot",
    )
  }
  lo + 1
}

///|
/// Keyset continuation is bound to structure, values and page size. Changed
/// content rejects old cursors, even when observation count and keys are equal.
/// A selected/period-filtered dataset naturally has a different fingerprint.
pub fn PageSnapshot::page(
  self : PageSnapshot,
  page_size~ : Int32 = 100,
  after~ : PageCursor? = None,
) -> DatasetPage raise SdmxError {
  if page_size < 1 || page_size > self.structure.limits.max_rows {
    raise Invalid(path="page_size", reason="outside positive row budget")
  }
  let start = match after {
    None => 0
    Some(cursor) => {
      if cursor.page_size != page_size {
        raise Invalid(path="page_size", reason="page size differs from cursor")
      }
      page_after_position(self, cursor)
    }
  }
  let remaining = self.rows.length() - start
  let count = if page_size < remaining { page_size } else { remaining }
  let rows : Array[Observation] = []
  for i = start; i < start + count; i = i + 1 {
    rows.push(detached_observation(self.rows[i]))
  }
  let next_cursor = if start + count < self.rows.length() {
    Some({
      snapshot: self.fingerprint,
      after_key: rows[count - 1].key.copy(),
      page_size,
    })
  } else {
    None
  }
  { rows, next_cursor, snapshot: self.fingerprint, }
}
