///|
fn main raise {
  let catalog = @sdmx.StructureCatalog::from_json2(
    "{\"meta\":{\"schema\":\"https://json.sdmx.org/2.0.0/sdmx-json-structure-schema.json\",\"id\":\"registry-demo\",\"sender\":{\"id\":\"DEMO\"},\"prepared\":\"2026-11-06T00:00:00Z\"},\"data\":{\"codelists\":[{\"id\":\"CL_AREA\",\"agencyID\":\"DEMO\",\"version\":\"1.0\",\"codes\":[{\"id\":\"A\",\"name\":\"A\",\"names\":{\"en\":\"A\"}},{\"id\":\"B\",\"name\":\"B\",\"names\":{\"en\":\"B\"}}],\"name\":\"CL_AREA\",\"names\":{\"en\":\"CL_AREA\"}}],\"conceptSchemes\":[{\"id\":\"CONCEPTS\",\"agencyID\":\"DEMO\",\"version\":\"1.0\",\"concepts\":[{\"id\":\"AREA\",\"name\":\"AREA\",\"names\":{\"en\":\"AREA\"}},{\"id\":\"TIME_PERIOD\",\"name\":\"TIME_PERIOD\",\"names\":{\"en\":\"TIME_PERIOD\"}},{\"id\":\"UNIT\",\"name\":\"UNIT\",\"names\":{\"en\":\"UNIT\"}},{\"id\":\"OBS_VALUE\",\"name\":\"OBS_VALUE\",\"names\":{\"en\":\"OBS_VALUE\"}}],\"name\":\"CONCEPTS\",\"names\":{\"en\":\"CONCEPTS\"}}],\"dataStructures\":[{\"id\":\"DSD\",\"agencyID\":\"DEMO\",\"version\":\"1.0\",\"dataStructureComponents\":{\"dimensionList\":{\"id\":\"DimensionDescriptor\",\"dimensions\":[{\"id\":\"AREA\",\"position\":1,\"localRepresentation\":{\"enumeration\":\"urn:sdmx:org.sdmx.infomodel.codelist.Codelist=DEMO:CL_AREA(1.0)\"},\"conceptIdentity\":\"urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=DEMO:CONCEPTS(1.0).AREA\"}],\"timeDimensions\":[{\"id\":\"TIME_PERIOD\",\"position\":2,\"localRepresentation\":{\"format\":{\"textType\":\"ObservationalTimePeriod\"}},\"conceptIdentity\":\"urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=DEMO:CONCEPTS(1.0).TIME_PERIOD\"}]},\"measureList\":{\"id\":\"MeasureDescriptor\",\"primaryMeasure\":{\"id\":\"OBS_VALUE\",\"localRepresentation\":{\"format\":{\"textType\":\"Decimal\"}},\"conceptIdentity\":\"urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=DEMO:CONCEPTS(1.0).OBS_VALUE\"}},\"attributeList\":{\"id\":\"AttributeDescriptor\",\"attributes\":[{\"id\":\"UNIT\",\"assignmentStatus\":\"Conditional\",\"attributeRelationship\":{\"dimensions\":[\"AREA\"]},\"localRepresentation\":{\"format\":{\"textType\":\"String\"}},\"conceptIdentity\":\"urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=DEMO:CONCEPTS(1.0).UNIT\"}]}},\"name\":\"DSD\",\"names\":{\"en\":\"DSD\"}},{\"id\":\"DSD_ALT\",\"agencyID\":\"DEMO\",\"version\":\"1.0\",\"dataStructureComponents\":{\"dimensionList\":{\"id\":\"DimensionDescriptor\",\"dimensions\":[{\"id\":\"AREA\",\"position\":1,\"localRepresentation\":{\"enumeration\":\"urn:sdmx:org.sdmx.infomodel.codelist.Codelist=DEMO:CL_AREA(1.0)\"},\"conceptIdentity\":\"urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=DEMO:CONCEPTS(1.0).AREA\"}],\"timeDimensions\":[]},\"measureList\":{\"id\":\"MeasureDescriptor\",\"primaryMeasure\":{\"id\":\"OBS_VALUE\",\"localRepresentation\":{\"format\":{\"textType\":\"Decimal\"}},\"conceptIdentity\":\"urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=DEMO:CONCEPTS(1.0).OBS_VALUE\"}},\"attributeList\":{\"id\":\"AttributeDescriptor\",\"attributes\":[{\"id\":\"UNIT\",\"assignmentStatus\":\"Conditional\",\"attributeRelationship\":{\"dimensions\":[\"AREA\"]},\"localRepresentation\":{\"format\":{\"textType\":\"String\"}},\"conceptIdentity\":\"urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept=DEMO:CONCEPTS(1.0).UNIT\"}]}},\"name\":\"Alternate structure\",\"names\":{\"en\":\"Alternate structure\"}}],\"dataflows\":[{\"id\":\"FLOW\",\"agencyID\":\"DEMO\",\"version\":\"1.0\",\"structure\":\"urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=DEMO:DSD(1.0)\",\"name\":\"FLOW\",\"names\":{\"en\":\"FLOW\"}},{\"id\":\"FLOW_ALT\",\"agencyID\":\"DEMO\",\"version\":\"1.0\",\"structure\":\"urn:sdmx:org.sdmx.infomodel.datastructure.DataStructure=DEMO:DSD_ALT(1.0)\",\"name\":\"FLOW_ALT\",\"names\":{\"en\":\"FLOW_ALT\"}}]}}",
  )
  let csv = "STRUCTURE,STRUCTURE_ID,ACTION,AREA,TIME_PERIOD,OBS_VALUE,UNIT\r\ndataflow,DEMO:FLOW(1.0),A,A,2026-01,1.20,kWh\r\ndataflow,DEMO:FLOW(1.0),R,A,2026-01,2.30,kWh\r\ndataflow,DEMO:FLOW_ALT(1.0),I,B,,9.00,kWh\r\n"
  let bundle = @sdmx.decode_csv2_bundle(csv, catalog)
  assert_eq(bundle.datasets().length(), 3)
  let normalized = bundle.encode_json2(
    id="example",
    sender="DEMO",
    prepared="2026-11-06T00:00:00Z",
  )
  let result = @sdmx.decode_json2_bundle(normalized, catalog=Some(catalog)).apply(
    Map([]),
  )
  assert_eq(result["dataflow:DEMO:FLOW(1.0)"].observations()[0].measures(), [
    Some("2.30"),
  ])
  assert_eq(result["dataflow:DEMO:FLOW_ALT(1.0)"].observations()[0].key(), ["B"])
  println(
    "Standard DSD/codelist resolution, distinct schema datasets and ordered actions retain exact values",
  )
}
