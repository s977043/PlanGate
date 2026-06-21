# docs/working/templates — テンプレート一覧

PlanGate ワークフローで使うテンプレート群。

## 必須 artifact テンプレート

| テンプレート | 用途 | フェーズ |
| --- | --- | --- |
| [`handoff.md`](./handoff.md) | 完了時の引き継ぎパッケージ（必須6要素・全PBI必須） | WF-05 |

## 親 PBI（Orchestrator Mode）

| テンプレート | 用途 |
| --- | --- |
| [`parent-plan.md`](./parent-plan.md) | 親計画 |
| [`dependency-graph.md`](./dependency-graph.md) | 子 PBI 依存グラフ |
| [`parallelization-plan.md`](./parallelization-plan.md) | 並行実行計画 |
| [`integration-plan.md`](./integration-plan.md) | 統合チェック / 親完了条件 |

## 任意（optional）artifact テンプレート

| テンプレート | 用途 | 備考 |
| --- | --- | --- |
| [`run-outcome-review.md`](./run-outcome-review.md) | run の改善学習（振り返り。handoff とは責務が異なる） | **任意**（#228 / v8.7.0）。必須化しない。WF-06 Retro（opt-in）が 5 項目を入力に使用 |
| [`current-state.md`](./current-state.md) | 現在状態スナップショット | タスク完了毎に上書き |
| [`design.md`](./design.md) | WF-03 設計成果物 | UI タスク時 視覚設計セクション併用 |
| [`review-self.md`](./review-self.md) / [`review-external.md`](./review-external.md) | C-1 / C-2 レビュー結果 | |
| [`evidence-tdd-ledger.json`](./evidence-tdd-ledger.json) | TDD RED/GREEN/REFACTOR VERIFY 証跡 | high-risk / critical mode のTDD必須時に使用 |

> `run-outcome-review.md` は v8.6.0 以前の利用者に**移行コストゼロ**（任意・後方互換）。


## Phase 分割表 (規模 L 以上 / #352 codex-mvp-split)

規模 L 以上 (TASK-0117 #351 事前メトリクス検証で実数 ≥ 3 倍) の機能は、
PBI INPUT PACKAGE (`pbi-input.md`) に **Phase 分割表** を含める:

| Phase | 内容 | 工数 | 状態 |
|---|---|---|---|
| 1 | <採用 MVP> | M | 着手 |
| 2 | <次の拡張> | S | 繰延 (別 PBI) |
| 3 | <最終形> | M | 繰延 (別 PBI) |

Phase 1 のみ本 PBI scope。Phase 1 の選定は [`/codex-mvp-split`](../../../.claude/commands/codex-mvp-split.md)
で Codex 相談。正本: [`docs/ai/codex-mvp-split.md`](../../ai/codex-mvp-split.md)。

(規模 standard 以下で分割不要の場合は「該当なし」と明記)
