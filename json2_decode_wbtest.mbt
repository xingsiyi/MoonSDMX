///|
fn fixture_json_message() -> Json {
  {
    "meta": {
      "id": "synthetic",
      "sender": { "id": "DEMO" },
      "prepared": "2026-10-22T00:00:00Z",
    },
    "data": {
      "structures": [fixture_json_structure()],
      "dataSets": [
        {
          "attributes": [0],
          "series": {
            "0": { "observations": { "0": ["1.2300", 0], "1": [null] } },
          },
        },
      ],
    },
  }
}

///|
test "JSON2 expands series and restores logical keys with inherited unit" {
  let text = canonical_json(fixture_json_message(), Limits::standard())
  let message = decode_json2(text)
  let data = message.dataset().sorted()
  assert_eq(data.length(), 2)
  let rows = data.observations()
  assert_eq(rows[0].key(), ["2026-01", "N"])
  assert_eq(rows[0].measures(), [Some("1.2300")])
  assert_eq(rows[0].attributes(), [Some("kWh"), Some("E")])
  assert_eq(rows[1].measures(), [None])
  assert_eq(rows[1].attributes(), [Some("kWh"), None])
}

///|
test "JSON2 rejects out of range index mutation and annotation tuple" {
  let base = canonical_json(fixture_json_message(), Limits::standard())
  for
    text in [
      base.replace(old="\"attributes\":[0]", new="\"attributes\":[1]"),
      base.replace(
        old="\"dataSets\":[{",
        new="\"dataSets\":[{\"action\":\"Delete\",",
      ),
      base.replace(old="[\"1.2300\",0]", new="[\"1.2300\",0,1]"),
    ] {
    let failed = try {
      ignore(decode_json2(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
