---
task_id: TASK-0077
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0077 F5-AD（Lite分岐 + C-3降格 / 計画のみ先行）

## Goal

規模ベース Lite/Standard 分岐（A）と C-3 条件付き降格（D）を、承認境界を
撤廃せず opt-in で実現する**設計を策定**する。実装は C-3 で承認境界変更の
是非を人間が判断した後の別 phase。

## Constraints / Non-goals

- 承認境界の撤廃はしない（強度・同期非同期の選択肢化のみ）
- opt-in 既定 OFF（明示時のみ Lite/降格）
- 本 PBI で A/D の実装はしない（計画 → C-3 で停止）
- B/C(TASK-0076)・#213/#226 実装本体は Non-goal
- TASK-0071 と責務重複させない（境界を AC-4 で明文化）

## Approach Overview

1. Lite/Standard 判定軸と自動推定+override（#213 Plan Health 連携）を設計
2. Lite ゲート構成と mode-classification との関係を整理
3. C-3 降格（同期/非同期 opt-in・reject 巻き戻し・監査）を承認境界非撤廃で設計
4. TASK-0071 との責務境界を定義
5. 承認境界後退リスクと緩和を明記、計画段階で停止（実装は C-3 後）

## Work Breakdown（計画策定タスク）

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 現状調査: mode-classification / C-3 ゲート定義 / #213 / TASK-0071 範囲 | 調査メモ | agent | low | - |
| S2 | A 設計: 判定軸・自動推定+override・Lite 構成・mode 関係 | 設計節 | agent | high | 🚩AC-1,2 |
| S3 | D 設計: 降格条件・同期非同期 opt-in・reject 巻き戻し・監査 | 設計節 | agent | crit | 🚩AC-3,5 |
| S4 | TASK-0071 との責務境界定義 | 境界表 | agent | high | 🚩AC-4 |
| S5 | #213/#226 接続点 + リスク緩和明記 + 計画停止条項 | 設計節 | agent | med | 🚩AC-6,7 |
| — | （実装は本 PBI 範囲外。C-3 で承認境界変更の是非を人間判断後に別 phase） | — | human | crit | 🚩C-3 |

## Files / Components to Touch（計画ドキュメントのみ）

- `docs/working/TASK-0077/`（本 PBI の plan/設計成果物）
- 参照のみ（変更しない）: `.claude/rules/mode-classification.md` /
  `.claude/rules/working-context.md`（C-3 ゲート）/ `docs/working/TASK-0071/`

> 注: 本 PBI は **設計策定**。上記 rules への実変更は C-3 承認後の別 PBI/phase。

## Testing Strategy

- 計画成果物の自己検証: AC-1〜7 を設計ドキュメントの構造 grep で確認
- 不変確認: 本 PBI では rules/承認境界の実ファイルを変更しない（diff 空）
- 整合: TASK-0071 境界表に重複・矛盾がない（レビュー）

## Risks & Mitigations

- R1: 計画が実装に踏み込む → S レベルで「実装は C-3 後」を不変条項化、
  Files は計画ドキュメントのみ
- R2: 承認境界後退 → opt-in 既定 OFF / reject 巻き戻し / 監査 を設計の
  不変前提として明記（AC-5）
- R3: TASK-0071 と二重定義 → AC-4 + **AC-10 Hardening Override**（TASK-0071
  抵触時 Lite/降格 無効化・Standard/同期強制）で上位優先を固定
- R4: Lite 誤適用 → **AC-8 判定不能は必ず Standard**（証明可能時のみ Lite）
- R5: 非同期降格が事後追認化 → **AC-9 reject 巻き戻し具体化**（ブランチ破棄/
  PR close/成果物 invalidation/監査記録）
- R6: 計画が実装に滲む → **AC-13 機械ガード**（diff に rules/scripts/bin
  実装変更 → C-1 FAIL）

## Questions / Unknowns

- Lite が mode-classification の直交軸か内包か（S2 / C-3）
- C-3 降格の既定値・適用条件の厳格度（S3 / C-3）
- （C-2 R-001〜006 は AC-8〜13 として確定反映済。C-3 で承認境界可変化の
  是非とともに最終判断）

## Mode判定

**モード**: critical

**判定根拠**:
- 変更種別: 承認境界（PlanGate 中核）に関わる設計 → アーキ級
- リスク: 極高（緩和を誤るとガバナンス崩壊）。計画のみでも慎重
- 影響範囲: ゲートモデル全体・TASK-0071 と交差
- **最終判定**: critical。**ただし本 PBI は計画策定で完了**（実装は C-3 で
  承認境界変更の是非を人間判断 → 別 PBI/phase）。C-2/V-3 は計画に対し実施
