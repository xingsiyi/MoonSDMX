# Changelog

## 0.2.0 — 2026-11-06

- Add standard JSON2 StructureMessage data-access projection and external DSD/codelist/concept resolution, with authoritative value validation by component identity.
- Add ordered multi-structure/dataset JSON2 and CSV2 containers, preserved A/R/D/I and validity, bounded atomic full-key application.
- Add explicit legacy provider adapter, real ECB all-value replay verification, official-schema checked synthetic standard inputs, CLI and runnable integration example.
- Publish the API/version compatibility matrix and explicit unsupported action/DSD semantics.

- 保留语义的指标透视表。
- 显式缺期补全。
- 增加回归测试、独立可运行示例与 CI 示例步骤；详见 docs/EXPANSION_20261106.md。

## 0.1.0 — 2026-11-01

- 结构一致的分区合并：Dataset::merge_partition
- 保留单位与缺值的精确分组汇总：Dataset::grouped_totals
- 增加边界回归、可运行集成示例和CI步骤。

### Initial development — 2026-10-23

- Independent structures, representations, code lists and attachment validation.
- Bounded CSV2/JSON2 Information exchange with indexed expansion and annotations.
- Exact decimals and explicit calendar reporting-period queries.
- Dimension selection, identity-preserving reorder, coded migration and projection.
- Snapshot-bound pagination, field-level revisions and atomic local editing plans.
- Coverage diagnostics, native conversion CLI and four complete scenarios.
- Source/history hygiene and configured four-backend CI.

Public namespace: xingsiyi/moonsdmx; fixed compiler/core version, Linux/Windows CI and local package exclusion checks.
