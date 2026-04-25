# PlanGate ワークフロー & プロンプト集（v5 / v6 / v7）

> Claude Codeコマンド: `/ai-dev-workflow`（`.claude/commands/ai-dev-workflow.md`）
> PlanGate概要ガイド: [docs/plangate.md](plangate.md)
>
> **v7 ハイブリッドアーキテクチャ**: 本書の統制層を維持しつつ、実行層を Workflow/Skill/Agent 3 層で再構築したのが v7。詳細は [docs/plangate-v7-hybrid.md](./plangate-v7-hybrid.md) 参照。v5/v6 の運用を継続しつつ、段階的に v7 要素を opt-in 可能。

## 概要

PBI（プロダクトバックログアイテム）からPlan生成、レビュー、Agent実行、多層防御検証、PR作成までを体系化したワークフロー。
obra/superpowersの思想（Iron Law、合理化テーブル、2-5分粒度、TDD先行）をv3で取り込み、v4でtakt知見（マルチエージェント協調、V系検証ステップ）、v5でハーネスエンジニアリング知見（L-0リンター自動修正ループ）を統合。

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
#   → workflow-conductorがtodo.mdの🤖タスクを順に実行し、多層防御検証を経てPR作成まで自動で行う
```

**人間が行うのは2つだけ:**

- PBI情報の入力（ステップ2）
- plan/todo/test-casesの確認・承認（ステップ2→3の間）
- C-4: GitHub上でPRレビュー

---

## ワークフロー全体像

### 状態遷移（v5）

```
Ready → In Progress
  → 0: Brainstorming 🤖👤（対話的な要件整理・設計書生成、任意）
  → A: PBI INPUT PACKAGE作成 👤
  → B: Plan + ToDo + Test Cases同時生成 🤖
  → C-1: セルフレビュー 🤖（17項目チェック）
  → C-2: 外部AIレビュー 🤖（専門エージェント経由）
  → C-3: 人間レビュー 👤（三値ゲート：APPROVE / CONDITIONAL / REJECT）
  → D: Agent実行 🤖（workflow-conductor経由、TDD）
  → L-0: リンター自動修正 🤖（autofix → AI修正 → 抑制）
  → V-1: 受け入れ検査 🤖（test-cases.md突合）
  → V-2: コード最適化 🤖（high-risk/criticalモード）
  → V-3: 外部モデルレビュー 🤖
  → V-4: リリース前チェック 🤖（criticalモード）
  → PR作成 🤖
  → C-4: 人間レビュー 👤（GitHub上、APPROVE / REQUEST CHANGES / REJECT）
  → Done
```

> 👤 = 人間タスク / 🤖 = AIタスク / C-3, C-4 がゲート

### 各フェーズの成果物

| フェーズ | 成果物 | 作成者 |
| --- | --- | --- |
| 0: Brainstorming（任意） | pbi-input.md（対話で生成） | AI + 人間 |
| A: PBI INPUT PACKAGE作成 | pbi-input.md | 人間 |
| B: Plan + ToDo + Test Cases生成 | plan.md + todo.md + test-cases.md | AI（Prompt 1） |
| C-1: セルフレビュー | review-self.md（17項目PASS/WARN/FAIL） | AI（Prompt 2） |
| C-2: 外部AIレビュー | review-external.md（PASS/WARN/FAIL） | AI（専門エージェント経由） |
| C-3: 人間レビュー（ゲート） | APPROVE / CONDITIONAL / REJECT | 人間 |
| D: Agent実行（TDD） | 実装コード | AI（workflow-conductor） |
| L-0: リンター自動修正 | リンター通過済みコード | AI |
| V-1: 受け入れ検査 | PASS / FAIL | AI |
| V-2: コード最適化（フルのみ） | 最適化済みコード | AI |
| V-3: 外部モデルレビュー | レビュー結果 | AI |
| V-4: リリース前チェック（フルのみ） | チェック結果 | AI |
| PR作成 | Pull Request + status.md | AI |
| C-4: 人間レビュー（ゲート） | APPROVE / REQUEST CHANGES / REJECT | 人間 |

### タスク規模によるモード分岐

| モード | 対象 | 検証ステップ |
| --- | --- | --- |
| **ライト** | バグ修正・設定変更・1ファイル以内の変更 | L-0 → V-1 → V-3 → PR → C-4 |
| **フル** | 機能追加・リファクター・複数ファイル変更 | L-0 → V-1 → V-2 → V-3 → V-4 → PR → C-4 |

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

## 運用の最小ルール v5

1. Ready → In Progressに動かしたら**PBI INPUT PACKAGE**を作る
2. `/ai-dev-workflow TASK-XXXX plan`で**Plan + ToDo + Test Cases + セルフレビュー（17項目） + 外部AIレビュー**を一括生成
3. 人が**C-3レビュー**（三値判断: APPROVE → exec / CONDITIONAL → plan修正後exec / REJECT → plan再生成）
4. `/ai-dev-workflow TASK-XXXX exec`で**Agent実行**。workflow-conductorが多層防御（L-0→V-1→V-2→V-3→V-4→PR）まで自動管理
5. 人が**C-4レビュー**（GitHub上でPR確認。APPROVE → マージ / REQUEST CHANGES → exec再実行 / REJECT → plan再生成）

---

## ゲート条件

### C-3ゲート（計画承認・三値）

| 判断 | 意味 | 次のアクション |
| --- | --- | --- |
| **APPROVE** | 計画に問題なし | exec開始 |
| **CONDITIONAL** | 骨格は有効だが修正が必要 | 指摘をplan.mdに反映 + 簡易C-1再実行 → exec開始 |
| **REJECT** | 根本的な問題あり | plan再生成（Step 2に戻る） |

### C-4ゲート（PRレビュー・三値）

| 判断 | 意味 | 次のアクション |
| --- | --- | --- |
| **APPROVE** | PRに問題なし | マージ → Done |
| **REQUEST CHANGES** | 修正が必要 | execから再実行 |
| **REJECT** | 根本的な問題あり（稀） | planからやり直し |

### 共通ルール

- Planレビュー（C-3）が通るまで、エージェントの実行は禁止
- Agent指示書に「スコープ外はやらない」「不明点は止めて質問化」を明記
- 実行中はworkflow-conductorがtodo.md/status.mdをリアルタイム更新
- タスク完了の受理条件: todo.mdチェック更新 + status.md更新 + 完了条件の証拠

---

## タスク粒度の原則

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

## workflow-conductor（v5）

フェーズDの実行を管理する専用エージェント。定義: `.claude/agents/workflow-conductor.md`

### 8つの役割

| # | 役割 | 概要 |
|---|---|---|
| 1 | フェーズ遷移管理 | C-3承認なしにexecに進まないゲートキーパー。exec → L-0 → V-1〜V-4の遷移も制御 |
| 2 | 並列タスク実行判断 | todo.mdのdepends_onを分析し、独立タスクを並列委譲 |
| 3 | 変更伝播 | todo/test-cases変更時に後続タスク・レビューに反映。L-0/V-2でのコード変更もテスト確認対象 |
| 4 | チェック漏れ防止 | 証拠なしにタスク完了を受理しない。V-1/V-2の結果、L-0の完了ログを証拠として記録 |
| 5 | セッション復旧 | status.md/todo.mdから現在地を復元。V系ステップの進行状況も記録し、中断時にV-Nから再開可能 |
| 6 | fix loop管理 | V-1 FAIL時のfix loop回数カウント。最大5回でABORT → 人間判断へエスカレーション |
| 7 | モード分岐制御 | plan.mdのタスク規模に基づき、V-2/V-4のスキップ判定を自動実行（ライト/フル） |
| 8 | L-0管理 | exec完了後にリンター自動実行。autofix → AI修正ループ（最大3回）→ 抑制の3段階を制御 |

### exec以降の多層防御フロー

```
D: TDD実装（RED → GREEN → REFACTOR）
  ↓
L-0: リンター自動修正
  autofix実行 → autofix不可はAI修正（最大3回） → 解消しなければ抑制（noqa等）+ V-3申し送り
  ↓
V-1: 受け入れ検査
  test-cases.mdの完了条件を1つずつ機械的に突合
  FAIL → fix → L-0再実行 → V-1再実行（最大5回。超過時ABORT → 人間判断）
  ↓
V-2: コード最適化（high-risk/criticalモード）
  冗長コード削減・可読性向上。動作を変えない改善に限定。最適化後にテスト再実行
  ↓
V-3: 外部モデルレビュー
  外部AI（Gemini等）が設計品質をチェック。L-0で抑制した違反の申し送りも確認
  ↓
V-4: リリース前チェック（criticalモード）
  PR作成前の最終品質ゲート
  ↓
PR作成
  GitHubにPull Requestを自動作成
  ↓
C-4: 人間レビュー（GitHub上）
  APPROVE → マージ → Done / REQUEST CHANGES → execから再実行 / REJECT → planからやり直し
```

### エージェントのステータスコード

| コード | 意味 | conductor対応 |
|--------|------|-------------|
| DONE | 完了 | 次タスクへ |
| DONE_WITH_CONCERNS | 完了（懸念あり） | 懸念をstatus.mdに記録、次タスクへ |
| NEEDS_CONTEXT | 情報不足 | 追加情報を渡して再実行 |
| BLOCKED | 外部依存で停止 | ユーザーに報告、待機 |

---

## 振り返りメトリクス

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
  自動レビュー → PASS/WARN/FAIL判定（17項目）
       ↓
外部AIレビュー（専門エージェント経由）
  複数視点での並列チェック
       ↓ 人間がC-3で三値判断 → APPROVE / CONDITIONAL / REJECT
Prompt 3  Agent実行（workflow-conductor経由）
  Approved済みPlan + ToDo + Test Casesに従って実装
  → L-0 → V-1 → V-2 → V-3 → V-4 → PR作成
  → C-4（GitHub上で人間レビュー）
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

### Mode判定
**モード**: {ultra-light | light | standard | high-risk | critical}
> 判定基準の正本: `.claude/rules/mode-classification.md`

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

#### 検証フェーズ
- [ ] 🚩 T-N: typecheck/lint/test実行 [Owner: agent] [depends_on: 実装フェーズ最終タスク] [files: -]
- [ ] 🚩 T-N+1: 受入基準の全確認 [Owner: agent] [depends_on: T-N] [files: -]

#### 完了フェーズ
- [ ] 🚩 T-N+2: コミット作成 [Owner: agent] [depends_on: T-N+1] [files: -]
- [ ] 🚩 T-N+3: status.md最終更新 [Owner: agent] [depends_on: T-N+2] [files: status.md]

> 注: L-0〜V-4, PR作成はworkflow-conductorが自動制御するため、todo.mdには含めない。

### 👤 Humanタスク（人間が実行）
- [ ] C-3: Plan/ToDo/Test Casesの人間レビュー（exec前ゲート） [Owner: human]
- [ ] C-4: PRレビュー・承認（GitHub上） [Owner: human]

### ⚠️ 依存関係
- Agent実装 → Human C-3レビュー承認後にexec開始
- PR作成 → Human C-4レビュー承認後にマージ

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
8. タスク粒度: 各タスクが2〜5分で完了できる粒度か（必須）
9. depends_on設定: 依存関係が明示されているか（必須）
10. チェックポイント設定: 各StepにToDo更新タイミングが設定されているか（推奨）
11. Iron Law遵守: 承認前コード実行・スコープ逸脱の危険がないか（必須）
12. 完了条件: 各タスクに完了条件が記述されているか（推奨）

## TestCasesチェック（3項目）
13. 受入基準との紐付き: 全受入基準に対してテストケースがあるか（必須）
14. Edge case網羅: 境界値・異常系が設計されているか（必須）
15. 自動化可否: 手動テストのみでなく自動化できるか（推奨）

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
**出力:** 実装 + 多層防御検証 + PR

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

## 実装後の多層防御（workflow-conductorが自動制御）
D: TDD実装 → L-0: リンター自動修正 → V-1: 受け入れ検査 → V-2: コード最適化(フル) → V-3: 外部モデルレビュー → V-4: リリース前チェック(フル) → PR作成 → C-4: 人間レビュー

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
4. **TDD先行**: plan phaseでtest-cases.mdを生成し、C-1でテストケースの品質もレビュー（17項目化）
5. **workflow-conductor**: exec phaseの司令塔エージェント（並列実行判断・チェック漏れ防止・セッション復旧）
6. **振り返りメトリクス**: 計画精度/テスト品質/プロセス遵守/効率性/成果物品質の5軸評価

### v4改善（takt知見統合）

1. **C-3三値化**: APPROVE / CONDITIONAL / REJECT（CONDITIONALで柔軟なゲート通過）
2. **V-1〜V-4**: exec以降に多層防御の検証ステップ追加
3. **5段階モード分類**: タスク規模に応じた検証ステップの最適化（ultra-light/light/standard/high-risk/critical）
4. **C-4**: GitHub上での明示的なPRレビューゲート

### v5改善（ハーネスエンジニアリング知見統合）

1. **L-0リンター自動修正ループ**: exec完了後にリンター自動実行。autofix → AI修正（最大3回）→ 抑制+V-3申し送りの3段階制御
2. **workflow-conductor 8役割化**: fix loop管理・モード分岐制御・L-0管理を追加

---

## 関連ファイル

| 用途 | パス |
| --- | --- |
| PlanGateガイド | `docs/plangate.md` |
| メインコマンド | `.claude/commands/ai-dev-workflow.md` |
| workflow-conductor | `.claude/agents/workflow-conductor.md` |
| セルフレビュースキル | `.claude/skills/self-review/SKILL.md` |
| brainstormingスキル | `.claude/skills/brainstorming/SKILL.md` |
| SDDスキル | `.claude/skills/subagent-driven-development/SKILL.md` |
| debuggingスキル | `.claude/skills/systematic-debugging/SKILL.md` |
| 作業コンテキストルール | `.claude/rules/working-context.md` |
| レビュー原則 | `.claude/rules/review-principles.md` |
| テンプレート | `docs/working/TASK-XXXX/` |
