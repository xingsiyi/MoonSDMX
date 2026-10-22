///|
fn csv_push_field(
  row : Array[String],
  value : String,
  limits : Limits,
) -> Unit raise SdmxError {
  if row.length() >= limits.max_columns + 3 {
    raise Limit(resource="CSV columns", maximum=limits.max_columns + 3)
  }
  check_field(value, limits, "CSV field")
  row.push(value)
}

///|
fn csv_push_row(
  rows : Array[Array[String]],
  row : Array[String],
  limits : Limits,
) -> Unit raise SdmxError {
  if rows.length() >= limits.max_rows + 1 {
    raise Limit(resource="CSV records", maximum=limits.max_rows)
  }
  rows.push(row)
}

///|
fn csv_rows(
  text : String,
  limits : Limits,
) -> Array[Array[String]] raise SdmxError {
  check_text(text, limits, "CSV text")
  let chars = text.to_array()
  let rows : Array[Array[String]] = []
  let mut row : Array[String] = []
  let mut field = StringBuilder()
  let mut units = 0
  let mut state = 0 // start, unquoted, quoted, after closing quote
  let mut i = if chars.length() > 0 && chars[0].to_int() == 65279 {
    1
  } else {
    0
  }
  while i < chars.length() {
    let ch = chars[i]
    if state == 2 {
      if ch == '"' {
        if i + 1 < chars.length() && chars[i + 1] == '"' {
          field.write_char('"')
          units += 1
          i += 1
        } else {
          state = 3
        }
      } else {
        field.write_char(ch)
        units += if ch.to_int() > 65535 { 2 } else { 1 }
      }
    } else if ch == ',' {
      csv_push_field(row, field.to_string(), limits)
      field = StringBuilder()
      units = 0
      state = 0
    } else if ch == '\r' || ch == '\n' {
      if ch == '\r' {
        if i + 1 >= chars.length() || chars[i + 1] != '\n' {
          raise Invalid(path="CSV", reason="bare CR outside quoted field")
        }
        i += 1
      }
      csv_push_field(row, field.to_string(), limits)
      csv_push_row(rows, row, limits)
      row = []
      field = StringBuilder()
      units = 0
      state = 0
    } else if ch == '"' && state == 0 {
      state = 2
    } else if ch == '"' || state == 3 {
      raise Invalid(
        path="CSV row \{rows.length() + 1}",
        reason="invalid quotation",
      )
    } else {
      state = 1
      field.write_char(ch)
      units += if ch.to_int() > 65535 { 2 } else { 1 }
    }
    if units > limits.max_field {
      raise Limit(resource="CSV field", maximum=limits.max_field)
    }
    i += 1
  }
  if state == 2 {
    raise Invalid(path="CSV", reason="unterminated quoted field")
  }
  if !row.is_empty() || units > 0 || state != 0 {
    csv_push_field(row, field.to_string(), limits)
    csv_push_row(rows, row, limits)
  }
  if rows.is_empty() {
    raise Invalid(path="CSV", reason="missing header")
  }
  let width = rows[0].length()
  for n, record in rows {
    if record.length() != width {
      raise Invalid(
        path="CSV row \{n + 1}",
        reason="record width differs from header",
      )
    }
  }
  rows
}

///|
fn csv_quote(value : String) -> String {
  let out = StringBuilder()
  let mut quote = false
  for ch in value {
    if ch == ',' || ch == '"' || ch == '\r' || ch == '\n' {
      quote = true
    }
  }
  if !quote {
    return value
  }
  out.write_char('"')
  for ch in value {
    if ch == '"' {
      out.write_char('"')
    }
    out.write_char(ch)
  }
  out.write_char('"')
  out.to_string()
}

///|
fn csv_document(
  rows : Array[Array[String]],
  limits : Limits,
) -> String raise SdmxError {
  let output = StringBuilder()
  let mut units = 0
  for row in rows {
    for i, field in row {
      check_field(field, limits, "CSV output field")
      let escaped = csv_quote(field)
      let extra = escaped.length() + (if i == 0 { 0 } else { 1 })
      if units > limits.max_output - extra {
        raise Limit(resource="CSV output", maximum=limits.max_output)
      }
      units += extra
      if i > 0 {
        output.write_char(',')
      }
      output.write_string(escaped)
    }
    if units > limits.max_output - 2 {
      raise Limit(resource="CSV output", maximum=limits.max_output)
    }
    units += 2
    output.write_string("\r\n")
  }
  output.to_string()
}
