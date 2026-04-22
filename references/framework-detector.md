# framework-detector — 框架 + 环境检测

## 用途

检测项目使用的前端框架、UI 库、CSS 方案、包管理器、monorepo 结构及所有关键目录路径。**支持缓存**，避免重复检测。

## 缓存机制

**缓存文件：** `.harness-env.json`（项目根目录）

缓存采用**多维度自动失效**策略，无需手动删除缓存文件：

```
1. 检查项目根目录 .harness-env.json 是否存在
2. 不存在 → 执行完整检测
3. 存在 → 执行多维度缓存校验（见 Step 0）
   - 校验通过 → 直接读取并返回，跳过所有检测步骤
   - 校验失败 → 缓存失效，执行完整检测并覆盖写入
```

### 缓存失效触发场景

| 场景 | 触发原因 | 结果 |
|------|----------|------|
| `npm install` 新包 | lockfile 内容 hash 变化 | 自动失效 |
| monorepo 切换 app | appDir 路径不存在 | 自动失效 |
| 修改 workspace 配置 | pnpm-workspace.yaml 或 workspaces 字段内容变化 | 自动失效 |
| 升级依赖（即使只改 patch 版本） | lockfile 内容变化 | 自动失效 |
| 修改 scripts 字段 | scripts 不参与 cacheKey 计算 | **不触发**失效 |
| 手动删除 `.harness-env.json` | 缓存文件不存在 | 直接重新检测 |

## 输入

- 项目根目录路径

## 输出

```json
{
  "framework": "vue",
  "frameworkVersion": "3.5",
  "ui": "element-plus",
  "css": "scss",
  "testFramework": "vitest | jest | none",
  "packageManager": "pnpm | yarn | npm",
  "hasDesignSpec": false,
  "monorepo": true,
  "appDir": "apps/template",
  "srcDir": "apps/template/src",
  "apiDir": "apps/template/src/api",
  "viewsDir": "apps/template/src/views",
  "componentsDir": "apps/template/src/components",
  "storesDir": "apps/template/src/stores",
  "routerDir": "apps/template/src/router",
  "i18nDir": "apps/template/src/language",
  "stylesDir": "apps/template/src/styles",
  "demandRoot": "apps/template"
}
```

## 执行步骤

### Step 0: 检查缓存

读取项目根目录的 `.harness-env.json`：

1. **不存在** → 执行完整检测（跳至 Step 1）
2. **存在** → 校验缓存有效性（多维度）：

#### a. _cacheKey 校验

计算当前项目的 cacheKey，与缓存中的 `_cacheKey` 字段对比。

cacheKey 的输入源（**全部参与 hash，使用 SHA-256**）：
- 项目根 `package.json` 的 `dependencies` + `devDependencies`
- `appDir` 下的 `package.json` 的 `dependencies` + `devDependencies`（monorepo 场景）
- lockfile 的内容 hash（`package-lock.json` / `yarn.lock` / `pnpm-lock.yaml`）
  **注意：hash lockfile 的文件内容，不是修改时间戳（mtime 在 clone/checkout/解压后不可靠）**
- `pnpm-workspace.yaml` 或 `package.json` 中 `workspaces` 字段的内容（monorepo 场景）
- 缓存中记录的 `appDir` 值

两者不一致 → 缓存失效，执行完整检测（跳至 Step 1）

#### b. 关键路径存在性校验

cacheKey 一致后，继续校验：
- `appDir` 路径是否实际存在？**不存在 → 失效**
- `srcDir` 路径是否实际存在？**不存在 → 失效**
- `node_modules` 是否存在？**不存在 → 提示用户安装依赖，但不强制失效**

#### c. 全部校验通过 → 使用缓存

直接返回缓存内容，结束。

### Step 1: 检测 monorepo

```
1. 检查 pnpm-workspace.yaml 是否存在 → pnpm monorepo
2. 检查 lerna.json 是否存在 → lerna monorepo
3. 检查根 package.json 的 "workspaces" 字段 → yarn/npm monorepo
4. 检查 apps/ 或 packages/ 目录是否包含多个带 package.json 的子目录
5. 以上都不是 → 非 monorepo
```

**monorepo 时确定 appDir：**
- 如果用户在触发命令中指定了项目名（如 `feat: template/积分管理`）→ `appDir` = `apps/<项目名>/`
- 未指定 → 列出 `apps/` 或 `packages/` 下的子项目，询问用户选择
- 非 monorepo → `appDir` = `.`（项目根目录）

### Step 2: 定位 package.json

```
1. monorepo → 读取 <appDir>/package.json
2. 非 monorepo → 读取项目根目录 package.json
3. 以实际包含 vue/react 依赖的 package.json 为准
```

### Step 3: 检测框架

读取 `dependencies` + `devDependencies`：

```
有 "vue" → framework: "vue"，读取版本号 → frameworkVersion
有 "react" → framework: "react"，读取版本号 → frameworkVersion
两者都有 → 以 appDir 的 package.json 为准
都没有 → framework: "unknown"
```

### Step 4: 检测 UI 库

```
"element-plus" → ui: "element-plus"
"ant-design-vue" → ui: "antdv"
"antd" → ui: "antd"
"@mui/material" → ui: "mui"
"@chakra-ui/react" → ui: "chakra"
"naive-ui" → ui: "naive-ui"
都没有 → ui: "none"
```

### Step 5: 检测 CSS 方案

```
"sass" or "scss" in deps → css: "scss"
"tailwindcss" in deps → css: "tailwind"
"less" in deps → css: "less"
"styled-components" in deps → css: "styled-components"
都没有 → css: "css-modules"
```

### Step 6: 检测其他

- 测试框架：vitest → vitest / jest → jest / 都没有 → none
- 包管理器：pnpm-lock.yaml → pnpm / yarn.lock → yarn / package-lock.json → npm
- design.md：项目根目录是否存在 `design.md` → hasDesignSpec: true/false

### Step 7: Playwright 可用性检测

```bash
npx playwright --version 2>/dev/null
```

- 成功 → 记录版本号
- 失败 → 标记为未安装

输出到 `.harness-env.json`：
```json
{
  "playwright": {
    "installed": true,
    "version": "1.x.x"
  }
}
```

如未安装：
```json
{
  "playwright": {
    "installed": false
  }
}
```

### Step 8: 探测目录结构

以 `appDir` 为基准，扫描实际目录结构，**不硬编码路径**：

```
srcDir:
  <appDir>/src/ 存在 → "<appDir>/src"
  否则 → "<appDir>"

apiDir:
  <srcDir>/api/ 存在 → "<srcDir>/api"
  <srcDir>/services/ 存在 → "<srcDir>/services"
  否则 → 不设置

viewsDir:
  <srcDir>/views/ 存在 → "<srcDir>/views"
  <srcDir>/pages/ 存在 → "<srcDir>/pages"
  <srcDir>/app/ 存在（Next.js）→ "<srcDir>/app"
  否则 → 不设置

componentsDir:
  <srcDir>/components/ 存在 → "<srcDir>/components"
  否则 → 不设置

storesDir:
  <srcDir>/stores/ 存在 → "<srcDir>/stores"
  <srcDir>/store/ 存在 → "<srcDir>/store"
  否则 → 不设置

routerDir:
  <srcDir>/router/ 存在 → "<srcDir>/router"
  否则 → 不设置

i18nDir:
  <srcDir>/locales/ 存在 → "<srcDir>/locales"
  <srcDir>/language/ 存在 → "<srcDir>/language"
  <srcDir>/i18n/ 存在 → "<srcDir>/i18n"
  否则 → 不设置

stylesDir:
  <srcDir>/styles/ 存在 → "<srcDir>/styles"
  <srcDir>/assets/styles/ 存在 → "<srcDir>/assets/styles"
  否则 → 不设置

demandRoot:
  monorepo → <appDir>
  非 monorepo → "."（项目根目录）
```

### Step 9: 写入缓存

将检测结果写入项目根目录的 `.harness-env.json`。写入时**必须包含缓存元数据字段**：

```json
{
  "_cacheKey": "<sha256-of-all-inputs>",
  "_cachedAt": "<ISO-8601-timestamp>",
  "_lockfileHash": "<sha256-of-lockfile-content>",
  "framework": "vue",
  "frameworkVersion": "3.5",
  "ui": "element-plus",
  "css": "scss",
  "testFramework": "vitest",
  "packageManager": "pnpm",
  "monorepo": true,
  "appDir": "apps/template",
  "srcDir": "apps/template/src",
  "apiDir": "apps/template/src/api",
  "viewsDir": "apps/template/src/views",
  "componentsDir": "apps/template/src/components",
  "storesDir": "apps/template/src/stores",
  "routerDir": "apps/template/src/router",
  "i18nDir": "apps/template/src/language",
  "stylesDir": "apps/template/src/styles",
  "demandRoot": "apps/template",
  "playwright": { "installed": true, "version": "1.x.x" }
}
```

**元数据字段说明：**
- `_cacheKey`：Step 0 中描述的全部输入源的 SHA-256 hash，用于下次校验
- `_cachedAt`：写入时的 ISO 8601 时间戳，便于排查问题
- `_lockfileHash`：lockfile 文件内容的 SHA-256 hash，单独记录便于调试

### overrides 配置

`.harness-env.json` 支持 `overrides` 字段，允许项目自定义验证行为：

```json
{
  "overrides": {
    "lint": { 
      "tool": "biome",        // 强制指定工具，跳过自动检测
      "required": true,        // 默认 true
      "timeout": 180           // 覆盖默认超时（秒）
    },
    "format": { 
      "required": false,       // 该项目无 format，SKIPPED 不报警
      "reason": "Biome 已包含 format"  // SKIPPED 时显示的原因
    },
    "build": { 
      "required": false, 
      "reason": "纯 library，无构建产物" 
    },
    "typeCheck": { 
      "tool": "vue-tsc",       // 强制 vue-tsc
      "timeout": 240 
    },
    "fixThreshold": 100,       // 自动修复文件数量阈值（默认 50）
    "monorepo": { 
      "incrementalLint": true,  // 启用增量 lint
      "incrementalBuild": true,
      "filterCommand": "pnpm --filter"  // 自定义 filter 命令
    }
  }
}
```

#### overrides 管理规则
- `overrides` 字段由用户手动编辑，framework-detector 不自动写入
- 首次生成 .harness-env.json 时，不包含 overrides（使用默认值）
- 检测到 overrides 字段存在时，缓存刷新不会清除 overrides
- 如需自定义，在 .harness-env.json 中手动添加 overrides 字段

输出检测摘要：
```
✅ 环境探测完成
  框架: Vue 3.5 + Element Plus + SCSS
  包管理器: pnpm
  monorepo: 是（appDir: apps/template）
  已写入 .harness-env.json（cacheKey: <前8位hash>...）
```
