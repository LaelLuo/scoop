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
