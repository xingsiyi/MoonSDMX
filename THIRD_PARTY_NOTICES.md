# Sources and dependencies

MoonSDMX is an independent implementation of a documented SDMX data profile, not a source-code port.
The SDMX Technical Working Group specifications are format references:

- https://github.com/sdmx-twg/sdmx-csv (SDMX-CSV data messages)
- https://github.com/sdmx-twg/sdmx-json (SDMX-JSON data messages)
- https://github.com/sdmx-twg/sdmx-im (information model)
- https://www.rfc-editor.org/rfc/rfc4180 (CSV quoting)

No reference implementation source or real personal/statistical records is copied.
Tests and examples use original synthetic observations. Normative specifications remain under their respective rights.
MoonBit core and `moonbitlang/x@0.4.49` declare Apache-2.0 and are consumed as dependencies; they are not vendored or included in source scale.

Compiler-generated `pkg.generated.mbti` interfaces are committed for API review
but excluded from source counts. AI tools assisted implementation and validation;
separate AI assistance and contest-review materials remain outside Git.
Official schemas and samples used for independent validation are not redistributed
as this project's own fixtures. All committed test data is original synthetic data.

The optional Windows compiler path adapter in `scripts/` reuses this workspace's
original auxiliary adapter from MoonProcessLens, under MIT. It is build support only;
no prior project's production MoonBit code or history is reused.
