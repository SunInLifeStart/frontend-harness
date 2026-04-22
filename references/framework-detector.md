# framework-detector — 框架 + 环境检测

## 用途

检测项目使用的前端框架、UI 库、CSS 方案、包管理器、monorepo 结构及所有关键目录路径。**支持缓存**，避免重复检测。

## 缓存机制

**缓存文件：** `.harness-env.json`（项目根目录）

```
1. 检查项目根目录 .harness-env.json 是否存在
2. 存在且内容完整 → 直接读取并返回，跳过所有检测步骤
3. 不存在 → 执行完整检测，检测完成后写入缓存文件
```

**缓存失效：** 当项目 package.json 的 dependencies 发生重大变化时（如安装了新框架），手动删除 `.harness-env.json` 即可触发重新检测。

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

读取项目根目录的 `.harness-env.json`，如果存在且内容完整（包含 `framework`、`appDir`、`srcDir` 等关键字段）→ 直接返回，结束。

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

将检测结果写入项目根目录的 `.harness-env.json`，下次直接读取。

输出检测摘要：
```
✅ 环境探测完成
  框架: Vue 3.5 + Element Plus + SCSS
  包管理器: pnpm
  monorepo: 是（appDir: apps/template）
  已写入 .harness-env.json
```
