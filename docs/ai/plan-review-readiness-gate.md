# Plan Review Readiness Gate

> Issue: [#652](https://github.com/s977043/plangate/issues/652)
> Related upstream: [s977043/river-review#1325](https://github.com/s977043/river-review/issues/1325)

## 1. 目的と位置づけ

Plan Review Readiness Gate は、`plan.md` / `todo.md` / `test-cases.md` が生成された直後、C-1 self-review の前に置く計画実行準備ゲートである。

```text
WF-00 -> WF-01 -> WF-02 -> WF-03 -> plan/todo/test-cases
  -> Plan Review Readiness Gate
  -> C-1 self-review -> C-2 external AI review -> C-3 human approval -> WF-04 -> WF-05
```

このゲートの目的は、AI 実行に渡す前の計画が「レビュー可能」であり、かつ C-1 / C-2 / C-3 が見るべき境界を明示していることを確認することである。実装品質そのものを判定するゲートではなく、レビュー対象 artifact の準備状態を判定する。

> Design decision: 新規 standalone gate として定義する。`docs/ai/plan-quality-checks.md` は advisory な計画品質チェック、`docs/ai/gate-checks.md` は C-3 承認記録の optional 拡張であり、本ゲートのように C-1 前で `pass / needs_revision / blocked` を返す実行前判定とは責務と時点が異なるため、既存文書への混在を避ける。

## 2. 判定値

| Verdict | 意味 | 次アクション |
|---------|------|--------------|
| `pass` | 7 項目がすべて記入され、C-1 で妥当性レビューできる状態 | C-1 self-review へ進む |
| `needs_revision` | 計画の不足はあるが、危険操作や承認境界違反ではない | `plan.md` / `todo.md` / `test-cases.md` を修正して再判定 |
| `blocked` | 矛盾、未承認の危険操作、Human-owned 境界、破壊的操作、依存追加など、AI が自己判断で進めてはいけない要素がある | 人間判断または PBI 再整理まで停止 |

判定不能な場合は安全側に倒し、少なくとも `needs_revision` とする。危険操作・承認境界・破壊的変更に関わる判定不能は `blocked` とする。

## 3. チェック項目

すべての項目は `plan.md` に明示し、必要に応じて `todo.md` / `test-cases.md` と対応させる。

| # | 項目 | `pass` | `needs_revision` | `blocked` |
|---|------|--------|------------------|-----------|
| 1 | Success criteria | AC、完了境界、Done 判定が具体的で、`test-cases.md` と対応している | AC と作業の対応が一部曖昧、検証方法が不足 | 成功条件が矛盾、または完了境界が定義不能 |
| 2 | Review criteria | 設計整合、テスト期待値、セキュリティ、保守性、後方互換、運用リスクの観点が揃っている | 一部観点が N/A 理由なし（N/A の根拠が未記載）または空欄で欠落 | 重要リスクをレビュー対象から外している |
| 3 | Required context | 参照 Issue / ADR / docs / 既存実装 / 関連テスト / 制約が列挙されている | 参照先が不足、または確認済み/未確認の区別が弱い | 必須前提が未確認で、誤実装や破壊的変更につながる |
| 4 | Non-goals and scope boundary | Out of scope、変更禁止領域、禁止依存が明示されている | 禁止領域や依存追加方針が曖昧 | HO パス（`bin/plangate`・`schemas/`・`.claude/`・`CLAUDE.md` 等、[EH-1 正本](./hook-enforcement.md) 参照）や禁止領域を編集対象に含めている |
| 5 | Stop conditions | 競合要件、認証/課金/破壊的操作、新規依存、大規模な想定外変更の停止条件がある | 停止条件が一般論で、実行者が判断しにくい | 停止すべき条件を通常作業として扱っている |
| 6 | Replan Triggers | hidden dependency、public API 変更、test contract mismatch、scope bloat、security impact の再計画トリガーが列挙されている | 再計画トリガーが一部未記入、または閾値が曖昧 | 再計画が必要な変更を exec 中に吸収する計画になっている |
| 7 | Human approval boundary | security、auth、billing、permissions、prod ops、data deletion、migration、irreversible changes、merge（C-4）の人間承認境界が明示されている | 一部境界が N/A 理由なし（N/A の根拠が未記載）または空欄で欠落 | Human-owned 操作を AI 判断で実行する計画になっている |

## 4. Decision table

複数条件が同時に成立した場合は、より厳しい verdict を採用する（`blocked` > `needs_revision` > `pass`）。

| 条件 | Verdict |
|------|---------|
| 7 項目すべてが具体的に記入され、未解決の危険境界がない | `pass` |
| 1 つ以上の項目に記入不足があるが、修正すれば C-1 に進める | `needs_revision` |
| `TBD` / `TODO` / `必要に応じて` / プレースホルダ未置換 / 空欄 が重要項目に残っている | `needs_revision` |
| AC と `test-cases.md` の対応が欠落している | `needs_revision` |
| 禁止ファイル、HO パス（EH-1 正本参照）、Out of scope が変更対象に含まれている | `blocked` |
| 認証、課金、権限、本番運用、データ削除、migration、不可逆変更、merge（C-4）を AI 判断で実行する | `blocked` |
| 承認トークンファイル（`approvals/c3.json`・`maintenance.json` 等）を AI が直接編集する計画がある | `blocked` |
| 新規依存や public API 変更が必要だが、承認境界と再計画条件が未定義 | `blocked` |
| 要件が互いに矛盾し、AI が一意に解釈できない | `blocked` |

## 5. 良い AI 実行計画の例

```markdown
## Plan Review Readiness

### Success Criteria
- AC-1 は `test-cases.md` T1/T2 で確認する。
- Done は docs 更新、リンク整合、`rg` による旧名称なし確認まで。

### Review Criteria
- Design alignment: 既存の `docs/workflows/` 命名と対応表に合わせる。
- Security: executable code と hook は変更しないため N/A。
- Backward compatibility: 既存フェーズ名を削除せず追記のみ。

### Required Context
- Issue: #652
- Existing docs: `docs/ai/gate-checks.md`, `docs/ai/plan-quality-checks.md`
- Constraints: HO paths は編集しない。

### Non-goals and Scope Boundary
- Out of scope: schema 変更、hook 実装、CLI 実装。
- Forbidden zones: `bin/plangate`, `schemas/*.schema.json`, `.github/workflows/*.yml`,
  `.claude/settings*.json`, `.claude/rules/**`, `plugin/plangate/**`,
  `CLAUDE.md`, `AGENTS.md`, `docs/ai/core-contract.md`
  （詳細は EH-1 production code 定義参照）

### Stop Conditions
- HO パス編集が必要になったら停止。
- 新規依存や CLI 実装が必要になったら停止。

### Replan Triggers
- C-1 前でなく C-3 側に置くべき既存正本が見つかった場合は再計画。
- public API / schema 変更が必要になった場合は再計画。

### Human Approval Boundary
- schema、hook、CI、権限、本番運用、データ削除、migration、merge（C-4）は人間承認なしに実行しない。
- 承認トークンファイル（`approvals/c3.json` 等）の AI 直接編集は禁止。
```

この例は、レビュー観点と停止境界が具体的で、実行者が「どこまで進めてよいか」を判断できる。

## 6. 悪い AI 実行計画の例

```markdown
## Plan Review Readiness

### Success Criteria
- いい感じに動くこと。

### Review Criteria
- 必要に応じて確認する。

### Required Context
- たぶん既存 docs を見る。

### Non-goals and Scope Boundary
- 特になし。

### Stop Conditions
- 問題があれば止める。

### Replan Conditions
- 必要なら再計画する。

### Human Approval Boundary
- AI が判断する。
```

この例は、AC・レビュー観点・停止条件・再計画条件が実行可能な粒度ではないため `needs_revision` の要素を含む。さらに Human Approval Boundary に「AI が判断する」と記入されている箇所は Section 4 の `blocked` 条件に直接該当する。`needs_revision` と `blocked` は独立した判定軸であり、`blocked` 条件が 1 つでも成立すれば最終判定は `blocked`（優先順: `blocked` > `needs_revision` > `pass`）。

## 7. 関連

- [`plan-quality-checks.md`](./plan-quality-checks.md) — advisory な計画品質チェック
- [`gate-checks.md`](./gate-checks.md) — C-3 承認時の optional 記録拡張
- [`review-gate-decision-mapping.md`](./review-gate-decision-mapping.md) — C-2 / C-3 判定接続
- [`../workflows/03_solution_design.md`](../workflows/03_solution_design.md) — WF-03 の完了条件
- [`../working/templates/plan.md`](../working/templates/plan.md) — 本ゲートが確認する plan fields
