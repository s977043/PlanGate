# TASK-1608 handoff（verify 時点 / T-16 敵対レビュー前）

> issued_at_commit: `57673063`（実装の最終 commit。本ファイルを含む commit はその直後）。以下の測定値はこの SHA 時点の値。
> 改訂 plan（D-1b、plan_hash `439f1620…`、C-3 再承認 2026-10-24T16:15:34Z）に基づく。T-16（敵対レビュー R5 / R6）後に更新する。

## 1. 要件適合確認（総合: WARN）

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 既存テスト・ta-116 PASS | **WARN** | 単体 57 件 OK・ta-116 2 passed / 0 failed。ただし #1574 由来の既存テスト 1 件の fixture に空行を 1 行挟んだ（D-012。AC-1 と TC-CB-05 の衝突を D-1b 優先で解消、判定の意図は不変） |
| AC-2 HTML コメント / ブロック内の seed を数えない | PASS | TC-R4-02 / TC-HTML-01〜06 |
| AC-3 現行データ REVIEW_CANDIDATE / 7 / 5 | PASS | `evidence/test-runs/t14-current-data.json` |
| AC-4 #1574 台帳の回帰ケース | PASS | test-cases の TC-R1〜R4 |
| AC-5 不可視文字は拒否 | PASS | TC-INV-01〜04 |
| AC-6 否定値は拒否 / 同綴り人名は誤拒否を固定 | PASS | TC-R2-06 / TC-R4-03 / TC-NEG-01〜02 / adv_r3_02 |
| AC-7 全文走査の正規表現を使わない | PASS | TC-STRUCT-01 |
| AC-8 PG-SH-GUARD バイト一致 | PASS | ta-70 9 passed / 0 failed |
| AC-9 標準ライブラリのみ | PASS | TC-STRUCT-02 |
| AC-10 対象ブロックは CommonMark 規則、守備範囲外は拒否 | PASS（T-16 未了） | R4 critical を TC-CB-01〜04 で拒否側に固定。敵対レビュー R5 / R6 は未実施 |
| AC-11 空行なしのコンテナ切り替えは拒否、現行データで誤拒否なし | PASS | TC-CB-01〜07 / N1〜N3、現行データ 7 / 5 不変 |

## 2. 既知課題

- 敵対レビュー R5 / R6（T-16）が未実施。コンテナ境界規則の回避（タブ・入れ子・順序付きリスト等）と正常系の誤拒否は未評価
- 変異 M17 は等価変異として生存（D-1b により到達入力が境界で先に拒否される）
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
| `python3 scripts/test_improvement_seed_delta.py` | 57 tests OK（rc=0） |
| `sh tests/extras/ta-116-improvement-seed-delta.sh` | 2 passed / 0 failed（rc=0） |
| `sh tests/extras/ta-70-py-sh-misinvocation-guard.sh` | 9 passed / 0 failed（rc=0） |
| 現行データ CLI | rc=0、REVIEW_CANDIDATE / 7 / 2 / 5 |
| 変異注入（34 種） | 33 KILLED / 1 等価（M17）（`evidence/test-runs/t9-mutation.log`） |
