///|
pub struct Dataset {
  priv structure : Structure
  priv rows : Array[Observation]
  priv index : Map[String, Int32]
} derive(@debug.Debug)

///|
pub extend Dataset with @debug.Debug::{to_repr}

///|
pub fn Dataset::new(
  structure : Structure,
  rows : Array[Observation],
) -> Dataset raise SdmxError {
  if rows.length() > structure.limits.max_rows {
    raise Limit(resource="observations", maximum=structure.limits.max_rows)
  }
  let detached : Array[Observation] = []
  let mut text_units = 0
  let index : Map[String, Int32] = Map([])
  let attached : Array[Map[String, String?]] = structure.attributes.map(_ => {
    Map([])
  })
  for n, input in rows {
    let row = Observation::new(
      structure,
      input.key,
      input.measures,
      input.attributes,
    )
    for value in row.key {
      if text_units > structure.limits.max_text - value.length() {
        raise Limit(resource="dataset text", maximum=structure.limits.max_text)
      }
      text_units += value.length()
    }
    for group in [row.measures, row.attributes] {
      for value in group {
        if value is Some(text) {
          if text_units > structure.limits.max_text - text.length() {
            raise Limit(
              resource="dataset text",
              maximum=structure.limits.max_text,
            )
          }
          text_units += text.length()
        }
      }
    }
    let token = row.key_token()
    if index.contains(token) {
      raise Conflict(
        key=token,
        reason="duplicate observation key at row \{n + 1}",
      )
    }
    for i, attribute in structure.attributes {
      let scope = attachment_key(structure, attribute, row.key)
      match attached[i].get(scope) {
        Some(value) =>
          if value != row.attributes[i] {
            raise Conflict(
              key=token,
              reason="inconsistent attached attribute: \{attribute.id}",
            )
          }
        None => attached[i][scope] = row.attributes[i]
      }
    }
    index[token] = detached.length()
    detached.push(row)
  }
  { structure, rows: detached, index, }
}

///|
pub fn Dataset::structure(self : Dataset) -> Structure {
  self.structure
}

///|
pub fn Dataset::length(self : Dataset) -> Int32 {
  self.rows.length()
}

///|
pub fn Dataset::observations(self : Dataset) -> Array[Observation] {
  self.rows.map(detached_observation)
}

///|
pub fn Dataset::get(
  self : Dataset,
  key : Array[String],
) -> Observation? raise SdmxError {
  if key.length() != self.structure.dimensions.length() {
    raise Invalid(path="key", reason="wrong dimension count")
  }
  for i, component in self.structure.dimensions {
    validate_value(component, key[i], self.structure.limits)
  }
  match self.index.get(framed_key(key)) {
    Some(i) => Some(detached_observation(self.rows[i]))
    None => None
  }
}

///|
fn compare_keys(
  a : Observation,
  b : Observation,
  structure : Structure,
) -> Int32 {
  for i, component in structure.dimensions {
    let order = if component.role is TimeDimension {
      // Observation construction has already checked these period strings.
      let x = PeriodValue::parse(a.key[i]) catch {
        _ => abort("validated period")
      }
      let y = PeriodValue::parse(b.key[i]) catch {
        _ => abort("validated period")
      }
      let c = x.compare_period(y)
      if c == 0 {
        a.key[i].lexical_compare(b.key[i])
      } else {
        c
      }
    } else {
      a.key[i].lexical_compare(b.key[i])
    }
    if order != 0 {
      return order
    }
  }
  0
}

///|
pub fn Dataset::sorted(self : Dataset) -> Dataset raise SdmxError {
  let rows = self.observations()
  rows.sort_by((a, b) => compare_keys(a, b, self.structure))
  Dataset::new(self.structure, rows)
}

///|
pub fn Dataset::validate_with(
  self : Dataset,
  structure : Structure,
) -> Dataset raise SdmxError {
  let left = self.structure.components()
  let right = structure.components()
  if left.length() != right.length() {
    raise Invalid(path="structure", reason="different component count")
  }
  for i, c in left {
    if c.id != right[i].id {
      raise Invalid(path="structure", reason="component order differs")
    }
    let compatible = match (c.role, right[i].role) {
      (Dimension, Dimension)
      | (TimeDimension, TimeDimension)
      | (Measure, Measure) => true
      (Attribute(a), Attribute(b)) => a == b
      _ => false
    }
    if !compatible {
      raise Invalid(path=c.id, reason="component roles/attachments differ")
    }
  }
  if self.structure.reference != structure.reference {
    raise Invalid(path="structure", reason="reference differs")
  }
  Dataset::new(structure, self.rows)
}
