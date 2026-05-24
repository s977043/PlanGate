---
name: plan-review-gate
description: "PlanGate の C-1 / C-2 / C-3 ゲートを確認し、exec 開始可否を判定する。Use when: plan レビュー通過済みか確認したい時、c3.json を発行したい時。"
---

# Plan Review Gate (PlanGate / Codex 共用)

PlanGate の **plan ゲート（C-1 セルフレビュー / C-2 外部レビュー / C-3 人間承認）** を確認する skill。EH-3（plan_hash 改竄検知）と整合する手順順序を担保する。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（C-3 三値ゲート / 条件付き降格 / settings タスクロック）
4. `.claude/rules/review-principles.md`（5 観点 / Severity / C-2 2 レーン責務契約）
5. `.claude/rules/mode-classification.md`（mode 別フェーズ適用マトリクス）
6. `docs/working/TASK-XXXX/plan.md`
7. `docs/working/TASK-XXXX/review-self.md`（C-1）
8. `docs/working/TASK-XXXX/review-external.md`（C-2、存在すれば）
9. `docs/working/TASK-XXXX/approvals/c3.json`（存在すれば）
10. `docs/working/TASK-XXXX/status.md`

## C-1 セルフレビュー（17 項目）

mode に応じて適用範囲を切り替える（mode-classification.md フェーズ適用マトリクス）:

- **ultra-light**: スキップ
- **light**: Plan 7 項目（C1-PLAN-01〜07）のみ
- **standard 以上**: 17 項目（Plan 7 + ToDo 5 + TestCases 3 + 結合 2）

判定: PASS / WARN / FAIL。FAIL があれば plan/todo/test-cases を修正し再実行。evidence は FAIL 時必須（`evidence/c1-review/`）。

## C-2 外部レビュー（2 レーン責務）

- **設計妥当性レーン**: plan/todo/test-cases/pbi-input を読む。実装コードは原則読まない。
- **コードベース整合レーン**: 既存パターン該当箇所のみ。1 エージェントに集約。
- 指摘は **R-NNN** 採番で `review-external.md` に追記専用集約。指摘ゼロでも「指摘なし」を明示記録。
- 実装詳細レビューは V-3 に寄せる（plan 段階の二重精読を解消）。

## C-2 → 確定反映 → c3.json 発行（EH-3 整合・厳守順序）

1. **R-NNN を review-external.md に集約**（追記専用）
2. **1 回確定反映**（plan/todo/test-cases へ反映。コミットメッセージに `Refs: R-NNN`）
3. **簡易 C-1 再実行**（反映分のみ）
4. **人間が APPROVED c3.json 発行**（確定後 plan の `plan_hash: sha256:...` を含む）
5. **exec 開始**（`bin/plangate exec` は APPROVED のみ受理）

> ⚠️ **c3.json 発行は確定反映の後**。順序を逆にすると EH-3 が plan_hash mismatch で block する。

## C-3 三値判定

- **APPROVE**: status.md に `## C-3 Gate: APPROVED` 記録 + c3.json 発行 → exec
- **CONDITIONAL**: R-NNN 反映 → 簡易 C-1 → c3.json APPROVED 発行 → exec
- **REJECT**: plan 再生成

## C-3 条件付き降格（opt-in・既定 OFF）

`C-1 PASS` & `C-2 critical/major=0` & `lite_eligible=true` がすべて満たされる場合のみ非同期降格候補。判定不能なら必ず同期（AC-8 安全側）。`critical` mode は原則 `lite_eligible=false`（AC-11）。Hardening Override（settings / 責務 4 分類 / Critical Infra）抵触時は Standard・同期を強制（AC-10）。

## settings タスクロック

V-1 / handoff 完了の前提条件として `bin/plangate doctor --check-settings` PASS を要求。未配線時は **Shadow Configuration 防止**のため C-3 通過していても完了扱いにしない。settings 適用は Human-owned（AI 不可）。

## CLI 呼び出し

- C-1 セルフレビュー実行: `bin/plangate review TASK-XXXX` 相当
- 最終判定の機械検証: `bin/plangate gate TASK-XXXX` 相当

## 判定

1 つでも未充足なら exec を始めない。不明点があれば status.md に追記候補を示す。
