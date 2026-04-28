#!/bin/sh
# check-orchestrator-docs.sh — TASK-0038 / Issue #109 文書整合性検証
#
# Usage: sh scripts/check-orchestrator-docs.sh
# Exit code: 0 = all PASS, 1 = any FAIL
#
# 本スクリプトは TASK-0038 で作成した 9 ファイル + 関連の存在 / 必須セクション /
# YAML 構文 / 用語整合性を検証する。

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$REPO_ROOT"

pass=0
fail=0

check() {
  label=$1
  shift
  if eval "$@" >/dev/null 2>&1; then
    printf '[PASS] %s\n' "$label"
    pass=$((pass + 1))
  else
    printf '[FAIL] %s\n' "$label"
    fail=$((fail + 1))
  fi
}

# ----------------------------------------------------------------
# TC-01 〜 TC-02: アーキテクチャ正本
# ----------------------------------------------------------------

check "TC-01: docs/orchestrator-mode.md exists with parent/child terms" \
  "test -f docs/orchestrator-mode.md && grep -q '親 PBI' docs/orchestrator-mode.md && grep -q '子 PBI' docs/orchestrator-mode.md"

check "TC-02: orchestrator-mode.md mentions existing v7 hybrid agents" \
  "grep -cE 'orchestrator|solution-architect|implementation-agent|qa-reviewer|requirements-analyst' docs/orchestrator-mode.md | awk '\$1 >= 3 { exit 0 } { exit 1 }'"

# ----------------------------------------------------------------
# TC-03 〜 TC-05: 子 PBI YAML schema
# ----------------------------------------------------------------

check "TC-03: child-pbi.yaml is valid YAML" \
  "test -f docs/schemas/child-pbi.yaml && python3 -c 'import yaml,sys; yaml.safe_load(open(\"docs/schemas/child-pbi.yaml\"))'"

check "TC-04: child-pbi.yaml has all 9 required keys" \
  "for key in id parent_id in_scope out_of_scope dependencies allowed_files forbidden_files acceptance_criteria pr_strategy; do grep -qE \"^[[:space:]]+\$key:\" docs/schemas/child-pbi.yaml || exit 1; done"

check "TC-05: forbidden_files section uses glob patterns" \
  "awk '/forbidden_files:/{flag=1; next} flag && /\\*/ {found=1} flag && /^[a-z_]+:/{flag=0} END{exit found?0:1}' docs/schemas/child-pbi.yaml"

# ----------------------------------------------------------------
# TC-06 〜 TC-07: CLI RFC
# ----------------------------------------------------------------

check "TC-06: plangate-decompose RFC exists with Status: Draft" \
  "test -f docs/rfc/plangate-decompose.md && grep -qE 'Status.*Draft' docs/rfc/plangate-decompose.md"

check "TC-07: RFC marks implementation as out of scope" \
  "grep -qE '別 PBI|Out of scope|out of scope' docs/rfc/plangate-decompose.md"

# ----------------------------------------------------------------
# TC-08 〜 TC-10: テンプレート 4 種
# ----------------------------------------------------------------

check "TC-08: dependency-graph template uses mermaid graph" \
  "test -f docs/working/templates/dependency-graph.md && grep -qE 'mermaid|graph TD|flowchart' docs/working/templates/dependency-graph.md"

check "TC-09: parallelization-plan template has both sections" \
  "test -f docs/working/templates/parallelization-plan.md && grep -q '並行実行可能' docs/working/templates/parallelization-plan.md && grep -q '並行実行不可' docs/working/templates/parallelization-plan.md"

check "TC-10: integration-plan template has integration-check and completion sections" \
  "test -f docs/working/templates/integration-plan.md && grep -q '統合チェック' docs/working/templates/integration-plan.md && grep -q '完了条件' docs/working/templates/integration-plan.md"

# ----------------------------------------------------------------
# TC-11 〜 TC-12: PR strategy
# ----------------------------------------------------------------

check "TC-11: pr_strategy has 3 sub-fields (branch / pr_size / merge_after)" \
  "awk '/^[[:space:]]*pr_strategy:/{flag=1; next} flag && /^[[:space:]]*[a-z_]+:/ && !/^[[:space:]]*#/{print \$1}' docs/schemas/child-pbi.yaml | grep -E '^(branch|pr_size|merge_after):' | sort -u | wc -l | awk '\$1 == 3 { exit 0 } { exit 1 }'"

check "TC-12: branch naming convention is documented" \
  "grep -qE 'feature/PBI-' docs/orchestrator-mode.md docs/rfc/plangate-decompose.md docs/schemas/child-pbi.yaml docs/working/templates/parent-plan.md 2>/dev/null"

# ----------------------------------------------------------------
# TC-13: 並行条件
# ----------------------------------------------------------------

check "TC-13: parallelization conditions enumerated (>= 4 ok / >= 4 ng) within their sections" \
  "test \$(awk '/### 並行実行可能な条件/,/### 並行実行不可の条件/' docs/orchestrator-mode.md | grep -cE '^[[:space:]]*[0-9]+\\.') -ge 4 && test \$(awk '/### 並行実行不可の条件/,/## モード分類との統合/' docs/orchestrator-mode.md | grep -cE '^[[:space:]]*[0-9]+\\.') -ge 4"

# ----------------------------------------------------------------
# TC-14 〜 TC-17: Gate 不変条件
# ----------------------------------------------------------------

check "TC-14: NewChildPBIAllowed and 再承認 documented" \
  "grep -q 'NewChildPBIAllowed' .claude/rules/orchestrator-mode.md && grep -q '再承認' .claude/rules/orchestrator-mode.md docs/orchestrator-mode.md 2>/dev/null"

check "TC-15: ParentDone and 受入基準 documented" \
  "grep -q 'ParentDone' .claude/rules/orchestrator-mode.md && grep -q '受入基準' .claude/rules/orchestrator-mode.md"

check "TC-16: ChildExecAllowed invariant defined" \
  "grep -q 'ChildExecAllowed' .claude/rules/orchestrator-mode.md && grep -q 'ChildPlanApproved' .claude/rules/orchestrator-mode.md && grep -q 'ParentPlanApproved' .claude/rules/orchestrator-mode.md"

check "TC-17: AI self-completion is forbidden" \
  "grep -qE '自己完結|完全自動.*禁止|完全自動.*してはならない' docs/orchestrator-mode.md .claude/rules/orchestrator-mode.md 2>/dev/null"

# ----------------------------------------------------------------
# TC-18 〜 TC-20: 文書間整合性
# ----------------------------------------------------------------

check "TC-18: orchestrator-mode.md links to >= 6 spec files" \
  "grep -cE '\\(\\./schemas/|\\(\\./workflows/orchestrator|\\(\\./working/templates/|\\(\\.\\./\\.claude/rules/orchestrator|\\(\\./rfc/plangate-decompose' docs/orchestrator-mode.md | awk '\$1 >= 6 { exit 0 } { exit 1 }'"

check "TC-19: state names use ASCII colon (no full-width)" \
  "! grep -lE 'parent：|child：' docs/orchestrator-mode.md docs/workflows/orchestrator-decomposition.md docs/workflows/orchestrator-integration.md .claude/rules/orchestrator-mode.md docs/working/templates/parent-plan.md 2>/dev/null | grep -q ."

check "TC-20: this script exists and is executable readable" \
  "test -f scripts/check-orchestrator-docs.sh && test -r scripts/check-orchestrator-docs.sh"

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------

printf '\n=== Summary ===\n'
printf 'Results: %d passed, %d failed\n' "$pass" "$fail"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
