# TASK-0780 (Slice B) Design Draft — plan 品質 hard gate + breakdown-gate 接続

> Issue: #780 Slice B / Status: 設計ドラフト（exec は #809・Slice D 完了後）
> 出典 gap: agentic-six-stage-loop.md Verifier 行「C-1 が loop の前提であって loop 内ステップとして義務化されていない」（#782 P1-1 同根）+ Conductor 行「着手前の分解制御が空白」

## Goal

ai-loop の C-3' 裁定前に (1) C-1 相当の plan 品質確認 と (2) breakdown-gate の粒度判定 を
**機械検査可能な必須ステップ**として接続する。

## 設計オプション比較

| 案 | 機構 | メリット | デメリット | 判定 |
|---|------|---------|-----------|------|
| A | arbiter 入力に必須フィールド `gates: {c1: "PASS", breakdown: "pass"}` を追加。欠落・非 PASS → HUMAN_ESCALATED | #809 の allowed_paths と同型で決定論・導入先のファイル配置に非依存 | 申告制（誠実申告依存。lite 4 軸と同じ限界 — 既知として自己開示） | **採用候補** |
| B | arbiter が evidence ファイル（review-self.md 等）の実在・PASS 記載を検証 | 申告より強い | arbiter が PlanGate の working-context 配置に結合し、導入先で壊れる（Phase 1 の導入先適用と衝突） | 不採用 |
| C | runbook / SKILL の手順記載のみ | 工数最小 | 規範層のみ＝#809 で是正した fail-closed 過大表明と同型のアンチパターン | 不採用 |

## 採用案 A の要点

1. **c1 ゲート**: 入力 `gates.c1` は "PASS" のみ通過。他値・欠落 → HUMAN_ESCALATED（reason=plan-quality gate）。
   SKILL Step 1 に「C-1 実施の evidence（review-self.md 等）へのパスを run 記録に残す」を運用必須化（申告の監査可能性）
2. **breakdown ゲート**: SKILL に Step 0 を新設 — breakdown-gate スキル（5 要素: 目的/変更対象/完了条件/検証方法/Rollback + 粒度判定）を C-3' 前に必ず実行。
   verdict を `gates.breakdown` に "pass"（単一タスク粒度）/ "split-suggested"（分割候補提示）で申告。"split-suggested" → HUMAN_ESCALATED（分割案を人間へ提示）
3. **POLICY_REF**: @v1 → @v2（入力契約の変更 = policy 改版・Human-owned 手続き）
4. 既存 record 21+ 件は legacy（Slice D の集計と同じ扱い）

## 依存・順序

- #809 マージ後（validate_input の構造が確定してから）。Slice D とはファイル競合最小だが record スキーマ追記が重なるため D → B の順
- breakdown-gate スキル（#802）は実在済み・変更不要（接続のみ）

## Open Questions（exec 前に確定）

- `gates.c1` を導入先（PlanGate 非使用リポジトリ）でどう充足するか → 「同等の plan self-review PASS」で可と lite-criteria 同様の申告規約にする案


---

## 設計精緻化（#816 マージ後・exec 前の深堀り）

### gates 欠落の扱い: exit 1 ではなく escalate（安全側・非破壊）

当初案「gates 必須化（欠落→exit 1）」を見直す。ai-loop の中核原則
「証明可能なときだけ auto-approve・判定不能は escalate」に照らすと、
**gates 未提供＝plan 品質が未証明** であり、正しい安全側挙動は
**HUMAN_ESCALATED**（exit 2）である（入力エラー exit 1 ではない）。

- `gates` は入力スキーマ上は**任意**フィールド（欠落で exit 1 にしない）
- priority 1.7 で判定: `gates.c1 == "PASS"` かつ `gates.breakdown == "pass"`
  でなければ（**欠落・null・異表記を含む**）HUMAN_ESCALATED
- これにより既存呼び出し（gates 無し）は **exit 1 で壊れず、escalate に落ちる**
  ＝後方互換かつ安全側（AC-8 と一貫）
- 型は与えられた場合のみ検証: c1/breakdown が str でなければ escalate 理由に含める

### priority 1.7 の挿入位置（#816 テーブル確定後）

#816 で arbitrate は priority_table（1/1.5/2/3/4/6）+ priority 5 個別 の構造。
priority 1.7 は **scope(1.5) の後・lite(2) の前**。テーブルに 1 エントリ追加:
`("plan-quality", <guard: not (c1==PASS and breakdown==pass)>, "in_scope", ...)`
guard は signals から plan-quality を評価（_evaluate_signals に plan_quality_ok を追加）。

### POLICY_REF: @v1 → @v2

gates は auto-approve の**新たな必要条件**であり gate 挙動を変える（＝policy 改版）。
Slice D の run（provenance のみ）と異なり、こちらは bump する。Human-owned 手続き
（C-3 承認 + C-4 マージ）で改版記録。

### 安全性の不変検証（レビュー必須観点）

**この変更は「以前 escalate だったものを auto-approve にする」経路を絶対に作らない**
（追加は escalate 条件のみ・auto-approve 条件は狭める方向）。差分検証で、
gates 完備（c1=PASS/breakdown=pass）の入力では #816 と同一裁定、gates 不備では
より escalate 側に倒れることのみ、を機械証明する（敵対レーンの主眼）。
