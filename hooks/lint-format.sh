#!/bin/bash
# Stop hook: 自动执行 lint + format
# 仅在有源文件变更时运行，无变更则静默退出
# 自动检测包管理器和可用命令，适配不同项目配置

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

# 检测包管理器
if [ -f "pnpm-lock.yaml" ] || [ -f "$GIT_ROOT/pnpm-lock.yaml" ]; then
  PM="pnpm"
elif [ -f "yarn.lock" ] || [ -f "$GIT_ROOT/yarn.lock" ]; then
  PM="yarn"
else
  PM="npm run"
fi

# 从 package.json 检测可用命令
has_script() {
  node -e "const p=require('./package.json'); process.exit(p.scripts && p.scripts['$1'] ? 0 : 1)" 2>/dev/null
}

# 检测 lint 命令：lint > eslint > lint:fix
LINT_CMD=""
for cmd in lint eslint "lint:fix"; do
  if has_script "$cmd"; then
    LINT_CMD="$PM $cmd"
    break
  fi
done

# 检测 format 命令：format > prettier
FORMAT_CMD=""
for cmd in format prettier; do
  if has_script "$cmd"; then
    FORMAT_CMD="$PM $cmd"
    break
  fi
done

# 执行 lint
LINT_EXIT=0
LINT_OUTPUT=""
if [ -n "$LINT_CMD" ]; then
  LINT_OUTPUT=$($LINT_CMD 2>&1)
  LINT_EXIT=$?
fi

# 执行 format
if [ -n "$FORMAT_CMD" ]; then
  $FORMAT_CMD >/dev/null 2>&1
fi

# lint 失败 → 唤醒 Agent 修复
if [ $LINT_EXIT -ne 0 ]; then
  python3 -c "
import json, sys
reason = 'Lint 检查发现错误，请修复：\n\n' + sys.argv[1]
print(json.dumps({'decision': 'block', 'reason': reason}))
" "$LINT_OUTPUT"
  exit 0
fi

# 全部通过，静默退出
exit 0
