# 作業コンテキスト管理ルール

## 目的

セッション切れや日付またぎでコンテキストが失われることを防ぐ。
チケット単位で作業状態を `docs/working/` 配下にファイルとして保存し、次回セッションで即座に復元可能にする。

## AI駆動開発ワークフローとの対応

このルールは「AI駆動開発 ワークフロー v2」の各フェーズで生成される成果物を永続化する。
ワークフロー詳細: `docs/ai-driven-development.md`

```
Ready → In Progress
  → 0: Brainstorming 🤖👤（対話的な要件整理・設計書生成、任意）
  → A: PBI INPUT PACKAGE 作成 👤（または フェーズ0で自動生成）
  → B: Plan + ToDo 同時生成 🤖（Prompt 1）
  → C-1: セルフレビュー 🤖（Prompt 2）
  → C-2: 外部AIレビュー 🤖
  → C-3: 人間レビュー 👤（ゲート：通過するまでAgent実行禁止）
  → D: Agent実行 🤖（Prompt 3）
  → Done
```

## ディレクトリ構造

```
docs/working/
└── TASK-{ticket-number}/
    ├── pbi-input.md         # A: PBI INPUT PACKAGE（人間が作成）
    ├── plan.md              # B: EXECUTION PLAN（Prompt 1で生成）
    ├── todo.md              # B: EXECUTION TODO（Prompt 1で生成）
    ├── review-self.md       # C-1: セルフレビュー結果（Prompt 2で生成）
    ├── review-external.md   # C-2: 外部AIレビュー結果（任意）
    └── status.md            # D〜: 作業ステータス（随時更新）
```

## 各ファイルの役割

### pbi-input.md（PBI INPUT PACKAGE）

フェーズA で人間が作成。以下を含める：

- PBI概要（Why / What）
- 受け入れ条件
- 制約・スコープ
- 外部チケットURL（任意）

### plan.md（EXECUTION PLAN）

フェーズB（Prompt 1）で生成。以下を含める：

- Goal
- Constraints / Non-goals
- Approach Overview
- Work Breakdown（各Stepに Output / Owner / Risk / 🚩チェックポイント）
- Files / Components to Touch
- Testing Strategy（Unit / Integration / E2E / Verification Automation）
- Risks & Mitigations
- Questions / Unknowns

### todo.md（EXECUTION TODO）

フェーズB（Prompt 1）でplanと同時生成。以下を含める：

- 🤖 Agent タスク（準備 → 実装 → 検証 → 完了の4フェーズ）
- 👤 Human タスク
- ⚠️ 依存関係（Agent ↔ Human）
- 各タスクに Owner（agent / human）と 🚩チェックポイントを明記

### review-self.md（セルフレビュー結果）

フェーズC-1（Prompt 2）で生成。以下を含める：

- Plan チェック（7項目）: 受入基準網羅性、Unknowns処理、スコープ制御、テスト戦略、Work Breakdown Output、依存関係、動作検証自動化
- ToDo チェック（5項目）: Owner明確性、Agent/Human分離、実行順序、チェックポイント設定、動作検証タスクの具体性
- 判定: PASS / WARN / FAIL + 指摘事項

### review-external.md（外部AIレビュー結果）

フェーズC-2 で生成（任意）。外部AIツールによるレビュー結果。

### status.md（作業ステータス）

フェーズD以降で随時更新。以下を含める：

- **全体構成**: PR一覧（ブランチ名、状態）
- **各PRの実装状態**: コミット履歴、変更ファイル一覧
- **計画からの変更点**: リネーム、削除、設計変更などの差分を明記
- **残タスク**: チェックリスト形式（`- [ ]` / `- [x]`）
- **Claude Codeプロンプト**: 次の作業をClaude Codeに依頼する際のプロンプト（コンテキスト・背景・タスク込み）
- **参照ファイル一覧**: 関連ドキュメントへのパス

#### 段階別出力フォーマット

status.md の更新タイミングと記載内容を段階で分ける：

**開始時**（セッション開始・exec開始）:
- 現在のフェーズと残タスク数を記録
- 前回セッションからの変更点を確認・記載

**実装中**（各🚩チェックポイント通過時）:
- 完了したステップと変更ファイルを追記
- 計画からの逸脱があれば「計画からの変更点」に即記録
- 仮定した事項があれば明記

**終了時**（セッション終了・exec完了）:
- 実装結果サマリ: 完了した作業、変更ファイル一覧、実行したコマンド
- 検証結果: lint/test/typecheck の結果
- 既知の制約・リスク
- 次回セッション用の Claude Code プロンプト（コンテキスト・背景・具体的タスクを含む）

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

プロンプトに以下を必ず含める：

- `docs/working/TASK-XXXX/status.md` の参照指示
- 外部チケットURL（任意、Why / What の理解用）
- 命名変更など計画との差分の明示
- 具体的なタスクリスト

### ゲート条件（C-3通過前）

- `review-self.md`（C-1）のレビュー結果を人間が確認し、Approvedになるまで Agent実行（フェーズD）に進まない
- C-2（`review-external.md`）は任意。C-2をスキップする場合はC-1のみでApproved可
- FAILが出た場合は指摘事項を反映して plan.md / todo.md を再生成する
