///|
/// An annotation object is retained as bounded canonical JSON, without fetching URLs.
pub struct Annotation {
  priv content : String
} derive(Eq, @debug.Debug)

///|
pub extend Annotation with Eq::{equal, not_equal}

///|
pub extend Annotation with @debug.Debug::{to_repr}

///|
pub fn Annotation::from_json(
  text : String,
  limits~ : Limits = Limits::standard(),
) -> Annotation raise SdmxError {
  let value = parse_bounded_json(text, limits)
  ignore(j_object(value, "annotation"))
  { content: canonical_json(value, limits), }
}

///|
pub fn Annotation::to_json(self : Annotation) -> String {
  self.content
}

///|
pub fn DataMessage::annotations(self : DataMessage) -> Array[Annotation] {
  self.notes.copy()
}

///|
pub fn DataMessage::annotations_for(
  self : DataMessage,
  key : Array[String],
) -> Array[Annotation] raise SdmxError {
  if self.dataset.get(key) is None {
    raise Invalid(path="annotation key", reason="observation does not exist")
  }
  match self.row_notes.get(framed_key(key)) {
    None => []
    Some(indices) => indices.map(i => self.notes[i])
  }
}

///|
pub fn DataMessage::with_annotations(
  self : DataMessage,
  notes : Array[Annotation],
  bindings : Array[(Array[String], Array[Int32])],
) -> DataMessage raise SdmxError {
  let limits = self.dataset.structure.limits
  if notes.length() > limits.max_codes {
    raise Limit(resource="annotations", maximum=limits.max_codes)
  }
  let mut units = 0
  for note in notes {
    if units > limits.max_text - note.content.length() {
      raise Limit(resource="annotation text", maximum=limits.max_text)
    }
    units += note.content.length()
  }
  if bindings.length() > self.dataset.rows.length() {
    raise Invalid(
      path="annotation bindings",
      reason="more bindings than observations",
    )
  }
  let mapping : Map[String, Array[Int32]] = Map([])
  let mut references = 0
  for (key, indices) in bindings {
    if self.dataset.get(key) is None {
      raise Invalid(path="annotation key", reason="observation does not exist")
    }
    let token = framed_key(key)
    if mapping.contains(token) {
      raise Invalid(path="annotation bindings", reason="duplicate key")
    }
    if indices.length() > 1024 {
      raise Limit(resource="annotations per observation", maximum=1024)
    }
    references += indices.length()
    if references > 1000000 {
      raise Limit(resource="annotation references", maximum=1000000)
    }
    let seen : Map[Int32, Bool] = Map([])
    for index in indices {
      if index < 0 || index >= notes.length() {
        raise Invalid(path="annotation index", reason="out of range")
      }
      if seen.contains(index) {
        raise Invalid(path="annotation index", reason="duplicate reference")
      }
      seen[index] = true
    }
    mapping[token] = indices.copy()
  }
  { ..self, notes: notes.copy(), row_notes: mapping, }
}

///|
pub fn DataMessage::without_annotations(self : DataMessage) -> DataMessage {
  { ..self, notes: [], row_notes: Map([]), }
}
