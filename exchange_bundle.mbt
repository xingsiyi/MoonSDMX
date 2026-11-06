///|
pub(all) enum DataAction {
  Information
  Append
  Replace
  Delete
} derive(Eq, @debug.Debug)

///|
pub extend DataAction with Eq::{equal, not_equal}

///|
pub extend DataAction with @debug.Debug::{to_repr}

///|
pub fn DataAction::parse(text : String) -> DataAction raise SdmxError {
  match text {
    "Information" | "I" => Information
    "Append" | "A" => Append
    "Replace" | "R" => Replace
    "Delete" | "D" => Delete
    _ => raise Invalid(path="action", reason="unknown SDMX data action")
  }
}

///|
pub fn DataAction::format(self : DataAction) -> String {
  match self {
    Information => "Information"
    Append => "Append"
    Replace => "Replace"
    Delete => "Delete"
  }
}

///|
pub struct ExchangeDataset {
  priv action : DataAction
  priv message : DataMessage
  priv valid_from : String?
  priv valid_to : String?
}

///|
pub fn ExchangeDataset::action(self : ExchangeDataset) -> DataAction {
  self.action
}

///|
pub fn ExchangeDataset::message(self : ExchangeDataset) -> DataMessage {
  self.message
}

///|
pub fn ExchangeDataset::validity(self : ExchangeDataset) -> (String?, String?) {
  (self.valid_from, self.valid_to)
}

///|
pub struct ExchangeBundle {
  priv items : Array[ExchangeDataset]
  priv limits : Limits
}

///|
pub fn ExchangeBundle::datasets(
  self : ExchangeBundle,
) -> Array[ExchangeDataset] {
  self.items.copy()
}

///|
/// Validate external DSD by component identity instead of wire attribute order.
pub fn Dataset::validate_external(
  self : Dataset,
  expected : Structure,
) -> Dataset raise SdmxError {
  let source = self.structure
  for c in source.components() {
    let target = match expected.component(c.id) {
      Some(t) => t
      None =>
        raise Invalid(path=c.id, reason="component absent from external DSD")
    }
    let compatible = match (c.role, target.role) {
      (Dimension, Dimension)
      | (TimeDimension, TimeDimension)
      | (Measure, Measure) => true
      (Attribute(a), Attribute(b)) => {
        let x = a.copy()
        let y = b.copy()
        x.sort()
        y.sort()
        x == y
      }
      _ => false
    }
    if !compatible {
      raise Invalid(
        path=c.id,
        reason="DSD component role or attachment differs",
      )
    }
  }
  for c in expected.dimensions {
    if source.dimension_index(c.id) is None {
      raise Invalid(path=c.id, reason="missing DSD dimension")
    }
  }
  fn select(
    values : Array[String?],
    from : Array[Component],
    into : Array[Component],
  ) -> Array[String?] {
    into.map(c => {
      let mut found : String? = None
      for i, s in from {
        if s.id == c.id {
          found = values[i]
          break
        }
      }
      found
    })
  }
  let rows = self.rows.map(row => {
    Observation::new(
      expected,
      expected.dimensions.map(c => {
        row.key[source.dimension_index(c.id).unwrap()]
      }),
      select(row.measures, source.measures, expected.measures),
      select(row.attributes, source.attributes, expected.attributes),
    )
  })
  Dataset::new(expected, rows)
}

///|
fn bundle_check(
  items : Array[ExchangeDataset],
  limits : Limits,
) -> ExchangeBundle raise SdmxError {
  if items.length() > limits.max_columns {
    raise Limit(resource="message data sets", maximum=limits.max_columns)
  }
  let mut rows = 0
  let mut text = 0
  for item in items {
    if item.message.dataset.rows.length() > limits.max_rows - rows {
      raise Limit(resource="bundle rows", maximum=limits.max_rows)
    }
    rows += item.message.dataset.rows.length()
    for row in item.message.dataset.rows {
      for value in row.key {
        if value.length() > limits.max_text - text {
          raise Limit(resource="bundle expanded text", maximum=limits.max_text)
        }
        text += value.length()
      }
      for group in [row.measures, row.attributes] {
        for value in group {
          if value is Some(s) {
            if s.length() > limits.max_text - text {
              raise Limit(
                resource="bundle expanded text",
                maximum=limits.max_text,
              )
            }
            text += s.length()
          }
        }
      }
    }
  }
  { items, limits, }
}

///|
/// Decode ordered SDMX 2.0 datasets, resolving each index and optional external DSD.
pub fn decode_json2_bundle(
  text : String,
  catalog~ : StructureCatalog? = None,
  limits~ : Limits = Limits::standard(),
) -> ExchangeBundle raise SdmxError {
  let root = j_object(parse_bounded_json(text, limits), "message")
  if root.contains("errors") {
    raise Unsupported(feature="error message")
  }
  let meta = j_object(j_required(root, "meta"), "meta")
  ignore(j_string(j_required(meta, "id"), "meta.id"))
  ignore(j_object(j_required(meta, "sender"), "meta.sender"))
  if meta.get("schema") is Some(v) &&
    !j_string(v, "schema").has_suffix("/2.0.0/sdmx-json-data-schema.json") {
    raise Unsupported(feature="bundle requires SDMX-JSON Data 2.0.0")
  }
  let data = j_object(j_required(root, "data"), "data")
  let structures = j_array(j_required(data, "structures"), "structures")
  let datasets = j_array(j_required(data, "dataSets"), "dataSets")
  if structures.is_empty() ||
    structures.length() > limits.max_columns ||
    datasets.length() > limits.max_columns {
    raise Limit(
      resource="bundle structures/datasets",
      maximum=limits.max_columns,
    )
  }
  let expected = structures.map(v => {
    match catalog {
      None => None
      Some(c) => {
        let (kind, reference) = json_exchange_reference(
          j_object(v, "embedded structure"),
        )
        Some(c.resolve(kind, reference))
      }
    }
  })
  // Reject malformed unused layouts too, not merely selected dataset indexes.
  for i, v in structures {
    ignore(json_layout(v, None, limits))
    ignore(expected[i])
  }
  let items : Array[ExchangeDataset] = []
  for raw in datasets {
    let dataset = j_object(raw, "dataSet").copy()
    let index = match dataset.get("structure") {
      Some(v) => j_int(v, "dataSet.structure", structures.length() - 1)
      None => 0
    }
    let action = DataAction::parse(
      j_optional_string(dataset, "action", "Information"),
    )
    let (source_kind, source_reference) = json_exchange_reference(
      j_object(structures[index], "structure"),
    )
    let (dataset_kind, dataset_reference) = if dataset.contains("links") {
      json_exchange_reference(dataset)
    } else {
      (source_kind, source_reference)
    }
    if dataset_kind != source_kind || dataset_reference != source_reference {
      match catalog {
        Some(c) =>
          if c.resolve(dataset_kind, dataset_reference).reference !=
            expected[index].unwrap().reference {
            raise Conflict(
              key=dataset_reference.format(),
              reason="dataset source DSD differs from selected structure",
            )
          }
        None =>
          raise Unsupported(
            feature="different dataset/structure source identities require external DSD resolution",
          )
      }
    }
    dataset["structure"] = Json::number(0)
    dataset["action"] = Json::string("Information")
    let single : Json = {
      "meta": Json::object(meta),
      "data": {
        "structures": [structures[index]],
        "dataSets": [Json::object(dataset)],
      },
    }
    let original = decode_json2(canonical_json(single, limits), limits~)
    let message : DataMessage = {
      ..original,
      kind: dataset_kind,
      reference: dataset_reference,
    }
    let message = match expected[index] {
      None => message
      Some(s) => {
        let validated = message.dataset.validate_external(s)
        let changed = DataMessage::new(
          message.kind,
          message.reference,
          validated,
        )
        // Keys can be reordered by the DSD. Rebind notes to the validated keys.
        let bindings : Array[(Array[String], Array[Int32])] = []
        for i, row in message.dataset.rows {
          if message.row_notes.get(row.key_token()) is Some(notes) {
            bindings.push((validated.rows[i].key, notes))
          }
        }
        changed.with_annotations(message.notes, bindings)
      }
    }
    let valid_from = match dataset.get("validFrom") {
      Some(v) => Some(j_string(v, "validFrom"))
      None => None
    }
    let valid_to = match dataset.get("validTo") {
      Some(v) => Some(j_string(v, "validTo"))
      None => None
    }
    items.push({ action, message, valid_from, valid_to, })
    ignore(bundle_check(items, limits))
  }
  bundle_check(items, limits)
}

///|
pub fn ExchangeBundle::encode_json2(
  self : ExchangeBundle,
  id~ : String,
  sender~ : String,
  prepared~ : String,
) -> String raise SdmxError {
  let structures : Array[Json] = []
  let datasets : Array[Json] = []
  let mut meta : Json = Json::null()
  for i, item in self.items {
    let root = j_object(
      parse_bounded_json(
        item.message.encode_json2(id~, sender~, prepared~),
        self.limits,
      ),
      "message",
    )
    meta = root["meta"]
    let data = j_object(root["data"], "data")
    structures.push(j_array(data["structures"], "structures")[0])
    let dataset = j_object(j_array(data["dataSets"], "dataSets")[0], "dataSet").copy()
    dataset["structure"] = Json::number(i.to_double())
    dataset["action"] = Json::string(item.action.format())
    if item.valid_from is Some(v) {
      dataset["validFrom"] = Json::string(v)
    }
    if item.valid_to is Some(v) {
      dataset["validTo"] = Json::string(v)
    }
    datasets.push(Json::object(dataset))
  }
  if self.items.is_empty() {
    raise Invalid(path="bundle", reason="cannot encode an empty exchange")
  }
  canonical_json(
    { "meta": meta, "data": { "structures": structures, "dataSets": datasets } },
    self.limits,
  )
}

///|
/// Pure full-key action application in dataset order. Information means Append.
/// No wildcards/partial keys or remote writes. Failure leaves all inputs intact.
pub fn ExchangeBundle::apply(
  self : ExchangeBundle,
  current : Map[String, Dataset],
) -> Map[String, Dataset] raise SdmxError {
  let staged = current.copy()
  for item in self.items {
    if item.valid_from is Some(_) || item.valid_to is Some(_) {
      raise Unsupported(
        feature="time-qualified action application; host must handle validFrom/validTo",
      )
    }
    let m = item.message
    if !m.notes.is_empty() {
      raise Unsupported(
        feature="action application with annotations requires an annotation-aware host",
      )
    }
    let key = m.kind.format() + ":" + m.reference.format()
    let bounded = Structure::new(
      m.dataset.structure.reference,
      m.dataset.structure.components(),
      limits=self.limits,
    )
    let incoming = m.dataset.validate_with(bounded)
    let old = staged
      .get(key)
      .unwrap_or_else(() => Dataset::new(incoming.structure, []))
      .validate_with(bounded)
    if old.structure.to_profile_json() != incoming.structure.to_profile_json() {
      raise Conflict(key~, reason="stored DSD contract differs")
    }
    let rows : Array[Observation] = []
    for row in old.rows {
      match incoming.index.get(row.key_token()) {
        None => rows.push(row)
        Some(i) =>
          match item.action {
            Delete => ()
            Replace => rows.push(incoming.rows[i])
            Append | Information => {
              let next = incoming.rows[i]
              rows.push(
                Observation::new(
                  old.structure,
                  row.key,
                  row.measures.mapi((i, v) => {
                    if v is Some(_) {
                      v
                    } else {
                      next.measures[i]
                    }
                  }),
                  row.attributes.mapi((i, v) => {
                    if v is Some(_) {
                      v
                    } else {
                      next.attributes[i]
                    }
                  }),
                ),
              )
            }
          }
      }
    }
    if item.action != Delete {
      for row in incoming.rows {
        if !old.index.contains(row.key_token()) {
          if rows.length() >= self.limits.max_rows {
            raise Limit(
              resource="action result rows",
              maximum=self.limits.max_rows,
            )
          }
          rows.push(row)
        }
      }
    }
    staged[key] = Dataset::new(incoming.structure, rows)
  }
  staged
}
