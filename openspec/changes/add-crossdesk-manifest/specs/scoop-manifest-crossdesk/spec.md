## ADDED Requirements

### Requirement: CrossDesk 清单
系统 SHALL 在该 bucket 中提供名为 `crossdesk` 的 Scoop 清单，用于在 Windows 10+ x64 上安装 CrossDesk 客户端。

#### Scenario: 用户安装 CrossDesk
- **WHEN** 用户执行 `scoop install <bucket>/crossdesk`
- **THEN** Scoop SHALL 从 GitHub Releases 下载 Windows x64 资产并完成安装
- **AND** 安装过程 SHALL 不运行上游 NSIS 安装器（避免管理员权限与系统级改动）
- **AND** 用户 SHALL 获得可用的 `CrossDesk` 快捷方式

### Requirement: 便携化数据目录
清单 SHALL 使用 `portableProfile` 将 CrossDesk 的用户数据持久化到 `$persist_dir`，至少覆盖以下目录：
- `%APPDATA%\CrossDesk`
- `%LOCALAPPDATA%\CrossDesk`

#### Scenario: 重装后数据保持
- **GIVEN** 用户已运行过 CrossDesk 并产生配置/缓存
- **WHEN** 用户卸载并重新安装 `crossdesk`
- **THEN** CrossDesk 的配置与缓存 SHALL 仍然可用（来自 `$persist_dir`）

### Requirement: 自动更新
清单 SHALL 支持通过 GitHub Releases 获取版本并自动更新下载地址（`checkver`/`autoupdate`）。

#### Scenario: 上游发布新版本
- **GIVEN** 上游发布了新的 Release tag（形如 `v<version>`）
- **WHEN** 维护者执行 `bin/checkver.ps1 crossdesk -u`
- **THEN** 清单版本与下载地址 SHALL 能被正确更新
