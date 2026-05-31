---
task_id: TASK-0121
artifact_type: review-self
phase: C-1
verdict: WARN
score: 90
---

# TASK-0121 C-1 セルフレビュー

## 総合判定

| 項目 | 結果 |
|------|------|
| 総合判定 | **WARN** |
| スコア | **90/100** |
| PASS / WARN / FAIL | 13 / 2 / 0 |

前提: Mode=high-risk。HO split-ownership として、振り返り配点は「計画精度30 / テスト品質15 / プロセス遵守15 / 効率性10 / 成果物品質30」、`.claude/agents/workflow-conductor.md` と `.claude/agents/retrospective-analyst.md` は人間編集として評価した。`plan.md` / `todo.md` / `test-cases.md` は変更せず、C-1 評価のみ作成した。

> 注記: 依頼文は「17項目」としているが、明示された内訳は Plan 7 + ToDo 5 + TestCases 3 の 15 項目であるため、本レビューは明示 ID に従って評価する。

## Plan 7項目

| ID | 判定 | 根拠 |
|----|------|------|
| C1-PLAN-01 | PASS | AC-1〜AC-9 が plan の Goal / Constraints / Work Breakdown / Testing Strategy に反映され、test-cases.md でも全 AC に対応している。 |
| C1-PLAN-02 | PASS | CI 配線・pre-push 配線・Human-owned 反映タイミングの Unknowns は human 判断として分離され、実行手順に落ちている。 |
| C1-PLAN-03 | PASS | `.codex` 未変更、過去 retrospective 再計算除外、HO 2件の人間編集など Non-goals と境界が明確。 |
| C1-PLAN-04 | PASS | `sh -n`、RED/GREEN、旧配点残存、新5軸、合計100、pre-push/CI 参照確認までテスト戦略が具体化されている。 |
| C1-PLAN-05 | PASS | Work Breakdown の各 Step に Output / Owner / Risk / チェックポイントがあり、agent と human の成果物が分離されている。 |
| C1-PLAN-06 | WARN | 主要依存は整理済みだが、CI 連携が任意である一方、todo の T-07 が H-05 にも依存しており、N/A 完了条件が明示されていない。 |
| C1-PLAN-07 | PASS | consistency script による RED/GREEN と `sh` / `rg` / `git diff` ベースの構造検証が定義され、ドリフト検知を自動化できる。 |

## ToDo 5項目

| ID | 判定 | 根拠 |
|----|------|------|
| C1-TODO-01 | PASS | T-01〜T-07 / H-01〜H-06 は1成果物または1検証単位に分かれ、owner と risk が明示されている。 |
| C1-TODO-02 | WARN | `depends_on` は概ね妥当だが、T-07 が optional な H-05 を必須依存に見せているため、CI 不要時の完了扱いが曖昧。 |
| C1-TODO-03 | PASS | 全タスクにチェックポイントがあり、構文確認・RED・GREEN・diffなし・HO人間編集など確認点が明確。 |
| C1-TODO-04 | PASS | H-01 後に agent 実装開始、HO / `.github/workflows/` は human、`.codex` は未変更確認に留める構造で Iron Law 境界を守っている。 |
| C1-TODO-05 | PASS | 各タスクに完了条件があり、旧配点なし、新配点確認、script 起動確認、C-4 レビューなど終了判定が書かれている。 |

## TestCases 3項目

| ID | 判定 | 根拠 |
|----|------|------|
| C1-TC-01 | PASS | AC-1〜AC-9 が TC-01〜TC-10 に紐付き、配点同期・C-1語彙・HO人間編集・pre-push/CI まで対応している。 |
| C1-TC-02 | PASS | EC-01〜EC-05 で過去 artifact 誤検出、部分更新、合計不一致、`.codex` 誤更新、pre-push 未配線を扱っている。 |
| C1-TC-03 | WARN | 多くはコマンドで自動確認可能だが、TC-08 の fixture / 一時コピー作成方法と TC-10 の human-owned 変更確認は手順がやや手動依存。 |

## 指摘事項

| severity | 対象 | 内容 | 推奨 |
|----------|------|------|------|
| minor | C1-PLAN-06 / C1-TODO-02 | H-05 は「CI 連携が必要な場合」だが、T-07 の `depends_on` では必須依存に見える。 | C-2 または C-3 前の確定反映時に、CI 不要時は H-05 を N/A 完了扱いにできることを todo に明記する。 |
| minor | C1-TC-03 | TC-08 の合計不一致 negative test は fixture / 一時コピーの作り方が未確定。 | 実装時に一時ディレクトリまたは script 引数で検証対象を差し替える方針を evidence に残す。 |

## C-3 向け結論

FAIL はなく、HO split-ownership と plan_hash 固定の前提は守られている。上記 WARN は exec を直ちに止める blocker ではないが、high-risk として C-2 / C-3 では optional CI 依存と negative test 手順を確認すること。
