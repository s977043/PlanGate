# C-2 外部AIレビュー結果 — TASK-0043 (PBI-116-03)

> 実施: 2026-04-30 / Codex CLI / `codex exec` 経由
> 入力: [`_codex-c2.txt`](./_codex-c2.txt)

## サマリ

| 区分 | 件数 |
|------|------|
| critical | 0 |
| major | **2** |
| minor | 2 |
| info | 1 |

**総合判定: WARN / Child C-3 推奨: CONDITIONAL → 同 PR で全 5 件対応済**

## 観点別判定（6 観点）

| 観点 | 判定 | コメント |
|------|------|---------|
| 1. 要件適合性 | WARN | AC は対応するが phase 定義と Core Contract に未解決点 |
| 2. スコープ境界 | WARN | 成果物の一部が `allowed_files` と一致しない |
| 3. Phase 1/2 整合性 | WARN | adapter enum は一致、7 phase と Core Contract に差分 |
| 4. テスト戦略 | WARN | enum 完全一致検証が grep で弱い |
| 5. リスク評価 | PASS | L1〜L5 は現実的 |
| 6. doc-only 制約 | PASS | 擬似コード / skeleton までで明確 |

## 指摘事項

### EX-03-01 [major] `verify` phase が Core Contract phase 表と未整合

- 該当: pbi-input.md L39 / plan.md L50 / core-contract.md L34
- 内容: 7 phase 前提だが Phase 1 Core Contract Success criteria は 6 phase（review に受入包含）
- 推奨: prompt-assembly.md で「Core Contract v1 では review に包含、Prompt Assembly では verify を明示 layer 化」と互換説明追加

### EX-03-02 [major] `allowed_files` と実作業予定ファイルが一致しない

- 該当: PBI-116-03.yaml L26 / plan.md L83 / todo.md L41
- 内容: allowed_files は docs/ai/* / CLI / schema のみだが、evidence/verification.md / handoff.md / status.md が新規作成予定に含まれる
- 推奨: allowed_files に `docs/working/TASK-0043/**` 追加

### EX-03-03 [minor] adapter enum 完全一致テストが grep では弱い

- 該当: test-cases.md L65 / model-profile.schema.json L114
- 内容: grep -E は存在確認のみで enum 追加・削除を検出できない
- 推奨: jq + sort + diff で完全一致確認

### EX-03-04 [minor] AC-4 表現が「最低 4 種」と「完全一致」で揺れ

- 該当: pbi-input.md L43 / L103 / plan.md L127
- 内容: 「最低 4 種」と「schema enum 完全一致必須」が混在
- 推奨: 「本 PBI 時点では schema enum 4 種を全件定義、将来 enum 追加時は skeleton 追加必須」に統一

### EX-03-05 [info] 4 層責務境界の上位概念接続

- 該当: responsibility-boundary.md L11 / structured-outputs.md L94
- 内容: Prompt Assembly 4 層は Responsibility Boundary の Prompt layer 内サブ構造
- 推奨: prompt-assembly.md に「Prompt layer 内 assembly 構造、Hook/Tool Policy/CLI validate は別 layer」追記

## 同 PR での CONDITIONAL 対応

| ID | 対応 |
|----|------|
| EX-03-01 (major) | ✅ pbi-input.md In scope #3 で「Core Contract v1 互換: review に包含、Prompt Assembly では verify を分離」明記 |
| EX-03-02 (major) | ✅ PBI-116-03.yaml allowed_files に `docs/working/TASK-0043/**` 追加 |
| EX-03-03 (minor) | ✅ test-cases.md TC-E1 を jq + sort + diff に強化 |
| EX-03-04 (minor) | ✅ pbi-input.md In scope #4 / AC-4 を「schema enum 全件 = 4 種」「追加時 skeleton 必須」に統一 |
| EX-03-05 (info) | ✅ plan.md Approach Overview に「上位概念との接続」セクション追加（prompt-assembly.md exec 時に詳細記述） |

→ 全 5 件対応済。Child C-3 ゲート: **APPROVE 候補**

## Child C-3 推奨

**APPROVE**（CONDITIONAL → 同 PR で全件対応済）
