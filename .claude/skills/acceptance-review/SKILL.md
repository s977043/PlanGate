---
name: acceptance-review
description: "実装結果を受け入れ条件（AC）と照合し、適合 / 不足を明確化する。Use when: WF-05 Verify & Handoff で要件適合確認が必要な時、PR の受入基準チェックを網羅的に実施したい時。"
---

# Acceptance Review

実装差分と AC（受け入れ条件）を突き合わせ、適合 / 不足 / 保留を判定する Skill。

## カテゴリ

Review

## 想定 Phase

WF-05 Verify & Handoff

## 入力

- AC 一覧（acceptance-criteria-build の出力）
- 実装差分（known-issues artifact + コード）
- テスト実行結果 / CI 結果

## 出力

要件適合確認結果:

- AC ごとの 適合 / 不足 / 保留 判定
- 適合根拠（テストケース ID / スクリーンショット）
- 不足があればフォローアップ計画
- V2 候補（scope 外と確認された項目）

## 使い方

- WF-05 で qa-reviewer が呼び出す
- 出力は handoff artifact の中核となる

## 関連

- Workflow: `docs/workflows/05_verify_and_handoff.md`
- 連携 Skill: acceptance-criteria-build / known-issues-log
- Rule: Rule 2
