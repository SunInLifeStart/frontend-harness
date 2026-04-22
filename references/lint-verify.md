# lint-verify — 多工具感知验证引擎

> **自动 lint hook 说明：** 部分 agent（如 Claude Code）支持 Stop hook，可在每次对话结束时自动执行 lint + format。
> 如果项目已配置自动 lint hook，手动调用本能力仅在需要执行 build / type-check 验证时使用。

## 用途

运行项目的 lint、format、type-check、build 验证管线，确保代码通过项目质量标准。
支持 Biome / oxlint / ESLint 8+9 / dprint / Prettier 等主流工具自动检测，统一输出标准验证报告。

## 输入

- 应用根目录路径（`{{appDir}}`，从 `.harness-env.json` 读取）
- 包管理器（`{{pm}}`，从 `.harness-env.json` 的 `packageManager` 字段读取）
- 当前工作流类型（feat / bug / change / hotfix / refactor / chore / perf）

## 输出

标准验证报告（Markdown 表格）+ 总判定结果

---

## Step 0.0: 读取项目配置（Overrides）

读取 `.harness-env.json` 的 `overrides` 字段：

1. 无 overrides 字段 → 使用全部默认值
2. 有 overrides → 逐项合并：
   - `overrides.lint.tool` 存在 → 跳过 Step 0 的 lint 工具自动检测，直接使用指定工具
   - `overrides.lint.required === false` → lint 步骤标记为 SKIPPED + reason
   - `overrides.format.required === false` → format 步骤标记为 SKIPPED + reason
   - `overrides.build.required === false` → build 步骤标记为 SKIPPED + reason（忽略工作流分级）
   - `overrides.typeCheck.tool` 存在 → 跳过 type checker 自动检测
   - `overrides.*.timeout` 存在 → 覆盖该步骤的默认超时值
   - `overrides.fixThreshold` 存在 → 覆盖自动修复文件数量阈值
   - `overrides.monorepo.*` → 传递给 Step 0.1 monorepo 检测

3. 输出提示：
   - 首次运行无 overrides → 「使用默认配置。如需自定义，请编辑 .harness-env.json 的 overrides 字段」
   - 有 overrides → 「已加载项目配置：lint=biome, format=SKIPPED, ...」

---

## Step 0: 工具检测

读取 `{{appDir}}/package.json` 的 `scripts`、`dependencies`、`devDependencies` 字段，以及项目根目录配置文件，按优先级检测可用工具。

> **扩展说明：** Step 0.1 已追加 monorepo 检测与增量验证策略。

### 0.1 Lint 工具检测

按优先级从高到低，**命中即停止**：

| 优先级 | 工具 | 检测条件 | 备注 |
|--------|------|----------|------|
| 1 | Biome | `biome.json` 或 `biome.jsonc` 存在 **且** devDependencies 含 `@biomejs/biome` | lint + format 合一 |
| 2 | oxlint | `.oxlintrc.json` 存在 **且** devDependencies 含 `oxlint` | 仅 lint，需另配 formatter |
| 3 | ESLint 9 | `eslint.config.js` / `eslint.config.mjs` / `eslint.config.cjs` 任一存在 | flat config，无 `--ext` |
| 4 | ESLint 8 | `.eslintrc` / `.eslintrc.js` / `.eslintrc.cjs` / `.eslintrc.json` / `.eslintrc.yml` 任一存在 | legacy config |
| 5 | Deno lint | `deno.json` 或 `deno.jsonc` 存在 | Deno 项目专用 |

→ 输出：`detectedLintTool` = `biome` / `oxlint` / `eslint9` / `eslint8` / `deno` / `none`

### 0.2 Format 工具检测

按优先级从高到低，**命中即停止**：

| 优先级 | 工具 | 检测条件 | 备注 |
|--------|------|----------|------|
| 1 | Biome | `detectedLintTool === biome` | 复用 lint 检测结果，lint + format 合一 |
| 2 | dprint | `dprint.json` 或 `.dprint.json` 存在 | Rust 系高速 formatter |
| 3 | Prettier | `.prettierrc` / `.prettierrc.*` / `prettier.config.*` 任一存在 | 社区最广泛 |

→ 输出：`detectedFormatTool` = `biome` / `dprint` / `prettier` / `none`

### 0.3 TypeScript 类型检查检测

按优先级从高到低，**命中即停止**：

| 优先级 | 检测条件 | 执行命令 |
|--------|----------|----------|
| 1 | `package.json` scripts 含 `type-check` | `{{pm}} run type-check` |
| 2 | 框架为 Vue **且** devDependencies 含 `vue-tsc` | `{{pm}} exec vue-tsc --noEmit` |
| 3 | devDependencies 含 `typescript` | `{{pm}} exec tsc --noEmit` |
| 4 | 以上都不满足 | SKIPPED |

→ 输出：`detectedTypeChecker` = `script` / `vue-tsc` / `tsc` / `none`

### 0.4 检测结果摘要

完成检测后，输出内部摘要（不输出给用户）：

```
检测结果:
  Lint: {{detectedLintTool}}
  Format: {{detectedFormatTool}}
  TypeCheck: {{detectedTypeChecker}}
  PM: {{pm}}
```

---

## Step 0.1: Monorepo 检测与验证范围确定

### 检测 monorepo 标志

检查以下文件/字段是否存在：
- `pnpm-workspace.yaml` 存在
- `package.json` 包含 `workspaces` 字段
- `lerna.json` 存在
- `nx.json` 存在

任一存在 → 标记为 monorepo 项目
全部不存在 → 非 monorepo，跳过本步骤，使用全量验证

### 确定受影响的 workspace packages

获取本次任务变更的文件列表，映射到受影响的 workspace packages：
1. 根据变更文件路径，确定所属 package（通过 workspace 配置中的 packages glob 模式匹配）
2. 如果有跨 package 的共享依赖变更（如 packages/shared/），需要包含依赖该共享包的下游 package

### 增量验证策略

#### Lint 增量
- **优先**：`<pm> --filter <affected-packages> run lint`（pnpm/yarn/nx 均支持 --filter）
- **如果 lint script 支持文件参数**：`eslint --cache <changed-files>`（ESLint 专属优化）
- **回退**：全量 `<pm> run lint`，报告中标注「全量扫描，耗时可能较长」

#### Build 增量
- **优先**：`<pm> --filter <affected-packages> run build`
- **回退**：全量 `<pm> run build`

#### Test 增量
- **优先**：`<pm> --filter <affected-packages> run test`
- **如果 test 框架支持 --changedSince**：`vitest --changed` 或 `jest --changedSince=HEAD~1`
- **回退**：全量 `<pm> run test`

#### Format 增量
- **优先**：如果 format 工具支持文件参数，只 format 变更文件
- **回退**：全量 format

### 报告标注

验证报告中必须标注验证范围：
- 增量模式：「增量验证：2/15 packages（pkg-a, pkg-b）」
- 全量回退：「全量验证（项目不支持增量或检测到跨包依赖变更）」

---

## ESLint 8 / 9 差异表

当 `detectedLintTool` 为 `eslint8` 或 `eslint9` 时，必须注意以下差异：

| 特性 | ESLint 8 | ESLint 9 |
|------|----------|----------|
| 配置文件 | `.eslintrc.*`（JSON / JS / YAML） | `eslint.config.js` / `.mjs` / `.cjs`（flat config） |
| `--ext` 参数 | 需要指定：`--ext .js,.ts,.vue` | **已移除**，在配置文件内通过 `files` 字段控制 |
| 忽略文件 | `.eslintignore` 独立文件 | 配置文件中 `ignores` 数组，或全局 `ignores` 配置对象 |
| 插件引用 | 字符串名称：`"plugins": ["vue"]` | 直接 import 对象：`import vue from 'eslint-plugin-vue'` |
| `--fix` 命令 | `eslint --ext .js,.ts,.vue --fix .` | `eslint --fix .` |

**关键规则：** 当用 `{{pm}} exec eslint` 构造命令时，**绝不**对 ESLint 9 加 `--ext` 参数，否则会报错退出。

---

## Step 1: 构造执行命令

### 1.1 统一命令格式

所有工具执行遵循唯一规则：

| 场景 | 格式 | 示例 |
|------|------|------|
| package.json 中有对应 script | `{{pm}} run <script>` | `pnpm run lint` |
| 无 script，但检测到工具已安装 | `{{pm}} exec <tool> <args>` | `pnpm exec biome check` |

**绝不**直接使用 `npx`、`bunx` 或全局命令。统一通过 `{{pm}} run` 或 `{{pm}} exec` 执行。

### 1.2 Biome 特殊处理

Biome 为 lint + format 合一工具：

| 操作 | 命令 |
|------|------|
| 检查（lint + format） | `{{pm}} exec biome check .` |
| 修复（lint + format） | `{{pm}} exec biome check --fix .` |
| 仅 lint | `{{pm}} exec biome lint .` |
| 仅 format | `{{pm}} exec biome format .` |

如 package.json 有 `lint` / `format` script 且内部调用 Biome → 优先使用 `{{pm}} run lint`。

---

## Step 1.5: 脚本可用性判定

检查 `package.json` scripts 中各阶段脚本是否存在，按以下规则处理：

| 脚本 | scripts 中缺失时的判定 | 行为 |
|------|------------------------|------|
| `lint` | NOT CONFIGURED | 标记验证不完整。**但如果 Step 0 检测到 Biome / oxlint 配置文件，仍可通过 `{{pm}} exec` 执行，此时不算 NOT CONFIGURED** |
| `format` | SKIPPED | 继续执行后续步骤，报告中标注"未配置格式化" |
| `build` | **按工作流分级判定** | 见下方规则 |
| `test` | SKIPPED | 继续执行后续步骤，报告中标注"测试缺口" |

### build 脚本缺失的工作流分级

| 工作流类型 | 无 build script 时 | 原因 |
|------------|---------------------|------|
| feat / refactor / chore / perf | **FAIL** — 必须配置 build | 这些工作流涉及结构性变更，构建验证不可跳过 |
| bug / change / hotfix | SKIPPED + 记录原因 | 局部修复，构建验证可延后到 CI |

---

## Step 1.6: 命令执行与失败分级

所有命令执行后，按 exit code 统一分级：

| Exit Code | 含义 | 结果标记 | 处理方式 |
|-----------|------|----------|----------|
| 0 | 通过 | **PASS** | 继续下一步 |
| 1 | 检查发现错误 | **FAIL** | 收集错误输出，记入报告 |
| 2+ | 命令异常（配置错误等） | **ERROR** | 收集错误输出，标记为工具异常 |
| 127 | command not found | **NOT FOUND** | 标记工具未安装，建议安装 |
| 超时 | 超过时限未完成 | **TIMEOUT** | 终止命令，标记超时 |

### 超时默认值

| 阶段 | 默认超时 |
|------|----------|
| lint | 120s |
| format | 60s |
| build | 300s |
| test | 600s |
| type-check | 120s |

> 超时值后续可通过 overrides 机制自定义。

---

## Step 2: 执行 Lint（自动修复优先）

### 2.1 检测修复命令

读取 `package.json` scripts，检查是否存在 `lint:fix` 脚本。

### 2.2 修复策略

按优先级选择修复方式，**命中即执行**：

| 优先级 | 条件 | 修复命令 |
|--------|------|----------|
| a | scripts 含 `lint:fix` | `{{pm}} run lint:fix` |
| b | `detectedLintTool === biome` | `{{pm}} exec biome check --fix .` |
| c | `detectedLintTool === oxlint` | `{{pm}} exec oxlint --fix` |
| d | `detectedLintTool === eslint9` 且无 `lint:fix` | `{{pm}} run lint -- --fix` |
| e | `detectedLintTool === eslint8` 且无 `lint:fix` | `{{pm}} run lint -- --fix` |
| f | 修复命令执行异常（exit 2+ / 127） | 跳过修复，直接进入检查 |

### 2.3 修复范围防护

修复执行后，立即检查修改范围：

```
1. 运行 git diff --name-only
2. 与当前任务涉及的文件列表对比
3. 如果修复触及的文件数超过阈值（默认 50 个）→ 执行 git checkout 回滚修复，报告异常
4. 阈值内 → 保留修复结果
```

### 2.4 执行正式检查

**无论修复是否成功**，都必须再执行一次普通 lint 命令获取真实剩余错误：

| 场景 | 检查命令 |
|------|----------|
| scripts 含 `lint` | `{{pm}} run lint` |
| Biome（无 lint script） | `{{pm}} exec biome check .` |
| oxlint（无 lint script） | `{{pm}} exec oxlint .` |
| ESLint 9（无 lint script） | `{{pm}} exec eslint .` |
| ESLint 8（无 lint script） | `{{pm}} exec eslint --ext .js,.ts,.jsx,.tsx,.vue .` |

将结果按 Step 1.6 分级标记。

---

## Step 3: 执行 Format

### 3.1 执行格式化

按 `detectedFormatTool` 执行：

| 工具 | 命令 |
|------|------|
| biome | **已在 Step 2 中合并处理**（`biome check` 包含格式化检查），此步标记 PASS 并跳过 |
| dprint | `{{pm}} exec dprint fmt` |
| prettier | `{{pm}} run format`（有 script 时）或 `{{pm}} exec prettier --write .`（无 script 时） |
| none | SKIPPED |

### 3.2 检查格式化结果

```
1. 执行 git diff --name-only
2. 有修改 → 记录被格式化的文件列表
3. 无修改 → 格式化通过
```

将结果按 Step 1.6 分级标记。

---

## Step 4: 执行 Build

```
1. 检查 scripts 中是否有 build 命令
2. 有 → 执行 {{pm}} run build
3. 无 → 按 Step 1.5 的工作流分级判定处理
```

将结果按 Step 1.6 分级标记。

---

## Step 4.5: TypeScript 类型检查

按 Step 0.3 检测结果执行：

| detectedTypeChecker | 执行命令 |
|---------------------|----------|
| `script` | `{{pm}} run type-check` |
| `vue-tsc` | `{{pm}} exec vue-tsc --noEmit` |
| `tsc` | `{{pm}} exec tsc --noEmit` |
| `none` | SKIPPED |

**注意：** vue-tsc 和 tsc 使用 `{{pm}} exec` 而非 `{{pm}} run`，因为它们不是 package.json scripts。

将结果按 Step 1.6 分级标记。

---

## Step 5: 输出标准验证报告

### 5.1 报告格式

```markdown
## 验证结果

| 步骤 | 工具 | 版本 | 耗时 | 结果 | 详情 |
|------|------|------|------|------|------|
| Lint | ESLint 9 | 9.x.x | 3.2s | ✅ PASS | 无错误 |
| Format | Prettier | 3.x.x | 1.1s | ⚠️ 已修复 | 3 个文件格式化 |
| Build | vite | 6.x.x | 12.4s | ✅ PASS | 编译成功 |
| TypeCheck | tsc | 5.x.x | 8.7s | ✅ PASS | 无类型错误 |
```

- **版本**：从工具输出或 `node_modules/<pkg>/package.json` 读取
- **耗时**：记录命令执行的实际耗时
- 被 SKIPPED 的步骤仍需列入表格，结果列标记 `⏭️ SKIPPED` 并在详情说明原因

### 5.2 总判定规则

按以下优先级从上到下匹配，**命中即停止**：

| 条件 | 总判定 | 标记 |
|------|--------|------|
| 任一步骤 FAIL | 未通过 | ❌ 验证未通过 |
| 任一步骤 ERROR 或 TIMEOUT | 验证异常 | ⚠️ 验证异常，请检查工具配置 |
| lint 为 NOT CONFIGURED | 验证不完整 | ⚠️ 验证不完整（lint 未配置） |
| 全部 PASS + 有 SKIPPED 步骤 | 验证不完整 | ⚠️ 验证通过但不完整 |
| 全部 PASS + 无 SKIPPED | 全部通过 | ✅ 全部通过 |

### 5.3 错误详情输出

当存在 FAIL 步骤时，在报告表格下方输出具体错误信息，格式：

```
### 错误详情

**Lint 错误（共 N 条）：**
- `src/views/Home.vue:42:5` — 'unused' is defined but never used (@typescript-eslint/no-unused-vars)
- `src/utils/request.ts:15:1` — Expected indentation of 2 spaces (indent)

**Build 错误：**
- TS2304: Cannot find name 'UserInfo' (src/types/index.ts:12:5)
```

供主 Agent 修复后重试验证。
