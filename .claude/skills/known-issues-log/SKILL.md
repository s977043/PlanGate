---
name: known-issues-log
description: "妥協点・既知不具合・V2 候補を文書化し、次の担当者が再開可能な形に整備する。Use when: WF-05 Verify & Handoff で handoff パッケージを仕上げる時、今回のスコープ外を明示的に残したい時。"
---

# Known Issues Log

実装過程で発生した妥協点、既知不具合、V2 候補を明文化し、handoff パッケージに統合する Skill。

## カテゴリ

Review

## 想定 Phase

WF-05 Verify & Handoff

## 入力

- known-issues artifact（WF-04 出力）
- acceptance-review の出力
- 実装時に記録した TODO / FIXME コメント

## 出力

既知課題表:

- 既知不具合（再現手順 / 影響範囲 / 回避策）
- 妥協点（選ばなかった選択肢と理由）
- V2 候補（今回 scope 外と確認された項目、優先度付き）
- フォローアップチケット候補

## 使い方

- WF-05 で qa-reviewer が呼び出す
- 出力は handoff artifact に統合され、次スプリント / 別チームに引き渡される

## 関連

- Workflow: `docs/workflows/05_verify_and_handoff.md`
- 連携 Skill: acceptance-review
- Rule: Rule 2、Rule 5（最終成果物は毎回 handoff に集約）
