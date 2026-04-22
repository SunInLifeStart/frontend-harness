# E2E 验证阶段（Phase: Verify E2E）

> Playwright 功能验证与 UI 截图对比阶段。
> 工作流通过「读取 references/phases/verify-e2e.md 执行」调用。
> 本阶段为**可选步骤**，Playwright 未安装时自动跳过。

## 输入
- 本次变更涉及的页面/组件列表
- 验证重点（由调用工作流决定）：
  - feat → 新功能可访问、关键交互可用、数据展示正确
  - bug → 复现场景已修复、关联功能无回归
  - change → 修改效果符合预期、关联功能无回归
  - refactor → 功能等价性（重构前后行为一致）
  - hotfix → 紧急问题已修复、核心流程正常
  - perf → 优化后功能不受影响

## 前置条件检查

1. **读取环境缓存** — 检查 `.harness-env.json` 中的 `playwright.installed` 字段：
   - `true` → 进入功能验证（可从 `playwright.version` 获取版本号用于报告输出）
   - `false` → 输出「Playwright 未安装，跳过 E2E 验证。」，**结束本阶段**
   - 字段不存在 → 执行实时检测（`npx playwright --version`），将结果回写到 `.harness-env.json`
2. 检查项目是否有 Playwright 测试配置（如 `playwright.config.ts`）
3. 确认开发服务器可启动并访问目标页面
   - 无法启动 → 输出「开发服务器无法启动，跳过 E2E 验证。」，**结束本阶段**

## 功能验证

针对本次变更涉及的页面/组件，编写或运行 Playwright 测试：
1. 页面可访问性 — 目标页面能正常加载，无控制台报错
2. 关键交互验证 — 按钮点击、表单提交、弹窗展示等核心交互正常
3. 数据展示验证 — 列表渲染、详情展示等数据绑定无误
4. 如果项目已有 e2e 测试 → 优先运行受本次修改影响的测试用例

## UI 截图对比（推荐）

使用 Playwright 的 `page.screenshot()` API 进行截图对比：
1. **修改前基准截图**（如有条件）：修改前对目标页面截图，存入 `screenshots/before/`
2. **修改后截图**：修改完成后对同一页面截图，存入 `screenshots/after/`
3. **对比结果**：列出每个页面的 before/after 截图路径，标注视觉变化是否符合预期

## 输出

输出验证摘要：
- 通过/失败的测试列表
- 截图对比摘要（如已执行）
- 如有失败项 → 标注需要关注的问题，返回调用方修复后重新验证
