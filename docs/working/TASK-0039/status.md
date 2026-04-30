# TASK-0039 Status

> exec フェーズの進捗ログ（フェーズ遷移ごとに追記）

## 全体構成

- **対象 Issue**: [#117](https://github.com/s977043/plangate/issues/117)
- **親 PBI**: [PBI-116](../PBI-116/parent-plan.md)
- **子 PBI ID**: PBI-116-01
- **ブランチ**: `feat/PBI-116-01-impl-pr-a`（Step 5 → 3 → 4）
- **モード**: high-risk
- **状態**: exec 中（PR #132 で Step 1+2 完了、本 PR で Step 3-5 完了、Step 6-8 は次 PR）

## C-3 Gate: APPROVED

- 判定: APPROVED（2026-04-30、s977043）
- 記録: [`approvals/c3.json`](./approvals/c3.json)
- plan_hash: `sha256:6632a42...`

## 現在のフェーズ

✅ Step 1 棚卸し完了 → [`evidence/inventory.md`](./evidence/inventory.md)
✅ Step 2 Core Contract 作成完了 → [`docs/ai/core-contract.md`](../../ai/core-contract.md)
✅ Baseline 記録完了 → [`evidence/baseline.md`](./evidence/baseline.md)

⏳ Step 3-6（既存ファイル薄型化）は次セッションで別 PR に分割

## PR-A 成果（Step 5 → 3 → 4）

### Step 5: project-rules.md 整合
- [x] T-15: Core Contract 参照と「正本責務の境界」セクション追加（A' セクション + G 参照表）

### Step 3: CLAUDE.md 薄型化
- [x] T-9: baseline 記録（43 行、`evidence/baseline.md`）
- [x] T-10: 書き換え（参照テーブル → 短い箇条書き、`<law>` 全文維持）
- [x] T-11: **21 行達成**（baseline 43 → 51% 削減、目標 22 以下 ✅）

### Step 4: AGENTS.md 薄型化
- [x] T-12: baseline 記録（61 行）
- [x] T-13: 書き換え（表 2 つ → 短い箇条書き、Progressive Disclosure 表は working-context.md 参照に統合）
- [x] T-14: **29 行達成**（baseline 61 → 52% 削減、目標 30 以下 ✅）

### リンク到達性検証
- [x] CLAUDE.md / AGENTS.md の全参照リンクが解決可能（手動 ls で確認）

## PR-B で実施（次 PR）

- T-16〜T-20: Step 6 hard-mandate 削減
- T-21〜T-24: Step 7 検証（grep / wc / lint）→ evidence/verification.md
- T-25〜T-28: Step 8 handoff + 子 PR

## 旧: 完了タスク（PR #132 = Step 1+2）

### 準備
- [x] T-1: Scope/受入基準の再確認
- [x] T-2: 既存 Iron Law 6 項目との対応特定（pbi-input.md 対応表で実施済）

### Step 1: 棚卸し
- [x] T-3: 64 ファイル grep 実行 → `evidence/inventory.md`
- [x] T-4: 削減候補を 3 段階分類（必須 7 / 推奨 1 / 保持 14 / 個別 4）

### Step 2: Core Contract 定義
- [x] T-5: skeleton 作成（8 セクション）
- [x] T-6: Hard constraints に Iron Law 7 項目を明示
- [x] T-7: Role / Goal / Success criteria / Decision rules / Available evidence / Stop rules / Output discipline 全セクション記述
- [x] T-8: セルフ検証（8 セクション完備、Iron Law 7 項目漏れなし）

## 未完了タスク（次セッション、別 PR）

### Step 3: CLAUDE.md 薄型化（T-9〜T-11）
### Step 4: AGENTS.md 薄型化（T-12〜T-14）
### Step 5: project-rules.md 整合（T-15）
### Step 6: hard-mandate 削減（T-16〜T-20）
### Step 7: 検証（T-21〜T-24）
### Step 8: handoff + PR（T-25〜T-28）

## 計画からの変更点

- **PR 分割**: T-1〜T-8 を本 PR、T-9〜T-28 を次 PR に分割
- **理由**: high-risk な既存ファイル編集（CLAUDE.md / AGENTS.md / その他）はレビュー粒度を別 PR に分けたほうが安全。本 PR は新規ファイル作成（core-contract.md / inventory.md / baseline.md）のみで影響範囲限定。

## 関連 PR

- PR #126〜#131（計画書 + Parent C-3 + 子 plan + C-2 + Child C-3）
- 本 PR（exec Step 1+2、新規ファイル 3 件）

## 次セッションのタスク（Codex 相談を反映）

### PR-A: Step 5 → Step 3 → Step 4（入口ファイル薄型化）

1. ブランチ `feat/PBI-116-01-impl-pr-a`（仮）
2. **Step 5**: project-rules.md に Core Contract 参照追加（責務境界明文化）
3. **Step 3**: CLAUDE.md を 21〜22 行へ薄型化（`<law>` 維持優先）
4. **Step 4**: AGENTS.md を 24〜28 行へ薄型化（表 → 短い箇条書き）
5. PR 作成 → C-4

### PR-B: Step 6 → Step 7 → Step 8（hard-mandate 削減 + 検証 + handoff）

1. ブランチ `feat/PBI-116-01-impl-pr-b`（仮）
2. **Step 6**: hard-mandate 削減（必須 7 件 + 推奨 1 件 + 個別 4 件）
3. **Step 7**: 検証（grep / wc / lint）→ evidence/verification.md
4. **Step 8**: handoff.md / 子 PR → Child C-4 ゲート

### 各 Step の Stop rule

[plan.md の Stop rules セクション](./plan.md#stop-rules) 参照
