# PRD 文档来源

## 本地文档

将 `.docx` / `.pdf` 文件直接放在当前 `prd/` 目录下。

## 飞书 / Lark 文档

把飞书文档链接填在这里。`feat:` 工作流会自动识别并调用本机飞书 skill 解析。

支持：

- `https://xxx.feishu.cn/docx/...`
- `https://xxx.feishu.cn/doc/...`
- `https://xxx.feishu.cn/wiki/...`
- `https://xxx.larksuite.com/docx/...`
- `https://xxx.larksuite.com/wiki/...`

示例：

```markdown
- 标题：{{需求名称}} PRD
  链接：https://xxx.feishu.cn/docx/xxxxxxxx
  说明：主 PRD
```

## 注意

- 飞书文档需要当前账号有访问权限。
- 如果首次使用飞书 CLI，需要先完成 `lark-cli config init --new` 和用户授权。
- 表格、Base、幻灯片默认不会当 PRD 正文解析，除非你明确说明它就是需求来源。
