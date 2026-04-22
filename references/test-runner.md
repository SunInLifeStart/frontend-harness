# test-runner — 测试执行

## 用途

执行测试验证。两种模式，**判定语义严格区分**：
1. **模式 A: Markdown 测试用例** → 静态检查 + checklist，判定为 `STATIC CHECK PASS` / `STATIC CHECK FAIL` / `NEEDS MANUAL VERIFY`
2. **模式 B: 自动化测试文件** → 实际运行，判定为 `PASS` / `FAIL`

> **核心原则：只有模式 B（实际运行测试）才有资格给出 PASS / FAIL。模式 A 的判定永远不叫 PASS，只叫 STATIC CHECK PASS 或 NEEDS MANUAL VERIFY。**

## 输入

- 测试文件路径
- 可选：关联的源代码文件路径

## 输出

检查清单或测试运行结果

---

## 模式 A: Markdown 测试用例（test-cases.md）

**重要：这是静态分析，不是实际执行。判定结果为 STATIC CHECK PASS / STATIC CHECK FAIL / NEEDS MANUAL VERIFY，永远不输出 PASS / FAIL。**

### 步骤

```
1. 读取 test-cases.md，解析所有测试用例
2. 对每个用例，区分「可静态验证」和「需人工验证」：
   ├── 可静态验证 — 代码层校验：
   │   ├── 对应的函数/组件是否存在
   │   ├── 入参类型是否匹配
   │   └── 关键分支是否覆盖（empty / error / loading 状态）
   └── 需人工验证 — 无法通过代码分析确认：
       └── UI 表现、交互行为、视觉还原等
3. 对可静态验证项执行代码层校验，给出 STATIC CHECK PASS / STATIC CHECK FAIL
4. 对需人工验证项生成 [ ] 待验证 checklist
5. 输出汇总判定
```

### 输出格式

**Part 1: 静态检查结果**
```markdown
## 静态检查结果

| # | 用例 | 检查项 | 结果 | 关键代码位置 |
|---|------|--------|------|-------------|
| 1 | 正常提交流程 | handleSubmit 函数存在 | ✅ STATIC CHECK PASS | Form.vue:42-58 |
| 2 | 空数据展示 | 空态分支处理存在 | ✅ STATIC CHECK PASS | List.vue:15 |
| 3 | 接口报错处理 | catch 块存在且有 UI 反馈 | ❌ STATIC CHECK FAIL — catch 块无 UI 反馈 | api.js:23 |
| 4 | 超长文本输入 | 长度限制逻辑存在 | ❌ STATIC CHECK FAIL — 未找到长度限制 | - |
```

**Part 2: 待人工验证清单**
```markdown
## 待人工验证清单

- [ ] 正常提交流程：实际提交行为是否符合预期
- [ ] 空数据展示：空态 UI 是否正确渲染
- [ ] 接口报错处理：错误提示文案与交互
```

**Part 3: 汇总判定**
```markdown
## 判定

<!-- 规则（三选一，严格执行）：
  - 静态检查项全部 PASS + 无人工验证项 → STATIC CHECK PASS
  - 静态检查项有 FAIL               → STATIC CHECK FAIL，列出失败项
  - 静态检查项全部 PASS + 存在人工验证项 → NEEDS MANUAL VERIFY，列出待确认项
-->

**NEEDS MANUAL VERIFY** — 静态检查 2/4 通过，2 项失败，3 项待人工确认

失败项：
- #3 接口报错处理：catch 块无 UI 反馈
- #4 超长文本输入：未找到长度限制

待人工确认：
- [ ] 正常提交流程：实际提交行为
- [ ] 空数据展示：空态 UI
- [ ] 接口报错处理：错误提示文案与交互
```

**建议：** 如果用例较多，建议生成可执行测试文件（Vitest/Jest），放在 test/ 目录下实际运行，获得真正的 PASS/FAIL 判定。

### 生成可执行测试（可选）

当 test-cases.md 包含 3 个以上用例时，建议同时生成对应的可执行测试文件：
- Vue 项目 → `demand/<需求名>/test/<module>.spec.js`（Vitest）
- React 项目 → `demand/<需求名>/test/<module>.test.tsx`（Jest）
- 然后按模式 B 实际运行

---

## 模式 B: 自动化测试文件（vitest / jest / playwright）

**这是唯一有资格给出 PASS / FAIL 的模式 — 基于实际运行结果，可信。**

```
1. 检测测试框架（从 .harness-env.json 读取 testFramework）：
   ├── vitest → npx vitest run <file> --reporter=verbose
   ├── jest → npx jest <file> --verbose
   ├── playwright → npx playwright test <file> --reporter=list
   └── none → 输出提示，跳过
2. 解析运行结果：
   ├── 通过的用例列表
   ├── 失败的用例 + 错误信息 + 堆栈
   └── 总计：X passed, Y failed, Z skipped
3. 判定（基于实际运行）：
   ├── 全部通过 → **PASS**
   └── 有失败   → **FAIL**，列出失败用例
```

---

## 无测试文件

如果目标路径下没有任何测试文件：
- 输出：「无测试用例，跳过测试阶段。」
- 不中断工作流
