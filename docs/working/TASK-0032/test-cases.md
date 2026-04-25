# テストケース定義 — TASK-0032

## メタ情報

```yaml
task: TASK-0032
related_issue: https://github.com/s977043/plangate/issues/57
phase: B（テストケース定義）
created_at: 2026-04-26
```

## 受入基準 → テストケースマッピング

| AC-ID | 受入基準 | テストケース |
|-------|---------|------------|
| AC-1 | high-risk 以上で Design Gate なしに実装へ進めない（completion-gate.md に明記） | TC-01 |
| AC-2 | critical で rollback plan なしに完了できない（completion-gate.md に明記） | TC-02 |
| AC-3 | TDD 必須モードで failing test evidence がない場合にブロックできる | TC-03 |
| AC-4 | Review Gate で critical finding がある場合に Completion Gate が失敗する | TC-04 |
| AC-5 | Evidence Ledger なしに Completion Gate が passed にならない | TC-05 |
| AC-6 | 軽微修正では Design/TDD/Review を過剰要求しない | TC-06 |

## テストケース一覧

| TC-ID | 対応 AC | 前提条件 | テスト操作 | 期待結果 | 種別 |
|-------|--------|---------|-----------|---------|------|
| TC-01 | AC-1 | Mode: high-risk | `completion-gate.md` を参照し「条件 1: Design Gate パス必須（high-risk/critical）」セクションを確認 | `high-risk` 以上で Design Gate が必須（BLOCKED 条件として）明記されている | 文書確認 |
| TC-02 | AC-2 | Mode: critical | `completion-gate.md` を参照し Mode 別適用マトリクスの `critical` 行と条件 5 を確認 | Rollback Plan が `critical` で **必須** と明記されている | 文書確認 |
| TC-03 | AC-3 | Mode: high-risk | `completion-gate.md` の条件 2 および `plugin/plangate/commands/pg-tdd.md` の連携記述を確認 | `type: "test"` の証拠が欠落時のブロック条件が明記されている | 文書確認 |
| TC-04 | AC-4 | Review Gate に critical finding あり | `completion-gate.md` の条件 3 および `plugin/plangate/rules/review-gate.md` の Completion Gate ブロック条件を確認 | `severity=critical` finding → Completion Gate ブロックの連携が両ファイルで整合していることを確認 | 文書確認 |
| TC-05 | AC-5 | Evidence Ledger 欠落 | `completion-gate.md` の条件 4 を確認 | Evidence Ledger の `status: "passed"` が Completion Gate の必須条件として明記されている | 文書確認 |
| TC-06 | AC-6 | Mode: ultra-light / light | `plugin/plangate/rules/mode-classification.md` の「## Gate 適用マトリクス」を確認 | `ultra-light` / `light` の Design Gate・TDD Gate が `-`（スキップ）になっている | 文書確認 |

## エッジケース

| ケース | 期待動作 |
|--------|---------|
| `standard` モードで Evidence Ledger が存在しない | 条件 4 でブロック（standard では Evidence Ledger 必須） |
| `ultra-light` モードで Review Gate の critical finding がある | スキップ設定だが、条件 3 により全モードでブロック |
| `high-risk` モードで major finding のみの場合 | 推奨ブロック（必須ブロックではない）として記述されていること |
| `critical` モードで major finding のみの場合 | 強制ブロックとして記述されていること |

## 自動化可否

| テストケース | 自動化 | 備考 |
|------------|--------|------|
| TC-01〜06 | 手動（文書確認） | Markdown 内容の意味検証は人間が確認。markdownlint による構造チェックは CI で自動化 |
| エッジケース | 手動（文書確認） | 記述の正確性確認 |
