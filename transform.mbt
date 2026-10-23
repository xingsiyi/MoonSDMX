///|
fn transform_same_role(a : Role, b : Role) -> Bool {
  match (a, b) {
    (Dimension, Dimension) | (TimeDimension, TimeDimension) | (Measure, Measure) => true
    (Attribute(x), Attribute(y)) => x == y
    _ => false
  }
}

///|
fn transform_same_component(
  a : Component,
  b : Component,
  limits : Limits,
  representation~ : Bool = true,
) -> Unit raise SdmxError {
  if a.id != b.id || a.name != b.name || a.required != b.required ||
    !transform_same_role(a.role, b.role) {
    raise Invalid(path=b.id, reason="transformation changes component metadata or attachment")
  }
  if representation &&
    canonical_json(representation_json(a.representation), limits) !=
    canonical_json(representation_json(b.representation), limits) {
    raise Invalid(path=b.id, reason="transformation changes representation without explicit recoding")
  }
}

///|
fn transform_same_columns(
  a : Array[Component],
  b : Array[Component],
  limits : Limits,
) -> Unit raise SdmxError {
  if a.length() != b.length() {
    raise Invalid(path="transformation", reason="component count differs")
  }
  for i, c in a {
    transform_same_component(c, b[i], limits)
  }
}

///|
/// Change dimension order using an explicitly supplied target structure.
/// No dimension, measure, attachment, representation or metadata is removed.
pub fn Dataset::reorder_dimensions(
  self : Dataset,
  target : Structure,
) -> Dataset raise SdmxError {
  if self.structure.dimensions.length() != target.dimensions.length() {
    raise Invalid(path="dimensions", reason="reordering must retain all identifying dimensions")
  }
  transform_same_columns(self.structure.measures, target.measures, target.limits)
  transform_same_columns(self.structure.attributes, target.attributes, target.limits)
  let positions : Array[Int32] = []
  for component in target.dimensions {
    let old = match self.structure.positions.get(component.id) {
      Some(i) => i
      None => raise Invalid(path=component.id, reason="not an original dimension")
    }
    transform_same_component(self.structure.dimensions[old], component, target.limits)
    positions.push(old)
  }
  let rows : Array[Observation] = []
  for row in self.rows {
    rows.push(Observation::new(target, positions.map(p => row.key[p]), row.measures, row.attributes))
  }
  Dataset::new(target, rows)
}
