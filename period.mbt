///|
pub(all) enum Granularity {
  Annual
  HalfYear
  Quarterly
  Monthly
  Daily
} derive(Eq, @debug.Debug)

///|
pub extend Granularity with Eq::{equal, not_equal}

///|
pub extend Granularity with @debug.Debug::{to_repr}

///|
pub struct PeriodValue {
  priv code : String
  priv granularity : Granularity
  priv start_day : Int32
  priv end_day : Int32
} derive(Eq, @debug.Debug)

///|
pub extend PeriodValue with Eq::{equal, not_equal}

///|
pub extend PeriodValue with @debug.Debug::{to_repr}

///|
fn leap_year(year : Int32) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
fn month_days(year : Int32, month : Int32) -> Int32 {
  match month {
    2 => if leap_year(year) { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
// 0001-01-01 is day zero; only the end sentinel may use year 10000.
fn civil_day(year : Int32, month : Int32, day : Int32) -> Int32 {
  let y = year - 1
  let mut ordinal = 365 * y + y / 4 - y / 100 + y / 400 + day - 1
  for m = 1; m < month; m = m + 1 {
    ordinal += month_days(year, m)
  }
  ordinal
}

///|
fn period_digits(
  text : String,
  start : Int32,
  end : Int32,
) -> Int32 raise SdmxError {
  let mut value = 0
  for i = start; i < end; i = i + 1 {
    let n = text[i].to_int()
    if n < 48 || n > 57 {
      raise Invalid(path="period", reason="expected decimal digits")
    }
    value = value * 10 + n - 48
  }
  value
}

///|
pub fn PeriodValue::parse(text : String) -> PeriodValue raise SdmxError {
  let size = text.length()
  if size != 4 && size != 7 && size != 10 {
    raise Unsupported(
      feature="period outside Gregorian Jan-1 year/half/quarter/month/day profile",
    )
  }
  let year = period_digits(text, 0, 4)
  if year == 0 {
    raise Invalid(path="period.year", reason="year must be 0001..9999")
  }
  if size == 4 {
    return {
      code: text,
      granularity: Annual,
      start_day: civil_day(year, 1, 1),
      end_day: civil_day(year + 1, 1, 1),
    }
  }
  if text[4] != '-' {
    raise Invalid(path="period", reason="expected '-' after year")
  }
  if size == 7 && (text[5] == 'Q' || text[5] == 'S') {
    let part = period_digits(text, 6, 7)
    let step = if text[5] == 'Q' { 3 } else { 6 }
    let maximum = 12 / step
    if part < 1 || part > maximum {
      raise Invalid(path="period", reason="quarter/half out of range")
    }
    let month = (part - 1) * step + 1
    let end_month = month + step
    let end_day = if end_month > 12 {
      civil_day(year + 1, 1, 1)
    } else {
      civil_day(year, end_month, 1)
    }
    return {
      code: text,
      granularity: if step == 3 {
        Quarterly
      } else {
        HalfYear
      },
      start_day: civil_day(year, month, 1),
      end_day,
    }
  }
  let month = period_digits(text, 5, 7)
  if month < 1 || month > 12 {
    raise Invalid(path="period.month", reason="month out of range")
  }
  if size == 7 {
    let end_day = if month == 12 {
      civil_day(year + 1, 1, 1)
    } else {
      civil_day(year, month + 1, 1)
    }
    return {
      code: text,
      granularity: Monthly,
      start_day: civil_day(year, month, 1),
      end_day,
    }
  }
  if text[7] != '-' {
    raise Invalid(path="period", reason="expected '-' before day")
  }
  let day = period_digits(text, 8, 10)
  if day < 1 || day > month_days(year, month) {
    raise Invalid(path="period.day", reason="day out of range")
  }
  let start_day = civil_day(year, month, day)
  { code: text, granularity: Daily, start_day, end_day: start_day + 1, }
}

///|
pub fn PeriodValue::code(self : PeriodValue) -> String {
  self.code
}

///|
pub fn PeriodValue::granularity(self : PeriodValue) -> Granularity {
  self.granularity
}

///|
pub fn PeriodValue::day_bounds(self : PeriodValue) -> (Int32, Int32) {
  (self.start_day, self.end_day)
}

///|
pub fn PeriodValue::overlaps(self : PeriodValue, other : PeriodValue) -> Bool {
  self.start_day < other.end_day && other.start_day < self.end_day
}

///|
pub fn PeriodValue::contains_period(
  self : PeriodValue,
  other : PeriodValue,
) -> Bool {
  self.start_day <= other.start_day && self.end_day >= other.end_day
}

///|
pub fn PeriodValue::compare_period(
  self : PeriodValue,
  other : PeriodValue,
) -> Int32 {
  let first = self.start_day.compare(other.start_day)
  if first != 0 {
    first
  } else {
    self.end_day.compare(other.end_day)
  }
}

///|
pub fn PeriodValue::frequency(self : PeriodValue) -> String {
  match self.granularity {
    Annual => "A"
    HalfYear => "S"
    Quarterly => "Q"
    Monthly => "M"
    Daily => "D"
  }
}
