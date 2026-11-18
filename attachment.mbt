///|
priv struct AttachedValue {
  value : String
  mut used : Bool
}

///|
fn attachment_positions(
  structure : Structure,
  attribute : Component,
) -> Array[Int32] {
  match attribute.role {
    Attribute(keys) => keys.map(id => structure.positions[id])
    _ => abort("attribute required")
  }
}

///|
priv struct AttachmentIndex {
  component : Component
  positions : Array[Int32]
  values : Map[String, AttachedValue]
}

///|
fn attachment_index(
  structure : Structure,
  attribute : Component,
) -> AttachmentIndex {
  {
    component: attribute,
    positions: attachment_positions(structure, attribute),
    values: Map([]),
  }
}

///|
fn AttachmentIndex::put(
  self : AttachmentIndex,
  key : Array[String],
  value : String,
  limits : Limits,
) -> Unit raise SdmxError {
  validate_value(self.component, value, limits)
  let token = framed_key(self.positions.map(i => key[i]))
  match self.values.get(token) {
    Some(previous) =>
      if previous.value != value {
        raise Conflict(
          key=token,
          reason="inconsistent attached attribute: \{self.component.id}",
        )
      }
    None => self.values[token] = { value, used: false, }
  }
}

///|
fn AttachmentIndex::get(self : AttachmentIndex, key : Array[String]) -> String? {
  match self.values.get(framed_key(self.positions.map(i => key[i]))) {
    None => None
    Some(entry) => {
      entry.used = true
      Some(entry.value)
    }
  }
}

///|
fn AttachmentIndex::check_used(self : AttachmentIndex) -> Unit raise SdmxError {
  for _, entry in self.values {
    if !entry.used {
      raise Unsupported(
        feature="standalone attribute without a matching observation: " +
          self.component.id,
      )
    }
  }
}
