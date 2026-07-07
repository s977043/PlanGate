# ai-loop Run-019 — LoopSpec + 計画（摩擦 ID 台帳の単一権威化）

> 昨日の棚卸しで検出した整合課題の解消 run: 並行セッションの run 記録（run-015/016/018）
> で発行された F-35〜F-39 が台帳（run-001-frictions.md）に行として存在せず、
> 「ID の単一権威」が構造化されていない。台帳へ出典つきで追記（append-only）し、
> 「新 ID は台帳追記と同時にのみ発行」を runbook 正本へ昇格する。
> §2-(0) 採番 2 点照合の 1 点目実施済み（run-019 空きを実測）。分離 worktree 実行。

## LoopSpec

```yaml
loop:
  name: run-019-friction-ledger-authority
  trigger: {type: manual, detail: "運用改善の継続指示 + 2026-07-07 棚卸しで検出した台帳整合課題"}
  goal:
    description: "run-001-frictions.md に F-35〜F-39 を出典つきで追記（5 行）+ execution-runbook §2-(4) に台帳単一権威の規律 1 節を追記"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-5"
  context:
    include: [design_docs, run_frictions, diff]
    external_sources: []
    exclude: [stale_tool_outputs]
  scope:
    allowed_paths:
      - "docs/working/ai-loop-runs/**"
      - "docs/workflows/ai-loop/execution-runbook.md"
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - cmd: "test \"$(grep -cE '^\\| F-3[5-9] ' docs/working/ai-loop-runs/run-001-frictions.md)\" -eq 5"
        expect_exit: 0
        note: AC-1 F-35〜39 の台帳行が正確に 5（FAIL 方向 0・PASS 方向 5 行サンプル、閾値そのもので実測済み）
      - cmd: "grep -qF '単一権威' docs/workflows/ai-loop/execution-runbook.md"
        expect_exit: 0
        note: AC-2 規律の正本化（両方向実測済み）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/working/ai-loop-runs/run-001-frictions.md docs/workflows/ai-loop/execution-runbook.md"
        expect_exit: 0
        note: AC-3
      - cmd: "test \"$(git diff --name-only origin/main -- docs/workflows/ | wc -l | tr -d ' ')\" -le 1"
        expect_exit: 0
        note: AC-4 runbook のみ
      - cmd: "git diff origin/main -- docs/working/ai-loop-runs/run-001-frictions.md | grep -c '^-[^-]'"
        expect_exit: 1
        note: AC-5 台帳 append-only（F-28 厳密形・削除行 1 のサンプルで exit0=検知可を実測済み）
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

1. **台帳追記（run-001-frictions.md 末尾に新節）**: 「並行セッション発行分の台帳転記
   （2026-07-08・出典つき）」として F-35〜F-39 の 5 行を表形式で追記。各行は
   **原文 run 記録からの要約転記 + 出典（run doc 名 / PR 番号）を明記**（F-37 の
   転記規律に従い、参照する run doc・PR 番号は実在を検証してから転記）:
   - F-35（AC 転記の実行形乖離 → 機械的参照値全般の転記規律へ拡張）出典: run-016-loopspec.md / PR #765
   - F-36（add/add 衝突の inverted 解決・stage 表示同定で是正）出典: run-015-loopspec.md / PR #764
   - F-37（実在しない出典 ID の手書き転記）出典: run-018-loopspec.md / PR #767
   - F-38（記録なき実践主張 — 出典は run 記録・PR・実測出力で検証可能であること）出典: run-018-loopspec.md / PR #767
   - F-39（grep -F 型 AC の PASS 事前検証は実挿入フォーマットで）出典: run-018-loopspec.md / PR #767
   - 冒頭に「意味の定義は各出典 run 記録が一次記録・本表は ID 台帳としての索引」と明記
     （二重定義でなく索引化 — 既存の run 内定義を正とする）
2. **runbook §2-(4)（memory / record 保存節）へ規律 1 節追記**:
   「**摩擦 ID は台帳（run-001-frictions.md）が単一権威**。新しい F-NNN は台帳への
   追記と**同時にのみ**発行する（run 記録・PR 本文のみでの新 ID 発行は不可 —
   多セッション並行時の二重採番防止。F-34 と同根・2026-07-08 の F-35〜39 台帳欠落が実例）。
   採番前に台帳の最大 ID を確認する（§2-(0) の run 採番照合と同型）。」

- **Non-goals**: 既存 run 記録内の F 番号の書き換え（監査記録不変）/ 台帳既存行の編集 /
  SKILL.md 変更
- **lite**: size_ok=true / no_new_design=true（F-34 対策・§2-(0) と同型の規律追加 +
  索引転記のみ）/ follows_pattern=true / reversible=true
- **boundary**: clean（両パスともドメイン内・HO 非接触）
- **class**: no-merge

---

## Round 2 改訂（R1: A=reject(documentation) / B=reject(documentation) — 転記内容の是正）

> **台帳単一権威化の run 自身が F-37 型の転記誤りを 2 種犯していた**のを A/B が独立検出:
> A = 出典の採番元取り違え（F-35/F-37 を「正本化した run」に帰属させ「採番した run」を
> 誤記）/ B = F-35 の要約に F-37 の定義文言（機械的参照値全般への拡張）を混入。
> 全採用。以下の確定転記表が Round 1 計画の転記 5 件を**置換**する
> （各行は採番元 doc の原文を実読して要約・本改訂時に git show で照合済み）。

### 確定転記表（maker はこの 5 行の内容をそのまま台帳の表形式に転記する）

| ID | 要約（採番元原文に忠実） | 採番元（一次記録） | 正本化 |
|---|---|---|---|
| F-35 | 「実行した検証コマンド」と「記録に転記したコマンド」が乖離し転記側が検証不能形だった（実測自体は正しい形で実施・結論は有効）。対策: AC 転記は実行履歴からのコピーとし手書き整形を禁じる | run-015-loopspec.md L125（PR #764） | PR #765 |
| F-36 | add/add 衝突解決時に rebase の ours/theirs 方向を取り違え、並行 run の記録を自分の内容で上書きする inverted 解決を一度生成（自己検出し再生成で是正・損失なし） | run-015-loopspec.md（PR #764） | PR #767 |
| F-37 | 出典 ID の手書き転記による誤記。F-35 の適用範囲を『AC コマンド』から『出典 ID 等の機械的参照値全般』へ広げる拡張は採番時点ではスコープ外・次 Optimize 候補とされた | run-016-loopspec.md L98（PR #765） | PR #767 |
| F-38 | run 記録に残っていない実践をセッション記憶から実例として主張。出典は run 記録・PR・実測出力のいずれかで検証可能でなければならない | run-018-loopspec.md（PR #767） | —（未正本化） |
| F-39 | grep -F 型 AC の PASS 方向事前検証は実際の挿入フォーマット（行折り返し・インデント含む）で行う | run-018-loopspec.md（PR #767） | —（未正本化） |

- AC 1-5 は Round 1 のまま不変（consolidated ブロック追記は不要 — F-30 は「AC の変更」時
  のみ要求。本改訂は転記**内容**の是正で AC は変わらない）
- 本 run の摩擦記録に追加: **F-40（新規・台帳追記と同時発行）**: 「摩擦の索引転記では
  『採番した run（一次記録）』と『正本化した run』を区別して出典を書く —
  取り違えは意味の系譜（何が実害で何が対策かの帰属）を壊す」

---

## Round 3 — 最終確定（R2: A=approve / B=reject(documentation) — F-40 の自己整合是正）

> B 指摘（採用）: 「新 ID は台帳追記と同時にのみ発行」を正本化する本 run 自身が、
> F-40 を run 記録で先行発行し台帳追記を AC/goal でカバーしていなかった（是正対象の再演）。
> **F-40 も台帳同時追記の対象に含め、goal を「6 行」に、AC-1 を F-40 込みに拡張**する。
> AC 変更につき F-30 に従い consolidated ブロックで最終確定。Round 1-2 は監査記録として不変。

### 最終確定 AC（機械可読 consolidated ブロック / maker・検証者は本ブロックのみ実行）

```yaml
verification_final:
  deterministic:
    - cmd: "test \"$(grep -cE '^\\| F-(3[5-9]|40) ' docs/working/ai-loop-runs/run-001-frictions.md)\" -eq 6"
      expect_exit: 0
      note: AC-1v2 F-35〜F-40 の台帳行が正確に 6（FAIL 方向 現状 0 / 6 行サンプルで exit0 / 5 行では exit1 — 全て本改訂時に実測）
    - cmd: "grep -qF '単一権威' docs/workflows/ai-loop/execution-runbook.md"
      expect_exit: 0
      note: AC-2（R1 から不変）
    - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/working/ai-loop-runs/run-001-frictions.md docs/workflows/ai-loop/execution-runbook.md"
      expect_exit: 0
      note: AC-3
    - cmd: "test \"$(git diff --name-only origin/main -- docs/workflows/ | wc -l | tr -d ' ')\" -le 1"
      expect_exit: 0
      note: AC-4 runbook のみ
    - cmd: "git diff origin/main -- docs/working/ai-loop-runs/run-001-frictions.md | grep -c '^-[^-]'"
      expect_exit: 1
      note: AC-5 台帳 append-only（F-28 厳密形・両方向実測済み）
  review: [requirements_fit, no_duplication]
```

### F-40 の台帳行（確定転記表に 6 行目として追加・maker はそのまま転記）

| F-40 | 摩擦の索引転記では「採番した run（一次記録）」と「正本化した run」を区別して出典を書く — 取り違えは意味の系譜を壊す（本 run R1 で A/B が独立検出した実害） | run-019-loopspec.md R2（本 run・台帳追記と同時発行） | —（未正本化） |

---

## exec 記録（Step 5.5 rubric grader 適用・本セッション初）

- maker: AC 全 PASS・純追加 diff（+20/-0）・printf 追記で F-32 回避・F-39 遵守（1 行 1 レコード）
- **rubric grader（独立サブエージェント）: verdict pass / failed_criteria なし** — 5 基準
  すべてに引用つき根拠（出典行番号の実在照合・確定転記表との一言一句一致・既存表様式の
  precedent 確認・境界強化方向の確認・単一権威の重複定義なし grep 実測）。
  判定/証跡ブロック分離形式（Run-016 の Gemini 指摘反映後の形）が設計どおり機能
- orchestrator 独立再検証: consolidated 5 件 PASS
