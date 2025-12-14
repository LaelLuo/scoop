<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Codex Agent Briefing

## 仓库定位
- Scoop AI Tooling Bucket，聚焦 AI IDE、Agent、MCP 工具与开发效率组件。
- 生产清单位于 `bucket/`，**不可直接编辑**；一切改动需先修改 `src/bucket/*.json[c]`，再执行 `bun scripts/build.ts [--only <manifest>]` 生成产物。

## 清单规范
1. **源文件 (`src/bucket`)**
   - 支持 JSON/JSONC，可添加注释。
   - 推荐使用 `portableProfile` 声明便携化逻辑：
     ```jsonc
     "portableProfile": {
       "mappings": [
         {
           "label": "roaming",
           "source": "AppData/MyApp",
           "target": "$persist_dir/roaming",
           "strategy": "symlink",
           "ensureTarget": true,
           "migrateFrom": ["$dir/data"],
           "targetType": "directory"
         }
       ],
       "cleanup": { "removeAfterMigrate": ["$dir/data"] },
       "options": { "log": true }
     }
     ```
   - `targetType` 可选 `directory`（默认）/`file`，后者用于阻挡文件（如 updater placeholder）。

2. **构建输出 (`bucket`)**
   - 由 `build.ts` 自动注入标准化 PowerShell 函数（见 `scripts/portable.psm1`），包含安装/卸载生命周期脚本。
   - 任何手写的便携化脚本应优先转为 `portableProfile`；仅保留必要的安装附加操作（如迁移遗留文件、链接 bun/uv）。

## 工具链
- `bun scripts/build.ts`：全量构建；`--only <pkg>` 支持增量。
- `bin/checkver.ps1` / `bin/checkhashes.ps1` / `bin/checkurls.ps1`：版本、哈希与链接校验。
- `bin/formatjson.ps1`：保证 JSON 排版一致。
- `Scoop-Bucket.Tests.ps1`：运行 Pester 测试，确保便携化脚本涵盖主流程。

## 工作流要求
1. 编辑清单 → 运行 `bun scripts/build.ts --only <manifest>` → 提交 `src/` 与 `bucket/` 的双写结果。
2. 渐进迁移：旧的 `post_install`/`pre_uninstall` 逻辑应逐步下线，统一使用 `portableProfile`。
3. CI/PR 前需执行构建与测试，避免 `bucket` 与 `src` 不一致。
4. README 已记录 `src → bucket` 流程，如有新约定需同步更新文档。

牢记：**修改 `bucket/` 无法通过审查**，必须回到 `src/` 源头修正。*** End Patch
