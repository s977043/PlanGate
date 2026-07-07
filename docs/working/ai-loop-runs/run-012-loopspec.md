# ai-loop Run-012 — LoopSpec + 計画（F-27/F-28 の正本化）

> 本日の運用で確立・実践済みの 2 規律を正本へ明文化する Optimize
> （摩擦記録 F-27/F-28 → 実践 → 本 run で正本化。I-5 の記録→最適化順序に準拠）。
> 並行中の doctor バッチ（main ワークツリー）と対象ファイルが重ならないことを確認済み。

## LoopSpec

```yaml
loop:
  name: run-012-f27-f28-canonicalization
  trigger:
    {
      type: manual,
      detail: "運用改善の継続指示。F-27（ユーザー検出の運用ギャップ）対策の正本化",
    }
  goal:
    description: "execution-runbook §2-(7) に「AI レビュー着弾確認 → 対応 → auto-merge arm」の順序を手順として明文化 + loopspec 検証節に digest 系 AC の厳密形（F-28）を注記"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-4"
  context:
    include: [run_frictions, design_docs, diff]
    exclude: [stale_tool_outputs]
    external_sources: []
  scope:
    allowed_paths:
      - "docs/workflows/ai-loop/**"
      - "docs/working/ai-loop-runs/**"
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - cmd: 'test "$(grep -cF "auto-merge" docs/workflows/ai-loop/execution-runbook.md)" -ge 2'
        expect_exit: 0
        note: AC-1 F-27 手順の明文化（現状 0/exit1 実測・サンプル 1 実測）
      - cmd: 'grep -qF "削除行ゼロ" docs/workflows/ai-loop/loopspec.md'
        expect_exit: 0
        note: AC-2 F-28 厳密形注記（現状 0/exit1 実測）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/workflows/ai-loop/execution-runbook.md docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-3
      - cmd: 'test "$(git diff --name-only origin/main -- docs/workflows/ | wc -l | tr -d " ")" -le 2'
        expect_exit: 0
        note: AC-4 対象 2 ファイル以内（run 記録は docs/working）
    review: [requirements_fit, no_duplication]
  stopping_rule:
    terminal_state_ref: "decision-table.md"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write: [decision_record, run_frictions]
    ref: "execution-runbook.md §2-(4)"
  escalation: { touches_ho: unconditional, budget_ref: "arbiter-policy.md §7" }
```

## 計画（確定追記文言）

1. **execution-runbook.md §2-(7) 実行手順**の手順 3（AI レビュー指摘確認）を以下で置換・拡張:
   「3. **AI レビューの着弾を確認してから次へ進む**（PR 作成直後は未着弾のことがある —
   着弾前に auto-merge を arm すると、指摘未対応のままマージされ得る。F-27 の実害経路）。
   CI/PR 時の AI レビュー指摘を確認し、各指摘について**採用して修正**するか、
   **理由付きで不採用とする**かを記録する。
   **auto-merge の arm は、指摘対応完了（または指摘なしの確認）の後に行う**。」
2. **loopspec.md** の deterministic フィールド注記（F-12 文の周辺）に 1 文:
   「ログ・台帳系の AC は厳密形を用いる — ID 収録は表行限定（行頭 `^| ID` 一致）、
   append-only の不変検証は**基準コミット比の削除行ゼロ**（部分一致・ステージング依存の
   偽陽性を防ぐ。F-28）。」

- **lite**: size_ok=true / no_new_design=true（実践済み規律の明文化のみ）/
  follows_pattern=true / reversible=true
- **boundary**: clean / **class**: no-merge

---

## Round 2 改訂（R1: A=approve / B=reject(logic) — AC-1 事前検証の自己矛盾）

> B 指摘（採用）: AC-1 は `grep -cF "auto-merge"` **≥ 2** を要求するのに、Round 1 の
> 事前検証は「PASS サンプル 1 実測」— 要求水準（≥2）を満たす入力での PASS 方向を
> 一度も実測していなかった（F-12 の要求「AC に採用する条件そのものでの両方向確認」の
> 不履行。F-14 と同型の note↔要求の不整合）。Round 1 本文は監査記録として不変。

### 改訂 1 — AC-1 を確定文言そのもので再検証（本改訂時に実測済み）

runbook へ挿入する**確定文言**（手順 3 置換・maker はこの文言をそのまま使う):

「3. **AI レビューの着弾を確認してから次へ進む**（PR 作成直後は未着弾のことがある —
着弾前に auto-merge を arm すると、指摘未対応のままマージされ得る。F-27 の実害経路）。
CI/PR 時の AI レビュー指摘を確認し、各指摘について**採用して修正**するか、
**理由付きで不採用とする**かを記録する。
**auto-merge の arm は、指摘対応完了（または指摘なしの確認）の後に行う**。」

実測（本改訂の直前に実行・貼付）: 上記文言を一時ファイルに書き
`grep -cF 'auto-merge'` → **2**（`test -ge 2` → exit 0 = PASS 方向 ✓）。
FAIL 方向: 現状 runbook で count=0 / exit 1 ✓。AC-1 の要求（≥2）と事前検証が一致した。

### 改訂 2 — 摩擦記録

F-12 の運用不履行（要求水準未満のサンプルでの PASS 申告）を run_frictions に F-29 として
記録する（Optimize 候補: 「PASS 方向の実測は **AC の閾値・条件そのもの**で行う」を
loopspec.md の F-12 文に含めるかは本 run の AC-2 追記と別に判断 — スコープ外）。

---

## Round 3 改訂（Human 指示による前提変更・最終）

> **Human 指示（2026-07-07・verbatim）**: 「auto-mergeを設定するのはやめたい」
>
> Round 2 までの確定文言は「レビュー対応完了後に auto-merge を arm」という運用を
> 正本化する内容だったが、本指示により **auto-merge 自体を廃止**する。実運用も
> 即時追従済み（PR #757/#758 の auto-merge を解除・autoMergeRequest=null を実測）。
> Round 1-2 本文は監査記録として不変。本節の確定文言・AC が最終。

### 改訂 3 — runbook へ挿入する最終確定文言（手順 3 置換・maker はそのまま使う）

「3. **AI レビューの着弾を確認してから次へ進む**（PR 作成直後は未着弾のことがある —
着弾前にマージ準備を完了扱いにすると、指摘未対応のままマージされ得る。F-27 の実害経路）。
CI/PR 時の AI レビュー指摘を確認し、各指摘について**採用して修正**するか、
**理由付きで不採用とする**かを記録する。**auto-merge は使用しない**
（2026-07-07 Human 指示）。指摘対応完了（または指摘なしの確認）後に merge-ready 報告を
行い、マージは Human が実行する（responsibility-classes: merge は Human-owned）。」

### 改訂 4 — AC-1 の置換（本改訂時に両方向実測済み）

- **新 AC-1**: `grep -qF 'auto-merge は使用しない' docs/workflows/ai-loop/execution-runbook.md`
  → exit 0。FAIL 方向: 現状 0 件 / exit 1 実測 ✓。PASS 方向: 上記確定文言サンプルで exit 0 実測 ✓
- **不採用（F-12 が検出）**: 固定句 `merge-ready` の AC 化は、現行 runbook に既に
  7 箇所存在し FAIL 方向が成立しないため**採用しない**（既在句は変更検証にならない）
- AC-2（F-28「削除行ゼロ」）・AC-3（markdownlint）・AC-4（≤2 ファイル）は Round 1-2 のまま

### 補足 — 本改訂の承認根拠

前提変更は Human の明示指示そのもの（escalate 第2型と同型: Human 判断が計画に注入された）。
文言は指示を転記し、responsibility-classes 正本（merge は Human-owned）と整合させたのみで
no_new_design=true を維持する。

---

## 最終確定 AC（機械可読 consolidated deterministic ブロック / HUMAN_ESCALATED 解消・Human 選択 1）

> **Human 判断（2026-07-07・escalate 解消）**: C/D 不一致（record:
> `20260707T092419Z-9d7af43-run012-r3.json` / decision=HUMAN_ESCALATED）に対し、
> Human が選択肢 1（consolidated ブロックの追記方式）を採択。YAML 原文は遡及編集せず
> （監査記録不変原則）、**maker・検証者は本ブロックのみを実行する**。
> 旧 AC-1（auto-merge ≥2）は本ブロックに存在しない＝失効。

```yaml
verification_final:
  deterministic:
    - cmd: "grep -qF 'auto-merge は使用しない' docs/workflows/ai-loop/execution-runbook.md"
      expect_exit: 0
      note: AC-1（Round 3 置換版。FAIL 方向 exit1 / PASS 方向 exit0 実測済み）
    - cmd: "grep -qF '削除行ゼロ' docs/workflows/ai-loop/loopspec.md"
      expect_exit: 0
      note: AC-2（F-28。現状 0 / exit1 実測済み）
    - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/workflows/ai-loop/execution-runbook.md docs/workflows/ai-loop/loopspec.md"
      expect_exit: 0
      note: AC-3
    - cmd: "test \"$(git diff --name-only origin/main -- docs/workflows/ | wc -l | tr -d ' ')\" -le 2"
      expect_exit: 0
      note: AC-4 対象 2 ファイル以内
```

摩擦記録: F-30「AC を Round 改訂で変更した場合、機械可読な consolidated deterministic
ブロックを追記する（文章宣言のみでは機械実行前提の YAML と食い違う — C 指摘）」を
run_frictions に記録。次 run 以降で loopspec.md への正本化を Optimize 候補とする。
