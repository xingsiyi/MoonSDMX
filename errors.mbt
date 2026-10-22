///|
pub(all) suberror SdmxError {
  Invalid(path~ : String, reason~ : String)
  Limit(resource~ : String, maximum~ : Int32)
  Unsupported(feature~ : String)
  Conflict(key~ : String, reason~ : String)
} derive(@debug.Debug)

///|
pub extend SdmxError with @debug.Debug::{to_repr}

///|
pub fn SdmxError::message(self : SdmxError) -> String {
  match self {
    Invalid(path~, reason~) => "\{path}: \{reason}"
    Limit(resource~, maximum~) => "\{resource}: limit \{maximum} exceeded"
    Unsupported(feature~) => "unsupported profile: \{feature}"
    Conflict(key~, reason~) => "\{key}: \{reason}"
  }
}

///|
pub struct Limits {
  max_text : Int32
  max_rows : Int32
  max_columns : Int32
  max_field : Int32
  max_codes : Int32
  max_output : Int32
} derive(Eq, @debug.Debug)

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub fn Limits::new(
  max_text~ : Int32 = 16777216,
  max_rows~ : Int32 = 100000,
  max_columns~ : Int32 = 128,
  max_field~ : Int32 = 65536,
  max_codes~ : Int32 = 100000,
  max_output~ : Int32 = 33554432,
) -> Limits raise SdmxError {
  if max_text < 1 ||
    max_text > 67108864 ||
    max_rows < 1 ||
    max_rows > 1000000 ||
    max_columns < 1 ||
    max_columns > 1024 ||
    max_field < 1 ||
    max_field > 1048576 ||
    max_codes < 1 ||
    max_codes > 1000000 ||
    max_output < 1 ||
    max_output > 67108864 {
    raise Invalid(path="limits", reason="outside supported positive bounds")
  }
  { max_text, max_rows, max_columns, max_field, max_codes, max_output, }
}

///|
pub fn Limits::standard() -> Limits {
  {
    max_text: 16777216,
    max_rows: 100000,
    max_columns: 128,
    max_field: 65536,
    max_codes: 100000,
    max_output: 33554432,
  }
}

///|
pub fn Limits::max_rows(self : Limits) -> Int32 {
  self.max_rows
}

///|
fn check_text(
  text : String,
  limits : Limits,
  path : String,
) -> Unit raise SdmxError {
  if text.length() > limits.max_text {
    raise Limit(resource=path, maximum=limits.max_text)
  }
}

///|
fn check_field(
  text : String,
  limits : Limits,
  path : String,
) -> Unit raise SdmxError {
  if text.length() > limits.max_field {
    raise Limit(resource=path, maximum=limits.max_field)
  }
  for ch in text {
    if ch.to_int() == 0 {
      raise Invalid(path~, reason="NUL is not permitted")
    }
  }
}

///|
fn identifier(value : String, path : String) -> Unit raise SdmxError {
  if value.is_empty() || value.length() > 128 {
    raise Invalid(path~, reason="expected identifier of length 1..128")
  }
  for ch in value {
    let n = ch.to_int()
    if !((n >= 65 && n <= 90) ||
      (n >= 97 && n <= 122) ||
      (n >= 48 && n <= 57) ||
      ch == '_' ||
      ch == '-' ||
      ch == '.') {
      raise Invalid(path~, reason="invalid identifier character")
    }
  }
}

///|
fn unique_names(values : Array[String], path : String) -> Unit raise SdmxError {
  let seen : Map[String, Bool] = Map([])
  for value in values {
    identifier(value, path)
    if seen.contains(value) {
      raise Invalid(path~, reason="duplicate identifier: \{value}")
    }
    seen[value] = true
  }
}

///|
// Length framing avoids collisions when dimension values contain separators.
fn framed_key(values : Array[String]) -> String {
  let out = StringBuilder()
  for value in values {
    out.write_string(value.length().to_string())
    out.write_string(":")
    out.write_string(value)
  }
  out.to_string()
}
