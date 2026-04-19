# PBI INPUT PACKAGE: PlanGate 主要 skills を plugin に移植する

> 作成日: 2026-04-19
> PBI: [TASK-0016-B] PlanGate 主要 skills を plugin に移植する
> チケットURL: https://github.com/s977043/plangate/issues/18
> 親チケット: https://github.com/s977043/plangate/issues/16

---

## Context / Why

Issue #16（plugin 化）の 2 つ目のステップとして、PlanGate の主要導線 skills を plugin 側に配置し、plugin 経由で呼び出し可能にする。

skills は PlanGate ワークフローの UX を司る要素であり、plugin 経由で動作することで以下が実現する:

- 他リポジトリで `/working-context` や `/ai-dev-workflow` を plugin だけで利用できる
- commands と skills の併存（ハイブリッド方針）を具体化できる
- 後続の agents 移植（#19）の前提条件を整える

---

## What（Scope）

### In scope

**実態調査（TASK-0018 着手時）で判明**: 当初計画の 7 skills のうち 3 件（`pr-review-response`, `pr-code-review`, `setup-team`）が `.claude/` に存在しない。2 件（`working-context`, `ai-dev-workflow`）は skill ではなく command として存在。計画を実態に合わせて修正:

- **Skills 移植（5 件）**: `.claude/skills/` から `plugin/plangate/skills/` にコピー
  - `brainstorming`
  - `self-review`
  - `subagent-driven-development`
  - `systematic-debugging`
  - `codex-multi-agent`
- **Commands 移植（2 件）**: `.claude/commands/` から `plugin/plangate/commands/` にコピー
  - `working-context`
  - `ai-dev-workflow`
- 各 skill/command ファイルを plugin 側で参照可能にする
- plugin 経由の呼び出し検証
- plugin 内での相互参照パスが壊れないか確認
- commands 併存方針（C. ハイブリッド）の境界ルールを evidence に記録（TASK-0020 の素材）

### Out of scope

- 他の skill（`skill-creator`, `skill-ops-planner`, `skill-optimizer` 等のツール系）の移植
- 存在しない skill の新規作成（`pr-review-response`, `pr-code-review`, `setup-team`）
- skills/commands の挙動変更・リファクタリング
- `.claude/skills/` / `.claude/commands/` 側の削除（A. デュアル運用のため温存）
- commands → skills 変換（今回はコピーのみ、型はそのまま維持）

---

## 受入基準

- [ ] 5 skills 全てが `plugin/plangate/skills/` 配下に存在する（brainstorming, self-review, subagent-driven-development, systematic-debugging, codex-multi-agent）
- [ ] 2 commands 全てが `plugin/plangate/commands/` 配下に存在する（working-context, ai-dev-workflow）
- [ ] plugin 経由で `/working-context` が動作する
- [ ] plugin 経由で `/ai-dev-workflow` が動作する
- [ ] 5 skills も plugin 経由で呼び出し可能である（runtime 検証）
- [ ] skill/command 間の相互参照パスが機能する
- [ ] 既存 `.claude/skills/` と `.claude/commands/` 側の動作が壊れていない（デュアル運用 + runtime）
- [ ] ハイブリッド方針の境界ルール（skill / command の使い分け）が evidence に記録されている（TASK-0020 素材）

---

## Notes from Refinement

### 決定事項（親 TASK-0016 より継承）

- 対象 skills: 7 件（主要導線のみ）
- 移行方式: C. ハイブリッド（skills として plugin へ、commands は `.claude/commands/` 側に残存）
- plugin 名: `plangate`

### commands 併存の扱い

既存 `.claude/commands/*.md` のうち、本 issue で skills 化するもの:

| command | 対応 skill | 併存方針 |
|---------|-----------|---------|
| `/working-context` | `working-context` skill | 両方残す |
| `/ai-dev-workflow` | `ai-dev-workflow` skill | 両方残す |
| `/self-review` | `self-review` skill | 両方残す |
| `/pr-review-response` | `pr-review-response` skill | 両方残す |
| `/pr-code-review` | `pr-code-review` skill | 両方残す |
| `/setup-team` | `setup-team` skill | 両方残す |

`brainstorming` は skill のみ（command は存在しない前提）。

### 想定モード判定

**standard**（中）を想定。

- 変更ファイル数: 7-10 ファイル（skills のコピー + plugin.json 更新）
- 変更種別: ファイル配置＋設定追記
- リスク: 中（既存 skill の参照パスが壊れる可能性）

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| skills 内の相対パス参照が plugin 配置で壊れる | Medium | コピー前に参照パスを一覧化、壊れる箇所は修正 |
| 同名 skill が `.claude/skills/` と plugin 側で衝突し呼び出しが不定 | Medium | 呼び出し prefix（`plangate:`）で明示的に区別 |
| plugin 経由呼び出しが CC の仕様上 `.claude/` 側より優先されない | Low | 仕様を事前確認、必要なら `.claude/skills/` 側を一時リネームして検証 |
| commands 併存により UX 混乱 | Low | README / migration note に明確な使い分けルールを記載（#20） |

### Unknowns

- plugin 経由 skill の呼び出し syntax（`plangate:skill-name` か `/skill-name` か）
- skill 間の参照解決がディレクトリ境界を越えるか
- plugin の skills 登録に `plugin.json` で何が必要か（パス指定 vs auto-discovery）

### Assumptions

- TASK-0017（スケルトン）が完了しており、`plugin/plangate/` が存在する
- `.claude/skills/` 配下の 7 skills は現行で動作している
- skill ファイル構造は plugin 側でも互換（拡張子、命名規則が同一）

---

## 依存

- **前提**: Sub #17（TASK-0017）完了
- **後続**: Sub #19（TASK-0019: agents 移植）、Sub #20（TASK-0020: README）

---

## 次フェーズへの申し送り

- B: plan 生成（TASK-0017 完了後に着手）
- plan では skill 間の参照パス調査タスクを先頭に含める
- C-1 セルフレビュー（standard モードで 17項目チェック）
- C-3 ゲート後に exec
