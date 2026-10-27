# Design Workflow Toolkit

从实际设计与开发任务中整理的 7 个工具和 AI 工作流：3 个代码工具、4 个 skills。重点是可复用流程、可检查的交付，以及清楚的能力边界。

English: A curated collection of practical design utilities and AI-assisted workflows. Includes source code, reusable skills, usage notes, and explicit third-party attribution.

| 项目 | 解决的问题 | 入口与运行方式 |
|---|---|---|
| 桌面文件工作台 | 文件基线、近期整理、项目归档 | [PowerShell 工具](tools/desktop-organizer/README.md)，Windows PowerShell 5.1 |
| 黑白底片边框检测器 | 从预览图提取可信裁切坐标 | [Python 检测器](tools/autocrop-bw-detector/README.md)，基于 CC0 AutoCrop 的适配 |
| Web 组件工程起步包 | 将界面组件、契约、演示和测试分开 | [React + TypeScript 模板](tools/web-components-starter/README.md)，含六视角选择器 |
| Competition PPT Template First | 从事实证据到模板、可编辑内容和渲染复核 | [Skill](skills/competition-ppt-template-first/SKILL.md)，含初始化和验证脚本 |
| Product Analysis Report | 让设计决策、方案比较与验证形成推理链 | [Skill](skills/product-analysis-report/SKILL.md) |
| Poster to Editable PSD | 海报拆层、文字可编辑与视觉保真检查 | [Skill](skills/poster-to-editable-psd/SKILL.md)，需宿主图像/Photoshop 能力 |
| 新生辩论备赛导师 | 审题、举证责任、比较、质询与复盘 | [Skill](skills/xinguobian-debate-mentor/SKILL.md) |

## 使用 skills

将需要的单个 skill 文件夹复制到所用 Agent 的 skills 目录，保留其中的 `SKILL.md`、`references`、`templates` 和 `scripts`。宿主须支持 skills；实际图像、PPT 或 Photoshop 操作依赖宿主工具。纯文本 skill 是工作流说明，不是独立运行的软件，也不会自带模型服务或 API 额度。

例如：

```text
使用 product-analysis-report，把我的项目证据整理成方案比较和验证计划；缺失的证据明确标注。
```

模板工作区可单独生成：

```sh
python skills/competition-ppt-template-first/scripts/init-report-grounded-deck.py ./my-deck-workspace
python skills/competition-ppt-template-first/scripts/validate-package.py
python skills/competition-ppt-template-first/scripts/test-workspace-contract.py
```

## 发布范围与验证

本次只从白名单复制源码和通用文档，未导入原 Git 历史。原始项目素材、简历信息、公司模板、通信配置、运行时和第三方安装包不随仓库发布。桌面工具默认分类中的个人项目名称已泛化。

验证结果见 [VALIDATION.md](VALIDATION.md)。未完成的集成测试明确保留为未测，不把存在测试文件当成测试通过。

本项目使用 AI 辅助开发与整理；AutoCrop 是明确标注的上游适配，其他依赖不作为原创成果。许可与来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
