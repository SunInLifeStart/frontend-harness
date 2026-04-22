# lint-verify — 代码验证

> **自动 lint hook 说明：** 部分 agent（如 Claude Code）支持 Stop hook，可在每次对话结束时自动执行 lint + format。
> 如果项目已配置自动 lint hook，手动调用本能力仅在需要执行 build 验证时使用。

## 用途

运行项目的 lint、format、build 验证管线，确保代码通过项目质量标准。

## 输入

- 应用根目录路径（`{{appDir}}`，从 `.harness-env.json` 读取）

## 输出

验证结果（通过/失败 + 错误详情）

## 执行步骤

### Step 1: 检测可用命令

读取 `package.json` 的 `scripts` 字段，确认实际命令名：

```
查找优先级:
├── lint: "lint" > "eslint" > "lint:fix"
├── format: "format" > "prettier"
└── build: "build:test" > "build:dev" > "build"
```

同时从 `.harness-env.json` 读取包管理器（`packageManager` 字段）。

### Step 2: 执行 Lint

运行 `{{packageManager}} lint` 或对应命令：
- 成功（exit 0）→ ✅ Lint 通过
- 失败 → 收集错误信息（文件名:行号:错误描述）

### Step 3: 执行 Format

运行 `{{packageManager}} format` 或对应命令：
- 检查是否有文件被修改（格式化后 git diff）
- 有修改 → ⚠️ 部分文件未格式化，已自动修复
- 无修改 → ✅ 格式化通过

### Step 4: 执行 Build（可选）

运行 build 命令验证编译通过：
- 成功 → ✅ Build 通过
- 失败 → 收集构建错误

**注意：** build 步骤仅在 feat: 工作流中执行，change: 和 bug: 默认跳过，除非以下文件有变更：
- `vite.config.*`
- `package.json`（scripts 或 dependencies 变更）
- `tsconfig.*`
- `.env*` 文件
- 入口文件（`src/main.js` 或 `src/index.tsx`）

### Step 5: 汇总报告

```
## 验证结果

| 步骤 | 状态 | 详情 |
|------|------|------|
| Lint | ✅ 通过 | 无错误 |
| Format | ⚠️ 已修复 | 3 个文件格式化 |
| Build | ✅ 通过 | 编译成功 |
```

如有错误 → 输出具体错误信息供主 Agent 修复后重试。
