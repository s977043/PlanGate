# TASK-1623 TEST CASES

## 受入基準 → テストケース マッピング

| AC | TC |
|---|---|
| AC-1 最悪ケース event の組み立てと byte 計算が fixture で再現 | TC-01, TC-02, TC-03, TC-E01, TC-E02, TC-E03 |
| AC-2 I-11 が上限超過を `DecisionInputError` にする | TC-04, TC-05, TC-E04 |
| 派生 AC-3 #1392 reserve が同じ定数を参照 | TC-06 |
| 回帰（`test_no_byte_constants` の置換）| TC-07 |

## テストケース一覧

### TC-01: outcome 別の最悪ケース event の byte 数

- 前提: 構造は `6756a597` の `run_event`（`DECISION_REQUIRED_KEYS` / `COMMON_ACCEPTED_KEYS`）
- 入力: MERGE_READY / BLOCKED / HUMAN_ESCALATED / null の各合法最悪 event
- 期待: `canonical_bytes` 長の最大 ≤ `MAX_DECISION_EVENT_BYTES`、かつ最大値の event が `validate_event` を通る
- 種別: unit（自動）

### TC-02: 3 定数の区分整合

- 入力: 最悪 event を input 由来 / fixed / envelope に分割
- 期待: 各区分の実測 ≤ 対応定数、`input 由来上限 + DECISION_FIXED_OVERHEAD + ENVELOPE_OVERHEAD ≤ MAX_DECISION_EVENT_BYTES`、キー・区切りの二重計上なし
- 種別: unit

### TC-03: drift 照合

- 入力: fixture の構造写像と実 validator（`6756a597`、マージ後は main）
- 期待: 同じ event の byte 数が一致。構造キーが増減したら FAIL
- 種別: unit

### TC-04: I-11 上限ちょうどは受理

- 入力: byte 合計が上限ちょうどの `make_decision_input` 引数
- 期待: 例外なし
- 種別: unit（#1393 core 前提）

### TC-05: I-11 上限 +1 byte は拒否

- 期待: `DecisionInputError`、Decision を生成しない
- 種別: unit（#1393 core 前提）

### TC-06: reserve 契約

- 期待: #1392 側 fixture が `limits.MAX_DECISION_EVENT_BYTES` を import し、`TERMINAL_RESERVE >= 1 event and >= MAX_DECISION_EVENT_BYTES` を満たす
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

全件自動化可。TC-04 / 05 は #1393 core（`DecisionInputError`）が main に入るまで実行不可（案 B なら #1623-b）。

## 検証結果（V-1 で記入）

未実施。
