# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个Scoop bucket项目，专门收录AI开发工具和编辑器的便携化清单。Scoop是Windows包管理器，此bucket包含如Cursor、OOMOL Studio、LM Studio等AI/开发工具的清单文件。

## 核心架构

### 目录结构
- `bucket/` - 应用清单文件(JSON)，定义下载、安装和便携化配置
- `bin/` - PowerShell脚本，用于测试、验证、格式化清单文件
- `docs/` - 文档目录，包含详细的清单配置模式规范
- `deprecated/` - 废弃的清单文件

### 清单文件规范
遵循Scoop清单格式，包含基础元数据、下载配置、便携化脚本和数据持久化配置。

## 开发命令

### 清单管理
```powershell
# 检查单个清单版本更新
bin/checkver.ps1 <清单名>

# 自动更新清单(利用缓存)
bin/checkver.ps1 <清单名> -u

# 批量检查版本
bin/checkver.ps1

# 验证哈希值
bin/checkhashes.ps1 <清单名>

# 检查URL有效性
bin/checkurls.ps1 <清单名>

# 格式化JSON
bin/formatjson.ps1 <清单名>
```

### 测试
本地没有 Pester 测试环境，测试由 CI 自动执行。

## 清单开发模式

### 基础结构
参考 `@docs/scoop-manifest-patterns.md` 中的详细规范：
- 基础元数据：version, description, homepage, license
- 下载配置：architecture(推荐64bit单架构), hash(优先SHA256)
- 安装解压：innosetup, extract_dir, 7zip处理

### InnoSetup应用处理
使用 `innounp.exe -t installer.exe` 检测，配置：
```json
{
    "innosetup": true,
    "extract_dir": "{code_GetDestDir}"
}
```

### 便携化实现模式
参考文档中的四种模式：
1. **Junction Points模式** - 完全重定向系统目录
2. **阻止文件夹创建模式** - 创建blocker文件
3. **快捷方式参数模式** - 通过命令行参数指定数据目录  
4. **环境变量模式** - 通过环境变量控制数据位置

## 开发最佳实践

### 缓存优化策略
开发时减少重复下载：
1. 临时降低清单版本号到已知版本
2. 使用 `checkver -u` 利用Scoop缓存机制
3. 缓存位置：`$env:SCOOP/cache`

### 网络请求优化
避免不必要的下载：
```powershell
# ✅ 只获取头部信息
$response = Invoke-WebRequest -Uri $url -Method Head

# ✅ 捕获重定向
try {
    $response = Invoke-WebRequest -Uri $url -MaximumRedirection 0 -ErrorAction Stop
} catch {
    if ($_.Exception.Response.StatusCode -eq 302) {
        $redirectUrl = $_.Exception.Response.Headers.Location
    }
}
```

### 便携化注意事项
- Junction points需要管理员权限或开发者模式
- 数据迁移前确保备份成功
- 路径处理使用双引号和 `-Force` 参数
- 添加友好的用户提示和错误处理

## 参考示例

现有清单提供最佳实践参考：
- `oomol.json` - 复杂便携化和junction points实现
- `cursor.json` - InnoSetup应用标准处理  
- `puro.json` - 环境变量和数据迁移
- `notion.json` - 7zip解压和便携化
