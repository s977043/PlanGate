# C-2 外部AIレビュー結果 — TASK-0039

> 実施: 2026-04-30 / Codex CLI (`codex-cli 0.124.0`) / `codex exec` 経由
> 入力プロンプト: [`_codex-prompt.txt`](./_codex-prompt.txt)
> 対象: pbi-input.md / plan.md / todo.md / test-cases.md / review-self.md（+ 親 PBI 周辺ドキュメント）

## サマリ

| 区分 | 件数 |
|------|------|
| critical | 0 |
| major | 3 |
| minor | 3 |
| info | 1 |

**総合判定: WARN（CONDITIONAL）**

## 観点別判定

### 1. 要件適合性
- 判定: WARN
- コメント: AC-1〜AC-6 は plan/test-cases に概ね対応。ただし AC-4 の「各 phase」は TC-6 の確認方法が曖昧で、実行可能な検査条件が不足。

### 2. スコープ境界
- 判定: FAIL
- コメント: plan/todo/test-cases は `docs/ai-driven-development.md` 更新を前提にしているが、子 PBI YAML の allowed_files に含まれていない。

### 3. Iron Law 整合性
- 判定: WARN
- コメント: Core Contract で保持する方針は明確。ただし「既存 6 項目 + 追加 2 項目」と「Iron Law 7 項目」の数え方が混在している。

### 4. 削減目標の妥当性
- 判定: WARN
- コメント: `CLAUDE.md` 43 行、`AGENTS.md` 61 行を 50% 以下にする目標は厳しめ。token 50% 削減の測定対象も plan 内で揺れている。

### 5. テスト戦略
- 判定: WARN
- コメント: doc-review PBI として網羅性は高いが、TC-7 は grep の存在確認だけでは制約維持の検証として弱い。手動 E2E WARN は妥当。

### 6. リスク評価
- 判定: WARN
- コメント: L1〜L5 は現実的。ただし allowed_files 不整合、削減目標未達、Core Contract 正本化による既存文書移行漏れが明示リスク化されていない。

## 指摘事項

### EX-01 [major] `docs/ai-driven-development.md` が allowed_files 外
- 該当箇所: `plan.md:152`, `plan.md:158-159`, `todo.md:11`, `test-cases.md:70-74`, `PBI-116-01.yaml:19-30`
- 指摘内容: plan/test-cases は `ai-driven-development.md` を Core Contract 参照へ切替える前提だが、allowed_files に含まれていない。high-risk の scope discipline 上、このまま exec するとスコープ違反になる。
- 推奨対応: Child C-3 前に `docs/ai-driven-development.md` を allowed_files に追加するか、本 PBI では「確認のみ」に落として更新を別 PBI に分離する。

### EX-02 [major] Iron Law の項目数定義が不整合
- 該当箇所: `pbi-input.md:42-49`, `pbi-input.md:100`, `docs/ai-driven-development.md:102-109`
- 指摘内容: 既存 `docs/ai-driven-development.md` は 6 項目で、その中に root cause と two-stage review が既に含まれている。一方 pbi-input は「既存 6 項目を 7 項目（root cause + two-stage review 追加）に拡張」としており、数え方が合わない。
- 推奨対応: Core Contract の Iron Law 7 項目を正本として、既存 6 項目から何を統合・分割・追加するのかを plan に明記する。

### EX-03 [major] 削減目標の測定対象が揺れている
- 該当箇所: `plan.md:9`, `plan.md:88`, `plan.md:142`, `todo.md:49`, `test-cases.md:32-42`
- 指摘内容: Goal は「常時ロード token 半分以下」、TC-3/TC-4 は `CLAUDE.md` / `AGENTS.md` の行数 50% 以下、T-23 は「主要ファイル」も含む token 削減率としている。合否判定の母数が不明。
- 推奨対応: baseline/after の対象を `CLAUDE.md` + `AGENTS.md` のみか、常時ロード一式かに固定し、token 測定コマンドまたは算出方法を明記する。

### EX-04 [minor] TC-7 の制約維持検証が弱い
- 該当箇所: `test-cases.md:56-60`
- 指摘内容: `C-3|C-4|scope discipline|verification honesty` が少なくとも 1 ファイルに残るだけでは、制約が弱化していないことを確認できない。
- 推奨対応: Core Contract Hard constraints 内で該当制約が MUST 相当として残ること、入口ファイルから到達可能であることを期待出力に追加する。

### EX-05 [minor] 64 ファイル棚卸しと 1 セッション実行の整合が曖昧
- 該当箇所: `plan.md:43-46`, `plan.md:149`, `todo.md:16-17`
- 指摘内容: Step 1/T-3 は 64 ファイル全体の棚卸し完了を要求する一方、L2 mitigation は「1 セッション内では入口 + 共通 + 必要最小限」に絞るとしている。
- 推奨対応: 64 ファイルは全件 grep 記録まで必須、編集対象は優先層に限定、のように完了条件を分離する。

### EX-06 [minor] TASK 状態表示が古い
- 該当箇所: `INDEX.md:32-38`, `pbi-input.md:3`, `current-state.md:8`
- 指摘内容: plan/todo/test-cases/review-self が存在するが、INDEX/current-state/pbi-input は PLAN-READY や未作成表示のまま。
- 推奨対応: Child C-3 前に `current-state.md` と INDEX の状態を C-2/C-3 待ちへ更新する。

### EX-07 [info] 手動 E2E WARN の扱いは妥当
- 該当箇所: `review-self.md:42-45`, `test-cases.md:82-92`
- 指摘内容: Claude Code / Codex CLI 起動確認は環境依存があり、doc-review PBI で完全自動化しない判断は妥当。
- 推奨対応: `evidence/verification.md` に実施日時、実行者、結果、未実行理由を必ず残す。

## Questions（保留事項、Child C-3 で確認推奨）

- Q1: `docs/ai-driven-development.md` の更新は本 PBI の scope に含めますか？
- Q2: Iron Law 7 項目の正確な内訳は、既存 6 項目の再分類ですか、それとも新規追加を含みますか？
- Q3: token 50% 削減の合否対象は `CLAUDE.md` / `AGENTS.md` のみですか、常時ロード文書全体ですか？
- Q4: 64 ファイル棚卸しは全件レビュー完了まで必須ですか、全件 grep + 優先ファイル編集で十分ですか？

## Child C-3 ゲートへの推奨

**CONDITIONAL** — 計画の方向性と AC カバーは概ね妥当。ただし `docs/ai-driven-development.md` の allowed_files 不整合、Iron Law 7 項目の定義、削減率の測定母数は exec 前に修正が必要。

## CONDITIONAL 対応サマリ（同 PR 内で実施）

| ID | 対応方針 |
|----|---------|
| EX-01 | `docs/ai-driven-development.md` を `PBI-116-01.yaml` の allowed_files に追加（Q1: scope に含める） |
| EX-02 | Core Contract の Iron Law 7 項目を正本とし、既存 6 項目との対応表を plan に明記（Q2: 既存 6 項目の再分類 + root cause / two-stage review を独立化） |
| EX-03 | 削減目標を `CLAUDE.md` + `AGENTS.md` の行数のみに固定、Goal の表現も統一（Q3: 入口 2 ファイルのみ） |
| EX-04 | TC-7 の期待出力を強化（Core Contract に MUST 相当残存 + 入口から到達可能） |
| EX-05 | T-3 / Step 1 の完了条件を「全件 grep 記録は必須、編集対象は優先層」に分離（Q4: grep 必須 + 優先編集） |
| EX-06 | INDEX.md / current-state.md / pbi-input.md の状態表示を「C-2 完了 / Child C-3 待ち」に更新 |
| EX-07 | 対応不要（info、運用時に注意） |
