# perf: 性能优化

## 用法

```
perf: <优化目标>
```

性能优化工作流，核心特点是 Before/After 基准对比，用数据说话。

> **执行模式说明：** 本工作流中所有「调用 references/xxx.md」均指**读取对应文件，按其中步骤顺序执行**。所有步骤由当前 Agent 顺序完成，不启动子 Agent。

---

## 阶段 0: 环境预检

[阶段 0/9] 环境预检...

1. **读取环境配置** — 检查 `.harness-env.json` 是否存在：
   - 不存在 → 调用 `references/framework-detector.md` 执行环境探测
   - 存在 → 读取缓存
2. **确认 node_modules 存在** — 不存在则提示安装
3. **确认构建正常** — `{{packageManager}} run build` 能通过（优化前必须有可用基线）

---

## 阶段 1: 性能基准采集（Before）

[阶段 1/9] 性能基准采集...

在任何优化之前，先采集当前性能指标作为基线：

### 1.1 Bundle Size

```bash
cd {{appDir}} && {{packageManager}} run build
```

记录：
- 总产物大小
- 各 chunk 大小（重点关注入口 chunk 和最大 chunk）
- 是否存在过大的单个 chunk（>250KB gzip）

### 1.2 Lighthouse 分数（如适用）

如果是 Web 应用，记录关键指标：
- Performance 分数
- FCP（First Contentful Paint）
- LCP（Largest Contentful Paint）
- TBT（Total Blocking Time）
- CLS（Cumulative Layout Shift）

### 1.3 关键渲染路径

分析目标页面：
- 首屏关键资源数量和大小
- 阻塞渲染的 JS/CSS
- 图片加载策略

### 1.4 记录 Before 指标

将所有采集到的数据记录下来，作为优化后对比的基线。

---

## 阶段 2: 分析瓶颈

[阶段 2/9] 分析瓶颈...

### 2.1 加载框架规范

根据 `.harness-env.json` 中的 `framework` 字段加载对应规范：
- Vue → 读取 `references/vue-best-practices.md`
- React → 读取 `references/react-best-practices.md`

### 2.2 代码层面分析

1. **Bundle 分析** — 检查 webpack-bundle-analyzer / rollup-plugin-visualizer 输出
   - 识别过大的依赖
   - 识别重复打包的模块
   - 识别未使用的代码（tree-shaking 失败）

2. **运行时分析**
   - React：React Profiler 定位不必要的 re-render
   - Vue：Vue DevTools Performance 面板定位慢组件
   - 通用：Chrome DevTools Performance 面板分析 Long Task

3. **网络层分析**
   - 资源加载瀑布图
   - 未压缩的资源
   - 缺少缓存策略的请求

### 2.3 瓶颈清单

输出瓶颈清单，按影响程度排序：
- 瓶颈描述
- 影响程度（高/中/低）
- 可能的优化方向

---

## 阶段 3: 制定优化方案

[阶段 3/9] 制定优化方案...

基于瓶颈分析，制定具体优化方案：

1. 列出每项优化措施
2. 预估优化效果
3. 标注风险和注意事项
4. 按优先级排序（投入产出比）

### ⏸️ 审批门禁

**停下来等用户确认优化方案。在用户明确表示"开始优化"、"批准"、"approved"等之前，不动代码。**

---

## 阶段 4: 实施优化

[阶段 4/9] 实施优化...

按用户批准的方案逐项实施：

### 常见优化手段

**Bundle 优化：**
- 路由懒加载 `() => import()`
- 大型库按需引入（如 lodash-es、dayjs 替代 moment）
- 动态导入非首屏组件 `defineAsyncComponent` / `React.lazy`
- 图片压缩 + WebP 格式 + 懒加载

**运行时优化：**
- React：React Compiler 自动优化 / 手动 `useMemo` + `useCallback`（仅 Profiler 确认有问题时）
- Vue：`v-memo`、`shallowRef`、`markRaw`
- 长列表虚拟滚动
- 防抖/节流频繁操作

**网络优化：**
- 预加载关键资源 `<link rel="preload">`
- 预连接第三方域名 `<link rel="preconnect">`
- 合理的缓存策略

### 实施原则

- 每项优化独立实施，便于对比效果
- 遵循框架规范
- 不改变功能行为

---

## 阶段 5: 性能基准对比（After）

[阶段 5/9] 性能基准对比...

### 5.1 重新采集指标

按照阶段 1 相同的方式重新采集所有指标。

### 5.2 Before vs After 对比

输出对比表格：

```
| 指标 | Before | After | 变化 |
|------|--------|-------|------|
| Bundle Size | xx KB | xx KB | -xx% |
| LCP | xx s | xx s | -xx% |
| ... | ... | ... | ... |
```

### 5.3 优化效果评估

- 哪些优化有效、效果多大
- 哪些优化效果不明显
- 是否达到预期目标

---

## 阶段 6: E2E 验证（可选）

[阶段 6/9] E2E 验证...

读取 `references/phases/verify-e2e.md`，传入：
- 变更页面/组件：本次优化涉及的页面
- 验证重点：perf（优化后功能不受影响）

根据验证结果决定是否继续：
- ✅ 全部通过 → 继续下一阶段
- ⚠️ Playwright 未安装或无法启动 → 自动跳过，继续下一阶段
- ❌ 测试失败 → 回到阶段 4 修复后重新验证

---

## 阶段 7: 代码验证（强制）

[阶段 7/9] 代码验证...

读取 `references/phases/verify-code.md`，传入：
- 工作流类型：perf
- 变更文件列表：本次任务涉及的所有文件

根据验证报告的总判定决定是否继续：
- ✅ 全部通过 → 继续下一阶段
- ⚠️ 验证不完整 → 继续，但在最终输出中标注
- ❌ 未通过 → 修复后重试，连续 3 次失败 → 报告失败详情并停止

---

## 阶段 8: 测试验证

[阶段 8/9] 测试验证...

读取 `references/phases/verify-test.md`，传入：
- 测试范围：性能相关

根据测试结果决定是否继续：
- ✅ 全部通过 → 继续下一阶段
- ⚠️ 无测试文件 → 跳过，继续下一阶段
- ❌ 测试失败 → 修复后重试

---

## 阶段 9: 优化报告

[阶段 9/9] 生成优化报告...

输出：
- **优化目标**：针对什么做了性能优化
- **Before 指标**：优化前的性能数据
- **After 指标**：优化后的性能数据
- **优化措施**：做了哪些具体优化
- **效果总结**：整体提升幅度
- **后续建议**：还有哪些可以继续优化的方向
