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
