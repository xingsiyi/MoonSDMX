///|
pub struct CodeList {
  id : String
  labels : Map[String, String]
} derive(@debug.Debug)

///|
pub extend CodeList with @debug.Debug::{to_repr}

///|
pub fn CodeList::new(
  id : String,
  entries : Array[(String, String)],
  limits~ : Limits = Limits::standard(),
) -> CodeList raise SdmxError {
  identifier(id, "codelist.id")
  if entries.length() > limits.max_codes {
    raise Limit(resource="codes", maximum=limits.max_codes)
  }
  let labels : Map[String, String] = Map([])
  let mut text_units = 0
  for (code, label) in entries {
    if code.is_empty() {
      raise Invalid(path="code", reason="empty code is reserved for omission")
    }
    check_field(code, limits, "code")
    check_field(label, limits, "code.label")
    let extra = code.length() + label.length()
    if text_units > limits.max_text - extra {
      raise Limit(resource="code list text", maximum=limits.max_text)
    }
    text_units += extra
    if labels.contains(code) {
      raise Invalid(path="codelist", reason="duplicate code: \{code}")
    }
    labels[code] = label
  }
  { id, labels, }
}

///|
pub fn CodeList::id(self : CodeList) -> String {
  self.id
}

///|
pub fn CodeList::contains(self : CodeList, code : String) -> Bool {
  self.labels.contains(code)
}

///|
pub fn CodeList::label(self : CodeList, code : String) -> String? {
  self.labels.get(code)
}

///|
pub fn CodeList::entries(self : CodeList) -> Array[(String, String)] {
  let codes : Array[String] = self.labels.keys().collect()
  codes.sort_by((a, b) => a.lexical_compare(b))
  codes.map(code => (code, self.labels[code]))
}

///|
pub(all) enum Representation {
  Text
  Decimal
  Integer
  Period
  Coded(CodeList)
} derive(@debug.Debug)

///|
pub extend Representation with @debug.Debug::{to_repr}

///|
pub(all) enum Role {
  Dimension
  TimeDimension
  Measure
  Attribute(Array[String])
} derive(@debug.Debug)

///|
pub extend Role with @debug.Debug::{to_repr}

///|
fn detached_role(role : Role) -> Role {
  match role {
    Attribute(keys) => Attribute(keys.copy())
    _ => role
  }
}

///|
pub struct Component {
  id : String
  name : String
  role : Role
  representation : Representation
  required : Bool
} derive(@debug.Debug)

///|
pub extend Component with @debug.Debug::{to_repr}

///|
pub fn Component::new(
  id : String,
  role : Role,
  representation : Representation,
  name~ : String = "",
  required~ : Bool = false,
) -> Component raise SdmxError {
  identifier(id, "component.id")
  check_field(name, Limits::standard(), "component.name")
  if role is Attribute(keys) {
    unique_names(keys, "attachment")
  }
  { id, name, role: detached_role(role), representation, required, }
}

///|
pub fn Component::id(self : Component) -> String {
  self.id
}

///|
pub fn Component::name(self : Component) -> String {
  self.name
}

///|
pub fn Component::role(self : Component) -> Role {
  detached_role(self.role)
}

///|
pub fn Component::representation(self : Component) -> Representation {
  self.representation
}

///|
pub fn Component::required(self : Component) -> Bool {
  self.required
}
