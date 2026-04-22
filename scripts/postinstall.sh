#!/bin/bash
# postinstall.sh — 补充 npx skills add 之外的 agent 专属配置
# 用法：bash <skill-dir>/scripts/postinstall.sh [project-root]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "${1:-.}" && pwd)"

echo ""
echo "🔧 Frontend Harness 补充安装"
echo "   Skill 目录: $SKILL_DIR"
echo "   项目根目录: $PROJECT_ROOT"
echo ""

# ──────────────────────────────────
# 1. Claude Code 专属配置
# ──────────────────────────────────
setup_claude() {
  echo "[Claude Code] 配置中..."

  # 1.1 安装 hooks
  local HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
  mkdir -p "$HOOKS_DIR"
  if [ -f "$HOOKS_DIR/lint-format.sh" ]; then
    echo "  hooks/lint-format.sh 已存在，跳过（避免覆盖自定义修改）"
  else
    cp "$SKILL_DIR/hooks/lint-format.sh" "$HOOKS_DIR/"
    chmod +x "$HOOKS_DIR/lint-format.sh"
    echo "  hooks/lint-format.sh ✓"
  fi

  # 1.2 合并 settings.json（hooks 配置）
  local SETTINGS="$PROJECT_ROOT/.claude/settings.json"
  if [ ! -f "$SETTINGS" ]; then
    cat > "$SETTINGS" << 'SETTINGS_EOF'
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$(git rev-parse --show-toplevel)/.claude/hooks/lint-format.sh\"",
            "timeout": 120000
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
    echo "  settings.json ✓（新建）"
  else
    echo "  settings.json 已存在，跳过（请手动确认 hooks 配置）"
  fi

  # 1.3 安装模板文件
  local TPL_DIR="$PROJECT_ROOT/.claude/templates"
  mkdir -p "$TPL_DIR"
  local count=0
  for tpl in "$SKILL_DIR/templates/"*.tpl; do
    [ -f "$tpl" ] || continue
    local basename
    basename=$(basename "$tpl")
    if [ ! -f "$TPL_DIR/$basename" ]; then
      cp "$tpl" "$TPL_DIR/"
      count=$((count + 1))
    fi
  done
  echo "  templates: ${count} 个新文件 ✓"

  echo "[Claude Code] 完成"
}

# ──────────────────────────────────
# 2. 检测已安装的 agent 并配置
# ──────────────────────────────────

# Claude Code
if [ -d "$PROJECT_ROOT/.claude" ]; then
  setup_claude
else
  echo "[Claude Code] 未检测到 .claude/ 目录，跳过"
  echo "  如需启用，先运行: npx skills add zhumo/frontend-harness -a claude-code"
fi

# Cursor / Codex / 其他 agent — npx skills add 已处理 skill 分发
echo ""
echo "────────────────────────────────"
echo "✅ 安装完成"
echo ""
echo "提示："
echo "  • skill 文件已由 npx skills add 安装到各 agent 目录"
echo "  • 本脚本仅补充 hooks、settings、templates 等 agent 专属配置"
echo "  • 建议将 .harness-env.json 加入 .gitignore"
echo ""
echo "使用方式：在对话中输入以下前缀触发工作流"
echo "  feat: <需求名>     — 新需求端到端实现"
echo "  bug: <问题描述>    — Bug 修复"
echo "  change: <修改描述> — 局部修改"
echo "  refactor: <目标>   — 代码重构"
echo "  init: <需求名>     — 初始化需求目录"
echo ""
