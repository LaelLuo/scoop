# 开发规范和规则

- 版本检查最佳实践：使用scoop检查版本而非重复下载，利用缓存机制；checkver应使用重定向头而非updates页面，因为updates页面更新不及时
- 错误记录：之前错误地回避checkver问题而非解决，应该深入分析根本原因。autoupdate可以接受checkver返回结果进行变量替换，需要研究现有包的实现方式
- 需要创建Scoop开发踩坑文档，记录checkver脚本、autoupdate配置、重定向URL处理等常见问题和解决方案，避免重复踩坑
