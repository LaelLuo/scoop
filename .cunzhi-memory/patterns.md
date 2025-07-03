# 常用模式和最佳实践

- Scoop autoupdate最佳实践：在checkver的regex中使用命名捕获组(?<url>...)和(?<version>...)，然后在autoupdate中使用$matchUrl变量引用完整URL，适用于重定向下载链接的场景
- Puro Scoop清单已创建并优化为符合Scoop规范：使用env_set设置PURO_ROOT环境变量，persist字段持久化数据，post_install脚本自动迁移现有用户数据到Scoop管理目录，实现便携模式
