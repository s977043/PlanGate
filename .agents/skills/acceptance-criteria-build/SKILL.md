---
name: acceptance-criteria-build
description: "要件とエッジケースから受け入れ条件（AC）を明文化し、チェックリスト形式で整理する。Use when: WF-02 で AC を確定したい時、Definition of Done を明確化したい時、テストケース設計の前提を整えたい時。"
---

# Acceptance Criteria Build

要件・エッジケース・非機能要件を受け入れ条件（AC）に変換し、検証可能なチェックリストを生成する Skill。

## カテゴリ

Design

## 想定 Phase

WF-02 Requirement Expansion

## 入力

- requirements（機能 / 非機能）
- エッジケース一覧（edgecase-enumeration の出力）
- UX 期待値

## 出力

AC 一覧:

- 機械検証可能な項目（自動テスト化可能）
- 目視確認項目（スクリーンショット / 手動確認）
- 各 AC に対応する想定テストケース ID

## 使い方

- WF-02 終盤で qa-reviewer が呼び出す
- 出力は requirements artifact の最終形に統合される

## 関連

- Workflow: `docs/workflows/02_requirement_expansion.md`
- 連携 Skill: edgecase-enumeration / acceptance-review
- Rule: Rule 2
