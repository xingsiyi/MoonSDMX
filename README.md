# MoonSDMX

**MoonBit 原生的结构感知多维数据交换库。** 在 JSON/CSV 与图表、分析和导入管道之间，保留“维度键—观测值—单位—质量状态—附着范围”的含义。

例如，两个部门都提交 `120`，只有结合地区、指标、报告期、单位和质量标记才能使用。MoonSDMX 读取明确受限的 **SDMX-CSV 2.0.0 / SDMX-JSON Data Message 2.0.0**，展开索引与继承属性，校验代码表及完整键，提供选择、重编码、修订比较和稳定分页。核心独立使用 MoonBit 实现，无 Python/Java/JS 计算绑定。

## 当前状态

版本 `0.1.0`，模块 `xingsiyi/moonsdmx`，MIT 许可证；[公开仓库](https://github.com/xingsiyi/MoonSDMX) · [Mooncakes](https://mooncakes.io/docs/xingsiyi/moonsdmx) · [Linux/Windows CI](https://github.com/xingsiyi/MoonSDMX/actions)。CI 固定 compiler/core 0.10.16+b1a0e846e。

## 标准接入增量（本地未发布）

针对外部数据源接入，新增标准 **JSON 2.0 StructureMessage 的 DSD／代码表投影解析**、
外部概念与代码表依赖解析、**多结构／多数据集顺序容器**、完整观测键下的 **A/R/D/I 动作处理**。
新增 `decode_json1_provider` 显式适配 ECB 实际返回的 JSON1.0，保留动作及有效时间限定。
新功能需使用当前源码，已发布 0.1.0 不包含这些 API。

- [功能兼容矩阵、DSD 接入步骤与真实提供方验证](docs/INTEROPERABILITY.md)
- `moon run examples/standard_exchange --target native --deny-warn`：标准 DSD/代码表 → 两种不同结构 → CSV2/JSON2 往返 → 顺序应用动作。
- `python scripts/verify_standard_exchange.py CLI`：离线验证标准输入与多数据集。
- `python scripts/verify_provider.py CLI`：下载并逐字段核对真实 ECB 响应；`--file RAW_FILE` 可离线复放。

StructureMessage 是明确范围的数据校验投影，不是完整 Registry 实现；完整动作语义、
通配键删除、复杂 DSD facets 和 SDMX-ML 结构导入仍有明确边界，详见兼容矩阵。

## 能力与生态价值

| 能力 | 解决的问题 |
|---|---|
| 结构校验 | 代码表、有序维度、完整键、重复项、必需值及附着属性一致性 |
| 结构感知交换 | CSV 列重排；JSON dataset/series/observation 索引与 keyPosition、多度量、默认及继承属性、注释 |
| 精确值模型 | 缺值与零分开、保留原小数文本、有界精确十进制、报告期区间 |
| 安全转换 | 维度选择、期间查询、保持身份的重排、全代码域无碰撞映射、保留必需元数据的投影 |
| 修订及计划 | 新增/撤回/逐字段修改；全快照前置条件和最终一致性校验的显式本地编辑 |
| 分页与覆盖 | 内容绑定 keyset 游标；缺值、未出现代码及频率分析，不暗中合并不同单位 |

通用 DataFrame/CSV 库提供行列处理；本库增加 SDMX 语义解释，并可将结果交给这些库。它与本地纠删恢复、时间数据库、事件模式及流程发现项目具有不同核心。选题核查截至 2026-10-22：检索官方 3,226 模块目录、GitHub 近邻及本地 20 个项目，未发现相同 SDMX 核心；这是有范围的检索结论。

## 构建与运行

验证环境：`moonc v0.10.16`、`moon 0.1.20261016`；仅依赖 core 和 `moonbitlang/x@0.4.49`。

```sh
moon update
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run --target native examples/open_data
moon run --target native examples/department_kpi
moon run --target native examples/research_revision
moon run --target native examples/energy_catalog
moon run --target native --release examples/scale
```

Windows v0.10.16 扩展驱动器路径问题可用 `./scripts/Invoke-Moon.ps1 test --target all --deny-warn` 等同等命令。辅助脚本仅规范化安装的编译器/格式化器路径参数，不修改全局工具链。其他版本优先正常 `moon` 命令。

## API 示例

在已有 MoonBit 工程中安装：

```sh
moon add xingsiyi/moonsdmx@0.1.0
```

在使用方 `moon.pkg` 中配置 `import { "xingsiyi/moonsdmx" @sdmx, }`。以下代码可放在 `fn main raise { ... }` 内运行：

```moonbit
let structure = @sdmx.Structure::new(
  @sdmx.StructureRef::new("DEMO", "METRICS", "1.0"), [
    @sdmx.Component::new("REGION", @sdmx.Dimension, @sdmx.Text),
    @sdmx.Component::new("TIME_PERIOD", @sdmx.TimeDimension, @sdmx.Period),
    @sdmx.Component::new("OBS_VALUE", @sdmx.Measure, @sdmx.Decimal),
    @sdmx.Component::new("UNIT", @sdmx.Attribute(["REGION"]), @sdmx.Text, required=true),
  ],
)
let row = @sdmx.Observation::new(
  structure, ["N", "2026-01"], [Some("1.2300")], [Some("kWh")],
)
let data = @sdmx.Dataset::new(structure, [row])
let message = @sdmx.DataMessage::new(@sdmx.Datastructure, structure.reference(), data)
let json = message.encode_json2(id="demo", sender="DEMO", prepared="2026-10-23T00:00:00Z")
let restored = @sdmx.decode_json2(json, expected=Some(structure))
assert_eq(restored.dataset().fingerprint(), data.fingerprint())
```

接口见 `pkg.generated.mbti`，完整用法见 `examples/`。`Structure::from_profile_json` 使用本项目的 `moonsdmx.structure/1` 配置格式，是本地配置格式；标准 JSON2 StructureMessage 改用 `StructureCatalog::from_json2`，支持的 DSD 投影范围见兼容矩阵。

## 四个完整场景

| 场景 | 实际结果与失败路径 | 示例 |
|---|---|---|
| 开放数据到仪表盘 | 三层维度展开、单位与注释继承、地区和月份筛选、null 与零保留；注释不能静默丢到 CSV | `examples/open_data` |
| 部门 KPI 交换 | 共享 DSD 及代码表，接受不同列顺序，拒绝未知部门和附着单位冲突 | `examples/department_kpi` |
| 研究修订复核 | 1 新增、1 撤回、2 修订；null→0 及状态变化；过期计划拒绝，旧快照不变 | `examples/research_revision` |
| 能源环境目录迁移 | 全代码域重编码、保留 kWh/MWh 和月/季粒度、两页遍历、过期游标拒绝、覆盖缺口 | `examples/energy_catalog` |

`examples/scale` 验证 10,000 条观测的 JSON 交换、内容指纹一致和 79 页遍历，并断言 1,429 个缺值保留。elapsed_ms 为本机端到端墙钟观测，包含模型、编解码、排序/哈希及分页，不是跨机器性能承诺。

## 本地 CLI

CLI 承诺 native 运行；仅读取显式文件，不跟随远程链接：

```sh
moon run --target native cmd/moonsdmx -- json2csv MESSAGE.json
moon run --target native cmd/moonsdmx -- json2csv --drop-annotations MESSAGE.json
moon run --target native cmd/moonsdmx -- extract-structure MESSAGE.json
moon run --target native cmd/moonsdmx -- validate-csv STRUCTURE.json DATA.csv
moon run --target native cmd/moonsdmx -- csv2json STRUCTURE.json DATA.csv msg DEMO 2026-10-23T00:00:00Z
moon run --target native cmd/moonsdmx -- reencode-json2 MESSAGE.json msg DEMO 2026-10-23T00:00:00Z
```

末尾增加 `--output NEW_PATH` 输出精确 UTF-8，已有路径拒绝；完整验证后才写入。它不是并发文件系统事务，宿主应避免竞争写同一路径。stdout 适于交互查看；保存含换行字段的精确 CSV 应使用文件输出。

## 保证与边界

[支持范围](docs/PROFILE.md) 列出具体拒绝项。原有单消息 API 保持 Information 语义；新增 bundle API 保留 A/R/D/I，并由宿主显式调用纯函数 `apply` 处理完整观测键，按序暂存且失败不改原状态。有效时间限定、注释及通配/部分键等不支持自动应用的形式会明确拒绝。指纹和游标用于变化检测，不是身份认证。宿主负责授权、并发和持久化事务、业务冲突及单位转换。

设 N 行、C 组件、D 维度、K 代码、P 页长，忽略字符串长度：构造/验证及转换约 O(NC)，索引 O(N)；确定性排序/指纹增加 O(N log N)；分页快照 O(N log N·D)，续页 O(log N·D+PC)；重编码还需 O(K log K) 域核查。字符与哈希处理按文本长度收费。输入、展开总文本、字段、代码、行列、注释引用及输出均有上限；完整结果占 O(NC) 内存。

## 验证与维护

测试覆盖结构/代码域/附着关系、CSV 引号及截断、JSON 索引/默认/继承/null、独立整数 oracle 小数比较、日历边界、注释转换、预算、映射碰撞、游标失效、计划原子性及修订。官方固定 JSON 2.0 Schema 和三种官方样本另在 Git 外完成完整键、值、属性及注释对照；未将其冒作原创数据。

`scripts/verify_repository.py` 检查 >4,000 行有效生产 MoonBit、>30 条非空提交及私有材料不进入历史；排除测试、示例和生成接口。Linux/Windows CI 覆盖四后端检查/构建/测试、格式/接口、六个场景和打包卫生；独立官方样本验证与格式边界见支持范围，配置本身不替代执行结果。来源与许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。


## 十一月新增功能

**结构一致的分区合并**（`Dataset::merge_partition`）；**保留单位与缺值的精确分组汇总**（`Dataset::grouped_totals`）。详见[功能、用途和边界](docs/NOVEMBER_FEATURES.md)，运行 `moon run examples/november --target native --deny-warn`。功能已包含于0.1.0，安装方式见上文。


## 本地开发增量（未发布）

新增 **保留语义的指标透视表**、**显式缺期补全**，用途、限制和复杂度见 [功能文档](docs/EXPANSION_20261106.md)。
从本仓库源码运行 `moon run examples/expansion --target native --deny-warn`。
本节 API 尚未包含在已发布的 0.1.0 中。
