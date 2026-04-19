---
name: risk-assessment
description: "制約・未確定要素・技術的リスクを洗い出し、severity と mitigation を付けて一覧化する。Use when: WF-02/WF-03 でリスク評価が必要な時、Unknown を可視化して判断を促したい時、影響範囲を明確化したい時。"
---

# Risk Assessment

プロジェクトの制約・未確定要素・技術的リスクを列挙し、severity と mitigation を付して可視化する Skill。

## カテゴリ

Check

## 想定 Phase

WF-02 Requirement Expansion / WF-03 Solution Design

## 入力

- requirements（確定部分）
- 既存アーキテクチャ / 依存ライブラリ
- 過去の類似案件の振り返り（あれば）

## 出力

リスク一覧（テーブル形式）:

| Risk | Severity (critical/major/minor/info) | Mitigation |

加えて:

- Unknowns（未確定事項の列挙と解消方針）
- Assumptions（前提条件の明文化）

## 使い方

- WF-02 で qa-reviewer が呼び出す（要件段階のリスク）
- WF-03 で solution-architect が呼び出す（設計段階のリスク）

## 関連

- Workflow: `docs/workflows/02_requirement_expansion.md`, `docs/workflows/03_solution_design.md`
- 連携 Skill: architecture-sketch
- Rule: Rule 2
