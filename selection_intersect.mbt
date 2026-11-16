///|
/// Combine two selections by requiring both sets of constraints.
pub fn Selection::intersect(
  self : Selection,
  other : Selection,
) -> Selection raise SdmxError {
  if self.signature != other.signature {
    raise Invalid(
      path="selection",
      reason="cannot combine different structures",
    )
  }
  let right = Map([])
  for predicate in other.predicates {
    right[predicate.position] = predicate
  }
  let predicates : Array[DimensionPredicate] = []
  for left in self.predicates {
    match right.get(left.position) {
      Some(predicate) => {
        let codes : Map[String, Bool] = Map([])
        for code in left.codes.keys() {
          if predicate.codes.contains(code) {
            codes[code] = true
          }
        }
        predicates.push({ position: left.position, codes, })
        right.remove(left.position) |> ignore
      }
      None => predicates.push(left)
    }
  }
  for predicate in other.predicates {
    if right.contains(predicate.position) {
      predicates.push(predicate)
    }
  }
  { signature: self.signature, predicates, }
}
