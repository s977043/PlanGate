---
task_id: TASK-0083
artifact_type: plan
schema_version: 1
status: draft
---

# EXECUTION PLAN — TASK-0083 Run Outcome Review v1（#228・light）

## Goal

`run-outcome-review.md` テンプレ（5必須項目・記入例・責務違い明記・optional）を
作成。WF-06(#248) の参照先正本を確立。挙動不変・任意導入。

## 変更内容（light 簡易 plan）

- 新規: `docs/working/templates/run-outcome-review.md`（5項目+記入例+handoff責務違い）
- 追記: `docs/working/templates/README.md` に optional artifact 行（無ければ新規）
- 整合: retro-phase.md §2 / 06_retro.md 固定5項目と文言一致

## 確認方法

- AC-1〜7 を grep/構造で検証
- 5項目が WF-06(#248) と一致（突合）
- hook/CLI テスト回帰なし（テンプレ追加のみ＝挙動不変）

## Mode判定

**モード**: light（単一テンプレ追加+docs追記1-2箇所・後方互換・強制機構不変）
