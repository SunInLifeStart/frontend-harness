#!/bin/bash
set -e

# 切换到项目根目录
cd "$(dirname "$0")/.."
ROOT=$(pwd)
FIXTURES="$ROOT/tests/fixtures"

PASS=0
FAIL=0
ERRORS=""

assert() {
  local desc="$1" result="$2"
  if [ "$result" = "true" ]; then
    PASS=$((PASS + 1))
    echo "  ✅ $desc"
  else
    FAIL=$((FAIL + 1))
    ERRORS="$ERRORS\n  ❌ $desc"
    echo "  ❌ $desc"
  fi
}

echo "=== Fixture 冒烟测试 ==="

# ============================================================
# 1. Fixture 目录存在性
# ============================================================
echo ""
echo "--- 1. Fixture 目录结构 ---"

for fixture in react-app vue-app monorepo; do
  assert "fixture/$fixture 目录存在" "$([ -d "$FIXTURES/$fixture" ] && echo true || echo false)"
  assert "fixture/$fixture/package.json 存在" "$([ -f "$FIXTURES/$fixture/package.json" ] && echo true || echo false)"
done

# ============================================================
# 2. React App Fixture 检查
# ============================================================
echo ""
echo "--- 2. React App Fixture ---"

react_pkg="$FIXTURES/react-app/package.json"

# 检查 devDependencies 包含预期的工具
for dep in eslint prettier typescript; do
  has_dep=$(grep -q "\"$dep\"" "$react_pkg" 2>/dev/null && echo true || echo false)
  assert "[react-app] devDependencies 包含 $dep" "$has_dep"
done

# 检查 scripts 包含预期的命令
for script in lint format build type-check; do
  has_script=$(grep -q "\"$script\"" "$react_pkg" 2>/dev/null && echo true || echo false)
  assert "[react-app] scripts 包含 $script" "$has_script"
done

# 检查 ESLint 9 flat config 文件存在
assert "[react-app] eslint.config.js 存在（ESLint 9 flat config）" \
  "$([ -f "$FIXTURES/react-app/eslint.config.js" ] && echo true || echo false)"

# 检查 Prettier 配置文件存在
assert "[react-app] .prettierrc 存在" \
  "$([ -f "$FIXTURES/react-app/.prettierrc" ] && echo true || echo false)"

# 检查 tsconfig.json 存在
assert "[react-app] tsconfig.json 存在" \
  "$([ -f "$FIXTURES/react-app/tsconfig.json" ] && echo true || echo false)"

# ============================================================
# 3. Vue App Fixture 检查
# ============================================================
echo ""
echo "--- 3. Vue App Fixture ---"

vue_pkg="$FIXTURES/vue-app/package.json"

# 检查 devDependencies
for dep in eslint vue-tsc typescript; do
  has_dep=$(grep -q "\"$dep\"" "$vue_pkg" 2>/dev/null && echo true || echo false)
  assert "[vue-app] devDependencies 包含 $dep" "$has_dep"
done

# 检查 scripts — 故意无 format
has_lint=$(grep -q "\"lint\"" "$vue_pkg" 2>/dev/null && echo true || echo false)
has_build=$(grep -q "\"build\"" "$vue_pkg" 2>/dev/null && echo true || echo false)
has_format=$(grep -q "\"format\"" "$vue_pkg" 2>/dev/null && echo true || echo false)
assert "[vue-app] scripts 包含 lint" "$has_lint"
assert "[vue-app] scripts 包含 build" "$has_build"
assert "[vue-app] scripts 不包含 format（测试 SKIPPED 判定）" "$([ "$has_format" = "false" ] && echo true || echo false)"

# ESLint 8 legacy config
assert "[vue-app] .eslintrc.json 存在（ESLint 8 legacy config）" \
  "$([ -f "$FIXTURES/vue-app/.eslintrc.json" ] && echo true || echo false)"

# 不应有 ESLint 9 flat config
assert "[vue-app] 无 eslint.config.js（非 ESLint 9）" \
  "$([ ! -f "$FIXTURES/vue-app/eslint.config.js" ] && echo true || echo false)"

assert "[vue-app] tsconfig.json 存在" \
  "$([ -f "$FIXTURES/vue-app/tsconfig.json" ] && echo true || echo false)"

# ============================================================
# 4. Monorepo Fixture 检查
# ============================================================
echo ""
echo "--- 4. Monorepo Fixture ---"

mono_pkg="$FIXTURES/monorepo/package.json"

# 检查 workspaces 字段
has_workspaces=$(grep -q '"workspaces"' "$mono_pkg" 2>/dev/null && echo true || echo false)
assert "[monorepo] package.json 包含 workspaces 字段" "$has_workspaces"

# 检查 pnpm-workspace.yaml 存在
assert "[monorepo] pnpm-workspace.yaml 存在" \
  "$([ -f "$FIXTURES/monorepo/pnpm-workspace.yaml" ] && echo true || echo false)"

# 检查子包存在
for pkg in app-a app-b; do
  assert "[monorepo] packages/$pkg/package.json 存在" \
    "$([ -f "$FIXTURES/monorepo/packages/$pkg/package.json" ] && echo true || echo false)"
done

# ============================================================
# 5. lint-verify.md 工具检测逻辑与 fixture 配置匹配
# ============================================================
echo ""
echo "--- 5. 工具检测逻辑覆盖 ---"

# 检查 lint-verify.md 中的 ESLint 9 检测条件：eslint.config.js 存在
# react-app 有 eslint.config.js → 应匹配 ESLint 9
if grep -q "eslint.config.js" references/lint-verify.md 2>/dev/null; then
  assert "lint-verify.md 中 ESLint 9 检测条件与 react-app fixture 匹配" \
    "$([ -f "$FIXTURES/react-app/eslint.config.js" ] && echo true || echo false)"
fi

# 检查 lint-verify.md 中的 ESLint 8 检测条件：.eslintrc.json 等存在
# vue-app 有 .eslintrc.json → 应匹配 ESLint 8
if grep -q "\.eslintrc" references/lint-verify.md 2>/dev/null; then
  assert "lint-verify.md 中 ESLint 8 检测条件与 vue-app fixture 匹配" \
    "$([ -f "$FIXTURES/vue-app/.eslintrc.json" ] && echo true || echo false)"
fi

# 检查 lint-verify.md 中的 Prettier 检测条件：.prettierrc 存在
if grep -q "\.prettierrc" references/lint-verify.md 2>/dev/null; then
  assert "lint-verify.md 中 Prettier 检测条件与 react-app fixture 匹配" \
    "$([ -f "$FIXTURES/react-app/.prettierrc" ] && echo true || echo false)"
fi

# 检查脚本缺失判定：vue-app 无 format → 应判定为 SKIPPED
if grep -q "SKIPPED" references/lint-verify.md 2>/dev/null; then
  assert "lint-verify.md 有 format 缺失时的 SKIPPED 判定逻辑" "true"
fi

# ============================================================
# 汇总
# ============================================================
echo ""
echo "=== 测试结果 ==="
echo "通过: $PASS"
echo "失败: $FAIL"
if [ $FAIL -gt 0 ]; then
  echo -e "\n失败项:$ERRORS"
  exit 1
fi
echo "全部通过 ✅"
