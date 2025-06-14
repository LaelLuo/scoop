# Scoop 开发踩坑指南

> 基于 Oomol Studio 包开发过程中遇到的问题和解决方案整理

## 📋 目录

- [checkver 相关问题](#checkver-相关问题)
- [autoupdate 配置问题](#autoupdate-配置问题)
- [下载和哈希问题](#下载和哈希问题)
- [测试和调试技巧](#测试和调试技巧)
- [最佳实践总结](#最佳实践总结)

## checkver 相关问题

### 问题1：脚本方式的 checkver 不工作

**❌ 错误做法**：
```json
"checkver": {
    "script": "$response = Invoke-WebRequest -Uri 'https://example.com/latest' -MaximumRedirection 0; if ($response.Headers.Location -match 'v([\\d.]+)') { $matches[1] }"
}
```

**错误信息**：
```
oomol: couldn't match '@{script=System.Object[]}' in the output of script
```

**✅ 正确做法**：
```json
"checkver": {
    "script": [
        "$response = Invoke-WebRequest -Uri 'https://update.oomol.com/latest/win32-x64-user/stable' -MaximumRedirection 0 -ErrorAction SilentlyContinue",
        "$url = $response.Headers.Location",
        "if ($url -match 'Studio-([0-9.]+)-') { $url }"
    ],
    "regex": "(?<url>.*Studio-(?<version>[\\d.]+)-.*\\.exe)"
}
```

**关键点**：
- 脚本必须是数组格式
- 必须配合 `regex` 字段使用
- 脚本输出完整信息，regex 负责提取版本号

### 问题2：重定向 URL 的处理

**场景**：应用使用重定向机制提供下载链接

**❌ 错误做法**：
```json
"checkver": {
    "url": "https://example.com/updates/",
    "regex": "version ([\\d.]+)"
}
```

**问题**：更新页面信息不及时，无法获取真实下载链接

**✅ 正确做法**：
```json
"checkver": {
    "script": [
        "$response = Invoke-WebRequest -Uri 'https://update.oomol.com/latest/win32-x64-user/stable' -MaximumRedirection 0 -ErrorAction SilentlyContinue",
        "$url = $response.Headers.Location",
        "if ($url -match 'Studio-([0-9.]+)-') { $url }"
    ],
    "regex": "(?<url>.*Studio-(?<version>[\\d.]+)-.*\\.exe)"
}
```

**关键点**：
- 使用 `-MaximumRedirection 0` 获取重定向头
- 从 `$response.Headers.Location` 获取真实下载链接
- 脚本输出完整 URL，供 autoupdate 使用

### 问题3：命名捕获组的使用

**❌ 错误做法**：
```json
"regex": "([\\d.]+)"
```

**问题**：只能捕获版本号，无法为 autoupdate 提供 URL

**✅ 正确做法**：
```json
"regex": "(?<url>.*Studio-(?<version>[\\d.]+)-.*\\.exe)"
```

**关键点**：
- 使用 `(?<version>...)` 捕获版本号
- 使用 `(?<url>...)` 捕获完整 URL
- autoupdate 可以使用 `$matchUrl` 引用捕获的 URL

## autoupdate 配置问题

### 问题1：动态文件名的处理

**场景**：下载文件名包含动态日期或构建号

**示例文件名**：`OOMOL Studio-1.2.4-2025-06-13.10.exe`

**❌ 错误做法**：
```json
"autoupdate": {
    "architecture": {
        "64bit": {
            "url": "https://static.oomol.com/release/stable/win32/x64/OOMOL%20Studio-$version-$date.exe"
        }
    }
}
```

**问题**：无法预测日期部分

**✅ 正确做法**：
```json
"autoupdate": {
    "architecture": {
        "64bit": {
            "url": "$matchUrl"
        }
    }
}
```

**关键点**：
- 使用 `$matchUrl` 引用 checkver 捕获的完整 URL
- 避免尝试预测动态部分

### 问题2：$matchUrl 变量的使用

**前提条件**：checkver 的 regex 必须包含命名捕获组 `(?<url>...)`

**示例**：
```json
"checkver": {
    "script": ["..."],
    "regex": "(?<url>.*Studio-(?<version>[\\d.]+)-.*\\.exe)"
},
"autoupdate": {
    "architecture": {
        "64bit": {
            "url": "$matchUrl"
        }
    }
}
```

## 下载和哈希问题

### 问题1：aria2 下载器问题

**错误信息**：
```
ERROR: Failed to download https://example.com/file.exe
```

**解决方案**：
```powershell
# 临时禁用 aria2
scoop config aria2-enabled false

# 重新尝试安装
scoop install .\bucket\app.json

# 安装完成后可以重新启用
scoop config aria2-enabled true
```

### 问题2：哈希值不匹配

**场景**：文件在下载过程中被更新，导致哈希值变化

**解决方案**：
1. 使用 Scoop 的缓存机制检查版本
2. 从错误信息中获取正确的哈希值
3. 更新包定义中的哈希值

**示例**：
```
Hash check failed!
Expected: abc123...
Actual:   def456...
```

更新包定义：
```json
"hash": "def456..."
```

## 测试和调试技巧

### 1. 手动测试 checkver 脚本

```powershell
# 测试重定向获取
$response = Invoke-WebRequest -Uri 'https://update.oomol.com/latest/win32-x64-user/stable' -MaximumRedirection 0 -ErrorAction SilentlyContinue
$url = $response.Headers.Location
Write-Host "Redirect URL: $url"

# 测试正则表达式
if ($url -match 'Studio-([0-9.]+)-') { 
    Write-Host "Version found: $($matches[1])" 
}
```

### 2. 使用 checkver 工具

```powershell
# 检查版本
.\bin\checkver.ps1 app-name

# 测试自动更新
.\bin\checkver.ps1 app-name -u

# 检查特定目录
.\bin\checkver.ps1 -Dir .\bucket app-name
```

### 3. 安装测试流程

```powershell
# 1. 卸载现有版本
scoop uninstall app-name

# 2. 安装新版本
scoop install .\bucket\app-name.json

# 3. 检查安装状态
scoop list app-name

# 4. 测试应用启动
app-name --version
```

## 最佳实践总结

### 1. 开发流程

1. **信息收集**：使用 `codebase-retrieval` 查看现有类似包
2. **参考官方文档**：查看 Scoop Wiki 和官方示例
3. **逐步测试**：先测试 checkver，再测试 autoupdate
4. **完整验证**：测试安装、卸载、更新流程

### 2. 问题解决思路

1. **不要回避问题**：深入分析根本原因
2. **查看现有示例**：学习类似包的实现方式
3. **手动测试脚本**：确保逻辑正确再集成
4. **记录解决方案**：避免重复踩坑

### 3. 代码质量

1. **使用命名捕获组**：提高可读性和功能性
2. **处理错误情况**：添加 `-ErrorAction SilentlyContinue`
3. **添加注释说明**：解释复杂的逻辑
4. **遵循官方规范**：使用标准的字段和格式

## 参考资料

- [Scoop Wiki - App Manifests](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
- [Scoop Wiki - App Manifest Autoupdate](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifest-Autoupdate)
- [官方包示例](https://github.com/ScoopInstaller/Extras/tree/master/bucket)

---

*最后更新：2025-06-14*  
*基于 Oomol Studio 包开发经验整理*
