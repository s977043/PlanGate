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

- 以下 7 skills を `.claude/skills/` から `plugin/plangate/skills/` に配置（コピー）:
  - `working-context`
  - `ai-dev-workflow`
  - `brainstorming`
  - `self-review`
  - `pr-review-response`
  - `pr-code-review`
  - `setup-team`
- 各 skill の `SKILL.md`（または相当ファイル）を plugin 側で参照可能にする
- plugin 経由の呼び出し prefix を検証（`plangate:ai-dev-workflow` 形式で呼べるか）
- plugin 内で skill 間の相互参照パスが壊れないか確認
- `plugin.json` に skills エントリを追記
- commands 併存方針（C. ハイブリッド）の境界ルールを記録（`docs/` または plugin README に）

### Out of scope

- 他の skill（`brainstorming` 以外の多数あるドメイン skill 等）の移植
- skills の挙動変更・リファクタリング
- `.claude/skills/` 側の削除（A. デュアル運用のため温存）
- `.claude/commands/` の扱い変更（#20 で migration note に記載）
- commands → skills 変換（今回はコピーのみ、commands 側はそのまま）

---

## 受入基準

- [ ] 7 skills 全てが `plugin/plangate/skills/` 配下に存在する
- [ ] `plugin.json` の skills エントリに 7 件が列挙されている
- [ ] plugin 経由で `/working-context` が動作する
- [ ] plugin 経由で `/ai-dev-workflow` が動作する
- [ ] 他 5 skills（`brainstorming`, `self-review`, `pr-review-response`, `pr-code-review`, `setup-team`）も plugin 経由で呼び出し可能である
- [ ] skill 間の相互参照パス（例: `brainstorming` が他ファイルを読む場合）が機能する
- [ ] 既存 `.claude/skills/` 側の動作が壊れていない（デュアル運用成立）
- [ ] ハイブリッド方針の境界ルール（どの commands を skills 化したか）が文書化されている

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
