---
task_id: TASK-0039
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-04-30
author: Claude (PBI-116-01 exec)
v1_release: TBD (PR-B マージ後、子 PR としてマージ)
---

# TASK-0039 Handoff Package

> WF-05 Verify & Handoff の出力。PBI-116-01（Issue #117 Outcome-first Core Contract への移行）。
> 親 PBI: [PBI-116](../PBI-116/parent-plan.md) / Parent C-3: APPROVED（PR #128）/ Child C-3: APPROVED（PR #131）

## メタ情報

```yaml
task: TASK-0039
related_issue: https://github.com/s977043/plangate/issues/117
parent_pbi: PBI-116
covers_parent_ac: [parent-AC-1, parent-AC-7, parent-AC-8]
mode: high-risk
author: Claude
issued_at: 2026-04-30
exec_prs:
  - PR #132 (Step 1+2): docs/ai/core-contract.md 新規作成、棚卸し
  - PR #133 (Step 5+3+4): 入口ファイル薄型化（CLAUDE.md / AGENTS.md / project-rules.md）
  - PR-B (Step 6+7+8): hard-mandate 削減 + 検証 + handoff（本 PR）
```

## 1. 要件適合確認結果

`acceptance-review` Skill 相当の出力を統合（[`evidence/verification.md`](./evidence/verification.md) 詳細）。

| 受入基準 | 判定 | 根拠 |
|---------|------|---------------|
| AC-1: Core Contract が outcome-first 形式で定義 | PASS | `docs/ai/core-contract.md` 8 セクション完備（Role / Goal / Success criteria / Hard constraints / Decision rules / Available evidence / Stop rules / Output discipline）|
| AC-2: 常時ロード薄型化 | PASS | CLAUDE.md 43→21 (-51%)、AGENTS.md 61→29 (-52%)、両ファイル単独で 50% 以下達成 |
| AC-3: hard-mandate 限定 | PASS | 残存 21 件すべて Iron Law / 4 原則 / 仕様明確化として保持理由あり、削減対象（手順指定の冗長表現）はゼロ |
| AC-4: 各 phase の success criteria / stop rules | PASS | core-contract.md §3 (phase 別 Success criteria 表) / §7 (Stop rules 表) |
| AC-5: 既存ゲート維持 | PASS | C-3/C-4/scope discipline/verification honesty を Core Contract Hard constraints に MUST 相当で明示、入口から到達可能 |
| AC-6: plugin / .claude 整合 | PASS | 同期削減実施（working-context / commands / skills）、新規リンク切れ 0 件 |

**総合**: 6/6 基準 PASS
**FAIL / WARN の扱い**: なし（C-1 で 1 件 WARN として認識した手動 E2E は子 PR Child C-4 ゲートでユーザー確認に委譲）

## 2. 既知課題一覧

`known-issues-log` Skill 相当の出力。

| 課題 | Severity | 状態 | V2 候補 |
|------|---------|------|---------|
| 手動 E2E（Claude Code / Codex CLI 起動確認）未実施 | minor | accepted | No（Child C-4 でユーザー確認） |
| `docs/ai-driven-development.md` の Iron Law 6 項目本文が core-contract と重複保持 | minor | accepted | Yes（完全統合は V2 で） |
| .claude/agents の hard-mandate 残存（4 ファイル × 複数行） | info | accepted | No（Iron Law 相当として正当） |
| Plugin v8.1 ガードレール固有 rules（completion-gate / design-gate 等）の outcome-first 化 | minor | open | Yes |

**Critical 課題の対応**: なし

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 |
|--------|------|----------|
| Plugin 限定 rules（v8.1 ガードレール 6 件）の outcome-first 化 | 本 PBI scope は入口 + 共通 + .claude 主要範囲に限定 | Medium |
| ai-driven-development.md の Iron Law 6 項目本文を Core Contract 参照に完全置換 | 履歴的価値があるため本 PBI では保持 | Medium |
| `.claude/agents` の責務記述を outcome-first 化（残 19 ファイル分） | hard-mandate ヒットなしで本 PBI 対象外 | Low |
| 手動 E2E の自動化（CI 環境で Claude Code / Codex CLI 起動シミュレーション） | 環境依存高、別 PBI 適切 | Low |
| Stop rules の machine-checkable 化（schema 化） | PBI-116-04 (Structured Outputs) で扱える | Medium |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| 削減目標を「各ファイル単独 50% 以下」に固定 | 「合計 50% 以下」 | 公平性（片方だけ削減して合格を防ぐ）+ C-2 EX-03 修正後の合意 |
| `<law>` セクションを CLAUDE.md に保持（4 原則本文）| Core Contract への参照のみで本文削除 | Stop rule（`<law>` 全文維持）+ Claude Code 起動時の AI 運用 4 原則表示維持 |
| Iron Law 7 項目を Core Contract で正本化、ai-driven-development.md は履歴保持 | ai-driven-development.md の Iron Law 削除して core-contract への参照のみ | 既存読者の混乱回避、漸進的移行 |
| PR を 3 分割（PR #132 / #133 / 本 PR-B） | 1 PR にまとめる | レビュー粒度を小さくし、入口ファイル変更（high-risk）を独立検証可能に（Codex 相談 Q3 採用）|
| .claude/agents 4 件は保持判定 | 一部を outcome-first 化 | Iron Law 相当の表現として正当、削減すべきでない（inventory.md 個別レビューで判断）|

## 5. 引き継ぎ文書

### 概要

PlanGate の中核ルール（Iron Law 7 項目）を Core Contract（`docs/ai/core-contract.md`）に正本化し、入口ファイル（CLAUDE.md / AGENTS.md）を薄型化（51-52% 削減）した。AI 運用 4 原則は project-rules.md を正本としつつ CLAUDE.md `<law>` で表示維持。「絶対ルール」表記を「Iron Law（不可侵ルール）」に統一し、手順指定の冗長表現（必須削減 7 件 + 推奨 1 件 + 同期）を整理。

PR-B の段階で **PBI-116-01（#117）の exec フェーズが完了**。次は子 PR を main へマージし、Child C-4 ゲート判断を経て PBI-116-01 を `state: done` に遷移する。

### 触れないでほしいファイル

- `docs/ai/core-contract.md`: **正本**として確立。修正は別 PBI で（version-controlled な変更管理が必要）
- `CLAUDE.md` / `AGENTS.md`: 21 / 29 行という最適化済の状態。再度太らせる変更は避ける
- `.claude/agents/` の hard-mandate 表現（4 ファイル）: Iron Law 相当として正当、削減候補ではない
- `docs/ai-driven-development.md` の Iron Law 6 項目本文: 履歴的保持、core-contract が正本

### 次に手を入れるなら

- **V2-1 (Medium)**: Plugin 限定 rules（completion-gate / design-gate / evidence-ledger / review-gate / subagent-roles / worktree-policy）の outcome-first 化
- **V2-2 (Medium)**: Stop rules の machine-checkable 化 → PBI-116-04 (Structured Outputs) で schema 化
- **V2-3 (Low)**: ai-driven-development.md の Iron Law 完全統合

### 参照リンク

- 親 PBI: [`docs/working/PBI-116/parent-plan.md`](../PBI-116/parent-plan.md)
- Issue: https://github.com/s977043/plangate/issues/117
- 関連 PR: #126, #127, #128, #129, #130, #131, #132, #133, 本 PR
- C-1 セルフレビュー: [`review-self.md`](./review-self.md)（17 項目: 16 PASS / 1 WARN / 0 FAIL）
- C-2 外部AIレビュー: [`review-external.md`](./review-external.md)（Codex / CONDITIONAL → 全件対応）
- 検証結果: [`evidence/verification.md`](./evidence/verification.md)
- 棚卸し: [`evidence/inventory.md`](./evidence/inventory.md)
- baseline: [`evidence/baseline.md`](./evidence/baseline.md)
- 承認記録: [`approvals/c3.json`](./approvals/c3.json)（plan_hash で改竄検出可能）

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| 自動（grep / wc） | TC-3, TC-4, TC-5, TC-7, TC-8, TC-E1, TC-E2 | 7 | 0 | 高 |
| doc-review | TC-1, TC-2, TC-6 | 3 | 0 | 高 |
| 手動 E2E | TC-E3, TC-E4 | — | 2 SKIP | 子 PR Child C-4 で確認 |

**FAIL / SKIP の詳細**:
- TC-E3 / TC-E4 (手動 E2E): C-1 review-self で WARN として認識済。doc-review PBI として完全自動化困難な性質上やむを得ない。Child C-4 ゲートでユーザーが目視確認する。

**注**: 単体テスト（Unit）は doc-review PBI のため対象外。markdown lint は CI で自動実行（PR-A / PR-B 両方で PASS 確認済）。
