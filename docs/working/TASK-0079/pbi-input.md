---
task_id: TASK-0079
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0079

> F5-AD 実装: Lite/Standard ゲート分岐 + C-3 条件付き降格
> 起源: #251（実装 issue）/ 設計正本 TASK-0077（#250 マージ済・C-3 APPROVED）
> 設計時のユーザー方針「計画のみ先行・実装は別 PBI」の **実装 PBI**

## Context / Why

#234-A/D（小規模 PBI への過大ゲート / C-3 人間ボトルネック）の設計を
TASK-0077 で策定・C-3 APPROVED 取得済（承認境界を opt-in で可変化する設計を
是と人間判断）。本 PBI はその実装。承認境界は撤廃せず、ゲート強度の選択
（Lite/Standard）と C-3 の同期/非同期を opt-in 可能にする。

## What — Scope

### In scope

- **mode-classification.md に `lite_eligible` を内包**（mode の下位派生属性。
  直交軸にしない＝二重分類回避。AC-11）
- Lite 判定軸（変更ファイル数 / 新規設計の有無 / 既存パターン踏襲）と
  自動推定 + **人間 override** を定義
- **AC-8**: 判定不能/根拠不足/Plan Health 未算出/新規設計曖昧 → 必ず
  Standard・同期 C-3（Lite は証明可能時のみ＝例外扱い）
- **AC-11**: `critical` は原則 Lite 不可・例外は人間 C-3 明示承認
- **AC-12**: Lite の「外部レビュー 1 本」は critical/major=0 を要求・観点固定
- working-context.md に **C-3 条件付き降格**を実装:
  - 降格条件: `C-1 PASS かつ C-2 critical/major=0 かつ lite_eligible`
  - 同期（既定・従来）/ 非同期（exec 並行・reject で巻き戻し）の opt-in 選択
  - opt-in 既定 OFF（明示時のみ降格）
  - **AC-9**: reject 巻き戻し具体化（実装ブランチ破棄 / PR close / 成果物
    invalidation / 監査ログ記録 / 派生成果物の扱い）
  - **AC-10 Hardening Override**: Shadow Config / 承認境界 / 責務4分類 /
    Critical Infra 指定（TASK-0071 領域）に抵触する場合は Lite/降格を
    無効化し Standard/同期を強制（上位優先ルール）
- 監査: 降格適用・reject・override 発火を decision-log/監査に記録

### Out of scope

- #213 Plan Health Score の実装本体（連携点の定義のみ。未実装時は AC-8 に
  従い Standard へ倒す）
- TASK-0071 本体実装（#244・Hardening Override は概念参照。TASK-0071
  マージ時に機械判定へ接続）
- B/C（#249 マージ済）/ #226 実装本体
- AC-13 は TASK-0077（計画のみ）の歯止め＝本実装 PBI には非適用（本 PBI が
  サンクション済み実装）

## Acceptance Criteria

- [ ] AC-1: mode-classification に `lite_eligible` 内包定義（判定軸+自動推定+人間override）
- [ ] AC-2: Lite ゲート構成（C-1 + 外部レビュー1本 + C-3）が mode-classification に定義され Standard との差分が明確
- [ ] AC-3: working-context に C-3 条件付き降格（同期/非同期 opt-in・既定OFF・降格条件）が承認境界を撤廃しない形で定義
- [ ] AC-4: AC-8（判定不能等は必ず Standard・同期）が不変条件として実装される
- [ ] AC-5: AC-9（reject 巻き戻し対象の具体化）が手順として定義される
- [ ] AC-6: AC-10 Hardening Override（TASK-0071 領域抵触時 Lite/降格無効化）が上位優先ルールとして定義
- [ ] AC-7: AC-11（critical 原則 Lite 不可・例外は人間 C-3 明示承認）/ AC-12（外部1本は critical/major=0 要求）が実装
- [ ] AC-8: 既定 OFF で既存ゲート挙動が不変（opt-in 未指定時 full ゲート）。hook テスト回帰なし
- [ ] AC-9: 降格/override/reject の監査記録方式が定義される

## Notes from Refinement

- 設計正本: docs/working/TASK-0077/（plan / review-external R-001〜006 / handoff）
- TASK-0077 C-2 で確定した AC-8〜13 を実装要件として継承
- 承認境界は不変（強度/同期非同期の選択肢化のみ）。opt-in 既定 OFF 厳守
- mode-classification.md は正本（[`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)）

## Estimation Evidence

**Risks**: 承認境界（PlanGate 中核）の実装。緩和誤りでガバナンス崩壊 →
opt-in 既定 OFF・reject 巻き戻し・監査・Hardening Override を不変条件化。
既存挙動不変（opt-in 未指定で従来 full）を回帰で保証
**Unknowns**: #213 Plan Health 未実装時の自動推定代替（AC-8 で Standard に
倒すため安全側で確定）
**Assumptions**: rules/working-context のドキュメント実装（mode 判定は
doc-enforced + 人間 override、将来 Hook 強制）。Mode 想定: critical
