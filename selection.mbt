///|
struct DimensionPredicate {
  position : Int32
  codes : Map[String, Bool]
}

///|
pub struct Selection {
  priv signature : String
  priv predicates : Array[DimensionPredicate]
}

///|
pub fn Selection::new(
  structure : Structure,
  terms : Array[(String, Array[String])],
) -> Selection raise SdmxError {
  let predicates : Array[DimensionPredicate] = []
  let seen : Map[String, Bool] = Map([])
  for (id, values) in terms {
    let position = match structure.positions.get(id) {
      Some(i) => i
      None => raise Invalid(path="selection", reason="not a dimension: \{id}")
    }
    if seen.contains(id) {
      raise Invalid(path="selection", reason="duplicate dimension: \{id}")
    }
    seen[id] = true
    if values.length() > structure.limits.max_codes {
      raise Limit(
        resource="selection values",
        maximum=structure.limits.max_codes,
      )
    }
    let codes : Map[String, Bool] = Map([])
    for value in values {
      validate_value(structure.dimensions[position], value, structure.limits)
      if codes.contains(value) {
        raise Invalid(path=id, reason="duplicate selected code")
      }
      codes[value] = true
    }
    predicates.push({ position, codes, })
  }
  { signature: structure.to_profile_json(), predicates, }
}

///|
pub fn Dataset::select(
  self : Dataset,
  selection : Selection,
) -> Dataset raise SdmxError {
  if self.structure.to_profile_json() != selection.signature {
    raise Invalid(
      path="selection",
      reason="selection was compiled for a different structure",
    )
  }
  let rows : Array[Observation] = []
  for row in self.rows {
    let mut selected = true
    for predicate in selection.predicates {
      if !predicate.codes.contains(row.key[predicate.position]) {
        selected = false
        break
      }
    }
    if selected {
      rows.push(row)
    }
  }
  Dataset::new(self.structure, rows)
}

///|
pub fn Dataset::dimension_values(
  self : Dataset,
  id : String,
) -> Array[String] raise SdmxError {
  let index = match self.structure.dimension_index(id) {
    Some(i) => i
    None => raise Invalid(path=id, reason="not a dimension")
  }
  let seen : Map[String, Bool] = Map([])
  for row in self.rows {
    seen[row.key[index]] = true
  }
  let values : Array[String] = seen.keys().collect()
  values.sort_by((a, b) => a.lexical_compare(b))
  values
}
