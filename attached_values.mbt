///|
#derive(Eq, @debug.Debug)
pub(all) struct ScopedAttributeValue {
  key : Array[(String, String)]
  value : String
}

///|
pub extend ScopedAttributeValue with Eq::{equal, not_equal}

///|
pub extend ScopedAttributeValue with @debug.Debug::{to_repr}

///|
/// Return distinct populated scopes for one attribute in first-observed order.
pub fn Dataset::attached_values(
  self : Dataset,
  id : String,
) -> Array[ScopedAttributeValue] raise SdmxError {
  let mut index = -1
  for i, c in self.structure.attributes {
    if c.id == id {
      index = i
      break
    }
  }
  if index < 0 {
    raise Invalid(path=id, reason="not an attribute")
  }
  let positions = attachment_positions(
    self.structure,
    self.structure.attributes[index],
  )
  let seen : Map[String, Bool] = Map([])
  let values : Array[ScopedAttributeValue] = []
  for row in self.rows {
    if row.attributes[index] is Some(value) {
      let token = framed_key(positions.map(p => row.key[p]))
      if !seen.contains(token) {
        seen[token] = true
        let key = positions.map(p => {
          (self.structure.dimensions[p].id, row.key[p])
        })
        values.push({ key, value, })
      }
    }
  }
  values
}
