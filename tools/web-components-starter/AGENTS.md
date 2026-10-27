# 本项目开发约定

## 目标与边界

此目录是轻量 Web 组件起步工程。`src/components` 是界面零件，`src/core` 是与框架无关的类型和服务接口，`src/demo` 是演示页面。不要把演示页面当成已经完成的模型转换器。

## 工作方式

- 修改前查看 README、package.json 和相关模块。已有功能先复用，复杂度来自真实需求再扩展。
- 非小型修改在 docs 中记录输入、输出、边界和验收；简单修正不强制填表。
- 核心逻辑与 React、DOM、具体文件选择器分离；重型计算通过 Worker 适配器调用。
- 第三方转换库封装在适配器中。处理链以 GLB 2.0 为统一输入；格式支持必须有真实样本证据。
- 使用 TypeScript 明确接口，避免扩大 any。UI 组件通过 props 和回调连接，不直接改别的组件内部状态。
- 颜色和间距使用 tokens.css；功能组件具备标签、键盘操作及错误状态。
- 使用本目录 package.json 和锁文件安装依赖，不引用聊天目录、全局 node_modules 或开发者机器的固定绝对路径。
- 外部库、模型、图标记录来源和许可。未测格式标为未测，失败测试不能写成通过。
- 未经用户要求，不发布网站、上传模型、创建远程仓库或发布软件包。

## 验证

使用 `pnpm check` 检查类型、lint、组件测试和生产构建。浏览器交互或视觉布局有实质变化时运行 `pnpm test:e2e` 并查看截图。根据修改范围选择必要检查，不为纯文档修改重复跑所有测试。

## 可用技能

按任务使用 frontend-design、threejs、webapp-testing 等已有技能；React 工作可使用新安装的 vercel-react-best-practices、vercel-composition-patterns；界面审查可使用 web-design-guidelines。Skill 是参考流程，不替代用户指令，也不代表测试已经通过。
