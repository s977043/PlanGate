# ai-loop Run-005 — LoopSpec + 計画（F-14: 「検証済み」申告への証跡要求の運用化）

> Run-004 で暴露された虚偽申告（「実機で両方向検証済み」と書きながら AC-2 未検証）への
> Optimize。**前 run の摩擦を即・次 run で規律化**する 1 サイクル。
> **base: feat/ai-loop-run-004（#743・未マージ）にスタック** — 同一 2 ファイルの編集につき
> 並行作業確認で main 基点を棄却（squash 後は rebase --onto で追従）。
> AC 事前検証の**実行出力証跡**は本 run の作業ログに残置（F-14 の自己適用）:
> AC-1/AC-2 とも FAIL 方向 count=0/exit=1 を実測済み・PASS 方向はサンプル入力で 1 を実測済み。

## LoopSpec

```yaml
loop:
  name: run-005-evidence-for-verification-claims
  trigger:
    type: manual
    detail: "運用改善の継続指示。F-14（Run-004 R1 で B が虚偽申告を暴露）の Optimize"
  goal:
    description: "『検証済み』という申告には実行出力（コマンド+結果）の貼付を必須とする規律を、loopspec.md（申告側）と ai-loop-cycle SKILL.md（W チェックのレビュー側）の双方に追記"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-4"
  context:
    include:
      - run_frictions # F-14（run-001-frictions.md Run-004 節）
      - design_docs # loopspec.md（Run-004 で入った F-12 文の直後が挿入位置）/ ai-loop-cycle SKILL.md
      - diff
    exclude:
      - stale_tool_outputs
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      # F-12/F-14 自己適用: 両コマンドとも本計画時に実機で両方向確認・出力は上記ヘッダに証跡残置
      - "grep -cF '実行出力' docs/workflows/ai-loop/loopspec.md → 1 以上（AC-1）"
      - "grep -cF '証跡' .claude/skills/ai-loop-cycle/SKILL.md → 1 以上（AC-2）"
      - "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc（2ファイル）→ 0 error（AC-3）"
      - "git diff --name-only（base=feat/ai-loop-run-004）が宣言 2 ファイル + run 記録に収まる（AC-4）"
    review:
      - requirements_fit
      - no_bureaucracy # 証跡要求が軽量か（貼付は「実行した出力そのまま」でよく、整形・スクショ等の重い要求にしない）
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

- **確定追記文言（一字一句そのまま・Run-004 R2 の教訓で AC 固定句と文言を最初から結合）**:
  1. `docs/workflows/ai-loop/loopspec.md` — Run-004 で追記した F-12 規律文の直後に:
     「また、『実機で確認した』という申告には**実行出力（コマンドと結果）の貼付**を必須とする。
     証跡のない事前検証申告は未検証として扱う（実例: Run-004 R1 — 申告のみで未検証だった
     AC が W チェックで exit 2 を実機再現され虚偽と判明）。」
  2. `.claude/skills/ai-loop-cycle/SKILL.md` — Model A 委託プロンプト定型の観点行
     （「観点: 設計妥当性・受入基準（AC）網羅・スコープ整合。」）を次で置換:
     「観点: 設計妥当性・受入基準（AC）網羅・スコープ整合。計画中の『検証済み』申告には
     **証跡（実行出力の貼付）**があるか確認し、なければ未検証として扱う。」
- **固定句の包含を実測**: 文言 1 は「実行出力」を含む（AC-1 と結合）・文言 2 は「証跡」を
  含む（AC-2 と結合）— printf | grep -cF で各 1 を確認済み（証跡はヘッダ注記のとおり）。
- **Non-goals**: working-discipline 原則 12 本文の変更（参照のみ・重複定義しない）/
  Model B 定型の変更（申告検証は順方向 A の責務）
- **Files（Expected Diff）**: 上記 2 ファイルのみ
- **lite 4 軸**: size_ok=true / no_new_design=true / follows_pattern=true / reversible=true
- **boundary**: clean / **class**: no-merge
