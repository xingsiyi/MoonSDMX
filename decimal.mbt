///|
// Deliberately excludes Int64 minimum, so negation and absolute value are safe.
let decimal_bound : Int64 = 9000000000000000000L

///|
pub struct DecimalValue {
  coefficient : Int64
  scale : Int32
} derive(Eq, @debug.Debug)

///|
pub extend DecimalValue with Eq::{equal, not_equal}

///|
pub extend DecimalValue with @debug.Debug::{to_repr}

///|
fn decimal_abs(n : Int64) -> Int64 {
  if n < 0L {
    -n
  } else {
    n
  }
}

///|
fn decimal_times_ten(n : Int64) -> Int64 raise SdmxError {
  if decimal_abs(n) > decimal_bound / 10L {
    raise Invalid(path="decimal", reason="coefficient overflow")
  }
  n * 10L
}

///|
fn normalized_decimal(coefficient : Int64, scale : Int32) -> DecimalValue {
  let mut c = coefficient
  let mut s = scale
  while s > 0 && c % 10L == 0L {
    c /= 10L
    s -= 1
  }
  { coefficient: c, scale: s, }
}

///|
pub fn DecimalValue::parse(text : String) -> DecimalValue raise SdmxError {
  if text.is_empty() || text.length() > 128 {
    raise Invalid(path="decimal", reason="expected 1..128 characters")
  }
  let chars = text.to_array()
  let mut i = 0
  let mut negative = false
  if chars[0] == '-' || chars[0] == '+' {
    negative = chars[0] == '-'
    i += 1
  }
  let mut coefficient = 0L
  let mut digits = 0
  let mut scale = 0
  let mut dot = false
  while i < chars.length() && chars[i] != 'e' && chars[i] != 'E' {
    let ch = chars[i]
    if ch == '.' && !dot {
      dot = true
    } else if ch >= '0' && ch <= '9' {
      let digit = (ch.to_int() - 48).to_int64()
      if coefficient > (decimal_bound - digit) / 10L {
        raise Invalid(path="decimal", reason="coefficient overflow")
      }
      coefficient = coefficient * 10L + digit
      digits += 1
      if dot {
        scale += 1
      }
    } else {
      raise Invalid(path="decimal", reason="invalid numeric character")
    }
    i += 1
  }
  if digits == 0 {
    raise Invalid(path="decimal", reason="missing digits")
  }
  let mut exponent = 0
  if i < chars.length() {
    i += 1
    let mut exp_negative = false
    if i < chars.length() && (chars[i] == '+' || chars[i] == '-') {
      exp_negative = chars[i] == '-'
      i += 1
    }
    let start = i
    while i < chars.length() {
      let ch = chars[i]
      if ch < '0' || ch > '9' || exponent > 100 {
        raise Invalid(
          path="decimal.exponent",
          reason="invalid or excessive exponent",
        )
      }
      exponent = exponent * 10 + ch.to_int() - 48
      i += 1
    }
    if i == start || exponent > 128 {
      raise Invalid(
        path="decimal.exponent",
        reason="missing or excessive exponent",
      )
    }
    if exp_negative {
      exponent = -exponent
    }
  }
  scale -= exponent
  while scale < 0 {
    coefficient = decimal_times_ten(coefficient)
    scale += 1
  }
  if negative {
    coefficient = -coefficient
  }
  let value = normalized_decimal(coefficient, scale)
  if value.scale > 18 {
    raise Invalid(path="decimal", reason="more than 18 fractional digits")
  }
  value
}

///|
pub fn DecimalValue::format(self : DecimalValue) -> String {
  let digits = decimal_abs(self.coefficient).to_string()
  let sign = if self.coefficient < 0L { "-" } else { "" }
  if self.scale == 0 {
    return sign + digits
  }
  if digits.length() <= self.scale {
    return sign + "0." + "0".repeat(self.scale - digits.length()) + digits
  }
  let split = digits.length() - self.scale
  sign + digits[:split].to_owned() + "." + digits[split:].to_owned()
}

///|
pub fn DecimalValue::add(
  self : DecimalValue,
  other : DecimalValue,
) -> DecimalValue raise SdmxError {
  let scale = if self.scale > other.scale { self.scale } else { other.scale }
  let mut left = self.coefficient
  let mut right = other.coefficient
  for i = self.scale; i < scale; i = i + 1 {
    left = decimal_times_ten(left)
  }
  for i = other.scale; i < scale; i = i + 1 {
    right = decimal_times_ten(right)
  }
  if (right > 0L && left > decimal_bound - right) ||
    (right < 0L && left < -decimal_bound - right) {
    raise Invalid(path="decimal.sum", reason="coefficient overflow")
  }
  normalized_decimal(left + right, scale)
}

///|
pub fn DecimalValue::compare_value(
  self : DecimalValue,
  other : DecimalValue,
) -> Int32 {
  if self.coefficient < 0L && other.coefficient >= 0L {
    return -1
  }
  if self.coefficient >= 0L && other.coefficient < 0L {
    return 1
  }
  let scale = if self.scale > other.scale { self.scale } else { other.scale }
  let a = decimal_abs(self.coefficient).to_string() +
    "0".repeat(scale - self.scale)
  let b = decimal_abs(other.coefficient).to_string() +
    "0".repeat(scale - other.scale)
  let result = if a.length() != b.length() {
    a.length().compare(b.length())
  } else {
    a.lexical_compare(b)
  }
  if self.coefficient < 0L {
    -result
  } else {
    result
  }
}

///|
pub fn DecimalValue::is_integer(self : DecimalValue) -> Bool {
  self.scale == 0
}
