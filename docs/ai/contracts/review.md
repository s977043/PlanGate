# Phase Contract: review

> [`prompt-assembly.md`](../prompt-assembly.md) の phase_contract / 7 phase の 1 つ
> Prompt Assembly では `verify`（受入確認）から分離し、**設計品質レビュー** に特化

## Goal

実装の **設計品質**（可読性 / 保守性 / 拡張性 / セキュリティ / Plugin 同期）をレビューする。受入基準の機械突合は `verify` phase で実施。

## Success criteria

- 設計品質の判定（PASS / WARN / FAIL）が記録
- findings が [`schemas/review-result.schema.json`](../../../schemas/review-result.schema.json) 準拠
- C-1 セルフレビュー（17 項目）+ C-2 外部AIレビュー（high-risk / standard で実施）

## Stop rules

- C-2 で critical 発生 → C-3 ゲート前に即修正 or REJECT
- レビュー対象に Iron Law 違反検知 → block

## Output discipline

- `review-self.md` / `review-external.md`（Markdown 詳細）
- `review-result.json`（schema 準拠メタ、任意 → 段階的に必須化、Issue #158）
- JSON 出力時は [`schemas/review-result.schema.json`](../../../schemas/review-result.schema.json) 準拠、`schema-validate` CI で機械検証

## 関連

- [`schemas/review-result.schema.json`](../../../schemas/review-result.schema.json) — phase: C-1 / C-2 / V-3
- [`.claude/rules/review-principles.md`](../../../.claude/rules/review-principles.md)
- [`structured-outputs.md`](../structured-outputs.md)（schema validate CI 統合 / Issue #158）
