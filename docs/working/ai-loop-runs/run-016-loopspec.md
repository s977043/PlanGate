# ai-loop Run-016 — LoopSpec + 計画（F-34/F-35 の正本化 Optimize run）

> Run-015（PR #762 レビュー対応）で記録した摩擦のうち、同日 2 回再発した
> F-34（run 採番衝突）と、F-12/F-29 系列の F-35（AC 転記の実行形乖離）を
> 正本へ昇格する（I-5: 記録→実践→正本化。Run-012/014 と同型の Optimize run）。
> F-31/F-32/F-33/F-36 は ai-loop 正本の範囲外（権限運用・hook 設定・git 一般規律）
> のため本 run では扱わない（スコープ制御・Run-015 に記録済み）。

## LoopSpec

```yaml
loop:
  name: run-016-f34-f35-canonicalization
  trigger:
    { type: manual, detail: "Human 指示（2026-07-07 verbatim）: 「ai-loopで対応を進めて、運用の中で改善を進めたい」（2 回目の同文指示 = 継続委任）" }
  goal:
    description: "execution-runbook §2 に run 採番手順（起票時 + PR 作成直前の 2 点照合）を追加（F-34）+ loopspec.md F-12 文に AC 転記規律（実行履歴からのコピー・手書き整形禁止）を追加（F-35）"
    exit_criteria_ref: "本書 AC 1-4"
  context:
    include: [run_frictions, design_docs, diff]
    exclude: [stale_tool_outputs]
    external_sources:
      - "PR #764 gemini-code-assist レビューコメント id:3535921211 系（AC-4 here-string 欠陥指摘）— F-35 の実例出典（run-015-loopspec.md に出典つき引用で記録済み）"
  scope:
    allowed_paths:
      - "docs/workflows/ai-loop/**"
      - "docs/working/ai-loop-runs/**"
  actors:
    maker: main_agent(fable)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      - cmd: "grep -qF 'PR 作成直前に同じ照合を再実行' docs/workflows/ai-loop/execution-runbook.md"
        expect_exit: 0
        note: AC-1 F-34 採番手順の明文化（FAIL 方向 exit1 / PASS 方向サンプル exit0 実測済み）
      - cmd: "grep -qF '実行履歴からのコピー' docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-2 F-35 転記規律（FAIL 方向 exit1 / PASS 方向サンプル exit0 実測済み）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/workflows/ai-loop/execution-runbook.md docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-3
      - cmd: "test \"$(git diff origin/main --name-only -- docs/workflows/ | sort | tr '\n' ',')\" = 'docs/workflows/ai-loop/execution-runbook.md,docs/workflows/ai-loop/loopspec.md,'"
        expect_exit: 0
        note: AC-4 対象 2 ファイルのみ（run 記録は docs/working。マージ前ブランチ上で実行 — Run-015 F-35 教訓の適用）
    review: [requirements_fit, no_duplication]
  stopping_rule:
    terminal_state_ref: "decision-table.md"
    round_limit_ref: "execution-runbook.md §2-(7)（上限3）"
  memory:
    write: [decision_record, run_frictions]
    ref: "execution-runbook.md §2-(4)"
  escalation: { touches_ho: unconditional, budget_ref: "arbiter-policy.md §7" }
```

## 計画（確定追記文言）

1. **execution-runbook.md §2** に「### (0) run 採番（起票時 + PR 作成直前の 2 点照合）」を
   「### (1) 変更ファイルリスト取得」の直前へ新設:
   「run 番号は**起票時**に `git fetch origin` 後、origin/main の
   `docs/working/ai-loop-runs/` 一覧と open PR（使用中ブランチ・記録ファイル）を
   照合し、最大番号 +1 を仮採番する。さらに **PR 作成直前に同じ照合を再実行**し、
   並行 run による先取（同一パス add/add 衝突）を検出した場合は改番してから
   PR を作成する（F-34: 同日 2 回の採番衝突 — Run-013→014→015 の二重改番が実害）。」
2. **loopspec.md** F-12 文（F-29 文の直後）に 1 段落:
   「AC の転記は**実行履歴からのコピー**とする — 実測に使ったコマンド文字列を
   そのまま `cmd` へ転記し、手書き整形・等価に見える別形への書き換え（例:
   `test` 比較を `diff` 形へ）をしない。転記形は実行形と乖離した時点で未検証に
   戻る（実例: Run-015 F-35 — `| diff - /dev/stdin <<<` への手書き変換が
   here-string の stdin 上書きにより常時 exit 0 の検証不能形となった）。」

- **lite**: size_ok=true（2 ファイル）/ no_new_design=true（実践済み規律の明文化のみ・
  Run-012/014 と同型）/ follows_pattern=true（F-27/F-28/F-29/F-30 正本化のミラー）/
  reversible=true（revert 一発）
- **boundary**: clean（docs/workflows/ai-loop のみ・HO 9 カテゴリ非該当）
- **class**: no-merge

---

## Round 2 改訂（R1: A=approve / B=reject(documentation) — external_sources ID 誤記）

> B 指摘（採用・maker 実測で裏付け済み）: external_sources に記載した gemini
> コメント ID `3535921211` は実在しない。`gh api repos/s977043/plangate/pulls/764/comments`
> の実測では top-level は **`3535907277`**（gemini-code-assist[bot]）、reply は
> `3535922064`（s977043）のみ。F-35（転記規律）を正本化する run 自身が出典 ID を
> 記憶からの手書きで誤記した — F-35 と同型の実例がもう 1 件増えた形であり、
> 「出典 ID も実行履歴（API 実測出力）からコピーする」ことの傍証となる。
> Round 1 本文は監査記録として不変。

### 改訂 1 — external_sources の確定値（maker・検証者はこちらを使う）

```yaml
external_sources_final:
  - "PR #764 gemini-code-assist レビューコメント id:3535907277（AC-4 here-string 欠陥指摘）— F-35 の実例出典（run-015-loopspec.md に出典つき引用で記録済み）"
```

### 改訂 2 — 摩擦記録

F-37: 「出典 ID の手書き転記による誤記」を run_frictions に記録（F-35 の適用範囲を
『AC コマンド』から『出典 ID 等の機械的参照値全般』へ広げるかは本 run のスコープ外・
次 Optimize 候補）。

### arbiter R1 裁定の記録

- decision=HUMAN_ESCALATED（exit 2・severity=low / C/D 欠落の安全側）→
  flow-detect §3.3 の severity=low 経路に従い Model C/D 再裁定へ進む（escalate の
  自己解決ではなく、decision-table が定める正規の再裁定手順）。
