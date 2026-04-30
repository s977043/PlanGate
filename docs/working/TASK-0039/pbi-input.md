# PBI INPUT PACKAGE — TASK-0039 (PBI-116-01 / Issue #117)

> **Status**: PREPARATORY ONLY — Parent C-3 ゲート（`docs/working/PBI-116/approvals/parent-c3.json`）APPROVED 待ち
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / EPIC [#116](https://github.com/s977043/plangate/issues/116)
> 子 PBI ID: PBI-116-01
> Issue: [#117 Outcome-first Core Contract への移行（prompt slimming）](https://github.com/s977043/plangate/issues/117)
> Mode: high-risk（Phase 1、Core Contract が他子 PBI の前提）

## Context / Why

最新の実行モデル（GPT-5.5 系、Claude 4.x 系等）では、長い手順指定や重複した人格指定よりも、**目的・成功条件・制約・利用可能な根拠・停止条件・出力** を明確にする outcome-first な指示設計が有効。

PlanGate には C-3 承認、C-4 レビュー、受入基準、検証証拠、handoff という強い統制構造がある一方、既存の `CLAUDE.md` / `AGENTS.md` / rules / commands / agents にはモデルに細かな手順を指示する記述や `必ず` / `絶対` 等の冗長な記述が残存している。

本 PBI では、PlanGate の中核ルール（Iron Law 7 項目）を維持したまま、常時ロードされる指示を薄くし、Core Contract を outcome-first 形式に再構成する。

## What

### In scope

1. **既存プロンプト・ルールの棚卸し**（[`docs/working/PBI-116/notes-117-target-files.md`](../PBI-116/notes-117-target-files.md) 参照）
   - 入口: `CLAUDE.md`, `AGENTS.md`
   - 共通: `docs/ai/project-rules.md`
   - ローカル: `.claude/rules/*.md`, `.claude/commands/*.md`, `.claude/agents/*.md`
   - Plugin: `plugin/plangate/rules/*.md`, `plugin/plangate/commands/*.md`, `plugin/plangate/skills/*/SKILL.md`
   - 計 64 ファイル

2. **Core Contract の定義**（`docs/ai/core-contract.md` を新規作成）

   形式:
   ```text
   Role
   Goal
   Success criteria
   Hard constraints (Iron Law 7 項目)
   Decision rules
   Available evidence
   Stop rules
   Output discipline
   ```

3. **Iron Law 7 項目の明示維持**（削減対象外）
   - C-3 承認前に production code を変更しない
   - PBI 外の scope を追加しない
   - 検証証拠なしに完了扱いしない
   - 失敗・未実行・残リスクを隠さない
   - 承認済み plan と実装差分の整合性を崩さない
   - 原因調査なしに修正しない（NO FIXES WITHOUT ROOT CAUSE INVESTIGATION）
   - 2 段階レビューなしにマージしない（NO MERGE WITHOUT TWO-STAGE REVIEW）

4. **入口ファイルの薄型化**
   - `CLAUDE.md` / `AGENTS.md` は詳細手順ではなく、Core Contract と参照先への導線に寄せる
   - 重複した人格指定・過剰な手順指定の削除
   - `必ず` / `絶対` / `ALWAYS` / `NEVER` を不変制約に限定

### Out of scope

- C-3 / C-4 Gate の削除または緩和
- モデル別に完全に別プロンプトを作ること（→ PBI-116-03 で対応）
- Hook や CLI の実装変更（→ PBI-116-06 で境界定義のみ）
- Structured Outputs schema の詳細設計（→ PBI-116-04 で対応）
- Model Profile の定義（→ PBI-116-02 で対応）

## 受入基準

- [ ] PlanGate Core Contract が outcome-first 形式で `docs/ai/core-contract.md` 等に定義されている
- [ ] 常時ロードされる指示から重複した人格指定・過剰な手順指定が削減されている
- [ ] `必ず` / `絶対` / `ALWAYS` / `NEVER` が不変制約（Iron Law 7 項目）に限定されている
- [ ] 各 phase の指示に success criteria と stop rules が含まれている
- [ ] C-3 / C-4 / scope discipline / verification honesty の制約が維持されている
- [ ] 既存の plugin / `.claude/` 両方の導線と矛盾していない

## Notes from Refinement（議論で決まったこと）

- **棚卸し対象 64 ファイル**: [`notes-117-target-files.md`](../PBI-116/notes-117-target-files.md) で予備調査済
- **hard-mandate キーワードヒット 7 ファイル**: 個別レビューで Iron Law 適合性を確認
- **ローカル / Plugin の重複領域**: Plugin 側を権威として整理（v8.1 以降の進化を反映）
- **`covers_parent_ac`**: parent-AC-1（Core Contract outcome-first）/ parent-AC-7（既存 Gate 維持）/ parent-AC-8（薄型化による token 削減）

## Estimation Evidence

### Risks

| ID | Risk | Severity | Mitigation |
|----|------|---------|----------|
| L1 | `必ず` / `絶対` 削減で意図せず Iron Law を弱化 | high | 7 項目を明示保持、grep で hard mandate キーワードを除外確認 |
| L2 | 棚卸し 64 ファイルの削減が手作業で時間超過 | medium | カテゴリ別優先順序（入口 → 共通 → コマンド → ルール → Plugin）に従う |
| L3 | 入口薄型化で Claude Code / Codex CLI 双方の動作が壊れる | high | C-2 外部AIレビュー必須、C-3 で動作確認を強制 |
| L4 | Plugin 配布版（`plugin/plangate/`）との同期漏れ | medium | allowed_files に plugin 側を含め、棚卸し対象として明示 |

### Unknowns

- `CLAUDE.md` / `AGENTS.md` のどこまで薄型化するか（最終的な行数の目標）
  → C-2 レビューで判断、最初は **半分以下** を目安
- Iron Law を CLAUDE.md / AGENTS.md 直書きと参照リンクのどちらにするか
  → 直書きで明確化、参照は補助

### Assumptions

- 既存の `docs/ai-driven-development.md` の Iron Law 6 項目は本 PBI で 7 項目（root cause + two-stage review 追加）に拡張
- Codex CLI 用の `AGENTS.md` も同じ Core Contract を参照する（Claude Code / Codex CLI 共用設計）
- 本 PBI 単独で完結し、PBI-116-02〜06 の前提として機能する

## Parent PBI との関係

| 親 AC | 本 PBI でのカバー |
|------|-----------------|
| parent-AC-1 | Core Contract outcome-first 化（直接対応） |
| parent-AC-7 | C-3 / C-4 / scope discipline / verification honesty の維持（Iron Law 7 項目） |
| parent-AC-8 | CLAUDE.md / AGENTS.md 薄型化による常時ロード token 削減 |

## 着手前提条件（Parent C-3 待ち）

本 PBI の plan.md / todo.md / test-cases.md 作成は、以下を待ってから:

1. ✅ 親計画書 `docs/working/PBI-116/parent-plan.md` がマージ済み（PR #126 / `9203c84`）
2. ⏳ Parent C-3 ゲート APPROVED（`docs/working/PBI-116/approvals/parent-c3.json` の `decision: "APPROVED"`）
3. ⏳ Child C-3 用 `plan.md` / `todo.md` / `test-cases.md` の作成（次セッション）

## 関連リンク

- 親 PBI: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- 子 PBI YAML: [`docs/working/PBI-116/children/PBI-116-01.yaml`](../PBI-116/children/PBI-116-01.yaml)
- Issue: https://github.com/s977043/plangate/issues/117
- 予備調査: [`docs/working/PBI-116/notes-117-target-files.md`](../PBI-116/notes-117-target-files.md)
- 親計画 PR: https://github.com/s977043/plangate/pull/126
