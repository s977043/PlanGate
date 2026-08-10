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
| T1023-TC-17d | AC-07 | tmp複製で**`parsed-safe`のtool集合から`MultiEdit`を除去**する単一mutation。同override | syntax PASS、**T1023-TC-22a そのものがFAIL**（MultiEditがparse-unknown扱いになりrc=2になる）、復元後PASS |
| T1023-TC-17e | AC-07 | tmp複製で**top-level `.file_path` legacy fallbackを除去**する単一mutation。同override | syntax PASS、**T1023-TC-02b そのものがFAIL**、復元後PASS |
| T1023-TC-18 | AC-08 | `sh -n`、focused、full suite | 全てexit 0 / 0 failed |
| T1023-TC-19 | AC-09 | git all-ref + working artifact inventory | actor/provenance、plan hash/source SHA、後続変更、利用可否を記録。**加えて以下を機械的に検査する（M-2）**: (1) inventory の**起点が `2026-04-27`（リポジトリ初出）**であり `2026-06-02` 起点になっていない、(2) **(a) ガード不在 / (b) ガード存在・配線不在 / (c) 配線済みだが3欠陥で無効 の3区分で列挙**されている、(3) 記載した件数に**集計単位（追加イベント / distinct path）と測定日・base SHA が併記**されている。**いずれか欠落でFAIL** |
| T1023-TC-20 | AC-10 | legacy TC-01〜07/HMACとstandalone failure injection | legacy保持、standalone非0、source時親exitなし |
| T1023-TC-21 | AC-11 | configured Claude Code Edit/Write/Bash（**必須**）+ **MultiEdit（到達性が実測で確認できた場合のみ必須。到達しない場合は本TCの対象から外し否定宣言へ移す = G-9）** | tool非実行、artifact hash不変。**NotebookEdit / MCP write tool / Codex経路 / bypass発行元検証は対象外**（否定宣言）|
| T1023-TC-21b | AC-11 | **MultiEdit 到達性の実測**（configured Claude Code で `MultiEdit` を発行し hook 発火の有無を確認）| 到達する / しない を証跡付きで確定し、G-9 の分岐入力にする。**未実施ならAC-11はBLOCKED**（M-1）|
| T1023-TC-22a | AC-04 | `tool_name=MultiEdit` + `tool_input.file_path`が通常file | **rc=0**（誤blockしない。正のTC）|
| T1023-TC-22b | AC-01 | `tool_name=MultiEdit` + `tool_input.file_path`がtoken path | **rc=2**（負のTC）|
| T1023-TC-22c | AC-04 | **本文に token path 文字列を含む通常ファイルへの編集**（`tool_input.file_path`=`docs/working/TASK-1023/plan.md`、`edits[]`の`new_string`に`docs/working/TASK-1023/approvals/c3.json`を含む）を `MultiEdit` と `Edit` の両形で | **各 rc=0**（M-3。内容ではなく`file_path`で判定することを固定する。**この plan 自身を編集できなくなる誤blockを防ぐ**）|
| T1023-TC-23 | AC-03 | **stdinを疑似端末（TTY）にしたinvocation**（env normal / token の2形）を **timeout付き**で実行 | env normal → parse-unknown診断で**rc=2**、env token → BLOCKで**rc=2**。いずれも**timeoutに到達しない（非ハング）**ことをassertする |
| T1023-TC-24 | AC-10 | legacy TC-03/04 を `< /dev/null`、TC-05 を valid normal payload の pipe で起動する | stdin未リダイレクトのTCが残っていない（端末実行でsuiteがハングしない）|

## Traceability

| AC | Test |
|---|---|
| AC-01 | T1023-TC-01, T1023-TC-02a, T1023-TC-02b, T1023-TC-22b |
| AC-02 | T1023-TC-03, T1023-TC-04 |
| AC-03 | T1023-TC-05, T1023-TC-06a/b, T1023-TC-07/07b, **T1023-TC-23** |
| AC-04 | T1023-TC-08〜11, **T1023-TC-22a, T1023-TC-22c** |
| AC-05 | T1023-TC-04, T1023-TC-12 |
| AC-06 | T1023-TC-13a/b, **T1023-TC-13c-file, T1023-TC-13c-cmd**, T1023-TC-14a/b/c |
| AC-07 | T1023-TC-15〜17, **T1023-TC-17b, T1023-TC-17c, T1023-TC-17d, T1023-TC-17e** |
| AC-08 | T1023-TC-18 |
| AC-09 | T1023-TC-19 |
| AC-10 | T1023-TC-20, **T1023-TC-24** |
| AC-11 | T1023-TC-21, **T1023-TC-21b** |

## Exit Criteria

- AC-01〜11に未検証がない
- **mutation 7種がすべてkillされる**。かつ kill は `PG_T25_GUARD` override 下で **実TC が FAIL する**ことで示す（mutation script 内のインライン assert の FAIL は kill と認めない）
- **新規追加TCのうち、対応する変異を持たないものが無い**（m-1。TC-22a→変異6 / TC-02b→変異7 / TC-23→変異4 / TC-13c-file→変異5）
- parsed-safe正当経路が誤blockされず、混在commandの保守的blockが仕様と一致する
- **`MultiEdit` の正（rc=0）・負（rc=2）が両方assertされている**
- **本文に token path 文字列を含む通常ファイルの編集が rc=0 である**（TC-22c。誤block方向の検出）
- **MultiEdit 到達性が実測で確定している**（TC-21b）。到達しない場合は closure から外し否定宣言へ移してある
- **stdinをリダイレクトしないTCが1件も残っていない**（端末実行でsuiteがハングしない）
- full suiteが0 failed
- 実Claude Code PreToolUseで不正Write/Bashが停止する証跡がなければMERGE_READYにしない
- 「security closure」は**実際に配線された surface のみ**に限定して主張する（既定は Edit / Write / Bash。MultiEdit は TC-21b が到達を示した場合のみ加える）。NotebookEdit / MCP write / Codex 経路 / bypass 発行元検証は否定宣言として併記
