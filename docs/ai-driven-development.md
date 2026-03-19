# AI駆動開発 ワークフロー & プロンプト集

> Claude Codeコマンド: `/ai-dev-workflow`（`.claude/commands/ai-dev-workflow.md`）

## 概要

PBI（プロダクトバックログアイテム）からPlan生成、レビュー、Agent実行までを体系化したワークフロー。
obra/superpowersの思想（Iron Law、合理化テーブル、2-5分粒度、TDD先行）を取り込んだv3。

---

## クイックスタート（コマンド3つで完了）

```bash
# 1. 作業コンテキスト作成（初回のみ）
/working-context TASK-XXXX

# 2. Plan生成 → セルフレビュー → 外部AIレビュー（一括自動実行）
/ai-dev-workflow TASK-XXXX plan
#   → pbi-input.md / plan.md / todo.md / test-cases.md / review-self.md / review-external.md が生成される

# 3. 人間レビュー（C-3）で plan.md / todo.md / test-cases.md を確認・承認後、Agent実行
/ai-dev-workflow TASK-XXXX exec
#   → workflow-conductorがtodo.mdの🤖タスクを順に実行し、PR作成まで自動で行う
```

**人間が行うのは2つだけ:**

- PBI情報の入力（ステップ2）
- plan/todo/test-casesの確認・承認（ステップ2→3の間）

---

## ワークフロー全体像

### 状態遷移（v3）

```
Ready → In Progress
  → 0: Brainstorming 🤖👤（対話的な要件整理・設計書生成、任意）
  → A: PBI INPUT PACKAGE作成 👤
  → B: Plan + ToDo + Test Cases同時生成 🤖
  → C-1: セルフレビュー 🤖（15項目チェック）
  → C-2: 外部AIレビュー 🤖（利用可能なサブエージェント経由）
  → C-3: 人間レビュー 👤（ゲート：通過するまでAgent実行禁止）
  → D: Agent実行 🤖（workflow-conductor経由）
  → Done
```

> 👤 = 人間タスク / 🤖 = AIタスク / C-3がゲート（通過するまでAgent実行禁止）

### 各フェーズの成果物

| フェーズ | 成果物 | 作成者 |
| --- | --- | --- |
| 0: Brainstorming（任意） | pbi-input.md（対話で生成） | AI + 人間 |
| A: PBI INPUT PACKAGE作成 | pbi-input.md | 人間 |
| B: Plan + ToDo + Test Cases生成 | plan.md + todo.md + test-cases.md | AI（Prompt 1） |
| C-1: セルフレビュー | review-self.md（15項目PASS/WARN/FAIL） | AI（Prompt 2） |
| C-2: 外部AIレビュー | review-external.md（PASS/WARN/FAIL） | AI（サブエージェント経由） |
| C-3: 人間レビュー（ゲート） | Approved / Changes required | 人間 |
| D: Agent実行 | 実装 + PR + status.md | AI（workflow-conductor） |

---

## Iron Law（各フェーズの不可侵ルール）

obra/superpowersから取り込んだ最上位ルール。違反したら即停止。

| フェーズ/スキル | Iron Law |
| --- | --- |
| brainstorming | `NO CODE WITHOUT APPROVED DESIGN FIRST` |
| plan（フェーズB） | `NO EXECUTION WITHOUT REVIEWED PLAN FIRST` |
| exec（フェーズD） | `NO SCOPE CHANGE WITHOUT USER APPROVAL` |
| subagent-driven-development | `NO MERGE WITHOUT TWO-STAGE REVIEW` |
| self-review | `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE` |
| systematic-debugging | `NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST` |

---

## 運用の最小ルール v3

1. Ready → In Progressに動かしたら**PBI INPUT PACKAGE**を作る
2. `/ai-dev-workflow TASK-XXXX plan`で**Plan + ToDo + Test Cases + セルフレビュー + 外部AIレビュー**を一括生成
3. 人が**最終レビュー**（C-1 + C-2の結果を踏まえて判断。plan/todo/test-casesを確認。通るまでAgent実行禁止）
4. `/ai-dev-workflow TASK-XXXX exec`で**Agent実行**。workflow-conductorがToDoの🤖タスクを管理・実行
5. 完了時は**受入基準チェック結果 + 動作検証ログ + 振り返りメトリクス**を添付する

---

## ゲート条件

- Planレビューが通るまで、エージェントの実行は禁止
- Agent指示書に「スコープ外はやらない」「不明点は止めて質問化」を明記
- 実行中はworkflow-conductorがtodo.md/status.mdをリアルタイム更新
- タスク完了の受理条件: todo.mdチェック更新 + status.md更新 + 完了条件の証拠

---

## タスク粒度の原則（v3追加）

各タスクは**2-5分で完了する1アクション**に分解する。

良い例:

- 「Image.test.tsxにASCII URLのテストを追加する」
- 「テスト実行し、FAILを確認する」
- 「Image.tsxにsafeSrc変数を追加する」

悪い例:

- 「テストを書いて実装する」（複数アクション）
- 「Image関連の修正」（曖昧）

---

## 成果物の保存先

```
docs/working/
└── TASK-{ticket-number}/
    ├── pbi-input.md         # A: PBI INPUT PACKAGE（人間が作成）
    ├── plan.md              # B: EXECUTION PLAN（Prompt 1で生成）
    ├── todo.md              # B: EXECUTION TODO（Prompt 1で生成）
    ├── test-cases.md        # B: テストケース定義（Prompt 1で生成）
    ├── review-self.md       # C-1: セルフレビュー結果（Prompt 2で生成）
    ├── review-external.md   # C-2: 外部AIレビュー結果（任意）
    └── status.md            # D〜: 作業ステータス（随時更新）
```

テンプレート: `docs/working/TASK-XXXX/`
詳細ルール: `.claude/rules/working-context.md`

---

## workflow-conductor（v3追加）

フェーズDの実行を管理する専用エージェント。定義: `.claude/agents/workflow-conductor.md`

### 5つの役割

| # | 役割 | 概要 |
|---|---|---|
| 1 | フェーズ遷移管理 | ゲートキーパー型。C-3承認なしにexecに進まない |
| 2 | 並列タスク実行判断 | todo.mdのdepends_onを分析し、独立タスクを並列委譲 |
| 3 | 変更伝播 | todo/test-cases変更時に後続タスク・レビューに反映 |
| 4 | チェック漏れ防止 | 証拠なしにタスク完了を受理しない |
| 5 | セッション復旧 | status.md/todo.mdから現在地を復元し、中断タスクから再開 |

### exec実行フロー

```
準備 → 実装 → セルフレビュー① → 検証 → E2E → セルフレビュー② → コードレビュー → 完了
```

- **セルフレビュー①**（実装直後・検証前）: `/self-review`でロジック正確性・データフロー・残骸・エッジケースを確認
- **検証フェーズ**: typecheck/lint/test実行
- **E2E検証**: プロジェクトの検証手段に応じて実施
- **セルフレビュー②**（検証後・PR前）: CI互換性・コミット衛生・テスト網羅性を最終確認
- **コードレビュー**: 利用可能なサブエージェントで複数視点のコードレビュー

### サブエージェントのステータスコード

| コード | 意味 | conductor対応 |
|--------|------|-------------|
| DONE | 完了 | 次タスクへ |
| DONE_WITH_CONCERNS | 完了（懸念あり） | 懸念をstatus.mdに記録、次タスクへ |
| NEEDS_CONTEXT | 情報不足 | 追加情報を渡して再実行 |
| BLOCKED | 外部依存で停止 | ユーザーに報告、待機 |

---

## 振り返りメトリクス（v3追加）

exec完了時にconductorが自動収集し、status.mdに追記する。

### 評価軸（配点100点）

| 観点 | 配点 | 評価基準 |
|------|------|---------|
| 計画精度 | 15 | 想定粒度と実績の乖離、計画変更の有無 |
| テスト品質 | 15 | test-cases.mdの網羅性、RED-GREEN成功率 |
| プロセス遵守 | 15 | Iron Law違反の有無、チェック漏れ |
| 効率性 | 25 | 並列実行活用度、セッション復旧の円滑さ |
| 成果物品質 | 30 | レビュー指摘数、CI通過率、受入基準充足度 |

### タスク実行ログ

| タスクID | 想定粒度 | 実績 | 差分理由 |
|---------|---------|------|---------|
| T-1 | 2-5分 | 2-5分 | — |
| T-2 | 2-5分 | 10分超 | 依存関係が未検出だった |

---

## ClaudeCodeプロンプト集（各フェーズ用）

`{{...}}`を実際の値に置き換えて使用する。

### プロンプトの流れ

```
Prompt 1  Plan + ToDo + Test Cases生成
  人間がPBI INPUT PACKAGEを渡す → Plan + ToDo + Test Casesを同時出力
       ↓
Prompt 2  Plan + ToDo + Test Casesレビュー（セルフレビュー）
  自動レビュー → PASS/WARN/FAIL判定（15項目）
       ↓
外部AIレビュー（利用可能なサブエージェント経由）
  複数視点での並列チェック
       ↓ 人間が最終判断 → Approved
Prompt 3  Agent実行（workflow-conductor経由）
  Approved済みPlan + ToDo + Test Casesに従って実装・PR作成
```

> `/ai-dev-workflow TASK-XXXX plan`を使えば、Prompt 1 → 2 → 外部AIレビューが一括自動実行される。

---

### Prompt 1: Plan + ToDo + Test Cases生成

**タイミング:** In Progressに移動した直後
**入力:** PBI INPUT PACKAGE
**出力:** EXECUTION PLAN + EXECUTION TODO + TEST CASES

```
# タスク情報
チケットURL: {{TICKET_URL}}（任意）
PBIタイトル: {{PBI_TITLE}}

# 指示
以下のPBI INPUT PACKAGEを読み、3つの成果物を作成してください。

---

# 成果物① EXECUTION PLAN（実行計画）

「作文」ではなく「実行可能な計画」を作成すること。

## フォーマット

### Goal
### Constraints / Non-goals
### Approach Overview

### Work Breakdown (Steps)
各Stepに以下を必ず含めること：
1. Step:
   - Output:（具体的な成果物。ないStep＝Planが抽象的な証拠）
   - Owner: agent / human（曖昧にしない）
   - Risk: 低 / 中 / 高
   - 🚩 チェックポイント:

### Files / Components to Touch

### Testing Strategy
- Unit:
- Integration:
- E2E:
- Edge cases:
- Verification Automation:

### Risks & Mitigations
### Questions / Unknowns

---

# 成果物② EXECUTION TODO（実行タスク）

Work Breakdownを「2-5分粒度の実行可能なタスクリスト」に変換する。
最重要ルール: 各タスクのOwner（agent / human）を必ず明記すること。
各タスクに `depends_on`（依存タスクID）と `files`（変更対象ファイル）を含めること。

### 🤖 Agentタスク（エージェントが実行）

#### 準備フェーズ
- [ ] 🚩 T-1: Scope/受入基準を再掲し、作業範囲を固定する [Owner: agent] [depends_on: -] [files: -]

#### 実装フェーズ（TDD: RED → GREEN → REFACTOR）
- [ ] 🚩 T-2: {テスト記述} [Owner: agent] [depends_on: T-1] [files: {test file}]
- [ ] 🚩 T-3: {テスト実行しFAIL確認} [Owner: agent] [depends_on: T-2] [files: -]
- [ ] 🚩 T-4: {最小実装} [Owner: agent] [depends_on: T-3] [files: {src file}]
- [ ] 🚩 T-5: {テスト実行しPASS確認} [Owner: agent] [depends_on: T-4] [files: -]

#### セルフレビュー①
- [ ] 🚩 T-N: /self-review実行（ロジック正確性・データフロー・残骸・エッジケース確認） [Owner: agent] [depends_on: 実装フェーズ最終タスク] [files: -]

#### 検証フェーズ
- [ ] 🚩 T-N+1: typecheck/lint/test実行 [Owner: agent] [depends_on: T-N] [files: -]
- [ ] 🚩 T-N+2: 受入基準の全確認 [Owner: agent] [depends_on: T-N+1] [files: -]

#### E2E検証
- [ ] 🚩 T-N+3: E2E検証（プロジェクトの検証手段に応じて実施） [Owner: agent] [depends_on: T-N+2] [files: -]

#### セルフレビュー②
- [ ] 🚩 T-N+4: /self-review実行（CI互換性・コミット衛生・テスト網羅性確認） [Owner: agent] [depends_on: T-N+3] [files: -]

#### コードレビュー
- [ ] 🚩 T-N+5: 利用可能なサブエージェントで複数視点コードレビュー [Owner: agent] [depends_on: T-N+4] [files: -]

#### 完了フェーズ
- [ ] 🚩 T-N+6: コミット作成 [Owner: agent] [depends_on: T-N+5] [files: -]
- [ ] 🚩 T-N+7: PR作成 [Owner: agent] [depends_on: T-N+6] [files: -]
- [ ] 🚩 T-N+8: status.md最終更新 [Owner: agent] [depends_on: T-N+7] [files: status.md]

### 👤 Humanタスク（人間が実行）
- [ ] C-3: Plan/ToDo/Test Casesの人間レビュー（exec前ゲート） [Owner: human]
- [ ] PRレビュー・承認 [Owner: human]

### ⚠️ 依存関係
- Agent実装 → Human C-3レビュー承認後にexec開始
- PR作成 → Human PRレビュー承認後にマージ

---

# 成果物③ TEST CASES（テストケース定義）

受入基準から具体的なテストケースを導出する。

### 受入基準 → テストケース マッピング
| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|

### テストケース一覧

#### TC-1: {テスト名}
- 前提条件: {セットアップ}
- 入力: {具体的な入力値}
- 期待出力: {具体的な期待値}
- 種別: Unit / Integration / E2E

### エッジケース

#### TC-E1: {エッジケース名}
- 前提条件: ...
- 入力: ...
- 期待出力: ...

## PBI INPUT PACKAGE
{{PBI_INPUT_PACKAGEの内容をここに貼る}}
```

---

### Prompt 2: Plan + ToDo + Test Casesレビュー（セルフレビュー）

**タイミング:** Prompt 1の出力後（`/ai-dev-workflow plan`では自動実行）
**入力:** EXECUTION PLAN + EXECUTION TODO + TEST CASES + PBI INPUT PACKAGE
**出力:** レビュー結果（PASS/WARN/FAIL）

```
# タスク情報
チケットURL: {{TICKET_URL}}（任意）
PBIタイトル: {{PBI_TITLE}}

# 指示
あなたはPlan Review Agentです。
EXECUTION PLAN、EXECUTION TODO、TEST CASESを、PBI INPUT PACKAGEの受入基準と照らし合わせてレビューしてください。

## Planチェック（7項目）
1. 受入基準網羅性
2. Unknowns処理
3. スコープ制御
4. テスト戦略
5. Work Breakdown Output
6. 依存関係
7. 動作検証自動化

## ToDoチェック（5項目）
8. Owner明確性: 全タスクにagent/humanが明記されているか
9. Agent/Human分離: 明確に分かれているか
10. タスクの実行順序: 依存関係に矛盾がないか
11. チェックポイント設定: 各タスクに🚩があるか
12. 動作検証タスクの具体性: コマンド/期待結果があるか

## テストケースチェック（3項目）
13. 受入基準→テストケースの網羅性: 全受入基準に対応するテストケースがあるか
14. テストケースの具体性: 入力値・期待値が具体的か（「正しく動作する」ではなく値レベル）
15. エッジケースの考慮: 境界値・異常系・空入力が含まれているか

## 出力: PASS/WARN/FAIL + 指摘事項

## EXECUTION PLAN
{{EXECUTION_PLANの内容}}

## EXECUTION TODO
{{EXECUTION_TODOの内容}}

## TEST CASES
{{TEST_CASESの内容}}

## PBI INPUT PACKAGE
{{PBI_INPUT_PACKAGEの内容}}
```

---

### Prompt 3: Agent実行

**タイミング:** C-3 Approved後
**入力:** EXECUTION PLAN + EXECUTION TODO + TEST CASES
**出力:** 実装 + PR

```
# タスク情報
チケットURL: {{TICKET_URL}}（任意）
PBIタイトル: {{PBI_TITLE}}

# 指示
EXECUTION PLAN、EXECUTION TODO、TEST CASESに従って実装してください。

## Iron Law
NO SCOPE CHANGE WITHOUT USER APPROVAL

## 絶対ルール
1. TODOの「🤖 Agentタスク」だけを実行する。「👤 Humanタスク」には手を出さない
2. スコープ外はやらない
3. 不明点は即座に停止
4. 🚩チェックポイントでtodo.md更新・動作検証を実施（リアルタイム更新）
5. 変更点は差分で説明
6. テストコードだけでなく実際に動かして確認
7. TDD: test-cases.mdに基づいてテスト先行（RED → GREEN → REFACTOR）

## 実行フロー
準備 → 実装 → セルフレビュー① → 検証 → E2E → セルフレビュー② → コードレビュー → 完了

## Required Outputs
- PR概要 / 受入基準チェック結果 / テスト結果 / 動作検証結果 / リスク・懸念 / 振り返りメトリクス

## EXECUTION PLAN（Approved済み）
{{PLANの内容}}

## EXECUTION TODO（Approved済み）
{{TODOの内容}}

## TEST CASES（Approved済み）
{{TEST_CASESの内容}}
```

---

## フィードバック反映事項

### v2改善

1. **動作検証の自動化**: PLANに「Verification Automation」セクション追加
2. **実行計画のWチェック自動化**: C-1 + C-2の2段階チェック
3. **チェックポイントの明確化**: 全テンプレートに🚩マーク導入
4. **確認の最小化**: サブコマンド実行自体を承認とみなす

### v3改善（superpowers思想取り込み）

1. **Iron Law**: 各スキル/サブコマンドに不可侵の最上位ルール（6つ）
2. **合理化テーブル**: AIが「スキップしよう」と合理化するパターンを先回りして封じる
3. **2-5分粒度原則**: todo.md生成時のタスク分解粒度を定義
4. **TDD先行**: plan phaseでtest-cases.mdを生成し、C-1でテストケースの品質もレビュー（15項目化）
5. **workflow-conductor**: exec phaseの司令塔エージェント（並列実行判断・チェック漏れ防止・セッション復旧）
6. **振り返りメトリクス**: 計画精度/テスト品質/プロセス遵守/効率性/成果物品質の5軸評価

---

## 関連ファイル

| 用途 | パス |
| --- | --- |
| メインコマンド | `.claude/commands/ai-dev-workflow.md` |
| workflow-conductor | `.claude/agents/workflow-conductor.md` |
| セルフレビュースキル | `.claude/skills/self-review/SKILL.md` |
| brainstormingスキル | `.claude/skills/brainstorming/SKILL.md` |
| SDDスキル | `.claude/skills/subagent-driven-development/SKILL.md` |
| debuggingスキル | `.claude/skills/systematic-debugging/SKILL.md` |
| 作業コンテキストルール | `.claude/rules/working-context.md` |
| レビュー原則 | `.claude/rules/review-principles.md` |
| テンプレート | `docs/working/TASK-XXXX/` |
