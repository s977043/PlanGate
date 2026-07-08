# ai-loop Run-021 — LoopSpec + 計画（F-41: 件数上限型 AC の silent pass 対策）

> Run-020 PR #769 の Gemini 指摘（採用・繰延）を正本化する Optimize run。
> **F-41 は台帳追記と同時発行**（#768 で正本化した単一権威規律に準拠）。
> §2-(0) 採番照合 1 点目実施済み（021 空き実測）。分離 worktree 実行。
> **AC-4 自体に F-41 形式を初適用**（前段失敗時に exit≠0 となることを事前実証済み）。

## LoopSpec

```yaml
loop:
  name: run-021-optimize-f41
  trigger: {type: manual, detail: "運用改善の継続指示。Run-020 事後注記の繰延分（F-41 予定）の正本化"}
  goal:
    description: "loopspec.md の F-39 注記直後に F-41（件数集計型 AC は前段成功を && で担保）を追記 + 台帳へ F-41 行を同時発行"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-4"
  context:
    include: [run_frictions, design_docs, diff]
    external_sources:
      - "PR #769 Gemini レビュー指摘（silent pass リスク・転記時は出典明示）"
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
      - cmd: "grep -qF '前段コマンドの成功' docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-1 F-41 正本化（FAIL 方向 0/exit1・PASS 方向は実挿入フォーマットで実測 — F-39 適用）
      - cmd: "test \"$(grep -cE '^\\| F-41 ' docs/working/ai-loop-runs/run-001-frictions.md)\" -eq 1"
        expect_exit: 0
        note: AC-2 台帳への同時発行（現状 0 = FAIL・1 行サンプルで PASS を実測。grep -c は単一コマンドでパイプ集計を含まず F-41 の対象外形）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/workflows/ai-loop/loopspec.md docs/working/ai-loop-runs/run-001-frictions.md"
        expect_exit: 0
        note: AC-3
      - cmd: "git diff --name-only origin/main -- docs/workflows/ > /tmp/run021.diff && test \"$(wc -l < /tmp/run021.diff | tr -d ' ')\" -le 1"
        expect_exit: 0
        note: AC-4 対象 1 ファイル（**F-41 形式の初適用** — 前段 git diff の成功を && で担保。前段失敗時に exit≠0 となることを存在しない ref で実証済み）
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

1. **loopspec.md** の F-39 注記の直後に追記:

   「件数上限・件数一致型の AC（`wc -l` 等の集計結果を test で比較する形）は、
   **前段コマンドの成功**を `&&` で担保してから集計する（前段が失敗すると空出力 = 0 件
   として偽 PASS する silent pass を防ぐ — F-41。Run-020 AC-4 への外部レビュー指摘が
   起点・実害未発生のうちの予防的正本化）。」

2. **run-001-frictions.md** 末尾に新節「## Run-021 での摩擦（2026-07-08 追記）」+ 表 1 行:

   「| F-41 | 件数上限型 AC（`test "$(... \| wc -l)" -le N` 形式）は前段コマンド失敗時に空出力 → 0 件で偽 PASS する（silent pass）。対策: 前段の成功を `&&` で担保してから集計する。PR #769 の Gemini 指摘由来・実害未発生のうちに台帳同時発行で予防的採番（#768 の発行規律に準拠） | AC の頑健性 |」

   （表ヘッダは既存 run 節と同じ `| # | 観測事実 | 種別 |`。台帳追記は append-only）

- 出典検証（F-37/F-38）: 「PR #769 の Gemini 指摘」は PR #769 レビューコメント
  （run-020-loopspec.md L41 への medium 指摘）に実在 — 本計画時に実読確認済み
- **Non-goals**: 既存 run 記録・既存 AC の遡及修正 / runbook・SKILL.md 変更
- **lite**: size_ok=true / no_new_design=true（Run-014/020 同型の規律追記 + 台帳 1 行）/
  follows_pattern=true / reversible=true
- **boundary**: clean / **class**: no-merge

---

## exec 記録

- W R1 A✓/B✓ ワンラウンド合意（B は旧形式の偽 PASS を実再現し F-41 の必要性を実証・
  /tmp 名前空間の残留懸念を non-blocking として明記）→ AUTO_APPROVED
- maker: AC 4 件 PASS・純追加（+5/+6）・printf 追記で F-32 回避
- rubric grader: **pass 5/5（3 run 連続）**
- orchestrator 独立再検証: AC 全 PASS・台帳 append-only 確認

---

## 事後注記（PR #770 Gemini レビュー由来・2026-07-08）

AC-4 の `/tmp/run021.diff` 経由形に対し、シェル変数形
`diff_files=$(git diff ...) && test "$(printf '%s\n' "$diff_files" | grep -c .)" -le N`
なら一時ファイル不要で並行衝突リスク（W チェック B も指摘した F-34 同族の残留懸念）を
排除できるとの指摘（妥当・採用）。変数形でも前段失敗 → exit≠0 となることを本注記時に
両方向実測済み。**以後の run の件数集計型 AC は変数形を推奨実装とする**。
本 LoopSpec の AC-4 は実行済みの時点記録として不変（正本 loopspec.md の F-41 文言は
実装非依存のため変更不要 — `&&` による前段担保という規律自体は両形式に共通）。
