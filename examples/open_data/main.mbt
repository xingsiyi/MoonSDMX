///|
fn main raise {
  // Original synthetic dissemination response: one dataset dimension, one series dimension.
  let response : Json = {
    "meta": {
      "id": "open-data",
      "prepared": "2026-10-23T00:00:00Z",
      "sender": { "id": "DEMO" },
    },
    "data": {
      "structures": [
        {
          "links": [
            {
              "urn": "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=DEMO:LABOUR(1.0)",
              "rel": "dataflow",
            },
          ],
          "dimensions": {
            "dataSet": [
              {
                "id": "FREQ",
                "keyPosition": 0,
                "values": [{ "id": "M", "name": "Monthly" }],
              },
            ],
            "series": [
              {
                "id": "REGION",
                "keyPosition": 1,
                "values": [
                  { "id": "N", "name": "North" },
                  { "id": "S", "name": "South" },
                ],
              },
            ],
            "observation": [
              {
                "id": "PERIOD",
                "roles": ["TIME_PERIOD"],
                "keyPosition": 2,
                "values": [
                  { "id": "2026-01", "name": "January" },
                  { "id": "2026-02", "name": "February" },
                ],
              },
            ],
          },
          "attributes": {
            "dataSet": [
              {
                "id": "UNIT",
                "relationship": { "dataflow": {} },
                "values": [{ "id": "PCT", "name": "Percent" }],
                "default": "PCT",
              },
            ],
            "observation": [
              {
                "id": "STATUS",
                "relationship": { "observation": {} },
                "values": [{ "id": "E", "name": "Estimated" }],
              },
            ],
          },
          "annotations": [
            { "id": "PROVISIONAL", "text": "Synthetic provisional series" },
          ],
        },
      ],
      "dataSets": [
        {
          "series": {
            "0": {
              "annotations": [0],
              "observations": { "0": [0, 0], "1": [null] },
            },
            "1": { "observations": { "0": [4.25], "1": [4.00, 0] } },
          },
        },
      ],
    },
  }
  let message = @sdmx.decode_json2(response.stringify())
  let data = message.dataset()
  assert_eq(data.structure().time_index(), Some(2))
  data.validate_frequency("FREQ")
  assert_eq(data.get(["M", "N", "2026-01"]).unwrap().measures()[0], Some("0"))
  assert_eq(data.get(["M", "N", "2026-02"]).unwrap().measures()[0], None)
  assert_eq(message.annotations_for(["M", "N", "2026-01"]).length(), 1)
  let selected = data.select(
    @sdmx.Selection::new(data.structure(), [("REGION", ["N"])]),
  )
  assert_eq(selected.length(), 2)
  let january = selected.periods_contained(
    @sdmx.PeriodWindow::new(
      @sdmx.PeriodValue::parse("2026-01"),
      @sdmx.PeriodValue::parse("2026-01"),
    ),
  )
  assert_eq(january.length(), 1)
  let refused = try {
    ignore(message.encode_csv2())
    false
  } catch {
    _ => true
  }
  assert_true(refused)
  let restored = @sdmx.decode_json2(
    message.encode_json2(
      id="dashboard",
      sender="DEMO",
      prepared="2026-10-23T00:00:00Z",
    ),
  )
  assert_eq(
    restored.dataset().sorted().observations(),
    data.sorted().observations(),
  )
  println(
    "open-data: 4 observations, null/zero preserved, time role recognized, inherited unit and notes preserved; January North = 0 PCT",
  )
}
