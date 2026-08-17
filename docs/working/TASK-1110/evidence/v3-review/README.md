# TASK-1110 V-3 レビュー evidence（外部レビューア側で作成）

`../../review-external.md` の各指摘の根拠を再現するためのプローブ一式。

> **注意**: これらのスクリプトはレビュー時の worktree / scratchpad の
> **絶対パスをハードコードしている**（`before.sh` = `origin/main` の guard、
> `after.sh` = PR head の guard を `git show` で書き出したもの）。
> 別環境で再現する場合は先頭の `S` / `WT` / `OLD` / `NEW` を書き換えること。
> 実 `approvals/` には一切書き込まない（rc の観測のみ）。

| ファイル | 対応する指摘 | 内容 |
|----------|-------------|------|
| `cases_v3.py` | R-001 / 棄却候補 | 35 ケースの新旧 rc 比較（新規攻撃ケース N1〜N35） |
| `cases_v3b.py` | **R-001** | 切り詰め文字 9 クラスの網羅 + fail-closed 宣言の全数照合 |
| `cases_v3c.py` | **R-001** | 現実的な spaced / metachar パスでのバイパス |
| `cases_v3d.py` | **R-001** | Write レーン / `tee` レーン / `>` レーンの非対称性 |
| `bench_v3.py` | R-007 | 新旧を交互実行した median 実測（N=60） |
| `my_mutations.sh` | R-005 | V-3 独自変異 M-A〜M-D（focused 群） |
| `my_mutations_full.sh` | R-005 | 同上を 77 TC のフルグループで評価 |
| `ta25_harness_mode.sh` | R-009 | `PG_HARNESS_SOURCED=1` + `FIXTURES_DIR` の harness 相当実行 |
| `run_gnu_ta25.sh` | 棄却候補（移植性） | GNU sed を PATH 先頭に置いた TA-25 実行 |
| `ta61-run.log` | R-009 | `sh tests/extras/ta-61-extra-contract.sh` の完走ログ（89 passed, 0 failed / EXIT=0） |

## プローブの前提（踏みやすい罠）

1. payload に `"hook_event_name":"PreToolUse"` が必須。無いと `parse-unknown` で全件 rc=2
2. hook をシェルから直接叩く場合は `</dev/null` を付ける。stdin が TTY / 空だと fail-closed
   （本ディレクトリの Python プローブは `subprocess.run(input=...)` で常に stdin を供給する）
