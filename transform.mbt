///|
fn transform_same_role(a : Role, b : Role) -> Bool {
  match (a, b) {
    (Dimension, Dimension)
    | (TimeDimension, TimeDimension)
    | (Measure, Measure) => true
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
  if a.id != b.id ||
    a.name != b.name ||
    a.required != b.required ||
    !transform_same_role(a.role, b.role) {
    raise Invalid(
      path=b.id,
      reason="transformation changes component metadata or attachment",
    )
  }
  if representation &&
    canonical_json(representation_json(a.representation), limits) !=
    canonical_json(representation_json(b.representation), limits) {
    raise Invalid(
      path=b.id,
      reason="transformation changes representation without explicit recoding",
    )
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
    raise Invalid(
      path="dimensions",
      reason="reordering must retain all identifying dimensions",
    )
  }
  transform_same_columns(
    self.structure.measures,
    target.measures,
    target.limits,
  )
  transform_same_columns(
    self.structure.attributes,
    target.attributes,
    target.limits,
  )
  let positions : Array[Int32] = []
  for component in target.dimensions {
    let old = match self.structure.positions.get(component.id) {
      Some(i) => i
      None =>
        raise Invalid(path=component.id, reason="not an original dimension")
    }
    transform_same_component(
      self.structure.dimensions[old],
      component,
      target.limits,
    )
    positions.push(old)
  }
  let rows : Array[Observation] = []
  for row in self.rows {
    rows.push(
      Observation::new(
        target,
        positions.map(p => row.key[p]),
        row.measures,
        row.attributes,
      ),
    )
  }
  Dataset::new(target, rows)
}

///|
pub struct CodeMapping {
  dimension : String
  replacements : Map[String, String]
}

///|
/// Unspecified codes retain their identity. Only coded identifying dimensions
/// may be recoded: measures and unit/other attributes require semantic conversion.
pub fn CodeMapping::new(
  dimension : String,
  pairs : Array[(String, String)],
  limits~ : Limits = Limits::standard(),
) -> CodeMapping raise SdmxError {
  identifier(dimension, "mapping.dimension")
  if pairs.length() > limits.max_codes {
    raise Limit(resource="mapping entries", maximum=limits.max_codes)
  }
  let replacements : Map[String, String] = Map([])
  for (source, destination) in pairs {
    check_field(source, limits, "mapping.source")
    check_field(destination, limits, "mapping.destination")
    if source.is_empty() || destination.is_empty() {
      raise Invalid(path=dimension, reason="empty mapping code")
    }
    if replacements.contains(source) {
      raise Invalid(path=dimension, reason="duplicate mapping source")
    }
    replacements[source] = destination
  }
  { dimension, replacements, }
}

///|
pub fn CodeMapping::dimension(self : CodeMapping) -> String {
  self.dimension
}

///|
fn transform_recode_domain(
  before : Component,
  after : Component,
  mapping : CodeMapping,
) -> Unit raise SdmxError {
  let (old_codes, new_codes) = match
    (before.role, before.representation, after.representation) {
    (Dimension, Coded(a), Coded(b)) => (a, b)
    _ =>
      raise Invalid(
        path=before.id,
        reason="recoding requires a coded non-time dimension",
      )
  }
  for source in mapping.replacements.keys() {
    if !old_codes.contains(source) {
      raise Invalid(
        path=before.id,
        reason="mapping source is outside original code list",
      )
    }
  }
  let seen : Map[String, String] = Map([])
  for (source, _) in old_codes.entries() {
    let destination = mapping.replacements.get(source).unwrap_or(source)
    if !new_codes.contains(destination) {
      raise Invalid(
        path=before.id,
        reason="mapped code is outside target code list",
      )
    }
    if seen.contains(destination) {
      raise Conflict(
        key=destination,
        reason="code mapping merges distinct source codes",
      )
    }
    seen[destination] = source
  }
}

///|
/// Recode one or more coded dimensions without changing row identity cardinality.
/// The target structure is explicit even for a same-version code-label migration.
/// Mapping validation covers the full source domain, including unobserved codes.
pub fn Dataset::recode(
  self : Dataset,
  target : Structure,
  mappings : Array[CodeMapping],
) -> Dataset raise SdmxError {
  if mappings.length() > self.structure.dimensions.length() {
    raise Invalid(path="mappings", reason="more mappings than dimensions")
  }
  if self.structure.dimensions.length() != target.dimensions.length() {
    raise Invalid(
      path="dimensions",
      reason="recoding must retain all dimensions",
    )
  }
  transform_same_columns(
    self.structure.measures,
    target.measures,
    target.limits,
  )
  transform_same_columns(
    self.structure.attributes,
    target.attributes,
    target.limits,
  )
  let by_position : Map[Int32, CodeMapping] = Map([])
  for mapping in mappings {
    let position = match self.structure.positions.get(mapping.dimension) {
      Some(i) => i
      None =>
        raise Invalid(
          path=mapping.dimension,
          reason="mapping is not for a dimension",
        )
    }
    if by_position.contains(position) {
      raise Invalid(
        path=mapping.dimension,
        reason="duplicate dimension mapping",
      )
    }
    by_position[position] = mapping
  }
  for i, before in self.structure.dimensions {
    let after = target.dimensions[i]
    let explicit = by_position.contains(i)
    transform_same_component(
      before,
      after,
      target.limits,
      representation=!explicit,
    )
    if by_position.get(i) is Some(mapping) {
      transform_recode_domain(before, after, mapping)
    }
  }
  let rows : Array[Observation] = []
  for row in self.rows {
    let key = row.key.copy()
    for position, mapping in by_position {
      key[position] = mapping.replacements
        .get(key[position])
        .unwrap_or(key[position])
    }
    rows.push(Observation::new(target, key, row.measures, row.attributes))
  }
  Dataset::new(target, rows)
}

///|
fn transform_projection_positions(
  original : Array[Component],
  selected : Array[String],
  target : Array[Component],
  limits : Limits,
) -> Array[Int32] raise SdmxError {
  if selected.length() != target.length() {
    raise Invalid(
      path="projection",
      reason="selected fields differ from target structure",
    )
  }
  let available : Map[String, Int32] = Map([])
  for i, component in original {
    available[component.id] = i
  }
  let seen : Map[String, Bool] = Map([])
  let positions : Array[Int32] = []
  for i, id in selected {
    if seen.contains(id) {
      raise Invalid(path=id, reason="duplicate projected component")
    }
    let position = match available.get(id) {
      Some(p) => p
      None =>
        raise Invalid(path=id, reason="component is not in the selected role")
    }
    seen[id] = true
    transform_same_component(original[position], target[i], limits)
    positions.push(position)
  }
  for component in original {
    if component.required && !seen.contains(component.id) {
      raise Invalid(
        path=component.id,
        reason="projection would drop required metadata or measure",
      )
    }
  }
  positions
}

///|
/// Project explicit measure/attribute lists; all dimensions and every required
/// measure/attribute must remain. Optional metadata is dropped only by omission
/// from the explicit list; retained metadata and attachments cannot be rewritten.
pub fn Dataset::project(
  self : Dataset,
  target : Structure,
  measures : Array[String],
  attributes : Array[String],
) -> Dataset raise SdmxError {
  transform_same_columns(
    self.structure.dimensions,
    target.dimensions,
    target.limits,
  )
  let measure_positions = transform_projection_positions(
    self.structure.measures,
    measures,
    target.measures,
    target.limits,
  )
  let attribute_positions = transform_projection_positions(
    self.structure.attributes,
    attributes,
    target.attributes,
    target.limits,
  )
  let rows : Array[Observation] = []
  for row in self.rows {
    rows.push(
      Observation::new(
        target,
        row.key,
        measure_positions.map(i => row.measures[i]),
        attribute_positions.map(i => row.attributes[i]),
      ),
    )
  }
  Dataset::new(target, rows)
}
