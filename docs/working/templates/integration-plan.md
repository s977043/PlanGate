# Integration Plan — PBI-XXX

> **Template**: PlanGate Orchestrator Mode 統合計画テンプレート
> 関連: [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) / [`docs/workflows/orchestrator-integration.md`](../../workflows/orchestrator-integration.md)
> 用途: 子 PBI 群完了後の統合チェック + 親 PBI 完了判定

## メタデータ

| 項目 | 値 |
|------|---|
| Parent PBI ID | PBI-XXX |
| Generated at | YYYY-MM-DD |
| Status | pending / in_progress / passed / failed |

## カバレッジマトリクス（受入基準 × 子 PBI）

親 PBI の各 AC を、どの子 PBI がカバーするかを明示。0 子 PBI でカバーされる AC は **gap**。

| 親 AC | PBI-XXX-01 | PBI-XXX-02 | PBI-XXX-03 | PBI-XXX-04 | カバー判定 |
|------|-----------|-----------|-----------|-----------|----------|
| parent-AC-1 | ✅ | — | — | — | ✅ |
| parent-AC-2 | — | ✅ | ✅ | — | ✅ |
| parent-AC-3 | — | — | — | ✅ | ✅ |
| parent-AC-4 | — | — | — | — | ❌ **gap** |

`covers_parent_ac` は各子 PBI YAML に記載。

### Gap 検出時の対応

`parent-AC-4` のような gap が検出された場合:

- 既存子 PBI の AC を拡張する（軽微な場合）
- 新規子 PBI を提案する（`new_child_pbi_proposed` フロー）
- 親 PBI 自体のスコープ縮小を検討する（人間判断）

## 統合チェックリスト

子 PBI 単独では検出できない統合観点。

### A. API Contract

- [ ] 子 PBI 間で公開された API のシグネチャが consistent
- [ ] 型定義が共通モジュールで一元管理されている
- [ ] バージョン互換性が宣言されている

### B. データ整合性

- [ ] DB schema 変更が子 PBI 間で衝突しない
- [ ] Migration 順序が dependency-graph に沿っている
- [ ] データ型 / NULL 許容が一貫している

### C. ユーザーフロー（E2E）

- [ ] エンドツーエンドの主要シナリオが動作する
- [ ] エラーパスが想定通り branch する
- [ ] 認証 / 認可フローが破綻していない

### D. 非機能

- [ ] パフォーマンス劣化が許容範囲（既存 baseline ± X%）
- [ ] メモリ使用量が予算内
- [ ] ログ / 監視が網羅されている

### E. セキュリティ

- [ ] 認証境界が壊れていない
- [ ] 機密データ取り扱いが pass-through で漏洩していない
- [ ] 依存関係に脆弱性なし

### F. ドキュメント

- [ ] 親 PBI README / API ドキュメントが更新されている
- [ ] CHANGELOG に親 PBI エントリが追加されている
- [ ] migration guide（ある場合）が整備されている

## 完了条件（ParentDone）

```text
ParentDone =
  AllRequiredChildrenAccepted
  AND ParentAcceptanceCriteriaCovered
  AND IntegrationChecksPassed
  AND NoOpenBlockingGap
  AND HumanOrPolicyFinalApprovalPassed
```

| 条件 | 確認方法 | 判定 |
|------|---------|------|
| AllRequiredChildrenAccepted | 子 PBI 状態追跡で全 required 子 PBI が `child:done` | (pending) |
| ParentAcceptanceCriteriaCovered | 上記カバレッジマトリクスで全行 ✅ | (pending) |
| IntegrationChecksPassed | 上記 A〜F のすべての項目 ✅ | (pending) |
| NoOpenBlockingGap | Gap リストが空または「先送り合意済み」のみ | (pending) |
| HumanOrPolicyFinalApprovalPassed | `approvals/parent-integration.json` で APPROVE | (pending) |

## 統合チェック結果ログ

| Date | チェック | 結果 | 担当 | 備考 |
|------|---------|------|------|------|
| YYYY-MM-DD | A. API contract | PASS | qa-reviewer | — |
| YYYY-MM-DD | C. E2E ユーザーフロー | FAIL | Integration Agent | gap-001 を起票 |
| YYYY-MM-DD | C. E2E ユーザーフロー（再）| PASS | Integration Agent | gap-001 解決済 |

## Gap リスト

| Gap ID | 内容 | 起票日 | 解決方針 | 状態 |
|--------|------|--------|---------|------|
| gap-001 | （例: ログイン後リダイレクトが新権限と不整合）| YYYY-MM-DD | PBI-XXX-03 を修正 | resolved |

## 統合ゲート判定

| 項目 | 値 |
|------|---|
| 判定者 | (👤 人間 or policy) |
| 判定日時 | YYYY-MM-DD HH:MM |
| 判定 | APPROVE / REQUEST CHANGES / REJECT |
| コメント | (free text) |
| 記録 | `approvals/parent-integration.json` |

## References

- [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) — 仕様正本
- [`docs/workflows/orchestrator-integration.md`](../../workflows/orchestrator-integration.md) — 統合フロー
- [`parent-plan.md`](./parent-plan.md) — 親計画
- [`dependency-graph.md`](./dependency-graph.md) — 依存関係
- [`parallelization-plan.md`](./parallelization-plan.md) — 並行実行計画
