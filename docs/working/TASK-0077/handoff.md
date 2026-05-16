---
task_id: TASK-0077
artifact_type: handoff
schema_version: 1
status: done
---

# HANDOFF — TASK-0077 (F5-AD Lite分岐+C-3降格 / 計画のみ先行)

## 1. 要件適合確認結果（計画成果物 AC）

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 Lite判定軸+自動推定+override | PASS | plan S2 設計節 |
| AC-2 Lite構成+mode関係 | PASS | mode 内包(`lite_eligible`)方針（C-2 R-004） |
| AC-3 C-3降格 同期/非同期 opt-in（承認境界非撤廃） | PASS | plan S3 |
| AC-4 TASK-0071 責務境界 | PASS | + AC-10 Hardening Override |
| AC-5 承認境界後退リスク+緩和 | PASS | opt-in既定OFF/reject巻戻し/監査 |
| AC-6 #213/#226 接続点 | PASS | plan |
| AC-7 実装はC-3後別phase・計画停止 | PASS | plan 不変条項 + AC-13 機械ガード |
| AC-8〜13 C-2 反映（R-001〜006） | PASS | review-external.md / pbi-input |

## 2. 既知課題一覧

- 本 PBI は **計画完了でクローズ**。実装（rules/mode-classification/C-3 ゲート
  への実変更）は **C-3 APPROVE を受けた別 PBI** で起票する（本 PBI では
  rules/scripts/bin を変更しない＝AC-13 歯止め遵守）。
- 実装 PBI は AC-8〜13（判定不能→Standard / reject巻戻し具体 / Hardening
  Override / Lite=mode内包 / 外部1本品質 / 機械ガード）を要件として継承する。

## 3. V2 候補（= 実装 PBI スコープ）

- Lite/Standard 自動推定の #213 Plan Health 連携実装
- C-3 同期/非同期降格の opt-in 実装 + reject 巻き戻し機構
- TASK-0071 Hardening Override の機械判定

## 4. 妥協点

- 「計画のみ先行」（ユーザー方針）。承認境界＝PlanGate 中核のため実装前に
  C-3 で是非判断 → APPROVE 取得済。実装は分離（安全側）
- C-2 major は計画段階で AC 化（実装を待たず要件確定）

## 5. 引き継ぎ文書（5分サマリ）

#234-A/D（小規模PBIへの過大ゲート / C-3人間ボトルネック）に対し、承認境界
を撤廃せず opt-in で「ゲート強度の選択」「C-3 同期/非同期」を可能にする設計を
策定。C-2（Codex/Gemini）で安全側フォールバック・reject巻戻し・TASK-0071
Hardening Override を AC-8〜13 として確定。C-3 APPROVE 取得。**実装は別 PBI**。

## 6. テスト結果サマリ

- 計画成果物 AC-1〜13: 構造検証 PASS
- 本 PBI は rules/scripts/bin 無変更（diff = docs/working/TASK-0077 のみ）
- C-2: Codex critical0/major3 + Gemini critical0/major1 → 全 AC 反映
