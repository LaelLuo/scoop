# 常用模式和最佳实践

- Scoop autoupdate最佳实践：在checkver的regex中使用命名捕获组(?<url>...)和(?<version>...)，然后在autoupdate中使用$matchUrl变量引用完整URL，适用于重定向下载链接的场景
