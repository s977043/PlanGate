---
name: context-load
description: "CLAUDE.md と依頼文から案件の前提・制約・品質基準を抽出し、context artifact としてサマライズする。Use when: 新しい TASK に着手する前、WF-01 Context Bootstrap 開始時、前提情報を整理したい時。"
---

# Context Load

CLAUDE.md、関連 docs、依頼文（チケット / 会話 / 添付資料）から案件に必要な前提を抽出し、後続 phase が迷わず進められる形にサマライズする Skill。

## カテゴリ

Scan

## 想定 Phase

WF-01 Context Bootstrap

## 入力

- プロジェクトの CLAUDE.md
- 関連する既存ドキュメント（docs/*）
- 依頼文（チケット本文 / コメント / 添付資料）
- 既存コード（読むべき範囲のみ）

## 出力

artifact クラス: **context**

- 対象範囲のサマリ
- 使用可能な技術スタック一覧
- 禁止事項・触ってはいけないファイルの列挙
- 成果物定義（Definition of Done の骨子）

## 使い方

- WF-01 入口で orchestrator / requirements-analyst が呼び出す
- 出力は WF-02 Requirement Expansion の入力となる

## 関連

- Workflow: `docs/workflows/01_context_bootstrap.md`（**配布対象外**。`install.sh --claude` / plugin / Codex の 3 経路とも導入先には配置されない。解決できない場合は本 Skill の記述を代替正本とし、「正本 `<path>` を参照できなかった」と明示する）
- Rule: Rule 2（Skill は再利用単位）、Rule 4（案件固有情報は CLAUDE.md に寄せる）
