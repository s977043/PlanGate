# TASK-1550 INDEX

> 最終更新: 2026-10-11 14:46
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

実際に使われている PR 本文の自動生成経路 1 つに、Rollback / Detection の 3 要素（Kill-switch・Detection signal・Observation window）を届ける。テンプレート（PR #1547）を置いただけでは生成 PR に反映されないため、稼働経路を証跡で特定してから最小差分で入れる。

## 現在のフェーズ

BLOCKED

- blocker: U-01（稼働中の PR 本文生成経路の実行証跡が未取得）/ U-02（変更対象ファイルと HO 該当の有無が未確定）。
- unblock_condition: D-01 で run ID と `gh pr create` 分岐到達を記録し、D-03 で対象 1 経路と files / fixtures を確定する。詳細は [plan.md](./plan.md) の Readiness と [pbi-input.md](./pbi-input.md) の Execution Readiness。
- C-1 判定: **FAIL**（critical=0, major=2, minor=0。[review-self.md](./review-self.md) の判定語を転記）
- C-2: 未実施（R1 / R2 を todo の D-05 / D-06 に計画）
- C-3: 未承認（`approvals/c3.json` なし）

## 次のアクション

plan.md に「Mode判定」節を追加（R-1553-01 の残り。`PLANGATE_HOOK_TASK=TASK-1550` のセッションで行う）→ D-01（稼働経路の実行証跡）→ D-02（#1547 の採用状態）→ D-03（対象 1 経路の確定）→ C-1 再実施 → C-2 R1 / R2 → Human C-3。

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・受入基準（AC-01〜AC-07） |
| plan.md | exec, review | 実行計画（Draft / C-3 未承認） |
| todo.md | exec | タスク一覧・依存・rollback |
| test-cases.md | exec, review | テストケース定義（TC-01〜TC-10、Not run） |
| review-self.md | C-3, review | C-1 結果 |

## 変更ファイル一覧（概要）

未確定（U-02）。候補は稼働が確認された PR 本文生成経路 1 つと、その fixture / test。HO 対象（`.github/workflows/*.yml` / `.claude/agents/*.md`）なら Human 向け apply patch に分離する。
