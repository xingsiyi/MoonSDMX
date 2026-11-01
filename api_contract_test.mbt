///|
test "public accessors cannot mutate a validated snapshot" {
  let attachment = ["REGION"]
  let attribute = @moonsdmx.Component::new(
    "UNIT",
    @moonsdmx.Attribute(attachment),
    @moonsdmx.Text,
    required=true,
  )
  attachment[0] = "UNKNOWN"
  let structure = @moonsdmx.Structure::new(
    @moonsdmx.StructureRef::new("DEMO", "API", "1"),
    [
      @moonsdmx.Component::new("REGION", @moonsdmx.Dimension, @moonsdmx.Text),
      @moonsdmx.Component::new(
        "TIME_PERIOD",
        @moonsdmx.TimeDimension,
        @moonsdmx.Period,
      ),
      @moonsdmx.Component::new(
        "OBS_VALUE",
        @moonsdmx.Measure,
        @moonsdmx.Decimal,
      ),
      attribute,
    ],
  )
  let key = ["N", "2026"]
  let values = [Some("0")]
  let row = @moonsdmx.Observation::new(structure, key, values, [Some("kWh")])
  let data = @moonsdmx.Dataset::new(structure, [row])
  let fingerprint = data.fingerprint()
  key[0] = "S"
  values[0] = None
  row.key()[0] = "W"
  row.measures()[0] = Some("999")
  structure.dimensions()[0] = structure.dimensions()[1]
  if attribute.role() is @moonsdmx.Attribute(keys) {
    keys[0] = "UNKNOWN"
  }
  data.observations()[0].attributes()[0] = Some("MWh")
  assert_eq(data.fingerprint(), fingerprint)
  assert_eq(data.get(["N", "2026"]).unwrap().measures(), [Some("0")])
  let first = @moonsdmx.PageSnapshot::new(data).page(page_size=1)
  first.observations()[0].key()[0] = "CHANGED"
  assert_eq(first.observations()[0].key()[0], "N")
}
