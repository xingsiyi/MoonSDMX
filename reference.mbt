///|
pub struct StructureRef {
  priv agency : String
  priv id : String
  priv version : String
} derive(Eq, @debug.Debug)

///|
pub extend StructureRef with Eq::{equal, not_equal}

///|
pub extend StructureRef with @debug.Debug::{to_repr}

///|
pub fn StructureRef::new(
  agency : String,
  id : String,
  version : String,
) -> StructureRef raise SdmxError {
  identifier(agency, "reference.agency")
  identifier(id, "reference.id")
  identifier(version, "reference.version")
  { agency, id, version, }
}

///|
pub fn StructureRef::parse(text : String) -> StructureRef raise SdmxError {
  let colon = text.find(":")
  let open = text.find("(")
  match (colon, open) {
    (Some(c), Some(p)) if c > 0 && p > c + 1 && text.has_suffix(")") =>
      StructureRef::new(
        text[:c].to_owned(),
        text[c + 1:p].to_owned(),
        text[p + 1:text.length() - 1].to_owned(),
      )
    _ => raise Invalid(path="reference", reason="expected AGENCY:ID(VERSION)")
  }
}

///|
pub fn StructureRef::agency(self : StructureRef) -> String {
  self.agency
}

///|
pub fn StructureRef::id(self : StructureRef) -> String {
  self.id
}

///|
pub fn StructureRef::version(self : StructureRef) -> String {
  self.version
}

///|
pub fn StructureRef::format(self : StructureRef) -> String {
  "\{self.agency}:\{self.id}(\{self.version})"
}
