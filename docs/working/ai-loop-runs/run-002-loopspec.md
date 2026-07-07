# ai-loop Run-002 — LoopSpec + 計画（Run-001 escalate の人間判断 (a) を受けた再実行）

> Run-001 の HUMAN_ESCALATED に対する人間判断: **(a) living index を新設し、
> Phase 0 スナップショット（asset-inventory / related-specs）は監査証跡として不変維持**。
> 本 run は Run-001 摩擦記録の Optimize を反映: **F-1**（W チェック reject_category の
> enum 厳格指定）/ **F-4**（AC の機械検証化）。

## LoopSpec

```yaml
loop:
  name: run-002-living-index
  trigger:
    type: manual
    detail: "Run-001 escalate への人間判断 (a)。設計判断は人間が実施済み"
  goal:
    description: "docs/ai/ai-loop/README.md を薄い入口として新設（living 地図 = design-philosophy §7 を案内・スナップショットは監査証跡と明記）+ design-philosophy §7 文書地図に batch1 新資産 4 件を追記"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-5（機械検証可能）"
  context:
    include:
      - run-001 records # escalate 理由と人間判断
      - design_docs # design-philosophy §7 / 既存 README パターン
      - diff
    exclude:
      - stale_tool_outputs
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/ai/ai-loop/README.md docs/ai/ai-loop/design-philosophy.md"
      - "grep -c 'loopspec.md' docs/ai/ai-loop/design-philosophy.md → 1 以上（AC-2 機械検証）"
      - "grep -c 'loop-safety-gates.md' docs/ai/ai-loop/design-philosophy.md → 1 以上"
      - "grep -c 'unknown-discovery.md' docs/ai/ai-loop/design-philosophy.md → 1 以上"
      - "grep -c 'hotl-merge-entry-criteria.md' docs/ai/ai-loop/design-philosophy.md → §7 内 1 以上"
      - "grep -c 'design-philosophy.md' docs/ai/ai-loop/README.md → 1 以上（AC-1）"
      - "git diff --numstat で asset-inventory.md / related-specs.md の変更ゼロ（AC-4 スナップショット不変）"
    review:
      - requirements_fit
      - no_duplicate_taxonomy # README が §7 地図を複製していない（薄い入口のみ）
  stopping_rule:
    terminal_state_ref: "decision-table.md（AUTO_APPROVED / HUMAN_ESCALATED / BLOCKED）"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write:
      - decision_record
      - run_frictions
    ref: "execution-runbook.md §2-(4)（L4 学習側: review-feedback-loop.md）"
  escalation:
    touches_ho: unconditional
    budget_ref: "arbiter-policy.md §7"
```

## 計画

- **Goal**: 上記 goal.description のとおり。
- **Non-goals**: asset-inventory.md / related-specs.md への変更（監査証跡・不変）。
  §7 地図の再構成（追記のみ）。README での資産再列挙（地図の複製禁止）。
- **AC（機械検証可能 — F-4 反映）**:
  1. README.md が新設され design-philosophy.md への案内を含む（grep）
  2. §7 文書地図に loopspec / loop-safety-gates / unknown-discovery の 3 行が追加（grep）
  3. §7 の記録層または契約層に hotl-merge-entry-criteria が追加（grep）
  4. asset-inventory.md / related-specs.md の diff がゼロ（git diff --numstat）
  5. markdownlint 0 error・追記リンク全解決
- **Files（Expected Diff）**: `docs/ai/ai-loop/README.md`（新規）/
  `docs/ai/ai-loop/design-philosophy.md`（§7 のみ追記）の 2 ファイル
- **lite 4 軸**: size_ok=true / **no_new_design=true**（living index の設計判断は
  Run-001 escalate で人間が実施済み。本 run は実装のみ）/ follows_pattern=true
  （§7 の既存表形式・repo の README 慣行）/ reversible=true
- **boundary**: clean（docs/ai/ai-loop/ 配下）
- **class**: no-merge
