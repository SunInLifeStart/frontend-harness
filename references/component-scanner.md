# component-scanner — 项目资产扫描

## 用途

扫描项目现有的组件、hooks/composables、工具函数、API 层等，为实现阶段提供复用依据。

## 扫描 Scope

### scope: full（全量扫描）— 用于 feat: 工作流

扫描所有 8 个维度：组件、hooks/composables、utils、api、store、路由、权限、i18n

### scope: targeted（按需扫描）— 用于 change: / refactor: 工作流

仅扫描与修改目标相关的模块：
- 必扫：components、composables/hooks
- 按需：如果修改涉及 API 调用则扫 api，涉及状态管理则扫 store
- 跳过：路由、权限、i18n（除非修改明确涉及）

### scope: minimal（最小扫描）— 用于 bug: 工作流

仅扫描与 bug 相关的直接代码路径，不做广域扫描。

---

## 输入

- 项目 `{{srcDir}}` 目录路径（从 `.harness-env.json` 读取）
- scope: full | targeted | minimal
- 目标文件/模块（targeted 和 minimal 时需要）

## 输出

可复用资产清单，分类整理

## 标准输出格式

所有扫描结果统一使用以下表格格式输出：

**组件列表（Step 1）：**

| 组件名 | 路径 | Props | 功能 | 使用频率 |
|--------|------|-------|------|----------|
| AppButton | src/components/AppButton.vue | label, type, disabled | 通用按钮 | ★★★ |

**Hooks / Composables（Step 2）：**

| Hook名 | 路径 | 签名 | 功能 |
|--------|------|------|------|
| useAuth | src/hooks/useAuth.js | `(options?) => { user, login, logout }` | 用户认证 |

**工具函数（Step 3）：**

| 函数名 | 路径 | 签名 | 功能 |
|--------|------|------|------|
| formatDate | src/utils/date.js | `(date, format?) => string` | 日期格式化 |

**API 函数（Step 4）：**

| 函数名 | 路径 | 方法 | 请求路径 |
|--------|------|------|----------|
| getUser | src/api/user.js | GET | /api/user |

**Store（Step 5）：**

| Store名 | 路径 | State 字段 | Actions |
|---------|------|------------|----------|
| useUserStore | src/stores/user.js | name, token | login, logout |

**路由（Step 6）：**

| 路由路径 | 名称 | 组件 | 备注 |
|----------|------|------|------|
| /dashboard | Dashboard | views/Dashboard.vue | 可挂载子路由 |

**权限（Step 7）：**

| 权限模块 | 指令/函数 | 使用位置 | 配置方式 |
|----------|------------|----------|----------|

**i18n（Step 8）：**

| 语言文件 | Key 结构示例 | 新 Key 放置位置 |
|----------|--------------|----------------|

## 智能扫描范围选择

根据项目规模自动调整扫描策略：

- **≤ 15 个组件文件** → 全量扫描，读取每个文件提取详细信息
- **16 ~ 50 个组件文件** → 全量扫描，提取关键信息（Props + 功能摘要）
- **> 50 个组件文件** → 按需扫描：
  - 仅返回前 30 个常用组件（按引用频率排序）
  - 补充输出：`ℹ️ 项目共 {N} 个组件，已展示前 30 个高频组件。如需查看完整列表，请指定目标目录进行定向扫描。`
  - 如果是 targeted scope，优先扫描目标相关组件，不受 30 个限制

扫描范围选择在 Step 1 执行前自动判断，无需用户手动指定。

## 执行步骤（full scope）

### Step 1: 扫描组件

搜索 `{{componentsDir}}/**/*.vue`（Vue）或 `**/*.tsx`（React）：
- 读取组件文件，提取 Props 定义
- 推断组件功能
- 输出：组件名 + 路径 + Props 列表 + 功能摘要

### Step 2: 扫描 Hooks / Composables

搜索以下路径：
- `{{srcDir}}/hooks/**/*.js`
- `{{srcDir}}/composables/**/*.js`
- `{{viewsDir}}/**/component/**`（view 级组件）
- `{{viewsDir}}/**/utils/**`（view 级工具函数）
- `{{viewsDir}}/**/hooks/**`（view 级 hooks）
- `{{viewsDir}}/**/ui/**`（view 级 UI 组件）

targeted scope 时，优先扫描修改目标所在 view 目录下的上述子目录。

对每个找到的文件：
- 读取导出的函数签名
- 输出：函数名 + 路径 + 参数 + 返回值

### Step 3: 扫描工具函数

搜索 `{{srcDir}}/utils/**/*.js`：
- 列出所有导出函数名和简要功能

### Step 4: 扫描 API 层

搜索 `{{apiDir}}/**/*.js`：
- 列出所有导出的 API 函数名
- 提取对应的请求路径和方法

### Step 5: 扫描 Store

搜索 `{{storesDir}}/**/*.js`：
- 列出每个 store 的名称
- 提取 state 字段和 action 函数名

### Step 6: 扫描路由表（full scope 才执行）

读取 `{{routerDir}}` 下的路由配置：
- 列出现有路由结构
- 标注新页面可挂载的路由节点

### Step 7: 扫描权限配置（full scope 才执行）

搜索权限指令的使用和定义：
- 列出已有权限模块名
- 标注新功能权限配置方式

### Step 8: 扫描 i18n 结构（full scope 才执行）

读取 `{{i18nDir}}` 下的语言文件：
- 识别 key 命名结构
- 标注新功能 i18n key 应放在哪个文件

## 执行步骤（targeted scope）

仅执行 Step 1-2，按需执行 Step 3-5。

## 执行步骤（minimal scope）

仅搜索与目标文件直接相关的引用链。
