---
name: frontend-harness
description: |
  前端开发 harness 工作流。通过前缀路由触发：
  feat: 新需求端到端实现 | bug: Bug修复 | change: 局部修改 | refactor: 代码重构 | init: 初始化需求目录。
  内置 Vue 3 / React 19 最佳实践、8 维代码审查、PRD 解析、Figma 解析、API 文档解析、项目资产扫描。
  适用于任何 Vue/React 前端项目（支持 monorepo）。
---

# Frontend Harness — 前端 AI 开发工作流

> 本文件是 AI 进入项目时的认知入口。兼容 Claude Code、Cursor、Codex 及所有支持 skill 的 AI 工具。

---

## 触发路由

当用户消息以下列前缀开头时，读取对应的工作流文档并按流程执行：

| 前缀 | 工作流 | 适用场景 | 详细流程 |
|------|--------|----------|----------|
| `feat: <需求名>` | 新需求实现 | 新功能、有 PRD、涉及 3+ 组件/页面 | `references/workflow-feat.md` |
| `bug: <问题描述>` | Bug 修复 | 页面报错、功能异常、样式错乱 | `references/workflow-bug.md` |
| `change: <修改描述>` | 局部修改 | 改样式/逻辑、调交互、反馈微调 | `references/workflow-change.md` |
| `refactor: <重构目标>` | 代码重构 | 不改功能，优化结构/性能/可维护性 | `references/workflow-refactor.md` |
| `init: <需求名>` | 初始化需求目录 | 新需求开始前创建目录脚手架 | `references/workflow-init.md` |

### 路由优先级

1. 精确匹配前缀 → 进入对应工作流
2. 无前缀但描述明确是 bug → 提示用户「检测到可能是 bug，建议使用 `bug: <描述>` 触发修复工作流」
3. 无前缀 → 不触发工作流，按普通对话处理

---

## 环境探测（首次触发任何工作流时执行）

检查项目根目录是否存在 `.harness-env.json`：
- **存在且内容完整** → 读取缓存，跳过探测
- **不存在** → 读取 `references/framework-detector.md`，执行完整探测，将结果写入 `.harness-env.json`

探测结果决定后续所有工作流中的路径变量：
- `{{appDir}}` — 应用根目录（monorepo 时为子项目路径，如 `apps/template`）
- `{{srcDir}}` — 源码目录（如 `apps/template/src`）
- `{{apiDir}}` — API 层目录（如 `apps/template/src/api`）
- `{{viewsDir}}` — 页面目录（如 `apps/template/src/views`）
- `{{componentsDir}}` — 组件目录（如 `apps/template/src/components`）
- `{{storesDir}}` — 状态管理目录
- `{{routerDir}}` — 路由目录
- `{{i18nDir}}` — 国际化目录
- `{{stylesDir}}` — 样式目录
- `{{demandRoot}}` — 需求目录根路径

**monorepo 处理**：检测到 monorepo 时，如果用户未指定项目，则列出 `apps/` 或 `packages/` 下的子项目让用户选择，选择后写入 `appDir` 字段。

---

## 不适用场景（直接编码，不进工作流）

| 场景 | 处理方式 |
|------|----------|
| 改文案 / typo | 直接改 |
| 纯样式微调（颜色/间距/字号） | 直接改 |
| 改配置文件（.env / 路由参数） | 直接改 |
| 删除未使用的代码 | 直接改 |
| 单行 bug 修复（根因明确） | 直接改 + 验证 |

---

## 编码规约

- 代码注释使用**中文**
- git commit message 使用**中文**，格式：`<类型>: <简短描述>`
- 遇到歧义**必须停下询问**，禁止猜测
- **复用优先**：优先使用项目已有组件/函数，没有也不过度封装
- **最小改动**：只改需要改的，不做额外「优化」或「顺手重构」

---

## 框架规范

根据 `.harness-env.json` 中的 `framework` 字段自动加载：
- `vue` → 读取 `references/vue-best-practices.md` 作为编码硬约束
- `react` → 读取 `references/react-best-practices.md` 作为编码硬约束

---

## 原子能力

以下能力被各工作流按需调用（读取对应 references 文件，按其中步骤执行）：

| 能力 | 文档 | 用途 |
|------|------|------|
| 框架检测 | `references/framework-detector.md` | 检测框架/UI库/CSS方案/monorepo，输出 `.harness-env.json` |
| PRD 解析 | `references/doc-parser.md` | docx/pdf → 结构化 Markdown |
| Figma 解析 | `references/figma-analyzer.md` | 设计稿 → 组件树 + 状态矩阵 |
| API 解析 | `references/api-spec-analyzer.md` | API 文档 → 接口清单 + 复用标注 |
| 资产扫描 | `references/component-scanner.md` | 扫描组件/hooks/api/store 等可复用资产 |
| 代码审查 | `references/code-reviewer.md` | 多维度审查（feat 8维/change 4维/bug 2维/refactor 3维） |
| 测试执行 | `references/test-runner.md` | 测试用例检查清单 / 实际运行测试 |
| 代码验证 | `references/lint-verify.md` | lint + format + build 验证链 |

---

## 执行模式

- **单 Agent 顺序执行**：所有步骤在当前对话中完成，不启动子 Agent
- 「调用 references/xxx.md」= 读取该文件内容，按其中步骤顺序执行
- 每个工作流的阶段按顺序进行，不跳步
- 遇到审批门禁（标 ⏸️ 的地方）必须停下等用户确认

---

## 需求目录结构

```
demand/<需求名>/
├── demand.md           ← 需求简述
├── prd/                ← PRD 文档（docx/pdf）
├── figma/
│   └── figma-links.md  ← Figma 链接 + 页面说明
├── api/
│   └── README.md       ← 接口文档说明（按后端模块拆分多个 .md）
├── test/
│   └── test-cases.md   ← 测试用例（可选）
└── output/             ← 工作流产出
    ├── requirements.md
    ├── component-map.md
    ├── implementation-plan.md
    └── report.md
```

---

## 设计规范

- 项目根目录有 `design.md` → 作为样式/布局标准
- 无 `design.md` → 按 Figma 设计稿或截图一比一还原
