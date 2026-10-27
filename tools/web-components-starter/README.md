# 可复用 Web 起步项目

这是组件工程模板，提供六视角选择器的独立演示与测试，不包含已完成的模型转换算法。

要求 Node.js 22.12+ 与 pnpm 11。首次运行：

```powershell
pnpm install --frozen-lockfile
pnpm dev
```

常用命令：

```powershell
pnpm check          # 类型、lint、组件测试、生产构建
pnpm format         # 自动整理格式
pnpm test:e2e       # 浏览器交互测试
pnpm build:lib      # 将可复用组件和类型构建为内部库
```

浏览器测试默认使用本机 Edge；其他电脑可运行 `pnpm exec playwright install chromium`，随后在没有 Edge 的环境自动使用 Chromium。持续集成配置会安装 Chromium。首次安装浏览器需要联网，组件自身不依赖服务器。

## 目录

```text
src/components/  可复用 UI 组件及组件测试
src/core/        数据类型、转换服务契约
src/demo/        用于查看和操作组件的页面
src/styles/      共用颜色、间距和外观
tests/          浏览器交互测试
docs/           模块边界与后续迁移记录
.github/        自动检查配置模板
```

先在一个仓库中按模块管理。第二个项目需要同一套组件时，可用 `pnpm build:lib` 输出 `dist-lib` 和类型声明，再决定是否拆成独立包。当前 package.json 是 private，不会误当成已发布 npm 包。

本目录附带 Git 忽略规则和 CI 配置，但是否已初始化 Git、是否实际运行 GitHub Actions，请以交付验证记录为准；仅有文件不代表远程配置生效。
