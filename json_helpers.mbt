///|
fn parse_bounded_json(text : String, limits : Limits) -> Json raise SdmxError {
  check_text(text, limits, "JSON text")
  let value = @json.parse(
    text[:],
    max_nesting_depth=24,
    reject_duplicate_keys=true,
    preserve_number_repr=true,
  ) catch {
    error => raise Invalid(path="JSON", reason=error.to_string())
  }
  let pending = [value]
  let mut nodes = 0
  while !pending.is_empty() {
    let node = pending.pop().unwrap()
    nodes += 1
    if nodes > 1000000 {
      raise Limit(resource="JSON nodes", maximum=1000000)
    }
    match node {
      Object(object) =>
        for key, child in object {
          check_field(key, limits, "JSON property")
          pending.push(child)
        }
      Array(array) =>
        for child in array {
          pending.push(child)
        }
      String(text) => check_field(text, limits, "JSON string")
      _ => ()
    }
    if pending.length() > 1000000 {
      raise Limit(resource="JSON nodes", maximum=1000000)
    }
  }
  value
}

///|
fn j_object(value : Json, path : String) -> Map[String, Json] raise SdmxError {
  match value {
    Object(object) => object
    _ => raise Invalid(path~, reason="expected object")
  }
}

///|
fn j_array(value : Json, path : String) -> Array[Json] raise SdmxError {
  match value {
    Array(array) => array
    _ => raise Invalid(path~, reason="expected array")
  }
}

///|
fn j_string(value : Json, path : String) -> String raise SdmxError {
  match value {
    String(text) => text
    _ => raise Invalid(path~, reason="expected string")
  }
}

///|
fn j_bool(value : Json, path : String) -> Bool raise SdmxError {
  match value {
    True => true
    False => false
    _ => raise Invalid(path~, reason="expected boolean")
  }
}

///|
fn j_int(value : Json, path : String, maximum : Int32) -> Int32 raise SdmxError {
  match value {
    Number(n, ..) if n >= 0.0 && n <= maximum.to_double() => {
      let result = n.to_int()
      if result.to_double() != n {
        raise Invalid(path~, reason="expected nonnegative integer")
      }
      result
    }
    _ => raise Invalid(path~, reason="index outside supported range")
  }
}

///|
fn j_required(
  object : Map[String, Json],
  name : String,
) -> Json raise SdmxError {
  match object.get(name) {
    Some(value) => value
    None => raise Invalid(path=name, reason="missing property")
  }
}

///|
fn j_known(
  object : Map[String, Json],
  names : Array[String],
  path : String,
) -> Unit raise SdmxError {
  for name, _ in object {
    if !names.contains(name) {
      raise Unsupported(feature="\{path}.\{name}")
    }
  }
}

///|
fn j_strings(value : Json, path : String) -> Array[String] raise SdmxError {
  j_array(value, path).map(v => j_string(v, path))
}

///|
fn j_optional_string(
  object : Map[String, Json],
  name : String,
  fallback : String,
) -> String raise SdmxError {
  match object.get(name) {
    None | Some(Null) => fallback
    Some(value) => j_string(value, name)
  }
}

///|
fn j_optional_bool(
  object : Map[String, Json],
  name : String,
  fallback : Bool,
) -> Bool raise SdmxError {
  match object.get(name) {
    None | Some(Null) => fallback
    Some(value) => j_bool(value, name)
  }
}

///|
fn j_scalar(value : Json, path : String) -> String? raise SdmxError {
  match value {
    Null => None
    String(text) =>
      if text.is_empty() {
        raise Invalid(path~, reason="empty scalar outside profile")
      } else {
        Some(text)
      }
    Number(_, repr~) =>
      Some(
        match repr {
          Some(text) => text
          None => value.stringify()
        },
      )
    _ => raise Unsupported(feature="non-scalar component value at \{path}")
  }
}

///|
fn canonical_json(value : Json, limits : Limits) -> String raise SdmxError {
  let out = StringBuilder()
  let mut units = 0
  fn write(text : String) -> Unit raise SdmxError {
    if units > limits.max_output - text.length() {
      raise Limit(resource="JSON output", maximum=limits.max_output)
    }
    units += text.length()
    out.write_string(text)
  }
  fn visit(value : Json) -> Unit raise SdmxError {
    match value {
      Object(object) => {
        write("{")
        let names : Array[String] = object.keys().collect()
        names.sort_by((a, b) => a.lexical_compare(b))
        for i, name in names {
          if i > 0 {
            write(",")
          }
          write(Json::string(name).stringify())
          write(":")
          visit(object[name])
        }
        write("}")
      }
      Array(array) => {
        write("[")
        for i, child in array {
          if i > 0 {
            write(",")
          }
          visit(child)
        }
        write("]")
      }
      _ => write(value.stringify())
    }
  }
  visit(value)
  out.to_string()
}
