# feat: 新需求端到端实现

## 用法

```
feat: <需求名>
feat: <项目名>/<需求名>    ← monorepo 时指定项目
```

读取 `{{demandRoot}}/demand/<需求名>/` 下的需求文档，经过 10 个阶段完成从需求到代码的全流程。

> **路径说明：** `{{demandRoot}}` 从 `.harness-env.json` 读取。非 monorepo 时为项目根目录，monorepo 时为 `{{appDir}}`。下文所有 `demand/<需求名>/` 路径均相对于 `{{demandRoot}}`。

> **执行模式说明：** 本工作流中所有「调用 references/xxx.md」均指**读取对应文件，按其中步骤顺序执行**。所有步骤由当前 Agent 顺序完成，不启动子 Agent。

---

## 阶段 0: 环境预检

[阶段 0/10] 环境预检...

在开始需求分析前，确认基本环境就绪：

1. **读取环境配置** — 检查 `.harness-env.json` 是否存在：
   - 不存在 → 调用 `references/framework-detector.md` 执行环境探测
   - 存在 → 读取缓存
2. **确定 demandRoot** — 从 `.harness-env.json` 读取 `demandRoot` 字段：
   - monorepo + 用户在 `feat:` 后指定了项目名 → 更新 `demandRoot`
   - monorepo + 未指定 → 询问用户选择项目
3. **检查 demand 目录** — `{{demandRoot}}/demand/<需求名>/` 是否存在且包含 demand.md
   - 不存在 → 提示用户先运行 `init: <需求名>`
4. **检查 node_modules** — 项目 node_modules 是否存在
   - 不存在 → 提示用户运行 `{{packageManager}} install`

> **注意：** 阶段 0 不检查 Git 状态和分支。需求分析和计划阶段（阶段 1-3）允许脏工作区，Git 相关检查推迟到阶段 4（准备实施环境）。

全部通过后进入阶段 1。

---

## 阶段 1: 读取需求

[阶段 1/10] 读取需求...

### 1.1 读取需求简述

读取 `demand/<需求名>/demand.md`，理解需求目标、范围和约束。

### 1.2 解析 PRD 文档

读取 `references/doc-parser.md`，按步骤执行：
- 扫描 `demand/<需求名>/prd/` 下所有 `.docx`、`.pdf`
- 读取 `demand/<需求名>/prd/prd-links.md` 中的飞书 / Lark 文档链接
- 扫描 `demand/<需求名>/prd/*.md` 和 `demand/<需求名>/demand.md` 中出现的飞书 / Lark 文档链接
- 本地文档按本地转换链路解析；飞书 / Lark 文档必须调用本机 `lark-doc` skill 解析
- 将所有 PRD 来源合并为结构化 Markdown

### 1.3 解析 Figma 设计稿

检查 `demand/<需求名>/figma/figma-links.md` 是否有实质内容（不是空模板）。

**有内容 + Figma MCP 可用：**
读取 `references/figma-analyzer.md`，按 MCP 模式步骤执行。

**有内容但 MCP 不可用：**
读取 `references/figma-analyzer.md`，按截图引导模式步骤执行：提醒用户粘贴截图或提供详细文字描述，基于现有信息分析。

**无内容（空模板）：**
跳过 Figma 解析。提示用户补充设计参考。

### 1.4 解析 API 文档

读取 `references/api-spec-analyzer.md`，按步骤执行：
- 扫描 `demand/<需求名>/api/` 目录下所有 `.md` 文件（排除 README.md）
- 逐个解析后合并为统一接口清单，标注复用/新建

### 1.5 输出

将所有解析结果整合写入 `demand/<需求名>/output/requirements.md`。

---

## 阶段 2: 分析需求

[阶段 2/10] 分析需求...

### 2.1 加载框架规范

根据 `.harness-env.json` 中的 `framework` 字段加载对应规范：
- Vue → 读取 `references/vue-best-practices.md`
- React → 读取 `references/react-best-practices.md`

### 2.2 扫描项目资产

读取 `references/component-scanner.md`，**全量扫描**（scope: full）：
- 组件、hooks、utils、api、store、路由、权限、i18n

### 2.3 需求分析

结合阶段 1 的需求文档和扫描结果：
1. 识别需要哪些页面和组件
2. 识别每个组件的 UI 状态（空态、加载中、错误、正常、hover、弹窗等）
3. 标注可复用的现有组件/函数
4. 梳理 API 调用关系和数据流
5. 确定 i18n key 规划
6. 确定路由注册方案
7. 确定权限配置方案

### 2.4 疑问确认

如有不确定的地方，**必须停下来问**。不猜测。

### 2.5 输出

写入 `demand/<需求名>/output/component-map.md`。

---

## 阶段 3: 生成实现计划

[阶段 3/10] 生成实现计划...

基于前面所有产出，生成实现计划：

1. 列出所有要新建的文件（组件、页面、API、store、i18n 等）
2. 列出所有要修改的文件
3. 按依赖顺序排列实现步骤
4. 标注每步复用的现有资产
5. 标注 i18n 文案处理方案
6. 标注路由和权限注册步骤

### 输出

写入 `demand/<需求名>/output/implementation-plan.md`。

### ⏸️ 审批门禁

**停下来等用户审批。在用户明确表示"开始实现"、"批准"、"approved"等之前，不写任何业务代码。**

---

## 阶段 4: 准备实施环境

[阶段 4/10] 准备实施环境...

审批通过后，写代码前：

1. **确认分支** — 当前是否在 `feature/<需求名>` 分支
   - 不在 → 创建并切换
2. **确认工作区干净** — `git status` 无未提交变更
3. **同步最新代码** — `git pull`（如有远程）

---

## 阶段 5: 代码实现

[阶段 5/10] 代码实现...

**单 Agent 顺序执行**（不启动子 Agent），按实现计划逐步编码：

1. 严格按 implementation-plan.md 中的步骤顺序执行
2. 遵循框架规范（阶段 2 加载的 best-practices）
3. 优先复用项目已有组件/函数，没有也不过度封装
4. 实现所有 UI 状态（loading、error、empty、正常）
5. API 对接（在 `{{apiDir}}` 下新建或复用函数）
6. i18n 处理（所有文案走国际化，中文开发者填，英文 AI 翻译，日文/西班牙文 AI 翻译 + 标 TODO）
7. 路由注册（新页面加入路由表，懒加载）
8. 权限配置（需要权限控制的功能加权限指令）
9. 有 design.md → 遵循设计规范；无 → 按 Figma/截图一比一还原

---

## 阶段 6: E2E 验证（可选）

[阶段 6/10] E2E 验证...

读取 `references/phases/verify-e2e.md`，传入：
- 变更页面/组件：本次需求涉及的所有页面
- 验证重点：feat（新功能可访问、关键交互可用、数据展示正确）
- 截图存储路径：`demand/<需求名>/screenshots/`

根据验证结果决定是否继续：
- ✅ 全部通过 → 继续下一阶段
- ⚠️ Playwright 未安装或无法启动 → 自动跳过，继续下一阶段
- ❌ 测试失败 → 回到阶段 5 修复后重新验证

---

## 阶段 7: 自查 + 代码审查

[阶段 7/10] 自查 + 代码审查...

实现完成后，**自行按 code-reviewer 的规则审查代码**。

读取 `references/code-reviewer.md`，使用 **demand profile（全部 8 维度）**：
1. 框架规范合规
2. 组件复用
3. UI 状态完整性
4. 可访问性
5. 安全性
6. i18n 完整性
7. 路由/权限注册
8. 设计规范合规

**发现问题 → 立即修复 → 再次自查。最多 2 轮自查-修复循环。**

如果 2 轮后仍有无法自行解决的问题 → 列出问题告知用户。

---

## 阶段 8: 代码验证（强制）

[阶段 8/10] 代码验证...

读取 `references/phases/verify-code.md`，传入：
- 工作流类型：feat
- 变更文件列表：本次任务涉及的所有文件

根据验证报告的总判定决定是否继续：
- ✅ 全部通过 → 继续下一阶段
- ⚠️ 验证不完整 → 继续，但在最终输出中标注
- ❌ 未通过 → 修复后重试，连续 3 次失败 → 报告失败详情并停止

---

## 阶段 9: 测试验证

[阶段 9/10] 测试验证...

读取 `references/phases/verify-test.md`，传入：
- 测试范围：强制（全量）
- 测试用例文档：`demand/<需求名>/test/test-cases.md`（如存在）

根据测试结果决定是否继续：
- ✅ 全部通过 → 继续下一阶段
- ⚠️ 无测试文件 → 跳过，继续下一阶段
- ❌ 测试失败 → 修复后重试

---

## 阶段 10: 完成报告

[阶段 10/10] 生成完成报告...

### 10.1 完成报告

写入 `demand/<需求名>/output/report.md`，包含：
- 实现的功能摘要
- 新建/修改的文件列表
- 自查审查结果摘要
- 代码验证结果（阶段 8 输出）
- 测试验证结果（阶段 9 输出）
- E2E 验证结果（阶段 6 输出，如已执行）
- 遗留问题（如有）

### 10.2 清理确认

询问用户是否清理 `demand/<需求名>/output/` 中的中间产物（requirements.md、component-map.md），仅保留 implementation-plan.md 和 report.md。
