#!/bin/sh

set -eu

. "$(dirname -- "$0")/ai-dev-common.sh"

if [ "${1:-}" = "--" ]; then
  shift
fi

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  ai_dev_usage "sync-cloud"
  exit 0
fi

ai_dev_parse_task_args "$@"

status_file=$(ai_dev_status_file)
todo_file=$AI_DEV_WORK_DIR/todo.md
plan_file=$AI_DEV_WORK_DIR/plan.md
packet_file=$(ai_dev_packet_file)

if [ "$AI_DEV_DRY_RUN" -eq 1 ]; then
  missing_items=""
  if [ ! -f "$status_file" ]; then
    missing_items="${missing_items}\n- missing status file: $status_file"
  fi
  if [ ! -f "$todo_file" ]; then
    missing_items="${missing_items}\n- missing todo file: $todo_file"
  fi
  if [ ! -f "$plan_file" ]; then
    missing_items="${missing_items}\n- missing plan file: $plan_file"
  fi
  if [ ! -f "$packet_file" ]; then
    missing_items="${missing_items}\n- missing manual cloud task packet: $packet_file"
  else
    actual_task=$(ai_dev_packet_task_id "$packet_file")
    if [ -z "$actual_task" ]; then
      missing_items="${missing_items}\n- missing Task ID in packet: $packet_file"
    elif [ "$actual_task" != "$AI_DEV_TASK" ]; then
      missing_items="${missing_items}\n- packet task mismatch: expected $AI_DEV_TASK but found $actual_task in $packet_file"
    fi
  fi

  printf 'Would sync:\n- %s\n- %s\n\nFrom:\n- %s\n- %s\n' \
    "$status_file" \
    "$todo_file" \
    "$packet_file" \
    "$plan_file"
  if [ -n "$missing_items" ]; then
    printf 'Preconditions not yet satisfied:%b\n' "$missing_items"
  else
    echo "Preconditions satisfied."
  fi
  exit 0
fi

ai_dev_ensure_work_dir

ai_dev_require_file "$status_file" "status file"
ai_dev_require_file "$todo_file" "todo file"
ai_dev_require_file "$plan_file" "plan file"
ai_dev_require_file "$packet_file" "manual cloud task packet"
ai_dev_require_packet_task_match "$packet_file" "$AI_DEV_TASK"

prompt=$(cat <<EOF
あなたは AI駆動開発ワークフローの Cloud task 後処理を担当する。
workflow_conductor の観点で、Cloud task の結果をローカル作業ドキュメントへ同期する。

対象チケット:
- $AI_DEV_TASK

参照順序:
1. $ai_dev_repo_root/CLAUDE.md
2. $ai_dev_repo_root/AGENTS.md
3. $ai_dev_repo_root/.codex/manual-cloud-task.md
4. $AI_DEV_WORK_DIR/status.md
5. $AI_DEV_WORK_DIR/todo.md
6. $AI_DEV_WORK_DIR/plan.md

更新対象:
- $AI_DEV_WORK_DIR/status.md
- $AI_DEV_WORK_DIR/todo.md

目的:
- handoff packet に残った changed files / verification results / concerns / approval request note を status.md に反映する
- todo.md のうち、packet の証拠で完了扱いできるものだけ更新する
- Cloud task の完了は仮完了であり、人間承認待ちであることを status.md に残す

制約:
- 実装コードは変更しない
- plan.md は変更しない
- packet に証拠がない項目は完了扱いにしない
- 不足情報がある場合は、status.md に「要確認」として残す

最終メッセージでは以下を簡潔に報告する:
- 更新した status/todo の要点
- 人間が次に確認すること
EOF
)

printf '%s\n' "$prompt" | "$ai_dev_script_dir/codex-local.sh" exec --full-auto --sandbox workspace-write -C "$AI_DEV_WORK_DIR" --add-dir "$ai_dev_repo_root/.codex" -
