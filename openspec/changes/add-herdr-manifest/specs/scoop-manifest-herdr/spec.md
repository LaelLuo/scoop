## ADDED Requirements

### Requirement: 官方 Windows 稳定版安装
清单 SHALL 使用官方 Windows x64 稳定 ZIP，保留完整 ConPTY 与第三方许可证文件，提供 herdr 命令入口并核对 SHA-256。

#### Scenario: 安装并启动
- **WHEN** 在隔离 Scoop 安装 Herdr
- **THEN** herdr --version 与清单一致，完整包文件保留，独立终端进程能解析命令并启动后正常退出。

#### Scenario: 错误校验和
- **WHEN** 下载内容的 SHA-256 与清单不符
- **THEN** Scoop 阻止安装，不将错误内容激活为 current。

### Requirement: 稳定版自动检测与更新
清单 SHALL 从官方 GitHub stable release 检测版本，用 v$version 下载同名 x64 ZIP，通过既有构建同步源与产物。

#### Scenario: 检测与生成
- **WHEN** 查询 checkver 并构建清单
- **THEN** 版本与官方 stable release 一致，autoupdate 资产存在，源与生成产物一致且全量 checkver 不因本清单引入失效。

#### Scenario: 正在运行
- **WHEN** Herdr 占用其程序文件而无法升级
- **THEN** 沿用 Scoop 的占用处理，维护任务不结束 Herdr 或其中的 agent 进程。

### Requirement: 用户数据与更新入口
清单 SHALL 使用既有 portableProfile 持久化默认 AppData/herdr 和 LocalAppData/herdr，保留升级/卸载后的 persist 数据，尊重自定义路径，说明 Scoop 更新命令，不改变其他 agent 配置。安装前仅接受默认源路径不存在或已指向本清单 persist 的符号链接，其余状态必须停止安装并保留原状。

#### Scenario: 映射与生命周期
- **WHEN** 干净首次安装创建映射后执行同版本强制更新及卸载
- **THEN** 数据保持在 persist，卸载只解除映射链接且不删除 persist 内容。

#### Scenario: 既有数据或外来链接
- **WHEN** 默认路径已有普通目录/文件、外来或失效链接，或不能可靠检查
- **THEN** 停止安装，原数据/链接与已有 persist 保持不变，不执行自动复制删除迁移。

#### Scenario: 用户路径覆写
- **WHEN** 用户设置 XDG_CONFIG_HOME、XDG_STATE_HOME 或 HERDR_CONFIG_PATH
- **THEN** 清单不覆盖这些设置，notes 说明自定义数据路径由用户管理，更新使用 scoop update herdr。
