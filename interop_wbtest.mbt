///|
fn registry_fixture() -> Json {
  {
    "meta": {
      "schema": "https://json.sdmx.org/2.0.0/sdmx-json-structure-schema.json",
      "id": "demo",
      "sender": { "id": "DEMO" },
    },
    "data": {
      "codelists": [
        {
          "agencyID": "DEMO",
          "id": "CL_AREA",
          "version": "1.0",
          "codes": [
            { "id": "A", "name": "Area A" },
            { "id": "B", "name": "Area B" },
          ],
        },
      ],
      "dataStructures": [
        {
          "agencyID": "DEMO",
          "id": "DSD",
          "version": "1.0",
          "dataStructureComponents": {
            "dimensionList": {
              "dimensions": [
                {
                  "id": "AREA",
                  "position": 1,
                  "localRepresentation": {
                    "enumeration": "urn:sdmx:org.sdmx.infomodel.codelist.Codelist=DEMO:CL_AREA(1.0)",
                  },
                },
              ],
              "timeDimensions": [{ "id": "TIME_PERIOD", "position": 2 }],
            },
            "measureList": {
              "primaryMeasure": {
                "id": "OBS_VALUE",
                "localRepresentation": { "format": { "textType": "Decimal" } },
              },
            },
            "attributeList": {
              "attributes": [
                {
                  "id": "UNIT",
                  "attributeRelationship": { "dimensions": ["AREA"] },
                  "localRepresentation": { "format": { "textType": "String" } },
                },
              ],
            },
          },
        },
      ],
      "dataflows": [
        {
          "agencyID": "DEMO",
          "id": "FLOW",
          "version": "1.0",
          "structure": "urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=DEMO:DSD(1.0)",
        },
      ],
    },
  }
}

///|
fn registry_catalog() -> StructureCatalog raise SdmxError {
  StructureCatalog::from_json2(
    canonical_json(registry_fixture(), Limits::standard()),
  )
}

///|
test "repeated catalog resolution never mutates stored descriptor arrays" {
  try {
    let c = registry_catalog()
    ignore(c.references())
    ignore(
      decode_json2_bundle(
        canonical_json(
          action_fixture("Information", Some("1.20")),
          Limits::standard(),
        ),
        catalog=Some(c),
      ),
    )
    ignore(
      decode_csv2_bundle(
        "STRUCTURE,STRUCTURE_ID,ACTION,AREA,TIME_PERIOD,OBS_VALUE,UNIT\r\ndataflow,DEMO:FLOW(1.0),A,A,2026-01,1.20,kWh\r\n",
        c,
      ),
    )
  } catch {
    e => fail(e.message())
  }
}

///|
fn action_fixture(
  action : String,
  value : String?,
  area~ : String = "A",
) -> Json {
  {
    "meta": { "id": "demo", "sender": { "id": "DEMO" } },
    "data": {
      "structures": [
        {
          "links": [
            {
              "urn": "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=DEMO:FLOW(1.0)",
              "rel": "dataflow",
            },
          ],
          "dimensions": {
            "observation": [
              { "id": "AREA", "keyPosition": 0, "values": [{ "id": area }] },
              {
                "id": "TIME_PERIOD",
                "keyPosition": 1,
                "values": [{ "id": "2026-01" }],
              },
            ],
          },
          "measures": {
            "observation": [
              { "id": "OBS_VALUE", "format": { "dataType": "Decimal" } },
            ],
          },
          "attributes": {
            "series": [],
            "observation": [
              { "id": "UNIT", "relationship": { "dimensions": ["AREA"] } },
            ],
          },
        },
      ],
      "dataSets": [
        {
          "structure": 0,
          "action": action,
          "observations": {
            "0:0": [
              match value {
                Some(v) => Json::string(v)
                None => Json::null()
              },
              "kWh",
            ],
          },
        },
      ],
    },
  }
}

///|
test "standard DSD codelist and dataflow resolution validates authoritative vocabulary" {
  let catalog = registry_catalog()
  let s = catalog.resolve(Dataflow, StructureRef::new("DEMO", "FLOW", "1.0"))
  assert_eq(s.reference.format(), "DEMO:DSD(1.0)")
  assert_eq(s.dimensions[0].id, "AREA")
  assert_eq(catalog.references().length(), 1)
  let b = decode_json2_bundle(
    canonical_json(
      action_fixture("Information", Some("1.20")),
      Limits::standard(),
    ),
    catalog=Some(catalog),
  )
  assert_eq(b.items[0].message.dataset.structure.reference, s.reference)
  assert_eq(b.items[0].message.dataset.rows[0].measures, [Some("1.20")])
  assert_true(
    try {
      ignore(
        decode_json2_bundle(
          canonical_json(
            action_fixture("Information", Some("1"), area="OUTSIDE"),
            Limits::standard(),
          ),
          catalog=Some(catalog),
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  let text = canonical_json(registry_fixture(), Limits::standard())
  assert_true(
    try {
      ignore(
        StructureCatalog::from_json2(
          text.replace_all(old="CL_AREA(1.0)", new="MISSING(1.0)"),
        ).resolve(Dataflow, StructureRef::new("DEMO", "FLOW", "1.0")),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        StructureCatalog::from_json2(
          text.replace_all(
            old="\"codes\":[",
            new="\"isPartial\":true,\"codes\":[",
          ),
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(StructureCatalog::from_json2(text, external=[catalog]))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "external registry dependency and unsupported facets fail explicitly" {
  let o = j_object(registry_fixture(), "fixture")
  let d = j_object(o["data"], "data")
  let codes : Json = {
    "meta": o["meta"],
    "data": { "codelists": d["codelists"] },
  }
  let definitions : Json = {
    "meta": o["meta"],
    "data": {
      "dataStructures": d["dataStructures"],
      "dataflows": d["dataflows"],
    },
  }
  let base = StructureCatalog::from_json2(
    canonical_json(codes, Limits::standard()),
  )
  let catalog = StructureCatalog::from_json2(
    canonical_json(definitions, Limits::standard()),
    external=[base],
  )
  assert_eq(
    catalog.resolve(Datastructure, StructureRef::new("DEMO", "DSD", "1.0")).dimensions.length(),
    2,
  )
  let bad = canonical_json(registry_fixture(), Limits::standard()).replace_all(
    old="\"textType\":\"Decimal\"",
    new="\"textType\":\"Decimal\",\"maxLength\":2",
  )
  assert_true(
    try {
      ignore(
        StructureCatalog::from_json2(bad).resolve(
          Dataflow,
          StructureRef::new("DEMO", "FLOW", "1.0"),
        ),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "multi structure dataset indexes and ordered actions roundtrip without conflation" {
  let a = j_object(action_fixture("Append", Some("1")), "fixture")
  let b = j_object(action_fixture("Replace", Some("2"), area="B"), "fixture")
  let ad = j_object(a["data"], "data")
  let bd = j_object(b["data"], "data")
  let second = j_object(j_array(bd["dataSets"], "dataSets")[0], "dataSet").copy()
  second["structure"] = Json::number(1)
  let message : Json = {
    "meta": a["meta"],
    "data": {
      "structures": [
        j_array(ad["structures"], "s")[0],
        j_array(bd["structures"], "s")[0],
      ],
      "dataSets": [j_array(ad["dataSets"], "d")[0], Json::object(second)],
    },
  }
  let bundle = decode_json2_bundle(
    canonical_json(message, Limits::standard()),
    catalog=Some(registry_catalog()),
  )
  assert_eq(bundle.items.length(), 2)
  assert_eq(bundle.items[1].action, Replace)
  assert_eq(bundle.items[1].message.dataset.rows[0].key, ["B", "2026-01"])
  let output = bundle.encode_json2(
    id="out",
    sender="DEMO",
    prepared="2026-11-06T00:00:00Z",
  )
  assert_eq(decode_json2_bundle(output).items[1].action, Replace)
  assert_true(
    try {
      ignore(
        decode_json2_bundle(
          output.replace_all(old="\"structure\":1", new="\"structure\":2"),
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(decode_json2_bundle(output, limits=Limits::new(max_rows=1)))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(bundle.apply(Map([]))["dataflow:DEMO:FLOW(1.0)"].length(), 2)
}

///|
test "full-key actions preserve existing append fields replace delete and rollback" {
  let catalog = registry_catalog()
  let decode = fn(
    action : String,
    value : String?,
  ) -> ExchangeBundle raise SdmxError {
    decode_json2_bundle(
      canonical_json(action_fixture(action, value), Limits::standard()),
      catalog=Some(catalog),
    )
  }
  let state = decode("Append", None).apply(Map([]))
  let filled = decode("Information", Some("1.20")).apply(state)
  let ignored = decode("Append", Some("9")).apply(filled)
  let key = "dataflow:DEMO:FLOW(1.0)"
  assert_eq(ignored[key].rows[0].measures, [Some("1.20")])
  let replaced = decode("Replace", None).apply(ignored)
  assert_eq(replaced[key].rows[0].measures, [None])
  assert_eq(decode("Delete", None).apply(replaced)[key].length(), 0)
  assert_eq(filled[key].rows[0].measures, [Some("1.20")])
  let from = canonical_json(
    action_fixture("Replace", Some("2")),
    Limits::standard(),
  ).replace_all(
    old="\"action\":\"Replace\"",
    new="\"action\":\"Replace\",\"validFrom\":\"2026-01-01\"",
  )
  assert_true(
    try {
      ignore(decode_json2_bundle(from).apply(filled))
      false
    } catch {
      _ => true
    },
  )
  let after = decode_json2_bundle(from).encode_json2(
    id="out",
    sender="DEMO",
    prepared="2026-11-06T00:00:00Z",
  )
  assert_true(after.contains("validFrom"))
  let broken = decode("Append", Some("2"))
  let bad = DataMessage::new(
    Dataflow,
    StructureRef::new("DEMO", "FLOW", "1.0"),
    Dataset::new(total_fixture(), []),
  )
  let transaction = bundle_check(
    [
      broken.items[0],
      { action: Replace, message: bad, valid_from: None, valid_to: None, },
    ],
    Limits::standard(),
  )
  assert_true(
    try {
      ignore(transaction.apply(filled))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(filled[key].rows[0].measures, [Some("1.20")])
}

///|
test "CSV catalog resolution keeps contiguous action order and code validation" {
  let csv = "STRUCTURE,STRUCTURE_ID,ACTION,AREA,TIME_PERIOD,OBS_VALUE,UNIT\r\ndataflow,DEMO:FLOW(1.0),A,A,2026-01,1.20,kWh\r\ndataflow,DEMO:FLOW(1.0),R,A,2026-01,2.30,kWh\r\ndataflow,DEMO:FLOW(1.0),D,A,2026-01,,kWh\r\n"
  let b = decode_csv2_bundle(csv, registry_catalog())
  assert_eq(b.items.length(), 3)
  assert_eq(b.items[0].action, Append)
  assert_eq(b.items[1].action, Replace)
  assert_eq(b.items[2].action, Delete)
  assert_eq(b.apply(Map([]))["dataflow:DEMO:FLOW(1.0)"].length(), 0)
  assert_true(
    try {
      ignore(
        decode_csv2_bundle(
          csv.replace_all(old=",A,2026-01", new=",X,2026-01"),
          registry_catalog(),
        ),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "external validation reorders keys by component identity and bounds action state" {
  let target = registry_catalog().resolve(
    Datastructure,
    StructureRef::new("DEMO", "DSD", "1.0"),
  )
  let source = Structure::new(target.reference, [
    target.dimensions[1],
    target.dimensions[0],
    target.measures[0],
    target.attributes[0],
  ])
  let d = Dataset::new(source, [
    Observation::new(source, ["2026-01", "A"], [Some("1.20")], [Some("kWh")]),
  ])
  assert_eq(d.validate_external(target).rows[0].key, ["A", "2026-01"])
  let b = decode_json2_bundle(
    canonical_json(action_fixture("Replace", Some("1")), Limits::standard()),
    catalog=Some(registry_catalog()),
    limits=Limits::new(max_rows=1),
  )
  let old = Dataset::new(target, [
    Observation::new(target, ["A", "2026-01"], [Some("1")], [Some("kWh")]),
    Observation::new(target, ["A", "2026-02"], [Some("2")], [Some("kWh")]),
  ])
  assert_true(
    try {
      ignore(b.apply(Map([("dataflow:DEMO:FLOW(1.0)", old)])))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(old.length(), 2)
}

///|
test "legacy provider adapter retains uncoded values and action validity with nulls" {
  let legacy : Json = {
    "header": { "id": "provider", "sender": { "id": "DEMO" } },
    "structure": {
      "dimensions": {
        "series": [{ "id": "AREA", "values": [{ "id": "A" }] }],
        "observation": [
          { "id": "TIME_PERIOD", "values": [{ "id": "2026-01" }] },
        ],
      },
      "attributes": {
        "series": [{ "id": "UNIT", "values": [{ "name": "kWh" }] }],
      },
    },
    "dataSets": [
      {
        "action": "Replace",
        "validFrom": "2026-01-01T00:00:00Z",
        "series": {
          "0": { "attributes": [0], "observations": { "0": [null] } },
        },
      },
    ],
  }
  let b = decode_json1_provider(
    canonical_json(legacy, Limits::standard()),
    StructureRef::new("DEMO", "FLOW", "1.0"),
  )
  assert_eq(b.items[0].message.dataset.rows[0].attributes, [Some("kWh")])
  assert_eq(b.items[0].message.dataset.rows[0].measures, [None])
  assert_eq(b.items[0].validity().0, Some("2026-01-01T00:00:00Z"))
  assert_true(
    try {
      ignore(b.apply(Map([])))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "dataset source identity cannot bypass selected external DSD or version checks" {
  let root = j_object(action_fixture("Append", Some("1")), "fixture")
  let data = j_object(root["data"], "data")
  let dataset = j_object(j_array(data["dataSets"], "datasets")[0], "dataset").copy()
  dataset["links"] = Json::array([
    {
      "urn": "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=DEMO:MISSING(1.0)",
      "rel": "dataflow",
    },
  ])
  let document : Json = {
    "meta": root["meta"],
    "data": {
      "structures": data["structures"],
      "dataSets": [Json::object(dataset)],
    },
  }
  let text = canonical_json(document, Limits::standard())
  assert_true(
    try {
      ignore(decode_json2_bundle(text))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(decode_json2_bundle(text, catalog=Some(registry_catalog())))
      false
    } catch {
      _ => true
    },
  )
  let wrong : Json = {
    "meta": {
      "id": "bad",
      "sender": { "id": "DEMO" },
      "schema": "https://json.sdmx.org/2.1.0/sdmx-json-data-schema.json",
    },
    "data": root["data"],
  }
  assert_true(
    try {
      ignore(decode_json2_bundle(canonical_json(wrong, Limits::standard())))
      false
    } catch {
      _ => true
    },
  )
}
