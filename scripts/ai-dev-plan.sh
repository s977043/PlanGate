#!/bin/sh

set -eu

. "$(dirname -- "$0")/ai-dev-common.sh"

if [ "${1:-}" = "--" ]; then
  shift
fi

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  ai_dev_usage "plan"
  exit 0
fi

ai_dev_parse_task_args "$@"
status_file=$(ai_dev_status_file)
if [ "$AI_DEV_DRY_RUN" -eq 1 ]; then
  if [ ! -d "$AI_DEV_WORK_DIR" ]; then
    echo "Would create work dir: $AI_DEV_WORK_DIR"
  fi
  if [ ! -f "$status_file" ]; then
    echo "Would create status stub: $status_file"
  fi
  if [ ! -f "$AI_DEV_WORK_DIR/pbi-input.md" ]; then
    echo "Would create missing PBI input stub: $AI_DEV_WORK_DIR/pbi-input.md"
    exit 0
  fi
else
  ai_dev_ensure_work_dir
  if [ ! -f "$status_file" ]; then
    ai_dev_create_status_stub
    echo "Created status stub: $status_file"
  fi
fi

if [ ! -f "$AI_DEV_WORK_DIR/pbi-input.md" ]; then
  ai_dev_create_pbi_stub
  echo "Created PBI input stub: $AI_DEV_WORK_DIR/pbi-input.md"
  echo "Fill the PBI and rerun ./scripts/ai-dev-workflow $AI_DEV_TASK plan" >&2
  exit 1
fi

# Mode switches (default = new skill-aligned flow):
#   PLANGATE_PLAN_LEGACY=1     旧挙動 (C-2 review-external.md 作成 + Cloud handoff draft 強制)
#   PLANGATE_CLOUD_HANDOFF=1   新挙動でも Cloud handoff draft を出力 (Codex Cloud 利用時のみ)
plan_legacy="${PLANGATE_PLAN_LEGACY:-0}"
plan_cloud_handoff="${PLANGATE_CLOUD_HANDOFF:-0}"

if [ "$AI_DEV_DRY_RUN" -eq 1 ]; then
  echo "Would run Codex plan workflow for: $AI_DEV_TASK"
  echo "Would read: $ai_dev_repo_root/CLAUDE.md, $ai_dev_repo_root/AGENTS.md, $ai_dev_repo_root/.claude/rules/working-context.md, $ai_dev_repo_root/.claude/rules/mode-classification.md, $ai_dev_repo_root/.claude/rules/hybrid-architecture.md, $ai_dev_repo_root/.agents/skills/ai-dev-plan/SKILL.md, $ai_dev_repo_root/docs/ai-driven-development.md, $AI_DEV_WORK_DIR/pbi-input.md, $AI_DEV_WORK_DIR/status.md"
  if [ "$plan_legacy" = "1" ]; then
    echo "Would update (legacy mode): $AI_DEV_WORK_DIR/plan.md, $AI_DEV_WORK_DIR/todo.md, $AI_DEV_WORK_DIR/test-cases.md, $AI_DEV_WORK_DIR/review-self.md, $AI_DEV_WORK_DIR/review-external.md, $AI_DEV_WORK_DIR/status.md, $ai_dev_repo_root/.codex/manual-cloud-task.md"
  else
    echo "Would update: $AI_DEV_WORK_DIR/plan.md, $AI_DEV_WORK_DIR/todo.md, $AI_DEV_WORK_DIR/test-cases.md, $AI_DEV_WORK_DIR/review-self.md, $AI_DEV_WORK_DIR/decision-log.jsonl, $AI_DEV_WORK_DIR/status.md"
    if [ "$plan_cloud_handoff" = "1" ]; then
      echo "Would also draft: $ai_dev_repo_root/.codex/manual-cloud-task.md"
    fi
  fi
  exit 0
fi

if [ "$plan_legacy" = "1" ]; then
# ===== legacy prompt (preserved for backward compatibility) =====
prompt=$(cat <<EOF
あなたは AI駆動開発ワークフローの plan フェーズを担当する (legacy mode)。
この実行では multi-agent 機能を積極的に使い、計画・レビュー・handoff draft を半自動で整えること。
少なくとも orchestrator / project_planner の役割を使い、必要に応じて documentation_writer / explorer_agent を委譲先として活用すること。

対象チケット:
- $AI_DEV_TASK

参照順序:
1. $ai_dev_repo_root/CLAUDE.md
2. $ai_dev_repo_root/AGENTS.md
3. $ai_dev_repo_root/docs/ai-driven-development.md
4. $AI_DEV_WORK_DIR/pbi-input.md
5. $AI_DEV_WORK_DIR/status.md

この実行で更新するファイル:
- $AI_DEV_WORK_DIR/plan.md
- $AI_DEV_WORK_DIR/todo.md
- $AI_DEV_WORK_DIR/test-cases.md
- $AI_DEV_WORK_DIR/review-self.md
- $AI_DEV_WORK_DIR/review-external.md
- $AI_DEV_WORK_DIR/status.md
- $ai_dev_repo_root/.codex/manual-cloud-task.md

実施内容:
1. pbi-input.md を読んで execution plan を作成する
2. todo を 2-5 分粒度で分解する
3. acceptance criteria と test cases を対応付ける
4. C-1 として review-self.md を作成する
5. C-2 として review-external.md を作成する
6. Cloud task 用の handoff draft を .codex/manual-cloud-task.md に作成する

制約:
- 実装コードは変更しない
- まだ C-3 承認前なので exec しない
- review-self / review-external の指摘は review-external.md に追記専用集約（指摘ID R-NNN）。plan/todo/test-cases への反映は exec 開始時に 1 回だけ確定（反映コミットに Refs: R-NNN）。詳細: .claude/rules/working-context.md「C-2 指摘の差分管理」
- .codex/manual-cloud-task.md は draft とし、C-3 未承認であることを明記する
- Codex Cloud の検証方針は「修正箇所に絞った test / lint / typecheck を優先し、最終完了は人間承認で確定する」
- docs/working/ の内容はローカル作業コンテキストであり、Cloud task には draft packet として要点だけを転記する

status.md には最低限以下を反映する:
- plan フェーズを実行したこと
- 生成した成果物一覧
- ## C-3 Gate: PENDING を明記すること
- C-3 承認待ちであること
- 次のアクションが Cloud task 起動ではなく人間レビューであること

最終メッセージでは以下を簡潔に報告する:
- 更新したファイル
- review-self / review-external の最終判定
- 人間が次にやること
EOF
)
else
# ===== new skill-aligned prompt (default) =====
cloud_handoff_note=""
cloud_handoff_file=""
cloud_handoff_step=""
if [ "$plan_cloud_handoff" = "1" ]; then
  cloud_handoff_note="- $ai_dev_repo_root/.codex/manual-cloud-task.md (Cloud handoff draft, optional)"
  cloud_handoff_step="5. Cloud task 用の handoff draft を .codex/manual-cloud-task.md に作成する (C-3 未承認である旨を明記)"
fi

prompt=$(cat <<EOF
あなたは PlanGate の plan フェーズ (WF-02〜WF-03) を担当する。
.agents/skills/ai-dev-plan/SKILL.md の規約に従い、B-1 → B-2 → B-3 のフローで実行する。

対象チケット:
- $AI_DEV_TASK

参照順序 (Read First):
1. $ai_dev_repo_root/CLAUDE.md
2. $ai_dev_repo_root/AGENTS.md
3. $ai_dev_repo_root/.claude/rules/working-context.md (B フェーズ規約・C-3 ゲートの正本)
4. $ai_dev_repo_root/.claude/rules/mode-classification.md (5 段階 mode + lite_eligible の正本)
5. $ai_dev_repo_root/.claude/rules/hybrid-architecture.md (Rule 1〜5)
6. $ai_dev_repo_root/.agents/skills/ai-dev-plan/SKILL.md (skill 規約)
7. $ai_dev_repo_root/docs/ai-driven-development.md (Prompt 1: Plan + ToDo + Test Cases生成)
8. $AI_DEV_WORK_DIR/pbi-input.md
9. $AI_DEV_WORK_DIR/status.md

この実行で更新するファイル:
- $AI_DEV_WORK_DIR/plan.md
- $AI_DEV_WORK_DIR/todo.md
- $AI_DEV_WORK_DIR/test-cases.md
- $AI_DEV_WORK_DIR/review-self.md (C-1 セルフレビュー)
- $AI_DEV_WORK_DIR/decision-log.jsonl (B-1/B-2/B-3 主要判断を append)
- $AI_DEV_WORK_DIR/status.md
$cloud_handoff_note

実施内容 (B-1 → B-2 → B-3 フロー):
1. B-1: pbi-input.md の曖昧点を最大 3 問の確認質問 (多肢選択推奨) で解消する。曖昧さがなければスキップ可。
2. B-2: 2〜3 アプローチ案を trade-off 付きで比較し推薦案を明示する。比較結果は plan.md「アプローチ比較」セクションに記載。
3. B-3: 確定仕様で plan.md + todo.md + test-cases.md を同時生成する。
4. C-1 として review-self.md を作成する (mode に応じた項目数。詳細は working-context.md 正本)
$cloud_handoff_step

plan.md に必ず含めるセクション:
- Goal / Constraints / Non-goals / Approach Overview
- 確認事項 (B-1 の Q&A、無ければ「該当なし」明記)
- アプローチ比較 (B-2、無ければ「該当なし」明記)
- Work Breakdown (Step ごとに Output / Owner / Risk / 🚩 checkpoint)
- Files / Components to Touch
- Testing Strategy / Risks & Mitigations / Questions / Unknowns
- Mode判定 (ultra-light / light / standard / high-risk / critical) + 判定根拠
- lite_eligible (true / false) + 根拠 (AC-8 安全側、AC-11 critical 原則 false)

todo.md 規約:
- タスク粒度 2-5 分、Owner: agent / human 必須、depends_on / files 必須
- L-0〜V-4・PR 作成は含めない (workflow-conductor が自動制御)

test-cases.md 規約:
- 各 AC → テストケースのマッピング必須、Edge case を含める

制約:
- 実装コードは変更しない
- まだ C-3 承認前なので exec しない
- C-2 (外部 AI レビュー) は本フェーズでは作成しない。plan-review-gate skill の手順で bin/plangate review --phase c2 を別途実行する。
- decision-log.jsonl に B-1/B-2/B-3 の主要判断を append-only で記録する
- mode が critical で lite_eligible=true にする場合は人間の C-3 明示承認記録が前提 (AC-11)

status.md には最低限以下を反映する:
- plan フェーズを実行したこと (B-1/B-2/B-3 各ステップの実施有無)
- 生成した成果物一覧 (plan / todo / test-cases / review-self / decision-log)
- Mode判定結果と lite_eligible
- ## C-3 Gate: PENDING を明記
- 次のアクションが C-2 外部レビュー (plan-review-gate skill) + 人間レビューであること

最終メッセージでは以下を簡潔に報告する:
- 更新したファイル
- B-1/B-2/B-3 の実施結果サマリ
- Mode判定 / lite_eligible 結果
- review-self の最終判定
- 人間が次にやること (plan-review-gate skill → C-2 → C-3)
EOF
)
fi

printf '%s\n' "$prompt" | "$ai_dev_script_dir/codex-local.sh" exec --full-auto --sandbox workspace-write -C "$AI_DEV_WORK_DIR" --add-dir "$ai_dev_repo_root/.codex" -
