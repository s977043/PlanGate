---
task_id: TASK-0071
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0071

> Governance Hardening: AI 不可侵領域（settings / merge）の正式ワークフロー化
> 起源: TASK-0070 方針レビュー（Codex 提案 × Gemini 検証 / direction-codex-gemini.md）

## Context / Why

TASK-0070 (P4(d)) で AI 開発の構造的摩擦が顕在化:
1. `.claude/settings*.json` は Claude self-mod ガードで AI 編集不可 → AC-8 が
   ユーザー手動依存。AI が「適用済み」と誤認する Shadow Configuration リスク。
2. EH-3 が TASK 文脈なしで Edit をブロックし heredoc 回避が常態化（UX 欠陥）。
3. merge は sockpuppet 禁止で AI 自律不可。待ち状態が不可視でボトルネック化。

Codex 提案を Gemini が監査検証し、合意 4 点 + Gemini 格上げ 5 点を統合。
本 PBI はその確定方針（最優先 3 アクション）を実装スコープとして起票する。

## What — Scope

### In scope

- **S1: AC-8 Manual Gate 化 + Shadow Config ロック**
  - settings パッチ正本を `docs/ai/` or `templates/` に配置
  - 適用 script + `bin/plangate doctor --check-settings`（適用状態検証）
  - doctor 検証 PASS まで該当 TASK の handoff/V-1 を完了扱いにしない（タスクロック）
- **S2: settings drift check を CI required 追加**
  - `${PLANGATE_HOOK_FILE:-}` wiring 未適用 + model-profile.schema 不整合を機械検出
  - warning ではなく required check failure
- **S3: EH-3 バイパス不要化 + SKIP_REASON 例外申請プロトコル**
  - 有効期限付きメンテモード or ハッシュ除外タグで heredoc を不要に
  - SKIP 選択時 `SKIP_REASON` を commit message / todo.md に強制記述
  - 人間が C-3/C-4 で明示追認
- **S4: 責務 4 分類の正式文書化**（AI / Human / CI / Workflow-owned）

### Out of scope

- merge 自動化（sockpuppet 禁止は非交渉・恒久制約）
- 既存 PR #242 / #243 のマージ操作（人手 C-4）
- EH-3 以外の Hook への横展開（別 PBI 候補）

## Acceptance Criteria

- [ ] AC-1: settings 変更が必要な TASK で AI がパッチ + 検証テストをセット出力する
- [ ] AC-2: `bin/plangate doctor --check-settings` が wiring 適用状態を判定し、未適用なら非0で fail
- [ ] AC-3: settings 未適用のまま handoff/V-1 を完了にできない（タスクロックが機能）
- [ ] AC-4: CI に settings drift check が required で追加され、wiring/schema 不整合で fail する
- [ ] AC-5: EH-3 が heredoc 不要のメンテモード or 除外タグを提供し、回避なしで作業継続できる
- [ ] AC-6: SKIP 発生時 SKIP_REASON が機械可読で残り、人間追認の証跡が C-3/C-4 に残る
- [ ] AC-7: 責務 4 分類が正本ドキュメント（rules or docs/ai）に明文化される
- [ ] AC-8: 既存テスト（hook 60件）に回帰がない

## Notes from Refinement

- Codex/Gemini 不一致点: 「SKIP 理由監査のみ」(Codex) vs「例外申請プロトコル必須」
  (Gemini) → Gemini 採用（監査は必要条件だが十分条件でない）
- Gemini critical: Shadow Configuration（AI の適用済み誤認）対策を最優先に
- jq なし fallback は優先度低（python -m json.tool 等で代替十分・可読性優先）
- 詳細根拠: docs/working/TASK-0070/direction-codex-gemini.md

## Estimation Evidence

**Risks**: ワークフロー定義・Hook・CI・doctor 横断 → アーキ変更級。最低「高」、
S3 のメンテモード設計次第で「超高」（強制力の意味的変更を含むため V-3/V-4 必須）
**Unknowns**: メンテモードの有効期限・除外タグの粒度（plan で要設計判断）
**Assumptions**: sockpuppet 禁止・self-mod ガードは恒久制約として受容（回避しない）
