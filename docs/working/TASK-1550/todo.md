# TASK-1550 — Work Breakdown (no C-3 approval yet)

## Investigation / Review (allowed before C-3)

- [x] D-00: 既存PR #1547とIssue #1550、mainのCore Contract / mode-classification / responsibility-classesを照合。**計画の根拠としてのみ**記録。
- [x] D-00b: `workflow-conductor`のHO分類と、`ai-dev-exec`がPR本文ownerでないことを確認。
- [ ] D-01: `.github/workflows/sync-plugin-plangate.yml` の設定済みcaller→bodyは確認済み。次は**実runと生成PR**、通常Claude/Codex経路の稼働証拠を固定（候補ファイルの存在だけでは不可）。
- [ ] D-02: #1547のHuman C-4/mergeとmainの採用状態を再確認。
- [ ] D-03: 対象1経路とfiles / fixturesを決定。HOと判明したらHuman apply patchへ分離。
- [ ] D-04: C-1/C-2相当レビュー、negative-control点検。未解決の重要UnknownをC-3へ渡す。

## Execution (blocked until Human C-3)

- [ ] H-01 (human): 対象パス・実装計画・テスト・HOを明示C-3承認する。**現状未承認**。
- [ ] T-01: fixture/testを先行し、期待されたFailure/Evidenceを記録。depends_on: H-01, D-03。
- [ ] T-02: 1つの稼働PR body経路へ最小導入。depends_on: T-01。
- [ ] T-03: 既存CI/negativeテスト/配布整合を再検証。depends_on: T-02。
- [ ] T-04: 独立レビュー→指摘修正→再レビュー。depends_on: T-03。
- [ ] H-02 (human): C-4レビューとmergeの実施。depends_on: T-04。
- [ ] O-01: 実PR採用状況の観測・revert基準評価。depends_on: H-02。

## Stop Conditions

- HOパスへの無承認編集、生成経路の未確認、C-3未承認、scope横断、Issueリンク破損、PR本文に根拠のない成功主張があれば、実装タスクは開始/継続しない。

## Rollback

- Docs-only planning artifact: このPR単位でrevert可能。
- Runtime/HO patch: Human承認を取得したPlanの単位でrevert。権限変更や設定適用はHuman-owned。
