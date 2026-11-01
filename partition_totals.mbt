///|
/// Merge compatible partitions, preserving first-seen order. Repeated keys are
/// rejected unless explicitly allowed AND every measure/attribute is identical.
pub fn Dataset::merge_partition(
  self : Dataset,
  other : Dataset,
  allow_identical~ : Bool = false,
) -> Dataset raise SdmxError {
  if self.structure.to_profile_json() != other.structure.to_profile_json() {
    raise Invalid(path="partition", reason="structure contracts differ")
  }
  let rows = self.rows.copy()
  for row in other.rows {
    match self.index.get(row.key_token()) {
      Some(i) =>
        if !allow_identical || self.rows[i] != row {
          raise Conflict(
            key=row.key_token(),
            reason="overlapping partition observation",
          )
        }
      None => {
        if rows.length() >= self.structure.limits.max_rows {
          raise Limit(
            resource="merged rows",
            maximum=self.structure.limits.max_rows,
          )
        }
        rows.push(row)
      }
    }
  }
  // Recheck cross-partition attribute attachment, not just duplicate keys.
  Dataset::new(self.structure, rows)
}

///|
pub(all) struct MeasureTotal {
  dimension_values : Array[String]
  attributes : Array[String?]
  frequency : String?
  reported : Int32
  missing : Int32
  total : String?
}

///|
priv struct TotalAccumulator {
  dimensions : Array[String]
  attributes : Array[String?]
  frequency : String?
  mut reported : Int32
  mut missing : Int32
  mut total : DecimalValue?
}

///|
/// Explicit numeric measure only. All attributes and period frequency remain
/// grouping keys, so units/quality/frequency are never silently combined.
/// Caller chooses whether summing observations is meaningful for its metric.
pub fn Dataset::grouped_totals(
  self : Dataset,
  measure : String,
  by : Array[String],
) -> Array[MeasureTotal] raise SdmxError {
  let indexes : Array[Int32] = []
  unique_names(by, "group dimensions")
  for name in by {
    match self.structure.dimension_index(name) {
      Some(i) => indexes.push(i)
      None => raise Invalid(path=name, reason="not a dimension")
    }
  }
  let mut selected = -1
  for i, c in self.structure.measures {
    if c.id == measure {
      if !(c.representation is Decimal || c.representation is Integer) {
        raise Invalid(path=measure, reason="numeric measure required")
      }
      selected = i
    }
  }
  if selected < 0 {
    raise Invalid(path=measure, reason="unknown measure")
  }
  let groups : Array[TotalAccumulator] = []
  let positions : Map[String, Int32] = Map([])
  for row in self.rows {
    let dimensions = indexes.map(i => row.key[i])
    let frequency = match self.structure.time_index() {
      Some(i) => Some(PeriodValue::parse(row.key[i]).frequency())
      None => None
    }
    let fields = dimensions.copy()
    for value in row.attributes {
      fields.push(
        match value {
          None => "0"
          Some(v) => "1" + v
        },
      )
    }
    fields.push(frequency.unwrap_or(""))
    let key = framed_key(fields)
    let index = match positions.get(key) {
      Some(i) => i
      None => {
        let i = groups.length()
        positions[key] = i
        groups.push({
          dimensions,
          attributes: row.attributes.copy(),
          frequency,
          reported: 0,
          missing: 0,
          total: None,
        })
        i
      }
    }
    let group = groups[index]
    match row.measures[selected] {
      None => group.missing += 1
      Some(value) => {
        let decimal = DecimalValue::parse(value)
        group.total = Some(
          match group.total {
            None => decimal
            Some(n) => n.add(decimal)
          },
        )
        group.reported += 1
      }
    }
  }
  groups.map(g => {
    dimension_values: g.dimensions.copy(),
    attributes: g.attributes.copy(),
    frequency: g.frequency,
    reported: g.reported,
    missing: g.missing,
    total: g.total.map(v => v.format()),
  })
}
