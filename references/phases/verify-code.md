# 代码验证阶段（Phase: Verify Code）

> 所有代码修改工作流的强制验证阶段。
> 工作流通过「读取 references/phases/verify-code.md 执行」调用。

## 输入
- 当前工作流类型（feat/bug/change/refactor/hotfix/chore/perf）— 用于 build 缺失时的分级判定
- 本次任务变更的文件列表 — 用于修复范围防护

## 配置
lint-verify.md 会自动从 .harness-env.json 读取 overrides 配置。
如果项目配置了 overrides（如 format.required=false），验证链会自动适配。
无需在工作流层面传递 overrides 参数。

## 执行
读取 references/lint-verify.md，按步骤执行完整验证链。

## 进度输出
执行过程中按以下格式输出进度：
  [验证 1/5] Lint 检查...
  [验证 2/5] Format 检查...
  [验证 3/5] Build 验证...
  [验证 4/5] 类型检查...
  [验证 5/5] 测试执行...

## 输出
lint-verify.md 定义的标准验证报告（Markdown 表格）。

## 硬门禁规则
> 本阶段是硬门禁。不论项目是否配置了 IDE hook，此步骤都必须显式执行。
> Hook（如 lint-format.sh）作为额外安全网存在，不替代本阶段。
