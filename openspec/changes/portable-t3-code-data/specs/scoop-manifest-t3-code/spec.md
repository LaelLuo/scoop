## MODIFIED Requirements

### Requirement: T3 Code 用户数据持久化

清单 SHALL 将 `%USERPROFILE%/.t3`、活动 Electron profile `%APPDATA%/t3code-v2`、旧 profile `%APPDATA%/T3 Code (Alpha)` 与 `%APPDATA%/t3code` 纳入 Scoop persist。既有来源 SHALL 先复制到 persist staging，并核验相对路径、entry 类型和文件 SHA-256，且确认来源未变；校验通过后保留来源备份并激活 junction。迁移 SHALL 在 `pre_install` 且 T3 已停止时按路径顺序执行。一个路径失败后，已完成的映射、persist 内容和来源备份 SHALL 保持有效；修复失败路径后可重试。目标冲突、非本清单 reparse point、损坏 link、hash/copy/query 错误 SHALL 停止且不删除数据。`post_install` SHALL 只验证已激活映射。卸载后 SHALL 只解除指向精确 persist target 的本清单 link，不删除 persist 或来源备份。

#### Scenario: 首次安装且来源不存在

- **WHEN** 来源和 persist target 均不存在并运行 `pre_install`
- **THEN** 创建 persist 目录及来源 junction，之后 T3 写入的数据落在 persist

#### Scenario: 迁移一个既有目录

- **WHEN** 来源为普通目录、persist target 不存在且 T3 已停止
- **THEN** staging 副本通过目录树与 SHA-256 核验后，原来源改名为备份，persist target 激活并建立 junction

#### Scenario: 后续路径失败并重试

- **WHEN** 前一 mapping 已完成，而后一来源遇到冲突或验证错误
- **THEN** 前一 mapping、persist 数据和备份保持有效，后一来源不被删除；修复冲突后再次执行会识别前一 mapping 并继续

#### Scenario: 已有 persist 冲突

- **WHEN** 普通来源与 persist target 同时存在且树内容不同
- **THEN** 操作停止并保留两个目录及其内容，不创建备份或覆盖目标

#### Scenario: 外来 link、损坏 link 或嵌套 reparse point

- **WHEN** 来源 link 指向其他目标、link 断裂、目标不是普通目录或来源树含 reparse point
- **THEN** 操作失败关闭，相关路径和数据原样保留

#### Scenario: T3 正在运行

- **WHEN** 任一 T3 主进程或 resource monitor 存活，或进程状态无法查询
- **THEN** 在该架构 pre_install 的内层应用归档展开前停止，不修改数据路径

#### Scenario: Scoop post_install 异常

- **WHEN** Scoop 在 current、shim 和 persist 建立后遇到 post_install 验证错误
- **THEN** portable 数据映射仍保持有效；修复状态后可通过同版本重试恢复 installed metadata

#### Scenario: 卸载和重装

- **WHEN** Scoop 完成卸载或之后重装
- **THEN** 卸载只解除本清单拥有的 source link，persist 和来源备份不变；重装识别现有 persist 并重建 link

#### Scenario: T3 运行后 persist 数据变化

- **WHEN** T3 在成功迁移后新增或修改会话/设置数据，并再次执行 Scoop 生命周期检查
- **THEN** live persist target 继续有效，历史来源备份保留但不要求与 target 相同；update/uninstall/reinstall 检查不因新增数据失败
