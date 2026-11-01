# MoonSDMX 十一月功能扩展

指标数值脱离地区、期间、单位和质量状态就无法安全使用。项目在JSON/CSV语法之上保留SDMX维度与属性附着语义，新增分区整合和明确分组的精确汇总，让公共数据、部门KPI和科研数据可以复核地进入MoonBit应用。

## 1. 结构一致的分区合并

`Dataset::merge_partition`：校验结构契约后按完整观测键合并；重叠键默认拒绝，仅显式allow_identical时允许值和属性完全相同的记录。合并后再次检查全体属性附着一致性，失败不改变输入。

复杂度与代价：除结构序列化与文本成本外预期O(N·C)时间和空间；不把该本地操作当作SDMX服务端Append/Replace。

## 2. 保留单位与缺值的精确分组汇总

`Dataset::grouped_totals`：仅允许指定Decimal/Integer度量；按选定维度、全部属性和报告期频率分组，输出reported/missing和可选精确十进制总和，不混加不同单位/质量/频率，不把全缺失当零。

复杂度与代价：预期O(N·(C+小数位数))，分组及文本空间有现有数据预算；溢出报错，不自动汇率/单位转换。可加性和重复期间是否可汇总由业务决定。

## 运行

```sh
moon run examples/november --target native --deny-warn
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
```

Windows当前工具链路径问题沿用README的项目适配脚本；源代码临时命名空间尚未发布。

## 范围

不实现完整Registry/XML/HTTP服务，不自动处理单位换算、统计估计或所有指标的可加性；分组汇总是本地分析辅助，不宣称某指标的官方统计口径。

现有四后端与10,000观测示例；新增重叠/附着冲突、精确小数、单位频率隔离与全缺值测试。 具体当前执行结果由本地检查记录提供，不以CI配置代替远端成功记录。
