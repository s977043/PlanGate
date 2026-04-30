# PBI-116 #117 棚卸し対象ファイル予備リスト

> **Status**: NOTE — `parent-plan-draft.md` 採用後の Phase 1 着手を補助する材料。
> 対象 Issue: [#117](https://github.com/s977043/plangate/issues/117) — Outcome-first Core Contract への移行（prompt slimming）
> 集計日: 2026-04-30

## 棚卸し対象ファイル全量

| カテゴリ | パス | ファイル数 | 行数（合計 / 概算） |
|---------|------|----------|------------------|
| 入口 | `CLAUDE.md` | 1 | 43 |
| 入口 | `AGENTS.md` | 1 | 61 |
| 共通ルール正本 | `docs/ai/project-rules.md` | 1 | 87 |
| ローカルルール | `.claude/rules/*.md` | 5 | 793 |
| ローカルコマンド | `.claude/commands/*.md` | 3 | 451 |
| ローカルエージェント | `.claude/agents/*.md` | 23 | — |
| Plugin ルール | `plugin/plangate/rules/*.md` | 9 | 931 |
| Plugin コマンド | `plugin/plangate/commands/*.md` | 7 | — |
| Plugin スキル | `plugin/plangate/skills/*/SKILL.md` | 14 | — |

**棚卸し総ファイル数**: 64 ファイル（推定）

### ローカル vs Plugin のファイル数乖離について

`.claude/` と `plugin/plangate/` でファイル数が異なる（rules 5 vs 9、commands 3 vs 7）のは意図的:

- **Plugin 限定 rules**: `completion-gate.md` / `design-gate.md` / `evidence-ledger.md` / `review-gate.md` / `subagent-roles.md` / `worktree-policy.md` は **Plugin 配布時の追加ガードレール**（v8.1 CLI / 配布形態固有）。ローカル開発では `.claude/rules/` の薄い構成で十分。
- **Plugin 限定 commands**: 同様に Plugin 配布形態に固有の入口を追加（v8.1 系で拡張）。

**棚卸し方針**: Plugin 限定ファイルは「Plugin 配布版の補強」として **#117 の対象に含む**（同期対象外ではない）。ただし内容が `.claude/` 側と重複する場合は Plugin 側を権威として整理する（v8.1 以降の進化を反映）。

## hard-mandate キーワード初動スキャン

正規表現 `必ず|絶対|ALWAYS|NEVER` でヒットしたファイルを 1 次抽出。`#117` の確認観点「`必ず`/`絶対`/`ALWAYS`/`NEVER` の乱用」検出のための初動。

### ヒットしたファイル（要レビュー）

| 区分 | ファイル | 一次評価 |
|------|---------|--------|
| 入口 | `CLAUDE.md` | 不変制約（AI運用4原則）に限定されているか要確認 |
| 共通ルール | `docs/ai/project-rules.md` | 同上 |
| ローカルルール | `.claude/rules/hybrid-architecture.md` | Rule 1〜5 関連、文脈確認必要 |
| ローカルルール | `.claude/rules/working-context.md` | フォーマット強制が多い、整理候補 |
| ローカルコマンド | `.claude/commands/ai-dev-workflow.md` | プロンプト本体。最も削減余地あり（353行） |
| Plugin ルール | `plugin/plangate/rules/working-context.md` | ローカル版と重複領域 |
| Plugin コマンド | `plugin/plangate/commands/ai-dev-workflow.md` | ローカル版と重複領域 |

### キーワード未検出だが要確認

- `AGENTS.md`: hard-mandate なし。outcome-first 観点での見直しは別途必要
- `.claude/agents/*.md`: agents 内では grep で 4 件ヒット（個別ファイル特定は次のステップ）

## #117 確認観点チェックリスト

各対象ファイルを以下の観点で個別レビューする。

- [ ] 過剰な手順指定（細かいステップ列挙）
- [ ] 重複した人格指定（"あなたは XX エンジニアです" 系の繰り返し）
- [ ] `必ず` / `絶対` / `ALWAYS` / `NEVER` の乱用（不変制約以外で使用）
- [ ] `段階的に考えて` / `ステップバイステップ` 系の不要な指示
- [ ] 巨大な出力形式説明（フォーマット強制）
- [ ] 停止条件がない検索・検証指示
- [ ] outcome（Goal / Success criteria）が不明瞭
- [ ] hard constraints（不変制約）が明示されていない

## 不変制約（保持必須）

`#117` の受入基準と既存 Iron Law（`docs/ai-driven-development.md` 定義）により、以下は **削減対象外**:

- C-3 承認前に production code を変更しない
- PBI 外の scope を追加しない
- 検証証拠なしに完了扱いしない
- 失敗・未実行・残リスクを隠さない
- 承認済み plan と実装差分の整合性を崩さない
- 原因調査なしに修正しない（`NO FIXES WITHOUT ROOT CAUSE INVESTIGATION`）
- 2 段階レビューなしにマージしない（`NO MERGE WITHOUT TWO-STAGE REVIEW`）

これらは Iron Law として明示維持し、`必ず` / `NEVER` の使用を許容する。

## 推奨着手順序

1. `CLAUDE.md` / `AGENTS.md` を outcome-first テンプレに整形（最重要、入口）
2. `docs/ai/project-rules.md` を Core Contract のソースに変換
3. `.claude/commands/ai-dev-workflow.md`（353 行）を中心にコマンド層の prompt slimming
4. `.claude/rules/working-context.md`（303 行）の重複削減
5. Plugin 配下（`plugin/plangate/rules/`, `commands/`）を 3〜4 と同期

## 関連

- 親計画書 DRAFT: `docs/working/PBI-116/parent-plan-draft.md`
- Issue: https://github.com/s977043/plangate/issues/117
- doc-audit 振り返り: `docs/working/retrospective-2026-04-30.md`
