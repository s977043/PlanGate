# TASK-1197 EXECUTION TODO（C-3 CONDITIONAL / c3.json 未発行）

## Mode

**モード**: critical

## 🤖 Agent タスク

### 1. 準備

- [ ] T-01: `git fetch` 後、origin/main の hook と ta 最大番号を再測定し、open PR の重複を確認する
  - Owner: agent
  - depends_on: H-01
  - files: 読取: `scripts/hooks/check-plan-hash.sh`, `tests/extras/`
  - rollback: 不要（読取のみ）
  - 完了条件: base SHA、ta-NN、実 repo の `rev-list --reflog` 所要時間を status.md に記録
  - 🚩 チェックポイント: hook が 9445df17 から変わっていたら patch 前に plan と照合

- [ ] T-02: H-02 の後に、適用した checkout で `PLANGATE_HOOK_TASK` なしで再起動したセッションから、未作成の検証用 TASK へ実 Write を 1 回行い `PLAN_CREATE_ALLOW` を確認する
  - Owner: agent
  - depends_on: H-02
  - files: 検証用 plan.md と `evidence/verification/`。確認後に検証用 plan.md を消す
  - rollback: 検証用 TASK ディレクトリの削除
  - 完了条件: 実測結果を evidence に保存。記録されなければ Replan
  - 🚩 チェックポイント: Replan Trigger 判定

### 2. 実装

- [ ] T-03: ta-NN の sandbox helper（`git init` + linked worktree、mktemp 配下のみ）を書く
  - Owner: agent
  - depends_on: T-01
  - files: `tests/extras/ta-NN-eh3-plan-create.sh`
  - rollback: `git rm tests/extras/ta-NN-eh3-plan-create.sh`
  - 完了条件: sandbox 生成と hook 発火の前提 assert が通る
  - 🚩 チェックポイント: なし

- [ ] T-04: TC-01〜TC-17（08b〜08g、11b を含む）と TC-E01〜E09 を追加し、未 patch hook で許可ケースの RED を確認する
  - Owner: agent
  - depends_on: T-03
  - files: `tests/extras/ta-NN-eh3-plan-create.sh`, `tests/fixtures/eh3-plan-create-pending-1197.flag`
  - rollback: `git revert <commit>`
  - 完了条件: 許可ケースが rc=2、block ケースが rc=2 と観測
  - 🚩 チェックポイント: RED ログを evidence に保存

- [ ] T-05: ta-79 を patched 複製で実走し、変更が不要であることを確認する
  - Owner: agent
  - depends_on: T-06
  - files: 読取: `tests/extras/ta-79-eh3-bash-lane.sh`
  - rollback: 不要（検証のみ）
  - 完了条件: 未 patch / patched の両方で ta-79 に FAIL なし
  - 🚩 チェックポイント: FAIL が出て既存 TC の変更が必要なら Replan

- [ ] T-06: 判定 patch を worktree の複製で実編集し、patch 文書へ `PG-PATCH` で収録する
  - Owner: agent
  - depends_on: T-04
  - files: `docs/working/_reports/1197-eh3-plan-create-patch.md`（HO 本体は編集しない）
  - rollback: `git rm docs/working/_reports/1197-eh3-plan-create-patch.md`
  - 完了条件: 複製への実適用で offset なし、TC GREEN
  - 🚩 チェックポイント: patch R1 敵対レビュー

- [ ] T-07: ta-NN に patched 複製レーンと変異 M1〜M12、M13a〜c、M14〜M18 を追加する
  - Owner: agent
  - depends_on: T-06
  - files: `tests/extras/ta-NN-eh3-plan-create.sh`
  - rollback: `git revert <commit>`
  - 完了条件: 全変異が対応 TC を FAIL させる（call site を壊す）
  - 🚩 チェックポイント: 未検出が 1 つでもあれば Replan

- [ ] T-08: 適用スクリプトを `ho-apply-script` の型で書く
  - Owner: agent
  - depends_on: T-06
  - files: `scripts/apply-eh3-plan-create-1197.sh`
  - rollback: `git rm scripts/apply-eh3-plan-create-1197.sh`
  - 完了条件: Skill の Checklist 全項目を確認
  - 🚩 チェックポイント: なし

- [ ] T-09: 適用スクリプトを複製のみで 4 モード実走する（実 repo では実行しない）
  - Owner: agent
  - depends_on: T-08
  - files: `PLANGATE_APPLY_REPO` の複製のみ。ログは evidence
  - rollback: 不要（複製のみ）
  - 完了条件: `--rollback` 後に対象の `git status --porcelain` が 0 行
  - 🚩 チェックポイント: なし

- [ ] T-10: rollout-policy に起動条件、no-task 挙動、迂回禁止を追記する
  - Owner: agent
  - depends_on: H-01
  - files: `docs/workflows/ai-loop/rollout-policy.md`
  - rollback: `git checkout origin/main -- docs/workflows/ai-loop/rollout-policy.md`
  - 完了条件: TC-D01〜D03 PASS。§4〜§6 の既存条件の削除なし
  - 🚩 チェックポイント: なし

- [ ] T-11: SKILL.md 前提節へ 1 行追記し、派生を同期する（Q-5 の裁定に従う）
  - Owner: agent
  - depends_on: T-10
  - files: `.claude/skills/ai-loop-cycle/SKILL.md`, `.agents/skills/ai-loop-cycle/SKILL.md`, `.codex/skills/ai-loop-cycle/SKILL.md`, `plugin/plangate/skills/ai-loop-cycle/SKILL.md`
  - rollback: 4 ファイルを `git checkout origin/main --`
  - 完了条件: drift チェックに差分なし
  - 🚩 チェックポイント: 差分が他へ及べば Replan

- [ ] T-12: hook-enforcement.md の EH-3 節へ許可経路と残存脅威を追記する
  - Owner: agent
  - depends_on: T-06
  - files: `docs/ai/hook-enforcement.md`
  - rollback: `git checkout origin/main -- docs/ai/hook-enforcement.md`
  - 完了条件: TC-D03 PASS。「Human 適用待ち」を明記
  - 🚩 チェックポイント: なし

### 3. 検証

- [ ] T-13: `sh tests/run-tests.sh` を実行し、ta-39 / 65 / 79 / 80 の結果を個別確認する
  - Owner: agent
  - depends_on: T-07, T-09, T-11, T-12
  - files: 読取: `tests/`
  - rollback: 不要（検証のみ）
  - 完了条件: FAIL なし。全文ログ保存
  - 🚩 チェックポイント: なし

- [ ] T-14: 許可経路の実行時間と非 plan 経路の fork 増加を測定する
  - Owner: agent
  - depends_on: T-13
  - files: `evidence/verification/`
  - rollback: 不要（検証のみ）
  - 完了条件: 測定値と環境を記録
  - 🚩 チェックポイント: ハングや合意値超過で Replan

### 4. 完了

- [ ] T-15: `status.md` / `current-state.md` / `INDEX.md` を更新し、`--verify` の手順と Human 手順を 1 本で提示する
  - Owner: agent
  - depends_on: T-14
  - files: `docs/working/TASK-1197/status.md`, `current-state.md`, `INDEX.md`
  - rollback: 不要（記録のみ）
  - 完了条件: 再起動を含む手順が 1 本になっている。適用先は hook が動く起動 checkout（`${CLAUDE_PROJECT_DIR}`）で、適用後に `PLANGATE_HOOK_TASK` なしで再起動すると明記する。handoff は WF-05 で発行する
  - 🚩 チェックポイント: なし

## 👤 Human タスク

- [x] H-00: Q-1〜Q-5 を裁定し、pbi-input.md を確定する
  - Owner: human
  - depends_on: なし
  - files: `pbi-input.md`
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: Q-1 / Q-2 未回答では C-3 へ進めない
- [ ] H-01: **C-3 ゲート**（同期固定）
  - Owner: human
  - depends_on: H-00, C-2 完了
  - files: `docs/working/TASK-1197/approvals/c3.json`
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: APPROVED まで exec しない。AI は c3.json を作らない
- [ ] H-02: 適用スクリプトを feature ブランチで実行し、`--verify` 後に pending flag を削除して commit する
  - Owner: human
  - depends_on: T-15
  - files: `scripts/hooks/check-plan-hash.sh`, `tests/fixtures/eh3-plan-create-pending-1197.flag`
  - rollback: `sh scripts/apply-eh3-plan-create-1197.sh --rollback`
  - 🚩 チェックポイント: AI は実行しない
- [ ] H-03: **C-4 ゲート**
  - Owner: human
  - depends_on: H-02, T-02
  - files: GitHub PR
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: merge は Human-owned

## ⚠️ 依存関係

| タスク | depends_on | 種別 | 備考 |
| --- | --- | --- | --- |
| repo への本書配置 | Human の `PLANGATE_HOOK_TASK=TASK-1197` 起動 | Human → Agent | 本 TASK の plan.md 自身が EH-3 に block される |
| T-01 | H-01 | Human → Agent | C-3 前に実装しない |
| H-02 | T-15 | Agent → Human | HO 適用 |
| T-02 | H-02 | Human → Agent | 実 payload の測定 |
| H-03 | T-02 | Agent → Human | 未測定または Replan 発火のまま C-4 に進まない |
