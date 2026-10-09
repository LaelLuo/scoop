# Herdr 实施验证

日期：2026-10-09；批次 add-herdr 修订 1；U3 已授权正式清单、隔离验收与提交推送。

## 环境与复现入口

正式源为 src/bucket/herdr.json，产物由 `bun scripts/build.ts --only herdr` 生成；Herdr 局部映射模块为 scripts/herdr-portable.psm1。共享 portable.psm1/build.ts 未修改。Bun 测试入口 `bun test ./tests/herdr-manifest.test.ts`，显式相对文件避免同时匹配验收快照副本；真实钩子 runner 使用默认 Continue；边界案例及日志落 workdir/herdr/tests。

真实安装根 workdir/herdr/acceptance，独立 Scoop、缓存、APPDATA/LOCALAPPDATA、全局应用目录均在该目录；默认测试清除子进程 XDG/Herdr 路径覆写，自定义路径另组。过程脚本 workdir/herdr/scoop-isolated.ps1 与 accept-lifecycle.ts，结果 acceptance/lifecycle-result.json。

首轮隔离 Scoop 复制自本机核心，后来其自更新换为上游核心；最终 Get-EnvVar/Set-EnvVar 在隔离副本限定到 Process，LAST_UPDATE 用运行时本地时间，避免更新替换该隔离边界。下载、校验、解包、shim、安装/更新/卸载与清单钩子仍执行原逻辑，不 mock 业务成功。

## 行为证据

- 官方 v0.9.3 x64 ZIP 的 7 个文件全部与原包逐文件 SHA-256 一致，含 conpty.dll、两架构 OpenConsole、清单与许可证；独立 PowerShell 子进程通过 Scoop shim 输出 `herdr 0.9.3`。
- 默认配置帮助显示隔离 APPDATA/herdr/config.toml，配置检查通过。自定义路径组显示独立 HERDR_CONFIG_PATH，配置检查通过，自定义文件与默认 persist 内容未被改写；XDG 状态运行验证另记最终终端结果。
- 真正 `scoop update herdr --force --independent` 执行同版本卸载/重装钩子；普通卸载与随后重装保持完整 persist 文件哈希及两份 config/state 样本，链接与 shim 按生命周期建立/解除。没有声称未来跨版本兼容已验证。
- 真实冲突安装已进入 Herdr pre_install，因第二个源的既有数据目录报错；原样本保留，第一个源没有创建链接，persist 未创建，current 未激活。早先因隔离缺 buckets 提前失败的记录是实验环境错误，不作为该验收证据。
- 错误 hash 清单真实安装在校验阶段停止，current 与数据映射未激活。
- 安全钩子测试覆盖既有目录/文件、外来/损坏链接、junction、第二入口冲突、persist 文件/链接、真实 ACL 检查失败、相对自有链接完整生命周期、persist 父目录完全缺失、pre_install 后才出现目录/外来链接、默认 Continue 下创建/删除失败注入、卸载被替换的路径和自有失效链接。无复制/覆盖/递归删除路径，不宣称检查与操作之间具有原子并发保护。
- PowerShell 5.1 在任何映射前明确要求从 pwsh 7 安装/升级；当前 PowerShell 7 的普通用户创建链接已实测。
- 单应用 checkver 输出 herdr: 0.9.3；全桶 60 项均取得版本，没有新增探测失效。bageshuo、workbuddy、chatcut、pnpm 显示正常 available，不在本批次改动。
- Pester 用 Windows checkout 等价的已跟踪文件快照，排除工作目录产物污染并保留完整测试集合：修改前 48 pass/18 fail；候选 49 pass/18 fail。归一化路径后失败名称和错误完全相同，Herdr schema/PowerShell 语法通过。既有 18 项为 16 个其他清单 schema、qq-nt 源缺末换行与 5 行既有尾空格，未扩面修复。最初直接在工作区跑测试扫入运行日志造成额外失败，该结果不能作正式候选回归。

## 隔离偏差与恢复

1. 首轮 Scoop shim 操作追加隔离 shims 到真实用户 PATH；与事前保存值核对后仅撤销该新增项，确认字符串完全相等。最终所有用户环境值与保存基线相同；后续 Scoop 环境操作限定到 Process。
2. TUI 走查误操作：欢迎页回车进入可选集成页面，随后原本用于 shell 的键入误触安装 omp/claude/codex/opencode 集成，确实写入了日常 agent 配置。测试命名会话已主动停止。服务日志路径为 workdir/herdr/acceptance/scoop/persist/herdr/roaming/sessions/scoop-acceptance/herdr-server.log，41–44 行为 2026-10-09 13:45:46–47 UTC 的 install 事件；取证副本保存在 workdir/herdr/recovery/incident-server.log。结合文件创建时间，7 个本次新文件移至 workdir/herdr/recovery：Claude hook、Codex hook/hooks.json、OpenCode plugin/TUI plugin/tui.jsonc、OMP extension；Claude settings.json 仅移除本次新增的 SessionStart hook，保留其他配置值。Codex config.toml 与 OpenCode opencode.json 未被本次改写。撤销检查见 acceptance/terminal-result.json 的 integration-cleanup-audit，记录原位置均不存在、Claude hooks 已移除；不输出其他配置值。
3. 没有事前保存全部 agent 配置的字节基线，不能声称逐字节恢复；已识别的新增集成均已撤销，恢复保留了其他配置值与现存目录。正式清单未包含自动集成；这次误操作属于执行过程偏差，不能写成授权内行为。后续终端验收只使用显式命名的隔离 headless 会话/API，不触发 onboarding 集成。

## 最终终端与交付

官方二进制曾在真实终端 PTY 下显示 Herdr 欢迎页；头部显示 spaces、工作区与 shell 提示符。主动停止命名服务器使 TUI 以 server shutdown 退出，此项不冒充正常客户端退出。

终端 shell/pane 已通过独立 Scoop shim 创建，输出 `HERDR_SCOOP_PTY_OK`（命令通过字符串拼接避免把命令回显当作结果），读取底部终端内容确认独立输出行；PID 43368 的模块列表显示加载的 DLL 为隔离 apps/herdr/current/conpty/conpty.dll。包与 shim 在最终模块修复后保持相同；最终命名会话复跑及交付结论见 [独立审核](reviews/herdr-delivery-2026-10-09.md)。

最终模块重装后以 workdir/herdr/final-terminal.ts 再验证：命名 headless 会话在独立 XDG 路径启动，Scoop shim/API 创建 shell，读取到独立 `FINAL_HERDR_PTY_OK` 输出行，PID 46176 确实加载本包 conpty.dll；shell 的 `exit` 在 custom-config/herdr/sessions/scoop-acceptance/herdr-server.log 第 16 行、13:54:18 UTC 记录 `pane.exit ... code: 0`，随后停止自有服务器，服务器主进程正常退出 0。套接字/日志位于 custom-config/herdr，状态实际生成 custom-state/herdr/agent-detection/status.toml，覆写文件保持。证据 acceptance/terminal-result.json。这里的正常退出指 shell 与 headless server，TUI 客户端的非零停止已单独记录。

最终显式单文件 Bun 测试 workdir/herdr/bun-tests-final.log：23 pass/0 fail/95 assertions。Tests workflow 在仓库原本为 disabled_manually（ID 151319911），保留该设置；新增 Herdr CI job 已写入工作流文件，但本批次不能声称 GitHub 自动 CI 已运行。

A3 的安装/持久化/覆写/错误保护与正式清单无 agent 写入已验证；“无 agent 配置修改”的执行过程约束实际出现上述偏差，且缺少完整事前字节基线，该复合验收保持未勾，不用功能测试或局部撤销冒充全条通过。
