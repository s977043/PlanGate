# ai-loop Run-013 — LoopSpec + 計画（#754 improvement-seeds hygiene 仕様正本化）

> intake loop（design-philosophy §6.1）経由の 3 例目（#746/#751 と同経路）。
> **escalate 2 事由を計画時点で宣言**（W チェック前・escalate 第2型）:
> (1) **touches_ho**: 対象が `docs/ai/*.md` トップレベル（ho-paths.md L35 で HO-contract
> 指定・Arbiter PoC が既存仕様を書き換えないための境界）に接触する
> (2) **配置の設計選択**: issue #754 自体が「retro-phase.md への追記 or 新規
> seeds-hygiene.md」を未確定のまま残している（no_new_design=false 相当）

## LoopSpec（Human 判断待ち・escalation 先行）

```yaml
loop:
  name: run-013-seeds-hygiene-754
  trigger: {type: manual, detail: "ai-loop 運用継続指示 + issue #754（intake §6.1 経路）"}
  goal:
    description: "#754 AC 1-5: seeds-hygiene 仕様（入力/処理/出力/還流/責務分類）の正本化 + append-only 不変の検証手順 + digest サンプル 1 件"
    exit_criteria_ref: "00_concept.md §3.3 + #754 受入基準 5 項目"
  context:
    include: [design_docs, run_frictions, diff]
    external_sources:
      - "issue #754 本文（Anthropic Managed Agents ギャップ分析の結論・転記時は出典明示）"
    exclude: [stale_tool_outputs]
  scope:
    allowed_paths:  # Human 選択により確定（下記 escalation 選択肢参照）
      - "docs/ai/seeds-hygiene.md または docs/ai/retro-phase.md（HO 接触・Human 承認必須）"
      - "docs/working/improvement-digest.md（digest サンプル・新規）"
      - "docs/working/ai-loop-runs/**"
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      # Human 選択確定後に consolidated ブロックで最終化（F-30 遵守）。候補（両方向未実測・確定時に実測する）:
      - cmd: "git diff origin/main -- docs/working/improvement-seeds.md | grep -c '^-[^-]'"
        expect_exit: 1
        note: AC-2 append-only 維持（削除行ゼロ・F-28 厳密形。count=0 で grep は exit1）
      - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc <確定対象ファイル>"
        expect_exit: 0
        note: AC 系（配置確定後に固定）
    review: [requirements_fit, no_duplication]
  stopping_rule:
    terminal_state_ref: "decision-table.md"
    round_limit_ref: "execution-runbook.md §2-(7) Scheduling 判断表（上限3）"
  memory:
    write: [decision_record, run_frictions]
    ref: "execution-runbook.md §2-(4)"
  escalation:
    touches_ho: unconditional  # → 本 run は W チェック前に HUMAN_ESCALATED（宣言どおり発火）
    budget_ref: "arbiter-policy.md §7"
```

## escalation 提示（Human 選択待ち）

- **接地事実**: improvement-seeds.md 実在（23 行・エントリ 1 件相当 → AC-5 のサンプル生成可能）/
  retro-phase.md は §1-6 構成（§2 が seeds スキーマ正本）/ ho-paths.md L35 が docs/ai/*.md
  トップレベルを HO-contract 指定
- **選択肢**（採否は Human）:
  1. （AI 推奨）新規 `docs/ai/seeds-hygiene.md` を正本化 + `retro-phase.md` §6 関連に参照 1 行追記
     （HO 接触 = 新規 1 + 既存 1 行。retro-phase の既存仕様を書き換えないため境界趣旨に最も整合）
  2. `retro-phase.md` へ節追記のみ（HO 接触 = 既存 1 ファイルの実質改変。ファイル数は最少）
  3. ai-loop を使わず PlanGate 通常フロー（standard PBI・同期 C-3）へ切替え
  4. run 中止

---

## Round 2 — Human 選択の記録 + 最終確定 AC（機械可読 consolidated ブロック / F-30 遵守）

> **Human 判断（2026-07-07・verbatim「１」）**: escalation 選択肢 1 を採択 —
> 新規 `docs/ai/seeds-hygiene.md` を正本化 + `retro-phase.md` へ参照リンク 1 行のみ追記。
> これにより HO 接触の承認範囲は「seeds-hygiene.md 新規作成 + retro-phase.md への
> 参照 1 行」に**限定**される（既存仕様の実質改変は承認範囲外・maker は逸脱禁止）。
> 配置の設計選択も解消し no_new_design=true に転じる。

### 確定 allowed_paths

- `docs/ai/seeds-hygiene.md`（新規・HO 接触承認済み）
- `docs/ai/retro-phase.md`（参照リンク 1 行のみ・HO 接触承認済み）
- `docs/working/improvement-digest.md`（digest サンプル・新規）
- `docs/working/ai-loop-runs/**`（run 記録）

### 最終確定 AC（maker・検証者は本ブロックのみ実行。各コマンド両方向事前検証済み）

```yaml
verification_final:
  deterministic:
    - cmd: "test -f docs/ai/seeds-hygiene.md && for w in 入力 処理 出力 還流 責務分類; do grep -qF \"$w\" docs/ai/seeds-hygiene.md || exit 1; done"
      expect_exit: 0
      note: AC-1 仕様 5 要素（#754 AC-1。FAIL 方向 = ファイル不在 exit1 実測 / PASS 方向 = 5 語サンプル実測）
    - cmd: "git diff origin/main -- docs/working/improvement-seeds.md | grep -c '^-[^-]'"
      expect_exit: 1
      note: AC-2 seeds append-only（#754 AC-2・F-28 厳密形。削除行 1 のサンプルで exit0=違反検出可を実測）
    - cmd: "grep -qF 'seeds-hygiene' docs/ai/retro-phase.md"
      expect_exit: 0
      note: AC-3 整合リンク（#754 AC-4。現状 0/exit1 実測）
    - cmd: "test -f docs/working/improvement-digest.md && grep -qF 'improvement-seeds.md' docs/working/improvement-digest.md"
      expect_exit: 0
      note: AC-4 digest サンプル + 出典明示（#754 AC-5。現状不在 exit1 実測）
    - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/ai/seeds-hygiene.md docs/ai/retro-phase.md docs/working/improvement-digest.md"
      expect_exit: 0
      note: AC-5 lint
    - cmd: "test \"$(git diff --name-only origin/main -- docs/ai/ | wc -l | tr -d ' ')\" -le 2"
      expect_exit: 0
      note: AC-6 HO 接触が承認範囲（docs/ai 配下 2 ファイル）を超えない
  review: [requirements_fit, no_duplication, ho_scope_containment]
```

（#754 AC-3「digest 採用フロー = Human-owned（PR レビュー経由）」は仕様本文の記載事項として
AC-1 の「責務分類」要素に包含・W チェック review 観点で確認する）

---

## Round 3 改訂（W チェック R1: A=approve / B=reject(ho_path_contact) — containment AC の強化）

> B 指摘 2 点を全採用（Round 2 の consolidated ブロックは監査記録として不変・
> **本節の consolidated ブロックが置換する**）:
> (1) AC-6 はファイル数のみで「retro-phase.md 参照 1 行のみ」の Human 承認範囲を
> 行数レベルで担保できない（節まるごと追記でも PASS した）
> (2) AC-2 は削除行のみ検出で、scope 外 seeds への**追記**を検知できない

### 最終確定 AC v2（機械可読 consolidated ブロック / 全コマンド両方向を実変更→復元で実測済み）

```yaml
verification_final_v2:
  deterministic:
    - cmd: "test -f docs/ai/seeds-hygiene.md && for w in 入力 処理 出力 還流 責務分類; do grep -qF \"$w\" docs/ai/seeds-hygiene.md || exit 1; done"
      expect_exit: 0
      note: AC-1 仕様 5 要素（Round 2 から不変）
    - cmd: "git diff --quiet origin/main -- docs/working/improvement-seeds.md"
      expect_exit: 0
      note: AC-2v2 seeds 完全無変更（追記・削除とも検知。追記 1 行で exit1 / 復元後 exit0 を実測）
    - cmd: "grep -qF 'seeds-hygiene' docs/ai/retro-phase.md"
      expect_exit: 0
      note: AC-3（Round 2 から不変）
    - cmd: "test -f docs/working/improvement-digest.md && grep -qF 'improvement-seeds.md' docs/working/improvement-digest.md"
      expect_exit: 0
      note: AC-4（Round 2 から不変）
    - cmd: "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc docs/ai/seeds-hygiene.md docs/ai/retro-phase.md docs/working/improvement-digest.md"
      expect_exit: 0
      note: AC-5（Round 2 から不変）
    - cmd: "test \"$(git diff --name-only origin/main -- docs/ai/ | wc -l | tr -d ' ')\" -le 2"
      expect_exit: 0
      note: AC-6a HO 接触ファイル数 ≤2（Round 2 から不変）
    - cmd: "a=$(git diff --numstat origin/main -- docs/ai/retro-phase.md | awk '{s+=$1} END{print s+0}'); d=$(git diff --numstat origin/main -- docs/ai/retro-phase.md | awk '{s+=$2} END{print s+0}'); test \"$a\" -le 1 && test \"$d\" -eq 0"
      expect_exit: 0
      note: AC-6b retro-phase.md は追加 ≤1 行・削除 0 行（Human 承認「参照 1 行のみ」の数量担保。2 行追記で exit1 を実測）
  review: [requirements_fit, no_duplication, ho_scope_containment]
```

---

## escalation 解消記録（exec 開始承認）

- W チェック R2: A=approve / B=approve（B は /tmp ミニ git repo で AC-2v2/AC-6b の
  3 パターン exit 遷移を独立再現）
- arbiter 刻印: `20260707T102937Z-94c9882-run013-r2.json` — **priority 1
  （boundary=touches-HO・絶対条件）で HUMAN_ESCALATED / exit 2**。W 合意でも HO 接触は
  機械的に Human へ返る（I-1 の実機動作確認・HO 接触 run の初事例）
- **Human 承認**: escalation 提示（選択肢 1-4）に対し verbatim「１」（2026-07-07）。
  承認範囲 = 新規 docs/ai/seeds-hygiene.md + retro-phase.md 参照 1 行 + digest サンプル。
  AC-6a/6b が範囲逸脱を機械検出する
- 以上により exec 開始（maker=sonnet・検証は verification_final_v2 のみ）
