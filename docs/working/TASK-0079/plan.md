---
task_id: TASK-0079
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0079 F5-AD 実装（Lite分岐+C-3降格）

## Goal

TASK-0077 で C-3 APPROVED の設計（Lite/Standard 分岐 + C-3 条件付き降格）を
mode-classification.md / working-context.md に実装する。承認境界は撤廃せず
opt-in 既定 OFF。AC-8〜12（TASK-0077 C-2 確定）を遵守。

## Constraints / Non-goals

- 承認境界撤廃しない（強度・同期非同期の選択肢化のみ）。opt-in 既定 OFF
- 既存ゲート挙動を不変に保つ（opt-in 未指定＝従来 full）
- #213 Plan Health 本体・TASK-0071 本体・#226 は Non-goal（連携点/概念参照のみ）
- mode-classification の既存 5 mode 定義は壊さない（lite_eligible は内包派生）

## Approach Overview

1. mode-classification.md: `lite_eligible` 内包派生属性（判定軸+自動推定+
   人間override+AC-8安全側+AC-11 critical不可+AC-12外部1本品質）
2. working-context.md: C-3 条件付き降格（同期/非同期 opt-in・既定OFF・
   降格条件・AC-9 reject巻戻し・AC-10 Hardening Override・監査）
3. 既定 OFF の挙動不変を回帰確認（hook テスト + 既存ゲート記述の非破壊）

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 現状調査: mode-classification 構造 / working-context C-3 ゲート節 / TASK-0077 設計詳細 | 調査メモ | agent | low | - |
| S2 | mode-classification に lite_eligible 内包実装（判定軸/override/AC-8/11/12）| rules 差分 | agent | crit | 🚩AC-1,2,4,7 |
| S3 | working-context に C-3 条件付き降格実装（opt-in/既定OFF/降格条件/監査）| rules 差分 | agent | crit | 🚩AC-3,9 |
| S4 | AC-9 reject 巻き戻し手順 + AC-10 Hardening Override（上位優先）| rules 差分 | agent | crit | 🚩AC-5,6 |
| S5 | 既定OFF 挙動不変 回帰（hook 78/0・既存5mode/C-3 非破壊）| テスト結果 | agent | high | 🚩AC-8 |
| V | V-1 / V-3（critical: Codex+Gemini）/ V-4（critical） | レビュー | agent | crit | - |

## Files / Components to Touch

- `.claude/rules/mode-classification.md`（lite_eligible 内包）
- `.claude/rules/working-context.md`（C-3 条件付き降格 / Hardening Override / 監査）
- 参照のみ: docs/working/TASK-0077/（設計正本）, #213/#226/TASK-0071（連携点）

## Testing Strategy

- 構造検証: lite_eligible 判定軸/AC-8/11/12、C-3降格 opt-in/既定OFF/降格条件/
  AC-9/AC-10 が grep で存在
- 挙動不変: opt-in 未指定で従来 full ゲート（既存5mode・C-3三値の記述非破壊を diff 確認）
- 安全側: 判定不能→Standard・同期（AC-8）、critical→原則Lite不可（AC-11）
- 回帰: hook テスト 78 passed/0 failed
- Hardening Override: TASK-0071 領域抵触時 Lite/降格無効の記述存在

## Risks & Mitigations

- R1: 承認境界後退 → opt-in 既定 OFF / AC-8 安全側 / AC-10 Override / reject
  巻き戻し / 監査 を不変条件として実装し V-3+V-4 で検証
- R2: 既存ゲート破壊 → lite_eligible は内包派生・既存 5 mode と C-3 三値の
  本文は非破壊（diff で確認）
- R3: #213 未実装で自動推定不可 → AC-8 で Standard に倒す（安全側確定）
- R4: TASK-0071 未マージで Override 機械判定不可 → 概念ルールとして実装し
  TASK-0071 マージ時に機械接続（handoff 明記）

## Questions / Unknowns

- なし（設計は TASK-0077 C-3 APPROVED で確定。AC-8〜12 を実装に落とすのみ）

## Mode判定

**モード**: critical

**判定根拠**:
- 変更種別: 承認境界（PlanGate 中核）の実装 + ワークフロー強度モデル変更
- リスク: 極高（緩和誤りでガバナンス崩壊）
- 影響範囲: 全 PBI のゲート強度・C-3 同期性
- **最終判定**: critical（C-2 設計は TASK-0077 で実施済 / 本実装に V-3+V-4 必須）
