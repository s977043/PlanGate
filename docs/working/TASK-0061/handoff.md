# Handoff: TASK-0061 (PBI-HI-000 / Issue #194)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 baseline 対象 TASK 3件以上 | 5 件 (TASK-0050/0054/0055/0056/0057) | ✅ PASS |
| AC-02 各 TASK で eval 結果保存 | 各 TASK 配下に eval-result.{md,json} 計 10 ファイル | ✅ PASS |
| AC-03 8 観点 eval 結果が MD/JSON | baseline.md §4 表 + baseline.json `tasks[]` 両方 | ✅ PASS |
| AC-04 release blocker 有無明記 | baseline.md §4 / json `release_blocker_count` 全件記録 | ✅ PASS |
| AC-05 hook / C-3 / C-4 / V-1 / handoff 現状 | baseline.md §5 (5 サブセクション) | ✅ PASS |
| AC-06 後続改善との比較可能形式 | baseline.md §6 比較表 + json schema | ✅ PASS |

**全 6/6 PASS**

## 2. 既知課題

- **approval_discipline 全 TASK FAIL**: light mode で `approvals/c3.json` を作成しない運用と整合。Eval expansion (PBI-HI-002 / #196) で mode 別判定への拡張候補
- **tool_overuse / latency_cost 全 TASK n/a**: session log 未供給。PBI-HI-001 (Metrics v1, #195) 実装後に再取得する必要

## 3. V2 候補

- session log を含めた baseline 再取得（#195 完了後）
- profile 別 baseline（claude-opus / sonnet / codex の profile 比較、#197 連動）
- baseline 自動更新 cron / CI integration（明示的 Non-goal）
- 全 TASK（過去 50+ 件）への網羅 eval（明示的 Non-goal、代表 5 件で固定）

## 4. 妥協点

- TASK 選定は **完了直近** 5 件に限定（過去 TASK-0001〜0049 までは含めない）。理由: light/standard mode の最新運用を baseline にしたいため
- light mode TASK は `approvals/c3.json` を作らないため eval が FAIL になる構造的問題があるが、本 PBI では事実として記録するに留める
- profile 指定なし baseline。profile 別比較は #197 (Model Profile v2) で実施
- session log 未供給。latency / cost / tool_overuse は n/a で記録

## 5. 引き継ぎ文書

新規 2 ファイル + 各 TASK の eval-result（副作用）：

- `docs/ai/eval-baselines/2026-05-04-baseline.md` — 人間可読 baseline（§1 目的〜§10 関連）
- `docs/ai/eval-baselines/2026-05-04-baseline.json` — 機械可読 snapshot（aggregate 含む）
- `docs/working/TASK-{0050,0054,0055,0056,0057}/eval-result.{md,json}` — 各 TASK の評価結果

#195 (Metrics v1) 着手時、本 baseline の `latency_cost` / `tool_overuse` 列が `n/a` から数値に変わることが期待される。比較は同 baseline_id を参照。

## 6. テスト結果サマリ

- L-0 markdown lint: CI で確認
- V-1 受入基準照合: 全 6 AC PASS（自己検証）
- eval-runner 実行: 5 件全件 exit 0（release blocker WARN は想定通り）
- 影響範囲: docs only（runtime 変更なし、副作用は eval-result ファイル生成のみ）
