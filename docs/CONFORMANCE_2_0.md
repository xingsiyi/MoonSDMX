# MoonSDMX 的 SDMX 2.0.0 符合性目标

最终交付目标是 **完整读写 SDMX-JSON 2.0.0 和 SDMX-CSV 2.0.0 Data Message，并完整接入其所依赖的 SDMX-JSON 2.0.0 结构与参考元数据语义**。结构和参考元数据保留原消息的可公开交换字段，并支持本地解析、引用解析、验证和标准格式导出。标准版本以 [JSON 2.0.0 固定规范](https://github.com/sdmx-twg/sdmx-json/tree/71fe5eaa9fcd29e3c15f2f0216a19b9b650b1dbd)和 [CSV 2.0.0 固定规范](https://github.com/sdmx-twg/sdmx-csv/tree/3f8211f1c2ecfb83b8033d586fb6acc598773c74)为准。参考元数据包括 Data Message 携带的元数据属性，以及配套的 JSON／CSV 2.0.0 Metadata Message；JSON Structure Message 的结构制品、引用和扩展字段也纳入完整验收。交付形态为本地可嵌入的 MoonBit 编解码、语义验证与快照应用库。SDMX-ML、2.1.0 和 REST 服务端属于独立标准或部署项。

## 完成判定

| 验收范围 | 最终验收条件 | 本轮复审实现 |
| --- | --- | --- |
| JSON Data Message | 覆盖 2.0.0 规范字段与合法布局，含无度量、仅属性、局部键、默认与哨兵值、注释及制品引用、多语言和多值、错误与可扩展字段。双向编解码后语义与规范一致 | 覆盖标量且绑定到现有观测的组属性，可读写部分键和适用度量，支持字典索引或直接值 |
| CSV Data Message | 覆盖结构引用、部件和键列、按规范允许的列编排、部分键、分隔符与媒体参数、多值、多语言、嵌套参考元数据和各动作标记。结合源 DSD 判定语义，与 JSON 能表达的公共信息做双向对照 | 支持标量 Information 消息中部分键属性行与完整观测行混传，回写为标准的重复属性列 |
| Structure 与 Metadata Message | 保留并验证制品内容、版本和引用，涵盖 dataflow、DSD、MSD、provision agreement、表示类型及约束、代码层级、可选维度、分组和多度量关系。完成标准结构和参考元数据的读写及往返 | 从现有 JSON Structure 读取路径解析固定维度组以及属性的独立度量关系，CSV 与 JSON 数据使用同一 DSD 判定 |
| 数据动作 | 按规范精确表达并在内存快照中验证 A/R/D/I、作用域、遗漏或清除、部分或通配键、按度量或属性更新及有效期。每种动作以执行前后快照为证据 | 保留既有完整键动作路径，部分键组属性当前用于 Information 交换 |
| 验收证据 | 建立到规范章节和字段的逐条测试矩阵。固定官方 schema 与样例，配合独立生产者文件验证合法输入、往返语义及非法值拒绝。Native、JS、Wasm、Wasm-GC 全通过后再声明完整符合性 | 已把本页用例加入跨平台测试与标准交换验证脚本。官方 JSON schema 检查消息形状，预期输出验证结构和数据的关联语义 |

迁移顺序为组值的独立存储及注释、复杂表示和元数据、标准动作与制品往返、完整交叉测试。当前仍需完成无匹配观测的组、组注释、可选维度、多值及其他矩阵缺口。对目标编码无标准表示的转换，应保留原始格式或返回明确的不可表示错误。结构属性以语义等价为准，元素排序、字典索引和 CSV 转义允许按规范重新编码。

## 标准输入和预期输出

- [JSON Structure Message](../examples/data/attachment-structure.json) 定义 \`AreaGroup → AREA\`。\`POWER_UNIT\` 和 \`ENERGY_UNIT\` 都依赖该组，但分别适用于 \`POWER\` 和 \`ENERGY\`。\`QUALITY\` 随完整观测键变化，只适用于 \`ENERGY\`。
- [JSON Data Message](../examples/data/attachment-data.json) 使用 \`dimensionGroupAttributes\`。完整的维度位置按 \`keyPosition\` 排列，\`0:\` 表示 \`AREA=A\`，时间位置留空。\`[0,"kWh"]\` 的 \`0\` 是功率单位字典的 \`kW\`，第二项是直接值。
- [CSV Data Message](../examples/data/attachment-data.csv) 在只有 \`AREA\` 的行提供 \`POWER_UNIT\` 和 \`ENERGY_UNIT\`。三条完整观测行留空单位列。地区 B 的组行位于其观测之后，读取仍按部分键匹配。CSV 的适用度量由外部 DSD 定义。
- [预期输出](../examples/data/attachment-expected.json) 展示按度量使用属性时的结果。该文件是业务语义断言，标准回写仍使用 JSON Data Message 或 CSV Data Message。

| AREA / TIME_PERIOD | POWER | ENERGY | QUALITY 的适用范围 |
| --- | --- | --- | --- |
| A / 2026-01 | 12.50 kW | 300.00 kWh | P，仅 ENERGY |
| A / 2026-02 | 13.00 kW | 310.00 kWh | E，仅 ENERGY |
| B / 2026-01 | 0.50 MW | 5.00 MWh | P，仅 ENERGY |

组值先按属性各自的维度投影建索引，再匹配观测键。相同组键遇到冲突值会失败。若外部 DSD 将单位绑定在另一度量，校验报错。消费者可用 \`Observation::attributes_for_measure\` 获取某度量的单位与质量。JSON 回写以每个部分键一条记录输出组值，CSV 回写将同一组值重复到匹配的完整观测行。结构组名保存在 DSD 和内部结构中，JSON Data Message 以实际维度标识表达其关系。

设 R 为观测行数，G 为组键数，A 为参与处理的属性数，D 为维度数。JSON 附着解析的上界为 O((R+G)·A·D)，其中哈希查找视为均摊常数。索引额外空间按实际属性赋值、投影键长度和展开后的结果计算。无需对每条观测逐一扫描所有组键。原有文本与行数预算继续约束输入及展开。

## 复现

\`\`\`sh
moon build --target native --deny-warn
python scripts/verify_standard_exchange.py _build/native/debug/build/cmd/moonsdmx/moonsdmx.exe
\`\`\`

上面的验证脚本也支持 \`--schemas PATH\`，传入固定提交的官方 JSON 规范检出目录，并安装 Python \`jsonschema\`。脚本验证两种输入产生同一输出，检查 JSON 与 CSV 重写，拒绝组键掩码错误、越界索引、冲突值和与 DSD 不一致的适用度量。Python 只用于测试。
