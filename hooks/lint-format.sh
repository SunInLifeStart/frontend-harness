#!/bin/bash
# ============================================
# lint-format.sh — Claude Code Stop Hook
# ============================================
# 适用范围：仅 Claude Code 环境
# 定位：安全网（额外保障），非主链路
# 主链路：工作流中显式调用 references/phases/verify-code.md
# 其他 IDE（Cursor/Copilot 等）通过工作流内验证保障
# ============================================

INPUT=$(cat)

# 防止无限循环：Stop hook 已激活时直接退出
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "True" ]; then
  exit 0
fi

# 确定应用目录：优先从 .harness-env.json 读取 appDir
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
ENV_FILE="$GIT_ROOT/.harness-env.json"

if [ -f "$ENV_FILE" ]; then
  APP_DIR_REL=$(python3 -c "import json; d=json.load(open('$ENV_FILE')); print(d.get('appDir', '.'))" 2>/dev/null)
  if [ "$APP_DIR_REL" = "." ]; then
    APP_DIR="$GIT_ROOT"
  else
    APP_DIR="$GIT_ROOT/$APP_DIR_REL"
  fi
else
  APP_DIR="$GIT_ROOT"
fi

if [ ! -d "$APP_DIR" ]; then
  exit 0
fi

# 检查是否有源文件变更（已暂存 + 未暂存 + 未追踪）
CHANGED=$(git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)
MATCHING=$(echo "$CHANGED" | sort -u | grep -E '\.(vue|js|jsx|ts|tsx|scss|css)$' || true)

if [ -z "$MATCHING" ]; then
  exit 0
fi

cd "$APP_DIR"

# ============================================
# 包管理器检测
# ============================================
PACKAGE_MANAGER=""
if [ -f "pnpm-lock.yaml" ] || [ -f "$GIT_ROOT/pnpm-lock.yaml" ]; then
  PACKAGE_MANAGER="pnpm"
elif [ -f "yarn.lock" ] || [ -f "$GIT_ROOT/yarn.lock" ]; then
  PACKAGE_MANAGER="yarn"
else
  PACKAGE_MANAGER="npm"
fi

# ============================================
# 脚本名白名单验证
# ============================================
validate_script_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-zA-Z0-9_:.-]+$ ]]; then
    echo "Invalid script name: $name" >&2
    return 1
  fi
}

# 从 package.json 检测可用命令
has_script() {
  node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts['$1'] ? 0 : 1)" 2>/dev/null
}

# ============================================
# 带超时的安全命令执行
# ============================================
run_with_timeout() {
  local timeout_secs="$1"
  shift
  if command -v timeout &>/dev/null; then
    timeout "$timeout_secs" "$@" 2>&1
  elif command -v gtimeout &>/dev/null; then
    gtimeout "$timeout_secs" "$@" 2>&1
  else
    "$@" 2>&1  # 无 timeout 命令，直接执行
  fi
}

# ============================================
# 超时配置（秒）
# ============================================
LINT_TIMEOUT=${HARNESS_LINT_TIMEOUT:-120}
FORMAT_TIMEOUT=${HARNESS_FORMAT_TIMEOUT:-60}

# ============================================
# 检测 format 命令：format > prettier
# ============================================
FORMAT_SCRIPT=""
for cmd in format prettier; do
  if has_script "$cmd"; then
    validate_script_name "$cmd" || continue
    FORMAT_SCRIPT="$cmd"
    break
  fi
done

# ============================================
# 检测 lint 命令：lint > eslint > lint:fix
# ============================================
LINT_SCRIPT=""
for cmd in lint eslint "lint:fix"; do
  if has_script "$cmd"; then
    validate_script_name "$cmd" || continue
    LINT_SCRIPT="$cmd"
    break
  fi
done

# ============================================
# 阶段 1：执行 format（带超时 + 安全）
# ============================================
FORMAT_EXIT=0
FORMAT_OUTPUT=""
if [ -n "$FORMAT_SCRIPT" ]; then
  # 精确差集检测：记录 format 前的文件状态
  BEFORE_FILES=$(git diff --name-only 2>/dev/null || echo "")

  FORMAT_ARGS=("$PACKAGE_MANAGER" "run" "$FORMAT_SCRIPT")
  FORMAT_OUTPUT=$(run_with_timeout "$FORMAT_TIMEOUT" "${FORMAT_ARGS[@]}")
  FORMAT_EXIT=$?

  # format 失败直接 block
  if [ "$FORMAT_EXIT" -ne 0 ]; then
    python3 -c "
import json, sys
reason = 'Format 执行失败（exit code: ' + sys.argv[1] + '），请检查：\n\n' + sys.argv[2]
print(json.dumps({'decision': 'block', 'reason': reason}))
" "$FORMAT_EXIT" "$FORMAT_OUTPUT"
    exit 0
  fi

  # ============================================
  # 阶段 2：精确差集检测（BEFORE/AFTER）
  # ============================================
  AFTER_FILES=$(git diff --name-only 2>/dev/null || echo "")
  FORMAT_CHANGED_FILES=$(comm -13 <(echo "$BEFORE_FILES" | sort) <(echo "$AFTER_FILES" | sort) 2>/dev/null || echo "")

  # ============================================
  # 阶段 3：format 变更文件数量阈值检查
  # ============================================
  FORMAT_THRESHOLD=${HARNESS_FIX_THRESHOLD:-50}
  FORMAT_COUNT=0
  if [ -n "$FORMAT_CHANGED_FILES" ]; then
    FORMAT_COUNT=$(echo "$FORMAT_CHANGED_FILES" | grep -c '.' 2>/dev/null || echo 0)
  fi

  if [ "$FORMAT_COUNT" -gt "$FORMAT_THRESHOLD" ]; then
    python3 -c "
import json, sys
count = sys.argv[1]
threshold = sys.argv[2]
reason = 'Format 变更文件数（' + count + '）超过安全阈值（' + threshold + '），可能存在异常批量修改，请人工确认。'
print(json.dumps({'decision': 'block', 'reason': reason}))
" "$FORMAT_COUNT" "$FORMAT_THRESHOLD"
    exit 0
  fi
fi

# ============================================
# 阶段 4：执行 lint（带超时 + 安全）
# ============================================
LINT_EXIT=0
LINT_OUTPUT=""
if [ -n "$LINT_SCRIPT" ]; then
  LINT_ARGS=("$PACKAGE_MANAGER" "run" "$LINT_SCRIPT")
  LINT_OUTPUT=$(run_with_timeout "$LINT_TIMEOUT" "${LINT_ARGS[@]}")
  LINT_EXIT=$?
fi

# ============================================
# 阶段 5：结果报告
# ============================================

# lint 失败 → 唤醒 Agent 修复
if [ "$LINT_EXIT" -ne 0 ]; then
  python3 -c "
import json, sys
reason = 'Lint 检查发现错误，请修复：\n\n' + sys.argv[1]
print(json.dumps({'decision': 'block', 'reason': reason}))
" "$LINT_OUTPUT"
  exit 0
fi

# format 有变更文件 → 提示（非 block）
if [ -n "$FORMAT_CHANGED_FILES" ]; then
  python3 -c "
import json, sys
files = sys.argv[1]
reason = 'Format 自动修正了以下文件，请确认变更：\n\n' + files
print(json.dumps({'decision': 'block', 'reason': reason}))
" "$FORMAT_CHANGED_FILES"
  exit 0
fi

# 全部通过，静默退出
exit 0
