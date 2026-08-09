# TEST CASES — TASK-1023

## Contract

| rc | 意味 |
|---:|---|
| 0 | 許可、または明示bypass |
| 2 | PreToolUse block |
| その他 | 本PBIのtoken guard正常系では使用しない |

## Test Cases

| ID | 対応AC | 入力 / 前提 | 期待結果 |
|---|---|---|---|
| TC-01 | AC-01 | env=`.../maintenance.json` | stderr BLOCK、rc=2 |
| TC-02 | AC-01 | stdin `.tool_input.file_path=.../approvals/c3.json` | stderr BLOCK、rc=2 |
| TC-03 | AC-02 | env=`src/index.ts` + stdin command=`printf x > .../c3.json` | stderr BLOCK、rc=2 |
| TC-04 | AC-02,05 | env通常path + 複数行/空白/quoteを含む`tee .../maintenance.json` | stderr BLOCK、rc=2 |
| TC-05 | AC-03 | jqを含まない一時PATH + TC-02 payload | rc=2 |
| TC-06 | AC-03 | jqを含まない一時PATH + TC-03 payload | rc=2 |
| TC-07 | AC-03,04 | jqを含まない一時PATH + normal file payload | rc=0 |
| TC-08 | AC-04 | token pathを`cat`するBash payload | rc=0 |
| TC-09 | AC-04 | `bin/plangate approve TASK-1023`文字列 | rc=0（guardはCLI内Human TTY検査へ委譲） |
| TC-10 | AC-04 | normal fileへのEdit/Write/Bash write | rc=0 |
| TC-11 | AC-05 | `./docs/.../approvals/c3.json`への`cp`/`mv`/`sed -i`代表形 | 各rc=2 |
| TC-12 | AC-06 | `PLANGATE_SKIP_TOKEN_GUARD=1` + malicious payload | rc=0 |
| TC-13 | AC-06 | bypass未設定/`0` + malicious payload | rc=2 |
| TC-14 | AC-07 | tmp複製で`exit 2`を`exit 1`へmutation | focused assertion FAIL |
| TC-15 | AC-07 | tmp複製でstdin常時captureを旧条件分岐へmutation | TC-03相当がFAIL |
| TC-16 | AC-07 | tmp複製でjq fallbackを除去、jqなしPATHで実行 | TC-05/06相当がFAIL |
| TC-17 | AC-08 | `sh -n`、TA-25、full suite | 全てexit 0 / 0 failed |
| TC-18 | AC-09 | read-only artifact inventory | path、生成根拠、plan hash/source SHA、再承認要否を記録 |

## Traceability

| AC | Test |
|---|---|
| AC-01 | TC-01, TC-02 |
| AC-02 | TC-03, TC-04 |
| AC-03 | TC-05, TC-06, TC-07 |
| AC-04 | TC-08, TC-09, TC-10 |
| AC-05 | TC-04, TC-11 |
| AC-06 | TC-12, TC-13 |
| AC-07 | TC-14, TC-15, TC-16 |
| AC-08 | TC-17 |
| AC-09 | TC-18 |

## Exit Criteria

- AC-01〜09に未検証がない
- mutation 3種がすべてkillされる
- 正当経路TC-07〜10が誤blockされない
- full suiteが0 failed
- 実Claude Code PreToolUseで不正Write/Bashが停止する証跡をHuman C-4前に確認する

