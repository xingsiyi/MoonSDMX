///|
test "public accessors cannot mutate a validated snapshot" {
  let attachment = ["REGION"]
  let attribute = @sdmx.Component::new(
    "UNIT",
    @sdmx.Attribute(attachment),
    @sdmx.Text,
    required=true,
  )
  attachment[0] = "UNKNOWN"
  let structure = @sdmx.Structure::new(
    @sdmx.StructureRef::new("DEMO", "API", "1"),
    [
      @sdmx.Component::new("REGION", @sdmx.Dimension, @sdmx.Text),
      @sdmx.Component::new("TIME_PERIOD", @sdmx.TimeDimension, @sdmx.Period),
      @sdmx.Component::new("OBS_VALUE", @sdmx.Measure, @sdmx.Decimal),
      attribute,
    ],
  )
  let key = ["N", "2026"]
  let values = [Some("0")]
  let row = @sdmx.Observation::new(structure, key, values, [Some("kWh")])
  let data = @sdmx.Dataset::new(structure, [row])
  let fingerprint = data.fingerprint()
  key[0] = "S"
  values[0] = None
  row.key()[0] = "W"
  row.measures()[0] = Some("999")
  structure.dimensions()[0] = structure.dimensions()[1]
  if attribute.role() is @sdmx.Attribute(keys) {
    keys[0] = "UNKNOWN"
  }
  data.observations()[0].attributes()[0] = Some("MWh")
  assert_eq(data.fingerprint(), fingerprint)
  assert_eq(data.get(["N", "2026"]).unwrap().measures(), [Some("0")])
  let first = @sdmx.PageSnapshot::new(data).page(page_size=1)
  first.observations()[0].key()[0] = "CHANGED"
  assert_eq(first.observations()[0].key()[0], "N")
}
