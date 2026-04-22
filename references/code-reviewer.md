# code-reviewer — 代码审查

## 用途

对变更代码进行审查，输出问题列表。不同工作流使用不同的审查 profile。

## 审查 Profile

### demand profile（全部 8 维度）— feat: 使用

1. 框架规范合规
2. 组件复用
3. UI 状态完整性
4. 可访问性
5. 安全性
6. i18n 完整性
7. 路由/权限注册
8. 设计规范合规

### modify profile（4 维度）— change: 使用

1. 框架规范合规
2. 组件复用
3. UI 状态完整性
4. 设计规范合规

### fix profile（2 维度）— bug: 使用

1. 框架规范合规
2. 安全性（确认修复没引入新问题）

### refactor profile（3 维度）— refactor: 使用

1. 框架规范合规
2. 组件复用（重构后复用度是否提升）
3. 安全性（确认重构没引入新问题、没改变外部行为）

---

## 输入

- 变更文件列表（通过 `git diff --name-only` 获取或手动指定）
- 使用哪个 profile（demand / modify / fix / refactor）
- 框架规范文件（`references/vue-best-practices.md` 或 `references/react-best-practices.md`）
- design.md 内容（如有）

## 输出格式

```
## 审查结果

Profile: demand / modify / fix / refactor
检查维度: X 项

### 问题列表

| 严重度 | 维度 | 文件:行号 | 描述 | 建议修复 |
|--------|------|-----------|------|----------|

### 总结

发现 X 个阻塞问题、Y 个建议改进。
```

严重度级别：
- 🔴 阻塞：必须修复
- 🟡 建议：代码可用但建议改进
- 🟢 信息：纯建议性提示

---

## 各维度详细检查项

### 维度 1: 框架规范合规（所有 profile）

**Vue 项目：**
- [ ] `<script setup>` 语法
- [ ] ref/reactive 使用合理
- [ ] `storeToRefs()` 解构 store
- [ ] `<style lang="scss" scoped>`
- [ ] `defineProps` / `defineEmits` 声明

**React 项目：**
- [ ] 普通函数组件（非 React.FC）
- [ ] 无不必要的 useMemo/useCallback
- [ ] Props 用 interface 定义
- [ ] 无 `any` 类型

### 维度 2: 组件复用（demand + modify + refactor profile）

- [ ] 使用了项目已有组件（而非重新实现）
- [ ] 使用了已有的 hooks/composables
- [ ] 新建的抽象合理（不过度封装）

### 维度 3: UI 状态完整性（demand + modify profile）

- [ ] loading 状态
- [ ] error 状态
- [ ] empty 状态
- [ ] Figma 设计中的所有状态

### 维度 4: 可访问性（demand profile 才检查）

- [ ] 语义化 HTML
- [ ] 图片 alt 文本
- [ ] 表单 label 关联
- [ ] 键盘可达

### 维度 5: 安全性（demand + fix + refactor profile）

- [ ] 无 v-html / dangerouslySetInnerHTML 未净化
- [ ] 无用户输入拼接到 URL
- [ ] 无硬编码 token/密钥
- [ ] API 调用走统一 request

### 维度 6: i18n 完整性（demand profile 才检查）

- [ ] 所有文案走 $t() / t()
- [ ] 新 key 在所有语言文件中有条目

### 维度 7: 路由/权限注册（demand profile 才检查）

- [ ] 新页面已注册路由（懒加载）
- [ ] 权限功能配置了权限指令

### 维度 8: 设计规范合规（demand + modify profile）

- [ ] 有 design.md → 对照检查
- [ ] 无 design.md → 对照 Figma/截图还原度
