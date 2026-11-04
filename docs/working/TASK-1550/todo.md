# TASK-1550 — EXECUTION TODO（C-3 未承認）

> 対応 plan: v0.2（2026-11-02 12:06 測定）。plan.md への反映は未了（[status.md](./status.md) の blocker 参照）。

## 準備（C-3 前に AI ができる範囲）

- [x] D-00: Issue #1550 / PR #1547 / mode-classification / responsibility-classes を照合。Owner: agent
  - 完了条件: #1547 が MERGED（2026-10-11、`2ea049de`）であることを記録済み
  - rollback: 不要（読取のみ）
- [x] D-01: PR 作成経路 R-1〜R-10 と baseline（3/30・5/30・2/30）を測定。Owner: agent 🚩
  - 完了条件: plan v0.2 §1 に測定日時・HEAD・コマンド・範囲を記録
  - rollback: 不要（読取のみ）
- [ ] D-01b: plan.md を v0.2 に置き換える。Owner: agent。depends_on: Human が `PLANGATE_HOOK_TASK=TASK-1550` でセッションを起動
  - 完了条件: plan.md の `## Mode判定` 節と §1〜§3 が v0.2 と一致
  - rollback: 当該 commit を `git revert`
- [ ] D-01c: plan v0.2 で C-1 を再実施し review-self.md を更新。Owner: agent。depends_on: D-01b
  - 完了条件: FAIL 0
  - rollback: 当該 commit を `git revert`
- [ ] D-02: C-2 R1（設計妥当性レーン + コードベース整合レーン）→ `review-external.md` に `R-NNN` で集約。Owner: agent。depends_on: D-01c
  - 完了条件: 回避クラス台帳を作成
  - rollback: 不要（レビュー記録のみ。commit 単位で revert 可）
- [ ] D-03: C-2 R2（R1 の是正そのものを疑う）。収束判定は「新しいクラスが出なくなったか」。Owner: agent。depends_on: D-02
  - 完了条件: 残存脅威モデルを記録
  - rollback: 不要（同上）

## 実装（Human C-3 後）

- [ ] H-01 (human): C-3 同期承認。`approvals/c3.json` は Human が発行する。depends_on: D-03
- [ ] T-01: fixture を先に書き、現行の `pr-decision` で FAIL することを確認する（TC-02〜TC-05）。Owner: agent。depends_on: H-01 🚩
  - 完了条件: 失敗ログを `evidence/test-runs/` に保存
  - rollback: T-01 の commit を `git revert`（追加した fixture が消えるだけ）
- [ ] T-02: `.agents/skills/pr-decision/SKILL.md` に「PR 本文への投影」節（参照のみ・3 点）を追加。Owner: agent。depends_on: T-01
  - 完了条件: TC-02〜TC-06 が PASS
  - rollback: T-02 の commit を `git revert`
- [ ] T-03: sync スクリプトでミラー再生成 → drift 検査。Owner: agent。depends_on: T-02 🚩
  - 完了条件: TC-07 PASS（drift 0）
  - rollback: T-02 と同じ commit 単位で revert し、再度 sync スクリプトを流す
- [ ] T-04: 実装 PR の本文で `## Rollback / Detection` の 3 行を記入（TC-08 の最初の観測点）。Owner: agent。depends_on: T-03
  - 完了条件: PR 本文に TODO が残っていない
  - rollback: 不要（PR 本文の編集のみ）
- [ ] H-02 (human): Phase 2（workflow-conductor への 1 行・HO）の採否。採る場合は AI が作った適用スクリプトを Human が実行。depends_on: T-03
  - rollback: Human が適用スクリプトの逆 patch を適用（AI は revert patch の作成まで）
- [ ] H-03 (human): C-4 / merge。depends_on: T-04, H-02
- [ ] O-01: merge 後、TC-01 と同じ条件で baseline を再測定し status.md に記録。Owner: agent。depends_on: H-03 🚩
  - 完了条件: 「設計 / 反映 / 実利用」を分けて記録。未観測なら `NOT VERIFIED`
  - rollback: 不要（測定のみ）

## 依存関係（Agent ↔ Human）

D-01b ← Human のセッション起動 / T-01 ← H-01 / H-03 ← T-04・H-02 / O-01 ← H-03
