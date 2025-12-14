# Change: 添加 CrossDesk Scoop 清单

## Why
CrossDesk 是一款轻量级跨平台远程桌面软件（含 Web Client）。当前 bucket 未收录该工具，用户需要手动下载安装包，难以与现有的便携化工作流（`portableProfile` + `$persist_dir`）集成。

## What Changes
- 新增 `crossdesk` 清单（源文件：`src/bucket/crossdesk.jsonc`；构建产物：`bucket/crossdesk.json`）。
- Windows 安装方式采用 GitHub Release 的 `crossdesk-win-x64-*.exe`（NSIS）并通过 `#/dl.7z` 直接解包获取 `crossdesk.exe`（避免运行安装器与管理员权限需求）。
- 使用 `portableProfile` 便携化：
  - `%APPDATA%\CrossDesk` → `$persist_dir/roaming`
  - `%LOCALAPPDATA%\CrossDesk` → `$persist_dir/local`
- 增加 `checkver`/`autoupdate`，从 GitHub Releases 获取最新版本并自动拼接下载 URL。

## Impact
- Affected specs: `scoop-manifest-crossdesk`（新增）
- Affected code (apply 阶段):
  - `src/bucket/crossdesk.jsonc`（新增）
  - `bucket/crossdesk.json`（由 `bun scripts/build.ts --only crossdesk` 生成）

## Notes / Open Questions
- 上游 NSIS 包内包含证书文件 `crossdesk.cn_root.crt`（路径形如 `$APPDATA\CrossDesk\certs\...`）。目前上游发布说明提到已用“证书指纹校验”替代根证书校验，因此证书文件可能并非必需。
  - 建议默认策略：**仅在解包存在该文件且目标持久化目录不存在时复制**，以尽量对齐官方安装器行为，同时不强依赖它。
