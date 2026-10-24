# TASK-1608 handoff（中間 / BLOCKED 時点）

> issued_at_commit: `a849dcfa`（実装の最終 commit。本ファイルを含む commit はその直後）。以下の測定値はこの SHA 時点の値。
> 本 handoff は完了資産ではなく、Stop Condition による停止時点の引き継ぎ。BLOCKED 解除後に更新する。

## 1. 要件適合確認（総合: WARN）

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 既存テスト・ta-116 PASS | PASS | 単体 55 件 OK（既存 22 件は無変更）、ta-116 2 passed / 0 failed、CI plangate CLI tests pass |
| AC-2 HTML コメント / ブロック内の seed を数えない | PASS | TC-R4-02 / TC-HTML-01〜06 |
| AC-3 現行データ REVIEW_CANDIDATE / 7 / 5 | PASS | `evidence/test-runs/t8-current-data.json` |
| AC-4 R1〜R4（#1574 台帳）の回帰ケース | PASS | test-cases.md の TC-R1〜R4 すべてに対応テスト |
| AC-5 不可視文字は拒否 | PASS | TC-INV-01〜04 |
| AC-6 否定値は拒否 / 同綴り人名は誤拒否を固定 | PASS | TC-R2-06 / TC-R4-03 / TC-NEG-01〜02 / adv_r3_02 |
| AC-7 全文走査の正規表現を使わない | PASS | TC-STRUCT-01（positive control つき） |
| AC-8 PG-SH-GUARD バイト一致 | PASS | ta-70 9 passed / 0 failed |
| AC-9 標準ライブラリのみ | PASS | TC-STRUCT-02 |
| AC-10 対象ブロックは CommonMark 規則、守備範囲外は fail-closed | **WARN** | 敵対レビュー R4 の critical（下記）が未是正。コンテナ軸で守備範囲外の構造が fail-open になる経路が残る |

## 2. 既知課題

- **critical（未是正）**: 空行なしの非リストブロック（`> q` / 列 0 の閉じた fence / `***`）でリストが終わっても `in_list` が残り、
  後続の `  ```` をリスト内 fence として開いた後に列 0 の行で閉じたと扱う。renderer では EOF まで code の seed を採用する（review-external.md R4）
- 拒否リスト方式の否定値判定は区切りの無い和文（「未確認です」）を検出しない（docstring に明記）

## 3. V2 候補

- コンテナ（blockquote / リスト項目）のスタックを持つ状態機械、または markdown-it-py による AST 化
- 確認マーカーを自由記述でなく構造化値（識別子 + 根拠）にするスキーマ変更（#1545 側）

## 4. 妥協点

- 確認値は表示の再現をやめ、構文文字（`< > & [ ] \`）を含む値を拒否した（D-009）。表示の再現は R1・R2 で連続して新クラスを生んだため
- マーカー行で開くブロックは追跡せず拒否した（R3）。コンテナのスタックを持たないための守備範囲の縮小
- R4 の是正は Stop Condition に従い行わなかった（D-010）

## 5. 引き継ぎ

#1608 の exec は C-3 承認済み plan で T-1〜T-10 まで完了した。新実装は旧実装より守備範囲が広い（旧実装は ZWSP 入り見出しを正規形として受理し、HTML コメント内の seed を数えていた。`evidence/test-runs/t2-red-old-impl.log`）。
ただし敵対レビューは R1〜R4 の 4 ラウンドで毎回新クラスが出た。値の層は判定モデルの変更（D-009）で R3・R4 では新クラスが出なくなったが、
ブロックの層はコンテナ軸で R3・R4 と連続して新クラスが出た。これは「コンテナのスタックを持たない限定状態機械」という Q-1 の設計そのものの限界と判断し、Human に設計の選択を戻す。
選択肢: (a) コンテナのスタックを実装（標準ライブラリのまま、規模は現行の 1.5〜2 倍見込み）/ (b) markdown-it-py（HO パス変更）/ (c) 守備範囲をさらに縮める（リスト中にリスト以外のブロックが現れたら拒否など。現行データで誤拒否が出ないかの実測が要る）。

## 6. テスト結果

| コマンド | 結果 |
|---------|------|
| `python3 scripts/test_improvement_seed_delta.py` | 55 tests OK（rc=0） |
| `sh tests/extras/ta-116-improvement-seed-delta.sh` | 2 passed / 0 failed（rc=0） |
| `sh tests/extras/ta-70-py-sh-misinvocation-guard.sh` | 9 passed / 0 failed（rc=0） |
| 現行データ CLI | rc=0、REVIEW_CANDIDATE / 7 / 2 / 5 |
| 変異注入（25 種） | すべて KILLED（`evidence/test-runs/t9-mutation.log`） |
| CI（PR #1611、各 push） | 全チェック pass |
