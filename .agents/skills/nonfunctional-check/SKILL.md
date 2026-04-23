---
name: nonfunctional-check
description: "性能・保守性・安全性・アクセシビリティなど非機能要件を体系的にチェックし、明示すべき非機能要件を一覧化する。Use when: WF-02 で非機能要件を確認したい時、性能/セキュリティ/保守性の要件を見落としなく整理したい時。"
---

# Nonfunctional Check

機能要件だけでなく、性能 / 保守性 / 安全性 / アクセシビリティなどの非機能要件を漏れなく確認する Skill。

## カテゴリ

Check

## 想定 Phase

WF-02 Requirement Expansion

## 入力

- requirements（WF-02 中間 artifact）
- プロジェクトの非機能基準（AGENTS.md / レビュー原則）

## 出力

非機能要件リスト:

- パフォーマンス要件（レスポンス時間 / スループット）
- 保守性要件（コードスタイル / テストカバレッジ / ログ要件）
- セキュリティ要件（認証 / 認可 / 機密情報保護）
- アクセシビリティ要件（該当する場合）
- 可観測性要件（ログ / メトリクス / トレース）

## 使い方

- WF-02 で qa-reviewer が呼び出す
- 結果は requirements artifact に統合される

## 関連

- Workflow: `docs/workflows/02_requirement_expansion.md`
- Rule: Rule 2
