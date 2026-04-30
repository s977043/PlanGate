# Phase Contract: handoff

> [`prompt-assembly.md`](../prompt-assembly.md) の phase_contract / 7 phase の 1 つ
> WF-05 Verify & Handoff の出力 phase

## Goal

PBI 完了時に **必須 6 要素** を含む `handoff.md` を発行する。次の担当者が 5 分で状況把握できるサマリ。

## Success criteria

必須 6 要素すべて記述（[`schemas/handoff-summary.schema.json`](../../../schemas/handoff-summary.schema.json) 準拠）:

1. **要件適合確認結果**（AC × 判定）
2. **既知課題一覧**（Severity / open or closed）
3. **V2 候補**（次 PBI への引き継ぎ）
4. **妥協点**（選んだ実装と諦めた代替）
5. **引き継ぎ文書**（5 分サマリ + 触らないファイル + 次のステップ）
6. **テスト結果サマリ**（layer × decision）

## Stop rules

- 必須 6 要素のいずれかが未記述 → block（[`hook-enforcement.md`](../hook-enforcement.md) EHS-2）
- AC FAIL が open のまま完了扱い → 停止（Iron Law #4: 失敗を隠さない）
- WARN が evidence なしで完了扱い → 停止

## Output discipline

- `docs/working/TASK-XXXX/handoff.md`（Markdown 本文）
- handoff-summary.json（schema 準拠メタ、任意）

## 関連

- [`docs/working/templates/handoff.md`](../../working/templates/handoff.md) — テンプレ
- [`schemas/handoff-summary.schema.json`](../../../schemas/handoff-summary.schema.json)
- [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) — handoff 必須化（Rule 5）
