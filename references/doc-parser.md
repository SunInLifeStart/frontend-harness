# doc-parser — 文档解析

## 用途

将 PRD 文档（.docx / .pdf）转换为结构化 Markdown，供后续需求分析使用。

## 输入

- 文档文件路径（支持 .docx 和 .pdf）
- 可以是单个文件，也可以是包含多个文档的目录

## 输出

结构化 Markdown 文本，包含：标题层级、表格、列表、图片位置标注

## 执行步骤

### Step 1: 检测文件类型

扫描目标路径，列出所有 .docx 和 .pdf 文件。

### Step 2: 转换文档

**docx 文件（优先级从高到低）：**

1. macOS → `textutil -convert txt "<file>" -output /tmp/<name>.txt`
2. 有 pandoc → `pandoc "<file>" -t markdown -o /tmp/<name>.md`
3. 有 LibreOffice → `soffice --headless --convert-to txt:"Text" --outdir /tmp "<file>"`
4. 有 python3 + python-docx → `python3 -c "from docx import Document; ..."`
5. 在线提示 → 提示用户使用在线工具（如 Google Docs）转换后粘贴
6. 回退 → 提示用户手动将 docx 内容粘贴为文本

**pdf 文件（优先级从高到低）：**

1. 有 pdftotext → `pdftotext "<file>" /tmp/<name>.txt`
2. 有 python3 + pypdf → `python3 -c "from pypdf import PdfReader; ..."`
3. 有 ghostscript → `gs -sDEVICE=txtwrite -o /tmp/<name>.txt "<file>"`
4. 在线提示 → 提示用户使用在线工具（如 Smallpdf）转换后粘贴
5. 回退 → 提示用户手动将 pdf 内容粘贴为文本

### Step 3: 读取转换结果

从 /tmp/ 读取转换后的文本文件。

### Step 4: 结构化处理

1. 识别标题层级（通过字号、加粗、编号等特征）→ 转为 # / ## / ###
2. 识别表格 → 转为 Markdown 表格
3. 识别列表（有序/无序）→ 转为 Markdown 列表
4. 标注图片位置 → `[图片: 此处有插图，描述见上下文]`
5. 保留原文中的重要格式（加粗、高亮）

### Step 5: 输出

将处理后的 Markdown 写入 `output/requirements.md`（feat: 工作流）或直接返回文本（其他场景）。

## 降级方案

如果所有转换工具都不可用：
- 输出提示：「文档转换工具不可用，请手动将文档内容粘贴到 demand.md 或 output/requirements.md 中」
- 不中断工作流，继续读取 demand.md 中的文字描述

### 降级流程（关键：转换失败不中断工作流）

无论转换是否成功，工作流都**必须继续执行**。降级处理流程如下：

1. **逐级尝试**：按上述优先级依次检测工具可用性，尝试转换
2. **单工具失败 → 自动跳到下一优先级**：某个工具执行报错时，捕获异常，继续尝试下一个
3. **全部失败 → 标注警告，继续执行**：
   - 在输出中插入：`⚠️ 文档转换未执行，请手动补充需求内容`
   - 后续步骤（Step 3 ~ Step 5）正常继续
   - 根据实际可用内容调整分析深度：
     - 如果 demand.md 中有文字描述 → 基于文字描述进行结构化处理
     - 如果完全无内容 → 生成空模板，标注所有章节为「待补充」
4. **部分成功 → 合并可用内容**：多文件场景下，部分文件转换成功、部分失败时，合并已成功的内容，对失败文件单独标注 `⚠️ [文件名] 转换失败，内容待手动补充`
