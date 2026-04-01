# 作業コンテキスト管理ルール

## 目的

セッション切れや日付またぎでコンテキストが失われることを防ぐ。
チケット単位で作業状態を `docs/working/` 配下にファイルとして保存し、次回セッションで即座に復元可能にする。

## PlanGateワークフローとの対応

このルールはPlanGateワークフロー v5の各フェーズで生成される成果物を永続化する。
PlanGateガイド: `docs/plangate.md`
ワークフロー詳細: `docs/ai-driven-development.md`

```text
Ready → In Progress
  → 0: Brainstorming 🤖👤（対話的な要件整理・設計書生成、任意）
  → A: PBI INPUT PACKAGE作成 👤
  → B: Plan + ToDo + Test Cases同時生成 🤖
  → C-1: セルフレビュー 🤖（15項目チェック）
  → C-2: 外部AIレビュー 🤖
  → C-3: 人間レビュー 👤（三値ゲート: APPROVE / CONDITIONAL / REJECT）
  → D: Agent実行 🤖（TDD）
  → L-0: リンター自動修正 🤖
  → V-1: 受け入れ検査 🤖
  → V-2: コード最適化 🤖（フルモードのみ）
  → V-3: 外部モデルレビュー 🤖
  → V-4: リリース前チェック 🤖（フルモードのみ）
  → PR作成 🤖
  → C-4: 人間レビュー 👤（GitHub上: APPROVE / REQUEST CHANGES / REJECT）
  → Done
```

## ディレクトリ構造

```text
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

## 各ファイルの役割

### pbi-input.md（PBI INPUT PACKAGE）

フェーズAで人間が作成。以下を含める:

- Context / Why（なぜやるか）
- What（Scope）: In scope / Out of scope
- 受入基準
- Notes from Refinement（議論で決まったこと）
- Estimation Evidence: Risks / Unknowns / Assumptions

### plan.md（EXECUTION PLAN）

フェーズB（Prompt 1）で生成。以下を含める:

- Goal
- Constraints / Non-goals
- Approach Overview
- Work Breakdown（各Stepに Output / Owner / Risk / 🚩チェックポイント）
- Files / Components to Touch
- Testing Strategy（Unit / Integration / E2E / Verification Automation）
- Risks & Mitigations
- Questions / Unknowns
- Mode判定（ライト / フル）

### todo.md（EXECUTION TODO）

フェーズB（Prompt 1）でplanと同時生成。以下を含める:

- 🤖 Agentタスク（準備 → 実装 → 検証 → 完了の4フェーズ）
- 👤 Humanタスク（C-3: exec前ゲート、C-4: PRレビュー）
- ⚠️ 依存関係（Agent ↔ Human）
- 各タスクに Owner（agent / human）と 🚩チェックポイントを明記
- L-0〜V-4, PR作成はworkflow-conductorが自動制御するため含めない

### test-cases.md（テストケース定義）

フェーズB（Prompt 1）でplanと同時生成。以下を含める:

- 受入基準 → テストケースマッピング
- テストケース一覧（前提条件 / 入力 / 期待出力 / 種別）
- エッジケース

### review-self.md（セルフレビュー結果）

フェーズC-1（Prompt 2）で生成。以下を含める:

- Planチェック（7項目）: 受入基準網羅性、Unknowns処理、スコープ制御、テスト戦略、Work Breakdown Output、依存関係、動作検証自動化
- ToDoチェック（5項目）: タスク粒度、depends_on設定、チェックポイント設定、Iron Law遵守、完了条件
- TestCasesチェック（3項目）: 受入基準との紐付き、Edge case網羅、自動化可否
- 判定: PASS / WARN / FAIL + 指摘事項

### review-external.md（外部AIレビュー結果）

フェーズC-2で生成（任意）。外部AIツールによるレビュー結果。

### status.md（作業ステータス）

フェーズD以降で随時更新。以下を含める:

- **全体構成**: PR一覧（ブランチ名、状態）
- **各PRの実装状態**: コミット履歴、変更ファイル一覧
- **計画からの変更点**: リネーム、削除、設計変更などの差分を明記
- **残タスク**: チェックリスト形式（`- [ ]` / `- [x]`）
- **V系ステップ進捗**: L-0/V-1〜V-4の完了状況
- **モード判定結果**: ライト / フル
- **Claude Codeプロンプト**: 次の作業をClaude Codeに依頼する際のプロンプト（コンテキスト・背景・タスク込み）
- **参照ファイル一覧**: 関連ドキュメントへのパス

#### 段階別出力フォーマット

status.mdの更新タイミングと記載内容を段階で分ける:

**開始時**（セッション開始・exec開始）:
- 現在のフェーズと残タスク数を記録
- 前回セッションからの変更点を確認・記載

**実装中**（各🚩チェックポイント通過時）:
- 完了したステップと変更ファイルを追記
- 計画からの逸脱があれば「計画からの変更点」に即記録
- 仮定した事項があれば明記

**終了時**（セッション終了・exec完了）:
- 実装結果サマリ: 完了した作業、変更ファイル一覧、実行したコマンド
- 検証結果: lint/test/typecheckの結果
- V系ステップ結果: L-0/V-1〜V-4の結果サマリ
- 既知の制約・リスク
- 次回セッション用のClaude Codeプロンプト（コンテキスト・背景・具体的タスクを含む）

## 運用ルール

### セッション開始時

1. 対象チケットの `docs/working/TASK-XXXX/` が存在するか確認する
2. 存在すれば `status.md` を読み、現在の状態を把握してから作業を開始する
3. `plan.md` / `todo.md` も参照し、当初計画と現在の実装の差分を認識する

### 作業中

- 計画から逸脱する変更（リネーム、機能削除、設計変更）が発生した場合、`status.md` の「計画からの変更点」セクションに記録する
- タスク完了時は `todo.md` と `status.md` の残タスクチェックリストを更新する

### セッション終了時・中断時

- `status.md` を最新の状態に更新する
- 特に「残タスク」と「Claude Codeプロンプト」が次回セッションで使えるよう整備する

### Claude Codeへの作業委譲時

プロンプトに以下を必ず含める:

- `docs/working/TASK-XXXX/status.md` の参照指示
- 外部チケットURL（任意、Why / Whatの理解用）
- 命名変更など計画との差分の明示
- 具体的なタスクリスト

### ゲート条件

#### C-3ゲート（計画承認・三値）

- `review-self.md`（C-1）と`review-external.md`（C-2）のレビュー結果を人間が確認
- 三値で判断:
  - **APPROVE**: exec開始。status.mdに`## C-3 Gate: APPROVED`を記録
  - **CONDITIONAL**: 指摘をplan.mdに反映 + 簡易C-1再実行 → exec開始。status.mdに`## C-3 Gate: CONDITIONAL`を記録
  - **REJECT**: plan再生成。status.mdに`## C-3 Gate: REJECTED`を記録
- C-2（`review-external.md`）は任意。C-2をスキップする場合はC-1のみで判断可
- FAILが出た場合は指摘事項を反映してplan.md / todo.md / test-cases.mdを再生成する

#### C-4ゲート（PRレビュー・三値）

- GitHub上でPRをレビュー
- **APPROVE**: マージ → Done
- **REQUEST CHANGES**: 指摘内容に基づきexecから再実行
- **REJECT**: planからやり直し（稀）
