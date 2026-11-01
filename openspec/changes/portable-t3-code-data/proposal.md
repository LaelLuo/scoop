# Change: T3 Code Scoop 数据便携化

## Why

T3 Code 的 Scoop 清单原先只阻挡 electron-updater，用户配置与会话仍留在默认 Windows profile。把这些默认路径接入 Scoop persist，才能让同一份状态跨 Scoop 更新保留并在卸载后继续留存。

## What Changes

- 将 `%USERPROFILE%/.t3`、活动 Electron profile `%APPDATA%/t3code-v2` 与两个旧 Local State fallback `T3 Code (Alpha)` / `t3code` 纳入 persist。
- 使用 T3 专属 portableProfile 模块逐路径迁移并保留来源备份；后续路径失败时之前完成的映射仍有效，修复后可重试续接。
- 通过构建器选项将进程门及迁移放在架构 `pre_install`，将只读检查放在 `post_install` / `pre_uninstall`，卸载后仅解除自有 link；继续阻挡应用内 updater。

## Impact

- 修改 T3 清单源/产物、portable hook 构建选项、清单专属 PowerShell 模块和合成 Pester 测试。
- 合成验证不安装或运行 T3；真实默认数据迁移经用户更正授权后执行，T3 优雅关闭，来源备份保留。
- 管理目标、原话、决策和证据记录于 Playground 的 scoop-admin 项目。
