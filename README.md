# Frontend Harness

前端 AI 开发工作流 skill。一键安装到 Claude Code / Cursor / Codex 等 45+ AI 工具。

## 一键安装

```bash
# 1. 安装 skill 到所有 AI 工具
npx skills add zhumo/frontend-harness

# 2.（Claude Code 用户）补充安装 hooks/settings/templates
bash .claude/skills/frontend-harness/scripts/postinstall.sh .
```

## 触发规则

在对话中使用以下前缀触发工作流：

| 前缀 | 用途 | 示例 |
|------|------|------|
| `feat:` | 新需求端到端实现 | `feat: 用户积分管理` |
| `bug:` | Bug 修复 | `bug: 积分页面列表为空但接口有数据` |
| `change:` | 局部修改 | `change: 把积分列表的分页从 10 改成 20` |
| `refactor:` | 代码重构 | `refactor: 把积分页面的 Options API 迁移到 Composition API` |
| `init:` | 初始化需求目录 | `init: 积分管理` |

无前缀 → 不触发工作流，按普通对话处理。

## 内置能力

| 能力 | 说明 |
|------|------|
| 框架检测 | 自动检测 Vue/React、UI 库、CSS 方案、monorepo |
| PRD 解析 | docx/pdf 文档 → 结构化 Markdown |
| Figma 解析 | 设计稿 → 组件树 + 状态矩阵（支持 MCP + 截图降级） |
| API 解析 | API 文档 → 接口清单 + 复用标注 |
| 资产扫描 | 扫描组件/hooks/api/store 等可复用资产 |
| 代码审查 | 多维度审查（feat 8维/change 4维/bug 2维/refactor 3维） |
| 测试执行 | 测试用例检查清单 / Vitest/Jest 运行 |
| 代码验证 | lint + format + build 验证链 |

## 能力矩阵

| 能力 | feat | bug | change | refactor | init |
|------|:----:|:---:|:------:|:--------:|:----:|
| 框架检测 | ✅ | ✅ | ✅ | ✅ | ✅ |
| PRD 解析 | ✅ | - | - | - | - |
| Figma 解析 | ✅ | - | - | - | - |
| API 解析 | ✅ | - | - | - | - |
| 资产扫描 | full | minimal | targeted | targeted | - |
| 代码审查 | 8维 | 2维 | 4维 | 3维 | - |
| 测试执行 | ✅ | - | ✅ | - | - |
| 代码验证 | ✅ | ✅ | ✅ | ✅ | - |

## 项目自适应

首次触发工作流时自动检测项目环境，生成 `.harness-env.json` 缓存：

- 框架类型（Vue/React）和版本
- UI 库（Element Plus / Ant Design / MUI 等）
- CSS 方案（SCSS / Tailwind / Less 等）
- 包管理器（pnpm / yarn / npm）
- monorepo 结构检测
- 所有关键目录路径自动探测

支持任何 Vue/React 前端项目，不绑定特定目录结构。

## Agent 兼容性

| Agent | skill 安装 | hooks | templates | 触发方式 |
|-------|:---------:|:-----:|:---------:|:--------:|
| Claude Code | `npx skills add` | postinstall.sh | postinstall.sh | 前缀触发 |
| Cursor | `npx skills add` | 不支持 | 不需要 | 前缀触发 |
| Codex | `npx skills add` | 不支持 | 不需要 | 前缀触发 |
| 其他 45+ agent | `npx skills add` | 不支持 | 不需要 | 前缀触发 |

## 首次使用

1. `npx skills add zhumo/frontend-harness`
2. （Claude Code 用户）`bash .claude/skills/frontend-harness/scripts/postinstall.sh .`
3. 在对话中输入 `feat: 你的需求名` 开始
4. 首次触发会自动探测项目环境，生成 `.harness-env.json`
5. 将 `.harness-env.json` 加入 `.gitignore`

## 目录结构

```
frontend-harness/
├── SKILL.md                    # 主入口（所有 agent 读这个）
├── README.md                   # 安装说明
├── references/                 # 按需读取的子文档
│   ├── workflow-feat.md        # feat: 新需求实现
│   ├── workflow-bug.md         # bug: Bug 修复
│   ├── workflow-change.md      # change: 局部修改
│   ├── workflow-refactor.md    # refactor: 代码重构
│   ├── workflow-init.md        # init: 初始化需求目录
│   ├── vue-best-practices.md   # Vue 3 编码规范
│   ├── react-best-practices.md # React 19 编码规范
│   ├── doc-parser.md           # PRD 文档解析
│   ├── figma-analyzer.md       # Figma 设计解析
│   ├── api-spec-analyzer.md    # API 文档解析
│   ├── component-scanner.md    # 项目资产扫描
│   ├── code-reviewer.md        # 代码审查
│   ├── test-runner.md          # 测试执行
│   ├── lint-verify.md          # 代码验证
│   └── framework-detector.md   # 框架检测
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

## License

MIT
