# Herdr 实现与交付审核

- 日期：2026-10-09；批次 add-herdr 修订 1，用户 U3 已批准。
- 初审：独立子代理 review_herdr_implementation；二次审核：另一个独立子代理 review_herdr_delivery。模型继承会话配置，工具未回显具体标识。
- 对照面：AGENTS、GOALS、U3、D1–D3、src/bucket 与生成清单、共享构建/portable 模块、Herdr 局部模块、测试 runner/矩阵、CI、真实生命周期与 Pester 基线证据、执行偏差与恢复记录。

## 发现与处置

| 发现 | 处置与复核 |
| --- | --- |
| P1 仅 pre_install 校验后仍可进入公共复制删除分支 | 已修。Herdr 改用局部模块，post_install 全量重验，无复制、覆盖或递归删除路径，阶段间新增目录/链接停止保留；二次审核已核实。 |
| P2 Continue 下链接创建/删除失败可能仍报告成功，runner Stop 掩盖 | 已修。局部模块设 Stop，命令 EA Stop，成功前核对；runner/真实隔离 wrapper Continue，故障注入终止且无成功输出；二次审核核实。 |
| P2 卸载没有核对链接归属 | 已修。仅有效 SymbolicLink、单目标、规范化本 persist 归属才解除；真实路径/外来链接/junction/自有失效链接均停止保留；补对应测试。 |
| P2 GOALS/D3 仍写公共映射机制 | 已修。文档同步为 portableProfile 的 Herdr 局部模块；不修改共享助手、不增加迁移器。 |
| P2 真实冲突验收早先因 buckets 缺失提前失败 | 已修环境后重跑。最终记录确实进入 Herdr guard 报既有数据路径并保持样本/current 未激活，旧失败不作为验收。 |
| TUI 验收误触可选集成造成日常 agent 写入 | 执行偏差。独立审核读实际服务 install 日志和 recovery 文件确认不是仅 UI 点击；已撤销识别的本次新增配置/文件，缺少全部事前字节基线，A3 的过程约束仍未通过，明确报告。 |

## 二次审核核对面

- 新模块与两个生成钩子内联内容一致；安装无迁移/覆盖，卸载非递归且验证身份。
- 既有、阶段间替换、权限与错误策略、卸载替换对象、relative 生命周期和父目录缺失矩阵；不宣称消除全部 TOCTOU。
- 完整官方包、独立 shim、真实 force update/卸载/重装、错误 hash/既有数据、默认与自定义路径证据。
- 独立归一化 Pester 18 个既有失败的名称与错误完全相同；候选增加 Herdr schema 通过，未修无关失败。
- 隔离副本的环境边界只操作 Process，安装业务钩子未 mock；记录首轮 PATH 偏差恢复和后来 TUI 集成实际写入/局部撤销。
- 正式清单无环境覆写或 agent 集成，更新来源和用户 notes 符合 D1–D3 与 U3。
- 最终实测：23 个测试/95 断言通过；独立审核亲读 terminal-result.json 及 custom-config 命名会话日志，核实最终 PID 46176 加载 bundled ConPTY、独立输出标记、shell 退出 0，随后停止自有服务器。最终会话没有 integration.action。

## 交付五关

1. 结构 review：初审三项代码问题已修，二次独立复核未见新增代码阻断。
2. 用户走查：隔离安装、shim、真实 ConPTY shell 输出、正常 shell 退出与生命周期已用；TUI 欢迎页渲染确认，但误触集成及主动服务器停止的客户端非零退出单列。
3. 修复复核：另派审核者核对 P1/P2，文档与自有失效链接合同修正后复核。
4. 交付完整性：正式源/产物、局部模块、测试/CI、使用说明与验收材料一起提交。Tests workflow 原本 disabled_manually，保持该设置，Herdr CI job 尚未运行；远端提交在最终交付时核实，不以前述通过代替远端状态。
5. 遗留审计：代码问题已修，无新增 backlog。全桶既有失败不属于本批次；A3 执行过程约束偏差没有自定豁免，保持未勾并报告，不能宣布全批次验收完成。
