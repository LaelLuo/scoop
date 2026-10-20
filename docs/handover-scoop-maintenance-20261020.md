# Scoop 维护线交接（2026-10-20）

> **来源**：ZCode 会话 `sess_e39163be-57b2-4cf7-bb14-10b03947b35f`（标题「scoop更新维护（自动）」，1754 条文本消息，2026-08-19 → 2026-10-09，completed）全量通读；另衔接 2026-10-09 之后 Codex 每日 04:00 自动化留下的 `docs/maintenance-runbook.md`、`GOALS.md` 与 `workdir/auto-update/` 日志。
> **接手人**：`scoop-steward`（DSH 长期 teammate）。
> 本文是交接与接手声明，**不改变任何清单、安装、环境变量或自动化配置**。

## 0. 接管声明

- 自 **2026-10-20** 起，Scoop 日常维护（夜间全量更新、laelluo bucket 健康巡检、清单修复、Actions 排查）由 `scoop-steward` 承接。
- **zcode 会话 `sess_e39163be…` 转为只读历史**：保留为证据与先例库，不再续聊、不再作为执行入口；后续排障不要依赖该会话上下文，需要背景时查本文与 `workdir/auto-update/` 日志。
- 现行夜间执行器（Codex 每日 04:00 自动化，见 `docs/maintenance-runbook.md`）**本任务未改动**。是否退役、改由 scoop-steward 触发，见「6. 未决事项」。
- 维护红线继承用户既有要求：**不停止/不强杀正在运行的程序、不安装新软件、不删除用户数据、git 只操作 LaelLuo/scoop 这一个仓库**（Playground 根仓库与其他项目仓库一律不碰）。

## 1. 维护对象与运行环境

- **真源仓库**：`E:\Projects\ScoopProjects\scoop`（独立 git；Playground 的 `projects/scoop` 是其符号链接）。bucket 名 `laelluo` → `https://github.com/LaelLuo/scoop`，当前 61 个清单。
- **清单双层结构**：`src/bucket/*.json(c)` 是源（可写注释、`portableProfile`、`checkver`/`autoupdate` 逻辑）→ `bucket/*.json` 是构建产物（用户 `scoop install/update` 实际读的面）。构建命令：`bun scripts/build.ts [--only <app>]`（在仓库 `scripts/` 目录或带路径执行）。
- **用户运行态**：Scoop 在 `D:\Scoop`（用户级）；已装应用 60+；本地桶 clone 在 `D:\Scoop\buckets\laelluo`，由 `scoop update`/`scoop update laelluo` 刷新。Windows 默认 shell 是 Git Bash + PowerShell 7。
- **自动化**：
  - `excavator`（GitHub Actions 定时）：跑 checkver，有新版就下载算 hash 并**只提交 `bucket/` 产物**（提交格式 `app: Update to version X`）。
  - `qqnt-mirror`（每 6h）：腾讯 QQ 新版 → `GetSign` 签名下载 → 发 GitHub Release → 更新清单 → 提交。
  - `CI`：Pester 全量清单校验（CI 环境下只校验本次变更的 bucket 文件）+ `tests/herdr-manifest.test.ts`。
- **日志**：`workdir/auto-update/<yyyy-MM-dd>.md`（`workdir/` 被 `.gitignore` 忽略，属本地运行证据，不进版本库）。`docs/` 亦在 `.gitignore` 中，但既有 7 份运维文档为已跟踪文件；本文按同样方式显式 `git add -f` 收进版本库。

## 2. 夜间例行 SOP（现行口径）

权威步骤以 `docs/maintenance-runbook.md` 为准（Codex 线 8 步）；下面是同一流程的可执行摘要与**判断口径**（历史任务书里有更细的先例说明）：

1. **更新**：`scoop update`（刷 Scoop 本体 + 各桶）→ `scoop update --all`（**必须 `--all`，不要写裸 `*`**，Git Bash 会把 `*` 展开成文件名）。输出追加进当天日志。更新慢时耐心等待，不要中途打断（2026-09-27 教训：自设 10 分钟超时把更新拦腰切断，违反纪律）。
2. **分类处理更新输出**：
   - 运行中/文件占用被跳过 → **预期行为**，只记录，绝不 taskkill/Stop-Process；连续多晚占用才在汇总提醒用户择机手动更新。
   - hash 失败 → 先当本地缓存损坏：`scoop cache rm <app>` 后 `scoop update <app>` 重试（cherry-studio aria2 断点缓存先例）。重试仍失败才查清单/上游。
   - 404/URL 失效/探测失效 → 按「3. 清单修复标准流程与核心机制」处理；看不懂上游变化就如实报告，不盲改。
   - 第三方桶（extras/main 等）失败 → 不改别人仓库，能本地绕过就绕过，否则记录报告。
3. **清理**（用户 2026-10-02 拍板每晚清）：`scoop cleanup '*'`、`scoop cache rm '*'`（**`*` 必须加引号**）。已知坑：cleanup 遇到文件锁在第一个错误处**整批终止**——按报错路径 `rm -rf <旧版本目录>` 后重跑（幂等）；查占用进程时 `$_` 在 bash 里要用单引号包住，别被先解引用。反复锁死且查不到占用者就跳过并记录，不强删不杀进程。汇总报「删了几个旧版本 + 腾出多少缓存」。
4. **checkver 健康巡检（防 Actions 静默漏更）**：先 `git pull origin master` 拉齐工作区（否则扫出幻影 available），再 `pwsh -NoProfile -File <绝对路径>/bin/checkver.ps1`（全量纯查询，**不加 `-u`**）。分类：
   - 检查源报错（couldn't match / URL / SSL）：SSL 或网络类**先原样重试一次**再定性（moonbit 瞬态 SSL、autoglm 无头抓页超时先例）；确属源失效走修复流程。
   - available：归 Actions 日常职责，当天不动；翻历史日志确认同一应用**连续 ≥2 天** available 才手动 `checkver.ps1 <app> -u`（日更类 app 桶清单常态停在最新-1，不算失效）。
   - 全部一致：一句话带过。
5. **qq-nt 镜像巡检**：只观察。连续 ≥2 天 available → `gh run list -R LaelLuo/scoop --workflow=qqnt-mirror.yml --limit 3` 查失败原因；必要时本地跑兜底（见 §4 坑清单第 8 条）。
6. **diskgenius-zh 镜像巡检**：`pwsh -NoProfile -File <仓库>/scripts/mirror-diskgenius.ps1`。无新版自动秒退；有新版会弹本机 Edge 走蓝奏云下载并自动完成 Release、清单、commit/push。遇验证码阻断只报告，不反复重试。
7. **Actions 巡检**：`gh run list -R LaelLuo/scoop --limit 15`；failure 用 `gh run view <id> -R LaelLuo/scoop --log-failed`。清单类问题（checkver throw、regex 失效、hash 失效）走修复流程；单次网络抖动标记观察。
8. **汇总**：日志末尾追加中文小结（更新/跳过/修复/清理/checkver/Actions/diskgenius），最终回复同样简短；一切正常一句话，需用户决策的单列。夜间全程不要询问用户（用户在睡觉）。

## 3. 清单修复标准流程与核心机制

### 3.1 修复流程（每个清单）

1. 只改 `src/bucket/<app>.json(c)`；`bucket/` 不手改。
2. `bun scripts/build.ts --only <app>` 生成产物，核对 diff 只含预期变化（版本三元组/checkver/autoupdate 段）。
3. `git add -- <src 路径> <bucket 路径>`（显式路径，不 `git add .`），串行执行 git 操作。
4. 提交信息遵循 `git-commit-zh`：`:gitmoji: type(scope): 中文描述`（如 `:bug: fix(autoglm): …`）；推 `origin master`；远端有 excavator 新提交时先 rebase 再推。
5. 验证闭环：触发 excavator（`gh workflow run` 或等定时）看日志确认新清单不报错、版本守住；必要时 `scoop update <app>` 实装验证（**能装才算修好**，不能只看 YAML 合法）。
6. 日志与汇总记录修了什么、提交号、验证方式。

### 3.2 src ↔ bucket 权威规则（最容易踩）

- **version / url / hash 以 `bucket/` 产物为权威**：`build.ts` 的 `mergeCanonicalFields` 会把产物里的版本三元组回写 `src/`。excavator 只动产物，所以 `src/` 会周期性落后——跑一次全量构建即自动追平（2026-09 的「41 个未提交版本升级文件」就是这么来的，收口提交 `6e09170`）。
- **checkver / autoupdate / portableProfile 以 `src/` 为权威**：这层改动必须写 src 再 build。
- **不要手改版本「顶」上去**：excavator 的判据是「checkver 版本 ≠ 清单版本就无条件 autoupdate」，**没有降级保护、也没有大小比较**。上游先放 CDN 文件、changelog/官网滞后时，手改的版本下一轮会被打回去（zcode 3.8.1 被回退事故，`782468f`）。**治本方法是改检测源（checkver script）**，让探测本身看到新版本；这是用户明确要求过的工作方式。
- `checkver` 的 script **严禁 throw**：会打挂 excavator 整个 run（open-pencil 504 事故、anytype、douyin-ide 均有先例）。要求 try/catch + 超时 + 失败输出空/兜底。
- `checkver` script 里**命名捕获组可直接喂给 `autoupdate` 模板**（`$matchUrl`、`$matchSignedurl`、`$match1..4` 等）；`autoupdate` 本身**没有脚本能力**，只能模板替换和按 GET 正则取 hash。
- autoupdate 模板只认裸 `$version`；`${version}` 会被原样透传导致 404（bageshuo 事故 `3baea25`）。
- **不可自动下载的版本不得发布进清单**：清单作为公开产物必须能被 scoop 自己的下载器安装；需要签名/人机交互的版本只能钉在可安装旧版或用镜像 Release（qq-nt 纪律）。

## 4. 已知坑与红线

| # | 场景 | 事实与处置 |
|---|---|---|
| 1 | **laelluo vs extras 同名 app** | 官方 extras 不管便携化，用户明确要求「别管 extras」，便携化由 laelluo 负责。同名时 `scoop install <app>` 按桶顺序解析（extras 常在前），`scoop update` 则**复用首次安装记录的 bucket**（`scoop-install.json`）。跨桶升级会丢便携化（zcode 3.7.7 被 extras 升级后 `~/.zcode` 变普通目录）。**安装一律用桶前缀** `scoop install laelluo/<app>`，装完用 `scoop info`/`scoop-install.json` 核实来源。要纠正归属只能重装，`scoop reset` 不解决。 |
| 2 | **workbuddy 双桶并存（2026-10-20 核实）** | 本机 workbuddy 来自 laelluo（5.8.3.41334564，`codebuddy.cn` 渠道、`WorkBuddy.exe`，带 portableProfile）；官方 extras 自 2026-10-16 起也收录同名包（5.8.4，`workbuddy.ai` 渠道、`WorkBuddyAI.exe`、无便携化）。已装应用与 `scoop update workbuddy` 仍走 laelluo（install.bucket 绑定），但**全新安装会优先命中 extras 装到另一渠道**。归属策略待拍板（见 §6 U7）。 |
| 3 | **`scoop reset` 不应用新清单改动** | `reset` 读的是已装版本目录里的 `scoop-manifest.json` 快照（安装时保存）。新增的 `env_set`/`post_install`/`portableProfile` 要等该应用**用新清单重装或更新**后才生效。env 类改动之后还要重启使用该变量的进程（如 DSH）。`scoop update <app>`（新版本）会自动重跑 install 钩子；同版本强制重装用 `scoop update <app> -f`（会移走 current、需先关闭程序，非必要不做）。 |
| 4 | **changelog / 官网滞后，仅 CDN 先发** | 上游常先放安装包到 CDN、后更新 changelog/官网。页面型 checkver 会漏版，且 excavator 无降级保护 → 手改版本会被回退。处置：checkver 改 script 探测 CDN 文件/官方 API/重定向 Location（zcode、lm-studio、autoglm、wechatdevtools 先例）。 |
| 5 | **excavator 静默漏更** | checkver 源失效时 excavator 只会静默跳过，run 依然绿。**Action 全绿 ≠ 清单健康**，夜间显式 checkver 巡检是唯一暴露手段（用户 2026-09 亲历后拍板加入）。 |
| 6 | **GitHub API 匿名限流 / 工作区落后** | checkver 的非 token 请求会限流，表现为假 available 或匹配失败（anytype、picacg、ccpocket 案），Actions 带 token 不受影响，属自愈噪音；checkver 前不 pull 会产生幻影 available。 |
| 7 | **扫描/清理的 shell 引号** | `scoop update --all` 不要用裸 `*`；`cleanup '*'`、`cache rm '*'` 必须引号；bash 下 `$`、`$_` 用单引号防解引用；路径用正斜杠避免被吃。 |
| 8 | **qq-nt 特例** | 腾讯新路径 `QQNTV2` 对非真浏览器请求一律 403（缺 `GetSign` 票据，不是指纹问题）。已切 **GitHub 镜像架构**：`qqnt-mirror` workflow 每 6h 签名下载→发 Release→更新清单；**清单已删 autoupdate 段**，防止 runner 侧陈旧 CDN 缓存（返回旧版）触发「不相等即更新」的合法降级（`aba461f` 事故）。已装包不受链接过期影响。镜像 workflow 在 runner 侧曾出现静默跳过（本地跑正常，疑境外 IP 或 CDN 陈旧缓存），本地兜底流程与脚本见 `scripts/qqnt-mirror.ps1`、`scripts/qqnt-fetch.ps1`。 |
| 9 | **应用自更新（绕过 scoop 自装第二副本）** | 便携化拦截用 `portableProfile` 的 updater 映射：把 `LocalAppData/<name>-updater` 挂成指向 `$persist_dir/updater-blocker` 空文件的 symlink，更新器下载阶段即失败。判据：`resources\app-update.yml` 存在 = electron-updater（**充分不必要**，figma= squirrel、capcut=差分升级器都没有该文件但会自更新，不能反推）；非 electron-updater 机制不盲套文件型拦截。当前桶内已有 10+ 清单带拦截（notion/lm-studio/zcode/qq-nt/claude/autoglm/anytype/open-pencil/autoclaw/chatcut/douyin-ide 等）。拦截生效时应用内「检测到新版」提示仍会出现（只读检测通道拦不住），升级走 `scoop update <app>`。 |
| 10 | **结构性跳过** | 夜巡自身跑在 Git Bash / ZCode 会话里：git 常因常驻 shell 占用而多晚跳过；zcode 自己**永远无法在夜巡中自更新**，只能提醒用户托盘退出 ZCode 后手动 `scoop update zcode`。lm-studio/feishu 等也常因运行中跳过。**不强制关闭正在运行的程序**。 |
| 11 | **网络瞬态** | SSL/超时先原样重试一次再定性；GitHub SSH 22 端口曾被网关 fake-ip 截断而 HTTPS 正常，remote 是否永久切 HTTPS 待用户拍板，不要擅自改 remote。 |
| 12 | **便携化验证要用真实数据流** | 只验证 symlink 存在不够：claude 案漏了 `~/.claude.json` 顶层配置，claude 首启写入才暴露；验证方法 = 应用首启/实际使用后检查 persist 内有活跃数据、`%APPDATA%`/`%LOCALAPPDATA%` 无散落真目录。应用改名或 Electron userData 名变化可能绕过映射（qoder 1.25.1 改名案实测未变，但每次上游改名都要复核）。 |
| 13 | **不适合 scoop 化的软件** | 输入法/驱动类（千问输入法、豆包输入法）：写 `Program Files`/HKLM/注册文本服务/常驻服务，解包必是空壳，走官方安装器直装，不做清单。 |
| 14 | **提交纪律** | 只 `git add -- <显式路径>`；提交信息 gitmoji + conventional + 中文（`git-commit-zh`）；git 操作串行；推前 rebase；不把本地日志/会话导出/无关文件带进提交；`workdir/`、`docs/` 默认被忽略（本文显式 `-f` 除外）。 |
| 15 | **CI 噪音** | 本地全量 Pester 有约 92 条既有 schema 失败，全部来自 `autoupdate` 的 `$matchUrl#/...` 片段被新 schema 判为非法 URI（workbuddy 也有 3 条同源）；CI 只校验变更清单，历史红不是新引入的。 |
| 16 | **Herdr 专项** | 用局部 portable 模块做双目录映射与“检查失败即停止”；`GOALS.md` 中 A3（隔离生命周期验收）**仍未勾**，不要表述为整批验收通过。 |

## 5. 当前状态（截至 2026-10-20 16:40）

- **仓库**：`HEAD = 9cb5e8b`（`:sparkles: feat(workbuddy): 清单接管 WORKBUDDY_ELECTRON_BIN 环境变量`，本文提交前的提交），与 `origin/master` 同步，工作区干净；61 个清单。
- **最近修复**：`178164d` herdr 收录；`6ed06b2` checkver GitHub API 模式 + CrossDesk 追平；`156be44` virtual-browser 2.4.0 哈希；`9cb5e8b` workbuddy 清单新增 env_set（`WORKBUDDY_ELECTRON_BIN=$dir\WorkBuddy.exe`，本机值暂未变，待下次 `scoop update workbuddy` 生效，见坑 3）。
- **最近一晚夜巡（2026-10-20 04:00）**：12 项待更新、9 项成功；bun/herdr/wechat 因运行中跳过（连续 3 天）；清理 9 个旧版本 + 缓存 1.1 GB；checkver 全量 exit 0，仅 qoder 报 SSL 握手失败（两次均失败）、utools 8.0.0 报 available；Actions 最近 15 个 run 全 success（最新 Excavator 单项 utools 更新因官方 IA-32 地址 404 失败）；diskgenius 上游/清单一致（6.2.0.1829）。日志：`workdir/auto-update/2026-10-20.md`（10-17 日志缺失，连续占用不跨缺日推算）。
- **2026-10-09 后已收敛的历史遗留**：41 个 src 源追平产物（`6e09170`）、qq-nt 降级隐患（`aba461f`）、codebuddy 检查域名迁移、autoglm 检查去 throw 化+改接口（`0f9036f`）、open-pencil throw（`6993aae`）、bageshuo `${version}` 模板 bug（`3baea25`）、douyin-ide 救活（`1d97e08`）、claude-code/rebased/chatcut/叭哥说等新清单收录。

## 6. 未决事项与需用户拍板

| # | 事项 | 现状 / 选项 |
|---|---|---|
| U1 | **每日 04:00 执行器归属** | 现由 Codex automation 跑（`docs/maintenance-runbook.md`）。scoop-steward 是会话型 teammate，**没有后台循环**：要么保留 Codex 作为 runner、scoop-steward 负责修复/复核/接手排障；要么由用户/Lead 每天唤醒 scoop-steward；要么改设 DSH 侧定时提醒（需会话常驻）。**需拍板，本任务未改自动化配置。** |
| U2 | **utools 8.0.0 autoupdate 失败** | 官方 IA-32 下载地址 404（Excavator 单项失败）；`src/bucket/utools.json` 仍含 32bit 架构、版本 7.8.0。方向：删 32bit 架构 / 修 autoupdate URL（参考 wechatdevtools 先例）。未动清单，待批准。 |
| U3 | **qoder checkver SSL 失败** | 2026-10-19、10-20 两晚 `center.qoder.sh` SSL 握手失败（已重试）。观察项；若持续需确认检查源是否迁移（参考 codebuddy `.ai→.cn` 先例）。 |
| U4 | **运行中占用三连** | bun / herdr / wechat 连续 3 晚被进程占用跳过；需用户退出这些程序后手动 `scoop update bun herdr wechat`（夜巡不杀进程）。 |
| U5 | **qqnt-mirror runner 静默跳过** | 方向二选一：给镜像脚本/workflow 加跳过原因日志做诊断，或接受「夜巡本地兜底」模式。 |
| U6 | **GitHub remote 协议** | 历史上 SSH 22 被网关截断、HTTPS 可用；建议切 HTTPS remote，但需用户拍板（本机未改）。 |
| U7 | **extras 同名包后的桶定位** | extras 收录 workbuddy（及此前 zcode/rebased 等）后，laelluo 版继续维护便携化，还是逐步下线/README 标注差异，需用户决定。 |
| U8 | **Herdr A3 验收** | `GOALS.md` 批次 add-herdr 的 A3 未勾（过程约束偏差，缺完整事前字节基线）；是否补验收/关闭批次需用户决定。 |
| U9 | **workbuddy env_set 生效时点** | 清单已推送（`9cb5e8b`），但既有 5.8.3 安装的 `scoop-manifest.json` 快照无 env_set，`scoop reset` 也不会应用；生效需等下一次 `scoop update workbuddy`（新版本）或经批准的 `scoop update workbuddy -f`；生效后需重启 DSH。 |

## 7. 以后如何触发这项工作

- **日常**：用户/Lead 说「跑夜巡 / 看昨晚更新 / 检查 Actions / 某个清单挂了」，scoop-steward 按本文 §2、§3 执行，产出写 `workdir/auto-update/<日期>.md` 并简短回报。
- **没有后台循环**：scoop-steward 只在被唤醒（用户消息或 Lead 指派）时执行；不会自动到点运行。若用户希望完全无人值守，需保留 Codex 04:00 automation（推荐，现状）或另设 DSH schedule（要求本会话常驻），见 U1。
- **紧急/失败**：提供失败日志路径或说「看最新 Actions run」，优先按 §3.1 修复流程；涉及重装、强杀进程、改 remote、改其他仓库等动作先回报等批准。

## 8. 关键提交索引（已核实存在于仓库历史）

- 清单修复：`4527a84` zcode autoupdate 平台子目录；`16ff602` zcode 3.8.1 + checkver CDN 探测；`fbf272a` project-graph/wechatdevtools/lm-studio；`fb45f42` aionui；`142e58c` anytype + diskgenius；`8e4e6ae` diskgenius CDN 直链；`6e09170` src 源追平产物；`0f9036f` autoglm 检查接口；`1c173e5` qq-nt GitHub 镜像架构；`1453f4f` qq-nt 签名下载器；`dce6221` 签名机制进 checkver；`aba461f` qq-nt 防降级 + codebuddy 域名；`25bf55f` qq-nt 9.9.36 镜像；`3baea25` bageshuo 模板；`6993aae` open-pencil 去 throw；`049c7a2` checkver 五源修复；`7fb60a0` zcode 快捷方式；`1d97e08` douyin-ide；`156be44` virtual-browser 哈希；`6ed06b2` checkver GitHub API 模式；`9cb5e8b` workbuddy env_set（本次）。
- 新清单/新能力：`8c31537` chatcut；`d825159`/`891122a` 网易叭哥说；`dd439ff`/`1fd91b8` rebased；`3e3d4b4` claude-code；`178164d` herdr；`cc53987` diskgenius 蓝奏云→Release；`75217ec` qqnt-mirror 两缺陷修复。
- 回退事故留证：`782468f` zcode 3.7.7（excavator 回退手改版本）。

## 9. 通读范围与证据（可复核）

用 `agent-sessions` CLI 对 zcode 会话做了**全量**读取（只读）：

- 目录：`read sess_e39163be-57b2-4cf7-bb14-10b03947b35f --agent zcode` → 1754 条消息、676,636 字符。
- 正文：1–1754 全覆盖。50 条/段 36 段；其中 9 段触发 CLI 28K 截断 → 改用 10 条/段重取，2 段仍截断 → 逐条补齐 20 条单条。校验：1754 条无缺失、无重复、无截断。
- 精读：453 条「用户」消息中剔除 239 条系统注入（TodoWrite 提醒/task-notification/Note/Read 注入）后，**214 条真实用户消息按内容去重为 157 组全部通读**（45 份重复夜间任务书取最长 4271 字版）；**33 条夜巡汇总全文**；159 条 ≥300 字助手结论索引全读，并对约 30 条关键结论全文精读（索引 30/44/106/160/178/227/378/380/865/877/1135/1145/1219/1404/1407/1429/1451/1479/1485/1563 等）。
- 未逐字阅读：约 1140 条助手过程叙述（工具调用/中间步骤，不含最终结论）与 239 条系统注入。结论性内容已由上述汇总、索引与精读覆盖。
- 原始会话文本仅作证据使用，不修改、不外传；本文不复制会话全文。
