## 1. Implementation
- [x] 新增 `src/bucket/crossdesk.jsonc`（字段顺序与现有清单保持一致）
- [x] 使用 GitHub Release Windows x64 资产（NSIS）并通过 `#/dl.7z` 解包获取 `crossdesk.exe`
- [x] 添加 `shortcuts`（`CrossDesk`）
- [x] 添加 `portableProfile` 映射：
  - [x] `AppData/CrossDesk` → `$persist_dir/roaming`
  - [x] `LocalAppData/CrossDesk` → `$persist_dir/local`
- [x] （可选）如上游包内包含 `crossdesk.cn_root.crt`：在 `post_install` 中按需复制到 `$persist_dir/roaming/certs/`
- [x] （可选）清理解包副产物目录（如 `$PLUGINSDIR`、`$APPDATA`）以保持安装目录整洁

## 2. Build
- [x] `bun scripts/build.ts --only crossdesk`

## 3. Validation
- [x] `bin/checkurls.ps1 crossdesk`
- [x] `bin/checkhashes.ps1 crossdesk`
- [x] `bin/checkver.ps1 crossdesk -u`（验证能从 GitHub Releases 提取最新 tag）
- [x] `bun run tsc --noEmit --skipLibCheck`（跳过：该仓库无 `package.json`，且按用户要求不做 lint）
- [x] `./Scoop-Bucket.Tests.ps1`（跳过：缺少 `BuildHelpers`，按用户要求不安装依赖）

## 4. Manual Sanity (optional)
- [x] 本机实际安装/卸载验证：`scoop install <bucket>/crossdesk`、启动后确认能生成/读取持久化目录（不应写入真实 `%APPDATA%` / `%LOCALAPPDATA%`）（跳过：可选）
