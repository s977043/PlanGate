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
- `parsed-safe`は`hook_event_name=PreToolUse`、`tool_name`が**Edit / Write / MultiEdit / Bash**、`tool_input`がobject、Edit/Writeは非空string `tool_input.file_path`（legacy互換のみtop-level `.file_path` fallback）、**MultiEditは非空string `tool_input.file_path` のみを評価対象とする**、Bashはstring `tool_input.command`を満たす場合だけとする。欠落・null・配列・数値・未知toolはparse-unknown（R-026）

  > **`edits[]` を評価しない理由（M-3）**: `tool_input.edits[]` の要素が path field を持つかを定義する artifact が
  > **リポジトリ内に 1 件も無い**（`grep -rn 'tool_input.edits\|\.edits\[' scripts/ tests/ docs/` → 0 件。
  > `scripts/hooks/check-post-edit-diff.sh` も MultiEdit を扱うが `edits[]` は読まない）。この状態で実装すると
  > **(i) 存在しない field 名を見て TC が自作 payload にだけ緑になる（vacuous AC の再生産）**か、
  > **(ii)「`edits[]` 内の任意文字列に token path が含まれるか」に緩めて誤 block を生む**かの二択にしかならない。
  > 後者は実害が具体的で、**本 plan 自身が本文に `docs/working/TASK-1023/approvals/c3.json` を含むため、
  > この plan を MultiEdit で編集すると block される**。よって `edits[]` 評価は採らず、`file_path` のみに限定する。
  > MultiEdit は編集対象ファイルを `tool_input.file_path` で示すため、token path への書き込みはこれで捕捉できる。
  > 将来 `edits[]` の実 payload が 1 件でも確認できたら再検討する（handoff の V2 候補）。
- **stdinがTTYまたは読み取り不能な場合は`parse-unknown`として`exit 2`にする**。`[ ! -t 0 ]`でガードして**スキップ**してはならない（スキップするとdefect #2がTTY経路で復活する）。また無条件`cat`にもしない（TTY時にhookがハングする）。判定は「TTYならreadせず即block」であり、**block側で統一かつ非ハング**を同時に満たす（R-027）
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
| normal/空 | normal/空 | **stdinがTTY / stdinが存在しない** | **parse-unknown → exit 2。かつstdinをreadせず即座に終了する（ハングしない）**（R-027） |
| token | 任意 | **stdinがTTY** | protected-write → exit 2（**`[ -t 0 ]` 判定を `cat` より前に置くためハングしない**。env 評価の順序は非ハング性の根拠ではない）|
| normal/空 | normal/空 | `tool_name=MultiEdit` + `tool_input.file_path`がtoken path | protected-write → exit 2（R-026）|
| normal/空 | normal/空 | `tool_name=MultiEdit` + 通常file（**本文に token path 文字列を含む場合も**）| parsed-safe → exit 0（R-026 / M-3。内容は判定に使わない）|

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
- legacy TC-03/04/05のinvocationで**stdinを明示的にリダイレクトする**（TC-03/04は`< /dev/null`、TC-05はvalid normal payloadのpipe）。現行TA-25はstdinをリダイレクトしておらず、実装で無条件`cat`にすると端末実行時にsuiteが無限ハングする（CIはstdinが`/dev/null`のため再現せず緑で出荷される）。R-027。
- 新規IDを`T1023-TC-*`とし、env+arg+stdin競合、Bash write、exit 2、parse-unknown、negative controlを追加する。
- **`PG_T25_GUARD`をenv overrideできるようにする**（`PG_T25_GUARD="${PG_T25_GUARD:-$PG_T25_ROOT/scripts/check-approval-token-write.sh}"`）。現行の`tests/extras/ta-25-approval-token-guard.sh:9`はハードコードで、これが無いとmutation TCは実TCではなくmutation script内のインラインassertをFAILさせることになり、「そのTCがその変異を検出する」ことが一度も実証されない（#874と同型）。R-029。
- **MultiEditの正負TC**（T1023-TC-22a / 22b）と**TTY非ハングTC**（T1023-TC-23）を追加する。R-026 / R-027。
- standalone counter/finalizerを追加し、FAIL表示時のrc=0を解消する。source時は親processをexitしない。
- pre-fix HEADで新規casesが期待どおりFAILする証跡を保存する。
- rollback: test commitのみを`git revert <sha>`。実装commitより先に戻さない。

### Task 2: Minimal boundary fix

- stdinを常時1回captureする。ただし**stdinがTTYのときはreadせずparse-unknownとして`exit 2`**にする（`[ ! -t 0 ]`でのスキップは禁止。R-027）。
- env→`$1` targetとstdin file pathを独立評価する。**stdin file_pathの抽出を`[ -z "$TARGET" ]`でgateしない**（gateするとdefect #2のEdit/Write側がそのまま残る。R-028）。
- **`MultiEdit`をparsed-safeのtool集合に含め、`tool_input.file_path`をtoken path判定にかける**（R-026 / `edits[]` は評価しない = M-3）。**ファイル内容（`old_string`/`new_string` 等）は判定に使わない**（token path 文字列を含む通常ファイルの編集を誤blockしないため）。
- stdin commandをenvの有無に関係なく評価する。
- `_block`を`exit 2`へ変更する。
- jq不在/malformed/emptyをparse-unknownとしてblockする。
- `apply_patch`/`patch`/Node/Perl/Rubyの代表write matcherを追加する。
- 固定payload: `apply_patch <<'PATCH' ... c3.json`、`patch ... c3.json <<'PATCH'`、`node -e "require('fs').writeFileSync('.../c3.json','{}')"`、`perl -e "open ...; print ..."`/`perl -pi`、`ruby -e "File.write('.../c3.json','{}')"`。各surfaceを別assertにする。
- bypass有効時は値全体やsecretを出さず、Human-owned emergency/test-onlyが有効である診断をstderrへ出す。
- rollback: 実装commitを`git revert <sha>`すると脆弱性が復活するため、緊急時はC-3'停止を維持したままHuman判断で実施する。

### Task 3: Mutation and compatibility verification

- **mutationは7種**とする。tmp複製へ1箇所ずつ注入し、置換件数=1・mutant `sh -n` PASS・baseline PASS・指定TC FAIL・復元PASSを確認する。
  1. `exit 2→1`
  2. stdin常時capture撤去（旧`[ -z "$TARGET" ]`分岐へ戻す）
  3. parse-unknown block撤去
  4. **`[ ! -t 0 ]`ガードを追加してTTY時にstdin評価をスキップさせる**（R-027）
  5. **stdin file_path抽出を`[ -z "$TARGET" ] &&`でenv-gatedに戻す**（stdin captureは常時のまま残す変異。R-028）
  6. **`parsed-safe`のtool集合から`MultiEdit`を除去する**（除去すると MultiEdit が parse-unknown 扱いになり、通常ファイルへの MultiEdit が rc=2 で全 block される。m-1）
  7. **top-level `.file_path` の legacy fallback を除去する**（m-1）
- **kill判定は`PG_T25_GUARD`をmutantへoverrideしたうえで、実TC（T1023-TC-01 / 03 / 05 / 13c-file / 23 / 22a / 02b）そのものがFAILすることで行う**。mutation script内のインラインassertのFAILをkillと申告してはならない（R-029 / #874既往）。
- **新規追加TCにも検出力の実証を課す**（m-1）。変異 6 / 7 は、自分が追加した TC-22a / TC-02b が
  「その変異を検出する」ことを示すために置く。**変異が対応しない新規TCを残さない**
  （R-029 で major とした基準を、自分が追加したTCにも同じく適用する）。
- token read、normal write、明示bypass、Human CLI文字列が通ることを確認する。
- non-TTY CLIは`mktemp -d`内へbinと最小TASKを複製して実行し、実repoのtracked/ignored audit artifactのbefore/after不変を確認する。
- rollback: verification artifactのみなら削除せずstatusへ失敗として記録し、修正はTask 1/2へ戻す。

### Task 4: Full verification and audit handoff

- `sh -n`、TA-25、full suite、diff scopeを確認する。
- git履歴/all refsを含む**既存approval artifact全体**（起点はリポジトリ初出＝実測`2026-04-27`）とdecision/RunEvidenceをread-onlyで列挙し、actor/provenance、plan hash、source SHA、後続変更、利用停止/再承認基準をhandoffへ記録する。**`2026-06-02`を起点にしない**（R-030）。
- 母集団は**保護状態で3区分**して列挙する。区分ごとに信頼度と再承認要否の判断材料が異なる。

  | 区分 | 期間 | 保護状態 |
  |---|---|---|
  | (a) ガード不在期間 | 〜2026-06-01 | ガードのファイル自体が存在しない |
  | (b) ガード存在・配線不在期間 | 2026-06-02（`a7c3805f`）〜06-11 | ファイルはあるがsettingsへ未配線で一度も発火しない |
  | (c) 配線済み・3欠陥で無効な期間 | 2026-06-12（`82137332`）〜本PBI修正まで | 配線済みだがexit 1 / env時stdin bypass / parse fail-openで実効ゼロ |

- **件数は契約値にしない**。`docs/working/**/approvals/` は運用で承認のたびに増える成長ディレクトリであり、
  絶対件数をACやplanの契約に固定すると**本PBIと無関係なPRがACを壊す**。件数は監査実施時に下記コマンドで
  導出し、**集計単位を必ず併記**する。

  ```sh
  # (1) 追加イベント数（commit×file 単位・同一 path が複数 ref で再出現するとその都度カウント）
  git log --all --diff-filter=A --format='C %ad' --date=short --name-only -- '*/approvals/*.json'
  # (2) distinct path 数（path ごとに初出日で 1 回だけカウント）… (1) の出力を path で uniq する
  ```

  | 測定 | 集計単位 | 値 | 測定日 |
  |---|---|---|---|
  | 本PBI（スナップショット）| 追加イベント | 163（`< 2026-06-02` 132 / `>=` 31）| 2026-08-10 / base `fac3445` |
  | 本PBI（スナップショット）| distinct path 初出 | 88（66 / 22）| 同上 |
  | オーガナイザー（参考）| `--format='%ad'` のみ・name-only無し | 153（`< 2026-06-02` 126）| 2026-08-10 |
  | C-2 レビュー本文（参考）| 不明 | 約 120（`< 2026-06-02`）| 2026-08-10 |

  > ⚠️ **同日に 3 者で数値が一致していない**。原因は**集計単位の差**（commit 単位 / commit×file 単位 /
  > distinct path 単位）と ref 範囲の差であり、母集団の実体が動いたわけではない。次に測る人は
  > **どの単位で数えたかを必ず明記する**こと。上表はいずれも**測定時点のスナップショットで契約値ではない**。

  - **起点変更の根拠は時間不変の性質に置く**: `< 2026-06-02` は **ガードのファイルが存在せず保護が 0 だった期間**であり、
    そこで作られた承認 artifact は hook の表示を根拠に真正とみなせない。**保護が 0 だった期間を監査対象から外すのは
    目的（どの承認 artifact を信頼してよいか）に対して逆**である。これは件数にも比率にも依存しない。
  - （参考・2026-08-10 時点のスナップショット）当時の分布では distinct 88 件中 66 件が `< 2026-06-02` に集中していた。
    **この比率は今後の承認追加により単調に低下する**（新規はすべて `>= 2026-06-02` 側に入る）ため、
    **比率を根拠や契約に使わない**。件数を AC から外したのと同じ理由である。
  - 起点の決め方（なぜ「ファイル誕生日」ではなく母集団全体か）を**根拠付きでhandoffに残す**。
- **`$1` fallbackが実行時 dead code である事実をhandoffに明記する**（R-031）。`.claude/settings.example.json:72,81` の`check-approval-token-write.sh`呼出はいずれも**引数なし**で、契約 `docs/ai/settings-wiring-contract.md:157` との drift は本PBIでは解消せず **#928 に残存**する。AC-06 の `$1` 経路は実装後も TC だけが緑になる。
- rollback: 文書は履歴を消さずaddendumで訂正する。

## Verification Plan

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence保存先 |
|---|---|---|---|
| Syntax | `sh -n scripts/check-approval-token-write.sh tests/extras/ta-25-approval-token-guard.sh` | exit 0 | `evidence/test-runs/syntax.log` |
| Focused | `sh tests/run-tests.sh`のTA-25区間およびstandalone helper | AC-01〜07、AC-10 PASS | `evidence/test-runs/ta-25.log` |
| Mutation | anchor置換数=1、mutant syntax PASS、`PG_T25_GUARD` overrideで**実TC**のみFAIL、復元PASS | **7 mutant kill**（R-027 / R-028 / R-029 / m-1）| `evidence/test-runs/mutation.log` |
| TTY | stdinを疑似端末（`script` 等）にしたinvocationを**timeout付き**で実行 | rc=2 かつ timeout到達せず（非ハング）| `evidence/test-runs/tty.log` |
| MultiEdit（script レベル）| `tool_name=MultiEdit` の正（通常file）・負（token path）payload を hook へ直接 pipe | 正 rc=0 / 負 rc=2 | `evidence/test-runs/multiedit.log` |
| **MultiEdit 到達性（配線レベル / R-034・G-9）**| **configured Claude Code で実際に `MultiEdit` を発行し、hook が発火するかを実測**する。現行 matcher は `Edit\|Write` と `Bash` の 2 本のみで、`Edit\|Write` が `MultiEdit` にマッチするか（部分一致か完全一致か）は**リポジトリ内に決定的 artifact が無い**ため実測でしか確定しない | **到達する / 到達しない のいずれかを証跡付きで確定**し、G-9 の (i)/(ii) 分岐へ入力する | `evidence/e2e/multiedit-reachability.md` |
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

## C-2 追記 2（PR #1024 敵対的レビュー）の反映

> 集約先: [`review-external.md`](./review-external.md) 「追記 2」（R-026〜R-034）。
> PR #1024 は merge 済みだがレビュー着弾が merge の 13 秒後だったため、
> **実装未着手のうちに本 plan へ 1 回確定反映**した。

| R-NNN | 反映箇所 |
|---|---|
| R-026（MultiEdit）| Global Constraints の `parsed-safe` 定義 / Input Decision Table 2 行 / Task 1・2 / Verification Plan |
| R-027（TTY・stdin不在）| Global Constraints / Input Decision Table 2 行 / Task 1（legacy stdin 明示）/ Task 2 / mutation 4 / Verification Plan |
| R-028（stdin の env 再従属）| Task 2 / mutation 5 / test-cases の TC-13c 分割 |
| R-029（mutation が実 TC を kill しない）| Task 1（`PG_T25_GUARD` override）/ Task 3（kill 判定の定義）|
| R-030（監査母集団の起点）| Task 4（3 区分 + 実測値）|
| R-031（`$1` dead code）| Task 4 / AC-06 |
| R-032（TC-02 の payload 同居）| test-cases の TC-02a / 02b 分割 |
| R-033（EH-10 ID 衝突）| **未確定。下記「Human C-3 の判断事項」G-6** |
| R-034（closure 表現）| 下記「security closure の否定宣言」/ AC-11 |

### 追加是正（独立 river-review / 2026-08-10）

| ID | 指摘 | 反映箇所 |
|---|---|---|
| M-1 | **MultiEdit は現行 matcher に配線されていないのに closure を 4 surface と宣言していた** | 否定宣言を到達性依存の分岐へ書き換え / Verification Plan に到達性実測を追加 / G-9 新設 / HO 境界の非対称性を明記 |
| M-2 | **R-030 の反映が AC 文言止まりで TC-19 に届いていない**（旧起点で inventory を作っても TC-19 が PASS する）| test-cases の TC-19 期待結果に起点・3 区分・集計単位併記を追加 |
| M-3 | **`MultiEdit` の `edits[]` path field が未特定**で、実装が「空振り」か「過剰 block」の二択になる | `edits[]` 評価を落とし `tool_input.file_path` のみに限定 / TC-22b(ii) 削除 / 誤 block 方向の負 TC を追加 |
| m-1 | 新規 TC のうち mutation で検出力が実証されるものが 0 件だった | 変異 6（MultiEdit 除去 → TC-22a）/ 変異 7（top-level fallback 除去 → TC-02b）を追加し 7 種へ |
| m-2 | G-7 の副作用を TTY 限定と過小評価。既存 bypass が選択肢に無い | 論点を「stdin 未供給の手実行全般」へ / 選択肢 (c)（既存 `PLANGATE_SKIP_TOKEN_GUARD=1` の文書化のみ）を追加 |
| m-3 | Decision Table の TTY 行の非ハング根拠が誤り | 「`[ -t 0 ]` を read より前に置くため」へ訂正 |
| m-4 | 「7 割以上が集中」は時間とともに崩れる主張 | 根拠を「起点より前は保護が 0 だった」という時間不変の性質へ置換。比率は参考スナップショット扱い |
| i-1 | `AC-33` は `R-033` のタイポ / 既存行の EH-10 前提が G-6 と矛盾 / 更新時刻が記述対象より前・UTC→JST 混在 | pbi-input・INDEX・current-state を訂正 |

### security closure の否定宣言（R-034）

本 PBI が閉じるのは **configured Claude Code の PreToolUse に実際に配線された surface のみ**である。

**現行配線は `Edit|Write` と `Bash` の 2 matcher しかない**（実測: `.claude/settings.example.json:68,78` /
契約 `docs/ai/settings-wiring-contract.md` §EH-10 も「`PreToolUse(Edit|Write)` に配線する」と規定）。
したがって **`MultiEdit` が hook に到達するかは未確定**であり、到達性を実測するまで
「MultiEdit を閉じた」とは主張しない（V-2 到達性実測 → 下記の分岐で確定）。

- **到達する場合**（matcher が部分一致で `Edit|Write` が `MultiEdit` にマッチする、
  またはローカル settings が `Edit|Write|MultiEdit` へ拡張済み）
  → closure は `Edit` / `Write` / `MultiEdit` / `Bash` の 4 surface。
- **到達しない場合** → closure は `Edit` / `Write` / `Bash` の **3 surface**。
  `MultiEdit` は**否定宣言側（下記の閉じない一覧）へ移す**。

以下は（到達性の結果によらず）**閉じない**:

- `NotebookEdit` およびその他の built-in write tool
- MCP 由来の write tool（`mcp__*`）
- Codex CLI 経路（`.codex/hooks.json` に EH-10 相当のエントリが無く、`eh-bridge.sh` は
  `$REPO_ROOT/scripts/hooks/$HOOK_NAME` しか解決しないため、`scripts/` 直下の本ガードは
  **構造的に到達不能**）
- `PLANGATE_SKIP_TOKEN_GUARD=1` の発行元検証（AI が env を付ければ全スキップ可能）

したがって AC-11 の E2E 取得をもって「承認境界が閉じた」とは主張しない。
残存は #928 の残存 P0 として扱う。

### Human C-3 の判断事項（AI が決めない）

| ID | 論点 | 選択肢 | 備考 |
|---|---|---|---|
| **G-6** | `EH-10` の採番が正本間で衝突している。`docs/ai/settings-wiring-contract.md:152` は EH-10 = 承認トークンガード、`docs/ai/hook-enforcement.md:10-18` は EH-10 / EH-11 を #760 / #762 用に**予約済み**として EH-12 を採番、`.claude/settings.example.json:98` も別 hook に「EH-10 候補」と付けている | (a) EH-10 = 本ガードで確定し `hook-enforcement.md` 側を是正 / (b) #760 側の予約を優先し本ガードへ別番号を採番 / (c) 本 PBI では確定せず handoff に衝突として記録し別 PBI へ分離 | **正本間の矛盾**であり AI は正本を書き換えない |
| **G-7** | **stdin を供給しない手実行が一律 `exit 2` になる**（TTY 限定ではない）。AC-03 は **stdin 空も parse-unknown → exit 2** と規定するため、`< /dev/null` でも block される。つまり「**valid な PreToolUse JSON を pipe しない限り、手実行は常に exit 2**」 | (a) 承認境界では可用性より fail-closed を優先し許容（本 plan の既定）/ **(c) 既存の `PLANGATE_SKIP_TOKEN_GUARD=1`（`scripts/check-approval-token-write.sh:16`）を診断・手実行時の escape hatch として文書化するだけに留める（追加実装ゼロ）** / (b) 手実行用の opt-in を新設する | R-027 の副作用。**(c) が最小コスト**。ただし (c) は「bypass の発行元が検証されない」既知ギャップ（否定宣言の 4 番目）を運用に晒すため Human 判断 |
| **G-8** | `parsed-safe` の許容 tool 集合をどこまで正本から導出するか | (a) `Edit` / `Write` / `MultiEdit` / `Bash` の固定 4 種（本 plan の既定。**script が受け付ける集合**であって配線とは別問題）/ (b) `settings.example.json` の matcher と `apply-claude-settings.sh` の `matcher_covers()` 包含規則から機械導出 | (b) は Out of Scope の settings 依存が増える |
| **G-9** | **MultiEdit 到達性の実測結果を受けた分岐**（V-2 で実測）。到達しない場合 | (i) AC-11 / TC-21 / T-09 から MultiEdit を外し **R-034 の否定宣言側へ移す**（settings 不変・本 PBI 内で完結）/ (ii) **settings patch を提示**して MultiEdit を配線対象に加える（**適用は Human-owned**） | (ii) を選ぶ場合、契約 `docs/ai/settings-wiring-contract.md` §EH-10 の `PreToolUse(Edit\|Write)` 記述も追随が要る。**採番（G-6）とセットで判断**すること |

> **HO 境界の非対称性（重要）**:
> `.claude/settings*.json` は **Hardening Override 9 カテゴリに含まれる**ため
> **適用は Human-owned**（AI は patch 提示のみ）。一方
> **`docs/ai/settings-wiring-contract.md` は HO 9 カテゴリ外**
> （`.claude/rules/*.md` / `.claude/settings*` / `.claude/commands` / `.claude/agents` /
> `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` / `.github/workflows` /
> `AGENTS.md`・`CLAUDE.md` のいずれにも該当しない）ため、**契約文書 §EH-10 の追随は AI が書ける**。
> Human-owned なのは **settings 実体だけ**である。
>
> **本 PBI のスコープ宣言**: 契約文書 §EH-10 の書き換えは **本反映では行わない**（Out of Scope）。
> 理由は §EH-10 の記述が **G-6（EH-10 の採番）と G-9(ii)（配線対象）の両方に依存**し、
> 先に書くと未決の Human 判断を AI が先取りすることになるため。
> **G-6 / G-9 が決まった時点で、契約文書の追随は本 PBI 内で AI が実施できる**（HO 外のため）。

### 承認状態への影響（重要）

**TASK-1023 は未承認である**。`docs/working/TASK-1023/approvals/` は
**tracked にも worktree にも存在せず**、`git log --all -- 'docs/working/TASK-1023/approvals/*'`
も 0 件（2026-08-10 実測 / base `fac3445`）。したがって exec 着手に必要なのは
**c3.json の「初回発行」**（再発行ではない）。

`24fcdf9f…` は **C-1 / C-2 と PR #1024 本文に記載された plan hash** であって、
**承認トークンに刻まれた hash ではない**。本反映で plan.md が変わったため、
Human C-3 は **確定後の plan_hash** に対して初回発行する。AI は承認トークンを作成しない。

> なお issue #1023 の進捗コメントには「別 worktree に untracked の `c3.json` が存在する」
> という記述があるが、**本 worktree からは検証できず、git 履歴上も痕跡が無い**。
> もし当該ファイルが存在する場合でも、それは反映前 plan（`24fcdf9f…`）に対するもので
> **本 plan には使えない**（EH-3 が plan_hash mismatch を検知する）。実体の有無の確認は Human 側で行う。

## Mode判定

**モード**: `critical` / `lite_eligible=false`

- 実装2ファイルでもP0 Minimum Trust Kernel、承認境界、既存承認監査を扱うため安全側にcriticalへ引き上げる
- 受入基準11件、security impact極高、C-3'利用不可
- Human C-3、V-2/V-3/V-4、Hook E2E、Human C-4を必須とする
