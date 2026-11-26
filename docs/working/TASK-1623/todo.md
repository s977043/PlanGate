# TASK-1623 EXECUTION TODO

## Mode

high-risk（plan.md「Mode判定」）。全実装タスクに rollback を記載。

## 🤖 Agent タスク

### 1. 準備

- [ ] T-01 Q-1 / Q-2 の決定記録を status.md に転記し、未決定なら停止（Owner: agent, depends_on: H-01, H-02）🚩 rollback: 不要（読取のみ）
- [ ] T-02 main と `6756a597` の `run_event.py` 構造定義差分を測る（RT-2 判定）（Owner: agent, depends_on: T-01）rollback: 不要

### 2. 実装

- [ ] T-03 RED: outcome 別の最悪ケース fixture と境界テスト、`test_no_byte_constants` の置換テストを追加し FAIL を確認（Owner: agent, depends_on: T-02）🚩 rollback: 追加したテスト・fixture を revert
- [ ] T-04 GREEN: `limits.py` に 3 定数と導出根拠コメント（実測値と切り上げ規則）を追加（Owner: agent, depends_on: T-03）🚩 rollback: `limits.py` を main の blob に戻す
- [ ] T-05 drift テスト: fixture 写像と実 `run_event` validator の byte 同値照合（Owner: agent, depends_on: T-04）rollback: テスト revert
- [ ] T-06 I-11 byte 検査の接続（配置は Q-1 の決定に従う。案 B なら #1623-b）（Owner: agent, depends_on: T-04, H-01）🚩 rollback: 接続 commit を revert
- [ ] T-07 #1392 reserve 契約 fixture（同じ定数を import）（Owner: agent, depends_on: T-04）rollback: fixture revert

### 3. 検証

- [ ] T-08 mutation 注入（定数 −1 / escape 無視 / 区分二重計上 / outcome 1 種欠落）が全て検出される（Owner: agent, depends_on: T-05〜T-07）rollback: 不要
- [ ] T-09 敵対レビュー R1 → 是正 → R2（§7-quater、回避クラス台帳）（Owner: agent, depends_on: T-08）🚩 rollback: 不要

### 4. 完了

- [ ] T-10 status.md / handoff.md 更新（#1623 の Open/Close 条件を明記）（Owner: agent, depends_on: T-09）rollback: 不要

## 👤 Human タスク

- [ ] H-01 Q-1 順序の決定（案 A / B / C）
- [ ] H-02 Q-2 の owner 確認（#1392 / #1393 / #1395）
- [ ] H-03 C-3（c3.json 発行）
- [ ] H-04 C-4（PR レビュー・merge）

## ⚠️ 依存関係

- T-01 ← H-01, H-02 / exec 開始 ← H-03 / T-06 の配置 ← H-01
- 案 B の場合 T-06 は #1393 core（`DecisionInputError` 導入）の後
