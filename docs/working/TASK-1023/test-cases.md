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
| T1023-TC-01 | AC-01 | env=`.../maintenance.json` | stderr BLOCK、rc=2 |
| T1023-TC-02 | AC-01 | stdin `.tool_input.file_path=.../approvals/c3.json`およびtop-level `.file_path` | stderr BLOCK、rc=2 |
| T1023-TC-03 | AC-02 | env=`src/index.ts` + stdin command=`printf x > .../c3.json` | stderr BLOCK、rc=2 |
| T1023-TC-04 | AC-02,05 | env通常path + 複数行/空白/quoteを含む`tee .../maintenance.json` | stderr BLOCK、rc=2 |
| T1023-TC-05 | AC-03 | required commandだけを持つ一時PATH（jqなし） | parse-unknown診断、rc=2 |
| T1023-TC-06a | AC-03 | malformed/truncated/empty stdin | 各parse-unknown診断、rc=2 |
| T1023-TC-06b | AC-03 | stdin FDを閉じて`cat` read error | read-failure診断、rc=2、artifact不変 |
| T1023-TC-07 | AC-03 | JSON escaped slash/quote/unicodeを含むvalid payload | jq decode後の実pathで判定、protectedならrc=2 |
| T1023-TC-07b | AC-03 | `{}`、missing `tool_input`、null/array/number field、unknown tool/event | 各parse-unknown診断、rc=2 |
| T1023-TC-08 | AC-04 | token pathをread-only `cat`するparsed Bash payload | rc=0 |
| T1023-TC-09 | AC-04 | token read + normal writeの混在command | 保守的rc=2（相関解析しない仕様） |
| T1023-TC-10 | AC-04 | normal fileへのEdit/Write/Bash write | rc=0 |
| T1023-TC-11 | AC-04 | `bin/plangate approve`/`maintenance start`非TTY実行 | hookは通すがCLI非0、artifact未生成 |
| T1023-TC-12 | AC-05 | 固定payload: heredoc `apply_patch`/`patch`、Node `writeFileSync`、Perl open/writeと`-pi`、Ruby `File.write` | surface別assert、各rc=2 |
| T1023-TC-13a | AC-06 | env空 + `$1` token + parsed-safe normal stdin | fallback targetでrc=2 |
| T1023-TC-13b | AC-06 | env normal + `$1` token + parsed-safe normal stdin | env優先でrc=0 |
| T1023-TC-13c | AC-06 | env normal + `$1` token + stdin malicious | `$1`でなくstdin独立評価によりrc=2 |
| T1023-TC-14a | AC-06 | hook processへHumanが継承させたbypass=1 | rc=0、secret非表示のstderr診断 |
| T1023-TC-14b | AC-06 | Bash command文字列内の`PLANGATE_SKIP_TOKEN_GUARD=1` + protected write、hook processは明示0 | bypassされずrc=2 |
| T1023-TC-14c | AC-06 | 全non-bypass assertionへcommand-scoped `PLANGATE_SKIP_TOKEN_GUARD=0` | inherited env=1でもassertionは無効化されない |
| T1023-TC-15 | AC-07 | tmp複製で`exit 2`を`exit 1`へ単一mutation | syntax PASS、T1023-TC-01 FAIL、復元PASS |
| T1023-TC-16 | AC-07 | tmp複製でstdin常時captureを旧分岐へ単一mutation | syntax PASS、T1023-TC-03 FAIL、復元PASS |
| T1023-TC-17 | AC-07 | tmp複製でparse-unknown blockを単一mutation | syntax PASS、T1023-TC-05 FAIL、復元PASS |
| T1023-TC-18 | AC-08 | `sh -n`、focused、full suite | 全てexit 0 / 0 failed |
| T1023-TC-19 | AC-09 | git all-ref + working artifact inventory | actor/provenance、plan hash/source SHA、後続変更、利用可否を記録 |
| T1023-TC-20 | AC-10 | legacy TC-01〜07/HMACとstandalone failure injection | legacy保持、standalone非0、source時親exitなし |
| T1023-TC-21 | AC-11 | configured Claude Code Edit/Write/Bash | tool非実行、artifact hash不変 |

## Traceability

| AC | Test |
|---|---|
| AC-01 | T1023-TC-01, T1023-TC-02 |
| AC-02 | T1023-TC-03, T1023-TC-04 |
| AC-03 | T1023-TC-05, T1023-TC-06a/b, T1023-TC-07/07b |
| AC-04 | T1023-TC-08〜11 |
| AC-05 | T1023-TC-04, T1023-TC-12 |
| AC-06 | T1023-TC-13a/b/c, T1023-TC-14a/b/c |
| AC-07 | T1023-TC-15〜17 |
| AC-08 | T1023-TC-18 |
| AC-09 | T1023-TC-19 |
| AC-10 | T1023-TC-20 |
| AC-11 | T1023-TC-21 |

## Exit Criteria

- AC-01〜11に未検証がない
- mutation 3種がすべてkillされる
- parsed-safe正当経路が誤blockされず、混在commandの保守的blockが仕様と一致する
- full suiteが0 failed
- 実Claude Code PreToolUseで不正Write/Bashが停止する証跡がなければMERGE_READYにしない
