# TASK-0814 TODO

## 前提（BLOCKED 解除条件）

- BLOCKED: #780 Slice D 後半（feat/780-slice-d-run-meta）が **main マージ済み**（arbiter.py の最新形が確定してから・同一ファイル衝突回避）。owner=human/自律フロー・unblock=Slice D 後半 merged

## 🤖 Agent（委託: sonnet / worktree / main 起点・Slice D 後半マージ後）

- [ ] R0: 全 priority 網羅の characterization test 追加（現状固定・GREEN のまま） rollback:不要
- [ ] R2: _evaluate_signals 抽出 → 全テスト GREEN rollback:revert
- [ ] R1: priority 0〜4,6 をテーブル化（priority 5 は個別保持）→ record バイト一致確認 rollback:revert
- [ ] R3: _require_normalized_path_list 抽出 → GREEN rollback:revert
- [ ] R9: sync + plugin cmp + PR（refactor: プレフィックス）

## レビュー（承認前・必須）

- 動作不変の敵対的確認（record バイト一致を疑う）+ over-engineering チェック

## ⚠️ 依存

- Slice B（priority 1.7 追加）は R1 テーブル化後に載せると 1 エントリ追加で済む。順序: Slice D 後半 → #814 → Slice B が最も低コスト
