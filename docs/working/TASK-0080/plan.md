---
task_id: TASK-0080
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0080 Governance Hardening S1+S2

## Goal

settings 自己改変ガード下の Shadow Configuration を構造解消する:
適用 script + `doctor --check-settings` + タスクロック + CI drift check。
TASK-0071 D-1 確定の第1スライス（S1+S2）。

## Constraints / Non-goals

- `.claude/settings*.json` を AI が編集しない（self-mod ガード恒久受容・
  適用はユーザー実行 script）
- 既存 `bin/plangate doctor` を破壊しない（非破壊拡張）
- S3（EH-3 メンテモード/SKIP_REASON）/ S4（責務4分類）は別スライス
- 既存挙動不変（適用済み環境で PASS・hook 78/0 維持）

## Approach Overview

1. settings 期待 wiring の正本を docs/ai/ に定義
2. 適用 script（ユーザー実行・冪等）
3. `bin/plangate doctor --check-settings`（適用判定・未適用非0）
4. タスクロック: doctor 未PASS で handoff/V-1 完了不可（強制層は C-3 判断）
5. CI settings drift check（required）
6. 適用済み環境での非破壊回帰

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 現状調査: bin/plangate doctor 構造 / settings.example.json 期待 wiring / CI workflow / hook テスト | 調査メモ | agent | low | - |
| S2 | 適用 script + settings 期待 wiring 正本（docs/ai/） | script + doc | agent | med | 🚩AC-1,2 |
| S3 | `bin/plangate doctor --check-settings` 実装（非破壊拡張・未適用非0） | doctor 差分 | agent | high | 🚩AC-3 |
| S4 | タスクロック機構（doctor 未PASS→handoff/V-1 完了不可）。強制層 C-3 判断 | ロック実装 | agent | crit | 🚩AC-4 / C-3 |
| S5 | CI settings drift check required 追加 | workflow yaml | agent | high | 🚩AC-5 |
| S6 | 非破壊回帰（適用済みで PASS・hook 78/0・doctor 既存12項目不変） | テスト結果 | agent | high | 🚩AC-6,7 |
| V | V-1 / V-3（critical: Codex+Gemini）/ V-4（critical） | レビュー | agent | crit | - |

## Files / Components to Touch（S1 確定）

- `bin/plangate`（doctor --check-settings サブ機能・非破壊拡張）
- `scripts/apply-claude-settings.sh`（新規・ユーザー実行適用 script）
- `docs/ai/`（settings 期待 wiring 正本）
- `.github/workflows/`（settings drift check required job）
- タスクロック: hook or workflow 定義（S1/C-3 で層を確定）
- `tests/`（doctor --check-settings / drift のテスト）
- 参照更新: docs/working/TASK-0071/（S1+S2 完了記録）

## Testing Strategy

- doctor: wiring 適用済み→PASS / 未適用→非0+対象明示（決定論）
- タスクロック: doctor 未PASS で handoff/V-1 完了がブロックされる（シナリオ）
- CI drift: wiring 未適用 PR で required job が fail することを実証
- 非破壊回帰: 既存 doctor 12 項目・hook 78/0・適用済み環境 PASS
- 冪等: 適用 script 複数回実行で安全

## Risks & Mitigations

- R1: タスクロック誤作動で正常完了阻害 → 適用済みで必ず PASS（AC-6）回帰 +
  bypass（既存 PLANGATE_BYPASS_HOOK 慣行）整合
- R2: doctor 既存破壊 → 非破壊拡張（既存12項目 diff ゼロ）を S6 で確認
- R3: settings 適用は AI 不可 → script+検証+ロックで Shadow Config を
  「適用したと誤認できない」構造に（適用自体はユーザー）
- R4: CI required 追加が他 PR を巻き込む → drift check は wiring 不在のみ
  fail（既存 PR は wiring 適用後 green）。段階導入を handoff 明記

## Questions / Unknowns

- ~~タスクロック強制層~~ → **C-3確定: doctor --check-settings 連動 + workflow DoD（05_verify_and_handoff）併用。新規Hook増やさず既存ゲート機構に乗せる**
- 適用 script の配置（scripts/ 直下 or bin 連携）→ S1 で確定

## Mode判定

**モード**: critical

**判定根拠**:
- 変更種別: ガバナンス強制機構（タスクロック）+ doctor/CI 横断
- リスク: 極高（誤作動で完了阻害 / Shadow Config 対策の中核）
- 影響範囲: 全 PBI の完了判定（handoff/V-1 ロック）
- **最終判定**: critical（V-3+V-4 必須。S4 タスクロック強制層は C-3 判断）
