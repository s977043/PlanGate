---
task_id: TASK-0083
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0083

> #228 PBI-HI-012: Run Outcome Review v1（Markdown テンプレート / v8.7.0 / light）
> F4(#248) WF-06 が「#228 固定5項目」を参照するが**テンプレ本体未作成**。本 PBI で作成。

## Context / Why

各 run 完了時の軽量振り返り `run-outcome-review.md` を導入。Trace Timeline
(#229) / Dogfooding Eval (#231) の「人間が納得できる評価項目」を先に固定。
WF-06 Retro(#248) は本テンプレを参照する前提で実装済み（再定義せず参照）。

## What — Scope

### In scope

- `docs/working/templates/run-outcome-review.md` 新規作成（5 必須セクション）:
  1. 目的は達成したか / 2. 失敗・迷走・手戻りは何か / 3. 次回再利用すべき
  判断は何か / 4. どの skill/gate/artifact が効いたか / 5. 1人運用上 負荷が
  高かった箇所（retro-phase.md §2 / 06_retro.md の固定5項目と一致させる）
- 記入例（実 TASK ベース）1 件以上
- handoff.md との責務違いをテンプレ冒頭に明記（handoff=引き継ぎ / outcome
  review=run 改善学習）
- `docs/working/templates/README.md`（無ければ docs/plangate.md）に optional
  artifact として記載
- 既存利用者の移行コストゼロ（**必須化しない**・任意導入）

### Out of scope

- 自動生成 / events.ndjson 連携 / multi-author / LLM-judge（#229/#231/#235で扱う）
- WF-06(#248) の再実装（参照関係は既存・整合確認のみ）

## Acceptance Criteria

- [ ] AC-1: `docs/working/templates/run-outcome-review.md` が存在し5項目が必須セクション
- [ ] AC-2: 記入例（実 TASK ベース）1件以上を含む
- [ ] AC-3: handoff との責務違いがテンプレ冒頭に明記
- [ ] AC-4: templates/README.md（or plangate.md）に optional artifact 記載
- [ ] AC-5: 必須化されていない（既存利用者 移行コストゼロ・後方互換）
- [ ] AC-6: 5項目が retro-phase.md §2 / 06_retro.md（#248 WF-06）と一致（整合）
- [ ] AC-7: 既存 hook/CLI テスト回帰なし（テンプレ追加のみ・挙動不変）

## Notes from Refinement

- F4 WF-06 が「テンプレ仕様は #228 に従う」と明記済 → 本テンプレが正本
- 項目過多はメモ化リスク（Round 5）→ 5項目厳守

## Estimation Evidence

**Risks**: handoff と内容重複 → 冒頭で責務違い明記。**Unknowns**: なし
**Assumptions**: Markdown 単体・必須化しない・WF-06 と5項目一致。Mode=light
