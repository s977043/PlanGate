---
task_id: TASK-1651
artifact_type: review-self
schema_version: 1
status: draft
verdict: WARN
created_by: orchestrator
---

# TASK-1651 セルフレビュー結果（C-1）

> レビュー日: 2026-11-13
> 対象: plan-draft.md / todo.md / test-cases.md（照合: origin/main `8a689907`、静的読解のみ）
> 判定: **WARN** — critical=0, major=0, minor=2

## サマリー

| result | 件数 |
|--------|------|
| PASS | 22 |
| WARN | 2 |
| FAIL | 0 |
| N/A | 1 |

## Plan チェック

### C1-PLAN-01: 受入基準網羅性
- **result**: PASS
- **finding**: AC-1 → Task 2/3、AC-2 → Task 5、AC-3 → Task 3/4 に対応。

### C1-PLAN-02: Unknowns処理
- **result**: PASS
- **finding**: U-1/U-2 は Task 1 で実測し違えば Stop、U-3 は Out of scope として handoff に残す。

### C1-PLAN-03: スコープ制御
- **result**: PASS
- **finding**: 変更は 2 ファイル。B/C 案・`bin/plangate`・#921 を Non-goals に明記。

### C1-PLAN-04: テスト戦略
- **result**: PASS
- **finding**: Unit（TC-7b 合成入力）/ Integration（TC-7 実出力・harness）を区別。E2E 該当なしを明記。

### C1-PLAN-05: Work Breakdown Output
- **result**: PASS
- **finding**: 各 Task に Output / Completion / Rollback あり。

### C1-PLAN-06: 依存関係
- **result**: PASS
- **finding**: T-1 → T-7 の直列。RED（T-2）が GREEN（T-3）に先行。

### C1-PLAN-07: 動作検証自動化
- **result**: WARN
- **finding**: macOS の再現は実行コマンドで自動化済み。Linux での M-1 は CI 上でしか確認できず、ローカル exec では TC-7b の合成入力で代替する。
- **suggested_action**: exec 中に M-1 を一時コミットした draft ブランチで CI を 1 回回すか、未検証として handoff に明記する
- **owner**: agent / **resolved**: false

### C1-PLAN-08-AEE: Stop Condition 記入
- **result**: PASS
- **finding**: Replan Trigger + EH-3 block 時の停止を記載。

### C1-PLAN-09-AEE: Replan Triggers 機械値
- **result**: PASS
- **finding**: 変更ファイル数 > 2、絶対パス値 ≥ 1 件、実行時間 +10 秒。

## Plan 品質追加

### C1-SUP-PLAN-01: No Placeholders Rule
- **result**: PASS
- **finding**: TBD 等なし。検査器の判定手順・合成入力の値を具体化。

### C1-SUP-PLAN-02: Task Sizing Rules
- **result**: PASS
- **finding**: Task ごとに対象ファイル・検証コマンド・期待結果が独立。

## ToDo チェック

### C1-TODO-08: タスク粒度
- **result**: PASS
- **finding**: 各タスクは 1 ファイル・1 目的。

### C1-TODO-09: depends_on設定
- **result**: PASS
- **finding**: 全タスクに depends_on。

### C1-TODO-10: チェックポイント設定
- **result**: PASS
- **finding**: 実装タスクに 🚩 todo/status 更新。

### C1-TODO-11: Iron Law遵守
- **result**: PASS
- **finding**: T-1 は C-3 APPROVED 依存。H-0（plan.md 移動）と H-1（approve）を Human タスクとして分離。

### C1-TODO-12: 完了条件
- **result**: PASS
- **finding**: 全タスクに完了条件。

### C1-TODO-RB: rollback
- **result**: PASS
- **finding**: standard のため任意だが全タスクに記載（読み取りのみは「不要」）。

## テストケースチェック

### C1-TEST-13: 受入基準→テストケース網羅性
- **result**: PASS
- **finding**: AC-1〜3 すべてに TC / 変異が対応。

### C1-TEST-14: テストケースの具体性
- **result**: PASS
- **finding**: 合成 JSON の値まで記載、期待値の出所を列挙。TC-01 は変更前 FAIL→変更後 PASS の差分で、TC-04 は旧検査で非検出であることの記録で、変更前のコードでは満たされない条件にしている。

### C1-TEST-15: エッジケースの考慮
- **result**: PASS
- **finding**: キー欠落・空文字・`project_root_source` 絶対パス・非 JSON・相対パスを列挙。

## B-1/B-2

### C1-B1B2-16: B-1確認質問
- **result**: WARN
- **finding**: D-1（`project_root` を契約として認める）は issue で「判断が要る」とされた点。issue 推奨案 A に従ったが、Human の明示確認は未取得。
- **suggested_action**: C-3 で D-1 を明示的に確認してもらう
- **owner**: human / **resolved**: false

### C1-B1B2-17: B-2アプローチ比較
- **result**: PASS
- **finding**: A〜D の 4 案を比較し採否理由を記載。

### C1-SEC-01: 秘密情報 非接触
- **result**: PASS
- **finding**: 個人パスを出力する検査の強化であり、秘密情報を新たに扱わない。テスト fixture の合成パスは実在ユーザー名を含まない。

### C1-SCOPE-DISC-01: 発見事項の予防的分離
- **result**: PASS
- **finding**: U-3（metrics-privacy §4）・#921 を handoff / 別 issue へ分離する方針。

### C1-UI-01: UI デザインシステム準拠
- **result**: N/A
- **finding**: non-UI。

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| C1-TEST-14 | D-3（埋め込みパス）を追加し、TC-05 / M-2 を追加 | plan-draft.md / test-cases.md |
