///|
fn validate_value(
  component : Component,
  value : String,
  limits : Limits,
) -> Unit raise SdmxError {
  check_field(value, limits, component.id)
  if value.is_empty() {
    raise Invalid(
      path=component.id,
      reason="empty text is omission in this profile",
    )
  }
  try {
    match component.representation {
      Text => ()
      Decimal => ignore(DecimalValue::parse(value))
      Integer => {
        let chars = value.to_array()
        let start = if chars[0] == '-' || chars[0] == '+' { 1 } else { 0 }
        if start == chars.length() {
          raise Invalid(path=component.id, reason="integer has no digits")
        }
        for i = start; i < chars.length(); i = i + 1 {
          if chars[i] < '0' || chars[i] > '9' {
            raise Invalid(path=component.id, reason="invalid integer")
          }
        }
        ignore(DecimalValue::parse(value))
      }
      Period => ignore(PeriodValue::parse(value))
      Coded(codes) =>
        if !codes.contains(value) {
          raise Invalid(path=component.id, reason="not in code list: \{value}")
        }
    }
  } catch {
    error => raise Invalid(path=component.id, reason=error.message())
  }
}

///|
pub struct Observation {
  key : Array[String]
  measures : Array[String?]
  attributes : Array[String?]
} derive(Eq, @debug.Debug)

///|
pub extend Observation with Eq::{equal, not_equal}

///|
pub extend Observation with @debug.Debug::{to_repr}

///|
pub fn Observation::new(
  structure : Structure,
  key : Array[String],
  measures : Array[String?],
  attributes : Array[String?],
) -> Observation raise SdmxError {
  if key.length() != structure.dimensions.length() ||
    measures.length() != structure.measures.length() ||
    attributes.length() != structure.attributes.length() {
    raise Invalid(
      path="observation",
      reason="component count differs from structure",
    )
  }
  for i, component in structure.dimensions {
    validate_value(component, key[i], structure.limits)
  }
  for i, component in structure.measures {
    match measures[i] {
      Some(value) => validate_value(component, value, structure.limits)
      None =>
        if component.required {
          raise Invalid(path=component.id, reason="required measure omitted")
        }
    }
  }
  for i, component in structure.attributes {
    match attributes[i] {
      Some(value) => validate_value(component, value, structure.limits)
      None =>
        if component.required {
          raise Invalid(path=component.id, reason="required attribute omitted")
        }
    }
  }
  { key: key.copy(), measures: measures.copy(), attributes: attributes.copy(), }
}

///|
fn detached_observation(row : Observation) -> Observation {
  {
    key: row.key.copy(),
    measures: row.measures.copy(),
    attributes: row.attributes.copy(),
  }
}

///|
pub fn Observation::key(self : Observation) -> Array[String] {
  self.key.copy()
}

///|
pub fn Observation::measures(self : Observation) -> Array[String?] {
  self.measures.copy()
}

///|
pub fn Observation::attributes(self : Observation) -> Array[String?] {
  self.attributes.copy()
}

///|
pub fn Observation::key_token(self : Observation) -> String {
  framed_key(self.key)
}

///|
pub fn Observation::value(
  self : Observation,
  structure : Structure,
  id : String,
) -> String? raise SdmxError {
  if structure.dimension_index(id) is Some(i) {
    return Some(self.key[i])
  }
  for i, component in structure.measures {
    if component.id == id {
      return self.measures[i]
    }
  }
  for i, component in structure.attributes {
    if component.id == id {
      return self.attributes[i]
    }
  }
  raise Invalid(path="component", reason="unknown component: \{id}")
}
