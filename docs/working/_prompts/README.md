# `_prompts/` — レビュー用プロンプトテンプレと履歴

## 目的

PBI ごとに発行される **外部 AI レビュー（C-2 / V-3）用プロンプト** の保管場所。
- `review-template.md`: 新規 PBI 用の正本テンプレ
- `review-{NNNN}.md`: 過去 PBI 固有の発行履歴（読み取り専用、再利用 / 監査用に保持）

## 構成

| ファイル | 役割 | 更新頻度 |
|---------|------|---------|
| `review-template.md` | **正本テンプレ**。新 PBI で C-2 / V-3 を実行する際はこれを起点に複製 | 仕様変更時 |
| `review-{NNNN}.md` | **過去 PBI 固有の発行記録**（例: `review-0017.md` = TASK-0017 で実際に外部 AI に投げたプロンプト） | 不変（履歴）|

## 運用ルール

### 新 PBI で外部 AI レビューを実行する場合

1. `review-template.md` をベースに `review-{TASK-NUMBER}.md` を作成
2. PBI 固有の context（goal / acceptance criteria / 関連 file 一覧 等）を埋める
3. 外部 AI（Codex / Gemini 等）に投げる
4. レビュー結果は `docs/working/TASK-XXXX/review-external.md` または `evidence/v3-review/` に保存
5. 発行プロンプトは本ディレクトリの `review-{NNNN}.md` として **保持**（履歴）

### 過去 prompts（review-0017〜review-0028）の扱い

これらは **削除しない**:
- 外部 AI レビューの再現性確保（同じプロンプトで再実行可能）
- 監査時のプロンプト品質変遷の追跡
- 新テンプレ改訂時の比較対象

ただし `review-template.md` に **大幅な変更** が入った場合、過去 prompts は「v1 系」として `_prompts/legacy/` に移動して整理しても良い（後方互換維持）。

## 関連

- 外部 AI レビュー Spec: [`docs/ai/contracts/review.md`](../../ai/contracts/review.md)
- review-result schema: [`schemas/review-result.schema.json`](../../../schemas/review-result.schema.json)
- C-2 / V-3 phase 説明: [`docs/ai/eval-plan.md`](../../ai/eval-plan.md) / [`hook-enforcement.md`](../../ai/hook-enforcement.md) EHS-1
- doc audit: `docs/working/_audit/2026-05-01-doc-audit.md` § V4-C-1 で本 README 新設の経緯を記録
