///|
pub(all) struct PivotCell {
  value : String?
  attributes : Array[String?]
}

///|
pub(all) struct PivotRow {
  key : Array[String]
  cells : Array[PivotCell?]
}

///|
pub(all) struct PivotTable {
  row_dimensions : Array[String]
  column_dimension : String
  column_values : Array[String]
  measure : String
  attribute_names : Array[String]
  rows : Array[PivotRow]
}

///|
/// No aggregation or numeric conversion. None cell means no observation;
/// Some cell with None value means a reported missing measure.
pub fn Dataset::pivot_measure(
  self : Dataset,
  measure : String,
  column_dimension : String,
) -> PivotTable raise SdmxError {
  let axis = match self.structure.dimension_index(column_dimension) {
    Some(i) => i
    None => raise Invalid(path=column_dimension, reason="not a dimension")
  }
  let mut selected = -1
  for i, c in self.structure.measures {
    if c.id == measure {
      selected = i
    }
  }
  if selected < 0 {
    raise Invalid(path=measure, reason="unknown measure")
  }
  let columns : Array[String] = []
  let column_index : Map[String, Int32] = Map([])
  let keys : Array[Array[String]] = []
  let row_index : Map[String, Int32] = Map([])
  let indexes : Array[Int32] = []
  for i = 0; i < self.structure.dimensions.length(); i = i + 1 {
    if i != axis {
      indexes.push(i)
    }
  }
  for row in self.rows {
    let value = row.key[axis]
    if !column_index.contains(value) {
      if columns.length() >= self.structure.limits.max_columns {
        raise Limit(
          resource="pivot columns",
          maximum=self.structure.limits.max_columns,
        )
      }
      column_index[value] = columns.length()
      columns.push(value)
    }
    let key = indexes.map(i => row.key[i])
    let token = framed_key(key)
    if !row_index.contains(token) {
      row_index[token] = keys.length()
      keys.push(key)
    }
  }
  // A dense pivot can be much larger than its sparse input. Bound cells first.
  if !columns.is_empty() &&
    keys.length() > self.structure.limits.max_rows / columns.length() {
    raise Limit(resource="pivot cells", maximum=self.structure.limits.max_rows)
  }
  let output : Array[PivotRow] = keys.map(key => {
    key,
    cells: Array::make(columns.length(), None),
  })
  for row in self.rows {
    let r = row_index[framed_key(indexes.map(i => row.key[i]))]
    let c = column_index[row.key[axis]]
    output[r].cells[c] = Some({
      value: row.measures[selected],
      attributes: row.attributes.copy(),
    })
  }
  {
    row_dimensions: indexes.map(i => self.structure.dimensions[i].id),
    column_dimension,
    column_values: columns,
    measure,
    attribute_names: self.structure.attributes.map(c => c.id),
    rows: output,
  }
}

///|
pub(all) struct DensifyResult {
  dataset : Dataset
  inserted_keys : Array[Array[String]]
}

///|
/// Add explicitly requested missing periods for existing series only. Measures
/// stay missing; caller supplies attributes, checked against attachment rules.
/// Existing observations (including periods outside the request) are retained.
pub fn Dataset::densify_periods(
  self : Dataset,
  periods : Array[String],
  attributes : Array[String?],
) -> DensifyResult raise SdmxError {
  let time = match self.structure.time_index() {
    Some(i) => i
    None => raise Invalid(path="densify", reason="time dimension required")
  }
  let limits = self.structure.limits
  if periods.length() > limits.max_rows {
    raise Limit(resource="requested periods", maximum=limits.max_rows)
  }
  if attributes.length() != self.structure.attributes.length() {
    raise Invalid(path="attributes", reason="wrong attribute count")
  }
  for i, attribute in self.structure.attributes {
    match attributes[i] {
      Some(v) => validate_value(attribute, v, limits)
      None =>
        if attribute.required {
          raise Invalid(path=attribute.id, reason="required attribute")
        }
    }
  }
  let seen : Map[String, Bool] = Map([])
  let mut frequency : String? = None
  for value in periods {
    validate_value(self.structure.dimensions[time], value, limits)
    if seen.contains(value) {
      raise Invalid(path="periods", reason="duplicate period")
    }
    seen[value] = true
    let f = PeriodValue::parse(value).frequency()
    if frequency is Some(old) && old != f {
      raise Invalid(path="periods", reason="mixed frequencies")
    }
    frequency = Some(f)
  }
  let series : Array[Array[String]] = []
  let names : Map[String, Bool] = Map([])
  let indexes : Array[Int32] = []
  for i = 0; i < self.structure.dimensions.length(); i = i + 1 {
    if i != time {
      indexes.push(i)
    }
  }
  for row in self.rows {
    let f = PeriodValue::parse(row.key[time]).frequency()
    if frequency is Some(old) && old != f {
      raise Invalid(path="periods", reason="input frequency differs")
    }
    let token = framed_key(indexes.map(i => row.key[i]))
    if !names.contains(token) {
      names[token] = true
      series.push(row.key.copy())
    }
  }
  if !periods.is_empty() && series.length() > limits.max_rows / periods.length() {
    raise Limit(resource="series-period work", maximum=limits.max_rows)
  }
  let additions : Array[Observation] = []
  let inserted : Array[Array[String]] = []
  let mut text = 0
  for row in self.rows {
    for k in row.key {
      text += k.length()
    }
    for group in [row.measures, row.attributes] {
      for v in group {
        if v is Some(s) {
          text += s.length()
        }
      }
    }
  }
  for series_key in series {
    for period in periods {
      let key = series_key.copy()
      key[time] = period
      if !self.index.contains(framed_key(key)) {
        if additions.length() >= limits.max_rows - self.rows.length() {
          raise Limit(resource="dense rows", maximum=limits.max_rows)
        }
        for v in key {
          if v.length() > limits.max_text - text {
            raise Limit(resource="dense text", maximum=limits.max_text)
          }
          text += v.length()
        }
        for v in attributes {
          if v is Some(s) {
            if s.length() > limits.max_text - text {
              raise Limit(resource="dense text", maximum=limits.max_text)
            }
            text += s.length()
          }
        }
        additions.push(
          Observation::new(
            self.structure,
            key,
            Array::make(self.structure.measures.length(), None),
            attributes,
          ),
        )
        inserted.push(key)
      }
    }
  }
  let rows = self.rows.copy()
  rows.append(additions)
  { dataset: Dataset::new(self.structure, rows), inserted_keys: inserted, }
}
