# Dogfooding Eval v1 — TASK-0085

> #231 PBI-HI-015 / single judge（決定論構造判定 + rationale）
> judge-prompt 正本: docs/ai/dogfooding-eval.md

| # | 項目 | 判定 |
|---|------|------|
| 1 | PBI→AC/Design/Task 分解 | **FAIL** |
| 2 | handoff 6 要素 | **FAIL** |
| 3 | C-3/C-4 証跡 | **FAIL** |
| 4 | Trace Timeline イベント(experimental) | **PARTIAL** |
| 5 | Stop rules / core-contract 違反なし | **FAIL** |

## Rationale

### 1. PBI→AC/Design/Task 分解 — FAIL
pbi-input AC=False / plan WorkBreakdown=False

### 2. handoff 6 要素 — FAIL
handoff section_count=0/6 (handoff.md 不在)

### 3. C-3/C-4 証跡 — FAIL
c3_status=None / C-4 言及=False

### 4. Trace Timeline イベント(experimental) — PARTIAL
events.ndjson に TASK-0085 の event=False (experimental＝無くても FAIL ではなく PARTIAL)

### 5. Stop rules / core-contract 違反なし — FAIL
未追認SKIP=16 / 証跡なし完了主張=False

## Release blockers: 4 — 要解消
