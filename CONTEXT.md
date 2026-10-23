# Statistical data exchange

Observations have meaning through the dimensions that identify them and the metadata that describe them. This context exchanges those observations without losing that meaning.

## Language

**Structure**: The ordered dimensions, measures and attributes that give a family of observations a shared meaning.

**Dimension**: A component of an observation's identity, such as region, indicator or reporting period.

**Measure**: A reported value of the phenomenon identified by the dimensions.

**Attribute**: Descriptive information such as a unit or quality flag; it does not identify an observation.

**Attachment**: The set of dimensions to which one attribute value applies.

**Code list**: An explicit vocabulary of allowed component values, with optional human-readable labels.

**Observation key**: The ordered dimension values that identify exactly one observation within a structure.

**Dataflow**: The identified exchange of observations governed by a structure.

**Snapshot**: A fixed set of observations and their structure, used as the basis for comparison and continuation.

**Revision**: The added observations, withdrawn observations and changed fields between compatible snapshots.

**Local plan**: A set of proposed edits against one snapshot, whose preconditions must hold together.

**Code mapping**: An explicit translation between dimension vocabularies that preserves distinct observation identities.

**Omission**: The absence of a reported value, distinct from a reported zero.
