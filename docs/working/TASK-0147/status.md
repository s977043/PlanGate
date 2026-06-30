# TASK-0147 作業ステータス — validation_bias conductor export（#527 follow-up）

## モード判定

**high-risk**（`bin/plangate` + `.claude/agents/workflow-conductor.md` = HO パス 2 種）/ `lite_eligible=false`

## C-3 Gate: APPROVED

- ユーザー明示承認（2026-06-27）: 「TASK-0147 を C-3 承認して実装を進めて」
- 記録: `approvals/c3.json`（`c3_status=APPROVED`, plan_hash 記載）
- HO のため autonomous APPROVE 不可 → **人間 C-3 として成立**

## 全体構成（PR 一覧）

| ブランチ | 状態 | 内容 |
|---------|------|------|
| `feat/task-0147-validation-bias-export` | PR 作成予定 | helper + apply-script + test（HO 本体は Human 適用） |

## 実装内容（AI-owned）

- `scripts/_resolve_validation_bias.py`: profile key → `validation_bias` 解決。未知 key / yaml 欠落・破損 / pyyaml 未導入は **normal fallback + stderr 警告**（サイレント失敗防止）。
- `scripts/apply-task-0147-bias-export.sh` + `_apply_task_0147_patches.py`: HO apply（文字列アンカー・dry-run/--apply）。3 patch:
  1. `cmd_verify` に `--profile` 解析 + bias export（env 既設定尊重）
  2. `cmd_handoff` に `--profile` 解析 + bias export
  3. `workflow-conductor.md` に profile→bias 運用の**非強制の補足**追記
- `tests/extras/ta-49-bias-export.sh`: 層A（helper 機能・常時実行）+ 層B（bin/plangate 配線・未適用 SKIP）

## 検証結果

- helper 単体: strict profile (`gpt-5_5_pro`)→strict / normal→normal / 未知 key・yaml 欠落→normal+stderr 警告
- ta-49 未適用ツリー: 層A 4 PASS / 層B SKIP
- **sandbox 適用**: 3 patch 命中・`sh -n` OK・ta-49 TC-01〜06 **全 PASS**・conductor 非強制明記・統合解決 OK（実ツリー HO 非改変）
- `sh tests/run-tests.sh`: **363 passed / 0 failed**

## 残タスク

- [x] helper / apply-script / test 実装
- [x] sandbox 適用検証（全 PASS）
- [x] C-3 承認記録
- [ ] PR 作成（C-4 ゲート）
- [ ] 👤 apply-script 適用（`--apply`、PR マージ後）
- [ ] hook-enforcement.md の follow-up 記述を「配線済み」へ更新（適用後・別 PR 可）

## フェーズ履歴

- 2026-06-27 C-3 APPROVED（人間）→ 実装 → sandbox 検証 → PR 作成

## 参照ファイル

- `docs/working/TASK-0147/plan.md` / `todo.md` / `test-cases.md` / `handoff.md`
- `scripts/_resolve_validation_bias.py` / `scripts/apply-task-0147-bias-export.sh`
