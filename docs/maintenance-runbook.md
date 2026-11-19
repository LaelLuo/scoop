# Scoop 日常维护接管

## 当前接管边界

2026-10-09 用户将 ZCode 会话 sess_e39163be-57b2-4cf7-bb14-10b03947b35f 的 Scoop 维护移交当前 Codex 聊天。原 ZCode 定时任务 automation-cc041293-b17f-4686-9bdf-9e143b17a5f1 为每天北京时间 04:00；本轮只读核实为 enabled=0、lifecycle_status=paused、running=0。今天夜巡已完成，接管不重复执行。

本任务沿用原夜巡范围，Herdr 新增清单按 GOALS 的 add-herdr 批次单独推进。2026-10-09 已用 Codex automation 工具创建并回读任务 scoop，状态 ACTIVE、每天北京时间 04:00、绑定当前聊天 01a1209d-56c0-7763-9884-54627cd99b54；持久配置亦核实一致。沿用原任务的每日简短汇总要求，正常时一句话，需决策或动作时单列；执行器未来运行仍依赖本机 Codex 可运行。2026-10-10 首轮 heartbeat 已完整执行更新、清理、纯查询 checkver、DiskGenius 和 Actions 核对，证据在 workdir/auto-update/2026-10-10.md。

## 执行顺序

工作目录 E:/Projects/ScoopProjects/scoop（Playground 的 projects/scoop 是其符号链接）。先读取仓库 AGENTS.md、本文及最近两晚日志；使用北京时间日期，将全部输出与中文小结追加到 workdir/auto-update/YYYY-MM-DD.md。

1. 依次执行 scoop update、scoop update --all，耐心等待完成。
2. 分类结果：运行中/文件占用仅记录；连续多晚阻塞在汇总提醒。hash 失败先 scoop cache rm <app> 再重试一次；仍失败才调查。非 laelluo 桶只作缓存等本地绕过，不改第三方仓库。laelluo 的下载/探测失效按既有修复授权处理：读源、验证实际上游、修改 src/bucket、bun scripts/build.ts --only <app>、核对产物、显式提交并推送、已安装应用更新复验，未安装应用只作探测。不理解上游变化就报告，不盲改。checkver script 不 throw，失败空输出。
3. 执行 scoop cleanup '*'、scoop cache rm '*'，保留输出并报告旧版本应用数与缓存空间。旧版本被锁时核实具体目录在 Scoop 应用目录内；不关闭进程、不强删锁定文件。只在可以安全处理后重跑；否则明确记录整批清理被中止及未清理范围。
4. 工作区干净才 git pull --ff-only origin master；存在无关改动保留并说明，不用 stash/restore 覆盖。执行 pwsh -NoProfile -File E:/Projects/ScoopProjects/scoop/bin/checkver.ps1（不加 -u）。网络/SSL 先重试一次；持续探测失效按第 2 步修复。available 首晚归 Actions 正常追版；连续两晚先核实是否其实每天追最新-1，确属停止追版才单应用 -u、build、提交推送。403/上游分发阻断不反复重试。
5. qq-nt 仅观察：它由 qqnt-mirror 每 6 小时检测、签名下载、发布镜像、更新清单。连续两晚 available 查 gh run list -R LaelLuo/scoop --workflow=qqnt-mirror.yml --limit 3 与失败日志，报告具体原因；正常时不干预。
6. 执行 pwsh -NoProfile -File E:/Projects/ScoopProjects/scoop/scripts/mirror-diskgenius.ps1。无新版直接退出；新版按现有镜像机制运行。验证码阻断就报告，不反复请求。
7. gh run list -R LaelLuo/scoop --limit 15；failure 用 gh run view <id> -R LaelLuo/scoop --log-failed。清单失效按第 2 步修复；单次网络抖动记录观察。Actions 全绿不代替 checkver 通过。
8. 日志末尾中文小结：更新/跳过/修复/清理空间/checkver/Actions/diskgenius。最终回复用同样简短的中文汇总，一切正常时一句话即可；修复、新失败、连续占用提醒、验证码或需要用户决策时具体报告。已完整完成本轮且无新变化时不重复通知。

## 硬约束

- 不停止正在运行的软件，不安装新软件，不删用户数据，不改桌面音频和设备配置。
- 夜巡 Git 操作只针对 LaelLuo/scoop，不碰 Playground 根仓库或其他项目。
- 已有维护与局部修复沿用真实授权；改变分发拓扑、共享真源或持久化关系时按 GOALS 修订流程处理。
- 不用旧会话的 shell 包装写法覆盖当前 AGENTS.md；用 workdir 指定目录，已安装工具直接调用。

## 历史证据

- 原会话全文共 1754 条文本；已读取全部用户需求并核对最近两晚正文和当前任务书。
- 最新日志：workdir/auto-update/2026-10-09.md；最新维护修复：0f9036f（AutoGLM checkver 直调官方版本 API）。
- 原会话曾处理的 MicYou 6X 安装已经交付，不属于每天夜巡；新增软件与其他设备操作不随接管自动扩大范围。

## 本地夜巡（2026-11-20 起，计划任务版）

每天 04:00 的夜巡由工作站上的 Windows 计划任务运行脚本 `scripts/nightly-patrol.ps1`，不再占用 Grok Bot 额度。脚本只做确定性步骤，只有出错或有清单需要修时才唤醒 bot。

### 运行方式

- 计划任务：「scoop 夜巡」（若已有同名任务则用「scoop 夜巡 (laelluo)」）。以当前登录用户运行、只在用户登录时运行、不提升权限（与手动操作同权限，能建 SymbolicLink）；每天 04:00，错过后补跑（StartWhenAvailable），执行时限 2 小时，不允许多实例。
- 动作：`pwsh.exe -NoProfile -ExecutionPolicy Bypass -File E:\Projects\ScoopProjects\scoop\scripts\nightly-patrol.ps1`。脚本必须在 pwsh 7 里跑，Scoop 操作全在该进程内直调 `D:\Scoop\apps\scoop\current\bin\scoop.ps1`，不回退 PS5.1。
- 手动运行：`pwsh -NoProfile -File scripts\nightly-patrol.ps1`。当天日志已完整（含「本轮完成」）时整轮跳过，重复运行无副作用；日志不完整会改名为 `YYYY-MM-DD.incomplete-HHmmss.md` 后重跑。
- 测试开关：`-DryRunWake` 只组装 payload 写盘不发送；`-SimulateFailure` 强制走唤醒分支，跳过全部真实操作，日志与 payload 文件带 `.simulated` 后缀，不改 state.json。

### 步骤与产物

1. Git 同步（工作区干净才 `git pull --ff-only origin master`）。2. 同进程 SymbolicLink 预检（文件型、目录型、AppData 卷到 persist 卷的跨卷链接），不过则不更新任何软件。3. 链接基线、`scoop update` 索引、`scoop status`。4. 逐个更新（不用 `update --all`；运行中和 hold 跳过；更新前后核对链接与 persist；hash 失败先 `scoop cache rm` 再重试一次；断链或报错立即停止其余更新）。5. `scoop cleanup '*'` 与 `scoop cache rm '*'`（本轮断链则不做）。6. `bin\checkver.ps1`（不加 -u，有报错原样重跑一次）。7. `gh run list` 与 open issues。8. `scripts\mirror-diskgenius.ps1`。9. 小结与唤醒判定。

- 日志：`workdir/auto-update/YYYY-MM-DD.md`（北京时间日期），原始输出在同名 `raw-YYYY-MM-DD/`。
- 跨晚状态：`workdir/auto-update/state.json`（available、被跳过的连续晚数；workdir 已被 git 忽略）。
- 脚本不修清单、不提交；DiskGenius 镜像脚本发现新版时按其既有机制发布并推送。

### 唤醒条件

唤醒：预检失败；断链（基线、更新后、清理后复核任一）；hash 重试后仍失败；更新报错；checkver 有清单报错（重跑后仍报）；清单 available 连续两晚以上；Actions 有失败（后续同名 workflow 已成功恢复的不算）；DiskGenius 遇到验证码或脚本失败；同一软件连续 3 晚因运行中被跳过（`grok-bot` 是 bot 自身守护进程，常驻运行，不计）；脚本自身异常（try/catch 兜底）。

不唤醒：只是首晚 available；软件因运行中被跳过（未满 3 晚）；单次网络失败、重跑后成功。

### 唤醒方式（webhook）

- 配置：`%USERPROFILE%\.config\scoop-nightly\webhook.json`，格式见 `scripts/nightly-patrol.webhook.example.json`（`{"url":"...","headers":{"<名>":"<值>"}}`），该文件不进仓库；url 与 headers 绝不写入日志或 payload 文件。
- 请求：POST JSON，字段 `date`、`reasons`（数组）、`summary`（日志小结，4000 字以内）、`log_path`。失败重试 3 次。
- 配置缺失、配置损坏、3 次发送失败或 `-DryRunWake` 时，payload 写到 `workdir/auto-update/pending-wake-YYYY-MM-DD.json`，日志记一笔；需人工补发或让 bot 读取该文件。

### 被唤醒后 bot 的处理

先读 payload 的 `log_path`，对应 `reasons` 逐项处理：清单修复走 `src/bucket` → `bun scripts/build.ts --only <app>` → 验证 → 提交推送；断链/预检失败只报告，不改 Junction、不合并真实目录；其余按本文「执行顺序」与「硬约束」。处理完在看板 task-b1eeada9 记一笔，并向用户报告。
