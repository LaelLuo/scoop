# Herdr 安装与更新

在 PowerShell 7（pwsh）中执行；非管理员创建符号链接需要 Windows Developer Mode。

```powershell
scoop bucket add laelluo https://github.com/LaelLuo/scoop
scoop install laelluo/herdr
herdr
```

已经添加该 bucket 时直接安装即可。清单提供官方 Windows x64 稳定版，包含终端运行组件。更新使用 `scoop update herdr`；Herdr 自带的 `herdr update` 会调用独立安装器并产生另一套安装。

默认配置 `%APPDATA%/herdr` 映射到 Scoop 的 `persist/herdr/roaming`，默认状态 `%LOCALAPPDATA%/herdr` 映射到 `persist/herdr/local`。普通 `scoop uninstall herdr` 保留 persist 数据，重装可复用。使用 `--purge` 会按 Scoop 的语义删除持久化数据。

默认路径已经存在数据目录、文件、外来/失效链接时，安装会报路径并停止，保留原内容。请先备份并处理冲突路径，再安装；清单没有自动迁移。卸载遇到被替换的路径同样保留并停止。

自定义 XDG_CONFIG_HOME、XDG_STATE_HOME 或 HERDR_CONFIG_PATH 继续由 Herdr 读取，自定义数据路径由用户自行管理。清单只安装 Herdr；应用首次启动的可选 agent 集成由用户另行决定。
