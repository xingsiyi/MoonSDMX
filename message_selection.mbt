///|
/// Apply a DSD-bound selection and retain annotations used by selected rows.
pub fn DataMessage::select(
  self : DataMessage,
  selection : Selection,
) -> DataMessage raise SdmxError {
  let dataset = self.dataset.select(selection)
  let notes : Array[Annotation] = []
  let reindex : Map[Int32, Int32] = Map([])
  let bindings : Map[String, Array[Int32]] = Map([])
  for row in dataset.rows {
    let token = row.key_token()
    if self.row_notes.get(token) is Some(indices) {
      let selected = indices.map(i => {
        match reindex.get(i) {
          Some(index) => index
          None => {
            let index = notes.length()
            reindex[i] = index
            notes.push(self.notes[i])
            index
          }
        }
      })
      bindings[token] = selected
    }
  }
  { ..self, dataset, notes, row_notes: bindings, }
}
