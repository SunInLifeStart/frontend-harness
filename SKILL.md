---
name: frontend-harness
description: |
  前端开发 harness 工作流。通过前缀路由触发：
  feat: 新需求端到端实现 | bug: Bug修复 | change: 局部修改 | refactor: 代码重构 | init: 初始化需求目录 | hotfix: 紧急修复 | perf: 性能优化 | docs: 文档更新 | chore: 工程调整。
  内置 Vue 3 / React 19 最佳实践、8 维代码审查、PRD 解析、Figma 解析、API 文档解析、项目资产扫描。
  适用于任何 Vue/React 前端项目（支持 monorepo）。
---

# Frontend Harness — 前端 AI 开发工作流

> 本文件是 AI 进入项目时的认知入口。兼容 Claude Code、Cursor、Codex 及所有支持 skill 的 AI 工具。

---

## 触发路由

当用户消息以下列前缀开头时，读取对应的工作流文档并按流程执行：

| 前缀 | 工作流 | 适用场景 | 判断标准 | 详细流程 |
|------|--------|----------|---------|----------|
| `feat: <需求名>` | 新需求实现 | 新功能、有 PRD、涉及 3+ 组件/页面 | 产品需求驱动，新增业务价值 | `references/workflow-feat.md` |
| `bug: <问题描述>` | Bug 修复 | 页面报错、功能异常、样式错乱 | **非预期行为**，违反设计稿或需求文档 | `references/workflow-bug.md` |
| `change: <修改描述>` | 局部修改 | 改样式/逻辑、调交互、反馈微调 | **预期调整**，优化体验或调整规范 | `references/workflow-change.md` |
| `refactor: <重构目标>` | 代码重构 | 不改功能，优化结构/性能/可维护性 | 改内部结构，不改外部行为 | `references/workflow-refactor.md` |
| `init: <需求名>` | 初始化需求目录 | 新需求开始前创建目录脚手架 | 脚手架初始化 | `references/workflow-init.md` |
| `hotfix: <问题描述>` | 紧急修复 | 生产 P0 bug | 线上紧急故障，需快速路径修复 | `references/workflow-hotfix.md` |
| `perf: <优化目标>` | 性能优化 | 打包/运行时性能 | Bundle 过大、加载慢、渲染卡顿 | `references/workflow-perf.md` |
| `docs: <修改描述>` | 文档更新 | 仅改文档/注释 | 不涉及功能代码，只改文档内容 | `references/workflow-docs.md` |
| `chore: <调整描述>` | 工程调整 | 依赖升级/配置 | 工程层面调整，不改业务逻辑 | `references/workflow-chore.md` |

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
| 框架检测 | `references/framework-detector.md` | 检测框架/UI库/CSS方案/monorepo，输出 `.harness-env.json`（含缓存失效 + overrides） |
| PRD 解析 | `references/doc-parser.md` | docx/pdf → 结构化 Markdown |
| Figma 解析 | `references/figma-analyzer.md` | 设计稿 → 组件树 + 状态矩阵 |
| API 解析 | `references/api-spec-analyzer.md` | API 文档 → 接口清单 + 复用标注 |
| 资产扫描 | `references/component-scanner.md` | 扫描组件/hooks/api/store 等可复用资产 |
| 代码审查 | `references/code-reviewer.md` | 多维度审查（feat 8维/change 4维/bug 2维/refactor 3维） |
| 代码验证 | `references/phases/verify-code.md` | 强制验证阶段：工具检测 → lint → format → build → type-check，输出标准验证报告 |
| 测试执行 | `references/phases/verify-test.md` | PASS/FAIL（实际运行）或 STATIC CHECK（Markdown 用例） |
| Playwright 验证 | `references/phases/verify-e2e.md` | 功能验证 + UI 截图对比（**可选**，未安装自动跳过） |

---

## 执行模式

- **单 Agent 顺序执行**：所有步骤在当前对话中完成，不启动子 Agent
- 「调用 references/xxx.md」= 读取该文件内容，按其中步骤顺序执行
- 每个工作流的阶段按顺序进行，不跳步
- 遇到审批门禁（标 ⏸️ 的地方）必须停下等用户确认

### 进度检查点

所有工作流输出 `[阶段 X/N]` 格式的进度标记，例如：

```
[阶段 1/5] 环境探测...
[阶段 2/5] 实现编码...
[阶段 3/5] 代码审查...
[阶段 4/5] 代码验证...
  [验证 1/5] Lint 检查...
  [验证 2/5] Format 检查...
  [验证 3/5] Build 验证...
  [验证 4/5] 类型检查...
  [验证 5/5] 测试执行...
[阶段 5/5] 完成总结...
```

验证阶段（phases/verify-code.md）内部输出 `[验证 X/5]` 子进度，嵌套在工作流主进度内。

---

## 审批门禁政策

### 一般原则
- 任何可能影响产品用户的变更都需要门禁
- 门禁用 ⏸️ 符号标注
- 门禁停下后需要用户明确确认（“批准”、“继续”、“开始”等）

### 验证阶段门禁

所有代码修改工作流必须通过 `phases/verify-code.md` 执行代码验证，输出标准验证报告（Markdown 表格）：

```markdown
| 步骤 | 工具 | 版本 | 耗时 | 结果 | 详情 |
|------|------|------|------|------|------|
| Lint | ESLint 9 | 9.x.x | 3.2s | ✅ PASS | 无错误 |
| Format | Prettier | 3.x.x | 1.1s | ✅ PASS | 无改动 |
| Build | vite | 6.x.x | 12.4s | ✅ PASS | 编译成功 |
| TypeCheck | tsc | 5.x.x | 8.7s | ✅ PASS | 无类型错误 |
```

> Hook（lint-format.sh）是 Claude Code 专属的额外安全网，不替代 phases/verify-code.md 的显式执行。

### 工作流门禁清单

#### feat: 工作流
- ⏸️ 阶段 1：信息不足时 → 询问用户补充
- ⏸️ 阶段 3：实现计划完成后 → 等用户审批

#### bug: 工作流
- ⏸️ 阶段 2：修复可能影响其他功能时 → 告知用户风险

#### change: 工作流
- ⏸️ 阶段 1：影响 >3 个文件时 → 先输出方案等确认

#### refactor: 工作流
- ⏸️ 阶段 2：影响 >3 个文件时 → 输出方案等确认

#### hotfix: 工作流
- 无显式门禁（快速路径，跳过完整审查）
- 修复后输出后续建议，由用户决定是否跟进

#### perf: 工作流
- ⏸️ 阶段 3：优化方案完成后 → 等用户确认后才动代码

#### docs: 工作流
- 无门禁（轻量流程）

#### chore: 工作流
- ⏸️ 阶段 3：涉及 major 版本升级时 → 输出 breaking changes 清单等确认

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

---

## IDE 兼容策略

| IDE | 验证保障方式 | 覆盖程度 |
|-----|------------|--------|
| Claude Code | 工作流显式调用 + lint-format.sh hook | 双重保障 |
| Cursor | 工作流显式调用（通过 .cursorrules 引用 SKILL.md） | 单链路 |
| Copilot Workspace | 工作流显式调用 | 单链路 |
| Windsurf | 工作流显式调用 | 单链路 |
| 其他 | 工作流显式调用 | 单链路 |

> 核心原则：工作流中的 `phases/verify-code.md` 是主链路，覆盖所有 IDE。
> Hook（`lint-format.sh`）是 Claude Code 专属的额外安全网。
