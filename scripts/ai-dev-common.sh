#!/bin/sh

set -eu

ai_dev_script_dir=$(
  CDPATH= cd -- "$(dirname -- "$0")" && pwd
)
ai_dev_repo_root=$(
  CDPATH= cd -- "$ai_dev_script_dir/.." && pwd
)

ai_dev_today() {
  date '+%Y-%m-%d'
}

ai_dev_usage() {
  command_name=$1
  printf 'Usage:\n'
  printf '  ./scripts/ai-dev-workflow TASK-XXXX %s\n' "$command_name"
  printf '  ./scripts/ai-dev-workflow TASK-XXXX %s --dry-run\n' "$command_name"
}

ai_dev_validate_task_id() {
  task_id=$1

  case "$task_id" in
    TASK-[A-Za-z0-9-][A-Za-z0-9-]*)
      case "$task_id" in
        *[!A-Za-z0-9-]*)
          echo "Task ID must contain only letters, numbers, and hyphens." >&2
          return 1
          ;;
      esac
      ;;
    *)
      echo "Task ID must match TASK-[A-Za-z0-9-]+." >&2
      return 1
      ;;
  esac
}

ai_dev_parse_task_args() {
  if [ $# -eq 0 ]; then
    echo "Task ID is required." >&2
    return 1
  fi

  AI_DEV_TASK=""
  AI_DEV_DRY_RUN=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --)
        ;;
      --dry-run)
        AI_DEV_DRY_RUN=1
        ;;
      *)
        if [ -n "$AI_DEV_TASK" ]; then
          echo "Only one Task ID can be specified." >&2
          return 1
        fi
        AI_DEV_TASK=$1
        ;;
    esac
    shift
  done

  if [ -z "$AI_DEV_TASK" ]; then
    echo "Task ID is required." >&2
    return 1
  fi

  ai_dev_validate_task_id "$AI_DEV_TASK"
  AI_DEV_WORK_DIR=$ai_dev_repo_root/docs/working/$AI_DEV_TASK
}

ai_dev_ensure_work_dir() {
  mkdir -p "$AI_DEV_WORK_DIR"
}

ai_dev_status_file() {
  printf '%s\n' "$AI_DEV_WORK_DIR/status.md"
}

ai_dev_packet_file() {
  printf '%s\n' "$ai_dev_repo_root/.codex/manual-cloud-task.md"
}

ai_dev_status_is_c3_approved() {
  status_file=$1
  grep -Eq '^## C-3 Gate: APPROVED$' "$status_file"
}

ai_dev_require_status_c3_approved() {
  status_file=$1
  if ! ai_dev_status_is_c3_approved "$status_file"; then
    echo "C-3 approval is not recorded in $status_file" >&2
    echo "Add a line exactly matching: ## C-3 Gate: APPROVED" >&2
    return 1
  fi
}

ai_dev_packet_task_id() {
  packet_file=$1
  sed -n 's/^- Task ID: //p' "$packet_file" | head -n 1
}

ai_dev_require_packet_task_match() {
  packet_file=$1
  expected_task=$2
  actual_task=$(ai_dev_packet_task_id "$packet_file")

  if [ -z "$actual_task" ]; then
    echo "Task ID is missing in packet: $packet_file" >&2
    return 1
  fi

  if [ "$actual_task" != "$expected_task" ]; then
    echo "Packet task mismatch: expected $expected_task but found $actual_task in $packet_file" >&2
    return 1
  fi
}

ai_dev_append_markdown_file_section() {
  output_file=$1
  section_title=$2
  source_file=$3

  {
    printf '\n## %s\n\n' "$section_title"
    printf '~~~~md\n'
    cat "$source_file"
    printf '\n~~~~\n'
  } >>"$output_file"
}

ai_dev_get_markdown_section() {
  source_file=$1
  section_title=$2

  awk -v target="## $section_title" '
    { sub(/\r$/, "") }
    found && /^## / {
      exit
    }
    $0 == target {
      found = 1
      next
    }
    found {
      print
    }
  ' "$source_file"
}

ai_dev_get_markdown_section_or_default() {
  source_file=$1
  section_title=$2
  default_content=$3

  section_content=""
  if [ -f "$source_file" ]; then
    section_content=$(ai_dev_get_markdown_section "$source_file" "$section_title")
  fi

  if [ -z "$(printf '%s' "$section_content" | tr -d '[:space:]')" ]; then
    printf '%s\n' "$default_content"
    return 0
  fi

  printf '%s\n' "$section_content"
}

ai_dev_create_status_stub() {
  status_file=$(ai_dev_status_file)
  cat >"$status_file" <<EOF
# $AI_DEV_TASK 作業ステータス

> 最終更新: $(ai_dev_today)
> PBI: TODO
> Notion: TODO

---

## 全体構成

| PR | ブランチ | 内容 | 状態 |
|----|---------|------|------|
| PR1 | \`TODO\` | TODO | Draft |

---

## PR1: TODO

## C-3 Gate: PENDING

### コミット履歴（新しい順）

1. \`- \` - 未作成

### 計画からの変更点

なし

### 変更ファイル一覧

| 種別 | ファイルパス |
|------|-----------|
| - | - |

### 残タスク

- [ ] pbi-input.md を記入
- [ ] plan / todo / test-cases を生成

---

## 次作業メモ

### 次の作業用メモ

\`\`\`
## コンテキスト
- チケット: $AI_DEV_TASK
- 作業ドキュメント: docs/working/$AI_DEV_TASK/status.md

## 現在の状態
PBI 未記入

## タスク
1. pbi-input.md を埋める
\`\`\`

---

## 参照ファイル

| 用途 | パス |
|------|------|
| 実行計画 | \`docs/working/$AI_DEV_TASK/plan.md\` |
| ToDo | \`docs/working/$AI_DEV_TASK/todo.md\` |
| このステータスファイル | \`docs/working/$AI_DEV_TASK/status.md\` |
| CLAUDE.md | \`CLAUDE.md\` |
EOF
}

ai_dev_create_pbi_stub() {
  cat >"$AI_DEV_WORK_DIR/pbi-input.md" <<EOF
# $AI_DEV_TASK PBI INPUT PACKAGE

## Why

- TODO

## What

- TODO

## Acceptance Criteria

- [ ] TODO

## Constraints / Non-goals

- TODO

## Related Files / URLs

- TODO

## Open Questions

- TODO
EOF
}

ai_dev_require_file() {
  file_path=$1
  description=$2
  if [ ! -f "$file_path" ]; then
    echo "Missing $description: $file_path" >&2
    return 1
  fi
}
