# TEST CASES — TASK-0142

## 受入基準 → テストケースマッピング

| AC | テストケース |
|----|------------|
| AC-1 | TC-01, TC-02, TC-03 |
| AC-2 | TC-04 |
| AC-3 | TC-05 |
| AC-4 | TC-06 |

## テストケース一覧

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| TC-01 | — | `docs/workflows/07_exploratory_debug.md` が存在する | ファイルが存在する | 手動確認 |
| TC-02 | TC-01 PASS | WF-07 の目次を確認 | 「探索ループ」「長時間外部検証待機」「インシデント駆動 AC 更新」の3セクションが存在 | 手動確認 |
| TC-03 | TC-01 PASS | `waiting_external_verification` キーワードを確認 | ファイル内に存在する | grep 確認 |
| TC-04 | — | `docs/workflows/README.md` に WF-07 の参照行が存在する | `07_exploratory_debug.md` への参照が存在 | grep 確認 |
| TC-05 | — | `docs/workflows/execution-sequence.md` に探索モード分岐が存在する | 「探索」または「exploratory」のキーワードが存在 | grep 確認 |
| TC-06 | 全ファイル実装後 | `sh scripts/lint.sh` または markdownlint | PASS / エラーなし | 自動 |

## エッジケース

- WF-07 が WF-06 との番号衝突がないか確認（06_retro.md が既存、07 は新規）
- 相互リンクが正しい相対パス（`./07_exploratory_debug.md`）になっているか
