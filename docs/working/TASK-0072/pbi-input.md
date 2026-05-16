---
task_id: TASK-0072
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0072

> F1: exec 委譲デッドロックの恒久対処（ケイパビリティ分岐 + 直接実行フォールバック）
> 起源（field feedback）: #239（field report 問題1）/ #237（bug）/ #238（feat）/ #234-E（★最優先）

## Context / Why

PlanGate exec フェーズが「`workflow-conductor` 役をサブエージェントで起動 →
conductor がさらにサブエージェントへ `Task` 委譲」という **2段委譲を暗黙の
前提**にしている。サブエージェントのネストを許可しない実行環境（Claude Code の
サブエージェント実行コンテキスト等）では `Task` が使えず、conductor の
Iron Law（CONDUCTOR ORCHESTRATES, NEVER IMPLEMENTS）と環境制約が衝突して
**デッドロック**する。

C-3（人間承認）通過後＝最もコストの高い実装直前で停止し、人間/メイン
セッションが手動で実装を引き取らないと完遂できない。**複数 PBI で恒常再発**
（直近2 PBI で確認、過去にも観測）。PlanGate の「型として配布する」価値
（誰がどの環境で回しても同じ手順で完遂）を損なう。

## What — Scope

### In scope

- exec フェーズ開始時に **委譲ケイパビリティのプリフライト判定**を追加
  （サブエージェント委譲＝`Task` 可否を明示ステップで検出）
- **フォールバック既定の正規化**: 委譲可能なら conductor 委譲、不可なら
  **メイン/単一エージェントが直接 Implementer を実行** を *既定の正規フロー*
  としてワークフロー定義に明記（「conductor 委譲が前提」記述を撤廃し、
  委譲は環境が許す場合の最適化と再位置づけ）
- **core-contract 不変条件追加**: 「exec はどの実行環境でも完遂可能であること」。
  2段委譲を必須とするフェーズ定義を禁止
- **error taxonomy 追加**: `delegation_unavailable`（サブエージェント内での
  サブエージェント起動不可）を tool error カテゴリ化し、recovery policy =
  「直接実行へ自動降格（人間介入不要）」を標準化（#203 へ接続）
- 対象ドキュメント/定義: `docs/ai/core-contract.md`、exec 系 workflow 定義
  （`docs/workflows/04_*` 等）、`.claude/agents/workflow-conductor.md`、
  関連 SKILL（`ai-dev-workflow`）、error taxonomy 文書

### Out of scope

- conductor の完全廃止（委譲可能環境の並列性・責務分離の利点は残す）
- #239 問題2（委譲先 commit 禁止のツールレベル強制）→ F2 別 PBI
- #239 問題3 の認証プリフライト全般 → F2 で扱う（本 PBI は Task 可否に限定）
- #234 の A/B/C/D（Lite 分岐 / C-2 責務分離 / 反映差分 / C-3 降格）→ F5 別トラック

## Acceptance Criteria

- [ ] AC-1: exec 開始時に委譲ケイパビリティ（Task 可否）を判定する明示ステップが定義・文書化されている
- [ ] AC-2: 委譲不可環境で exec が **人間介入なしで直接実行へ自動フォールバック**し完遂する（フロー定義として明記）
- [ ] AC-3: ワークフロー定義から「conductor 委譲が前提」の記述が撤廃され、委譲は環境依存の最適化と明記される
- [ ] AC-4: core-contract に「exec はどの実行環境でも完遂可能」が不変条件として追加され、2段委譲必須定義が禁止と明文化される
- [ ] AC-5: `delegation_unavailable` が error taxonomy に定義され、recovery policy=「直接実行へ自動降格」が標準化される
- [ ] AC-6: workflow-conductor の Iron Law と環境制約衝突時の正しい挙動（エスカレーション or 降格）がエージェント定義に整合反映される
- [ ] AC-7: 既存のドキュメント整合性チェック / hook テストに回帰がない

## Notes from Refinement

- conductor 自体のエスカレーション挙動は正しい（原則を破って勝手に実装しなかった）。
  不具合は「2段委譲前提の定義 ↔ ネスト不可環境」の**設計と実行モデルの不整合**
- メモリ既知: `conductor subagent Task 制約`（過去にメイン代行で回避＝要仕組み化）
- #238 が恒久対処の要望本体、#237 が bug、#239 が field evidence、#234-E が omnibus 内の★最優先項目。本 PBI は4者を1スコープに統合
- 「直接実行フォールバック」は #203 Tool Error Taxonomy の具体ケース提供を兼ねる

## Estimation Evidence

**Risks**: ワークフロー定義 + core-contract + agent 定義 + error taxonomy の
横断変更。強制力・実行モデルの中核に触れる → 最低「高」、core-contract 変更を
含むため「超高(critical)」想定。V-3 外部レビュー必須
**Unknowns**: ケイパビリティ判定の実装手段（環境変数 / プリフライト探索 /
ツール存在検査のどれを正規とするか）→ plan/C-3 で意思決定
**Assumptions**: 「conductor 委譲は最適化、直接実行が既定フォールバック」を
正規フロー化してよい（#238 提案・field evidence あり）。Mode 想定: critical
