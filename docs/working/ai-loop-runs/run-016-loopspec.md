# ai-loop Run-016 — LoopSpec + 計画（#753 gap 2: exec 差分 rubric grader の PoC）

> escalate 第2型を経由（HO 接触リスク + 進め方の設計選択）→ **Human 選択 1
> （2026-07-07・verbatim「1」）**: ai-loop 内で先に PoC。設計パラメータは提示選択肢の
> 記載で固定 — rubric は review-principles §2 の 5 観点由来（重複定義せず参照）・
> 不合格時はフィードバック付き再試行 ≤2・変更は ai-loop-cycle SKILL.md +
> execution-runbook のみ（HO 非接触）。本番（L-0/V-1）一般化は運用実績後の別 PBI。
> 分離 worktree 実行（F-33 対策・2 例目）。

## LoopSpec

```yaml
loop:
  name: run-016-rubric-grader-poc
  trigger: {type: manual, detail: "運用改善の継続指示 + issue #753 gap 2（Human 選択 1）"}
  goal:
    description: "ai-loop の exec 後段に maker 差分への rubric grader（合否+failed_criteria+フィードバックの構造化出力・不合格なら maker 再試行 ≤2）を追加する"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-4"
  context:
    include: [design_docs, run_frictions, diff]
    external_sources:
      - "issue #753 本文 gap 2 節（Anthropic Outcomes 対応の一般化検討・転記時は出典明示）"
    exclude: [stale_tool_outputs]
  scope:
    allowed_paths:
      - ".claude/skills/ai-loop-cycle/SKILL.md"
      - "docs/workflows/ai-loop/execution-runbook.md"
      - "docs/working/ai-loop-runs/**"
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - cmd: "grep -qF 'rubric grader' .claude/skills/ai-loop-cycle/SKILL.md"
        expect_exit: 0
        note: AC-1（FAIL 方向 0/exit1・PASS 方向 固定句そのもので実測済み — F-29 正本規律の初適用）
      - cmd: "grep -qF 'rubric grader' docs/workflows/ai-loop/execution-runbook.md"
        expect_exit: 0
        note: AC-2（同上）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc .claude/skills/ai-loop-cycle/SKILL.md docs/workflows/ai-loop/execution-runbook.md"
        expect_exit: 0
        note: AC-3
      - cmd: "test \"$(git diff --name-only origin/main -- docs/workflows/ .claude/skills/ | wc -l | tr -d ' ')\" -le 2"
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

## 計画

1. **SKILL.md**: Step 5（分岐後の行動）の AUTO_APPROVED → exec 経路に
   「Step 5.5: exec 差分への rubric grader」節を追加:
   - grader = maker と別の sonnet サブエージェント（maker≠grader・W チェック定型と同じ
     独立文脈方式）。入力 = maker 差分 + 計画の Goal/AC
   - **合否基準（rubric）**: review-principles §2 の 5 観点を参照で束ね（重複定義しない）、
     docs 変更に適用可能な形の固合否基準 5 項目に固定（各項目 pass/fail 判定可能な文で）
   - 出力定型（W チェックの 3 行 raw 形式踏襲・enum verbatim）:
     `verdict: pass|fail` / `failed_criteria: <項目番号列挙 or なし>` / `feedback: 1-3 文`
   - fail → feedback を添えて maker に再試行委託（**上限 2 回**）。上限超過 → HUMAN_ESCALATED
   - grader 結果は run 記録に貼付（証跡）
2. **execution-runbook**: §2 に「### (5b) exec 差分 rubric チェック（grader 再試行ループ）」を
   追加（既存 (6)(7) の番号は変更しない）。手順 + 上限 + escalate 先を記載

- **Non-goals**: PlanGate 本番 L-0/V-1 の変更・docs/ai/ 正本化・arbiter/schema 変更・
  W チェック（plan 側）の変更
- **lite**: size_ok=true / no_new_design=true（設計パラメータは Human 承認済み選択肢で
  固定・委託定型は W チェック形式のミラー）/ follows_pattern=true / reversible=true
- **boundary**: clean（.claude/skills = 非 HO（Run-004 前例）/ docs/workflows/ai-loop = ドメイン内）
- **class**: no-merge

---

## Round 2 改訂（R1: A=approve / B=reject(logic) — rubric 5 項目の exec 時定義先送りを解消）

> B 指摘（全採用）: (1) 合否基準 5 項目が計画に具体列挙されておらず「空洞化（例:
> セキュリティ=常に pass）」を事前レビューできない (2) grader 誤判定への歯止めが薄い。
> Round 1 本文は監査記録として不変・本節が確定する。

### 改訂 1 — rubric 合否基準 5 項目の確定列挙（maker はこの 5 項目をそのまま SKILL.md に転記する）

| # | 基準（review-principles §2 からの docs-run 翻訳） | fail 条件（判定可能形） |
|---|---|---|
| 1 | **正確性・正本整合**（保守性/可読性由来） | 差分中のファイルパス・コマンド・参照リンクに実在しないものが 1 つ以上ある、または参照正本と矛盾する記述がある |
| 2 | **要件適合**（計画との 1:1） | 計画の Goal・確定文言に対し宣言外の変更、または要求要素の欠落がある |
| 3 | **文体・構造踏襲**（可読性由来） | 追記が既存文書の見出し階層・表形式・文体から逸脱している |
| 4 | **境界安全**（セキュリティ由来） | 承認境界・HO 境界・停止規則を弱める/緩和する記述を含む |
| 5 | **重複定義回避**（拡張性/保守性由来） | 既存正本に定義済みの規範を参照でなく再定義している |

（パフォーマンス観点は docs-run では該当稀のため基準 1 に「実行例の到達性」として包含。
5 観点との対応は各行に明記し重複定義しない — 定義の正本は review-principles §2 のまま）

### 改訂 2 — grader 判定品質の歯止め

- **証跡引用の義務**: fail とする基準ごとに、差分からの**引用（行）を必須添付**。
  引用のない fail は無効（maker は再試行前に grader へ差し戻せる）
- pass にも基準ごとに 1 行の根拠を要求（全 5 行。「問題なし」のみは不可）
- 再試行上限 2 超過の HUMAN_ESCALATED 時は、**grader の全出力（引用込み）を人間へ提示**
  （false-fail 連鎖を人間が judged 可能にする）
- grader 出力は decision record と同様 run 記録へ全文貼付（監査可能性）

### 改訂 3 — AC の補強（両方向とも本改訂時に実測）

追加 AC-1b: `test "$(grep -cF '| fail 条件' .claude/skills/ai-loop-cycle/SKILL.md)" -ge 1 && test "$(grep -cF '引用' .claude/skills/ai-loop-cycle/SKILL.md)" -ge 1`
→ expect_exit 0（5 項目表と証跡引用義務が SKILL.md に実在することの検証。
FAIL 方向: 現状 grep -cF '| fail 条件' = 0 / exit1。PASS 方向: 本節の表見出し行そのもの
（`| # | 基準（...） | fail 条件（判定可能形） |` を含むサンプル）で 1 以上を実測）

---

## Round 3 — 最終確定 AC（機械可読 consolidated ブロック / R2 B=reject(format) 採用）

> B 指摘（採用）: AC-1b が地の文のみで F-30 正本規律（#763 で正本化・AC 変更は
> consolidated ブロック追記）に不準拠だった。**F-30 を正本化した直後の run で
> F-30 違反を B が検出** — 正本化した規律が即座に checker の判定基準として機能した。
> Round 1-2 は監査記録として不変。maker・検証者は本ブロックのみを実行する。

```yaml
verification_final:
  deterministic:
    - cmd: "grep -qF 'rubric grader' .claude/skills/ai-loop-cycle/SKILL.md"
      expect_exit: 0
      note: AC-1（R1 から不変・両方向実測済み）
    - cmd: "test \"$(grep -cF '| fail 条件' .claude/skills/ai-loop-cycle/SKILL.md)\" -ge 1 && test \"$(grep -cF '引用' .claude/skills/ai-loop-cycle/SKILL.md)\" -ge 1"
      expect_exit: 0
      note: AC-1b 5 項目表 + 証跡引用義務の実在（Round 2 で追加・FAIL 方向 0/exit1・PASS 方向は表見出し行そのものを含むサンプルで実測済み）
    - cmd: "grep -qF 'rubric grader' docs/workflows/ai-loop/execution-runbook.md"
      expect_exit: 0
      note: AC-2（R1 から不変）
    - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc .claude/skills/ai-loop-cycle/SKILL.md docs/workflows/ai-loop/execution-runbook.md"
      expect_exit: 0
      note: AC-3
    - cmd: "test \"$(git diff --name-only origin/main -- docs/workflows/ .claude/skills/ | wc -l | tr -d ' ')\" -le 2"
      expect_exit: 0
      note: AC-4 対象 2 ファイルのみ
  review: [requirements_fit, no_duplication]
```

---

## 事後注記（公開前改番: Run-015 → Run-016）

本 run は計画時 Run-015 として起動したが、exec 完了時点で並行セッションが
run-015 番号を先に公開済み（PR #764 の run-015-loopspec.md・PR #762 レビュー対応記録）
であることを検出した（run 番号の名前空間が多セッション間で調整されていない — 摩擦 F-34）。
**本記録は未公開（未コミット）段階だったため Run-016 へ改番**した。公開済み監査記録の
遡及編集には当たらない。W チェック・arbiter record 内の言及は改番前の名称のまま
（時点記録として不変・本注記が対応関係を確定する）。
