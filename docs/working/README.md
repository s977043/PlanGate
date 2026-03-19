# docs/working/

チケット単位の作業コンテキストを保存するディレクトリ。

セッション切れや日付またぎでコンテキストが失われることを防ぎ、次回セッションで即座に復元可能にする。

## 使い方

```text
# セッション開始時: 作業状態を読み込む（存在しなければ新規作成）
/working-context TASK-XXXX

# セッション中断・終了時: status.mdを最新化
/working-context save

# 全チケットの作業状態一覧を表示
/working-context
```

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

- ルール定義: `.claude/rules/working-context.md`
- ワークフロー: `.claude/commands/ai-dev-workflow.md`
