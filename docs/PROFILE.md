# Supported exchange profile

This implementation targets the fixed SDMX 3.0 data exchange specifications:

- SDMX-CSV **2.0.0**, [reference commit 3f8211f](https://github.com/sdmx-twg/sdmx-csv/tree/3f8211f1c2ecfb83b8033d586fb6acc598773c74).
- SDMX-JSON Data Message **2.0.0**, [reference commit 71fe5ea](https://github.com/sdmx-twg/sdmx-json/tree/71fe5eaa9fcd29e3c15f2f0216a19b9b650b1dbd).

The current upstream specifications also have 2.1 editions. Their added semantics
are outside this profile. This library does not claim complete SDMX conformance.

## API scopes (MoonSDMX 2.0.0)

The original `decode_json2` / `decode_csv2` APIs below retain their single
Information-message contracts. New `decode_json2_bundle`, `decode_csv2_bundle`,
`StructureCatalog::from_json2` and the explicit legacy provider adapter extend
that baseline. See [the version/feature matrix](INTEROPERABILITY.md) for standard
DSD/codelist integration, multiple datasets and bounded action semantics.
These APIs are included in GitHub release v2.0.0 / Mooncakes module 0.2.0;
module 0.1.0 is the earlier baseline.

## Common model

The original single-message APIs use one identified structure and dataset; complete observation keys;
scalar text, exact bounded decimal, integer, calendar-period and coded values;
multiple measures; attributes attached to dataset/dataflow scope, a dimension
combination, or the whole observation. A code list in a native structure is an
authoritative allowed vocabulary. A dictionary inferred from an input JSON message
is only that message's vocabulary: validate against an external structure when a
full DSD is available. Component order must match when supplying that structure.

Omission is `None`; zero is `Some("0")`. Original scalar spelling is retained.
Decimal arithmetic is explicit, bounded to 18 fractional digits and a coefficient
magnitude of 9,000,000,000,000,000,000; it never silently rounds into a float.
Dictionary expansion is bounded by the decoded dataset text budget as well as
input text, field length, rows, columns and code counts.

## CSV

Comma separator, labels=id, scalar flat observations, mandatory
`STRUCTURE,STRUCTURE_ID` prefix. `ACTION` is optional and defaults to Information;
an explicit action must occupy the third column and equal `I`. Component columns
may be reordered. Omitted measure/attribute columns become omitted values.
Output uses canonical dimension/measure/attribute order and CRLF record endings.

Other separators, label modes, custom columns, multilingual or multi-valued
components, nested reference metadata, partial/wildcard keys, and mutating
`A/R/D` actions are explicitly rejected. No server-side update is performed.
CSV cannot represent the supported JSON annotation bindings; annotated messages
must call `without_annotations()` explicitly before conversion.

## JSON

`meta/data/structures/dataSets` version 2.0 envelope; indexed dataset, series and
observation dimensions; complete `keyPosition` order; explicit measures or the
legacy implicit `OBS_VALUE`; coded/indexed and direct scalar values; dataset and
series attributes inherited into observations; explicit attribute defaults;
observation annotations, including inherited series/dataset references.

Time dimensions are recognized by the `TIME_PERIOD` identifier, a supported time
format, or the `TIME_PERIOD` role. JSON output uses a deterministic flat layout,
declares measure representations, emits source links at structure and dataset
levels, and requires an explicit UTC prepared timestamp. It keeps the values,
attachment relationships and supported annotations; it does not reproduce the
original physical layout or descriptive metadata verbatim.

The original single-message API accepts Information only. Its multiple structures/datasets, error
messages, dimensionGroup attributes, measure-specific attribute attachments,
multi-valued/localized values, unsupported format facets, component annotations
and component-value annotations are rejected. Descriptive links and display-only
metadata are not fetched or retained. Calendar bounds are computed using the
documented calendar profile, rather than trusting remote links or a custom fiscal
calendar. Use full-registry tools when their broader metadata fidelity is needed.

## Calendar and local transformations

Gregorian years 0001–9999, `YYYY`, `YYYY-S1/S2`, `YYYY-Q1..Q4`, `YYYY-MM`,
`YYYY-MM-DD`, with a Jan-1 reporting year. ISO/reporting weeks, custom fiscal
years, date-times, and arbitrary time-range periods are unsupported. Intervals
are half-open civil-day ranges; overlap and containment are separate queries.

The local revision/plan API keeps its own merge-present, replace and delete-exact semantics.
The new ExchangeBundle applies supported full-key SDMX actions through a separate
explicit pure-function API; full wildcard/group/measure-specific action forms remain unsupported.
Authentication, registry lookups, HTTP, persistence transactions, conflict policy,
unit conversion and statistical estimation belong to the host application.
