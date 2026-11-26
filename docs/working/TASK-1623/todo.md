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
- [ ] T-05 ズレ検出テスト（`test_limits.py` に同居）: 埋め込み写像の定義行 sha256 照合（MC-2a / R-004）、V2 の印が全て無い tree では写像で byte 再現（MC-3）、印が 1 つでもある tree では実 `run_event` validator と byte 同値・キー集合一致を照合し main 用分岐に入れば FAIL（AC-5 / R-001）（Owner: agent, depends_on: T-04）rollback: テスト revert
- [ ] T-05b ta-118 に `skipped=` の FAIL 判定を追加（別ファイルにした場合は実行行も）（AC-4 / R-003）（Owner: agent, depends_on: T-05）rollback: `tests/extras/ta-118-ai-loop-v2-limits.sh` を main の blob に戻す
- [ ] T-07 #1392 reserve 契約 fixture（`test_limits` 系に配置、`TERMINAL_RESERVE` は fixture 内の契約値、同じ定数を import）（R-007）（Owner: agent, depends_on: T-04）rollback: fixture revert

### 3. 検証

- [ ] T-08 mutation 注入（定数 −1 / escape 無視 / 区分二重計上 / outcome 1 種欠落 / 構造キー 1 件増減 / V2 tree で main 用分岐を強制 / V2 の印の一部だけ残す / テストを skip させる）が全て検出される（Owner: agent, depends_on: T-05, T-05b, T-07）rollback: 不要
- [ ] T-09 敵対レビュー R1 → 是正 → R2（§7-quater、回避クラス台帳）。R2 で新しい回避クラス 0 件なら終了、1 件以上で R3（R-009）（Owner: agent, depends_on: T-08）🚩 rollback: 不要
- [ ] T-11 MC-2（D-2）: 前半 PR の CI ログで定義行ハッシュ一致と skip 0 件を確認し evidence に保存。実行行 0 件または `skipped=` ありなら RT-7 で停止（Owner: agent, depends_on: T-05b）🚩 rollback: 不要

### 4. 完了

- [ ] T-10 status.md / handoff.md 更新（AC-2 未達・後半待ち、後半マージまで byte 上限は強制されていない、#1623 Open 維持、PR 本文は `Refs #1623` のみ = MC-1 / R-006。#1391 への引き継ぎ事項 H-1391-1〜3 を転記）（Owner: agent, depends_on: T-09, T-11）rollback: 不要

## 後半（参考・本 todo の exec 対象外）

- T-06 I-11 byte 検査の接続（`make_decision_input`、#1393 core と同時かその直後。別 C-3）

## 👤 Human タスク

- [x] H-01 Q-1 順序の決定 → 案 B（2026-11-26、plan.md D-1）
- [x] H-01b MC-2 の移管 → D-2（2026-11-26）
- [ ] H-02 Q-2 の owner 確認（#1392 / #1393 / #1395）。期限: 初回確認から 5 営業日（RT-3 / R-010）
- [ ] H-03 C-3（c3.json 発行）
- [ ] H-04 C-4（PR レビュー・merge）

## ⚠️ 依存関係

- T-01 ← H-02 / exec 開始 ← H-03 / C-4 ← T-11（MC-2）
- T-11 は前半 PR の CI run で完結する（D-2）。#1391 PR での実 validator 照合は #1391 の C-4 前提（plan.md H-1391-1）で本 todo の対象外
- 後半 T-06 は #1393 core（`DecisionInputError` 導入）と同時かその後
