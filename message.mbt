///|
pub(all) enum ExchangeKind {
  Dataflow
  Datastructure
  Dataprovision
} derive(Eq, @debug.Debug)

///|
pub extend ExchangeKind with Eq::{equal, not_equal}

///|
pub extend ExchangeKind with @debug.Debug::{to_repr}

///|
pub fn ExchangeKind::format(self : ExchangeKind) -> String {
  match self {
    Dataflow => "dataflow"
    Datastructure => "datastructure"
    Dataprovision => "dataprovision"
  }
}

///|
pub fn ExchangeKind::parse(text : String) -> ExchangeKind raise SdmxError {
  match text {
    "dataflow" => Dataflow
    "datastructure" => Datastructure
    "dataprovision" => Dataprovision
    _ => raise Unsupported(feature="structure type: \{text}")
  }
}

///|
/// A dissemination message. Mutating SDMX actions are deliberately not applied.
pub struct DataMessage {
  priv kind : ExchangeKind
  priv reference : StructureRef
  priv dataset : Dataset
  priv notes : Array[Annotation]
  priv row_notes : Map[String, Array[Int32]]
} derive(@debug.Debug)

///|
pub extend DataMessage with @debug.Debug::{to_repr}

///|
pub fn DataMessage::new(
  kind : ExchangeKind,
  reference : StructureRef,
  dataset : Dataset,
) -> DataMessage raise SdmxError {
  if kind is Datastructure && reference != dataset.structure.reference {
    raise Invalid(
      path="message.reference",
      reason="DSD reference does not match structure",
    )
  }
  { kind, reference, dataset, notes: [], row_notes: Map([]), }
}

///|
pub fn DataMessage::kind(self : DataMessage) -> ExchangeKind {
  self.kind
}

///|
pub fn DataMessage::reference(self : DataMessage) -> StructureRef {
  self.reference
}

///|
pub fn DataMessage::dataset(self : DataMessage) -> Dataset {
  self.dataset
}
