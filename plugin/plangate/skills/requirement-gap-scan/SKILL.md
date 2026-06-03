---
name: requirement-gap-scan
description: "初期要求から抜け漏れ・曖昧さ・対象外を体系的に洗い出し、追加要件候補をリストアップする。Use when: WF-02 Requirement Expansion で仕様の抜け漏れを検出したい時、PBI の In scope/Out of scope を締めたい時。"
---

# Requirement Gap Scan

初期要求を機能 / 非機能 / 対象外 / 例外条件 / UX期待値の観点で体系的にスキャンし、明文化されていない要件を抽出する Skill。

## カテゴリ

Scan

## 想定 Phase

WF-02 Requirement Expansion

## 入力

- context artifact（WF-01 出力）
- 初期要求（ユースケース / ユーザーストーリー）

## 出力

追加要件候補の一覧:

- 機能要件の抜け
- 非機能要件の抜け
- 未言及のエッジケース
- 暗黙の前提
- 対象外として確認すべき項目

## 使い方

- WF-02 で requirements-analyst が呼び出す
- 出力は acceptance-criteria-build の入力にもなる

## 関連

- Workflow: `docs/workflows/02_requirement_expansion.md`
- 連携 Skill: nonfunctional-check / edgecase-enumeration / acceptance-criteria-build
- Rule: Rule 2
