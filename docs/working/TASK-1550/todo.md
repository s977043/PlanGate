# TASK-1550 — Work Breakdown (no C-3 approval yet)

## Investigation / Review (allowed before C-3)

- [x] D-00: 既存PR #1547とIssue #1550、mainのCore Contract / mode-classification / responsibility-classesを照合。**計画の根拠としてのみ**記録。
- [x] D-00b: `workflow-conductor`のHO分類と、`ai-dev-exec`がPR本文ownerでないことを確認。
- [ ] D-01: `.github/workflows/sync-plugin-plangate.yml` の設定済みcaller→bodyは確認済み。次は**実runと生成PR**、通常Claude/Codex経路の稼働証拠を固定（候補ファイルの存在だけでは不可）。証跡として run ID と、job 内の `gh pr create` 分岐に到達したかを記録する。
- [ ] D-02: #1547のHuman C-4/mergeとmainの採用状態を再確認。
- [ ] D-03: 対象1経路とfiles / fixturesを決定。HOと判明したらHuman apply patchへ分離。depends_on: D-01, D-02。
- [x] D-04: C-1（テンプレート準拠・[review-self.md](./review-self.md)）を実施。判定は同ファイルのとおり（FAIL を含む。D-01/D-03 後に再実施する）。
- [ ] D-05: C-2 R1（[review-principles §7-quater](../../../.claude/rules/review-principles.md)）。設計妥当性レーン + コードベース整合レーンで plan / todo / test-cases を外部レビューし、指摘を `review-external.md` に `R-NNN` で追記集約、回避クラス台帳を作る。negative-control の点検を含む。depends_on: D-03, D-04（D-03 後の C-1 再実施）。
- [ ] D-06: C-2 R2。新しい穴ではなく **R1 の是正そのもの**を疑う（是正が効いていない別経路 / 是正で生まれた穴 / fail-closed 化が正常系を壊していないか）。収束判定は「新しい回避クラス / 失敗クラスが出なくなったか」とし、指摘ゼロを条件にしない。新クラスが出たら塞いで台帳に追記し、次ラウンドを行う。打ち切り時は残存脅威モデルを書く。未解決の重要UnknownをC-3へ渡す。depends_on: D-05。

## Execution (blocked until Human C-3)

- [ ] H-01 (human): 対象パス・実装計画・テスト・HOを明示C-3承認する。**現状未承認**。depends_on: D-06。
- [ ] T-01: fixture/testを先行し、期待されたFailure/Evidenceを記録。depends_on: H-01, D-03。
  - rollback: T-01 の commit を `git revert` する（本体未変更のため、追加した fixture/test が消えるだけ）。
- [ ] T-02: 1つの稼働PR body経路へ最小導入。depends_on: T-01。
  - rollback: T-02 の commit を `git revert` する。対象が HO パスの場合は、AI は revert patch の作成までとし、逆適用は Human が行う（Human-owned）。
- [ ] T-03: 既存CI/negativeテスト/配布整合を再検証。depends_on: T-02。
  - rollback: 不要（検証のみ。検証記録の追記は commit 単位で `git revert` できる）。配布物に差分が出た場合は T-02 の rollback に従う。
- [ ] T-04: 独立レビュー→指摘修正→再レビュー。depends_on: T-03。
  - rollback: 不要（レビューのみ。指摘修正の commit は T-02 と同じ手順で revert する）。
- [ ] H-02 (human): C-4レビューとmergeの実施。depends_on: T-04。
- [ ] O-01: 実PR採用状況の観測・revert基準評価。depends_on: H-02。

## Stop Conditions

- HOパスへの無承認編集、生成経路の未確認、C-3未承認、scope横断、Issueリンク破損、PR本文に根拠のない成功主張があれば、実装タスクは開始/継続しない。

## Rollback

- Docs-only planning artifact: このPR単位でrevert可能。
- Runtime/HO patch: Human承認を取得したPlanの単位でrevert。権限変更や設定適用はHuman-owned。
