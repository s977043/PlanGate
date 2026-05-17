---
task_id: TASK-0082
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0082 EH-3 メンテモード+SKIP_REASON（S3）

## Goal

EH-3 に承認ファイル方式メンテモード + SKIP_REASON 例外申請を実装。
plan.md 常時 BLOCK・BYPASS>メンテ>通常・最大30分・承認ファイルのみ・
fail-closed・監査・CI required（未追認 SKIP）。TASK-0071 最終スライス。

## Constraints / Non-goals

- plan.md は メンテ中でも必ず BLOCK（E1 不変）
- 優先順 BYPASS > メンテ > 通常（E2 不変）
- env でメンテ有効化しない（承認ファイルのみ＝AI 自己付与不可）
- P4(d)/正規化/jq抽出ロジックは改変せずメンテ分岐を追加するのみ
- 案B不採用 / S1+S2(#254)・S4(#256) は完了済

## Approach Overview

1. maintenance.json schema 定義（task_id/scope/until/reason/approved_by）
2. check-plan-hash.sh: BYPASS 後・plan.md BLOCK 判定の**後**にメンテ分岐
   （plan.md は先に BLOCK 済＝メンテで覆らない）。until 検証 fail-closed
3. SKIP 場面で SKIP_REASON 必須化（空→停止・decision-log append）
4. CI: SKIP_REASON 未追認検出 required check
5. 監査 machine-readable + 回帰（不在時従来動作・hook 78/0）

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | 現状調査: check-plan-hash.sh 分岐順 / decision-log / CI / schemas | 調査 | agent | low | - |
| S2 | maintenance.json schema（schemas/）+ 妥当性検証関数 | schema | agent | med | 🚩AC-1,4 |
| S3 | check-plan-hash.sh メンテ分岐追加（plan.md BLOCK 後・優先順厳守・fail-closed・監査）| hook 差分 | agent | crit | 🚩AC-1,2,3,4,5,8 |
| S4 | SKIP_REASON 必須化（空→停止・decision-log append・追認マーク形式確定）| hook+spec | agent | crit | 🚩AC-6 / C-3 |
| S5 | CI: SKIP_REASON 未追認 required check | workflow+script | agent | high | 🚩AC-7 |
| S6 | 回帰: 既存 hook 78/0・不在時従来動作・P4d 不変 | テスト | agent | high | 🚩AC-9 |
| V | V-1 / V-3（critical Codex+Gemini）/ V-4（critical）| レビュー | agent | crit | - |

## Files / Components to Touch（S1 確定）

- `scripts/hooks/check-plan-hash.sh`（メンテ分岐+SKIP_REASON。P4d非改変）
- `schemas/`（maintenance.json schema）
- `scripts/`（SKIP_REASON 未追認検出 script・メンテ検証ヘルパ）
- `.github/workflows/`（SKIP_REASON required check）
- `tests/hooks/run-tests.sh`（メンテ/SKIP_REASON/回帰 TC）
- docs: s3a-design-note 実装反映・TASK-0071 INDEX 更新

## Testing Strategy

- メンテ: 有効ファイル→非plan SKIP / plan.md→必ず BLOCK / until切れ→無効 /
  不正JSON→fail-closed / env単独→無効
- 優先順: BYPASS>メンテ>通常 をマトリクスで
- SKIP_REASON: 空→停止 / 設定→decision-log append / 未追認→CI fail
- 回帰: maintenance.json 不在で従来 P4(d) 挙動不変・hook 78/0
- 監査: 突入/失効/SKIP イベントが _audit に出る

## Risks & Mitigations

- R1: メンテが新バイパス → 承認ファイルのみ・plan.md常時BLOCK・最大30分・
  fail-closed・監査・優先順固定（V-3+V-4 で攻撃面再評価）
- R2: P4(d) 破壊 → メンテ分岐は plan.md BLOCK 判定の後に純追加・既存改変なし
- R3: SKIP_REASON が形骸化 → CI required（未追認 fail）で人間追認を強制
- R4: 承認ファイル AI 自己付与 → responsibility-classes で Human-owned。
  hook は「ファイルがあれば検証」のみ（生成は人間。CI で異常付与を監視）

## Questions / Unknowns

- ~~SKIP_REASON 追認マーク形式~~ → **C-3確定: decision-log.jsonl の reason エントリに acknowledged_by/acknowledged_at を人間追記。CI が未追記を検出**
- 承認ファイル配置（approvals/maintenance.json で確定）

## Mode判定

**モード**: critical

**判定根拠**:
- 変更種別: 強制 Hook（EH-3）の挙動拡張 + CI required + schema
- リスク: 極高（メンテが新バイパス経路化し得る／plan.md 保護の中核）
- 影響範囲: EH-3 を通る全 Edit/Write
- **最終判定**: critical（V-3+V-4 必須・C-3 3点確定済）
