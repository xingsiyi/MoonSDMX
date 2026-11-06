# MoonSDMX 增量功能：2026-11-06

状态：本地未发布增量。使用本目录源码运行，已发布的 0.1.0 不包含本页新增 API。

## 保留语义的指标透视表与显式缺期补全
`Dataset::pivot_measure(measure, column_dimension)` 将一个维度展开为列，其余维度作为完整行键。
按首次出现顺序保留行/列，保留原始十进制文本和每个观测的全部属性，返回 attribute_names 解释属性顺序。
None cell 表示不存在观测；Some(PivotCell{value:None,...}) 表示观测已报告、指标缺失；"0.00" 保持原样。
不求和、不换算单位。列数最多 max_columns，行列乘积最多 max_rows，分配稠密矩阵前检查。

`Dataset::densify_periods(periods, attributes)` 仅为已存在序列补齐显式指定的缺失期间，
返回新 Dataset 与 inserted_keys。保留全部旧观测及请求范围之外的期间；新指标均为 None，不插零、不插值。
调用方必须明确提供新观测属性；最终重新验证全部 attachment 约束，不推断单位或质量标记。
要求 TimeDimension，输入与请求同频，期间不重复；拒绝非法期间、必填指标/属性缺失、跨序列附着属性冲突。
混合单位的序列应先分组调用并明确各自属性。没有序列的空数据不会凭空生成序列。
series×requested-period 工作量最多 max_rows，总行数/文本也受 Limits 限制。

用于开放统计数据展示、部门 KPI 报表、研究时间序列对齐和能耗统计质量检查。
补齐后的缺失不是实际测量值，inserted_keys 应随审计过程保留。

透视期望时间 O(N*D+R*C)，空间 O(R*C+N*A)，D 为维度数、A 为属性数；
补期时间 O(N*D+S*P*D+输出重验证)，空间 O(新增键与观测+新 Dataset)，均有显式规模预算。
测试含缺观测/缺值/零区别、原始小数与单位、返回数组隔离、频率/附着冲突、空数据及预算拒绝。

## 运行

```sh
moon run examples/expansion --target native --deny-warn
moon test --target all --deny-warn
```

Windows 使用 README 中对应的 Moon 包装脚本替代 `moon`。
CI 已添加该示例；无需网络服务、私钥或真实设备。
