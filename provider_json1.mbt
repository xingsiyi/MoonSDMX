///|
/// Explicit legacy-provider adapter, not a JSON 2.0 conformance claim.
/// The host supplies the verified dataflow reference; no URL is trusted/fetched.
pub fn decode_json1_provider(
  text : String,
  reference : StructureRef,
  limits~ : Limits = Limits::standard(),
) -> ExchangeBundle raise SdmxError {
  let root = j_object(parse_bounded_json(text, limits), "legacy data message")
  if root.contains("errors") {
    raise Unsupported(feature="provider error message")
  }
  let header = j_object(j_required(root, "header"), "header")
  let structure = j_object(j_required(root, "structure"), "structure")
  let dim = j_object(j_required(structure, "dimensions"), "dimensions")
  j_known(dim, ["dataSet", "series", "observation"], "legacy dimensions")
  let converted_dims : Map[String, Json] = Map([])
  let dimension_names : Array[String] = []
  let series_names : Array[String] = []
  let mut position = 0
  for level in ["dataSet", "series", "observation"] {
    let values : Array[Json] = []
    for raw in json_level(dim, level) {
      let c = j_object(raw, "dimension").copy()
      let id = j_string(j_required(c, "id"), "id")
      dimension_names.push(id)
      if level != "observation" {
        series_names.push(id)
      }
      if c.get("keyPosition") is Some(p) {
        if j_int(p, "keyPosition", limits.max_columns) != position {
          raise Unsupported(feature="legacy non-contiguous dimension ordering")
        }
      }
      c["keyPosition"] = Json::number(position.to_double())
      position += 1
      if position > limits.max_columns {
        raise Limit(resource="legacy dimensions", maximum=limits.max_columns)
      }
      if id == "TIME_PERIOD" || j_optional_string(c, "role", "") == "time" {
        c["roles"] = Json::array([Json::string("TIME_PERIOD")])
      }
      values.push(Json::object(c))
    }
    converted_dims[level] = Json::array(values)
  }
  let attrs = match structure.get("attributes") {
    Some(v) => j_object(v, "attributes")
    None => Map([])
  }
  j_known(attrs, ["dataSet", "series", "observation"], "legacy attributes")
  let converted_attrs : Map[String, Json] = Map([])
  for level in ["dataSet", "series", "observation"] {
    let values : Array[Json] = []
    for raw in json_level(attrs, level) {
      let c = j_object(raw, "attribute").copy()
      let dictionary : Array[Json] = []
      for raw in json_level(c, "values") {
        let value = j_object(raw, "attribute dictionary").copy()
        if !value.contains("id") && !value.contains("value") {
          value["value"] = Json::string(
            j_string(j_required(value, "name"), "uncoded provider value"),
          )
        }
        dictionary.push(Json::object(value))
      }
      c["values"] = Json::array(dictionary)
      c["relationship"] = if level == "dataSet" {
        { "dataflow": {} }
      } else if level == "series" {
        { "dimensions": series_names }
      } else {
        { "observation": {} }
      }
      values.push(Json::object(c))
    }
    converted_attrs[level] = Json::array(values)
  }
  let urn = "urn:sdmx:org.sdmx.infomodel.datastructure.Dataflow=" +
    reference.format()
  let embedded : Json = {
    "links": [{ "urn": urn, "rel": "dataflow" }],
    "dimensions": Json::object(converted_dims),
    "attributes": Json::object(converted_attrs),
  }
  let document : Json = {
    "meta": {
      "schema": "https://json.sdmx.org/2.0.0/sdmx-json-data-schema.json",
      "id": j_string(j_required(header, "id"), "header.id"),
      "sender": j_required(header, "sender"),
    },
    "data": {
      "structures": [embedded],
      "dataSets": j_required(root, "dataSets"),
    },
  }
  decode_json2_bundle(canonical_json(document, limits), limits~)
}
