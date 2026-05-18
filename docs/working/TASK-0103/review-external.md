# V-3 外部レビュー（Codex）— TASK-0103 / #281

## 結果サマリ
1回目: critical 0 / **major 2** / minor 0（REQUEST_CHANGES）→ 全反映 → 回帰 PASS

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | `--tasks` が hook violation 未適用（run スコープ指定でも hook は period 全体・docs/AC2 違反）| `_hook_violations` に only_tasks 追加。指定時 cols[3] が TASK セットの行のみ（`-`/fixtures は run 外＝除外）。collect から伝播。§4-bis に hook 行扱い明記 |
| MJ-2 | major | `--tasks ""` が falsy で未指定扱い（空 exit2 未充足）| `if a.tasks is not None:` に変更。`""`/`","` exit2・未指定のみ None |
| info×4 | info | default off behavior-preserving / test/dev 判定健全 / cols[3] len 保護 / §4-bis AC 充足 | 対応不要 |

## 判定
major 2 全反映。critical 0。回帰: opt-in 未指定 2 期間 in-place 等価 /
--tasks で task_count と hook violation スコープ一致 / --tasks '' exit2・
未指定 exit0 / run-tests 68/0 / scope=reporting.py+md のみ。
