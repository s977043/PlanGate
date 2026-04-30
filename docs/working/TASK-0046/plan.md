# EXECUTION PLAN: TASK-0046 / Issue #155

> Mode: **standard**

## Goal

PlanGate v8.3 の eval framework に対し、PBI-116 EPIC 完了済 5 件（TASK-0039 / 0040 / 0041 / 0042 / 0044）から **初回 baseline** を取得し、`eval-comparison-template.md` に 1 行追記 + 集計手順を `eval-baseline-procedure.md` に明文化する。

## Approach

1. **対象選定**: PBI-116 配下の 5 子 PBI（最低 3 件の要件を満たす、Phase 1〜4 を網羅）
2. **集計方式**: 既存 handoff.md / approvals/c3.json / status.md から **手動抽出**（自動 eval runner は #156 で実装）
3. **8 観点測定**:
   - approval discipline: c3.json 存在率
   - AC coverage: handoff の AC PASS / 総 AC
   - format adherence: handoff 必須 6 要素 grep の準拠率
   - scope discipline / verification honesty / stop behavior: handoff 内宣言 + retrospective 矛盾チェック
   - tool overuse: 主観だが retrospective 言及があれば WARN
   - latency / cost: log 不在のため `n/a (manual)`、#156 で自動取得
4. **記入**: `eval-comparison-template.md` に v8.3 baseline 行を追記
5. **手順化**: `eval-baseline-procedure.md` を新設し、本セッションで実施した手順をそのまま記述（再現性担保）

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `docs/ai/eval-comparison-template.md` | 編集（baseline 行追加 + 出典セクション追加）|
| `docs/ai/eval-baseline-procedure.md` | 新規 |
| `docs/working/TASK-0046/*` | 新規（plan / handoff 等）|
| `docs/working/TASK-0046/evidence/baseline-data.md` | 新規（集計の生データ）|

## Mode判定

**モード**: standard

**判定根拠**:
- 変更ファイル数: 2 doc + 5 working = 7 → standard
- 受入基準数: 5 → standard
- 変更種別: doc-only / 計測 → standard
- リスク: doc 整合性のみ → 低
- **最終判定**: standard

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| handoff の自己申告に依存 → verification honesty が外形的 | 5 件横断で矛盾検出（retrospective vs handoff）、矛盾あれば WARN 記録 |
| latency / tool calls が n/a | #156 eval runner で自動集計、baseline 行に "TBD by #156" を明記 |
| schema 準拠率 < 95% で release blocker 該当 | handoff 必須 6 要素を全 PBI で grep、結果に応じて評価値を確定 |

## 確認方法

- `eval-comparison-template.md` に v8.3 baseline 行が visible
- `eval-baseline-procedure.md` の手順で第三者が同じ集計を再現可能
- 5 観点（scope / approval / AC coverage / verification honesty / format adherence）が PASS / 数値で埋まる
