///|
// These operations are explicitly local editing instructions, not SDMX actions.
enum LocalChangeKind {
  MergePresent
  ReplaceObservation
  DeleteExact
} derive(@debug.Debug)

///|
pub extend LocalChangeKind with @debug.Debug::{to_repr}

///|
pub struct LocalOperation {
  priv kind : LocalChangeKind
  priv key : Array[String]
  priv expected : Observation?
  priv measures : Array[String?]
  priv attributes : Array[String?]
  priv structure_profile : String
} derive(@debug.Debug)

///|
pub extend LocalOperation with @debug.Debug::{to_repr}

///|
fn detached_expected(row : Observation?) -> Observation? {
  row.map(detached_observation)
}

///|
fn detached_local_operation(operation : LocalOperation) -> LocalOperation {
  {
    ..operation,
    key: operation.key.copy(),
    expected: detached_expected(operation.expected),
    measures: operation.measures.copy(),
    attributes: operation.attributes.copy(),
  }
}

///|
fn operation_payload(
  base : Dataset,
  key : Array[String],
  measures : Array[String?],
  attributes : Array[String?],
) -> Unit raise SdmxError {
  // Validation permits omitted required fields in merge patches; final rows
  // are validated after the patch has been applied.
  ignore(base.get(key))
  if measures.length() != base.structure.measures.length() ||
    attributes.length() != base.structure.attributes.length() {
    raise Invalid(path="local.operation", reason="wrong component count")
  }
  for i, value in measures {
    if value is Some(text) {
      validate_value(base.structure.measures[i], text, base.structure.limits)
    }
  }
  for i, value in attributes {
    if value is Some(text) {
      validate_value(base.structure.attributes[i], text, base.structure.limits)
    }
  }
}

///|
// None in a merge payload means "not provided"; use replace to clear a value.
pub fn LocalOperation::merge_present(
  base : Dataset,
  key : Array[String],
  measures : Array[String?],
  attributes : Array[String?],
) -> LocalOperation raise SdmxError {
  operation_payload(base, key, measures, attributes)
  let mut provided = false
  for value in measures {
    if value is Some(_) {
      provided = true
    }
  }
  for value in attributes {
    if value is Some(_) {
      provided = true
    }
  }
  if !provided {
    raise Invalid(path="local.merge_present", reason="empty patch")
  }
  {
    kind: MergePresent,
    key: key.copy(),
    expected: base.get(key),
    measures: measures.copy(),
    attributes: attributes.copy(),
    structure_profile: base.structure.to_profile_json(),
  }
}

///|
pub fn LocalOperation::replace_observation(
  base : Dataset,
  key : Array[String],
  measures : Array[String?],
  attributes : Array[String?],
) -> LocalOperation raise SdmxError {
  let row = Observation::new(base.structure, key, measures, attributes)
  {
    kind: ReplaceObservation,
    key: row.key,
    expected: base.get(key),
    measures: row.measures,
    attributes: row.attributes,
    structure_profile: base.structure.to_profile_json(),
  }
}

///|
pub fn LocalOperation::delete_exact(
  base : Dataset,
  key : Array[String],
) -> LocalOperation raise SdmxError {
  let expected = base.get(key)
  if expected is None {
    raise Conflict(
      key=framed_key(key),
      reason="delete requires an existing exact key",
    )
  }
  {
    kind: DeleteExact,
    key: key.copy(),
    expected,
    measures: [],
    attributes: [],
    structure_profile: base.structure.to_profile_json(),
  }
}

///|
pub fn LocalOperation::key(self : LocalOperation) -> Array[String] {
  self.key.copy()
}

///|
pub fn LocalOperation::expected(self : LocalOperation) -> Observation? {
  detached_expected(self.expected)
}

///|
pub fn LocalOperation::kind(self : LocalOperation) -> String {
  match self.kind {
    MergePresent => "merge_present"
    ReplaceObservation => "replace_observation"
    DeleteExact => "delete_exact"
  }
}

///|
pub fn LocalOperation::measures(self : LocalOperation) -> Array[String?] {
  self.measures.copy()
}

///|
pub fn LocalOperation::attributes(self : LocalOperation) -> Array[String?] {
  self.attributes.copy()
}

///|
pub struct LocalPlan {
  priv base_signature : String
  priv structure_profile : String
  priv operations : Array[LocalOperation]
  priv limits : Limits
} derive(@debug.Debug)

///|
pub extend LocalPlan with @debug.Debug::{to_repr}

///|
fn check_expected(
  base : Dataset,
  operation : LocalOperation,
) -> Unit raise SdmxError {
  // Structure compatibility is checked once for the enclosing sealed plan.
  if base.get(operation.key) != operation.expected {
    raise Conflict(
      key=framed_key(operation.key),
      reason="operation expected state is stale",
    )
  }
}

///|
pub fn LocalPlan::new(
  base : Dataset,
  operations : Array[LocalOperation],
) -> LocalPlan raise SdmxError {
  if operations.length() > base.structure.limits.max_rows {
    raise Limit(
      resource="local operations",
      maximum=base.structure.limits.max_rows,
    )
  }
  let seen : Map[String, Bool] = Map([])
  let structure_profile = base.structure.to_profile_json()
  for operation in operations {
    let key = framed_key(operation.key)
    if seen.contains(key) {
      raise Conflict(key~, reason="duplicate local operation key")
    }
    seen[key] = true
    if operation.structure_profile != structure_profile {
      raise Invalid(
        path="local.operation.structure",
        reason="structure profile differs",
      )
    }
    if base.get(operation.key) != operation.expected {
      raise Conflict(key~, reason="operation expected state is stale")
    }
  }
  {
    base_signature: base.fingerprint(),
    structure_profile,
    operations: operations.map(detached_local_operation),
    limits: base.structure.limits,
  }
}

///|
pub fn LocalPlan::length(self : LocalPlan) -> Int32 {
  self.operations.length()
}

///|
pub fn LocalPlan::base_signature(self : LocalPlan) -> String {
  self.base_signature
}

///|
pub fn LocalPlan::operations(self : LocalPlan) -> Array[LocalOperation] {
  self.operations.map(detached_local_operation)
}

///|
fn merged_values(
  before : Array[String?],
  patch : Array[String?],
) -> Array[String?] {
  before.mapi((i, value) => {
    match patch[i] {
      None => value
      Some(text) => Some(text)
    }
  })
}

///|
fn operation_result(
  structure : Structure,
  operation : LocalOperation,
) -> Observation? raise SdmxError {
  match operation.kind {
    DeleteExact => None
    ReplaceObservation =>
      Some(
        Observation::new(
          structure,
          operation.key,
          operation.measures,
          operation.attributes,
        ),
      )
    MergePresent => {
      let (measures, attributes) = match operation.expected {
        Some(row) =>
          (
            merged_values(row.measures, operation.measures),
            merged_values(row.attributes, operation.attributes),
          )
        None => (operation.measures.copy(), operation.attributes.copy())
      }
      Some(Observation::new(structure, operation.key, measures, attributes))
    }
  }
}

///|
// Validation occurs before publishing a new Dataset. The source is immutable;
// simultaneous updates may repair shared attached metadata in one transaction.
pub fn Dataset::apply_local_plan(
  self : Dataset,
  plan : LocalPlan,
) -> Dataset raise SdmxError {
  if self.structure.to_profile_json() != plan.structure_profile ||
    self.fingerprint() != plan.base_signature {
    raise Conflict(key="dataset", reason="local plan base snapshot is stale")
  }
  let replacements : Map[String, Observation?] = Map([])
  let mut final_size = self.rows.length()
  for operation in plan.operations {
    check_expected(self, operation)
    if !self.index.contains(framed_key(operation.key)) {
      final_size += 1
    } else if operation.kind is DeleteExact {
      final_size -= 1
    }
  }
  if final_size > self.structure.limits.max_rows {
    raise Limit(resource="observations", maximum=self.structure.limits.max_rows)
  }
  for operation in plan.operations {
    replacements[framed_key(operation.key)] = operation_result(
      self.structure,
      operation,
    )
  }
  let rows : Array[Observation] = []
  for row in self.rows {
    match replacements.get(row.key_token()) {
      None => rows.push(detached_observation(row))
      Some(Some(replacement)) => rows.push(replacement)
      Some(None) => ()
    }
  }
  for operation in plan.operations {
    let token = framed_key(operation.key)
    if !self.index.contains(token) {
      match replacements[token] {
        Some(row) => rows.push(row)
        None => ()
      }
    }
  }
  Dataset::new(self.structure, rows)
}

///|
pub fn LocalPlan::to_json(self : LocalPlan) -> String raise SdmxError {
  canonical_json(
    {
      "profile": "moonsdmx.local-plan/1",
      "semantics": "explicit local edits; not SDMX data actions",
      "baseSnapshot": self.base_signature,
      "structure": self.structure_profile,
      "operations": self.operations.map(operation => {
        let document : Json = {
          "kind": operation.kind(),
          "key": operation.key.map(Json::string),
          "expected": match operation.expected {
            None => Json::null()
            Some(row) => revision_row_json(row)
          },
          "measures": operation.measures.map(optional_text_json),
          "attributes": operation.attributes.map(optional_text_json),
        }
        document
      }),
    },
    self.limits,
  )
}
