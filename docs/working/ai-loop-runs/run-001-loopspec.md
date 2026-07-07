# ai-loop Run-001 — LoopSpec + 計画（初回実走 / dogfooding）

> 本ファイルは `docs/workflows/ai-loop/loopspec.md` に準拠した初の実 LoopSpec 宣言。
> 実行手順は `docs/workflows/ai-loop/execution-runbook.md` §2 に従う。

## LoopSpec

```yaml
loop:
  name: run-001-asset-inventory-sync
  trigger:
    type: manual
    detail: "ユーザー指示「ai-loopで対応を進めて、運用の中で改善を進めたい」（初回実走）"
  goal:
    description: "docs/ai/ai-loop/ の資産索引（asset-inventory.md / related-specs.md）を、v8.16 期に追加された ai-loop 資産で現状同期する"
    exit_criteria_ref: "00_concept.md §3.3（merge-ready = CI green + AI レビュー指摘対応完了）+ 本書 AC 1-4"
  context:
    include:
      - related_issue # (#732/#734 で追加された資産一覧)
      - design_docs # design-philosophy.md / loopspec.md 等の実ファイル
      - diff
    exclude:
      - stale_tool_outputs
      - irrelevant_history
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial) # maker と独立起動
  verification:
    deterministic:
      - "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/ai/ai-loop/asset-inventory.md docs/ai/ai-loop/related-specs.md"
      - "相対リンク解決チェック（追記リンク全件の実在確認）"
    review:
      - requirements_fit # AC 1-4 充足
      - additive_only # 既存分類・記述の破壊なし
  stopping_rule:
    terminal_state_ref: "decision-table.md（AUTO_APPROVED / HUMAN_ESCALATED / BLOCKED）"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write:
      - decision_record
      - run_frictions # 初回実走で観測した摩擦点（L4 還元用）
    ref: "execution-runbook.md §2-(4)（L4 学習側: review-feedback-loop.md）"
  escalation:
    touches_ho: unconditional
    budget_ref: "arbiter-policy.md §7"
```

## 計画（C-3' への入力 plan 相当）

- **Goal**: asset-inventory.md / related-specs.md に、v8.16 期の新規 ai-loop 資産
  （design-philosophy.md / loopspec.md / loop-safety-gates.md / unknown-discovery.md /
  hotl-merge-entry-criteria.md、隣接: subagent-delegation）の索引を additive 追記し、
  Phase 0 時点の棚卸しを現状へ同期する。
- **Non-goals**: 既存分類の変更・資産本体の編集・HO パスへの接触。
- **AC**:
  1. asset-inventory.md に新資産 5 件が分類（uses/自己資産）付きで追記されている
  2. related-specs.md に新資産と既存仕様の関係が必要分のみ追記されている
  3. 既存の分類・記述を破壊しない（additive。削除行ゼロ）
  4. 追記リンク全解決・markdownlint 0 error
- **Files（Expected Diff）**: `docs/ai/ai-loop/asset-inventory.md` / `docs/ai/ai-loop/related-specs.md` の 2 ファイルのみ
- **lite 4 軸**: size_ok=true（2 files）/ no_new_design=true（既存表形式踏襲）/
  follows_pattern=true / reversible=true（docs・revert 可）
- **boundary**: clean（docs/ai/ai-loop/ 配下は ho-paths.md 対象外）
- **class**: no-merge（PR 作成まで。merge は C-4 Human-owned）

## loop-safety gates 事前チェック（loop-safety-gates.md）

- stop condition: あり（terminal 3 値 + AC 充足 or round 上限）✓
- feasibility: 矛盾制約なし（additive のみ）✓
- budget: ラウンド上限 3 継承 ✓
- 非停止パターン: 「完璧になるまで」等なし ✓
- failure reporting: 本ファイル + decision record ✓
