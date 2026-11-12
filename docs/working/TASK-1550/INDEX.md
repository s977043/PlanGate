# TASK-1550 INDEX

> 最終更新: 2026-11-02 12:06
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」

## チケット概要

AI が PR 本文を組み立てる主経路（`pr-decision` Skill）に、`.github/PULL_REQUEST_TEMPLATE.md` の Rollback / Detection 3 要素を参照で届ける。テンプレート（#1547、merge 済み）だけでは直近 30 件中 5 件しか見出しを持たない。

## 現在のフェーズ

BLOCKED

- blocker / owner / unblock_condition は [status.md](./status.md) を正本とする（plan.md の v0.2 反映待ち。owner: human）
- C-1 判定: **FAIL**（critical=0, major=1, minor=3。[review-self.md](./review-self.md) の判定語を転記）
- C-2: 未実施（todo D-02 / D-03）
- C-3: 未承認（`approvals/c3.json` なし）

## 次のアクション

Human が `PLANGATE_HOOK_TASK=TASK-1550` でセッションを起動 → plan.md を v0.2 に置換（D-01b）→ C-1 再実施 → C-2 R1 / R2 → Human C-3（同期）。

## ファイルマップ

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| status.md | 全 | フェーズ履歴・blocker・未決事項 |
| current-state.md | 全 | 現在地 |
| pbi-input.md | plan, review | 要件・AC-01〜06 |
| plan.md | exec, review | **v0.1 のまま**（v0.2 は draft PR 本文） |
| todo.md | exec | タスク・依存・rollback |
| test-cases.md | exec, review | TC-01〜TC-10 |
| review-self.md | C-3, review | C-1 結果 |
| decision-log.jsonl | 振返り | **未作成**（EH-3 block。D-001〜D-004 は draft PR 本文） |

## 変更ファイル一覧（予定・Phase 1）

`.agents/skills/pr-decision/SKILL.md`、ミラー 2 か所（sync スクリプトで再生成）、`tests/` の fixture 1〜2、任意で `docs/ai/github-account-pinning.md`。Phase 2（HO・Human 適用・任意）: `.claude/agents/workflow-conductor.md`。
