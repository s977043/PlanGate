---
task_id: TASK-0070
artifact_type: status
schema_version: 1
---

# TASK-0070 STATUS

## 全体構成

- ブランチ: `feature/TASK-0070-eh3-path-sensitive-skip`
- モード: standard（セキュリティ変更）

## C-3 Gate: CONDITIONAL

F-1（target_file 空時 fail-safe）を **F1-b**（PLANGATE_HOOK_FILE wiring を In scope
格上げ）でユーザー判定。plan/pbi-input/AC-8 反映済み。plan_hash 固定（c3.json）。

## 実装状態

- `scripts/hooks/check-plan-hash.sh`: TASK resolution を P4(d) に置換
- `tests/hooks/run-tests.sh`: P4d TC-1〜8 追加
- `.claude/settings*.json` wiring: **Claude 適用不可 → ユーザー手動適用待ち（AC-8）**

## V系進捗

- L-0: dash -n PASS
- V-1: AC-1〜7 PASS / AC-8 WARN（手動待ち）
- V-3: 未（Codex は PR #242 マージ後。Gemini は任意で実施可）

## 残タスク

- [ ] AC-8 wiring 2行をユーザー手動適用
- [ ] V-3 外部レビュー
- [ ] C-4 PR レビュー

## 計画からの変更点

- C-3 で wiring を Out→In scope 格上げ（F1-b）。ただし Claude 自己改変ガードで
  settings 適用はユーザーに委譲（handoff §2 に手順記載）
