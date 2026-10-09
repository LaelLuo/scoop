# Change: 新增 Herdr Scoop 清单

## Why

用户接管 Scoop 维护并要求新增收录 herdrdev/herdr。官方 Windows 稳定包可直接分发，需让安装、命令入口、持久化和升级归 Scoop 管理。

## What Changes

- 新增 Windows x64 Herdr 完整 ZIP 清单，保留 ConPTY 及许可证，提供 herdr 命令。
- GitHub 稳定版 checkver/autoupdate；默认 AppData 与 LocalAppData 使用既有 portableProfile 映射。安装前只允许路径不存在或已指向本清单 persist 的符号链接；已有数据目录/文件、外来或失效链接及检查失败时停止安装并保持原状。
- notes 说明 Scoop 更新入口与自定义路径边界；不修改 Herdr 上游，不触碰用户 agent 配置，不在用户日常环境安装。

## Impact

- 新增 src/bucket/herdr.json 与对应生成 bucket/herdr.json。
- 设计、验收、授权以 [GOALS](../../../GOALS.md) 的 add-herdr 修订 1 为准；详细决策见 [decisions](../../../decisions.md)，证据见 [可行性](../../../docs/herdr-feasibility.md)。
- 当前仅方案，未获得正式实施放行。
