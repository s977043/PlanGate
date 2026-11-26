# TASK-1623 TEST CASES

## 受入基準 → テストケース マッピング

| AC | TC | スライス |
|---|---|---|
| AC-1 最悪ケース event の組み立てと byte 計算が fixture で再現 | TC-01, TC-02, TC-03, TC-E01, TC-E02, TC-E03 | 前半 |
| AC-2 I-11 が上限超過を `DecisionInputError` にする | TC-04, TC-05, TC-E04 | 後半 |
| 派生 AC-3 #1392 reserve が同じ定数を参照 | TC-06 | 前半（契約 fixture） |
| 回帰（`test_no_byte_constants` の置換）| TC-07 | 前半 |
| AC-4 CI 上 skip 0 件・ta-118 が `skipped=` を FAIL（R-011） | TC-10 | 前半 |
| AC-5 V2 構造着地時は写像だけの検査が FAIL し実照合へ（R-012） | TC-11 | 前半（番兵）。V2 tree での実照合 PASS は #1391 側（plan.md H-1391-1） |
| 前半マージ条件 MC-1〜MC-3（plan.md） | TC-08, TC-09 | 前半 |

## テストケース一覧

### TC-01: outcome 別の最悪ケース event の byte 数

- 前提: 構造は `6756a597` の `run_event` を定義行ハッシュで束縛した埋め込み写像
- 入力: MERGE_READY / BLOCKED / HUMAN_ESCALATED / null の各合法最悪 event
- 期待（main 上）: 埋め込み写像の `canonical_bytes` 相当（`ensure_ascii=False` 含む）で byte 数が再現され、最大 ≤ `MAX_DECISION_EVENT_BYTES`
- 期待（V2 tree 上）: 加えて最大値の event が実 `validate_event` を通る。これは #1391 の C-4 前提（plan.md H-1391-1）で、前半の合格条件ではない（R-005）
- 種別: unit（自動）

### TC-02: 3 定数の区分整合

- 入力: 最悪 event を input 由来 / fixed / envelope に分割
- 期待: 各区分の実測 ≤ 対応定数、`input 由来上限 + DECISION_FIXED_OVERHEAD + ENVELOPE_OVERHEAD ≤ MAX_DECISION_EVENT_BYTES`、キー・区切りの二重計上なし
- 種別: unit

### TC-03: drift 照合

- 入力: 埋め込み写像・fixture 記録の定義行 sha256（`6756a597` の監視対象: plan.md RT-2）
- 期待: 写像から再計算した定義行ハッシュが記録値と一致（MC-2a）。構造キーが増減したら FAIL。実行時に `git show` しない（shallow checkout 前提 / R-001）
- 種別: unit

### TC-08: 前半 PR の CI で定義行ハッシュ一致と skip 0 件（MC-2 / D-2）

- 入力: 前半 PR の CI run ログ（ta-118）
- 期待: TC-03 / TC-11 のテスト名の実行行があり PASS、`skipped=` 0 件（skipped / 未収集なら FAIL）
- 種別: 手動確認（ログ evidence 保存）

### TC-10: skip / 未収集の検出（AC-4）

- 入力: ta-118 の実行。mutation で新規テストに skip を注入した版
- 期待: 通常は PASS かつ `skipped=` なし。skip 注入版で ta-118 が FAIL
- 種別: unit / mutation

### TC-11: 一方向の番兵（AC-5）

- 入力: (a) V2 の印が全て無い tree、(b) 印の一部だけある tree、(c) V2 tree で main 用分岐を強制した版
- 期待: (a) 写像検査で PASS、(b) FAIL、(c) FAIL
- 種別: unit / mutation

### TC-09: #1623 Open 維持（MC-1）

- 期待: 前半 PR 本文に closing keyword がない（`Refs #1623` のみ）、マージ後 issue #1623 が Open
- 種別: 手動確認

### TC-04: I-11 上限ちょうどは受理

- 入力: byte 合計が上限ちょうどの `make_decision_input` 引数
- 期待: 例外なし
- 種別: unit（#1393 core 前提）

### TC-05: I-11 上限 +1 byte は拒否

- 期待: `DecisionInputError`、Decision を生成しない
- 種別: unit（#1393 core 前提）

### TC-06: reserve 契約

- 期待: 前半の `test_limits` 系に置いた契約 fixture が `limits.MAX_DECISION_EVENT_BYTES` を import し、fixture 内の契約値 `TERMINAL_RESERVE`（#1392 の exec で置換）が `>= 1 event and >= MAX_DECISION_EVENT_BYTES` を満たす。#1392 所有物を定義しない（R-007）
- 種別: unit（契約 fixture）

### TC-07: limits.py leaf 維持

- 期待: 既存 `test_imports_no_ai_loop_v2_module` / positive control が PASS、旧 `test_no_byte_constants` は削除のみで終わらず TC-01/02 に置換されている
- 種別: unit

## Edge Cases

- TC-E01: `verifier_id` 16 件 × 71 文字の ASCII 制御文字（escape 最大、#1635 の 428 byte/要素）
- TC-E02: 整数 field の最大桁（Q-2 で確定した `MAX_EVENTS_PER_RUN` と revision 上限）
- TC-E03: 任意 `artifact_ref` あり / なし、`stop_reasons` の最大合法組（重複可否は Q-2 の決定に従う）
- TC-E04: 件数上限内でも byte 超過になる入力（件数検査で止まらないこと）

## 自動化可否

TC-01〜07 / 10 / 11 は自動化可、TC-08 / 09 は手動確認。TC-04 / 05 / E04 は後半（#1623-b、#1393 core で `DecisionInputError` 導入後）で実行し、前半では実行しない。

## 検証結果（V-1 で記入）

未実施。
