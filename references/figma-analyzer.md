# figma-analyzer — Figma 设计解析

## 用途

通过 Figma MCP 提取设计稿信息，输出组件结构、UI 状态矩阵和样式参考值。

## 输入

- `figma-links.md` 文件路径（包含 Figma URL + 页面说明）

## 输出

1. 组件树（层级结构）
2. 状态覆盖矩阵（每个组件有哪些状态变体）
3. 样式参考（间距、颜色、字体等）
4. 页面跳转关系

## 执行策略

```
检查 Figma MCP 是否可用
├── 可用 → 走 MCP 模式（完整解析）
└── 不可用 → 走截图引导模式（降级）
```

---

## MCP 模式（Figma MCP 可用）

### Step 1: 解析 figma-links.md

读取文件，提取：
- 每个 Figma URL
- 对应的页面名称和说明
- 用户标注的状态列表

### Step 2: 调用 Figma MCP

对每个 Figma URL：

1. 使用 Figma MCP 获取设计上下文
2. 提取 frame/layer 层级结构
3. 提取 auto-layout 信息（flex/grid 布局参考）
4. 提取 variant 列表（组件变体 = UI 状态）
5. 提取文本样式（字号、字重、颜色值）
6. 提取间距值（padding、gap）

### Step 3: 构建组件树

将 Figma 层级映射为前端组件树：
```
PageA
├── Header（导航栏）
├── FilterBar（筛选条）
├── DataTable（数据表格）
│   ├── TableHeader
│   ├── TableRow（可展开）
│   └── Pagination
└── ActionBar（操作栏）
```

### Step 4: 构建状态矩阵

```
| 组件 | default | empty | loading | error | hover | disabled |
|------|---------|-------|---------|-------|-------|----------|
| DataTable | ✅ | ✅ | ✅ | ✅ | - | - |
| Button | ✅ | - | ✅ | - | ✅ | ✅ |
```

### Step 5: 提取样式参考

```
间距: 页面内边距 24px，组件间距 16px，行间距 12px
颜色: 主色 #1890FF，文字 #333333，辅助文字 #999999
字体: 标题 16px/600，正文 14px/400，辅助 12px/400
```

### Step 6: 输出

将分析结果整理为 Markdown，用于后续实现参考。

---

## 截图引导模式（Figma MCP 不可用时降级）

**不跳过设计解析，改为引导用户提供截图。**

### Step 1: 提示用户

输出以下提示：
```
Figma MCP 未配置或不可用。请通过以下方式提供设计参考：

方式 1（推荐）：在对话中直接粘贴 UI 截图
方式 2：将截图文件放入 demand/<需求名>/figma/ 目录，命名为页面名称
方式 3：在 figma-links.md 中用文字详细描述每个页面的布局、组件和状态

配置 Figma MCP 的方法：在 settings.json 中添加
{
  "mcpServers": {
    "figma": { "type": "url", "url": "https://figma.com/mcp/v1" }
  }
}
```

### Step 2: 解析文字说明

读取 figma-links.md 中的文字描述，提取：
- 页面名称和用途
- 用户描述的组件列表
- 用户描述的状态列表
- 页面跳转关系

### Step 3: 如有截图

如果用户提供了截图（对话中粘贴或目录内文件）：
- 分析截图中的 UI 元素
- 推断组件结构
- 识别布局方式
- 提取可见的样式信息（颜色、间距等）

### Step 4: 构建组件树和状态矩阵

基于文字 + 截图信息，仍然输出组件树和状态矩阵（精度低于 MCP 模式，但不缺失）。

**标注：** 「基于文字描述/截图分析，建议开发中对照 Figma 原稿进行细节还原」
