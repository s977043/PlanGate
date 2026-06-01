# TASK-0123 current-state

更新日時: 2026-06-02

## 現在フェーズ

**C-1 セルフレビュー完了 → C-3 人間レビュー待ち**

## 完了済み

- pbi-input.md 生成
- plan.md 生成（Mode=critical / lite_eligible=false / HO 制約・AI/Human 責務分界明記）
- todo.md 生成
- test-cases.md 生成
- review-self.md（C-1）生成 → **PASS**
- INDEX.md 生成

## 次のアクション

1. Human: plan.md / pbi-input.md / test-cases.md / review-self.md をレビューし `approvals/c3.json` を発行（C-3 Gate）
2. AI（C-3 APPROVED 後）: Phase 1〜2（patch 生成・テストスクリプト実装）

## ブロッカー

**C-3 Human 承認待ち**（`docs/working/TASK-0123/approvals/c3.json` 未発行）

## 重要な設計決定

- 全 HO ファイルは patch 方式で Human が apply（AI 直接変更不可）
- HMAC 署名: `PLANGATE_MAINTENANCE_KEY` 設定済みの場合のみ検証有効（後方互換考慮）
- `check-approval-token-write.sh`: maintenance 窓でも常時 block（HO 相当）
