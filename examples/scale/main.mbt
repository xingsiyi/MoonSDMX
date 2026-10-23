///|
fn main raise {
  let s = @sdmx.Structure::new(@sdmx.StructureRef::new("DEMO", "SCALE", "1"), [
    @sdmx.Component::new("ENTITY", @sdmx.Dimension, @sdmx.Text),
    @sdmx.Component::new("TIME_PERIOD", @sdmx.TimeDimension, @sdmx.Period),
    @sdmx.Component::new("OBS_VALUE", @sdmx.Measure, @sdmx.Decimal),
    @sdmx.Component::new("UNIT", @sdmx.Attribute([]), @sdmx.Text, required=true),
  ])
  let before = @env.now()
  let rows = Array::makei(10000, i => {
    @sdmx.Observation::new(
      s,
      ["entity-\{i}", "2026-01"],
      [if i % 7 == 0 { None } else { Some(i.to_string()) }],
      [Some("count")],
    )
  })
  let data = @sdmx.Dataset::new(s, rows)
  let message = @sdmx.DataMessage::new(@sdmx.Datastructure, s.reference(), data)
  let encoded = message.encode_json2(
    id="scale",
    sender="DEMO",
    prepared="2026-10-23T00:00:00Z",
  )
  let restored = @sdmx.decode_json2(encoded, expected=Some(s)).dataset()
  assert_eq(restored.fingerprint(), data.fingerprint())
  let snapshot = @sdmx.PageSnapshot::new(restored)
  let mut cursor : @sdmx.PageCursor? = None
  let mut count = 0
  let mut pages = 0
  while true {
    let page = snapshot.page(page_size=127, after=cursor)
    count += page.observations().length()
    pages += 1
    cursor = page.next_cursor()
    if cursor is None {
      break
    }
  }
  assert_eq(count, 10000)
  assert_eq(pages, 79)
  assert_eq(data.coverage().measures()[0].omitted, 1429)
  println(
    "scale: n=10000 json_utf16=\{encoded.length()} pages=\{pages} omitted=1429 elapsed_ms=\{@env.now() - before}; content fingerprints equal",
  )
}
