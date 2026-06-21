---
name: plan-review-gate
description: "PlanGate の C-1 / C-2 / C-3 ゲートを確認し、exec 開始可否を判定する。Use when: plan レビュー通過済みか確認したい時、c3.json を発行したい時。"
---

# Plan Review Gate (PlanGate / Codex 共用)

PlanGate の **plan ゲート（C-1 セルフレビュー / C-2 外部レビュー / C-3 人間承認）** を確認する skill。EH-3（plan_hash 改竄検知）と整合する手順順序を担保する。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（C-1 17 項目 / C-3 三値ゲート / 条件付き降格 / settings タスクロック の正本）
4. `.claude/rules/review-principles.md`（5 観点 / Severity / C-2 2 レーン責務契約の正本）
5. `.claude/rules/mode-classification.md`（mode 別フェーズ適用マトリクス）
6. `docs/working/TASK-XXXX/plan.md`
7. `docs/working/TASK-XXXX/review-self.md`（C-1）
8. `docs/working/TASK-XXXX/review-external.md`（C-2、存在すれば）
9. `docs/working/TASK-XXXX/approvals/c3.json`（存在すれば）

## C-1 セルフレビュー

mode に応じた適用範囲・項目数（17 項目構成）は `.claude/rules/working-context.md` の C-1 節および `.claude/rules/mode-classification.md` フェーズ適用マトリクスを正本とする。FAIL があれば修正後再実行。evidence は FAIL 時必須（`evidence/c1-review/`）。

### C-1 追加品質ゲート: Plan 実行可能性

Superpowers の `writing-plans` から取り込む観点。ここでは Superpowers を依存として導入せず、PlanGate の C-1 に **plan を実行可能な作業指示書として読めるか** を確認する観点だけを吸収する。

#### Task Sizing Rules

各 Task / Step は以下を満たすこと。

- 独立して検証可能な成果物を持つ
- reviewer が単独で approve / reject できる粒度である
- setup / config / docs は、それを必要とする成果物の Task に含める
- 1 Task に複数の責務を詰め込まない
- Task 間の依存関係・公開インターフェース・順序制約が明示されている
- 変更対象ファイル、検証コマンド、期待結果が具体的に書かれている

#### No Placeholders Rule

以下が `plan.md` / `todo.md` / `test-cases.md` / `design.md` に残っている場合は C-1 FAIL として扱う。

- `TBD`
- `TODO`（未解決の実装TODO。チェックリスト用途は除く）
- `後で実装`
- `必要に応じて`
- `適切に`
- `いい感じに`
- `エラーハンドリングを追加` だけで具体的な失敗条件・期待挙動がない
- `テストを書く` だけで具体的な入力・期待値・検証コマンドがない
- `Task N と同様` だけで、当該 Task 単独で実行できない
- 未定義の関数名・型名・ファイルパス・コマンドを参照している

#### 判定

- `ultra-light` / `light`: 不備は WARN 可。ただし exec に必要なファイル・検証コマンドが欠ける場合は FAIL。
- `standard`: Task Sizing / No Placeholders の重大不備は FAIL。
- `high-risk` / `critical`: Task Sizing / No Placeholders の不備は FAIL。C-3 承認前に必ず修正する。

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
