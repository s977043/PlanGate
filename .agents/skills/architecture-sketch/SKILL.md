---
name: architecture-sketch
description: "確定した仕様を、モジュール境界・データフロー・状態管理・失敗時挙動を持つ設計案に落とし込む。Use when: WF-03 Solution Design で設計の叩き台を作りたい時、実装前にアーキテクチャの骨子を固めたい時。"
---

# Architecture Sketch

requirements から実装可能な構造（モジュール構成 / データフロー / 状態管理 / エラーパス / テスト観点）を描き出す Skill。

## カテゴリ

Design

## 想定 Phase

WF-03 Solution Design

## 入力

- requirements artifact（WF-02 出力）
- 既存アーキテクチャ / ADR
- 依存ライブラリ・フレームワーク制約

## 出力

design artifact:

- モジュール構成（境界と責務）
- データフロー図 / シーケンス
- 状態管理方針
- 失敗時の扱い（エラーパス / リトライ / フォールバック）
- テスト観点（Unit / Integration / E2E の分担）
- 依存制約 / 技術的妥協点

## 使い方

- WF-03 で solution-architect が呼び出す
- 出力は WF-04 implementation-agent の入力となる

## 関連

- Workflow: `docs/workflows/03_solution_design.md`
- 連携 Skill: risk-assessment
- Rule: Rule 2
