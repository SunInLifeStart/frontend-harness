# init: 初始化需求目录

## 用法

```
init: <需求名>
init: <项目名>/<需求名>    ← monorepo 时指定项目
```

## 执行流程

### Step 0: 环境预检

1. **读取环境配置** — 检查 `.harness-env.json` 是否存在：
   - 不存在 → 调用 `references/framework-detector.md` 执行环境探测
   - 存在 → 读取缓存

### Step 1: 需求名翻译

如果用户输入的需求名包含中文，自动将其翻译为英文短横线命名（kebab-case）作为目录名 `<dirName>`，同时保留原始中文名 `<displayName>` 用于 demand.md 标题。

示例：
- `积分管理` → dirName: `credit-management`, displayName: `积分管理`
- `用户权限体系` → dirName: `user-permission-system`, displayName: `用户权限体系`
- `credit-system` → dirName: `credit-system`, displayName: `credit-system`（纯英文不翻译）

翻译规则：
- 翻译为简洁的英文短语，用 `-` 连接单词
- 全小写
- 只保留字母、数字和 `-`

### Step 2: 确定 demand 目录位置

1. 从 `.harness-env.json` 读取 `demandRoot` 和 `monorepo` 字段
2. **非 monorepo** → `demandRoot` = 项目根目录
3. **monorepo**：
   - 如果用户在命令中指定了项目名（如 `init: template/积分体系`）→ `demandRoot` = `apps/<项目名>/`
   - 未指定 → 询问用户选择项目
4. 确认 `demandRoot` 路径存在

### Step 3: 创建目录结构

在 `demandRoot` 下创建（目录名使用 `<dirName>`）：

```
demand/<dirName>/
├── demand.md
├── prd/
├── figma/
│   └── figma-links.md
├── api/
│   └── README.md
├── test/
│   └── test-cases.md
└── output/
```

### Step 4: 填充模板文件

从 `templates/` 目录读取模板，替换占位符后写入对应文件：

1. **demand.md** ← `templates/demand.md.tpl`（替换 `{{需求名称}}` 为 `<displayName>`）
2. **figma/figma-links.md** ← `templates/figma-links.md.tpl`
3. **api/README.md** ← `templates/api-readme.md.tpl`
4. **test/test-cases.md** ← `templates/test-cases.md.tpl`

> **模板路径说明：** `templates/` 位于 skill 安装目录下。不同 agent 的安装位置不同：
> - Claude Code → `.claude/skills/frontend-harness/templates/`
> - Cursor → `.agents/skills/frontend-harness/templates/`
> - 其他 agent → 按 `npx skills add` 安装路径确定

### Step 5: Playwright 端到端测试配置（可选）

检查项目是否已安装 Playwright：

```bash
npx playwright --version
```

**如已安装** → 记录到环境配置（`.harness-env.json` 的 `playwright` 字段），跳过后续步骤

**如未安装** → 询问用户：

> 是否为本项目配置 Playwright 端到端测试？
> - Playwright 可在代码修改后自动验证功能和 UI 截图对比
> - 输入「是」初始化 Playwright，输入「跳过」稍后配置

如果用户选择「是」：
1. 执行 `npm init playwright@latest`
2. 建议使用默认配置（TypeScript、tests 目录、安装浏览器）
3. 将 Playwright 状态写入环境配置（`.harness-env.json` 中 `playwright.installed: true` + 版本号）

如果用户选择「跳过」：
- 标注「后续工作流中的 Playwright 验证步骤将自动跳过」
- 记录未安装状态到环境配置（`.harness-env.json` 中 `playwright.installed: false`）

### Step 6: 输出提示

```
✅ 需求目录已创建: {{demandRoot}}/demand/<dirName>/
   需求名称: <displayName>

下一步：
1. 将 PRD 文档（docx/pdf）放入 demand/<dirName>/prd/
2. 编辑 demand/<dirName>/figma/figma-links.md 填入 Figma 链接
3. 将各后端模块的 API 文档（.md）放入 demand/<dirName>/api/（每个模块一个文件）
4. （可选）编辑 demand/<dirName>/test/test-cases.md 填入测试用例
5. 编辑 demand/<dirName>/demand.md 填入需求简述

准备好后运行: feat: <dirName>
```
