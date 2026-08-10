# PBI INPUT PACKAGE — TASK-1023

> 対象 issue: [#1023](https://github.com/s977043/PlanGate/issues/1023)（P0 / bug / governance）
> 基点: `origin/main` = `9f9af9451e396eec52b7a737ac3db3166ff60fb1`（2026-08-09 再確認）

## Context / Why

`scripts/check-approval-token-write.sh` は、AI が `approvals/c3.json` や
`maintenance.json` を直接書いて Human-owned の承認境界を自己発行することを防ぐ
PreToolUse hook である。しかし、現在の main では次の 2 経路が実測で成立する。

1. 検出時の終了コードが `1` で、Claude Code の PreToolUse 契約上はツール実行を
   block しない。
2. `PLANGATE_HOOK_FILE` が設定されると stdin を読まないため、env が通常ファイルを
   指していて stdin の Bash command が承認 artifact を書く場合に `rc=0` で通る。

導入履歴では、ガード本体は `a7c3805f`（2026-06-02）で追加され、stdin/env 分岐と
`exit 1` は遅くとも `82137332`（2026-06-12）から存在する。したがって、その期間の
承認 artifact は hook の表示だけを根拠に真正とみなせない。

## What（Scope）

### In scope

- block時の終了コードを Claude Code PreToolUse の blocking contract に合わせて `2` にする
- `PLANGATE_HOOK_FILE` の有無にかかわらず stdin を一度だけ読み、envとstdinの両方を検査する
- jq不在・JSON parse不能・stdin空/読取不能を `parse-unknown` とし、安全側にblockする
- 正本契約どおり target path の位置引数 `$1` fallbackを維持する
- `apply_patch` / `patch` / Node / Perl / Ruby等の代表的write surfaceを追加hardeningする
- Edit/WriteとBashの正・負・回避テストを `ta-25-approval-token-guard.sh` に追加する
- 旧実装の2欠陥を戻すとテストが落ちる mutation verification を固定する
- 影響期間と既存承認artifactの監査手順をhandoff/statusに残す

### Out of scope

- `.claude/settings.json` / ruleset の変更（#928）
- `gh pr review --approve` / merge command の防止（#928）
- 承認artifactの署名方式・schema変更
- token path patternの全面再設計
- 過去artifactの削除・書き換え・一括無効化
- C-3'自動承認運用の再開判断

## 受入基準

- [ ] **AC-01**: envまたはstdinのEdit/Write/**MultiEdit** targetがtoken pathなら、hookは診断をstderrへ出し`exit 2`で終了する。MultiEditは`tool_input.file_path`と`tool_input.edits[]`の双方を評価する（R-026）
- [ ] **AC-02**: `PLANGATE_HOOK_FILE`が通常pathを指していても、stdin Bash commandがtoken pathへ書く場合は`exit 2`になる
- [ ] **AC-03**: jq不在、malformed/truncated JSON、stdin空/読取不能、**stdinがTTY / stdin不在**は診断付き`exit 2`となり、parse-unknownをfail-openにしない。**TTY時はstdinをreadせず即終了しハングしない**（`[ ! -t 0 ]`でのスキップは禁止 / R-027）
- [ ] **AC-04**: jq利用可能なparsed-safe経路では、token artifactのread-only command、通常ファイル操作（**`MultiEdit`での通常ファイル編集を含む**）、正規Human CLI呼出文字列は誤blockしない。token pathと別writeを混在させたcommandは安全側blockを仕様とする
- [ ] **AC-05**: Edit/Write/Bashの空白・複数行・`./`・quoteに加え、`apply_patch` / `patch` / Node / Perl / Rubyの代表write形がblockされる。ただしshell文字列matcherによる包括防止は本ACで主張しない
- [ ] **AC-06**: target pathはenv→`$1`の優先順で取得しつつstdinを独立評価する（**stdin file_pathの抽出をenvの有無でgateしない** / R-028）。なお`$1` fallbackは現行の実配線（`.claude/settings.example.json:72,81` は引数なし）に接続されないため**実行時dead code**であり、契約`docs/ai/settings-wiring-contract.md:157`とのdriftは#928に残存する（R-031）。`PLANGATE_SKIP_TOKEN_GUARD=1`はHuman-owned emergency/test-onlyとして診断され、通常testでは明示`0`に固定される
- [ ] **AC-07**: `exit 2→1`、stdin常時読取の撤去、parse-unknown blockの撤去、**`[ ! -t 0 ]`ガードの追加**、**stdin file_path抽出のenv-gated化**の**5 mutation**それぞれで、`PG_T25_GUARD` overrideのもと**実TCが少なくとも1件FAIL**する（mutation script内のインラインassertのFAILはkillと認めない / R-027・R-028・R-029）
- [ ] **AC-08**: `sh -n`、TA-25単体、`sh tests/run-tests.sh`が0 failedで完了する
- [ ] **AC-09**: git履歴・全refを含め、**既存`c3.json` / `maintenance.json` / C-3' decision/RunEvidenceの母集団全体**（起点はリポジトリ初出＝実測`2026-04-27`。**`2026-06-02`起点にしない**）を対象にしたread-only監査手順、provenance不明時の利用停止・再Human C-3基準が記録される。母集団は (a) ガード不在期間（〜06-01 / distinct 66 件）(b) ガード存在・配線不在期間（06-02〜06-11）(c) 配線済みだが3欠陥で無効な期間（06-12〜）の**3区分**で列挙し、起点の決め方の根拠をhandoffに残す（R-030）
- [ ] **AC-10**: TA-25既存TASK-0123 TC-01〜07/HMAC回帰を保持し、新規testは`T1023-TC-*`で分離する。standalone実行はFAIL表示時に非0を返し、harness source時は親processをexitしない
- [ ] **AC-11**: 実Claude Code PreToolUseでEdit/Write/**MultiEdit**/Bashが`exit 2`により非実行となりartifactが不変である証跡をMERGE_READY前に取得する。未取得ならBLOCKEDのままにする。**本ACはこの4 surfaceのみを証明対象とし、`NotebookEdit` / MCP系write tool / Codex経路（`.codex/hooks.json`未配線・`eh-bridge.sh`が`scripts/hooks/`しか解決しないため構造的に到達不能）/ `PLANGATE_SKIP_TOKEN_GUARD`の発行元検証は対象外**である。したがって本AC充足をもって「承認境界のsecurity closure」とは主張しない（R-034）

## Notes from Refinement

- 本変更自体が承認境界を変更するため、C-3'を使わずHuman C-3を必須とする。
- #1023がHuman C-4後にmainへ入るまで、既存の`AUTO_APPROVED`を新規実装の承認根拠にしない。
- jq不在時のraw grep fallbackはJSON escapeを安全に扱えないため採用しない。parse不能は安全側blockする。
- 本Issueは既知のexit/env/stdin/parse欠陥と代表write surfaceを塞ぐtactical fixであり、shell文字列matcherによる包括的な自己承認防止を完了とは扱わない。#928の多層防御完了までC-3'を再開しない。
- `PLANGATE_SKIP_TOKEN_GUARD=1`はHuman-owned emergency/test-only。利用理由・期間を記録し、C-3'運用では禁止する。
- #928 AC-1/AC-2のsettings wiring対象へEH-10を追加する追記を行い、Codex配線・間接実行の多層防御も残存P0として同Issueへ移管する。#1023 mergeだけではC-3'を再開せず、#928完了後に別Human判断を要する。
- テストは実リポジトリの承認artifactを作成せず、stdin文字列と`mktemp -d`内のscript複製のみを使う。
- 2026-08-10: PR #1024（Plan Package）は merge 済みだが、敵対的レビューの着弾が merge の
  13 秒後だったため **major 5 / minor 3 / info 1 が未反映のまま main に入った**。実装未着手の
  うちに `review-external.md`「追記 2」（R-026〜R-034）へ集約し、AC-01 / 03 / 04 / 06 / 07 /
  09 / 11 を 1 回確定反映した。**AC-33 相当の `EH-10` 採番衝突は AI が決めず Human C-3 判断
  （plan.md「Human C-3 の判断事項」G-6）へ回す**。
- 本反映で plan.md が変わるため、既発行 `approvals/c3.json`（plan `24fcdf9f…`）は **stale**。
  exec には確定後 plan_hash に対する **c3.json 再発行（Human-owned）** が必要。

## Estimation Evidence

### Risks

- false negativeはAI自己承認を許すため重大。
- false positiveは通常のEdit/Write/Bashを停止させるため、同一境界を通る負側テストが必要。
- malformed入力の安全側blockは一部CLI手動実行を止めうるが、承認境界では可用性よりfail-closedを優先する。

### Unknowns

- 既存承認artifact監査の結果。コード修正PRではread-only棚卸し手順までを確定し、artifactの無効化判断はHumanが行う。

### Assumptions

- Claude Code PreToolUseでは`exit 2`がblock、`exit 1`はnon-blocking errorである。
- `scripts/check-approval-token-write.sh`はHardening Overrideの列挙path外だが、意味上の承認境界なので最低high-riskを適用する。
- tracked `.claude/settings.json`はなく、Codex EH-10は未配線である。本Issue単独の適用範囲はconfigured Claude Code EH-10に限定される。
