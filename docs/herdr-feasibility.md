# Herdr 收录可行性

核实日期：2026-10-09；对应 GOALS add-herdr 修订 1。这是实施前的证据，不代表 Scoop 清单已完成。

## 已验证前提

- [官方稳定 Release v0.9.3](https://github.com/herdrdev/herdr/releases/tag/v0.9.3)：Windows 资产为 herdr-windows-x86_64.zip，9,846,312 字节；官方 GitHub digest 与本地下载 hash 均为 c75b1fa49f7a3ba4b8b11789912a6147e4214a3b6fd3556d0f80076c8887d795。gh release download 后 Get-FileHash 与 Bun crypto 独立核实一致。
- 7z l/x 显示共 7 文件：herdr.exe、conpty/conpty.dll、conpty/herdr-conpty.json、conpty/x64/OpenConsole.exe、conpty/arm64/OpenConsole.exe、两个 THIRD-PARTY-NOTICES 文件。ARM64 的 ConPTY 辅助文件不等于存在 Herdr ARM64 原生构建。
- workdir/herdr/probe-package.ts 在独立 XDG_CONFIG_HOME/XDG_STATE_HOME 下、显式清除继承 HERDR_CONFIG_PATH 后调用原始官方二进制；--version 输出 herdr 0.9.3，--help 正常、config check 输出 config: ok、channel show 输出 stable；均退出 0。结果保存在 workdir/herdr/probe-result.json。没有启动服务、修改用户 PATH 或安装到日常 Scoop。
- [v0.9.3 config/io.rs](https://github.com/herdrdev/herdr/blob/v0.9.3/src/config/io.rs)：Windows 默认 config_dir=APPDATA/herdr、state_dir=LOCALAPPDATA/herdr；XDG_CONFIG_HOME/XDG_STATE_HOME 优先，HERDR_CONFIG_PATH 可覆盖配置文件。插件配置和插件状态分别跟随这两个目录，见 [plugin_paths.rs](https://github.com/herdrdev/herdr/blob/v0.9.3/src/plugin_paths.rs)。
- [v0.9.3 update.rs](https://github.com/herdrdev/herdr/blob/v0.9.3/src/update.rs) 顶部与 Windows 更新函数：后台仅提示有更新；显式 herdr update 才下载并调用内嵌独立安装脚本。Windows 不识别 Scoop 包管理路径，因此不能承诺该命令受 Scoop 管理。脚本默认将包放 USERPROFILE/.herdr/packages/standalone，并为 LOCALAPPDATA/Programs/Herdr/bin 设置入口/PATH，见 [distribution/install.ps1](https://github.com/herdrdev/herdr/blob/v0.9.3/distribution/install.ps1)。
- Scoop 现有 cunzhi 清单使用 GitHub checkver 和 v$version 资产模板；github-stars-manager/zcode 使用同一 portableProfile 的 AppData 等语义路径。独立审核发现 scripts/portable.psm1 的复制静默吞错后仍删除原目录；本批次不得运行已有普通目录的数据迁移分支。增加 Herdr 安装前路径校验，仅接受不存在或本清单自己的 persist 符号链接，其余停止并保留；不修改公共助手。
- workdir/herdr/guard-probe.ps1 与 probe-guard.ts 为隔离可行性原型，尚未放进正式清单；12 个边界符合预期且样本/链接保持：源缺失、本清单有效链接、普通目录、普通文件、外来链接、失效链接、第二入口冲突、persist 目标为文件、junction、源父目录未创建、persist 父目录未创建、无效路径。两个入口全部只读检查完才允许映射，缺失父目录与检查错误区别处理。结果为 workdir/herdr/guard-result.json；权限故障的真实 ACL 场景及正式钩子整合仍待实施验收。

## 推荐方案与验证边界

方案写在 GOALS 与 decisions.md：完整官方 ZIP、x64、herdr 命令、GitHub 稳定版更新、两个默认目录持久化，已有独立数据或外来链接时停止安装保留原状。notes 指引更新用 Scoop、已有数据需先处理，保留用户自定义路径及检查偏好，不注入 agent 配置。

放行后验证实际 Scoop 安装入口、ConPTY 启动、hash 失败、既有样本/外来链接安全停止、同版本强制更新、卸载保留，以及全量 checkver。默认路径验收使用隔离 APPDATA/LOCALAPPDATA 并清除子进程 XDG/配置覆写，自定义路径另验，避免路径绕过让测试失真。未来跨版本兼容不能提前验证，不冒充已覆盖。

## 探索工具限制

系统 openspec 入口受 Node v24.15.0 shim 缺失影响；同一已安装 OpenSpec 的 E:/Library/bun/global/node_modules/@fission-ai/openspec/bin/openspec.js 用 Bun 运行正常，list 显示原 add-crossdesk-manifest 已完成、无已落地 specs。未安装新工具或修改系统运行时。
