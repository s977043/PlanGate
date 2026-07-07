# ai-loop Run-014 — LoopSpec + 計画（F-29/F-30 の loopspec.md 正本化）

> 摩擦バックログの Optimize run。Run-012（F-29: 事前検証は AC 閾値そのもので /
> F-30: AC 改訂は consolidated ブロック追記）で確立し Run-013 で再運用済みの
> 2 規律を正本へ昇格する（I-5: 記録→実践→正本化）。
> **並行セッション対策（F-33）**: 本 run は分離 git worktree 上で実行
> （main ワークツリーは #760 並行セッションが使用中・不介入）。

## LoopSpec

```yaml
loop:
  name: run-014-optimize-f29-f30
  trigger: {type: manual, detail: "運用改善の継続指示。Run-012/013 摩擦の Optimize"}
  goal:
    description: "loopspec.md の deterministic 注記に F-30（consolidated ブロック規律）と F-29（閾値そのものでの PASS 実測）の 2 文を追記"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-4"
  context:
    include: [run_frictions, design_docs, diff]
    external_sources: []
    exclude: [stale_tool_outputs]
  scope:
    allowed_paths:
      - "docs/workflows/ai-loop/loopspec.md"
      - "docs/working/ai-loop-runs/**"
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - cmd: "grep -qF 'consolidated' docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-1 F-30 規律（FAIL 方向 0/exit1 実測・PASS 方向は確定文言そのもので実測済み）
      - cmd: "grep -qF '閾値・条件そのもの' docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-2 F-29 規律（同上・両方向とも確定文言で実測）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-3
      - cmd: "test \"$(git diff --name-only origin/main -- docs/workflows/ | wc -l | tr -d ' ')\" -le 1"
        expect_exit: 0
        note: AC-4 対象 1 ファイルのみ（run 記録は docs/working）
    review: [requirements_fit, no_duplication]
  stopping_rule:
    terminal_state_ref: "decision-table.md"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write: [decision_record, run_frictions]
    ref: "execution-runbook.md §2-(4)"
  escalation: {touches_ho: unconditional, budget_ref: "arbiter-policy.md §7"}
```

## 計画（確定追記文言 — maker はそのまま使う）

loopspec.md の deterministic 注記（F-12 文・F-28 文の直後）に以下 2 文を追記:

「Round 改訂で deterministic の AC を変更した場合は、文章宣言だけで置換せず、
機械可読な consolidated deterministic ブロック（最終確定 AC）を新節として追記し、
maker・検証者はそのブロックのみを実行する（旧ブロックの遡及編集はしない —
監査記録不変。実例: Run-012 R3 C 指摘 / Run-013）。
PASS 方向の実測は AC の閾値・条件そのもの（要求する件数・複合条件を満たす入力）で
行う（要求水準未満のサンプルでの PASS 申告は事前検証にならない。実例: Run-012 F-29）。」

- 両固定句（`consolidated` / `閾値・条件そのもの`）を文言が含むことを事前実測済み
  （AC と文言の固定句結合 — Run-004 改訂 1 の方式）
- **Non-goals**: decision-table / SKILL.md 側の変更・F-31/F-32/F-33 の正本化（別 run）
- **lite**: size_ok=true / no_new_design=true（実践済み規律の明文化）/
  follows_pattern=true / reversible=true
- **boundary**: clean（docs/workflows/ai-loop/ はドメイン内・HO 非接触）
- **class**: no-merge
