# ai-loop Run-011 — LoopSpec + 計画（摩擦記録 hygiene: Dreams パターンの初適用）

> #751 intake で「hygiene は効果測定後に判断（I-5）」とした件。F-1〜F-24（24 件）が揃い、
> 複数の Optimize が効果実測済みとなったため、
> **base: feat/ai-loop-run-010（#755・未マージ）にスタック** — Run-011 も frictions へ追記するため
> 同一ファイル追記の衝突を回避（Run-005 先例。main 基点では F-22 まで・スタック基点で F-24 まで、
> の接地差も本スタックで解消）。squash 後は rebase --onto で追従。
> **元ログ不変（working-discipline skill 原則 11）+ 新規ダイジェスト生成 +
> 人間レビュー（C-4）で採用**という Dreams / growth-core:memory-dream と同型の手続きで実施。

## LoopSpec

```yaml
loop:
  name: run-011-frictions-hygiene-digest
  trigger: {type: manual, detail: "運用改善の継続指示。#751 hygiene 判断の効果測定素材が充足"}
  goal:
    description: "F-1〜F-24 を検証つきで棚卸しし frictions-digest-001.md（新規・派生成果物）を生成。元ログは不変"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-5"
  context:
    include:
      - run_frictions # 全 F エントリ（run-001-frictions.md）
      - design_docs # 各 Optimize の反映先正本（検証用）
      - diff
    exclude:
      - stale_tool_outputs
    external_sources: [] # 外部入力なし（明示。Run-010 の機構 — PR 未マージだが宣言規律を先行遵守）
  scope:
    allowed_paths:
      - "docs/working/ai-loop-runs/**"
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - cmd: 'test -f docs/working/ai-loop-runs/frictions-digest-001.md'
        expect_exit: 0
        note: AC-1 digest 実在
      - cmd: 'M=0; for i in $(seq 1 24); do grep -qE "F-$i([^0-9]|$)" docs/working/ai-loop-runs/frictions-digest-001.md || M=$((M+1)); done; test "$M" -eq 0'
        expect_exit: 0
        note: AC-2 全 24 ID 収録。**初版の grep -q "F-$i" は部分一致バグ（F-2 が F-24 にマッチ）を
          事前検証で自己検出し境界つきに修正**（F-12/F-16 の規律が機能した実例）。修正版で
          FAIL 方向 missing=22・PASS 方向（全 24 ID サンプル）missing=0 を実測済み
      - cmd: 'test "$(git diff --numstat docs/working/ai-loop-runs/run-001-frictions.md | wc -l | tr -d " ")" -eq 0'
        expect_exit: 0
        note: AC-3 元ログ不変（working-discipline skill 原則 11）
      - cmd: 'npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/working/ai-loop-runs/frictions-digest-001.md'
        expect_exit: 0
        note: AC-4 lint
    review:
      - requirements_fit
      - no_reinterpretation # digest が元記録の意味を改変・誇張していない（要約の忠実性）
  stopping_rule:
    terminal_state_ref: "decision-table.md"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write: [decision_record, run_frictions]
    ref: "execution-runbook.md §2-(4)"
  escalation: {touches_ho: unconditional, budget_ref: "arbiter-policy.md §7"}
```

## 計画

- **digest の構成（memory-dream / improvement-seeds の既存パターン踏襲 = no_new_design）**:
  1. 状態表: 各 F-ID × {**optimized-verified**（反映先正本を grep で実測できたもののみ）/
     **open**（未対応 backlog）/ **恒久教訓**（skill/正本に昇格済み）} + 反映先リンク
  2. open backlog の優先順（次 run 候補）
  3. メタ観測（ラウンド数推移・escalate 型の分布など、記録から機械的に導ける範囲のみ）
- **忠実性規律**: digest は要約であり解釈の追加・誇張をしない（review 観点 no_reinterpretation）。
  「optimized-verified」判定は**反映先の grep 実測を伴う場合のみ**（F-14: 証跡つき）
- **Files（Expected Diff）**: `docs/working/ai-loop-runs/frictions-digest-001.md`（新規）のみ
  （+ 本 run 記録）。**run-001-frictions.md には触れない**
- **lite 4 軸**: size_ok=true / no_new_design=true（既存パターン踏襲の派生成果物・正本/schema 変更なし）/
  follows_pattern=true / reversible=true
- **boundary**: clean / **class**: no-merge
