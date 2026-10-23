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

///|
test "JSON2 applies attribute defaults before attached metadata validation" {
  let value = fixture_json_message()
  let data = j_object(j_object(value, "root")["data"], "data")
  let structure = j_object(
    j_array(data["structures"], "structures")[0],
    "structure",
  )
  let attrs = j_object(structure["attributes"], "attributes")
  j_object(j_array(attrs["dataSet"], "dataSet attributes")[0], "unit")["default"] = Json::string(
    "kWh",
  )
  let dataset = j_object(j_array(data["dataSets"], "datasets")[0], "dataset")
  dataset["attributes"] = Json::array([Json::null()])
  let message = decode_json2(canonical_json(value, Limits::standard()))
  assert_eq(message.dataset().observations()[0].attributes()[0], Some("kWh"))
}

///|
test "external DSD validation rejects conflicting identified source structure" {
  let value = fixture_json_message()
  let root = j_object(value, "root")
  let data = j_object(root["data"], "data")
  let structure = j_object(
    j_array(data["structures"], "structures")[0],
    "structure",
  )
  let expected = json_layout(
      structure |> Json::object,
      None,
      Limits::standard(),
    ).structure
  j_array(structure["links"], "links").push({
    "urn": "urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=DEMO:OTHER(1.0)",
    "rel": "datastructure",
  })
  let rejected = try {
    ignore(
      decode_json2(
        canonical_json(value, Limits::standard()),
        expected=Some(expected),
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
