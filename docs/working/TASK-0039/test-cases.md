# TEST CASES — TASK-0039 (PBI-116-01 / Issue #117)

> ドキュメント中心の PBI のため、テストケースは **doc-review 観点** で構築。
> 自動化可能な部分は grep / wc / lint で機械検証。

## 受入基準 → テストケース マッピング

| 受入基準 | テストケース ID | 種別 |
|---------|--------------|------|
| AC-1: PlanGate Core Contract が outcome-first 形式で `docs/ai/core-contract.md` 等に定義されている | TC-1, TC-2 | doc-review + 自動 |
| AC-2: 常時ロードされる指示から重複した人格指定・過剰な手順指定が削減されている | TC-3, TC-4 | 自動（行数）+ doc-review |
| AC-3: `必ず` / `絶対` / `ALWAYS` / `NEVER` が不変制約（Iron Law 7 項目）に限定されている | TC-5 | 自動（grep） |
| AC-4: 各 phase の指示に success criteria と stop rules が含まれている | TC-6 | doc-review |
| AC-5: C-3 / C-4 / scope discipline / verification honesty の制約が維持されている | TC-7 | doc-review |
| AC-6: 既存の plugin / `.claude/` 両方の導線と矛盾していない | TC-8 | 自動（grep / link check） |

## テストケース一覧

### TC-1: Core Contract が 8 セクション完備
- 前提条件: `docs/ai/core-contract.md` が存在
- 入力: `grep -E "^## (Role|Goal|Success criteria|Hard constraints|Decision rules|Available evidence|Stop rules|Output discipline)" docs/ai/core-contract.md`
- 期待出力: 8 セクション全てがマッチ
- 種別: 自動（grep）

### TC-2: Core Contract の Hard constraints に Iron Law 7 項目が明示
- 前提条件: `docs/ai/core-contract.md` が存在
- 入力: Hard constraints セクション内で以下 7 キーワードを grep
  - C-3 承認 / scope / 検証証拠 / 隠さない / 整合性 / 原因調査 / 2 段階レビュー
- 期待出力: 7 項目全てヒット
- 種別: 自動（grep）+ doc-review

### TC-3: CLAUDE.md の行数が baseline の 50% 以下
- 前提条件: 変更前の CLAUDE.md 行数を baseline として記録
- 入力: `wc -l CLAUDE.md` 実行
- 期待出力: 行数が baseline × 0.5 以下
- 種別: 自動

### TC-4: AGENTS.md の行数が baseline の 50% 以下
- 前提条件: 変更前の AGENTS.md 行数を baseline として記録
- 入力: `wc -l AGENTS.md` 実行
- 期待出力: 行数が baseline × 0.5 以下
- 種別: 自動

### TC-5: hard-mandate キーワードが Iron Law 関連のみに限定
- 前提条件: 変更後の全対象ファイル
- 入力: `grep -rnE "必ず|絶対|ALWAYS|NEVER" CLAUDE.md AGENTS.md docs/ai/ .claude/ plugin/plangate/ 2>/dev/null`
- 期待出力: ヒット箇所が全て Iron Law 7 項目に紐づく文脈、または明示的に許容された箇所（AI 運用 4 原則等）
- 種別: 自動（grep）+ doc-review

### TC-6: 各 phase の指示に success criteria / stop rules が含まれる
- 前提条件: `docs/ai/core-contract.md` の Output discipline / Stop rules セクション
- 入力: 各 phase（plan / exec / review / handoff）について grep
- 期待出力: 各 phase に対応する success criteria と stop rules が記述
- 種別: doc-review

### TC-7: 既存ゲート（C-3 / C-4 / Iron Law）の維持
- 前提条件: 変更後の `CLAUDE.md` / `AGENTS.md` / `docs/ai/core-contract.md`
- 入力:
  - `grep -E "C-3|C-4|scope discipline|verification honesty" docs/ai/core-contract.md` を実行
  - `grep -E "core-contract.md" CLAUDE.md AGENTS.md` を実行
- 期待出力:
  - **Core Contract Hard constraints 内で各キーワードが MUST 相当として明示されている**（単なる存在確認ではなく、制約として機能していること）
  - **CLAUDE.md / AGENTS.md から `docs/ai/core-contract.md` への参照リンクが存在し、到達可能**
- 種別: 自動（grep）+ doc-review
- C-2 EX-04 対応: 単純な存在確認ではなく、Core Contract での MUST 相当残存と入口からの到達性を確認

### TC-8: 既存リンクの到達性
- 前提条件: 変更後の `CLAUDE.md` / `AGENTS.md` / `docs/ai/project-rules.md`
- 入力: 全 markdown link を抽出し、相対パスファイルが存在するか確認（`ls`）
- 期待出力: 全リンクが解決可能（リンク切れ 0 件）
- 種別: 自動（ls / grep）

## エッジケース

### TC-E1: Iron Law 重複の整理
- 前提条件: Core Contract と既存 `ai-driven-development.md` の Iron Law が重複する場合
- 入力: 両ファイルから Iron Law を抽出し比較
- 期待出力: Core Contract が正本となり、ai-driven-development.md が参照に切替（重複本文ゼロ）
- 種別: doc-review

### TC-E2: Plugin 配布版の同期漏れ
- 前提条件: 変更後の `plugin/plangate/rules/working-context.md` と `.claude/rules/working-context.md`
- 入力: `diff` 実行
- 期待出力: 共通範囲（v8.1 ガードレール固有を除く）が同一
- 種別: 自動（diff）+ doc-review

### TC-E3: Codex CLI 動作確認（手動）
- 前提条件: 薄型化した AGENTS.md
- 入力: `codex` で session 起動 + `/ai-dev-workflow TASK-XXXX status` 実行
- 期待出力: エラーなく起動、各原則が機能
- 種別: 手動（E2E）

### TC-E4: Claude Code 動作確認（手動）
- 前提条件: 薄型化した CLAUDE.md
- 入力: 新規セッションで PlanGate 関連質問
- 期待出力: AI 運用 4 原則が機能、Core Contract への参照が解決
- 種別: 手動（E2E）

### TC-E5: hard-mandate 残存の例外承認
- 前提条件: TC-5 で残存した hard-mandate がある場合
- 入力: 各残存箇所の文脈確認
- 期待出力: 全箇所が Iron Law 7 項目に紐づく、または明示的に許容（4 原則等）。例外がある場合は `evidence/verification.md` に明記
- 種別: doc-review

## 自動化サマリ

| TC | 自動化可能 |
|----|----------|
| TC-1 | ✅ grep |
| TC-2 | △ grep + 文脈確認 |
| TC-3 | ✅ wc -l |
| TC-4 | ✅ wc -l |
| TC-5 | △ grep + 文脈確認 |
| TC-6 | ✗ doc-review |
| TC-7 | ✅ grep |
| TC-8 | ✅ ls / link check |
| TC-E1 | ✗ doc-review |
| TC-E2 | ✅ diff |
| TC-E3 | ✗ 手動 E2E |
| TC-E4 | ✗ 手動 E2E |
| TC-E5 | ✗ doc-review |

自動化率: 8/13 が完全 / 部分自動化可能。
