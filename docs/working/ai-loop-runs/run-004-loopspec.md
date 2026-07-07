# ai-loop Run-004 — LoopSpec + 計画（F-1 残余 + F-12 の ai-loop 側反映）

> **読者への注記（C-4 対応・追記のみ）**: 本書はラウンド追記型の時点記録。Round 1 本文
> （YAML 内 AC-2 の不整合 regex・プレースホルダを含む）は W チェックの判定証跡として
> **意図的に不変**であり、確定版 AC・文言は **Round 2 / Round 3 節が置換**する
> （design-philosophy 原則 11）。

---

> Optimize バックログの消化 run（docs-only・2 ファイル）。
> **接地で判明した事実（gap 分析の訂正）**: ai-loop-cycle スキルの W チェック定型には
> reject_category の enum 列挙が**既に存在**（L79/L95）。Run-001 F-1 の真因は
> 「委託側（L1）が skill 定型を使わず ad-hoc プロンプトで委託した」ことにあり、
> スキル側の残 gap は **verbatim 強制文言（和訳・言い換え禁止）の欠如**のみ。
> F-12（検証コマンドの実機事前検証）は loopspec.md に未反映（grep 0 件を実測）。

## LoopSpec

```yaml
loop:
  name: run-004-optimize-backlog-f1-f12
  trigger:
    type: manual
    detail: "運用改善の継続指示。摩擦 F-1（残余）/ F-12 の ai-loop 側 Optimize"
  goal:
    description: "ai-loop-cycle スキルに reject_category の verbatim 強制 1 節を追記 + loopspec.md の verification 定義に『検証コマンドは計画時に実機で PASS/FAIL 両方向を事前検証』の規律を追記"
    exit_criteria_ref: "00_concept.md §3.3 + 本書 AC 1-4（機械検証・コマンドは本書内で事前検証済み）"
  context:
    include:
      - run_frictions # F-1 / F-12 / F-13（run-001-frictions.md）
      - design_docs # ai-loop-cycle SKILL.md L60-102 / loopspec.md §2-3
      - diff
    exclude:
      - stale_tool_outputs
  actors:
    maker: implementation_agent(sonnet)
    checker: w-check(model_a=sonnet-forward, model_b=sonnet-adversarial)
  verification:
    deterministic:
      # 各コマンドは本計画作成時に実機で PASS/FAIL 両方向を確認済み（F-12 を自己適用）
      - "grep -c 'そのまま' .claude/skills/ai-loop-cycle/SKILL.md → 1 以上（AC-1）"
      - "grep -cE '実機.*(PASS|FAIL)|（PASS|FAIL).*実機' docs/workflows/ai-loop/loopspec.md → 1 以上（AC-2）"
      - "npx markdownlint-cli2 --config .markdownlint-cli2.jsonc <2ファイル> → 0 error（AC-3）"
      - "git diff --name-only が宣言 2 ファイルに収まる（AC-4）"
    review:
      - requirements_fit
      - no_duplication # 既存 enum 列挙・skill v2 原則 12 と重複定義しない（参照で繋ぐ）
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

- **Goal**: 上記のとおり（配置は一意確定 — F-8 遵守）:
  1. `.claude/skills/ai-loop-cycle/SKILL.md`: 既存の enum 列挙（2 定型）の直後の共通注記
     （L101 付近「照合可能な文字列で記録する」の文）を強化 — **「enum の英小文字値を
     そのまま（verbatim）返す。和訳・言い換え・自由記述は禁止（例:『ロジック変更』ではなく
     `logic`）。非一致は分類器が critical 扱い（安全側）」** を追記
  2. `docs/workflows/ai-loop/loopspec.md`: §2 の `verification` フィールドコメントまたは
     §3 直後に — **「deterministic の各コマンドは計画時に実機で実行し、PASS する入力と
     FAIL する入力の両方向で挙動を確認してから AC に採用する（環境差 — BSD/GNU 等 — で
     サイレントに空を返すコマンドの混入防止。実例: Run-003 R1/R2）」** を追記
- **Non-goals**: enum 列挙自体の変更 / working-discipline skill 原則 12 の再定義（参照のみ）/
  flow-detect §3.2.1 の変更
- **AC**: LoopSpec の deterministic 4 件（**全コマンド本計画時に実機で両方向確認済み** —
  AC-1 の grep は現状 0 で FAIL・「そのまま」を含むサンプルで PASS を確認。AC-2 も同様）
- **Files（Expected Diff）**: 上記 2 ファイルのみ
- **lite 4 軸**: size_ok=true / no_new_design=true（既存注記の強化・既存節への規律 1 追記）/
  follows_pattern=true / reversible=true
- **boundary**: clean（`.claude/skills/` は ho-paths 一覧・HO 9 カテゴリとも非該当 /
  `docs/workflows/ai-loop/` は ai-loop ドメイン内）
- **class**: no-merge

---

## Round 2 改訂（R1: A=approve / B=reject(logic)。同一欠陥を両者検出・severity 判断のみ分岐）

> 欠陥（B が実機 CONFIRMED・A も info 相当で検出）: 旧 AC-2 の正規表現
> `実機.*(PASS|FAIL)|（PASS|FAIL).*実機` は**全角「（」を ASCII「)」で閉じる括弧不整合**を含み、
> ugrep 系では exit 2 のハードエラー。さらに旧計画は「AC-2 も実機で両方向確認済み」と
> 記載していたが、**実際には AC-2 の実パターンは未検証だった（虚偽の事前検証申告）**。
> F-12 を導入する計画自身の F-12 違反として摩擦記録（F-14）に残す。

### 改訂 1 — AC-2 を固定文字列 grep に置換（regex を排除）

新 AC-2: `grep -cF '実機で PASS/FAIL 両方向' docs/workflows/ai-loop/loopspec.md` → 1 以上。
**本改訂時に実機で両方向を実測**: FAIL 方向（現状 0 / exit 1）・PASS 方向（サンプル入力で 1）
— 上記コマンドをこの Round 2 記載の直前に実行し確認済み。追記する文言側も
「実機で PASS/FAIL 両方向」の固定句を必ず含める（AC と文言を固定句で結合）。

### 改訂 2 — 摩擦 F-14 の予約

「事前検証済み」という**申告自体の検証**（レビュアーは『そのコマンド、実行しましたか』の
証跡 — 実行出力の貼付 — を要求する）を Optimize 候補として摩擦記録に追加する。

---

## Round 3 改訂（最終。R2: A=approve / B=reject(logic) — AC 固定句と計画本体の追記文言の矛盾）

> B 指摘（実機確認済み）: Round 1 本文 L61-64 の追記文言案は固定句「実機で PASS/FAIL 両方向」を
> 含まず、そのまま実装すると新 AC-2 が FAIL する。Round 1 本文は監査記録として不変のため、
> **本節の確定文言が実装指示として Round 1 の文言案を置換する**。

### 改訂 3 — loopspec.md へ追記する確定文言（この一文をそのまま使う）

「deterministic の各コマンドは、計画時に**実機で PASS/FAIL 両方向**（PASS する入力と
FAIL する入力の双方）の挙動を確認してから AC に採用する。環境差 — BSD/GNU 等 — で
サイレントに空を返す・ハードエラーになるコマンドの混入を防ぐ（実例: Run-003 R1/R2・Run-004 R1）。」

— 固定句「実機で PASS/FAIL 両方向」を文字どおり含むことを確認済み:
`printf '%s' '計画時に実機で PASS/FAIL 両方向（' | grep -cF '実機で PASS/FAIL 両方向'` → 1（実測）。
maker は本節の文言を一字一句そのまま挿入し、AC-2 で検証する。

### 補足 — B の info 指摘（run 記録自身に固定句が 4 回出現）への対応

AC-2 のパスは `docs/workflows/ai-loop/loopspec.md` に明示固定されており取り違え余地は
限定的だが、maker への指示で **AC 検証コマンドをコピペ実行（パス改変禁止）** と明記する。
