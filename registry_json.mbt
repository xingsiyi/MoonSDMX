///|
/// Data-access projection of a standard JSON 2.0 StructureMessage. It resolves
/// supplied artefacts only; it never follows remote links or fetches a registry.
pub struct StructureCatalog {
  priv codes : Map[String, CodeList]
  priv dsds : Map[String, Json]
  priv flows : Map[String, String]
  priv concepts : Map[String, Json]
  priv limits : Limits
}

///|
fn artefact_reference(o : Map[String, Json]) -> StructureRef raise SdmxError {
  StructureRef::new(
    j_string(j_required(o, "agencyID"), "agencyID"),
    j_string(j_required(o, "id"), "id"),
    j_optional_string(o, "version", "1.0"),
  )
}

///|
fn urn_reference(
  text : String,
  class_name : String,
) -> StructureRef raise SdmxError {
  let prefix = "urn:sdmx:org.sdmx.infomodel." + class_name + "="
  if !text.has_prefix(prefix) {
    raise Invalid(path="URN", reason="unexpected artefact class")
  }
  StructureRef::parse(text[prefix.length():].to_owned())
}

///|
pub fn StructureCatalog::from_json2(
  text : String,
  external~ : Array[StructureCatalog] = [],
  limits~ : Limits = Limits::standard(),
) -> StructureCatalog raise SdmxError {
  let root = j_object(parse_bounded_json(text, limits), "StructureMessage")
  let meta = j_object(j_required(root, "meta"), "meta")
  let schema = j_string(j_required(meta, "schema"), "schema")
  if !schema.has_suffix("/2.0.0/sdmx-json-structure-schema.json") {
    raise Unsupported(feature="StructureMessage schema must be JSON 2.0.0")
  }
  let data = j_object(j_required(root, "data"), "data")
  let codes : Map[String, CodeList] = Map([])
  let dsds : Map[String, Json] = Map([])
  let flows : Map[String, String] = Map([])
  let concepts : Map[String, Json] = Map([])
  if external.length() > limits.max_columns {
    raise Limit(resource="catalog dependencies", maximum=limits.max_columns)
  }
  let mut count = 0
  let mut code_count = 0
  for catalog in external {
    for key, value in catalog.codes {
      if codes.contains(key) {
        raise Conflict(key~, reason="duplicate external codelist")
      }
      code_count += value.labels.length()
      if code_count > limits.max_codes {
        raise Limit(resource="catalog codes", maximum=limits.max_codes)
      }
      codes[key] = value
    }
    for key, value in catalog.dsds {
      if dsds.contains(key) {
        raise Conflict(key~, reason="duplicate external DSD")
      }
      dsds[key] = value
    }
    for key, value in catalog.flows {
      if flows.contains(key) {
        raise Conflict(key~, reason="duplicate external dataflow")
      }
      flows[key] = value
    }
    for key, value in catalog.concepts {
      if concepts.contains(key) {
        raise Conflict(key~, reason="duplicate external concept")
      }
      concepts[key] = value
    }
    count = codes.length() + dsds.length() + flows.length() + concepts.length()
    if count > limits.max_codes {
      raise Limit(resource="catalog artefacts", maximum=limits.max_codes)
    }
  }
  for raw in json_level(data, "codelists") {
    let o = j_object(raw, "codelist")
    let reference = artefact_reference(o)
    let key = reference.format()
    if j_optional_bool(o, "isExternalReference", false) {
      if !codes.contains(key) {
        raise Invalid(path=key, reason="unresolved external codelist")
      }
      continue
    }
    if j_optional_bool(o, "isPartial", false) {
      raise Unsupported(
        feature="partial codelist cannot serve as authoritative DSD vocabulary",
      )
    }
    if codes.contains(key) {
      raise Conflict(key~, reason="duplicate codelist identity")
    }
    let entries = json_level(o, "codes")
    if entries.length() > limits.max_codes - code_count {
      raise Limit(resource="catalog codes", maximum=limits.max_codes)
    }
    code_count += entries.length()
    codes[key] = CodeList::new(
      reference.id,
      entries.map(v => {
        let c = j_object(v, "code")
        (
          j_string(j_required(c, "id"), "code.id"),
          j_optional_string(c, "name", ""),
        )
      }),
      limits~,
    )
  }
  for raw in json_level(data, "conceptSchemes") {
    let o = j_object(raw, "conceptScheme")
    let reference = artefact_reference(o)
    for concept in json_level(o, "concepts") {
      let c = j_object(concept, "concept")
      let key = reference.format() +
        "." +
        j_string(j_required(c, "id"), "concept.id")
      if concepts.contains(key) {
        raise Conflict(key~, reason="duplicate concept")
      }
      if concepts.length() >= limits.max_codes {
        raise Limit(resource="concepts", maximum=limits.max_codes)
      }
      concepts[key] = concept
    }
  }
  for raw in json_level(data, "dataStructures") {
    let o = j_object(raw, "DSD")
    let key = artefact_reference(o).format()
    if j_optional_bool(o, "isExternalReference", false) {
      if !dsds.contains(key) {
        raise Invalid(path=key, reason="unresolved external DSD")
      }
      continue
    }
    if dsds.contains(key) {
      raise Conflict(key~, reason="duplicate DSD")
    }
    dsds[key] = raw
  }
  for raw in json_level(data, "dataflows") {
    let o = j_object(raw, "dataflow")
    let key = artefact_reference(o).format()
    if j_optional_bool(o, "isExternalReference", false) {
      if !flows.contains(key) {
        raise Invalid(path=key, reason="unresolved external dataflow")
      }
      continue
    }
    if flows.contains(key) {
      raise Conflict(key~, reason="duplicate dataflow")
    }
    flows[key] = urn_reference(
      j_string(j_required(o, "structure"), "dataflow.structure"),
      "datastructure.DataStructure",
    ).format()
  }
  count = codes.length() + dsds.length() + flows.length() + concepts.length()
  if count > limits.max_codes {
    raise Limit(resource="catalog artefacts", maximum=limits.max_codes)
  }
  { codes, dsds, flows, concepts, limits, }
}

///|
pub fn StructureCatalog::references(
  self : StructureCatalog,
) -> Array[StructureRef] raise SdmxError {
  let keys = self.dsds.keys().to_array()
  keys.sort()
  keys.map(StructureRef::parse)
}

///|
fn StructureCatalog::registry_representation(
  self : StructureCatalog,
  o : Map[String, Json],
  fallback : Representation,
) -> Representation raise SdmxError {
  let value = match o.get("localRepresentation") {
    Some(v) => v
    None => {
      let prefix = "urn:sdmx:org.sdmx.infomodel.conceptscheme.Concept="
      let identity = j_optional_string(o, "conceptIdentity", "")
      if !identity.has_prefix(prefix) {
        return fallback
      }
      let key = identity[prefix.length():].to_owned()
      let c = match self.concepts.get(key) {
        Some(v) => j_object(v, "concept")
        None =>
          raise Invalid(
            path=key,
            reason="unresolved concept; supply referenced concept scheme",
          )
      }
      match c.get("coreRepresentation") {
        Some(v) => v
        None => return fallback
      }
    }
  }
  let r = j_object(value, "representation")
  j_known(r, ["enumeration", "format", "enumerationFormat"], "representation")
  if r.contains("enumerationFormat") {
    raise Unsupported(feature="enumerationFormat facets")
  }
  if r.get("enumeration") is Some(v) {
    if r.contains("format") {
      raise Unsupported(feature="enumeration with extra format constraints")
    }
    let reference = urn_reference(
      j_string(v, "enumeration"),
      "codelist.Codelist",
    )
    return match self.codes.get(reference.format()) {
      Some(c) => Coded(c)
      None =>
        raise Invalid(
          path=reference.format(),
          reason="unresolved codelist; supply external StructureMessage",
        )
    }
  }
  if r.get("format") is Some(v) {
    let f = j_object(v, "format")
    // Do not silently drop regex, ranges, length or multiplicity constraints.
    j_known(f, ["textType"], "DSD format")
    return json_format(
      Map([
        ("format", { "dataType": j_optional_string(f, "textType", "String") }),
      ]),
    )
  }
  fallback
}

///|
pub fn StructureCatalog::resolve(
  self : StructureCatalog,
  kind : ExchangeKind,
  reference : StructureRef,
) -> Structure raise SdmxError {
  let key = match kind {
    Datastructure => reference.format()
    Dataflow =>
      match self.flows.get(reference.format()) {
        Some(k) => k
        None =>
          raise Invalid(path=reference.format(), reason="unresolved dataflow")
      }
    Dataprovision =>
      raise Unsupported(feature="provision agreement DSD resolution")
  }
  let raw = match self.dsds.get(key) {
    Some(v) => v
    None => raise Invalid(path=key, reason="unresolved DSD")
  }
  let o = j_object(raw, "DSD")
  let c = j_object(
    j_required(o, "dataStructureComponents"),
    "dataStructureComponents",
  )
  j_known(
    c,
    ["dimensionList", "measureList", "attributeList", "groups"],
    "dataStructureComponents",
  )
  if !json_level(c, "groups").is_empty() {
    raise Unsupported(feature="DSD group descriptors")
  }
  let dl = j_object(j_required(c, "dimensionList"), "dimensionList")
  j_known(
    dl,
    ["id", "name", "names", "links", "dimensions", "timeDimensions"],
    "dimensionList",
  )
  let dimensions = json_level(dl, "dimensions").copy()
  dimensions.append(json_level(dl, "timeDimensions"))
  if dimensions.length() > self.limits.max_columns {
    raise Limit(resource="DSD dimensions", maximum=self.limits.max_columns)
  }
  let positioned : Array[(Int32, Component)] = dimensions.map(v => {
    let d = j_object(v, "dimension")
    let id = j_string(j_required(d, "id"), "dimension.id")
    let is_time = id == "TIME_PERIOD" ||
      j_optional_string(d, "type", "") == "TimeDimension" ||
      json_level(dl, "timeDimensions").contains(v)
    let role : Role = if is_time { TimeDimension } else { Dimension }
    let representation = self.registry_representation(
      d,
      if is_time {
        Period
      } else {
        Text
      },
    )
    if is_time && !(representation is Period) {
      raise Unsupported(
        feature="time dimension representation is not a supported period",
      )
    }
    (
      j_int(
        j_required(d, "position"),
        "dimension.position",
        self.limits.max_columns,
      ),
      Component::new(
        id,
        role,
        representation,
        name=j_optional_string(d, "name", ""),
      ),
    )
  })
  positioned.sort_by((a, b) => a.0.compare(b.0))
  let components : Array[Component] = []
  for i, p in positioned {
    if p.0 != i + 1 {
      raise Invalid(
        path="DSD position",
        reason="expected unique contiguous positions starting at 1",
      )
    }
    components.push(p.1)
  }
  let ml = j_object(j_required(c, "measureList"), "measureList")
  let measures = json_level(ml, "measures").copy()
  if ml.get("primaryMeasure") is Some(v) {
    if !measures.is_empty() {
      raise Invalid(path="measureList", reason="multiple forms")
    }
    measures.push(v)
  }
  for v in measures {
    let d = j_object(v, "measure")
    components.push(
      Component::new(
        j_string(j_required(d, "id"), "measure.id"),
        Measure,
        self.registry_representation(d, Decimal),
      ),
    )
  }
  let names = positioned.map(p => p.1.id)
  if c.get("attributeList") is Some(v) {
    let al = j_object(v, "attributeList")
    for v in json_level(al, "attributes") {
      let d = j_object(v, "attribute")
      let status = j_optional_string(d, "assignmentStatus", "Conditional")
      if status != "Conditional" && status != "Mandatory" {
        raise Unsupported(feature="attribute assignmentStatus")
      }
      components.push(
        Component::new(
          j_string(j_required(d, "id"), "attribute.id"),
          json_relationship(j_required(d, "attributeRelationship"), names),
          self.registry_representation(d, Text),
          required=j_optional_string(d, "assignmentStatus", "Conditional") ==
            "Mandatory",
        ),
      )
    }
  }
  Structure::new(StructureRef::parse(key), components, limits=self.limits)
}
