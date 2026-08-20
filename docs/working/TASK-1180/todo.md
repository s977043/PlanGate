# EXECUTION TODO — TASK-1180

## 🤖 Agent タスク

### 準備

- [x] T1: `origin/main` から作業ブランチを作成し、base を検証する（owner: agent / rollback: `git branch -D`）🚩
- [x] T2: 修正前 baseline を測定する（owner: agent / rollback: 不要=読取のみ）🚩

### 実装

- [x] T3: 変異 M2b を現行実装へ適用し、TC-C6 が SURVIVE することを実証する
      （owner: agent / rollback: `git checkout -- scripts/check-skill-name-collisions.py`）🚩
- [x] T4: TC-C6 fixture を `plugin/plangate/skills` へ修正する
      （owner: agent / rollback: `git checkout -- tests/extras/ta-69-distribution-checks.sh`）
- [x] T5: 変異 M2b 適用下で TC-C6 が KILL されることを実証する（owner: agent / rollback: 不要=読取のみ）🚩

### 検証

- [x] T6: 変異を revert し、`git diff --name-only` で本番コードが無変更であることを実測する
      （owner: agent / rollback: 不要）🚩
- [ ] T7: `tests/run-tests.sh` で full suite の回帰なしを確認する（owner: agent / rollback: 不要=読取のみ）🚩
- [ ] T8: C-1 セルフレビューを実施する（owner: agent / rollback: 不要）
- [ ] T9: W チェック 2 体 → `arbiter.py` 裁定 → record 保存（owner: agent / rollback: 不要）🚩

### 完了

- [ ] T10: 対象ファイルのみ stage し、`git diff --cached` で他者変更の混入なしを検証して commit
      （owner: agent / rollback: `git reset --soft HEAD~1`）🚩
- [ ] T11: PR 作成 → CI / レビュー対応 → **MERGE_READY で停止**（owner: agent / rollback: PR close）🚩
- [ ] T12: handoff.md 発行（owner: agent / rollback: 不要）

## 👤 Human タスク

- [ ] H1: C-3 相当（本 run は ai-loop の C-3' 裁定に載せる。escalate 時のみ人間判断）🚩
- [ ] H2: C-4 PR レビュー → **merge（Human-owned 固定）**🚩

## ⚠️ 依存関係

- T5 は T3（変異適用）と T4（修正）の両方に依存する
- T9 は T8（C-1 PASS）に依存する（`gates.c1` の入力）
- T11 は T9 の裁定結果に依存する（HUMAN_ESCALATED なら停止して H1 へ）
- H2 は T11 完了に依存する。**AI は merge しない**
