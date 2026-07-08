# ai-loop Run-020 — LoopSpec + 計画（F-38/F-39 の正本化）

> 摩擦バックログ Optimize（Run-014/018 と同型・I-5）。台帳（Run-019 で索引化）に
> 「未正本化」と明示した F-38（記録なき実践主張）/ F-39（AC 事前検証は実挿入
> フォーマットで）を正本へ昇格する。§2-(0) 採番照合 1 点目実施済み（020 空き実測）。
> 分離 worktree 実行。**並行 PR #768 とは別 hunk**（本 run= runbook §2-(6) と
> loopspec.md / #768= runbook §2-(4)）— 競合しない見込みを事前確認済み。

## LoopSpec

```yaml
loop:
  name: run-020-optimize-f38-f39
  trigger: {type: manual, detail: "運用改善の継続指示。台帳の未正本化 2 件の Optimize"}
  goal:
    description: "runbook §2-(6) に F-38（実践主張の出典検証）を項目 5 として追加 + loopspec.md の F-12/F-29 系注記に F-39（実挿入フォーマットでの事前検証）を追記"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-4"
  context:
    include: [run_frictions, design_docs, diff]
    external_sources: []
    exclude: [stale_tool_outputs]
  scope:
    allowed_paths:
      - "docs/workflows/ai-loop/execution-runbook.md"
      - "docs/workflows/ai-loop/loopspec.md"
      - "docs/working/ai-loop-runs/**"
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - cmd: "grep -qF '検証可能な出典' docs/workflows/ai-loop/execution-runbook.md"
        expect_exit: 0
        note: AC-1 F-38 正本化（FAIL 方向 0/exit1・PASS 方向は実挿入フォーマット（行折り返し込み）の一時ファイルで実測 — F-39 自己適用）
      - cmd: "grep -qF '実際の挿入フォーマット' docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-2 F-39 正本化（同上・両方向実測済み）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/workflows/ai-loop/execution-runbook.md docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-3
      - cmd: "test \"$(git diff --name-only origin/main -- docs/workflows/ | wc -l | tr -d ' ')\" -le 2"
        expect_exit: 0
        note: AC-4 対象 2 ファイルのみ
    review: [requirements_fit, no_duplication]
  stopping_rule:
    terminal_state_ref: "decision-table.md"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write: [decision_record, run_frictions]
    ref: "execution-runbook.md §2-(4)"
  escalation: {touches_ho: unconditional, budget_ref: "arbiter-policy.md §7"}
```

## 計画（確定追記文言 — maker は実挿入フォーマットのままそのまま使う）

1. **execution-runbook.md §2-(6)** の項目 4 の直後に項目 5 を追加:

   「5. **実践事実の主張の出典検証**: 計画・run 記録・PR 本文中の「実践済み」「適用済み」等の
   実例主張が、**検証可能な出典**（run 記録・PR・実測出力のいずれか）に紐づくことを
   確認する（記録なき実践主張は削除する — F-38。Run-018 W チェック B の検出が実例）」

2. **loopspec.md** の F-12/F-29 系注記（「PASS 方向の実測は AC の閾値・条件そのもの…」文の直後）に追記:

   「grep -F 型 AC の PASS 方向事前検証は、**実際の挿入フォーマット**（行折り返し・
   インデントを含む最終挿入形そのもの）で行う（サンプル文字列の形式差がアンカー句を
   跨ぐことによる偽 PASS/偽 FAIL を防ぐ — F-39。Run-018 exec の AC-2 一時 FAIL が実例）。」

- 両文言とも**実挿入フォーマット（行折り返し込み）の一時ファイルで AC 固定句を実測済み**
- 出典検証（F-37/F-38 遵守）: F-38/F-39 の採番元 = run-018-loopspec.md（PR #767）、
  「Run-018 W チェック B の検出」「Run-018 exec の AC-2 一時 FAIL」はいずれも
  PR #767 本文・run-018 記録に実在（本計画時に実読確認）

- **Non-goals**: F-38 の PlanGate 本番（verification-report 等）への展開（別 PBI）/
  SKILL.md 変更 / 台帳の再編集
- **lite**: size_ok=true / no_new_design=true（実践済み規律の明文化・Run-014 同型）/
  follows_pattern=true / reversible=true
- **boundary**: clean / **class**: no-merge

---

## exec 記録

- W R1 A✓/B✓ ワンラウンド合意（正本規律の事前自己適用 — F-38/F-39 を計画自身に適用 —
  が効いた形。F-16 系の傾向継続）→ AUTO_APPROVED
- maker: AC 4 件 PASS・純追加。全角括弧の誤変換を自己検出・即修正（F-32 系の亜種）
- rubric grader: **pass 5/5**（2 run 連続）— 実例参照の実在・確定文言一致・文体踏襲・
  境界不変・重複定義なしを引用つきで独立検証
- orchestrator 独立再検証: AC 全 PASS・削除行 0

---

## 事後注記（PR #769 Gemini レビュー由来・2026-07-08）

AC-4 の `test "$(git diff ... | wc -l)" -le 2` 形式は、git diff 自体が失敗した場合に
空出力 → 0 件 → 偽 PASS となる silent pass リスクを持つ（Gemini 指摘・正当）。
本 run では同一セッション内の他 AC・純追加検証が同じ diff 基盤で正常動作しており
（AC-4 実行時に 2 件を実検出）偽 PASS は発生していないが、**「件数上限型 AC は
前段コマンドの成功を `&&` で担保する（または一時ファイル経由で wc する）」を
Optimize 候補（F-41 予定）として次 run に繰延**する。台帳追記は #768（台帳単一権威）
マージ後に発行規律へ従って行う。本 LoopSpec の AC は実行済みの時点記録として不変。
