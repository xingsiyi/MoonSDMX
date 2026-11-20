///|
/// Read a scoped attribute using named dimensions in any order.
pub fn Dataset::attached_value(
  self : Dataset,
  id : String,
  key : Array[(String, String)],
) -> String? raise SdmxError {
  let values = self.attached_values(id)
  let component = self.structure.component(id).unwrap()
  let positions = attachment_positions(self.structure, component)
  if key.length() != positions.length() {
    raise Invalid(path=id, reason="attribute scope dimension count differs")
  }
  let provided : Map[String, String] = Map([])
  for (name, value) in key {
    if provided.contains(name) {
      raise Invalid(path=id, reason="duplicate scope dimension")
    }
    provided[name] = value
  }
  for p in positions {
    let dimension = self.structure.dimensions[p]
    guard provided.get(dimension.id) is Some(value) else {
      raise Invalid(path=id, reason="attribute binding dimension missing")
    }
    validate_value(dimension, value, self.structure.limits)
  }
  for entry in values {
    if entry.key.all(pair => provided.get(pair.0) == Some(pair.1)) {
      return Some(entry.value)
    }
  }
  None
}
