---
task_id: TASK-1023
artifact_type: plan
schema_version: 1
status: draft
mode: critical
related_issue: https://github.com/s977043/PlanGate/issues/1023
created_by: codex
---

# TASK-1023 Implementation Plan

## Goal

configured Claude Code EH-10における既知のexit/env/stdin/parse欠陥をfail-closedで封鎖し、代表的write surfaceをhardeningする。shell文字列matcherだけで包括的なAI自己承認防止が完成したとは主張しない。

## Context

- 対象: `scripts/check-approval-token-write.sh`
- 回帰テスト: `tests/extras/ta-25-approval-token-guard.sh`
- 関連Issue: [#1023](https://github.com/s977043/PlanGate/issues/1023)、[#928](https://github.com/s977043/PlanGate/issues/928)
- base SHA: `9f9af9451e396eec52b7a737ac3db3166ff60fb1`
- 事前再現: envなしtoken fileは`rc=1`、envが通常pathのときstdin token file/Bash writeはいずれも`rc=0`

## Scope

### In Scope

- stdinを必ず一度読み、env targetとstdin file_path/commandを独立に評価
- blockを`exit 2`へ変更
- jq不在・malformed/empty inputのfail-closed
- `$1` target fallbackと代表write surface hardening
- TA-25の正・負・bypass・mutation coverage拡張
- TA-25 standaloneの終了コード正常化と既存TC保持
- 影響期間と既存artifact監査基準の記録

### Out of Scope

- settings/ruleset/Codex配線/merge guard、schema/署名、token path taxonomy全面改修
- 過去artifactのmutation、#928の実装、C-3'再開
- shell文字列の変数分割・間接script等を含む完全解析

## Global Constraints

- production codeはHuman C-3後にのみ編集する
- POSIX `sh`を維持し、新規依存を追加しない
- stdinは複数回読まず、command/file_path双方が同じpayloadを参照する
- target取得はenv→`$1`、stdin file_path/commandは独立に評価し、いずれかがprotected writeならblockする
- 明示bypass以外をfail-openにしない
- parse結果を`protected-write / parsed-safe / parse-unknown`の3値として扱い、parse-unknownはblockする
- `parsed-safe`は`hook_event_name=PreToolUse`、`tool_name`がEdit/Write/Bash、`tool_input`がobject、Edit/Writeは非空string `tool_input.file_path`（legacy互換のみtop-level `.file_path` fallback）、Bashはstring `tool_input.command`を満たす場合だけとする。欠落・null・配列・数値・未知toolはparse-unknown
- token pathと別writeが同一commandに混在する場合は相関解析をせず安全側blockする
- bypassはHuman-owned emergency/test-onlyで、通常test invocationは明示`0`にする
- 実承認artifactを作成・更新・削除しない

## 前提の実測検証

| 前提 | 検証コマンド | 実測結果 | 判定 |
|---|---|---|---|
| 最新main | `git rev-parse HEAD` / GitHub recent commits | `9f9af945...` | ✅ |
| exit 1欠陥 | token file_path payloadをhookへpipe | BLOCK表示、`rc=1` | ✅ |
| env時stdin bypass | env=`src/index.ts` + token Bash write payload | 出力なし、`rc=0` | ✅ |
| 正当なread | token pathへの`cat` payload | `rc=0` | ✅ |
| 影響開始 | `git log` / `git blame` | 追加`a7c3805f`、現分岐`82137332` | ✅ |
| 未列挙write | `apply_patch` / `patch` payload | token pathを含んでも`rc=0` | ❌。代表surfaceを本PBIへ追加 |
| Codex配線 | `.codex/hooks.json` / `eh-bridge.sh` | EH-10未配線、bridgeは`scripts/hooks/*` | ❌。#928へ残存P0として分離 |

## Questions / Unknowns

- 既存artifactの真正性はコード差分だけでは確定しない。provenance不明・hash不一致は利用停止候補としてHumanへ渡す。

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | envを優先しstdinはenv不在時のみ読む現設計の部分修正 | 差分最小 | Bash matcherが再びblindになる | 不採用 |
| B | stdinを常時captureし、env/arg target・parsed file_path・parsed commandを独立評価。parse不能はblock | 既知欠陥を同じ境界でfail-closed化 | jq不在・malformed時の可用性低下 | 採用 |
| C | Python等のJSON parserを必須依存にする | parser精度が高い | hookの可用性と配布互換性を下げる | 不採用 |

### Recommended Approach

案Bを採用する。`_stdin=$(cat ...)`をbypass判定後に一度だけ行い、jq利用可能時のみ構造化抽出する。jq不在、parse失敗、empty inputは`parse-unknown`として診断付き`exit 2`にする。env targetは`$1`より優先するが、stdin解析の代替にはしない。`_has_write_intent`へ代表surfaceを追加する一方、文字列matcherの包括性は主張せず、#928完了までC-3'停止を維持する。

### Input Decision Table

| env target | `$1` | stdin parse | 判定 |
|---|---|---|---|
| token | 任意 | 任意 | protected-write → exit 2 |
| 空 | token | parsed-safe | fallback targetとしてprotected-write → exit 2 |
| normal | token | parsed-safe | env優先のため`$1`は無視。stdinがparsed-safe normalならexit 0、stdin protectedならexit 2 |
| normal/空 | normal/空 | token file_pathまたはtoken write command | protected-write → exit 2 |
| normal/空 | normal/空 | read-only/normal operation | parsed-safe → exit 0 |
| 任意 | 任意 | jq不在、malformed/truncated、empty/read error | parse-unknown → exit 2 |

> 既存TA-25 TC-05（env normal、stdinなし、exit 0）は目的を保持しつつvalid normal
> PreToolUse JSONを渡す形へmigrationする。empty stdinを許可する旧期待値は安全側契約と
> 両立しないため変更するが、normal fileを許可する回帰目的は維持する。

## Files / Components to Touch

| ファイル | 操作 | 目的 |
|---|---|---|
| `scripts/check-approval-token-write.sh` | modify | stdin/env/fallback判定とblocking rc修正 |
| `tests/extras/ta-25-approval-token-guard.sh` | modify | 正負・回避・mutation test追加 |
| `docs/working/TASK-1023/**` | create/update | Plan/Gate/evidence/handoff |

## Work Breakdown

### Task 1: RED coverage and legacy preservation

- TA-25既存TASK-0123 TC-01〜07/HMAC checksを削除せず保持する。
- legacy TC-03/04の期待rcを1→2へ、TC-05の入力をvalid normal stdin付きへmigrationし、各testの回帰目的は維持する。
- 新規IDを`T1023-TC-*`とし、env+arg+stdin競合、Bash write、exit 2、parse-unknown、negative controlを追加する。
- standalone counter/finalizerを追加し、FAIL表示時のrc=0を解消する。source時は親processをexitしない。
- pre-fix HEADで新規casesが期待どおりFAILする証跡を保存する。
- rollback: test commitのみを`git revert <sha>`。実装commitより先に戻さない。

### Task 2: Minimal boundary fix

- stdinを常時1回captureする。
- env→`$1` targetとstdin file pathを独立評価する。
- stdin commandをenvの有無に関係なく評価する。
- `_block`を`exit 2`へ変更する。
- jq不在/malformed/emptyをparse-unknownとしてblockする。
- `apply_patch`/`patch`/Node/Perl/Rubyの代表write matcherを追加する。
- 固定payload: `apply_patch <<'PATCH' ... c3.json`、`patch ... c3.json <<'PATCH'`、`node -e "require('fs').writeFileSync('.../c3.json','{}')"`、`perl -e "open ...; print ..."`/`perl -pi`、`ruby -e "File.write('.../c3.json','{}')"`。各surfaceを別assertにする。
- bypass有効時は値全体やsecretを出さず、Human-owned emergency/test-onlyが有効である診断をstderrへ出す。
- rollback: 実装commitを`git revert <sha>`すると脆弱性が復活するため、緊急時はC-3'停止を維持したままHuman判断で実施する。

### Task 3: Mutation and compatibility verification

- `exit 2→1`、stdin常時capture撤去、parse-unknown block撤去をtmp複製へ1箇所ずつ注入し、置換件数=1・mutant `sh -n` PASS・baseline PASS・指定TC FAIL・復元PASSを確認する。
- token read、normal write、明示bypass、Human CLI文字列が通ることを確認する。
- non-TTY CLIは`mktemp -d`内へbinと最小TASKを複製して実行し、実repoのtracked/ignored audit artifactのbefore/after不変を確認する。
- rollback: verification artifactのみなら削除せずstatusへ失敗として記録し、修正はTask 1/2へ戻す。

### Task 4: Full verification and audit handoff

- `sh -n`、TA-25、full suite、diff scopeを確認する。
- git履歴/all refsを含む2026-06-02以降の既存approval artifactとdecision/RunEvidenceをread-onlyで列挙し、actor/provenance、plan hash、source SHA、後続変更、利用停止/再承認基準をhandoffへ記録する。
- rollback: 文書は履歴を消さずaddendumで訂正する。

## Verification Plan

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence保存先 |
|---|---|---|---|
| Syntax | `sh -n scripts/check-approval-token-write.sh tests/extras/ta-25-approval-token-guard.sh` | exit 0 | `evidence/test-runs/syntax.log` |
| Focused | `sh tests/run-tests.sh`のTA-25区間およびstandalone helper | AC-01〜07、AC-10 PASS | `evidence/test-runs/ta-25.log` |
| Mutation | anchor置換数=1、mutant syntax PASS、指定TCのみFAIL、復元PASS | 3 mutant kill | `evidence/test-runs/mutation.log` |
| Full | `sh tests/run-tests.sh` | 0 failed / exit 0 | `evidence/test-runs/full-suite.log` |
| No-jq | required `cat`/`grep`等だけをtemp binへsymlinkしjqを除外、absolute `/bin/sh`で実行 | `command -v jq`失敗かつparse-unknown rc=2 | `evidence/test-runs/no-jq.log` |
| Audit | `git log --all`、tree walk、tracked working artifactsのread-only棚卸し | provenanceと再承認判定が追跡可能 | `evidence/verification/approval-audit.md` |
| Hook E2E | configured Claude CodeでEdit/Write/Bashを実行 | tool非実行、artifact不変 | `evidence/e2e/claude-pretooluse.md` |

### レビューレーン計画

| 成果物 | レーン | unavailable時の代替 |
|---|---|---|
| Plan Package | 設計妥当性 / コードベース整合の2独立レーン | C-2 unavailableを記録しHuman C-3で代替せず停止 |
| 実装diff | security boundary bypass review / compatibility review | Human C-4で未充足を明示しmergeしない |

## Stop Conditions

- Human C-3未承認、plan hash不一致、base SHA drift、scope外file変更、mutation survivor、focused/full test失敗、非TTY CLIが0になるかfixture境界外を変更する、Hook E2E未取得、bypassがC-3'環境で有効、監査でprovenance不明の現行承認を検出した場合に停止する。

## Replan Triggers

- 変更対象が実装2ファイル以外へ広がる
- parsed-safe/parse-unknown decision tableを実装できない
- Claude Code実セッションで`exit 2`でも書き込みが停止しない
- plan更新後にC-3 artifactのplan hashが一致しない
- settings/Codex配線へscopeを広げる必要が生じる

## Mode判定

**モード**: `critical` / `lite_eligible=false`

- 実装2ファイルでもP0 Minimum Trust Kernel、承認境界、既存承認監査を扱うため安全側にcriticalへ引き上げる
- 受入基準11件、security impact極高、C-3'利用不可
- Human C-3、V-2/V-3/V-4、Hook E2E、Human C-4を必須とする
