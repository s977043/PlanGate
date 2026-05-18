# Reporting & Retrospective v1（正本）

> PlanGate の実利用シグナル（C-3/C-4/V-1/fix loop/hook violation/Keep Rate/
> latency）を **期間指定**で集計し、sprint retrospective に貼れる Markdown を
> 生成する正本。決定論・ローカル artifact のみ。
> 関連: [#200](https://github.com/s977043/plangate/issues/200)（PBI-HI-006）/
> TASK-0098 / [`metrics.md`](./metrics.md) / [`eval-runner.md`](./eval-runner.md) /
> [`keep-rate.md`](./keep-rate.md)（#198・任意入力）/ EPIC #193

## 1. 目的と原則

Metrics v1 / Eval comparison / Keep Rate / Dynamic Context が揃っても、
結果が retrospective → 次改善 PBI に変換されなければ継続運用にならない。
本機能は期間集計レポートでその橋渡しをする。

- **advisory のみ**: C-3/C-4 を緩和しない・LLM judge を hard gate にしない
  （#200 Non-goal・[responsibility-classes.md](../../.claude/rules/responsibility-classes.md)
  承認境界不変）。
- **決定論・ローカル**: Web dashboard / 外部 BI / Slack・Discussions 自動
  投稿はしない（Non-goal）。`docs/working/TASK-*/` の artifact のみ集計。
- 算出不能は `unknown`（0 と区別）。

## 2. 集計ソースと期間

| ソース | 取得項目 |
|--------|---------|
| `approvals/c3.json` | c3_status（APPROVED/CONDITIONAL/REJECTED）, approved_at（期間判定キー）|
| `approvals/c4-approval.json` | c4_status（APPROVED/REQUEST_CHANGES/REJECTED）|
| `eval-result.json` | ac_coverage / release_blocker_violations / latency_cost |
| `keep-rate-result.json` | code/plan keep rate（**#198 / PR #272 提供。無ければ `-`**）|
| `status.md` | fix loop 回数 / V-1 first pass（ヒューリスティック）|

期間は `c3.json` の `approved_at` が `--from`〜`--to`（YYYY-MM-DD・両端含む）
に入る TASK を対象とする。

## 3. Report items

| Item | 意味 |
|------|------|
| C-3 approved/conditional/rejected | plan 品質 |
| C-4 approved/request_changes/rejected | exec 品質 |
| V-1 first pass rate | 実装・受入条件の一致度（status.md 由来・近似）|
| fix loop max | 自己修正効率（1-2桁・日付除外・上限50）|
| hook violation | ガードレール違反（_audit/hook-events.log の VIOLATION を期間集計・hook 別）|
| release blocker total | ガードレール違反傾向 |
| Keep Rate (code/plan) | AI 成果物の実採用度（#198 入力時）|
| latency / cost | 運用効率（eval-result 由来）|

## 4. 使い方

```sh
sh bin/plangate report --from 2026-05-01 --to 2026-05-31
# → docs/working/_reports/report-2026-05-01_2026-05-31.{md,json}
sh bin/plangate report --from 2026-05-01 --to 2026-05-31 --no-write  # 標準出力
```

`--from`/`--to` は `YYYY-MM-DD`。`from > to` はエラー（exit 2）。

## 4-bis. 精度オプション（#281 / opt-in・behavior-preserving）

dogfooding 振り返りで顕在化した精度限界への opt-in 改善。**いずれも未指定
時は従来挙動と完全等価**（behavior-preserving）。

### `--exclude-test-hooks`

hook violation 集計から **test/dev 由来行を構造化判定で除外**する。
判定軸（雑な文字列一致でなく構造化キー）:

- `hook-events.log` の task 列が `TASK-HOOKTEST` プレフィックス → 除外
- task 列が `tests/fixtures/` を含むパス → 除外
- `-`（TASK 文脈なし）等の曖昧行は **除外しない**（実 violation を隠さない）

```sh
sh bin/plangate report --from 2026-05-01 --to 2026-05-31 --exclude-test-hooks
```

### `--tasks <TASK-id,...>`（run スコープ）

集計対象を指定 TASK 集合に限定（= 1 run の TASK セット単位の集計）。
period 窓は維持したうえで対象 TASK を絞る追加条件。未指定時は全 TASK
（従来挙動）。空指定（`""` / `","`）は exit 2。

**run スコープ時の hook violation**: `--tasks` 指定時は hook violation 集計も
対象 TASK セットの行のみに限定する（`-`＝TASK 文脈なし・fixtures パス等は
run 外として除外）。これにより `task_count` と hook violation のスコープが
一致する（#281 V-3 MJ-1）。

```sh
sh bin/plangate report --from 2026-05-01 --to 2026-05-31 --tasks TASK-0102,TASK-0101
```

> 真の run-id（イベント単位の run 識別）スコープには run_id インフラ新設が
> 必要で本 PBI の Out-of-scope（#281）。本オプションは run=TASK セットの
> 軽量近似であり、run_id 化は将来課題。

## 5. retrospective への接続

1. `bin/plangate report` を sprint 期間で実行。
2. `docs/working/_reports/report-*.md` を
   [`docs/working/templates/retrospective-template.md`](../working/templates/retrospective-template.md)
   §1 に貼付。
3. テンプレ §3「AI harness improvement 用の問い」に沿って KPT を記入。
4. レポート末尾の **次の harness improvement PBI 候補（抽出指針）** から
   1〜3 件を人間が EPIC #193 配下で起票判断（advisory）。

## 6. 次の harness improvement PBI 候補 抽出方針

| シグナル | 候補 PBI 方向 |
|---------|--------------|
| C-3 CONDITIONAL/REJECTED 多 | plan 品質強化（Plan Quality Checks #213）|
| C-4 REQUEST_CHANGES 多 | exec/レビュー観点の PBI |
| V-1 first pass rate 低 | test-cases 精度 / exec 手順 PBI |
| fix loop max 高 | fix loop 上限 / EHS-3 escalation 見直し |
| release blocker total 増 | 該当 aspect の Gate / tool-error-taxonomy 強化 |
| Keep Rate 低 | 採用されない成果物パターンの retro PBI |

抽出は **advisory**。PBI 化は人間判断（[issue-governance.md](./issue-governance.md)
に従い起票）。

## 7. Non-goals

- Web dashboard / 外部 BI ツール連携
- Slack / GitHub Discussions への自動投稿
- LLM judge を hard gate にすること / C-3 / C-4 gate の緩和

## 8. 関連

- [`metrics.md`](./metrics.md) — Metrics v1（PBI-HI-001）
- [`eval-runner.md`](./eval-runner.md) — eval-result（PBI-HI-002）
- [`keep-rate.md`](./keep-rate.md) — Keep Rate（#198・任意入力）
- [`docs/working/templates/retrospective-template.md`](../working/templates/retrospective-template.md)
- [`harness-improvement-roadmap.md`](./harness-improvement-roadmap.md) — EPIC #193 Phase 6
