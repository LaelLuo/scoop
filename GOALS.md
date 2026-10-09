# Scoop AI Tooling Bucket GOALS

- 规范版本：1

## 项目目标

维护 LaelLuo/scoop 的清单与既有日常巡检；本文件从 2026-10-09 的 Herdr 新增收录开始记录新批次，不追溯重写历史清单。

## 项目约束

- 真源为 src/bucket，产物由 bun scripts/build.ts 生成；显式路径暂存、串行 Git 变更。
- 日常维护承接 ZCode 会话 sess_e39163be-57b2-4cf7-bb14-10b03947b35f 的既有任务：不停止正在运行的软件，不删除用户数据；日常更新不安装新软件。
- Herdr 新增收录单独探索、对账与放行；当前没有新增清单或安装 Herdr 的实施授权。
- 原 ZCode 自动任务已核实暂停；当前 Codex 每日北京时间 04:00 任务 scoop 已启用并绑定本聊天。执行前检查当天日志，避免重复执行；见 [维护接管](docs/maintenance-runbook.md)。

## 项目验收

- [ ] P1 Herdr 通过本 bucket 安装与升级，维护者可据记录复核来源和用户数据边界。证据：未验证。

## 批次

### 新增 Herdr 清单

- 批次ID：add-herdr
- 阶段：待放行
- 修订：1
- 原话：[用户原话](docs/user-directives.md)
- 设计：内嵌
- 计划：内嵌

#### 目标与边界

将 https://github.com/herdrdev/herdr 收录进 LaelLuo/scoop，提供 Windows x64 官方稳定发布包的命令行入口与自动更新、配置/状态持久化。本次不修改 Herdr 上游功能，不安装到用户日常环境；安装与生命周期验收在隔离环境进行。

#### 关键问题与可行性

- 关键阻断：无
- 已验证 v0.9.3 官方 x64 ZIP 的 SHA-256、完整包结构、版本/帮助/配置检查；固定版本源码证明默认配置为 AppData/herdr、状态为 LocalAppData/herdr，XDG 覆写继续尊重。见 [可行性记录](docs/herdr-feasibility.md)。
- 正式清单构建、Scoop 隔离安装、升级/卸载及完整终端入口验证留在放行后，不冒充已交付。

#### 设计

- 问题与目标行为：用户可通过 Scoop 安装、运行及更新 Herdr。
- 现状与约束：当前 bucket 未发现 Herdr；既有清单依 src → build → bucket 工作流。Windows 包附带 ConPTY 与许可证文件，不能只提取 herdr.exe。
- 结构与流程：新增 src/bucket/herdr.json；architecture.64bit 使用官方 herdr-windows-x86_64.zip，完整解包，bin=herdr.exe；checkver 使用 GitHub stable release，autoupdate 固定 v$version 的同名 ZIP；portableProfile 将 AppData/herdr 和 LocalAppData/herdr 分别映射至 persist/roaming、persist/local。
- 关键取舍：自定·2026-10-09，采用官方稳定包与两个既有目录映射，理由和排除项见 [D1/D2/D3](decisions.md)。pre_install 先只读核查完两个默认源路径和 persist 目标，再进入任何映射动作：源只允许不存在或本清单 persist 目标的有效符号链接；目标只允许不存在或真实目录。既有数据目录/文件、junction、外来/失效链接、无效目标或检查失败时终止并保留原路径，不运行公共助手的数据迁移分支。不覆盖用户 XDG/HERDR_CONFIG_PATH，不修改配置开关，不注入 agent 集成。内置更新仅检查提示，真正安装由用户显式 herdr update 触发；notes 明确用 scoop update herdr，避免官方独立安装器创建第二套版本与 PATH。
- 异常路径：下载或 hash 失败由 Scoop 阻止安装；占用时跳过升级，不结束 Herdr/agent 进程；卸载仅移除映射链接与程序，Scoop persist 数据保留；既有源目录/文件、外来或失效链接、检查失败均报路径并停止，数据和链接保持原状，不自动删除/合并。自定义 XDG/配置路径仍由用户管理。无 Windows ARM64 原生资产，本批次只声明 x64。
- 可行性证据：官方发布包 hash、7 文件清单、隔离运行结果及固定 tag 源码见 [可行性记录](docs/herdr-feasibility.md)。
- 验收对应：A1, A2, A3

#### 验收标准

- [ ] A1 隔离 Scoop 安装官方 Windows x64 包后 herdr --version 与清单一致，命令入口可从独立终端进程解析；完整 ConPTY 文件及许可证保留；错误 hash 阻止安装；实际终端可启动 Herdr 的 shell/pane、输出标记并正常退出，核实辅助组件被使用。证据：未验证。
- [ ] A2 checkver 检出官方稳定版，autoupdate 定位同架构发布资产，构建结果与 src 一致；完整 checkver 回归不引入其他清单失效。证据：未验证。
- [ ] A3 隔离首次安装创建两个映射；既有目录/文件、外来或失效链接、检查失败时安装停止且源内容/链接及已有 persist 样本保持；同版本强制更新及卸载后 persist 内容保持，卸载仅解除链接；XDG/HERDR_CONFIG_PATH 覆写不被改写；notes 明确 Scoop 更新入口、默认持久化路径及既有数据需先处理；无 agent 配置修改与用户环境安装。证据：未验证。

#### 实施步骤

- [x] 形成内嵌设计与 [OpenSpec 提案](openspec/changes/add-herdr-manifest/proposal.md)，运行结构校验和提案 strict 校验，完成独立对账。证据：[独立初审与复核](docs/reviews/herdr-proposal-2026-10-09.md)。
- [ ] 一次呈交本修订，获得正式实施放行。
- [ ] 放行后新增 src 清单并构建 bucket，验证 A1/A2/A3；隔离安装的 Scoop、AppData、LocalAppData 和缓存位于 workdir/herdr，不复用用户运行态。默认目录验收清除子进程继承的 XDG_CONFIG_HOME/XDG_STATE_HOME/HERDR_CONFIG_PATH，覆写子进程 APPDATA/LOCALAPPDATA 至隔离目录；自定义路径验收另设独立 XDG/配置路径，两个分支分别核证。升级场景以同版本强制更新验证钩子，不谎称跨未来版本验证。
- [ ] 完成独立审核、用户视角走查、修复复核、交付完整性和遗留处置，显式提交并推送。

#### 审核与授权

- 对账：通过
- 审核记录：[独立初审与复核](docs/reviews/herdr-proposal-2026-10-09.md)
- 放行：未获得
- 批准修订：无
- 批准范围：无
- 批准依据：无

#### 过程发现

- 原会话包含 1754 条文本消息，最新一轮 Scoop 夜巡已于 2026-10-09 完成；工作区干净，最新修复提交为 0f9036f。本轮接管不重复执行已完成的夜巡。
- 独立对账发现公共 portable 助手复制吞错后仍删除源目录；本批次通过安装前源路径校验避开其迁移分支，采用安全停止行为，不修改共享助手。探索 probe 已显式清除继承 HERDR_CONFIG_PATH；正式验收区分默认与自定义路径。

## 文档索引

- [用户原话](docs/user-directives.md)
- [维护接管](docs/maintenance-runbook.md)
- [方案决策](decisions.md)
- [Herdr 可行性记录](docs/herdr-feasibility.md)
- [OpenSpec 提案](openspec/changes/add-herdr-manifest/proposal.md)
- [独立审核](docs/reviews/herdr-proposal-2026-10-09.md)
