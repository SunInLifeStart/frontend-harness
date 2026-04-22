# doc-parser — PRD 文档解析

## 用途

将 PRD 来源转换为结构化 Markdown，供 `feat:` 工作流做需求分析。PRD 来源支持：

- 本地 `.docx`
- 本地 `.pdf`
- 飞书 / Lark 在线文档链接（`docx` / `doc` / `wiki`）

## 输入

- `demand/<需求名>/prd/` 目录
- `demand/<需求名>/prd/prd-links.md` 中的在线文档链接
- `demand/<需求名>/prd/*.md` 或 `demand/<需求名>/demand.md` 中出现的飞书 / Lark 文档链接

飞书 / Lark 链接识别规则：

- 域名包含 `.feishu.cn` 或 `.larksuite.com`
- 路径包含 `/docx/`、`/doc/`、`/wiki/`

> 不把 `/sheets/`、`/bitable/` 默认当 PRD。除非用户明确说明该表格就是需求来源，否则只在报告中标注「发现非文档型飞书链接，未自动解析」。

## 输出

结构化 Markdown 文本，包含：

- 来源清单（文件名或飞书 URL、标题、解析状态）
- 标题层级
- 表格
- 列表
- 图片 / 附件 / 画板位置标注
- 解析失败或权限不足的警告

最终写入 `demand/<需求名>/output/requirements.md`。

## 执行步骤

### Step 1: 收集 PRD 来源

扫描以下位置：

1. `demand/<需求名>/prd/` 下所有 `.docx`、`.pdf`
2. `demand/<需求名>/prd/prd-links.md`
3. `demand/<需求名>/prd/*.md`
4. `demand/<需求名>/demand.md`

输出来源清单：

```markdown
| 来源 | 类型 | 状态 | 说明 |
|------|------|------|------|
| prd/xxx.docx | docx | 待解析 | 本地文档 |
| https://xxx.feishu.cn/docx/... | feishu-docx | 待解析 | 飞书文档 |
```

### Step 2: 解析本地 docx

按优先级尝试：

1. macOS → `textutil -convert txt "<file>" -output /tmp/<name>.txt`
2. 有 pandoc → `pandoc "<file>" -t markdown -o /tmp/<name>.md`
3. 有 LibreOffice → `soffice --headless --convert-to txt:"Text" --outdir /tmp "<file>"`
4. 有 python3 + python-docx → `python3 -c "from docx import Document; ..."`
5. 在线提示 → 提示用户使用在线工具转换后粘贴
6. 回退 → 提示用户手动将 docx 内容粘贴为文本

### Step 3: 解析本地 pdf

按优先级尝试：

1. 有 pdftotext → `pdftotext "<file>" /tmp/<name>.txt`
2. 有 python3 + pypdf → `python3 -c "from pypdf import PdfReader; ..."`
3. 有 ghostscript → `gs -sDEVICE=txtwrite -o /tmp/<name>.txt "<file>"`
4. 在线提示 → 提示用户使用在线工具转换后粘贴
5. 回退 → 提示用户手动将 pdf 内容粘贴为文本

### Step 4: 解析飞书 / Lark 文档

当发现飞书 / Lark 文档链接时，必须使用本机飞书 skill 的能力解析，不要把链接当普通网页抓取。

执行规则：

1. 读取本机 `lark-doc` skill；它要求先读取 `lark-shared` 处理认证、身份和权限规则。
2. 对 `/docx/`、`/doc/` 链接，优先执行：

   ```bash
   lark-cli docs +fetch --doc "<飞书文档URL>" --as user
   ```

3. 对 `/wiki/` 链接，按 `lark-doc` / `lark-drive` 的 Wiki 规则处理：
   - `docs +fetch` 支持的 wiki 文档可直接 fetch
   - 如返回类型不明确，先解析 wiki 节点，拿到 `obj_type` 和 `obj_token`
   - `obj_type=docx/doc` → 继续按文档解析
   - `obj_type=sheet/bitable/slides/file/mindnote` → 默认不当 PRD 正文解析，除非用户明确指定
4. `docs +fetch` 默认返回 JSON，优先取 `title` 和 `markdown` 字段；如需要人工可读输出，可使用 `--format pretty`。
5. 大文档如果返回 `has_more=true`，使用 `--offset` / `--limit` 分页拉取，直到内容完整。
6. 文档中的媒体标签按以下方式保留位置：
   - `<image .../>` → `[图片: 飞书文档图片，token=...]`
   - `<file .../>` → `[附件: 文件名，token=...]`
   - `<whiteboard .../>` → `[画板: token=...]`

权限和配置处理：

- `lark-cli` 不存在 → 标注 `SKIPPED: 未安装 lark-cli`，提示安装/配置飞书 CLI，不中断工作流
- 未初始化 → 提示执行 `lark-cli config init --new`
- 需要用户身份 → 提示执行 `lark-cli auth login --domain <domain>` 或按缺失 scope 执行 `lark-cli auth login --scope "<scope>"`
- 权限不足 → 标注 `PERMISSION_DENIED`，提示用户确认当前账号是否有文档访问权限
- 解析失败 → 保留 URL 和失败原因，继续处理其他来源

### Step 5: 合并与结构化处理

将本地文档和飞书文档内容合并，按来源分节：

```markdown
# 需求解析结果

## 来源清单

| 来源 | 类型 | 状态 | 标题/说明 |
|------|------|------|-----------|

## PRD: <标题或文件名>

...
```

结构化规则：

1. 识别标题层级 → 转为 `#` / `##` / `###`
2. 识别表格 → 转为 Markdown 表格
3. 识别列表 → 转为 Markdown 列表
4. 标注图片、附件、画板位置
5. 保留原文中的重要格式（加粗、高亮）
6. 去掉明显的空白页、页眉页脚、重复目录

### Step 6: 输出

将合并后的 Markdown 写入 `demand/<需求名>/output/requirements.md`。

## 降级方案

无论转换是否成功，工作流都必须继续执行。

1. **单个来源失败**：记录失败原因，继续解析其他来源
2. **本地转换工具不可用**：提示用户手动将内容粘贴到 `demand.md` 或 `output/requirements.md`
3. **飞书权限不足**：记录 URL、身份、错误信息，提示用户授权或分享权限
4. **全部来源失败**：
   - 如果 `demand.md` 有文字描述 → 基于 `demand.md` 做结构化处理
   - 如果完全无内容 → 生成空模板，标注所有章节为「待补充」

失败标记格式：

```markdown
> ⚠️ PRD 来源解析失败：<来源>
> 原因：<原因>
> 处理建议：<下一步>
```
