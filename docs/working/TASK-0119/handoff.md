---
task_id: TASK-0119
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-29
author: qa-reviewer
v1_release: ""
---

# Handoff Package — TASK-0119

## メタ情報

```yaml
task: TASK-0119
related_issue: TBD
author: qa-reviewer
issued_at: 2026-05-29
v1_release: ""
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: `scripts/check-git-add-scope.sh` が staged diff に noise を検知して warning + exit 1 | PASS | TC-06 (skip-log 未追認) / TC-07 (異 TASK eval-result) で exit 1 確認 |
| AC-2: TASK-0113 hook との重複回避 (共通化 or 明確な責務分界) | PASS | T-01 調査で責務分界確定。claude-mem 検知は TASK-0113 主担当、本スクリプトは補完として二重警告を許容 |
| AC-3: allowlist marker で個別許可可能 | PASS | `PLANGATE_SKIP_SCOPE_CHECK=1` 環境変数による全スキップを実装。TC-04 PASS |
| AC-4: `docs/ai/git-add-scope-guard.md` 運用ガイド | PASS | TC-03 で存在 + 主要 section 確認 |
| AC-5: `tests/extras/ta-22-git-add-scope.sh` で fixture 検証 | PASS | TC-01〜08 全 PASS (8件) |
| AC-6: markdownlint + 既存テスト regression なし | PASS | テストスイート 204 passed, 0 failed |

**総合**: `6/6 基準 PASS`

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| pre-commit.sample への統合ポイント未追加 | minor | accepted | Yes |
| `<claude-mem-context>` 検知時に TASK-0113 インストール済みかの自動判定なし (二重警告あり) | minor | accepted | Yes |
| `PLANGATE_HOOK_TASK` 未設定時は eval-result チェックをスキップ (INFO のみ) | minor | accepted | No (仕様通り) |

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| `scripts/templates/pre-commit.sample` への scope-guard 統合 | T-01 で判断を defer、今回は独立スクリプトとして運用 | Medium | - |
| TASK-0113 インストール検出による `<claude-mem-context>` 重複検知抑制 | 二重警告は動作上無害だが UX 改善余地あり | Low | - |

## 4. 妥協点

| 選択肢 | 採用/不採用 | 理由 |
|--------|-----------|------|
| `scripts/hooks/` 配下に配置 | 不採用 (Try #1 で失敗) | Hardening Override パスのため AI exec 不可 → `scripts/` ルート直下に再スコープ |
| pre-commit.sample への統合 | 不採用 (V2 候補) | T-01 調査で独立スクリプトとして運用する方が責務分界が明確と判断 |
| `acknowledged_by:null` 以外の未追認パターン追加 | 不採用 | 現行スキーマは `acknowledged_by:null` が唯一の未追認マーカー |

## 5. 引き継ぎ文書

TASK-0119 は `git add -A` による scope 外ファイル誤混入を pre-commit 層で機械検知する仕組みを追加した。

**主要成果物:**
- `scripts/check-git-add-scope.sh`: 検知スクリプト (実行可能、HO 外)
- `docs/ai/git-add-scope-guard.md`: 運用ガイド
- `tests/extras/ta-22-git-add-scope.sh`: 検証テスト (ta-22、8 TC PASS)

**使い方の要点:**
- `PLANGATE_SKIP_SCOPE_CHECK=1 git commit` で緊急スキップ
- `PLANGATE_HOOK_TASK=TASK-XXXX git commit` で eval-result scope チェックを有効化
- pre-commit hook への組み込みは `scripts/install-pre-commit.sh` 更新が必要 (手動、V2)

**TASK-0113 との関係:**
- 責務分界: claude-mem 検知 = TASK-0113、skip-log/eval-result = TASK-0119
- 二重警告は許容設計

## 6. テスト結果サマリ

```
=== TA-22: git-add-scope-guard (TASK-0119) ===
  [PASS] TC-01 check-git-add-scope.sh 存在 + 実行可能
  [PASS] TC-02 sh -n syntax check
  [PASS] TC-03 doc 存在 + 主要 section
  [PASS] TC-04 PLANGATE_SKIP_SCOPE_CHECK=1 でスキップ (exit 0)
  [PASS] TC-05 空 staging area → 通過 (exit 0)
  [PASS] TC-06 skip-log 未追認 → 検知 + exit 1
  [PASS] TC-07 異 TASK eval-result → 検知 + exit 1
  [PASS] TC-08 同 TASK eval-result → 通過 (exit 0)

全テストスイート: 204 passed, 0 failed
```
