# Dependency Graph — PBI-116

> 親 PBI [`parent-plan.md`](./parent-plan.md) の子 PBI 間依存関係。
> 関連: [`docs/orchestrator-mode.md`](../../orchestrator-mode.md)

## 依存関係（DAG）

```text
                          ┌─────────────────────┐
                          │  PBI-116-01 (#117)  │
                          │  Core Contract       │
                          │  high-risk           │
                          └──────────┬──────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
     ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
     │ PBI-116-02   │       │ PBI-116-04   │       │ PBI-116-06   │
     │ Model Profile│       │ Structured    │       │ Tool Policy  │
     │ standard     │       │ Outputs       │       │ Boundary     │
     │ parallel:T   │       │ standard      │       │ standard     │
     │              │       │ parallel:T    │       │ parallel:T   │
     └──────┬───────┘       └──────┬───────┘       └──────┬───────┘
            │                      │                      │
            │    （02 と 04 は並行・独立、03 は 02 のみに依存）
            │                      │                      │
            ▼                      │                      │
   ┌──────────────────┐            │                      │
   │  PBI-116-03      │            │                      │
   │  Prompt Assembly │            │                      │
   │  high-risk       │            │                      │
   │  parallel:F      │            │                      │
   │  Depends: 01,02  │            │                      │
   └──────────┬───────┘            │                      │
              │                    │                      │
              └────────────┬───────┴──────────────────────┘
                           ▼
                  ┌──────────────────┐
                  │  PBI-116-05      │
                  │  Eval Cases       │
                  │  standard         │
                  │  parallel:F       │
                  │  Depends: 全子    │
                  └──────────────────┘
```

**注**: PBI-116-03 (Prompt Assembly) は PBI-116-02 (Model Profile) のみに依存し、PBI-116-04 (Structured Outputs) には依存しない。両者は並行実行可能で独立。Prompt assembly が Structured Outputs schema を将来引用する場合は別 PBI で対応（今回 scope 外）。

## 依存関係表

| ID | Title | Mode | Parallelizable | Depends on | Phase |
|----|-------|------|---------------|-----------|-------|
| PBI-116-01 | Core Contract | high-risk | false | — | **Phase 1** |
| PBI-116-02 | Model Profile | standard | true | PBI-116-01 | **Phase 2** |
| PBI-116-04 | Structured Outputs | standard | true | PBI-116-01 | **Phase 2** |
| PBI-116-06 | Tool Policy Boundary | standard | true | PBI-116-01 | **Phase 2** |
| PBI-116-03 | Prompt Assembly | high-risk | false | PBI-116-01, PBI-116-02 | **Phase 3** |
| PBI-116-05 | Eval Cases | standard | false | 全子 PBI | **Phase 4** |

## トポロジカル順序

```
Phase 1: PBI-116-01
Phase 2: { PBI-116-02, PBI-116-04, PBI-116-06 }（並行）
Phase 3: PBI-116-03
Phase 4: PBI-116-05
```

## 依存関係の正当性

### PBI-116-01 が全ての前提
- Core Contract は `CLAUDE.md` / `AGENTS.md` / rules / agents の薄型化 + outcome-first 化を提供
- 他 5 子 PBI は Core Contract を参照点とする

### PBI-116-02 / 04 / 06 が並行可能な理由
- 各子 PBI の `allowed_files` が独立（`docs/ai/model-profiles.yaml` / `schemas/review-result.schema.json` / `docs/ai/tool-policy.md` 等）
- `forbidden_files` で互いの領域に踏み込まない設計
- Core Contract の出力（基盤）に対する追加層として独立

### PBI-116-03 が PBI-116-02 に依存する理由
- Prompt assembly の `model_adapter` 層が Model Profile の schema を引用
- PBI-116-02 完了後に schema を取り込む

### PBI-116-05 が最後の理由
- Eval cases は他 5 子 PBI の成果物（Core Contract / Model Profile / Prompt Assembly / Structured Outputs / Tool Policy）を全て参照対象とする
- 検証層として最後に配置

## 並行実行時の scope 衝突確認

PBI-116-02 / 04 / 06 が並行実行時、`allowed_files` の重複なし:

| ID | allowed_files 主要パス |
|----|---------------------|
| PBI-116-02 | `docs/ai/model-profiles.yaml`, `docs/ai/profiles/**`, `schemas/model-profile.schema.json` |
| PBI-116-04 | `schemas/review-result.schema.json`, `schemas/acceptance-result.schema.json`, `docs/ai/structured-outputs.md` |
| PBI-116-06 | `docs/ai/tool-policy.md`, `docs/ai/hook-enforcement.md`, `docs/ai/responsibility-boundary.md` |

衝突なし → 並行実行 OK。
