# TASK-1623 EXECUTION TODO

## Mode

high-risk（plan.md「Mode判定」）。全実装タスクに rollback を記載。

## 🤖 Agent タスク

### 1. 準備

> 対象は前半（#1623-a）のみ（plan.md D-1）。後半（I-11 接続）は別スライス・別 C-3。

- [ ] T-01 Q-2 の確定記録を status.md に転記し、未確定なら停止（Owner: agent, depends_on: H-02）🚩 rollback: 不要（読取のみ）
- [ ] T-02 main と `6756a597` の `run_event.py` 構造定義差分を測る（RT-2 判定）（Owner: agent, depends_on: T-01）rollback: 不要

### 2. 実装

- [ ] T-03 RED: outcome 別の最悪ケース fixture と境界テスト、`test_no_byte_constants` の置換テストを追加し FAIL を確認（Owner: agent, depends_on: T-02）🚩 rollback: 追加したテスト・fixture を revert
- [ ] T-04 GREEN: `limits.py` に 3 定数と導出根拠コメント（実測値と切り上げ規則）を追加（Owner: agent, depends_on: T-03）🚩 rollback: `limits.py` を main の blob に戻す
- [ ] T-05 ズレ検出テスト: main 上は固定 SHA 写像を検査（skip しない / MC-3）、V2 構造がある tree では実 `run_event` validator と byte 同値・キー集合一致を照合（Owner: agent, depends_on: T-04）rollback: テスト revert
- [ ] T-07 #1392 reserve 契約 fixture（同じ定数を import）（Owner: agent, depends_on: T-04）rollback: fixture revert

### 3. 検証

- [ ] T-08 mutation 注入（定数 −1 / escape 無視 / 区分二重計上 / outcome 1 種欠落 / 構造キー 1 件増減）が全て検出される（Owner: agent, depends_on: T-05, T-07）rollback: 不要
- [ ] T-09 敵対レビュー R1 → 是正 → R2（§7-quater、回避クラス台帳）（Owner: agent, depends_on: T-08）🚩 rollback: 不要
- [ ] T-11 MC-2: #1391 PR の CI ログでズレ検出テストの実行（skip / 未収集でない）を確認し evidence に保存。0 件なら RT-7 で停止（Owner: agent, depends_on: T-05）🚩 rollback: 不要

### 4. 完了

- [ ] T-10 status.md / handoff.md 更新（AC-2 未達・後半待ち、#1623 Open 維持、PR 本文は `Refs #1623` のみ = MC-1）（Owner: agent, depends_on: T-09, T-11）rollback: 不要

## 後半（参考・本 todo の exec 対象外）

- T-06 I-11 byte 検査の接続（`make_decision_input`、#1393 core と同時かその直後。別 C-3）

## 👤 Human タスク

- [x] H-01 Q-1 順序の決定 → 案 B（2026-11-26、plan.md D-1）
- [ ] H-02 Q-2 の owner 確認（#1392 / #1393 / #1395）
- [ ] H-03 C-3（c3.json 発行）
- [ ] H-04 C-4（PR レビュー・merge）

## ⚠️ 依存関係

- T-01 ← H-02 / exec 開始 ← H-03 / C-4 ← T-11（MC-2）
- T-11 は #1391 PR が前半を取り込んだ CI run を要する（#1391 側の作業に依存）
- 後半 T-06 は #1393 core（`DecisionInputError` 導入）と同時かその後
