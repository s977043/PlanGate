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
| T1023-TC-02a | AC-01 | stdin `.tool_input.file_path=.../approvals/c3.json` **のみ**（top-level `.file_path` を含めない） | stderr BLOCK、rc=2 |
| T1023-TC-02b | AC-01 | stdin **top-level `.file_path=.../approvals/c3.json` のみ**（`.tool_input.file_path` を含めない / legacy fallback） | stderr BLOCK、rc=2 |
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
| T1023-TC-13c-file | AC-06 | env normal（通常path） + `$1` token + stdin `.tool_input.file_path`=token path | `$1`でなくstdin独立評価によりrc=2。**stdin file_path抽出をenv-gatedに戻す変異をkillする唯一のTC** |
| T1023-TC-13c-cmd | AC-06 | env normal（通常path） + `$1` token + stdin `.tool_input.command`=token pathへのwrite | `$1`でなくstdin独立評価によりrc=2（Bashレーン側）|
| T1023-TC-14a | AC-06 | hook processへHumanが継承させたbypass=1 | rc=0、secret非表示のstderr診断 |
| T1023-TC-14b | AC-06 | Bash command文字列内の`PLANGATE_SKIP_TOKEN_GUARD=1` + protected write、hook processは明示0 | bypassされずrc=2 |
| T1023-TC-14c | AC-06 | 全non-bypass assertionへcommand-scoped `PLANGATE_SKIP_TOKEN_GUARD=0` | inherited env=1でもassertionは無効化されない |
| T1023-TC-15 | AC-07 | tmp複製で`exit 2`を`exit 1`へ単一mutation。**`PG_T25_GUARD`をmutantへoverrideして TA-25 を再実行** | syntax PASS、**T1023-TC-01 そのものがFAIL**、復元後PASS |
| T1023-TC-16 | AC-07 | tmp複製でstdin常時captureを旧`[ -z "$TARGET" ]`分岐へ単一mutation。同override | syntax PASS、**T1023-TC-03 そのものがFAIL**、復元後PASS |
| T1023-TC-17 | AC-07 | tmp複製でparse-unknown blockを単一mutation。同override | syntax PASS、**T1023-TC-05 そのものがFAIL**、復元後PASS |
| T1023-TC-17b | AC-07 | tmp複製で**`[ ! -t 0 ]`ガードを追加**しTTY時にstdin評価をスキップさせる単一mutation。同override | syntax PASS、**T1023-TC-23 そのものがFAIL**、復元後PASS |
| T1023-TC-17c | AC-07 | tmp複製で**stdin file_path抽出を`[ -z "$TARGET" ] &&`でenv-gated に戻す**単一mutation（stdin captureは常時のまま残す）。同override | syntax PASS、**T1023-TC-13c-file そのものがFAIL**、復元後PASS |
| T1023-TC-18 | AC-08 | `sh -n`、focused、full suite | 全てexit 0 / 0 failed |
| T1023-TC-19 | AC-09 | git all-ref + working artifact inventory | actor/provenance、plan hash/source SHA、後続変更、利用可否を記録 |
| T1023-TC-20 | AC-10 | legacy TC-01〜07/HMACとstandalone failure injection | legacy保持、standalone非0、source時親exitなし |
| T1023-TC-21 | AC-11 | configured Claude Code Edit/Write/MultiEdit/Bash | tool非実行、artifact hash不変。**NotebookEdit / MCP write tool / Codex経路は対象外**（否定宣言）|
| T1023-TC-22a | AC-04 | `tool_name=MultiEdit` + `tool_input.file_path`が通常file + `edits[]`も通常file | **rc=0**（誤blockしない。正のTC）|
| T1023-TC-22b | AC-01,05 | `tool_name=MultiEdit` + (i) `tool_input.file_path`がtoken path / (ii) `file_path`は通常だが`edits[]`要素がtoken pathを指す | 各ケース別assertで **rc=2**（負のTC）|
| T1023-TC-23 | AC-03 | **stdinを疑似端末（TTY）にしたinvocation**（env normal / token の2形）を **timeout付き**で実行 | env normal → parse-unknown診断で**rc=2**、env token → BLOCKで**rc=2**。いずれも**timeoutに到達しない（非ハング）**ことをassertする |
| T1023-TC-24 | AC-10 | legacy TC-03/04 を `< /dev/null`、TC-05 を valid normal payload の pipe で起動する | stdin未リダイレクトのTCが残っていない（端末実行でsuiteがハングしない）|

## Traceability

| AC | Test |
|---|---|
| AC-01 | T1023-TC-01, T1023-TC-02a, T1023-TC-02b, T1023-TC-22b |
| AC-02 | T1023-TC-03, T1023-TC-04 |
| AC-03 | T1023-TC-05, T1023-TC-06a/b, T1023-TC-07/07b, **T1023-TC-23** |
| AC-04 | T1023-TC-08〜11, **T1023-TC-22a** |
| AC-05 | T1023-TC-04, T1023-TC-12, **T1023-TC-22b** |
| AC-06 | T1023-TC-13a/b, **T1023-TC-13c-file, T1023-TC-13c-cmd**, T1023-TC-14a/b/c |
| AC-07 | T1023-TC-15〜17, **T1023-TC-17b, T1023-TC-17c** |
| AC-08 | T1023-TC-18 |
| AC-09 | T1023-TC-19 |
| AC-10 | T1023-TC-20, **T1023-TC-24** |
| AC-11 | T1023-TC-21 |

## Exit Criteria

- AC-01〜11に未検証がない
- **mutation 5種がすべてkillされる**。かつ kill は `PG_T25_GUARD` override 下で **実TC が FAIL する**ことで示す（mutation script 内のインライン assert の FAIL は kill と認めない）
- parsed-safe正当経路が誤blockされず、混在commandの保守的blockが仕様と一致する
- **`MultiEdit` の正（rc=0）・負（rc=2）が両方assertされている**
- **stdinをリダイレクトしないTCが1件も残っていない**（端末実行でsuiteがハングしない）
- full suiteが0 failed
- 実Claude Code PreToolUseで不正Write/Bashが停止する証跡がなければMERGE_READYにしない
- 「security closure」は Edit / Write / MultiEdit / Bash の 4 surface に限定して主張する（NotebookEdit / MCP write / Codex 経路は否定宣言として併記）
