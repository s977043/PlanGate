# TASK-1586 — Human handoff（6要素）

> State: **EVIDENCE_COLLECTED / C-3_NOT_APPROVED / NO_EXECUTION**
> Prepared: 2026-10-18 JST / Source: [#1586](https://github.com/s977043/PlanGate/issues/1586)
> Current source SHA: `1d624d95e597c711ec7f659868d4e1bf49d87d7a`

## 1. Goal / scope

ソフトウェア保守の改善候補を検証可能なEvidenceで特定し、Human承認の下で低リスクの変更へつなぐ。今回のPRは`docs/working/TASK-1586/**`への調査文書追加のみ。HO、Skill、Runner、CI、Runtimeは変更しない。

## 2. Changes / affected files

`INDEX.md`・`report.md`・本`handoff.md`。Issue本文の正本は[#1586](https://github.com/s977043/PlanGate/issues/1586)。文書以外への副作用は設計していない。

## 3. Verification evidence

- GitHubの固定SHA上でSkill 2件×4経路のGit blobを照合。正本/Codex/Pluginは一致し、Claudeだけ異なる。
- GitHub Actionsの[Test 39028937133](https://github.com/s977043/PlanGate/actions/runs/39028937133) はwall421秒でsuccess。経過時間と課金分数は別。
- #1556、#1578のClosedと元runの時系列を一次Issue/Actionsで照合。
- **未実行:** 最新文書PR headのCI、正式なC-1/C-2レビュー、Skill実行テスト、修正後の効果測定。これらの未実施をPASSと表示しない。

## 4. Unknowns / risks / stop

CIの旧集計2155分の分母・費用単位、Skill差分のRuntime影響、現在のHook物理配線、全コピーへの波及が未知。誤った安全宣言や配布規則の無言省略につながる変更は停止。配布Skill本体の差分修正は承認前に行わない。

## 5. Detection / rollback

- 今回の文書変更は該当PRのrevertで戻せる。
- 将来のSkill変更は正本とのdrift、下流CLI不在時の停止と`doctor --fix`のno-write挙動、同期テスト・Codex/Claude/Pluginの差分を検知点とする。
- 将来のHO改善はHumanが計画・適用・rollbackを管理する。今回の文書をHO実行スクリプトの代替とみなさない。

## 6. Next owner decision / approval gate

1. Maintainer: **SKILL-01/02を独立した修正計画と負例テストに進めるか**判断（優先）。
2. Human/CI Owner: 統一した計測単位でCI-01の課金ベースラインを作るか判断。
3. PlanGate Owner: HO候補の対象パスと個別C-3を審査。文書段階で承認トークンを発行しない。
4. Independent Reviewer: 差分とテスト結果、未知の取り扱いを検証。
5. Human C-4: 条件が満たされた変更PRのみ最終マージ判断を行う。

**Handoff verdict:** 今回のread-only報告はレビュー可能。Skill同期、HO適用、CI最適化の実装は未承認・未検証であり、Issue #1586はopenのまま維持する。
