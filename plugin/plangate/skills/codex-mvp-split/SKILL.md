---
name: codex-mvp-split
description: "規模 L 以上の機能の最小 MVP (Phase 1) を Codex に選定相談し Phase 分割表を作る。Use when: A フェーズ前段で規模 L 機能の MVP を決めたい時 / 事前メトリクス検証で実数 ≥ 3 倍判定時。"
---

# Codex MVP Split (PlanGate / Codex 共用)

規模 L 以上の機能を着手前に **最小 MVP (Phase 1)** に分割する skill。
実行ロジック・質問テンプレ詳細は `docs/ai/codex-mvp-split.md` を正本とし、
skill は読む順序と入出力規約のみを担う。

## Read First

1. `docs/ai/codex-mvp-split.md`（質問テンプレ・判定基準・実例の正本）
2. `docs/ai/plan-metrics-verification.md`（#351 / TASK-0117、前段の規模判定）
3. `.claude/rules/mode-classification.md`（5 段階 mode）
4. `docs/working/templates/README.md`（Phase 分割表 section / pbi-input.md template は未作成、README に記述）

## 想定 phase

A フェーズ (PBI INPUT PACKAGE 作成) **前段**。

## Input

- `<topic>`: MVP 分割を検討する機能・トピック名
- 規模見積もり (TASK-0117 事前メトリクス検証の結果、L 以上推奨)

## Output

- Codex への質問 (4 選択肢 A/B/C/D + 工数 S/M/L + 判断材料 3 軸)
- PBI INPUT PACKAGE への **Phase 分割表** (Phase 1 着手 / Phase 2+ 繰延)

## Rules

- 質問テンプレは `docs/ai/codex-mvp-split.md` を正本とする。skill は順序のみ。
- 判断材料 3 軸: ユーザ価値 / 実装の独立性 / 次フェーズへの拡張性
- Phase 1 のみ本セッション scope、Phase 2 以降は別 PBI に繰延
- TASK-0117 (#351) 事前メトリクス検証で実数 ≥ 3 倍 (規模 L 相当) 判定時に起動推奨

## 次フェーズへ

Phase 1 確定後は `ai-dev-plan` skill で plan 生成 (B-1 → 事前メトリクス検証 → B-2 → B-3)。
