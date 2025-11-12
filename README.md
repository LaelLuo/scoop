# Scoop AI Tooling Bucket

[![Tests](https://github.com/LaelLuo/scoop/actions/workflows/ci.yml/badge.svg)](https://github.com/LaelLuo/scoop/actions/workflows/ci.yml) [![Excavator](https://github.com/LaelLuo/scoop/actions/workflows/excavator.yml/badge.svg)](https://github.com/LaelLuo/scoop/actions/workflows/excavator.yml)

本仓库是一个面向 AI IDE、智能代理工具及开发者效率工具的 Scoop 桶。所有清单都经过便携化与持久化目录处理，可直接与官方 Scoop 仓库共存使用。

## Bucket 简介

- 聚焦 AI IDE、Agent、MCP 生态与本地 LLM 工具，如 Cursor、Trae、LM Studio、OOMOL 等。
- 兼容常用的前端/后端辅助工具（bun、pnpm、PocketBase、Puro），方便在同一 bucket 内完成环境搭建。
- 中文/英文双语软件并存，并针对需要登录或多目录数据的应用补充了 post-install 逻辑，开箱即可便携使用。
- `deprecated/` 用于存放下线的旧版本，方便追溯历史配置。

## 快速开始

### 1. 添加 bucket

```pwsh
# 可按需替换 bucket 名称（示例使用 lael-ai）
scoop bucket add lael-ai https://github.com/LaelLuo/scoop
```

### 2. 安装 / 更新应用

```pwsh
scoop install lael-ai/<manifest-name>
scoop update lael-ai/<manifest-name>
```

> 使用 `scoop update lael-ai` 可一次性同步整个 bucket。

## 清单一览

目前 bucket 收录 20+ 款 AI IDE、Agent、MCP 工具及开发辅助组件，可大致分为：

- **AI IDE / Agent**：Cursor、Trae（国内 / 国际版）、Kiro、CodeBuddy、Codex Flow、本地 Virtual Browser 等。
- **本地 LLM 与 MCP 工具**：LM Studio、OOMOL Studio、Anytype、MCP Language Server、Codex Rust、Cunzhi。
- **工程效率工具**：bun、pnpm、PocketBase、Puro、Project Graph、droid CLI、Feishu 等。

想了解完整清单，可直接浏览 `bucket/` 目录或运行：

```pwsh
Get-ChildItem bucket | Select-Object -ExpandProperty Name
```

如需查看单个清单详情，执行 `Get-Content bucket/<manifest>.json` 或使用 `jq`/`ast-grep` 等工具即可。

## 维护工作流

- `bin/checkver.ps1 <manifest> [-u]`：检查或更新清单版本号及下载地址。
- `bin/checkhashes.ps1 <manifest>`：校验并刷新安装包 SHA256 值。
- `bin/checkurls.ps1 <manifest>`：批量验证下载链接可用性。
- `bin/formatjson.ps1 <manifest>`：统一 JSON 排版，保持字段顺序一致。
- 复杂的便携化模式可参考现有清单（如 `oomol.json`、`cursor.json`、`puro.json` 等）实现。

## 测试与自动化

- 本地可通过 `bin/test.ps1` 或 `.\Scoop-Bucket.Tests.ps1` 运行 Pester 测试，确保清单与脚本可用。
- `ci.yml` 会在 PR / main 分支上执行格式校验与测试，阻止异常清单进入主干。
- `excavator.yml` 与 `bin/auto-pr.ps1` 负责批量检查上游版本并自动创建更新 PR。

## 贡献指南

欢迎 Issue / PR 帮助补充新的 AI 工具或修复既有清单。提交前请：

1. 阅读 [Scoop 官方 Manifest 规范](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)。
2. 参考本仓库现有清单的字段顺序与便携化模式，保持风格一致。
3. 为需要下线的应用将旧清单移动到 `deprecated/`，方便后续查阅。
4. 运行上文提到的脚本与测试，确保 CI 能顺利通过。

感谢所有贡献者一起完善 AI/开发工具的 Scoop 生态！
