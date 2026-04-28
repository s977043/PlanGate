# Parallelization Plan — PBI-XXX

> **Template**: PlanGate Orchestrator Mode 並行実行計画テンプレート
> 関連: [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) / Issue #109
> 用途: 子 PBI 群の並行実行可否を判定し、実行順序を確定

## メタデータ

| 項目 | 値 |
|------|---|
| Parent PBI ID | PBI-XXX |
| Generated at | YYYY-MM-DD |
| Reference graph | [`dependency-graph.md`](./dependency-graph.md) |

## 判定対象一覧

| 子 PBI ID | parallelizable (YAML 値) | 最終判定 | 同一バッチ |
|----------|------------------------|---------|----------|
| PBI-XXX-01 | true | 単独 | Batch 1 |
| PBI-XXX-02 | true | 並行可 | Batch 2 |
| PBI-XXX-03 | true | 並行可 | Batch 2 |
| PBI-XXX-04 | true | 単独 | Batch 3 |

## 並行実行可能と判定したペア

| ペア | 判定 | 根拠 |
|------|------|------|
| PBI-XXX-02 × PBI-XXX-03 | ✅ 並行可 | allowed_files が重複なし、依存先が共通完了済み、API contract 確定済み、テスト境界分離、低リスク |

### 並行可能の 5 条件チェック（PBI-XXX-02 × PBI-XXX-03 の例）

| 条件 | 判定 |
|------|------|
| 1. 変更ファイルが重ならない | ✅（02: middleware/, 03: ui/）|
| 2. 依存先が完了済み | ✅（両者とも PBI-XXX-01 完了後に開始）|
| 3. API contract / DB schema 固定済み | ✅（PBI-XXX-01 で確定）|
| 4. テスト境界が分離 | ✅（unit + 各々の integration test）|
| 5. 高リスク領域でない | ✅（auth / payment ではない）|

## 並行実行不可と判定したペア

| ペア | 判定 | 根拠 |
|------|------|------|
| 例: PBI-XXX-A × PBI-XXX-B | ❌ 並行不可 | 同一 schema.prisma を変更するため順序依存 |

### 並行不可の 5 条件チェック

| 条件 | 該当か |
|------|-------|
| 1. 同一ファイルを変更 | ✅ → 並行不可 |
| 2. DB migration 順序依存 | — |
| 3. 認証 / 認可 / 決済 / セキュリティ領域 | — |
| 4. API contract 未確定 | — |
| 5. 共通コンポーネント / 共通型を同時変更 | — |

いずれか 1 つでも該当 → 並行不可。

## 実行バッチ計画

| Batch | 並行実行する子 PBI | 開始条件 |
|-------|------------------|---------|
| Batch 1 | PBI-XXX-01 | parent:decomposition_approved |
| Batch 2 | PBI-XXX-02, PBI-XXX-03 | Batch 1 全完了 |
| Batch 3 | PBI-XXX-04 | Batch 2 全完了 |

## リソース制約

| 制約 | 値 |
|------|---|
| 同時実行 PR 上限 | 3（GitHub Actions concurrency 等を考慮）|
| 同時実行 worktree 上限 | 5（ローカルディスク容量）|
| reviewer 負荷上限 | 1 日あたり 子 PBI PR 5 件まで |

## モニタリング

並行実行中の状態を `parent-plan.md` の Status Log に追記:

| Date | Batch | Status |
|------|-------|--------|
| YYYY-MM-DD | Batch 1 | started |
| YYYY-MM-DD | Batch 1 | completed |
| YYYY-MM-DD | Batch 2 | started (PBI-XXX-02, PBI-XXX-03) |
| YYYY-MM-DD | Batch 2 | partial: PBI-XXX-02 done, PBI-XXX-03 review |

## エスカレーション

並行実行中に以下が発生した場合は 👤 人間にエスカレート:

- 並行可能と判定したペアで実行時にコンフリクト発生
- 想定外のリソース競合（CI 枯渇等）
- レビューキューが上限を超過
