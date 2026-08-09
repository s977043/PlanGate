---
task_id: TASK-1023
artifact_type: plan
schema_version: 1
status: draft
mode: high-risk
related_issue: https://github.com/s977043/PlanGate/issues/1023
created_by: codex
---

# TASK-1023 Implementation Plan

## Goal

承認token書き込みガードがenv/stdin/jq有無の各経路で承認artifactへのAI直接書き込みを実際に停止し、正当な読み取りと通常ファイル操作を維持する。

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
- jq不在時の保守的raw-payload fallback
- TA-25の正・負・bypass・mutation coverage拡張
- 影響期間と既存artifact監査基準の記録

### Out of Scope

- settings/ruleset/merge guard、schema/署名、token path taxonomy全面改修
- 過去artifactのmutation、#928の実装、C-3'再開

## Global Constraints

- production codeはHuman C-3後にのみ編集する
- POSIX `sh`を維持し、新規依存を追加しない
- stdinは複数回読まず、command/file_path双方が同じpayloadを参照する
- envとstdinが競合する場合はどちらか一方でもtoken writeならblockする
- 明示bypass以外をfail-openにしない
- 通常ファイルとread-only commandの互換性を同一テスト境界で確認する
- 実承認artifactを作成・更新・削除しない

## 前提の実測検証

| 前提 | 検証コマンド | 実測結果 | 判定 |
|---|---|---|---|
| 最新main | `git rev-parse HEAD` / GitHub recent commits | `9f9af945...` | ✅ |
| exit 1欠陥 | token file_path payloadをhookへpipe | BLOCK表示、`rc=1` | ✅ |
| env時stdin bypass | env=`src/index.ts` + token Bash write payload | 出力なし、`rc=0` | ✅ |
| 正当なread | token pathへの`cat` payload | `rc=0` | ✅ |
| 影響開始 | `git log` / `git blame` | 追加`a7c3805f`、現分岐`82137332` | ✅ |

## Questions / Unknowns

- 既存artifactの真正性はコード差分だけでは確定しない。Humanが監査結果を見て再承認範囲を決める。

## Approach Comparison

| 案 | 内容 | メリット | デメリット | 判定 |
|---|---|---|---|---|
| A | envを優先しstdinはenv不在時のみ読む現設計の部分修正 | 差分最小 | Bash matcherが再びblindになる | 不採用 |
| B | stdinを常時captureし、env target・parsed file_path・parsed commandを独立評価 | 2欠陥を同じ境界で閉じる、既存helper再利用 | fallback設計が必要 | 採用 |
| C | Python等のJSON parserを必須依存にする | parser精度が高い | hookの可用性と配布互換性を下げる | 不採用 |

### Recommended Approach

案Bを採用する。`_stdin=$(cat ...)`をbypass判定後に一度だけ行い、jq利用可能時は構造化抽出、jq不在時はraw payloadからtoken pathと操作種別を保守的に評価する。env targetはstdin解析の代替ではなく追加シグナルとして扱う。既存の`_is_token_path`と`_has_write_intent`を維持し、修正範囲を入力取得・判定合成・終了コードに限定する。

## Files / Components to Touch

| ファイル | 操作 | 目的 |
|---|---|---|
| `scripts/check-approval-token-write.sh` | modify | stdin/env/fallback判定とblocking rc修正 |
| `tests/extras/ta-25-approval-token-guard.sh` | modify | 正負・回避・mutation test追加 |
| `docs/working/TASK-1023/**` | create/update | Plan/Gate/evidence/handoff |

## Work Breakdown

### Task 1: RED coverage

- `ta-25`へenv+stdin競合、Bash write、exit 2、jqなし、negative controlを追加する。
- pre-fix HEADで新規casesが期待どおりFAILする証跡を保存する。
- rollback: test commitのみを`git revert <sha>`。実装commitより先に戻さない。

### Task 2: Minimal boundary fix

- stdinを常時1回captureする。
- env targetとstdin file pathを独立評価する。
- stdin commandをenvの有無に関係なく評価する。
- `_block`を`exit 2`へ変更する。
- jqなしfallbackを追加する。
- rollback: 実装commitを`git revert <sha>`すると脆弱性が復活するため、緊急時はC-3'停止を維持したままHuman判断で実施する。

### Task 3: Mutation and compatibility verification

- `exit 2→1`、stdin常時capture撤去、fallback撤去をtmp複製へ注入し、各mutationがkillされることを確認する。
- token read、normal write、明示bypass、Human CLI文字列が通ることを確認する。
- rollback: verification artifactのみなら削除せずstatusへ失敗として記録し、修正はTask 1/2へ戻す。

### Task 4: Full verification and audit handoff

- `sh -n`、TA-25、full suite、diff scopeを確認する。
- 2026-06-02以降の既存approval artifactをread-onlyで列挙するコマンドと再承認基準をhandoffへ記録する。
- rollback: 文書は履歴を消さずaddendumで訂正する。

## Verification Plan

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence保存先 |
|---|---|---|---|
| Syntax | `sh -n scripts/check-approval-token-write.sh tests/extras/ta-25-approval-token-guard.sh` | exit 0 | `evidence/test-runs/syntax.log` |
| Focused | `sh tests/run-tests.sh`のTA-25区間およびstandalone helper | AC-01〜07 PASS | `evidence/test-runs/ta-25.log` |
| Mutation | tmp複製3種にsed mutation後、focused cases実行 | 各mutationで1件以上FAIL | `evidence/test-runs/mutation.log` |
| Full | `sh tests/run-tests.sh` | 0 failed / exit 0 | `evidence/test-runs/full-suite.log` |
| Audit | `find docs/working -path '*/approvals/*.json' ...`等のread-only棚卸し | 対象一覧と再承認判定が追跡可能 | `evidence/verification/approval-audit.md` |

### レビューレーン計画

| 成果物 | レーン | unavailable時の代替 |
|---|---|---|
| Plan Package | 設計妥当性 / コードベース整合の2独立レーン | C-2 unavailableを記録しHuman C-3で代替せず停止 |
| 実装diff | security boundary bypass review / compatibility review | Human C-4で未充足を明示しmergeしない |

## Stop Conditions

- Human C-3未承認、plan hash不一致、base SHA drift、scope外file変更、mutation survivor、focused/full test失敗、正当なHuman CLI経路の誤blockのいずれかで停止する。

## Replan Triggers

- 変更対象が実装2ファイル以外へ広がる
- jqなしfallbackがAC-03とAC-04を同時に満たせない
- Claude Code実セッションで`exit 2`でも書き込みが停止しない
- plan更新後にC-3 artifactのplan hashが一致しない

## Mode判定

**モード**: `high-risk` / `lite_eligible=false`

- 実装2ファイルだが承認境界周辺変更の例外ルールにより最低high-risk
- 受入基準9件、security impact高、C-3'利用不可
- Human C-3、V-2/V-3、Human C-4を必須とする

