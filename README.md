# Frontend Harness

前端 AI 开发工作流 skill。一键安装到 Claude Code / Cursor / Codex 等 45+ AI 工具。

9 个工作流覆盖日常开发全场景，内置智能降级 —— 高级功能没装也不卡流程。

## 一键安装

```bash
# 1. 安装 skill 到所有 AI 工具
npx skills add zhumo/frontend-harness

# 2.（Claude Code 用户）补充安装 hooks/settings/templates
bash .claude/skills/frontend-harness/scripts/postinstall.sh .
```

## 快速上手

1. `npx skills add zhumo/frontend-harness`
2. （Claude Code 用户）`bash .claude/skills/frontend-harness/scripts/postinstall.sh .`
3. 在对话中输入 `feat: 你的需求名` 开始
4. 首次触发会自动探测项目环境，生成 `.harness-env.json`（后续免检）
5. 将 `.harness-env.json` 加入 `.gitignore`

## 工作流矩阵

在对话中使用前缀触发对应工作流，无前缀按普通对话处理。

| 前缀 | 用途 | 一句话说明 | 什么时候用 |
|------|------|-----------|-----------|
| `feat:` | 新需求实现 | 从 PRD 到代码到审查，端到端完成一个功能 | 新功能、有 PRD、涉及多个组件/页面 |
| `bug:` | Bug 修复 | 定位根因 → 修复 → 验证，不搞副作用 | 页面报错、功能异常、样式错乱 |
| `change:` | 局部修改 | 明确改什么 → 改 → 验证，最小动刀 | 改样式/逻辑、调交互、产品反馈微调 |
| `refactor:` | 代码重构 | 不改行为只优化结构，改完自动验证 | 迁移 API 风格、抽取公共逻辑、降复杂度 |
| `init:` | 初始化需求目录 | 一键创建需求目录脚手架 + Playwright 配置选项 | 新需求开始前的准备工作 |
| `hotfix:` | 紧急修复 | 跳过完整审查的快速路径，修完给后续建议 | 线上 P0 故障，分秒必争 |
| `perf:` | 性能优化 | 量化分析 → 优化方案 → 基准对比验证 | Bundle 过大、加载慢、渲染卡顿 |
| `docs:` | 文档更新 | 轻量流程，改文档/注释不走完整验证 | 只改文档内容，不涉及功能代码 |
| `chore:` | 工程调整 | 依赖升级/配置修改 + 兼容性检查 | 升级依赖、改构建配置、调 CI/CD |

> **bug vs change 怎么分？** bug = 非预期行为（违反设计稿/需求文档），change = 预期调整（优化体验/调整规范）。

## 内置能力

| 能力 | 说明 |
|------|------|
| 框架检测 | 自动检测 Vue/React、UI 库、CSS 方案、monorepo，结果缓存到 `.harness-env.json` |
| PRD 解析 | docx/pdf 文档 → 结构化 Markdown（6 层降级方案，转换失败不中断流程） |
| Figma 解析 | 设计稿 → 组件树 + 状态矩阵（MCP 优先获取，无 MCP 自动降级为截图识别） |
| API 解析 | API 文档 → 接口清单 + 复用标注（三级匹配：精确 → 语义 → 上下文，附匹配置信度） |
| 资产扫描 | 扫描组件/hooks/api/store 等可复用资产（统一输出格式，扫描范围按项目规模自适应） |
| 代码审查 | 多维度审查 + 上下文感知（按页面类型适配，以用户流程为中心） |
| 测试执行 | 测试用例检查清单 / Vitest・Jest 运行 |
| Playwright 验证 | 功能验证 + UI 截图对比，帮你肉眼确认改动没搞坏页面（**可选，未配置不阻塞**） |
| 代码验证 | lint + format + build 验证链 |

## 能力矩阵

| 能力 | feat | bug | change | refactor | init | hotfix | perf | docs | chore |
|------|:----:|:---:|:------:|:--------:|:----:|:------:|:----:|:----:|:-----:|
| 框架检测 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ |
| PRD 解析 | ✅ | - | - | - | - | - | - | - | - |
| Figma 解析 | ✅ | - | - | - | - | - | - | - | - |
| API 解析 | ✅ | - | - | - | - | - | - | - | - |
| 资产扫描 | full | minimal | targeted | targeted | - | minimal | targeted | - | - |
| 代码审查 | 8维 | 2维 | 4维 | 3维 | - | - | - | - | - |
| 测试执行 | ✅ | - | ✅ | - | - | - | - | - | - |
| Playwright 验证 | ✅ | ✅ | ✅ | ✅ | - | - | - | - | - |
| 代码验证 | ✅ | ✅ | ✅ | ✅ | - | ✅ | ✅ | - | ✅ |

> Playwright 验证为**可选步骤**，未安装 Playwright 时自动跳过，不影响工作流正常执行。

## 开发体验亮点

- **环境一次检测，后续免检** — 首次触发自动探测项目框架/UI 库/CSS 方案/目录结构，结果缓存到 `.harness-env.json`
- **Playwright 截图对比** — 代码改动后自动跑功能验证 + UI 截图，帮你肉眼确认没搞坏页面（可选，没装也不影响）
- **智能门禁** — 在关键决策点（如实现方案确认、破坏性升级）暂停等你确认，不该停的地方不打断
- **全链路智能降级** — Figma MCP 没装？用截图。文档转换失败？6 层降级兜底。工具没配？自动跳过。永远不卡流程
- **MCP 优先的 Figma 解析** — 有 MCP 直接拿设计数据，没有也会提醒并自动降级
- **API 三级智能匹配** — 精确匹配 → 语义匹配 → 上下文匹配，附匹配置信度，减少手动对接

## 项目自适应

首次触发工作流时自动检测项目环境，生成 `.harness-env.json` 缓存：

- 框架类型（Vue/React）和版本
- UI 库（Element Plus / Ant Design / MUI 等）
- CSS 方案（SCSS / Tailwind / Less 等）
- 包管理器（pnpm / yarn / npm）
- monorepo 结构检测
- Playwright 配置检测（init 工作流提供配置引导）
- 所有关键目录路径自动探测

支持任何 Vue/React 前端项目，不绑定特定目录结构。

## 审批门禁

在关键决策点自动暂停等用户确认（标 ⏸️），不该停的地方不打断：

| 工作流 | 门禁时机 |
|--------|---------|
| `feat:` | 信息不足时询问补充；实现计划完成后等审批 |
| `bug:` | 修复可能影响其他功能时告知风险 |
| `change:` | 影响 >3 个文件时先输出方案等确认 |
| `refactor:` | 影响 >3 个文件时输出方案等确认 |
| `hotfix:` | 无门禁（快速路径），修复后输出后续建议 |
| `perf:` | 优化方案完成后等确认才动代码 |
| `docs:` | 无门禁（轻量流程） |
| `chore:` | 涉及 major 版本升级时输出 breaking changes 清单等确认 |

## Agent 兼容性

| Agent | skill 安装 | hooks | templates | 触发方式 |
|-------|:---------:|:-----:|:---------:|:--------:|
| Claude Code | `npx skills add` | postinstall.sh | postinstall.sh | 前缀触发 |
| Cursor | `npx skills add` | 不支持 | 不需要 | 前缀触发 |
| Codex | `npx skills add` | 不支持 | 不需要 | 前缀触发 |
| 其他 45+ agent | `npx skills add` | 不支持 | 不需要 | 前缀触发 |

## 目录结构

```
frontend-harness/
├── SKILL.md                    # 主入口（所有 agent 读这个）
├── README.md                   # 安装说明 + 能力概览
├── references/                 # 按需读取的子文档
│   ├── workflow-feat.md        # feat: 新需求实现
│   ├── workflow-bug.md         # bug: Bug 修复
│   ├── workflow-change.md      # change: 局部修改
│   ├── workflow-refactor.md    # refactor: 代码重构
│   ├── workflow-init.md        # init: 初始化需求目录
│   ├── workflow-hotfix.md      # hotfix: 紧急修复
│   ├── workflow-perf.md        # perf: 性能优化
│   ├── workflow-docs.md        # docs: 文档更新
│   ├── workflow-chore.md       # chore: 工程调整
│   ├── vue-best-practices.md   # Vue 3 编码规范
│   ├── react-best-practices.md # React 19 编码规范（含 Compiler/Server Component）
│   ├── doc-parser.md           # PRD 文档解析（6 层降级）
│   ├── figma-analyzer.md       # Figma 设计解析（MCP 优先）
│   ├── api-spec-analyzer.md    # API 文档解析（三级智能匹配）
│   ├── component-scanner.md    # 项目资产扫描（标准化输出）
│   ├── code-reviewer.md        # 代码审查（上下文感知）
│   ├── test-runner.md          # 测试执行
│   ├── lint-verify.md          # 代码验证
│   └── framework-detector.md   # 框架检测（含 Playwright 检测）
├── hooks/
│   └── lint-format.sh          # Claude Code Stop hook
├── templates/                  # 需求目录脚手架模板
│   ├── demand.md.tpl
│   ├── figma-links.md.tpl
│   ├── api-readme.md.tpl
│   └── test-cases.md.tpl
└── scripts/
    └── postinstall.sh          # 补充安装脚本
```

> 各能力模块的详细说明请查阅 `references/` 目录下对应文件。

## License

MIT
