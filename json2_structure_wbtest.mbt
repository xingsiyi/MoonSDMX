///|
fn fixture_json_structure() -> Json {
  {
    "links": [
      {
        "urn": "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=DEMO:ENERGY(1.0)",
      },
    ],
    "dimensions": {
      "series": [
        {
          "id": "REGION",
          "keyPosition": 1,
          "values": [{ "id": "N", "name": "North" }],
        },
      ],
      "observation": [
        {
          "id": "TIME_PERIOD",
          "keyPosition": 0,
          "values": [{ "id": "2026-01" }, { "id": "2026-02" }],
        },
      ],
    },
    "measures": {
      "observation": [
        { "id": "OBS_VALUE", "format": { "dataType": "Decimal" } },
      ],
    },
    "attributes": {
      "dataSet": [
        {
          "id": "UNIT",
          "relationship": { "dimensions": ["REGION"] },
          "values": [{ "id": "kWh" }],
        },
      ],
      "observation": [
        {
          "id": "STATUS",
          "relationship": { "observation": {} },
          "values": [{ "id": "E" }],
        },
      ],
    },
  }
}

///|
test "JSON2 metadata restores DSD order independent of physical layout" {
  let layout = json_layout(fixture_json_structure(), None, Limits::standard())
  assert_eq(layout.structure.dimensions()[0].id(), "TIME_PERIOD")
  assert_eq(layout.structure.dimensions()[1].id(), "REGION")
  assert_eq(layout.dataset_attributes[0].component.id(), "UNIT")
  match layout.dataset_attributes[0].component.role() {
    Attribute(keys) => assert_eq(keys, ["REGION"])
    _ => fail("attribute expected")
  }
  assert_eq(layout.reference.id(), "ENERGY")
  assert_eq(layout.kind, Dataflow)
}
