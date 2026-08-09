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
- jq不在時も承認 artifact への書き込みを fail-open にしない保守的fallbackを実装する
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

- [ ] **AC-01**: envまたはstdinのEdit/Write targetがtoken pathなら、hookは診断をstderrへ出し`exit 2`で終了する
- [ ] **AC-02**: `PLANGATE_HOOK_FILE`が通常pathを指していても、stdin Bash commandがtoken pathへ書く場合は`exit 2`になる
- [ ] **AC-03**: jqがPATH上に存在しない環境でもAC-01/AC-02の代表入力が`exit 2`になり、通常ファイルのEdit/Writeは`exit 0`になる
- [ ] **AC-04**: token artifactの読み取り、通常ファイルへの書き込み、正規Human CLIの呼出文字列は誤blockしない
- [ ] **AC-05**: Edit/Write/Bashの空白・複数行・`./`・single/double quoteを含む代表的回避形がblockされる
- [ ] **AC-06**: `PLANGATE_SKIP_TOKEN_GUARD=1`の既存明示bypassは互換維持し、通常時には暗黙適用されない
- [ ] **AC-07**: `exit 2→1`、stdin常時読取の撤去、jq fallbackの撤去の各mutationで少なくとも1テストがFAILする
- [ ] **AC-08**: `sh -n`、TA-25単体、`sh tests/run-tests.sh`が0 failedで完了する
- [ ] **AC-09**: 2026-06-02以降の既存`c3.json` / `maintenance.json` / C-3' decision recordを対象にしたread-only監査手順と再承認基準が記録される

## Notes from Refinement

- 本変更自体が承認境界を変更するため、C-3'を使わずHuman C-3を必須とする。
- #1023がHuman C-4後にmainへ入るまで、既存の`AUTO_APPROVED`を新規実装の承認根拠にしない。
- fallbackは「jqなしだから通す」を禁止する。疑わしいtoken path + 書き込み意図を検出した場合は安全側にblockする。
- テストは実リポジトリの承認artifactを作成せず、stdin文字列と`mktemp -d`内のscript複製のみを使う。

## Estimation Evidence

### Risks

- false negativeはAI自己承認を許すため重大。
- false positiveは通常のEdit/Write/Bashを停止させるため、同一境界を通る負側テストが必要。
- raw JSON fallbackはjqより表現力が低いため、対応入力をテストで固定し、将来の完全JSON parser化は別PBIに分離する。

### Unknowns

- 既存承認artifact監査の結果。コード修正PRではread-only棚卸し手順までを確定し、artifactの無効化判断はHumanが行う。

### Assumptions

- Claude Code PreToolUseでは`exit 2`がblock、`exit 1`はnon-blocking errorである。
- `scripts/check-approval-token-write.sh`はHardening Overrideの列挙path外だが、意味上の承認境界なので最低high-riskを適用する。

