///|
pub struct PeriodWindow {
  start_day : Int32
  end_day : Int32
} derive(Eq, @debug.Debug)

///|
pub extend PeriodWindow with Eq::{equal, not_equal}

///|
pub extend PeriodWindow with @debug.Debug::{to_repr}

///|
pub fn PeriodWindow::new(
  first : PeriodValue,
  through : PeriodValue,
) -> PeriodWindow raise SdmxError {
  if first.start_day >= through.end_day || first.start_day > through.start_day {
    raise Invalid(
      path="period window",
      reason="reversed reporting period interval",
    )
  }
  { start_day: first.start_day, end_day: through.end_day, }
}

///|
pub fn Dataset::periods_overlapping(
  self : Dataset,
  window : PeriodWindow,
) -> Dataset raise SdmxError {
  let position = match self.structure.time_index() {
    Some(i) => i
    None =>
      raise Invalid(
        path="period query",
        reason="structure has no time dimension",
      )
  }
  let rows : Array[Observation] = []
  for row in self.rows {
    let period = PeriodValue::parse(row.key[position])
    if period.start_day < window.end_day && window.start_day < period.end_day {
      rows.push(row)
    }
  }
  Dataset::new(self.structure, rows)
}

///|
pub fn Dataset::periods_contained(
  self : Dataset,
  window : PeriodWindow,
) -> Dataset raise SdmxError {
  let position = match self.structure.time_index() {
    Some(i) => i
    None =>
      raise Invalid(
        path="period query",
        reason="structure has no time dimension",
      )
  }
  let rows : Array[Observation] = []
  for row in self.rows {
    let period = PeriodValue::parse(row.key[position])
    if period.start_day >= window.start_day && period.end_day <= window.end_day {
      rows.push(row)
    }
  }
  Dataset::new(self.structure, rows)
}

///|
/// Optional cross-component constraint; only the documented A/S/Q/M/D codes apply.
pub fn Dataset::validate_frequency(
  self : Dataset,
  frequency_dimension : String,
) -> Unit raise SdmxError {
  let position = match self.structure.time_index() {
    Some(i) => i
    None =>
      raise Invalid(path="frequency", reason="structure has no time dimension")
  }
  let frequency = match self.structure.dimension_index(frequency_dimension) {
    Some(i) => i
    None => raise Invalid(path=frequency_dimension, reason="not a dimension")
  }
  for row in self.rows {
    let expected = PeriodValue::parse(row.key[position]).frequency()
    if row.key[frequency] != expected {
      raise Conflict(
        key=row.key_token(),
        reason="FREQ does not match calendar period granularity",
      )
    }
  }
}
