# EXECUTION PLAN: TASK-0055 / retrospective Try T-5

> Mode: **standard**

## Goal

v8.4 ツーリング（`bin/plangate eval`）を PBI-116 配下 6 件に走らせ、自動測定が v8.3 手動測定と一貫した結果を出すことを実証 + v8.5 比較基準を確立。

## Approach

1. for loop で `python3 scripts/eval-runner.py <TASK> --no-write` を 6 回実行、stdout から数値抽出
2. 結果を `docs/working/TASK-0055/evidence/baseline-data-v8.4.md` に集計
3. `eval-comparison-template.md` に v8.4 baseline 行 + v8.3→v8.4 比較テーブル追記
4. `eval-baseline-procedure.md` を v2 に：自動手順を主、v8.3 手動手順を「後方互換」セクションに移動

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `docs/working/TASK-0055/evidence/baseline-data-v8.4.md` | 新規 |
| `docs/ai/eval-comparison-template.md` | 編集（v8.4 セクション追加）|
| `docs/ai/eval-baseline-procedure.md` | 編集（Status v1 → v2、自動手順追加）|
| `docs/working/TASK-0055/*` | 新規 |

## Mode判定

standard（CI 影響なし、doc-only、複数 doc 横断更新で軽微以上）

## 確認方法

- 全 6 PBI で eval-runner exit 0
- v8.3 手動 baseline と同等の数値（AC 100% / format 100%）
- schema compliance が 100%（v8.3 では「違反だが許容」だった部分が #167 で解消）
