///|
pub struct Structure {
  reference : StructureRef
  dimensions : Array[Component]
  measures : Array[Component]
  attributes : Array[Component]
  positions : Map[String, Int32]
  limits : Limits
} derive(@debug.Debug)

///|
pub extend Structure with @debug.Debug::{to_repr}

///|
pub fn Structure::new(
  reference : StructureRef,
  components : Array[Component],
  limits~ : Limits = Limits::standard(),
) -> Structure raise SdmxError {
  if components.length() > limits.max_columns {
    raise Limit(resource="components", maximum=limits.max_columns)
  }
  let ids = components.map(c => c.id)
  unique_names(ids, "components")
  let reserved = [
    "STRUCTURE", "STRUCTURE_ID", "STRUCTURE_NAME", "ACTION", "SERIES_KEY", "OBS_KEY",
  ]
  let dimensions : Array[Component] = []
  let measures : Array[Component] = []
  let attributes : Array[Component] = []
  let positions : Map[String, Int32] = Map([])
  let mut times = 0
  for component in components {
    if reserved.contains(component.id) {
      raise Invalid(path="component.id", reason="reserved exchange header")
    }
    let c = { ..component, role: detached_role(component.role), }
    match c.role {
      Dimension => {
        positions[c.id] = dimensions.length()
        dimensions.push(c)
      }
      TimeDimension => {
        times += 1
        if !(c.representation is Period) {
          raise Invalid(
            path=c.id,
            reason="time dimension must use Period representation",
          )
        }
        positions[c.id] = dimensions.length()
        dimensions.push(c)
      }
      Measure => measures.push(c)
      Attribute(_) => attributes.push(c)
    }
  }
  if dimensions.is_empty() || measures.is_empty() || times > 1 {
    raise Invalid(
      path="structure",
      reason="need dimensions, measures and at most one time dimension",
    )
  }
  for attribute in attributes {
    if attribute.role is Attribute(keys) {
      for key in keys {
        if !positions.contains(key) {
          raise Invalid(
            path=attribute.id,
            reason="attachment references unknown dimension: \{key}",
          )
        }
      }
    }
  }
  { reference, dimensions, measures, attributes, positions, limits, }
}

///|
fn detached_component(c : Component) -> Component {
  { ..c, role: detached_role(c.role), }
}

///|
pub fn Structure::reference(self : Structure) -> StructureRef {
  self.reference
}

///|
pub fn Structure::dimensions(self : Structure) -> Array[Component] {
  self.dimensions.map(detached_component)
}

///|
pub fn Structure::measures(self : Structure) -> Array[Component] {
  self.measures.map(detached_component)
}

///|
pub fn Structure::attributes(self : Structure) -> Array[Component] {
  self.attributes.map(detached_component)
}

///|
pub fn Structure::components(self : Structure) -> Array[Component] {
  let all = self.dimensions()
  for c in self.measures {
    all.push(detached_component(c))
  }
  for c in self.attributes {
    all.push(detached_component(c))
  }
  all
}

///|
pub fn Structure::dimension_index(self : Structure, id : String) -> Int32? {
  self.positions.get(id)
}

///|
pub fn Structure::time_index(self : Structure) -> Int32? {
  for i, c in self.dimensions {
    if c.role is TimeDimension {
      return Some(i)
    }
  }
  None
}

///|
pub fn Structure::component(self : Structure, id : String) -> Component? {
  for c in self.dimensions {
    if c.id == id {
      return Some(detached_component(c))
    }
  }
  for c in self.measures {
    if c.id == id {
      return Some(detached_component(c))
    }
  }
  for c in self.attributes {
    if c.id == id {
      return Some(detached_component(c))
    }
  }
  None
}

///|
fn attachment_key(
  structure : Structure,
  attribute : Component,
  key : Array[String],
) -> String {
  let values : Array[String] = []
  if attribute.role is Attribute(keys) {
    for id in keys {
      values.push(key[structure.positions[id]])
    }
  }
  framed_key(values)
}
