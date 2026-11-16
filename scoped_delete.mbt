///|
fn Selection::matches(self : Selection, row : Observation) -> Bool {
  for predicate in self.predicates {
    if !predicate.codes.contains(row.key[predicate.position]) {
      return false
    }
  }
  true
}

///|
/// Build a sealed withdrawal from exact rows matching a dimension selection.
/// The resulting LocalPlan protects the complete source snapshot.
pub fn Dataset::plan_delete_selection(
  self : Dataset,
  selection : Selection,
) -> LocalPlan raise SdmxError {
  let profile = self.structure.to_profile_json()
  if profile != selection.signature || selection.predicates.is_empty() {
    raise Invalid(
      path="delete.selection",
      reason="expected a restriction on the current structure",
    )
  }
  let operations : Array[LocalOperation] = []
  for row in self.rows {
    if selection.matches(row) {
      operations.push({
        kind: DeleteExact,
        key: row.key,
        expected: Some(row),
        measures: [],
        attributes: [],
        structure_profile: profile,
      })
    }
  }
  LocalPlan::new(self, operations)
}

///|
/// Apply a host-supplied dimension selection as a scoped deletion.
/// Require the expected match count and an explicit dimension restriction.
pub fn Dataset::delete_selection(
  self : Dataset,
  selection : Selection,
  expected_count~ : Int32,
) -> Dataset raise SdmxError {
  if self.structure.to_profile_json() != selection.signature {
    raise Invalid(
      path="delete.selection",
      reason="selection belongs to a different structure",
    )
  }
  if selection.predicates.is_empty() || expected_count < 0 {
    raise Invalid(
      path="delete.selection",
      reason="expected a dimension restriction and nonnegative count",
    )
  }
  let kept : Array[Observation] = []
  let mut matched = 0
  for row in self.rows {
    if selection.matches(row) {
      matched += 1
    } else {
      kept.push(row)
    }
  }
  if matched != expected_count {
    raise Conflict(
      key="delete.selection",
      reason="expected \{expected_count} rows, matched \{matched}",
    )
  }
  if matched == 0 {
    return self
  }
  Dataset::new(self.structure, kept)
}
