---
name: feature-implement
description: "design artifact に従って、最小単位で実装・テスト・自己レビューを繰り返し、動作するコード差分を生成する。Use when: WF-04 Build & Refine で実装する時、TDD で差分ごとに着実に進めたい時。"
---

# Feature Implement

design artifact に従って、機能を最小単位で実装する Skill。差分ごとに自己レビューと明示的な既知課題の記録を行う。

## カテゴリ

Build

## 想定 Phase

WF-04 Build & Refine

## 入力

- design artifact（WF-03 出力）
- テスト観点（design 内で指定されたもの）
- 既存コードベース

## 出力

known-issues artifact + コード差分:

- 動作するコード（テスト付き）
- 自己レビュー結果
- 明示的な既知課題（妥協点 / 未着手項目）
- 実装単位ごとのコミット履歴

## 使い方

- WF-04 で implementation-agent が呼び出す
- TDD サイクル（RED → GREEN → REFACTOR）を最小単位で回す
- 出力は WF-05 の入力となる

## 関連

- Workflow: `docs/workflows/04_build_and_refine.md`
- Rule: Rule 2
