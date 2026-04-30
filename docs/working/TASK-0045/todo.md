# EXECUTION TODO: TASK-0045 / Issue #159

> Mode: **light**

## Tasks

### 準備

- [x] PBI INPUT 作成（pbi-input.md）
- [x] plan + todo 作成

### 実装

- [x] `scripts/check-pr-issue-link.sh` 実装
- [x] `.github/workflows/check-pr-issue-link.yml` 作成
- [x] `tests/fixtures/check-pr-issue-link/{pass,warn,skip-label,skip-marker}/` fixture 作成
- [x] `tests/run-tests.sh` に呼び出し追加
- [x] `docs/schemas/child-pbi.yaml` に optional `related_issue:` 追記

### 検証

- [x] `sh tests/run-tests.sh` 全 PASS
- [x] markdownlint / shellcheck 無し（既存 CI が走る）
- [x] handoff.md 作成

### 完了

- [x] commit + push + PR 作成
- [ ] CI 緑確認 → C-4 ゲート（人間レビュー）
