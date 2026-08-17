---
name: plan-review-gate
description: "PlanGate の C-1 / C-2 / C-3 ゲートを確認し、exec 開始可否を判定する。Use when: plan レビュー通過済みか確認したい時、c3.json を発行したい時。"
---

# Plan Review Gate (PlanGate / Codex 共用)

PlanGate の **plan ゲート（C-1 セルフレビュー / C-2 外部レビュー / C-3 人間承認）** を確認する skill。EH-3（plan_hash 改竄検知）と整合する手順順序を担保する。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（C-1 / C-3 三値ゲート / 条件付き降格 / settings タスクロック の正本）
4. `.claude/rules/review-principles.md`（5 観点 / Severity / C-2 2 レーン責務契約の正本）
5. `.claude/rules/mode-classification.md`（mode 別フェーズ適用マトリクス）
6. `docs/working/TASK-XXXX/plan.md`
7. `docs/working/TASK-XXXX/review-self.md`（C-1）
8. `docs/working/TASK-XXXX/review-external.md`（C-2、存在すれば）
9. `docs/working/TASK-XXXX/approvals/c3.json`（存在すれば）

## C-1 セルフレビュー

チェック項目の定義と項目数は `docs/working/templates/review-self.md` を正本とする（現行 全 25 項目）。mode に応じた適用範囲は `.claude/rules/working-context.md` の C-1 節および `.claude/rules/mode-classification.md` フェーズ適用マトリクスを正本とする。FAIL があれば修正後再実行。evidence は FAIL 時必須（`evidence/c1-review/`）。

## C-2 外部レビュー

- 2 レーン責務（設計妥当性 / コードベース整合）と R-NNN 採番・追記専用集約の規約は `.claude/rules/review-principles.md` §7-bis を正本とする
- 実行コマンド: `bin/plangate review TASK-XXXX --phase c2`（外部 AI モデル呼び出し）
- 指摘ゼロでも「指摘なし」を明示記録

## C-2 → 確定反映 → c3.json 発行（EH-3 整合・厳守順序）

1. R-NNN を `review-external.md` に集約（追記専用）
2. 1 回確定反映（plan/todo/test-cases へ反映、コミットメッセージに `Refs: R-NNN`）
3. 簡易 C-1 再実行
4. **人間が APPROVED c3.json 発行**（確定後 plan の `plan_hash: sha256:...` を含む）
5. exec 開始

> ⚠️ **c3.json 発行は確定反映の後**。順序を逆にすると EH-3 が plan_hash mismatch で block する。

## C-3 三値判定

詳細は `.claude/rules/working-context.md` の C-3 ゲート節と条件付き降格節を正本とする。`bin/plangate exec` は APPROVED の c3.json のみ受理。

## settings タスクロック

`bin/plangate doctor --check-settings` PASS は **V-1 / handoff 完了の前提条件**（`.claude/rules/working-context.md` 正本）。plan ゲート段階での block 対象ではないが、未配線なら verify フェーズ前に Human が `sh scripts/apply-claude-settings.sh` 実行が必要なことを認識しておく。

## CLI 呼び出し

- 機械検証（plan_hash / artifact 整合）: `bin/plangate validate TASK-XXXX`
- C-2 / V-3 外部 AI レビュー: `bin/plangate review TASK-XXXX --phase {c2|v3}`
- gate 通過判定（artifact チェック）: `./scripts/ai-dev-workflow TASK-XXXX gate`

> ⚠️ **`bin/plangate review` は外部 AI モデル（gemini/codex 等）を呼び出す**。C-1 セルフレビュー目的で誤起動するとコスト発生・機密送信のリスクがある。C-1 は本 skill の手順に従い手動で実施する。

## 判定

1 つでも未充足なら exec を始めない。不明点があれば status.md に追記候補を示す。
