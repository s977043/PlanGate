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

if [ "$AI_DEV_DRY_RUN" -eq 1 ]; then
  echo "Would run Codex plan workflow for: $AI_DEV_TASK"
  echo "Would read: $ai_dev_repo_root/CLAUDE.md, $ai_dev_repo_root/AGENTS.md, $ai_dev_repo_root/docs/ai-driven-development.md, $AI_DEV_WORK_DIR/pbi-input.md, $AI_DEV_WORK_DIR/status.md"
  echo "Would update: $AI_DEV_WORK_DIR/plan.md, $AI_DEV_WORK_DIR/todo.md, $AI_DEV_WORK_DIR/test-cases.md, $AI_DEV_WORK_DIR/review-self.md, $AI_DEV_WORK_DIR/review-external.md, $AI_DEV_WORK_DIR/status.md, $ai_dev_repo_root/.codex/manual-cloud-task.md"
  exit 0
fi

prompt=$(cat <<EOF
あなたは AI駆動開発ワークフローの plan フェーズを担当する。
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
- review-self と review-external に WARN / FAIL があれば plan/todo/test-cases を修正してから確定する
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

printf '%s\n' "$prompt" | "$ai_dev_script_dir/codex-local.sh" exec --full-auto --sandbox workspace-write -C "$AI_DEV_WORK_DIR" --add-dir "$ai_dev_repo_root/.codex" -
