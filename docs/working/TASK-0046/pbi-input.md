# PBI INPUT PACKAGE: TASK-0046 / Issue #155

> Source: [#155 [EPIC] v8.3 baseline 測定 — Eval framework 初回ベースライン取得](https://github.com/s977043/plangate/issues/155)
> Mode: **standard**

## Context / Why

PlanGate v8.3.0 で **model migration eval framework**（`docs/ai/eval-plan.md` + `eval-cases/` × 8）を整備したが、比較対象の **baseline 測定が未実施**。後続のモデル変更・プロンプト変更の合否判定はこの baseline からの差分で行うため、初回測定が次の eval 系 PBI（#156 eval runner）の前提となる。

## What

### In scope

- 既存 PBI 完了済みの実セッション（PBI-116 配下: TASK-0039 / 0040 / 0041 / 0042 / 0044 の 5 件）から測定
- 8 観点（scope discipline / approval discipline / AC coverage / verification honesty / stop behavior / tool overuse / format adherence / latency-cost）を集計
- `docs/ai/eval-comparison-template.md` に v8.3 baseline 行を追記
- 集計手順を `docs/ai/eval-baseline-procedure.md` として新規ドキュメント化

### Out of scope

- 自動 eval runner の実装（#156 で対応）
- 全モデル / provider の網羅比較
- baseline の継続更新基盤
- latency / tool calls の正確な実測（log 不在のため "n/a" 扱い、#156 の自動集計で取得）

## Acceptance Criteria

- AC-1: `docs/ai/eval-comparison-template.md` に v8.3 baseline 行が記入されている
- AC-2: 8 観点すべての測定値（数値 or PASS/WARN/FAIL）が記入されている
- AC-3: 測定根拠（対象セッション・evidence ファイルパス）が記録されている
- AC-4: 集計手順が `docs/ai/eval-baseline-procedure.md` に明文化されている
- AC-5: schema 準拠率が ≥ 95% を満たしている（format adherence、release blocker 観点）

## Notes

- 推奨 mode: **standard**（doc-only / 1 観点 = 1 行 + 手順書）
- 関連: PBI-116 EPIC #116（前提）
- 次 EPIC: #156 eval runner 実装（本 PBI 完了後の自動化候補、baseline 値を既知の正解として動作確認に使う）
