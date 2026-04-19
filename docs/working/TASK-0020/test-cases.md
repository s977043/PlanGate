# TASK-0020 テストケース定義

> 生成日: 2026-04-19

## 受入基準 → テストケース マッピング

| 受入基準 | テストケースID | 種別 |
|---------|--------------|------|
| Root README に plugin 導入セクション追加 | TC-1 | Unit |
| README に新旧導入方法差分が表形式で記載 | TC-2 | Unit |
| README で Codex CLI 対象外が明記 | TC-3 | Unit |
| docs/plangate-plugin-migration.md が新規作成 | TC-4 | Unit |
| migration note に背景・同梱範囲・対象外理由・将来計画を記載 | TC-5 | Integration |
| plugin 内 README 本文完成（プレースホルダー解消） | TC-6 | Unit |
| plugin 内 README にインストール手順と使用例 | TC-7 | Integration |
| ドキュメント間の相互参照リンクが正しい | TC-8 | Integration |
| 新旧導入差分を一目で把握できる表現 | TC-9 | Manual Review |

## テストケース一覧

### TC-1: Root README plugin 導入セクション存在

- **前提条件**: TASK-0019 完了
- **入力**: `grep -c "plugin" README.md`
- **期待出力**: 1 以上、plugin 導入セクションの見出しが存在
- **種別**: Unit

### TC-2: 新旧導入方法差分表存在

- **前提条件**: TC-1 パス
- **入力**: README.md 内容確認
- **期待出力**: 以下を含む表形式記述
  - 導入方法（従来 / plugin）
  - 同梱範囲
  - アップデート方法
  - 対象ユーザー
- **種別**: Unit

### TC-2a: 同梱 skills/agents/rules 一覧記載

- **前提条件**: TC-1 パス
- **入力**: README.md 内容確認
- **期待出力**: 以下が記載されている
  - 同梱 7 skills（working-context, ai-dev-workflow, brainstorming, self-review, pr-review-response, pr-code-review, setup-team）の一覧と役割
  - 同梱 8 agents（workflow-conductor 〜 release-manager）の一覧と役割
- **種別**: Unit

### TC-2b: 未同梱 agents の理由・入手方法記載

- **前提条件**: TC-1 パス
- **入力**: README.md 内容確認
- **期待出力**: 未同梱 agents（`backend-specialist`, `frontend-specialist` 等）が「プロジェクト固有前提のため汎用配布に含めない」旨と、既存 `.claude/agents/` で入手可能な旨が記載
- **種別**: Unit

### TC-3: Codex CLI 対象外明記

- **前提条件**: TC-1 パス
- **入力**: `grep -i "codex" README.md`
- **期待出力**: 「Codex CLI は対象外」等の記述が含まれる
- **種別**: Unit

### TC-4: migration note 存在

- **前提条件**: Step 4 完了
- **入力**: `test -f docs/plangate-plugin-migration.md && wc -l docs/plangate-plugin-migration.md`
- **期待出力**: ファイル存在、50 行以上（最低限の情報量）
- **種別**: Unit

### TC-5: migration note 必須セクション

- **前提条件**: TC-4 パス
- **入力**: migration note の見出し抽出 `grep "^##" docs/plangate-plugin-migration.md`
- **期待出力**: 以下のセクションが含まれる
  - 背景・目的
  - デュアル運用の前提
  - 同梱範囲（詳細）
  - 対象外（プロジェクト固有 agents 等）の理由
  - 将来計画（marketplace 想定）
  - 既存利用者向け移行手順
- **種別**: Integration

### TC-6: plugin 内 README プレースホルダー解消

- **前提条件**: TASK-0017 でプレースホルダー作成済み、本 TASK で本文化
- **入力**: `grep "プレースホルダー\|TASK-0020 で完成予定" plugin/plangate/README.md`
- **期待出力**: 0 件（プレースホルダー文言が残っていない）
- **種別**: Unit

### TC-7: plugin 内 README 必須セクション

- **前提条件**: TC-6 パス、T-2a で install syntax が `evidence/install-syntax-reference.md` に確定済み
- **入力**: plugin README の見出し確認
- **期待出力**: 以下のセクションが含まれ、install syntax は `evidence/install-syntax-reference.md` と一致
  - インストール手順（TASK-0017 成果物から固定した syntax を使用）
  - 基本使い方（呼び出し例、TASK-0018 で確定した `plangate:...` 形式）
  - 同梱 skills / agents / rules 一覧
  - トラブルシュート
- **種別**: Integration

### TC-8: ドキュメント間リンク整合（手動確認）

- **前提条件**: TC-1, TC-4, TC-6 パス、T-8a で `evidence/link-verification.md` に結果記録済み
- **入力**: 各 md の相対リンクを Read ツールで辿り、リンク先ファイルの存在を確認（外部ツール `markdown-link-check` 等は使わない）
- **期待出力**: `evidence/link-verification.md` に以下が全て OK として記録されている
  - Root README → `docs/plangate-plugin-migration.md`
  - Root README → `plugin/plangate/README.md`
  - migration note → `plugin/plangate/README.md`
  - migration note → 親 issue / 子 issues（GitHub URL）
- **種別**: Integration（Manual）

### TC-9: 新旧差分の一覧性

- **前提条件**: TC-2 パス
- **入力**: README の差分表を第三者が読んだ際の理解可能性を手動レビュー
- **期待出力**: 従来方式と plugin 方式の違いが 30 秒以内に把握可能
- **種別**: Manual Review

## エッジケース

### TC-E1: 既存 README 既存セクションへの影響

- **前提条件**: 本 TASK 着手前の README を記録
- **入力**: `git diff README.md` を確認
- **期待出力**: plugin 導入セクションの追加のみで、既存セクションが削除/破壊されていない
- **種別**: Integration

### TC-E2: 想定コミットメント化の回避

- **前提条件**: TC-5 パス
- **入力**: migration note の将来計画セクションを読む
- **期待出力**: 「想定」「検討中」等の曖昧表現で、具体日付や確約コミットが無い
- **種別**: Manual Review

### TC-E3: 移行手順の段階性

- **前提条件**: TC-5 パス
- **入力**: migration note の移行手順セクション
- **期待出力**: 「急いで移行する必要は無い」旨の記述、段階的移行の手順が明記
- **種別**: Manual Review

### TC-E4: 同梱範囲記述の実装整合

- **前提条件**: TC-5 パス
- **入力**: migration note の同梱範囲記述と、`plugin/plangate/` の実態を突合
  - `ls plugin/plangate/skills/ | wc -l` → 7
  - `ls plugin/plangate/agents/ | wc -l` → 8
  - `ls plugin/plangate/rules/ | wc -l` → 3
- **期待出力**: 記述と実態が一致
- **種別**: Integration

### TC-E5: 第三者目線での導入試行

- **前提条件**: TC-7, TC-8 パス、install syntax が TASK-0017 成果物から固定済み
- **入力**: README と plugin README に記載された手順（install syntax は `evidence/install-syntax-reference.md` 由来）通りに plugin 導入を試行
- **期待出力**: 追加の質問なしで導入完了できる。導入失敗時は TASK-0017 成果物との不一致を再確認
- **種別**: E2E（Manual）
