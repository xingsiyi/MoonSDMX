# SDMX interoperability contracts (MoonSDMX 2.0.0, 2026-11-06)

Project version `2.0.0` extends the earlier `0.1.0` single-message profile.
GitHub release `v2.0.0` corresponds to Mooncakes module `0.2.0` under the registry's `0.x.y` version policy. These release versions are distinct from SDMX wire-format versions. This document distinguishes decoding a standard
message, projecting metadata for data validation, and applying actions to state.

## Version and feature matrix

| Feature | JSON Data 2.0.0 | CSV 2.0.0 | JSON Structure 2.0.0 / provider adapter |
|---|---|---|---|
| Single Information exchange | existing `decode_json2` | existing `decode_csv2` with explicit DSD | native local profile remains available |
| Ordered multiple datasets / different schemas | **new** `decode_json2_bundle`, each structure index validated | **new** `decode_csv2_bundle`, contiguous source/action groups | resolve each source through supplied catalog |
| External standard DSD and codelists | **new** catalog validation by component identity | **new** catalog resolves STRUCTURE/STRUCTURE_ID | **new** `StructureCatalog::from_json2` data-access projection |
| Dataset/series/observation dimensions and attributes | existing indexed expansion and attachment checks | scalar columns, labels=id, comma | ordered DSD dimensions, time dimension, measures, attributes |
| A/R/D/I actions | **new** parse, preserve, encode; full-key application | **new** parse, preserve; full-key application | full-key bounded semantics below; not complete storage protocol |
| Validity qualifiers | validFrom/validTo retained and exposed | not represented by this CSV profile | automatic application refused for qualified actions |
| Annotations | existing supported binding dictionary retained in bundle roundtrip | explicit dropping still required | annotated actions require annotation-aware host; automatic application refused |
| Partial/wildcard keys, grouped deletes, measure-specific actions | rejected | rejected | planned; not full data-action semantics |
| Full metadata fidelity / Registry API | no | no | no: metadata is projected, not a full registry persistence model |
| Legacy real provider JSON 1.0 | separate `decode_json1_provider` | n/a | explicit adapter; never counted as native 2.0 evidence |
| JSON/CSV 2.1 / SDMX-ML StructureMessage | not implemented | not implemented | explicit scope boundary |

Fixed primary specifications: [JSON 2.0.0](https://github.com/sdmx-twg/sdmx-json/tree/71fe5eaa9fcd29e3c15f2f0216a19b9b650b1dbd)
and [CSV 2.0.0](https://github.com/sdmx-twg/sdmx-csv/tree/3f8211f1c2ecfb83b8033d586fb6acc598773c74).
Official schemas are published at [json.sdmx.org](https://json.sdmx.org/).
Scope restrictions and unsupported facets remain in [PROFILE](PROFILE.md).

## External DSD / codelist integration

The host obtains a standard JSON 2.0 StructureMessage from its provider/registry.
Pass its text directly to `StructureCatalog::from_json2`. Multiple artefacts are
indexed by **agency + ID + version**, not bare ID. The `external` parameter accepts
previous catalogs containing referenced codelists, concept schemes or DSDs; links
are never fetched automatically. Duplicate identities, missing references and
partial codelists used as authoritative vocabularies are rejected.

The supported DSD projection reads `dataStructureComponents.dimensionList`
(`dimensions`/`timeDimensions`, contiguous 1-based position), measureList
(`primaryMeasure` or `measures`) and attributeList with explicit relationships.
Local representations or supplied concept core representations resolve coded
enumerations through full codelist URNs; scalar textType maps to the documented
text/numeric/calendar profile. Mandatory/conditional attributes are validated.
Dataflows resolve their `structure` DSD URN. Provision agreement resolution is not
implemented. Unused DSDs are parsed only when resolved: loading a catalog is not
a claim that every artefact can be executed by this data model.

Full multilingual/hierarchical metadata, constraints, group descriptors,
enumeration format facets, regex, min/max/length and multiplicity constraints are
outside the executable projection. Unsupported **representation** facets fail
on resolution rather than being silently weakened. Other artefact collections
(categories, organisations, constraints, etc.) and descriptive metadata are not
retained by the projection; do not use it to roundtrip a registry message.
SDMX-ML XML ingestion and arbitrary HTTP registry access remain host concerns.

For standard JSON data with `catalog=Some(catalog)`, dataflow/DSD links choose the
external contract. The decoded dataset is reordered by **component ID**, then
validated against DSD domains, required components and attachment scopes. Extra
unknown components and role conflicts fail. Missing optional components become
missing values; required values must exist. Message dictionaries are vocabulary
indexes only, not proof of full codelist membership. Without an external DSD the
inferred validation structure reference must not be labelled an authoritative DSD.
If dataset and embedded-layout source links differ, external resolution must
prove they use the same DSD; otherwise the input is rejected. Dataset identities
are retained rather than silently replaced by the layout's source link.

```sh
moon run cmd/moonsdmx --target native -- registry-dsd examples/data/registry-json2.json 'DEMO:DSD(1.0)'
# Separate external dependencies can be supplied as a standard message:
moon run cmd/moonsdmx --target native -- registry-dsd DEFINITIONS.json 'AGENCY:DSD(VERSION)' CODELISTS_AND_CONCEPTS.json
moon run cmd/moonsdmx --target native -- inspect-bundle DATA.json REGISTRY.json
moon run cmd/moonsdmx --target native -- validate-registry-csv REGISTRY.json DATA.csv
moon run examples/standard_exchange --target native --deny-warn
```

The synthetic `examples/data/registry-json2.json` contains **two different DSDs**
(one time-series key and one area-only key), their dataflows, concepts and codelist.
It conforms to the pinned official StructureMessage schema; no private profile
file is required at the CLI entry point.

## Ordered datasets and actions

`ExchangeBundle::datasets()` retains source order and actions. `encode_json2`
preserves observations, annotations, source identity, action and validity fields,
while emitting a canonical layout; it does not reproduce all header/publication
metadata or original physical grouping. Aggregate rows and expanded value text
are bounded across all datasets, not just each dataset. Structures and dataset
counts are bounded by max_columns (default 128). All structure indexes, including
malformed unused layouts, are checked. Returned container arrays are detached.

`ExchangeBundle::apply(current)` returns a new map keyed by
`kind.format() + ":" + reference.format()`. Explicit application means a host
has chosen to update its local state. With **complete typed observation keys**:

- Append fills fields that were missing and adds new keys; existing values win.
- Replace replaces complete keyed observations, including missing fields, and
  adds new keys. It does not clear unrelated keys.
- Delete removes exact supplied keys; absent keys are idempotently ignored.
- Information uses Append when explicitly applied, matching the transmission
  intention described in the fixed specification. Decoding alone mutates nothing.

The entire ordered call stages results; a later schema/budget/attachment conflict
returns no state changes. All affected states are revalidated under the call's
limits. No network/database writes, authorization, locking or durable transaction
are performed. ValidFrom/validTo-qualified actions and annotations are refused
by automatic application, while decoding preserves them. Delete currently uses
normal typed rows; key-only deletion against DSDs with required measures, partial
series deletes and wildcard scope are not implemented. The caller must not infer
that all standard action forms are supported from the enum names alone.

For CSV, equal consecutive source/action rows form one dataset. Different
structures can share a union header; columns outside a particular DSD must be
empty. Header-only messages cannot resolve an implicit source in the bundle API;
the original single-message API with explicit DSD handles that case.

## Real-provider file and independent validation

The live [ECB data API](https://data.ecb.europa.eu/help/api/data) was queried for
monthly USD/EUR exchange rates, January–March 2025:

`https://data-api.ecb.europa.eu/service/data/EXR/M.USD.EUR.SP00.A?startPeriod=2025-01&endPeriod=2025-03&format=jsondata`

The checked response was **SDMX-JSON 1.0.0-wd**, with Replace and validFrom;
therefore `decode_json1_provider(text, verified_flow_reference)` is an explicit
adapter. It covers dataset/series/observation dictionaries, scalar implicit
OBS_VALUE, uncoded name-only attribute values, full keys and action validity.
It does not interpret arbitrary legacy dialects, fiscal calendars, descriptive
time-bound metadata or full provider DSDs. The host supplies/validates dataflow
identity; the adapter does not authenticate arbitrary hyperlinks.

`scripts/verify_provider.py` independently flattens the raw provider file and
compares **every key, measure, attribute, missing value, action and validity**
with CLI results, then compares the normalized JSON2 roundtrip. Actual raw file,
URL, content type (when downloaded), SHA256, UTC check time and detailed evidence
stay under ignored `_local/provider-interop`. No provider data is redistributed
as original synthetic fixtures. This provider case does **not** claim authoritative
external DSD validation or native JSON2 provider compatibility.

```sh
python scripts/verify_standard_exchange.py _build/native/debug/build/cmd/moonsdmx/moonsdmx.exe
# Optional: independently check official schemas from a pinned checkout.
python scripts/verify_standard_exchange.py CLI --schemas PATH_TO_PINNED_SDMX_JSON_REPO
# Live download, or use --file PATH_TO_UNMODIFIED_ECB_RESPONSE for offline replay.
python scripts/verify_provider.py _build/native/debug/build/cmd/moonsdmx/moonsdmx.exe
```

The offline standard test separately checks the two-DSD StructureMessage,
external codelist/concept dependency resolution, three ordered datasets/actions,
JSON2/CSV2 parity, canonical output, unresolved references and bad indexes.
Official StructureMessage/DataMessage schema checks cover synthetic input and
encoded output. They complement actual provider evidence; neither substitutes
for testing a provider's complete version/DSD combination.

## Complexity and next compatibility work

Catalog indexing is expected O(artefact/code text); DSD resolution and external
component alignment are bounded by component count (some lookups O(C²)). A bundle
reuses the verified single-message decoder on each selected layout; repeated
serialization/layout checks cost O(sum(selected layout text + decoded data))
plus cumulative aggregate checks bounded by dataset count. Full-key action work
is expected O(sum(affected stored rows + incoming rows + field validation));
map copies and schema revalidation add retained-state/metadata cost. Host state
size, parser nodes, expanded text and work are not a process memory guarantee.

Next priorities: execute more DSD facets with retained constraints; support
group/measure-specific attachment and key-only/wildcard deletes through a typed
selector model; then validate another provider's native JSON2/CSV2 with its
authoritative full DSD. Implementations must include independent provider files,
all-value comparisons and refusal cases before broadening the matrix.
