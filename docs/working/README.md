# docs/working/

チケット単位の作業コンテキストを保存するディレクトリ。

セッション切れや日付またぎでコンテキストが失われることを防ぎ、次回セッションで即座に復元可能にする。

## PlanGateとの関係

本ディレクトリはPlanGate（ゲート型AI駆動開発ワークフロー）の成果物を格納する。
PlanGateの全体像・設計思想については [`docs/plangate.md`](../plangate.md) を参照。

## 使い方

```text
# セッション開始時: 作業状態を読み込む（存在しなければ新規作成）
/working-context TASK-XXXX

# セッション中断・終了時: status.mdを最新化
/working-context save

# 全チケットの作業状態一覧を表示
/working-context
```

## 状態遷移（PlanGate v5）

```text
Ready
  → A: PBI INPUT PACKAGE 作成 👤
  → B: Plan + ToDo + TestCases 生成 🤖（/ai-dev-workflow TASK-XXXX plan）
  → C-1: セルフレビュー（15項目）🤖
  → C-2: 外部AIレビュー 🤖
  → C-3: 人間レビュー 👤（三値ゲート: APPROVE / CONDITIONAL / REJECT）
  → D: Agent実行（TDD）🤖（/ai-dev-workflow TASK-XXXX exec）
  → L-0: リンター自動修正ループ 🤖
  → V-1: 受け入れ検査 🤖
  → V-2: コード最適化 🤖（フルモードのみ）
  → V-3: 外部モデルレビュー 🤖
  → V-4: リリース前チェック 🤖（フルモードのみ）
  → PR作成 🤖
  → C-4: PRレビュー・承認 👤（GitHub上）
  → Done
```

> C-3がゲート（通過するまでAgent実行禁止）。L-0〜V-4, PR作成, C-4はworkflow-conductorが自動制御。

## ディレクトリ構造

```text
docs/working/
├── README.md                    # このファイル
├── TASK-XXXX/                   # テンプレート
│   ├── pbi-input.md             # PBI INPUT PACKAGE
│   ├── plan.md                  # EXECUTION PLAN
│   ├── todo.md                  # EXECUTION TODO
│   ├── test-cases.md            # テストケース定義
│   ├── review-self.md           # セルフレビュー結果
│   ├── review-external.md       # 外部AIレビュー結果
│   └── status.md                # 作業ステータス
└── TASK-{ticket-number}/        # 実際の作業ディレクトリ
    ├── pbi-input.md             # A: PBI INPUT PACKAGE（人間が作成）
    ├── plan.md                  # B: EXECUTION PLAN（AI生成）
    ├── todo.md                  # B: EXECUTION TODO（AI生成）
    ├── test-cases.md            # B: テストケース定義（AI生成）
    ├── review-self.md           # C-1: セルフレビュー結果
    ├── review-external.md       # C-2: 外部AIレビュー結果（任意）
    └── status.md                # D〜: 作業ステータス（随時更新）
```

## 詳細ルール

- PlanGateガイド: `docs/plangate.md`
- ルール定義: `.claude/rules/working-context.md`
- ワークフロー: `.claude/commands/ai-dev-workflow.md`
