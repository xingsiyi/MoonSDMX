///|
pub(all) struct DimensionCoverage {
  id : String
  observed_values : Int32
  declared_codes : Int32?
  unseen_codes : Array[String]
} derive(@debug.Debug)

///|
pub extend DimensionCoverage with @debug.Debug::{to_repr}

///|
pub(all) struct ValueCoverage {
  id : String
  reported : Int32
  omitted : Int32
  distinct_values : Int32
} derive(@debug.Debug)

///|
pub extend ValueCoverage with @debug.Debug::{to_repr}

///|
pub struct DatasetCoverage {
  priv observations : Int32
  priv dimensions : Array[DimensionCoverage]
  priv measures : Array[ValueCoverage]
  priv attributes : Array[ValueCoverage]
  priv frequencies : Array[(String, Int32)]
  priv limits : Limits
} derive(@debug.Debug)

///|
pub extend DatasetCoverage with @debug.Debug::{to_repr}

///|
fn value_coverage(data : Dataset, measure : Bool) -> Array[ValueCoverage] {
  let components = if measure {
    data.structure.measures
  } else {
    data.structure.attributes
  }
  components.mapi((i, component) => {
    let seen : Map[String, Bool] = Map([])
    let mut reported = 0
    for row in data.rows {
      let value = if measure { row.measures[i] } else { row.attributes[i] }
      if value is Some(text) {
        reported += 1
        seen[text] = true
      }
    }
    {
      id: component.id,
      reported,
      omitted: data.rows.length() - reported,
      distinct_values: seen.length(),
    }
  })
}

///|
/// Coverage describes reported cells and vocabularies; it does not aggregate
/// values across units, frequencies, quality statuses or unit multipliers.
pub fn Dataset::coverage(self : Dataset) -> DatasetCoverage raise SdmxError {
  let dimensions = self.structure.dimensions.mapi((i, component) => {
    let seen : Map[String, Bool] = Map([])
    for row in self.rows {
      seen[row.key[i]] = true
    }
    let (declared_codes, unseen_codes) = match component.representation {
      Coded(codes) => {
        let unseen : Array[String] = []
        for (code, _) in codes.entries() {
          if !seen.contains(code) {
            unseen.push(code)
          }
        }
        (Some(codes.labels.length()), unseen)
      }
      _ => (None, [])
    }
    {
      id: component.id,
      observed_values: seen.length(),
      declared_codes,
      unseen_codes,
    }
  })
  let counts : Map[String, Int32] = Map([])
  if self.structure.time_index() is Some(position) {
    for row in self.rows {
      let frequency = PeriodValue::parse(row.key[position]).frequency()
      counts[frequency] = counts.get(frequency).unwrap_or(0) + 1
    }
  }
  let names : Array[String] = counts.keys().collect()
  names.sort_by((a, b) => a.lexical_compare(b))
  {
    observations: self.rows.length(),
    dimensions,
    measures: value_coverage(self, true),
    attributes: value_coverage(self, false),
    frequencies: names.map(name => (name, counts[name])),
    limits: self.structure.limits,
  }
}

///|
pub fn DatasetCoverage::observation_count(self : DatasetCoverage) -> Int32 {
  self.observations
}

///|
pub fn DatasetCoverage::dimensions(
  self : DatasetCoverage,
) -> Array[DimensionCoverage] {
  self.dimensions.map(c => { ..c, unseen_codes: c.unseen_codes.copy(), })
}

///|
pub fn DatasetCoverage::measures(
  self : DatasetCoverage,
) -> Array[ValueCoverage] {
  self.measures.copy()
}

///|
pub fn DatasetCoverage::attributes(
  self : DatasetCoverage,
) -> Array[ValueCoverage] {
  self.attributes.copy()
}

///|
pub fn DatasetCoverage::period_frequencies(
  self : DatasetCoverage,
) -> Array[(String, Int32)] {
  self.frequencies.copy()
}

///|
fn coverage_values_json(components : Array[ValueCoverage]) -> Array[Json] {
  components.map(c => {
    "id": c.id,
    "reported": c.reported,
    "omitted": c.omitted,
    "distinctValues": c.distinct_values,
  })
}

///|
pub fn DatasetCoverage::to_json(
  self : DatasetCoverage,
) -> String raise SdmxError {
  let dimensions : Array[Json] = self.dimensions.map(c => {
    let count = match c.declared_codes {
      None => Json::null()
      Some(n) => Json::number(n.to_double())
    }
    {
      "id": c.id,
      "observedValues": c.observed_values,
      "declaredCodes": count,
      "unseenCodes": c.unseen_codes.map(Json::string),
    }
  })
  let frequencies : Array[Json] = self.frequencies.map(pair => {
    "frequency": pair.0,
    "observations": pair.1,
  })
  canonical_json(
    {
      "profile": "moonsdmx.coverage/1",
      "observations": self.observations,
      "dimensions": dimensions,
      "measures": coverage_values_json(self.measures),
      "attributes": coverage_values_json(self.attributes),
      "periodFrequencies": frequencies,
    },
    self.limits,
  )
}
