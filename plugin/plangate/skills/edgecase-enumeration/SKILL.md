---
name: edgecase-enumeration
description: "境界条件・例外条件・異常系を体系的に列挙し、エッジケース一覧を作成する。Use when: WF-02 でエッジケース検討時、テスト観点の網羅性を高めたい時、失敗パス/異常系の抜けを防ぎたい時。"
---

# Edgecase Enumeration

入力の境界値、例外パス、異常系、競合条件などを体系的に列挙する Skill。

## カテゴリ

Check

## 想定 Phase

WF-02 Requirement Expansion

## 入力

- requirements（機能要件 / 非機能要件）
- 対象のデータ型 / API 仕様 / ユーザー操作フロー

## 出力

エッジケース一覧:

- 境界値（0 / 最小 / 最大 / オーバーフロー）
- null / 空 / 未定義の扱い
- タイムアウト / 再送 / 部分成功
- 並行アクセス / 競合条件
- 不正な入力 / バリデーション失敗

## 使い方

- WF-02 で qa-reviewer が呼び出す
- 結果は acceptance-criteria-build とテスト観点設計の入力になる

## 関連

- Workflow: `docs/workflows/02_requirement_expansion.md`
- 連携 Skill: acceptance-criteria-build
- Rule: Rule 2
