# TASK-1608 handoff（verify 時点 / T-16 敵対レビュー前）

> issued_at: R5 是正後（本ファイルを含む commit。測定値はその commit の実装に対する値）。
> 改訂 plan（D-1b、plan_hash `439f1620…`、C-3 再承認 2026-10-24T16:15:34Z）に基づく。R5 是正済み、R6 は未実施。

## 1. 要件適合確認（総合: WARN）

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 既存テスト・ta-116 PASS | **WARN（Human 確認事項）** | 単体 61 件 OK・ta-116 2 passed / 0 failed。ただし **AC-1 と TC-CB-05 が衝突**している: main の既存テスト `test_non_seed_heading_without_date_is_accepted` は「リスト項目の直後に空行なしで `### 補足`」を受理と期待し、承認済み TC-CB-05 は同じ形を拒否と定める。D-1b（Human 裁定）を優先し、既存テストの入力に空行 1 行を挟んだ（D-012）。「日付の無い見出しは受理」という意図は残るが、main の既存テストの入力を書き換えた点で AC-1 の趣旨を一部損なう。AC-1 を「既存テストの意図を保つ」と読み替えてよいか、または ATX 見出しを境界規則から外すかの判断が要る |
| AC-2 HTML コメント / ブロック内の seed を数えない | PASS | TC-R4-02 / TC-HTML-01〜06 |
| AC-3 現行データ REVIEW_CANDIDATE / 7 / 5 | PASS | `evidence/test-runs/t14-current-data.json` |
| AC-4 #1574 台帳の回帰ケース | PASS | test-cases の TC-R1〜R4 |
| AC-5 不可視文字は拒否 | PASS | TC-INV-01〜04 |
| AC-6 否定値は拒否 / 同綴り人名は誤拒否を固定 | PASS | TC-R2-06 / TC-R4-03 / TC-NEG-01〜02 / adv_r3_02 |
| AC-7 全文走査の正規表現を使わない | PASS | TC-STRUCT-01 |
| AC-8 PG-SH-GUARD バイト一致 | PASS | ta-70 9 passed / 0 failed |
| AC-9 標準ライブラリのみ | PASS | TC-STRUCT-02 |
| AC-10 対象ブロックは CommonMark 規則、守備範囲外は拒否 | PASS（R6 未了） | R4 critical を TC-CB-01〜04、R5 critical を adv_r5_c1 で拒否側に固定 |
| AC-11 空行なしのコンテナ切り替えは拒否、現行データで誤拒否なし | PASS | TC-CB-01〜07 / N1〜N3、現行データ 7 / 5 不変 |

## 2. 既知課題

- 敵対レビュー R6 が未実施（R5 は是正済み: 状態判定の入力の不一致 = 新クラス）。R5 は列 2 以上・タブ・深い入れ子・番号付きリスト・lazy 継続が拒否側に倒れることを確認済み
- **拒否が広い（m-1）**: リスト行の直後に空行なしで見出しや fence を置くだけで拒否される。R5 の実測で repo の `.md` 2,228 本中 75 本が `container boundary` で拒否される（seeds / digest は該当しない）。本検査を他の文書へ流用しないこと（docstring にも明記）
- D-012（AC-1 と TC-CB-05 の衝突、§1）は Human 確認事項
- 区切りの無い和文の否定値（「未確認です」）は検出しない（docstring に明記）

## 3. V2 候補

- コンテナのスタックを持つ状態機械、または markdown-it-py による AST 化（D-011 で今回は不採用）
- 確認マーカーの構造化（#1545 側）

## 4. 妥協点

- コンテナ境界は解釈せず拒否（D-011）。正当な文書でも「リストの直後に空行なしで見出し」等を書くと拒否される
- 確認値は構文文字（`< > & [ ] \`）を含めば拒否（D-009）
- 既存テスト 1 件の fixture を調整（D-012）

## 5. 引き継ぎ

初版 exec は敵対レビュー R4 で Stop Condition に該当し停止、Human 裁定 (c) で「コンテナが空行なしで別ブロックへ切り替わる構成は拒否する」（D-1b）へ守備範囲を縮めた。
再承認後、TC-CB を先に追加して RED（7 FAIL）を確認し、`line_shape` / `next_container` による境界判定を実装した。
T-16 の敵対レビューはオーガナイザー側で実施する。収束すれば T-12 で PR を ready にする。

## 6. テスト結果

| コマンド | 結果 |
|---------|------|
| `python3 scripts/test_improvement_seed_delta.py` | 61 tests OK（rc=0） |
| `sh tests/extras/ta-116-improvement-seed-delta.sh` | 2 passed / 0 failed（rc=0） |
| `sh tests/extras/ta-70-py-sh-misinvocation-guard.sh` | 9 passed / 0 failed（rc=0） |
| 現行データ CLI | rc=0、REVIEW_CANDIDATE / 7 / 2 / 5 |
| 変異注入（36 種） | 36 KILLED（`evidence/test-runs/t9-mutation.log`。M17 は等価判定を撤回し M17a / M17b に分割） |
