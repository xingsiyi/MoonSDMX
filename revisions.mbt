///|
// Revisions compare lexical component values: omission and numeric zero differ.
pub struct FieldRevision {
  priv component : String
  priv before : String?
  priv after : String?
} derive(Eq, @debug.Debug)

///|
pub extend FieldRevision with Eq::{equal, not_equal}

///|
pub extend FieldRevision with @debug.Debug::{to_repr}

///|
pub fn FieldRevision::component(self : FieldRevision) -> String {
  self.component
}

///|
pub fn FieldRevision::before(self : FieldRevision) -> String? {
  self.before
}

///|
pub fn FieldRevision::after(self : FieldRevision) -> String? {
  self.after
}

///|
pub struct ObservationRevision {
  priv key : Array[String]
  priv measures : Array[FieldRevision]
  priv attributes : Array[FieldRevision]
} derive(@debug.Debug)

///|
pub extend ObservationRevision with @debug.Debug::{to_repr}

///|
fn detached_revision(change : ObservationRevision) -> ObservationRevision {
  {
    key: change.key.copy(),
    measures: change.measures.copy(),
    attributes: change.attributes.copy(),
  }
}

///|
pub fn ObservationRevision::key(self : ObservationRevision) -> Array[String] {
  self.key.copy()
}

///|
pub fn ObservationRevision::measures(
  self : ObservationRevision,
) -> Array[FieldRevision] {
  self.measures.copy()
}

///|
pub fn ObservationRevision::attributes(
  self : ObservationRevision,
) -> Array[FieldRevision] {
  self.attributes.copy()
}

///|
pub struct DatasetRevision {
  priv structure_profile : String
  priv added : Array[Observation]
  priv removed : Array[Observation]
  priv changed : Array[ObservationRevision]
  priv limits : Limits
} derive(@debug.Debug)

///|
pub extend DatasetRevision with @debug.Debug::{to_repr}

///|
pub fn DatasetRevision::added(self : DatasetRevision) -> Array[Observation] {
  self.added.map(detached_observation)
}

///|
pub fn DatasetRevision::removed(self : DatasetRevision) -> Array[Observation] {
  self.removed.map(detached_observation)
}

///|
pub fn DatasetRevision::changed(
  self : DatasetRevision,
) -> Array[ObservationRevision] {
  self.changed.map(detached_revision)
}

///|
pub fn DatasetRevision::is_empty(self : DatasetRevision) -> Bool {
  self.added.is_empty() && self.removed.is_empty() && self.changed.is_empty()
}

///|
fn revision_structure_compatible(
  left : Structure,
  right : Structure,
) -> Unit raise SdmxError {
  if left.to_profile_json() != right.to_profile_json() {
    raise Invalid(
      path="revision.structure",
      reason="exact structure profile differs",
    )
  }
}

///|
fn optional_text_json(value : String?) -> Json {
  match value {
    None => Json::null()
    Some(text) => Json::string(text)
  }
}

///|
fn revision_row_json(row : Observation) -> Json {
  {
    "key": row.key.map(Json::string),
    "measures": row.measures.map(optional_text_json),
    "attributes": row.attributes.map(optional_text_json),
  }
}

///|
// The exact canonical snapshot is a collision-free local equality token,
// not a digest, signature, authentication credential or compact wire hash.
pub fn Dataset::snapshot_signature(self : Dataset) -> String raise SdmxError {
  let rows = self.observations()
  rows.sort_by((a, b) => a.key_token().lexical_compare(b.key_token()))
  canonical_json(
    {
      "profile": "moonsdmx.local-snapshot/1",
      "structure": self.structure.to_profile_json(),
      "rows": rows.map(revision_row_json),
    },
    self.structure.limits,
  )
}

///|
fn field_revisions(
  components : Array[Component],
  before : Array[String?],
  after : Array[String?],
) -> Array[FieldRevision] {
  let changes : Array[FieldRevision] = []
  for i, component in components {
    if before[i] != after[i] {
      changes.push({
        component: component.id,
        before: before[i],
        after: after[i],
      })
    }
  }
  changes
}

///|
pub fn Dataset::revisions_to(
  self : Dataset,
  next : Dataset,
) -> DatasetRevision raise SdmxError {
  revision_structure_compatible(self.structure, next.structure)
  let added : Array[Observation] = []
  let removed : Array[Observation] = []
  let changed : Array[ObservationRevision] = []
  let keys : Array[String] = self.index.keys().collect()
  keys.sort_by((a, b) => a.lexical_compare(b))
  for key in keys {
    let before = self.rows[self.index[key]]
    match next.index.get(key) {
      None => removed.push(detached_observation(before))
      Some(position) => {
        let after = next.rows[position]
        let measures = field_revisions(
          self.structure.measures,
          before.measures,
          after.measures,
        )
        let attributes = field_revisions(
          self.structure.attributes,
          before.attributes,
          after.attributes,
        )
        if !measures.is_empty() || !attributes.is_empty() {
          changed.push({ key: before.key.copy(), measures, attributes, })
        }
      }
    }
  }
  let next_keys : Array[String] = next.index.keys().collect()
  next_keys.sort_by((a, b) => a.lexical_compare(b))
  for key in next_keys {
    if !self.index.contains(key) {
      added.push(detached_observation(next.rows[next.index[key]]))
    }
  }
  {
    structure_profile: self.structure.to_profile_json(),
    added,
    removed,
    changed,
    limits: self.structure.limits,
  }
}

///|
fn field_revision_json(field : FieldRevision) -> Json {
  {
    "component": field.component,
    "before": optional_text_json(field.before),
    "after": optional_text_json(field.after),
  }
}

///|
pub fn DatasetRevision::to_json(
  self : DatasetRevision,
) -> String raise SdmxError {
  canonical_json(
    {
      "profile": "moonsdmx.revision/1",
      "structure": self.structure_profile,
      "added": self.added.map(revision_row_json),
      "removed": self.removed.map(revision_row_json),
      "changed": self.changed.map(change => {
        "key": change.key.map(Json::string),
        "measures": change.measures.map(field_revision_json),
        "attributes": change.attributes.map(field_revision_json),
      }),
    },
    self.limits,
  )
}
