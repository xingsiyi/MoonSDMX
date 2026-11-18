///|
#derive(@debug.Debug)
pub(all) struct DimensionGroup {
  id : String
  dimensions : Array[String]
}

///|
pub extend DimensionGroup with @debug.Debug::{to_repr}

///|
#derive(@debug.Debug)
pub struct Structure {
  priv reference : StructureRef
  priv dimensions : Array[Component]
  priv measures : Array[Component]
  priv attributes : Array[Component]
  priv positions : Map[String, Int32]
  priv limits : Limits
  priv groups : Array[DimensionGroup]
}

///|
pub extend Structure with @debug.Debug::{to_repr}

///|
pub fn Structure::new(
  reference : StructureRef,
  components : Array[Component],
  limits~ : Limits = Limits::standard(),
  groups~ : Array[DimensionGroup] = [],
) -> Structure raise SdmxError {
  if components.length() > limits.max_columns {
    raise Limit(resource="components", maximum=limits.max_columns)
  }
  if groups.length() > limits.max_columns {
    raise Limit(resource="dimension groups", maximum=limits.max_columns)
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
  let definitions : Map[String, Array[String]] = Map([])
  let group_keys : Map[String, Bool] = Map([])
  let groups = groups.map(group => {
    identifier(group.id, "group.id")
    unique_names(group.dimensions, "group dimensions")
    if ids.contains(group.id) ||
      definitions.contains(group.id) ||
      group.dimensions.is_empty() ||
      group.dimensions.length() > dimensions.length() {
      raise Invalid(
        path=group.id,
        reason="invalid or duplicate dimension group",
      )
    }
    let names = dimensions
      .map(c => c.id)
      .filter(id => group.dimensions.contains(id))
    if names.length() != group.dimensions.length() {
      raise Invalid(path=group.id, reason="unknown dimension in group")
    }
    let token = framed_key(names)
    if group_keys.contains(token) {
      raise Invalid(path=group.id, reason="duplicate group dimension set")
    }
    group_keys[token] = true
    definitions[group.id] = names
    { id: group.id, dimensions: names, }
  })
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
    for id in attribute.measure_ids {
      if !measures.any(c => c.id == id) {
        raise Invalid(
          path=attribute.id,
          reason="attachment references unknown measure: \{id}",
        )
      }
    }
    if attribute.group is Some(id) {
      let names = definitions.get(id)
      if !(attribute.role is Attribute(keys) &&
        names is Some(dims) &&
        keys.length() == dims.length() &&
        keys.all(k => dims.contains(k))) {
        raise Invalid(
          path=attribute.id,
          reason="group reference or dimensions disagree",
        )
      }
    }
  }
  { reference, dimensions, measures, attributes, positions, limits, groups, }
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

///|
pub fn Structure::groups(self : Structure) -> Array[DimensionGroup] {
  self.groups.map(group => {
    id: group.id,
    dimensions: group.dimensions.copy(),
  })
}

///|
fn same_measure_scope(
  a : Component,
  b : Component,
  structure : Structure,
) -> Bool {
  a.measure_ids == b.measure_ids ||
  (
    a.measure_ids.is_empty() &&
    b.measure_ids.length() == structure.measures.length()
  ) ||
  (
    b.measure_ids.is_empty() &&
    a.measure_ids.length() == structure.measures.length()
  )
}
