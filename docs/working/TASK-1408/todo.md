# TASK-1408 EXECUTION TODO（C-3 CONDITIONAL / c3.json 未発行）

## Mode

**モード**: critical

## 🤖 Agent タスク

### 1. 準備

- [ ] T-01: `git fetch` 後に main を再測定し、新規 canon commit と open PR の重複を確認する
  - Owner: agent
  - depends_on: H-01
  - files: 読取: `docs/ai/ai-loop-v2/`
  - rollback: 不要（読取のみ）
  - 完了条件: `<base>` SHA と差分表の更新要否を status.md に記録
  - 🚩 チェックポイント: M-1 が動いていたら Replan

- [ ] T-02: `ci.yml` L102 のテンプレート参照を読み、テンプレート変更の影響を確認する
  - Owner: agent
  - depends_on: T-01
  - files: 読取: `.github/workflows/ci.yml`
  - rollback: 不要（読取のみ）
  - 完了条件: 影響の有無を記録
  - 🚩 チェックポイント: CI 挙動が変わるなら Replan

### 2. 実装

- [ ] T-03: `evidence/measure.sh` を作る（ME-1〜5、commit 指定のみ、作業ツリー非依存）
  - Owner: agent
  - depends_on: T-01
  - files: `docs/working/TASK-1408/evidence/measure.sh`
  - rollback: `git rm docs/working/TASK-1408/evidence/measure.sh`
  - 完了条件: 親で M-2 が 0、merge で正の値、陽性対照ファイルを検出
  - 🚩 チェックポイント: なし

- [ ] T-04: 測定出力を保存する
  - Owner: agent
  - depends_on: T-03
  - files: `docs/working/TASK-1408/evidence/measurements.txt`
  - rollback: `git rm docs/working/TASK-1408/evidence/measurements.txt`
  - 完了条件: `<base>` を SHA で固定し、2 回実行で同一。canon 差分を含む測定は T-07 後に `<canon-sha>` で 1 回行う。evidence の commit で再生成しない
  - 🚩 チェックポイント: なし

- [ ] T-05: §7 に「例外の失効」節を追記する（Q-1, Q-2 の裁定を反映）
  - Owner: agent
  - depends_on: T-04, H-00, T-13
  - files: `docs/ai/ai-loop-v2/phase0-migration.md`
  - rollback: `git checkout origin/main -- docs/ai/ai-loop-v2/phase0-migration.md`
  - 完了条件: TC-01〜04, TC-06 PASS、`--numstat` の削除 0
  - 🚩 チェックポイント: 既存本文を変えたくなったら停止

- [ ] T-06: §8 に Phase 1 exit criteria を新設し 1 行追加する
  - Owner: agent
  - depends_on: T-05
  - files: `docs/ai/ai-loop-v2/phase0-migration.md`
  - rollback: `git checkout origin/main -- docs/ai/ai-loop-v2/phase0-migration.md`
  - 完了条件: TC-05 PASS
  - 🚩 チェックポイント: なし

- [ ] T-07: PR テンプレートに 1 項目追加する（Q-4 の裁定に従う）
  - Owner: agent
  - depends_on: T-02
  - files: `.github/PULL_REQUEST_TEMPLATE.md`
  - rollback: `git checkout origin/main -- .github/PULL_REQUEST_TEMPLATE.md`
  - 完了条件: TC-09 PASS
  - 🚩 チェックポイント: なし

- [x] T-13: H-04 の承認後に別 issue を起票し、番号、タイトル、本文を照合して status.md に記録する（#1643。status.md への記録は exec 開始時）
  - Owner: agent
  - depends_on: H-04
  - files: GitHub issue、`docs/working/TASK-1408/status.md`
  - rollback: issue の close（Human に確認）
  - 完了条件: 承認されたタイトルと一致する issue の番号を実測した
  - 🚩 チェックポイント: 番号を推測しない

- [ ] T-14: `<canon-sha>` の測定と `evidence/manifest.txt` を作る
  - Owner: agent
  - depends_on: T-05, T-06, T-07
  - files: `docs/working/TASK-1408/evidence/measurements.txt`, `manifest.txt`
  - rollback: `git revert <commit>`
  - 完了条件: blob SHA、入力 SHA、digest、実行者、時刻が揃う
  - 🚩 チェックポイント: なし

### 3. 検証

- [ ] T-08: R1 レビュー（I1 docs 整合 / I2 敵対）を `reviewed_at_sha` つきで実施する
  - Owner: agent
  - depends_on: T-05, T-06, T-07
  - files: `docs/working/TASK-1408/review-external.md`
  - rollback: 不要（記録のみ）
  - 完了条件: 指摘 R-NNN と回避クラス台帳を記録
  - 🚩 チェックポイント: §3 / §4 の弱化指摘で停止

- [ ] T-09: R1 是正後に R2（是正そのものを疑う）を実施する
  - Owner: agent
  - depends_on: T-08
  - files: `docs/working/TASK-1408/review-external.md`
  - rollback: 不要（記録のみ）
  - 完了条件: 新しいクラスの有無で収束判定
  - 🚩 チェックポイント: なし

- [ ] T-10: 別 context の実行者が、evidence を除いた tree で `<canon-sha>` に対してコマンドを組み立て、ファイル集合を照合する（ME-6。assertion として記録）
  - Owner: agent（別 context、Codex）
  - depends_on: T-09, T-14
  - files: `docs/working/TASK-1408/evidence/independent-rerun.txt`
  - rollback: 不要（検証のみ）
  - 完了条件: ME-1〜5 を固定 SHA で再実行した出力があり、ME-6 の集合が一致。最終 head で manifest の blob SHA と digest が一致
  - 🚩 チェックポイント: 不一致は原因特定まで停止

- [ ] T-11: `sh tests/run-tests.sh` と TC-07, TC-08 を実行する
  - Owner: agent
  - depends_on: T-10
  - files: 読取: `tests/`
  - rollback: 不要（検証のみ）
  - 完了条件: FAIL なし
  - 🚩 チェックポイント: なし

### 4. 完了

- [ ] T-12: `status.md` / `current-state.md` / `INDEX.md` / `handoff.md` を更新する
  - Owner: agent
  - depends_on: T-11
  - files: `docs/working/TASK-1408/*`
  - rollback: 不要（記録のみ）
  - 完了条件: I4 を「Human C-4 待ち」と記録。充足済みと書かない
  - 🚩 チェックポイント: なし

## 👤 Human タスク

- [x] H-00: Q-1〜Q-6 を裁定し、pbi-input.md を確定する
  - Owner: human
  - depends_on: なし
  - files: `pbi-input.md`
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: Q-1 / Q-3 未回答では C-3 へ進めない
- [x] H-04: 失効後差分の別 issue の起票を名指し承認する（Q-1。#1643）
  - Owner: human
  - depends_on: H-00
  - files: GitHub issue
  - rollback: issue の close
  - 🚩 チェックポイント: 番号を §7 と §8 に入れる（TC-11）
- [ ] H-01: **C-3 ゲート**
  - Owner: human
  - depends_on: H-00, C-2 完了
  - files: `docs/working/TASK-1408/approvals/c3.json`
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: AI は c3.json を作らない
- [ ] H-02: Issue コメント（Q-5）を merge 後に名指し承認する
  - Owner: human
  - depends_on: H-03
  - files: GitHub #1329, #1374
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: 名指し承認なしに投稿しない
- [ ] H-03: **C-4 ゲート**（I4 の Human 要素）
  - Owner: human
  - depends_on: T-12
  - files: GitHub PR
  - rollback: `git revert <merge>`（失効の事実は残るため再記録が要る）
  - 🚩 チェックポイント: merge は Human-owned

## ⚠️ 依存関係

| タスク | depends_on | 種別 | 備考 |
| --- | --- | --- | --- |
| repo への本書配置 | `PLANGATE_HOOK_TASK=TASK-1408` 起動 | Human → Agent | plan.md は EH-3 の block 対象 |
| T-01 | H-01 | Human → Agent | C-3 前に実装しない |
