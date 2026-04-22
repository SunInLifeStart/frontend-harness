#!/bin/bash
set -e

# 切换到项目根目录
cd "$(dirname "$0")/.."
ROOT=$(pwd)

PASS=0
FAIL=0
ERRORS=""

# 测试辅助函数
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

echo "=== 文档一致性测试 ==="

# ============================================================
# 1. 引用完整性：workflow-*.md 和 phases/*.md 中引用的文件是否存在
# ============================================================
echo ""
echo "--- 1. 引用完整性 ---"

# 扫描 references/ 下所有 md 文件中通过 backtick 引用的 references/ 路径
ref_ok=true
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  # 提取 backtick 中的 references/ 路径
  refs=$(echo "$line" | grep -oE 'references/[a-zA-Z0-9_./-]+\.md' || true)
  for ref in $refs; do
    # 跳过占位符 references/xxx.md
    case "$ref" in
      */xxx.md) continue ;;
    esac
    if [ ! -f "$ROOT/$ref" ]; then
      assert "[$file] 引用的 $ref 存在" "false"
      ref_ok=false
    fi
  done
done < <(grep -rn 'references/' references/ --include="*.md" 2>/dev/null || true)

# 同样检查 SKILL.md 中的引用
while IFS= read -r line; do
  refs=$(echo "$line" | grep -oE 'references/[a-zA-Z0-9_./-]+\.md' || true)
  for ref in $refs; do
    case "$ref" in
      */xxx.md) continue ;;
    esac
    if [ ! -f "$ROOT/$ref" ]; then
      assert "[SKILL.md] 引用的 $ref 存在" "false"
      ref_ok=false
    fi
  done
done < <(grep -n 'references/' SKILL.md 2>/dev/null || true)

if [ "$ref_ok" = true ]; then
  assert "所有文档内部引用的 references/*.md 文件均存在" "true"
fi

# ============================================================
# 2. 路由表一致性：SKILL.md 触发路由中引用的工作流文件是否存在
# ============================================================
echo ""
echo "--- 2. 路由表一致性 ---"

# 从 SKILL.md 的路由表提取所有 workflow 文件路径
route_files=$(grep -oE 'references/workflow-[a-zA-Z0-9_-]+\.md' SKILL.md | sort -u)
route_ok=true
for rf in $route_files; do
  if [ -f "$ROOT/$rf" ]; then
    assert "路由表文件 $rf 存在" "true"
  else
    assert "路由表文件 $rf 存在" "false"
    route_ok=false
  fi
done

# 反向检查：references/workflow-*.md 文件是否都在路由表中注册
for wf in references/workflow-*.md; do
  wf_base=$(basename "$wf")
  if echo "$route_files" | grep -q "$wf_base"; then
    assert "工作流 $wf_base 已在路由表注册" "true"
  else
    assert "工作流 $wf_base 已在路由表注册" "false"
  fi
done

# ============================================================
# 3. 阶段编号连续性：每个 workflow-*.md 中的阶段编号是否连续
# ============================================================
echo ""
echo "--- 3. 阶段编号连续性 ---"

for wf in references/workflow-*.md; do
  wf_name=$(basename "$wf")
  # 提取所有 ## 阶段 N 的 N（支持 "阶段 N:" 格式）
  stages=$(grep -oE '^## 阶段 [0-9]+' "$wf" | grep -oE '[0-9]+' || true)

  if [ -z "$stages" ]; then
    # workflow-init.md 使用 Step 而非阶段，特殊处理
    steps=$(grep -oE '^### Step [0-9]+' "$wf" | grep -oE '[0-9]+' || true)
    if [ -n "$steps" ]; then
      prev=-1
      step_ok=true
      for s in $steps; do
        if [ $prev -ge 0 ] && [ $((prev + 1)) -ne "$s" ]; then
          assert "[$wf_name] Step 编号 $prev 到 $s 连续" "false"
          step_ok=false
        fi
        prev=$s
      done
      if [ "$step_ok" = true ]; then
        assert "[$wf_name] Step 编号连续（$steps）" "true"
      fi
    else
      assert "[$wf_name] 存在阶段/Step 编号" "false"
    fi
    continue
  fi

  # 检查阶段编号连续性（从 0 或 1 开始，递增 1）
  prev=-1
  stage_ok=true
  for s in $stages; do
    if [ $prev -ge 0 ] && [ $((prev + 1)) -ne "$s" ]; then
      assert "[$wf_name] 阶段编号 $prev 到 $s 连续" "false"
      stage_ok=false
    fi
    prev=$s
  done

  if [ "$stage_ok" = true ]; then
    # 检查进度标记 [阶段 X/N] 中的 N 是否与最大阶段号一致
    max_stage=$prev
    progress_totals=$(grep -oE '\[阶段 [0-9]+/[0-9]+\]' "$wf" | grep -oE '/[0-9]+' | grep -oE '[0-9]+' | sort -u || true)
    progress_ok=true
    for total in $progress_totals; do
      if [ "$total" != "$max_stage" ]; then
        assert "[$wf_name] 进度标记总数 $total 与最大阶段号 $max_stage 一致" "false"
        progress_ok=false
      fi
    done
    if [ "$progress_ok" = true ]; then
      assert "[$wf_name] 阶段编号连续且进度标记一致（0-$max_stage）" "true"
    fi
  fi
done

# ============================================================
# 4. Phase 引用一致性：workflow 中调用的 phases/*.md 是否存在
# ============================================================
echo ""
echo "--- 4. Phase 引用一致性 ---"

phase_ok=true
for wf in references/workflow-*.md; do
  wf_name=$(basename "$wf")
  # 提取引用的 phases/ 文件
  phase_refs=$(grep -oE 'references/phases/[a-zA-Z0-9_-]+\.md' "$wf" | sort -u || true)
  # 也匹配 phases/ 直接引用（不带 references/ 前缀）
  phase_refs2=$(grep -oE 'phases/[a-zA-Z0-9_-]+\.md' "$wf" | sort -u || true)
  all_phases=$(echo -e "$phase_refs\n$phase_refs2" | sed 's|^phases/|references/phases/|' | sort -u | grep -v '^$' || true)

  for pf in $all_phases; do
    if [ ! -f "$ROOT/$pf" ]; then
      assert "[$wf_name] 引用的 $pf 存在" "false"
      phase_ok=false
    fi
  done
done

if [ "$phase_ok" = true ]; then
  assert "所有 workflow 引用的 phases/*.md 文件均存在" "true"
fi

# ============================================================
# 5. 能力矩阵一致性：README.md 矩阵中标 ✅ 的能力在对应工作流中有实际引用
# ============================================================
echo ""
echo "--- 5. 能力矩阵一致性 ---"

# 能力名称到 references 文件的映射（兼容 bash 3，不使用 declare -A）
# 格式: "能力名=ref文件"
CAPABILITY_MAP="框架检测=framework-detector.md
PRD 解析=doc-parser.md
Figma 解析=figma-analyzer.md
API 解析=api-spec-analyzer.md
代码审查=code-reviewer.md
代码验证=verify-code.md"

# 工作流前缀到文件的映射
WF_MAP="feat=references/workflow-feat.md
bug=references/workflow-bug.md
change=references/workflow-change.md
refactor=references/workflow-refactor.md
init=references/workflow-init.md
hotfix=references/workflow-hotfix.md
perf=references/workflow-perf.md
docs=references/workflow-docs.md
chore=references/workflow-chore.md"

# 辅助函数：从映射中查找值
map_get() {
  local map="$1" key="$2"
  echo "$map" | while IFS='=' read -r k v; do
    if [ "$k" = "$key" ]; then
      echo "$v"
      return 0
    fi
  done
}

# 矩阵列顺序
WF_ORDER="feat bug change refactor init hotfix perf docs chore"

matrix_ok=true
while IFS= read -r line; do
  # 提取能力名（第一列）
  cap_name=$(echo "$line" | awk -F'|' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -z "$cap_name" ]; then continue; fi

  # 查找对应的 reference 文件
  ref_file=$(map_get "$CAPABILITY_MAP" "$cap_name")
  if [ -z "$ref_file" ]; then continue; fi

  # 提取各列的值
  col_idx=0
  for wf_name in $WF_ORDER; do
    col_idx=$((col_idx + 1))
    col_val=$(echo "$line" | awk -F'|' -v c=$((col_idx + 2)) '{print $c}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # 只检查明确标记为 ✅ 的项
    if echo "$col_val" | grep -q '✅'; then
      wf_file=$(map_get "$WF_MAP" "$wf_name")
      if [ -f "$ROOT/$wf_file" ]; then
        if grep -q "$ref_file" "$ROOT/$wf_file" 2>/dev/null; then
          : # 引用存在，ok
        else
          # 对于代码验证，也检查 phases/verify-code.md 的间接引用
          if [ "$ref_file" = "verify-code.md" ]; then
            if grep -q "verify-code" "$ROOT/$wf_file" 2>/dev/null; then
              : # 间接引用存在
            else
              assert "[README 能力矩阵] $wf_name 工作流引用了 $cap_name ($ref_file)" "false"
              matrix_ok=false
            fi
          else
            assert "[README 能力矩阵] $wf_name 工作流引用了 $cap_name ($ref_file)" "false"
            matrix_ok=false
          fi
        fi
      fi
    fi
  done
done < <(grep '^|' README.md | grep -v '^| 能力' | grep -v '^|---' | grep -v '^|:' || true)

if [ "$matrix_ok" = true ]; then
  assert "能力矩阵中 ✅ 标记的能力在对应工作流中均有引用" "true"
fi

# ============================================================
# 6. 模板变量检查：检测 {{变量}} 是否在 SKILL.md 环境探测中定义
# ============================================================
echo ""
echo "--- 6. 模板变量检查 ---"

# 从 SKILL.md 提取所有已定义的模板变量
defined_vars=$(grep -oE '\{\{[a-zA-Z]+\}\}' SKILL.md | sort -u | sed 's/{{//;s/}}//' || true)
# 补充从 framework-detector.md 输出 schema 中定义的变量（.harness-env.json 字段）
detector_vars=$(grep -oE '\{\{[a-zA-Z]+\}\}' references/framework-detector.md 2>/dev/null | sort -u | sed 's/{{//;s/}}//' || true)
# 合并变量集合
defined_vars=$(echo -e "$defined_vars\n$detector_vars" | sort -u)

# 扫描 workflow-*.md 和 phases/*.md 中使用的 {{变量}}
var_ok=true
for f in references/workflow-*.md references/phases/*.md; do
  fname=$(basename "$f")
  used_vars=$(grep -oE '\{\{[a-zA-Z]+\}\}' "$f" 2>/dev/null | sort -u | sed 's/{{//;s/}}//' || true)
  for v in $used_vars; do
    # 跳过 pm 变量（在 lint-verify.md 中使用，来自 packageManager 的简写）
    if [ "$v" = "pm" ]; then continue; fi
    # 跳过 packageManager（来自 .harness-env.json，在 framework-detector.md 输出中定义）
    if [ "$v" = "packageManager" ]; then continue; fi
    if ! echo "$defined_vars" | grep -qx "$v"; then
      assert "[$fname] 变量 {{$v}} 在 SKILL.md 中有定义" "false"
      var_ok=false
    fi
  done
done

# 也检查 lint-verify.md 中的 {{pm}} 变量定义（它在 lint-verify.md 自身有说明）
if grep -q '{{pm}}' references/lint-verify.md 2>/dev/null; then
  if grep -q 'packageManager' references/lint-verify.md 2>/dev/null; then
    assert "lint-verify.md 中 {{pm}} 变量有来源说明（packageManager）" "true"
  else
    assert "lint-verify.md 中 {{pm}} 变量有来源说明" "false"
    var_ok=false
  fi
fi

if [ "$var_ok" = true ]; then
  assert "所有模板变量均有定义" "true"
fi

# ============================================================
# 7. Overrides 一致性：framework-detector.md 定义的 overrides 字段
#    在 lint-verify.md 中有对应处理
# ============================================================
echo ""
echo "--- 7. Overrides 一致性 ---"

# 从 framework-detector.md 提取 overrides 中的顶层字段
# 已知字段: lint, format, build, typeCheck, fixThreshold, monorepo
override_fields="lint format build typeCheck fixThreshold monorepo"

overrides_ok=true
for field in $override_fields; do
  # 检查 framework-detector.md 中是否定义了该字段
  if grep -q "\"$field\"" references/framework-detector.md 2>/dev/null; then
    # 检查 lint-verify.md 中是否有处理该字段的逻辑
    if grep -q "$field" references/lint-verify.md 2>/dev/null; then
      : # ok
    else
      assert "[Overrides] $field 在 lint-verify.md 中有处理" "false"
      overrides_ok=false
    fi
  fi
done

# 检查 lint-verify.md 中 Step 0.0 是否明确提到 overrides 处理
if grep -q "overrides" references/lint-verify.md 2>/dev/null; then
  assert "lint-verify.md 包含 overrides 处理逻辑" "true"
else
  assert "lint-verify.md 包含 overrides 处理逻辑" "false"
  overrides_ok=false
fi

# 检查 SKILL.md 和 README.md 中提到 overrides 时的文件指向一致性
if grep -q "overrides" SKILL.md 2>/dev/null && grep -q "overrides" README.md 2>/dev/null; then
  assert "SKILL.md 和 README.md 均提及 overrides 配置" "true"
else
  assert "SKILL.md 和 README.md 均提及 overrides 配置" "false"
  overrides_ok=false
fi

if [ "$overrides_ok" = true ]; then
  assert "Overrides schema 在 framework-detector.md 和 lint-verify.md 之间一致" "true"
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
