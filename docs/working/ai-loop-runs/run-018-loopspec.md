# ai-loop Run-018 — LoopSpec + 計画（F-36/F-37 の正本化 Optimize run）

> Run-015〜017 で実害化した 2 摩擦を正本へ昇格する（I-5: 記録→実践→正本化）。
> F-36（conflict 解消の ours/theirs 取り違え・inverted 解決を 1 回生成、内容表示で
> 自己検出）は本日 Run-017 改番対応でも stage 表示同定として実践済み。
> F-37（実在しない出典 ID の手書き転記・Run-016 R2 で W チェック B が検出）は
> F-35（AC 転記規律）の機械的参照値全般への拡張。
> F-31/F-33（HO・権限運用）は承認境界に関わるため本 run では扱わない（スコープ制御）。

## LoopSpec

```yaml
loop:
  name: run-018-f36-f37-canonicalization
  trigger:
    { type: manual, detail: "Human 指示（2026-07-07 verbatim）: 「ai-loopで対応を進めて、運用の中で改善を進めたい」（3 回目の同文指示 = 継続委任）" }
  goal:
    description: "loopspec.md の F-35 転記規律を機械的参照値全般（出典 ID・SHA・パス等）へ拡張（F-37）+ execution-runbook §2-(7) に conflict 解消の内容同定規律を追加（F-36）"
    exit_criteria_ref: "本書 AC 1-4"
  context:
    include: [run_frictions, design_docs, diff]
    exclude: [stale_tool_outputs]
    external_sources: []
  scope:
    allowed_paths:
      - "docs/workflows/ai-loop/**"
      - "docs/working/ai-loop-runs/**"
  actors:
    maker: main_agent(fable)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial) + rubric_grader(sonnet, Step 5.5)
  verification:
    deterministic:
      - cmd: "grep -qF '機械的参照値' docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-1 F-37 拡張（FAIL 方向 exit1 / PASS 方向サンプル exit0 実測済み）
      - cmd: "grep -qF '内容の冒頭を実際に表示して同定' docs/workflows/ai-loop/execution-runbook.md"
        expect_exit: 0
        note: AC-2 F-36 同定規律（FAIL 方向 exit1 / PASS 方向サンプル exit0 実測済み）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/workflows/ai-loop/execution-runbook.md docs/workflows/ai-loop/loopspec.md"
        expect_exit: 0
        note: AC-3
      - cmd: "test \"$(git diff origin/main --name-only -- docs/workflows/ | sort | tr '\n' ',')\" = 'docs/workflows/ai-loop/execution-runbook.md,docs/workflows/ai-loop/loopspec.md,'"
        expect_exit: 0
        note: AC-4 対象 2 ファイルのみ（マージ前ブランチ上で実行。cmd は Run-016 実行履歴からのコピー — F-35 準拠）
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

1. **loopspec.md** — F-35 段落（「AC の転記は実行履歴からのコピーとする」）の直後に 1 文:
   「同規律は AC コマンドに限らず、**出典 ID・commit SHA・ファイルパス・issue/PR 番号
   等の機械的参照値全般**に適用する — 記憶からの手書き転記を禁じ、実測出力
   （API 応答・コマンド出力）からコピーする（実例: Run-016 R2 — 実在しない
   レビューコメント ID の手書き転記を W チェック Model B が検出。F-37）。」
2. **execution-runbook.md §2-(7) 実行手順**の末尾に 1 項:
   「conflict 解消時の同定規律: rebase/merge の conflict 解消では、stage 番号
   （`:2:`/`:3:`）や ours/theirs のラベル理解に依存せず、**各側の内容の冒頭を実際に
   表示して同定してから**採用する。解消後は「維持すべき側のファイルが基準
   （origin/main 等）と差分ゼロであること」を機械検証する（実例: Run-015 —
   ラベル依存の解決が inverted となり、内容表示による検証で自己検出・是正。F-36）。」

- **lite**: size_ok=true（2 ファイル）/ no_new_design=true（実践済み規律の明文化のみ）/
  follows_pattern=true（Run-012/016 の正本化 run のミラー）/ reversible=true（revert 一発）
- **boundary**: clean（docs/workflows/ai-loop のみ・HO 9 カテゴリ非該当）
- **class**: no-merge

---

## Round 2 改訂（R1: A=approve / B=reject(documentation) — 検証不能な実例主張）

> B 指摘（採用）: 前文の「F-36 は本日 Run-017 改番対応でも stage 表示同定として
> 実践済み」は、main 上の run-017-loopspec.md に当該実践の記述がなく、監査記録から
> 検証できない主張だった（実践はセッション内で行われたが記録に残っていない —
> 記録なき実践主張は F-37 型の「記憶からの手書き裏付け」に該当）。Round 1 本文は
> 監査記録として不変。

### 改訂 1 — 前文の実例主張の確定形（maker・検証者はこちらを使う）

F-36 の裏付けとして引用してよいのは **run-015-loopspec.md の F-36 記載
（inverted 解決の自己検出・是正）のみ**。Run-017 改番時の stage 表示同定は
run 記録に残っていないため実例として引用しない（本改訂により削除扱い）。

### 改訂 2 — 摩擦記録

F-38: 「run 記録に残っていない実践をセッション記憶から実例として主張した」を
run_frictions に記録（F-37 の適用範囲『機械的参照値』に対し、こちらは『実践事実の
主張』— 出典は run 記録・PR・実測出力のいずれかに検証可能でなければならない）。

### arbiter R1 裁定の記録

R1: A=approve / B=reject(documentation) → severity=low・C/D 欠落 →
HUMAN_ESCALATED（安全側）→ flow-detect §3.3 の C/D 再裁定へ（Run-016 と同経路）。

## exec 記録（AC-2 一時 FAIL と是正）

- exec 初回の AC 実行で AC-2 が exit 1 — 挿入文の**行折り返しがアンカー句を跨いだ**
  （事前検証の PASS サンプルは改行なしの 1 行で、実挿入時の wrap 位置を再現して
  いなかった。F-29 の亜種）。折り返し位置を調整して句を 1 行に収め、AC 1-4 全 PASS。
- **F-39（摩擦）**: 「grep -F 型 AC の PASS 方向事前検証は、実際の挿入フォーマット
  （行折り返し・インデント含む）で行う」を Optimize 候補として記録。

## Round 3 追記（PR #767 gemini 指摘の反映）

- **指摘（medium x2・採用）**: F-36 追記文の「基準（origin/main 等）と差分ゼロ」は、
  ours 側を維持するケースでは比較基準がマージ/リベース前の自コミットになるため
  誤解を招く。runbook の確定文言を「**その本来の比較基準**（main 側維持なら
  origin/main、自ブランチ側維持ならマージ/リベース前の自コミット）」へ修正した。
- 本書「計画（確定追記文言）」節（Round 1）は監査記録として遡及編集しない —
  最終文言は runbook 本体（本 PR の差分）が正本。gemini 第 2 指摘（計画節の同期
  更新提案）は、この監査不変原則により**追記方式で対応**（F-30 と同じ構造）。
