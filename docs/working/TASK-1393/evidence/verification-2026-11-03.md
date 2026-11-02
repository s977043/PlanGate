# TASK-1393 局所検証と次の実装条件（2026-11-03）

## Scope / verdict

基準は `s977043/PlanGate@0d8d9468b815ed7068b31b1a5742667d745ad202`。
本記録は非権威の検証Evidenceであり、承認・独立レビュー・Delivery完成の宣言ではない。
Production code、approved Plan、todo、test-cases、approvals、canon、CI設定は変更していない。
**Delivery First ReleaseはBLOCKEDのまま。**

GitHub connectorでmain・open PR・#1623・AGENTS/Core Contract・対象ファイルを読んだ。
ローカルcloneは`Could not resolve host: github.com`で失敗した。
Claude/Codex CLIおよびAgent/Task起動手段を利用できず、Core Contract §5-bisのdirect modeを使う。
今回のレビューはすべて同一assistantのI0であり、I1/I3/I4や5人の独立評価ではない。

## Source identity / limitations

取得内容を局所コピーへ保存し、Git blob SHA1（`blob <byte-length>\0<bytes>`）を実行前後に照合した。

| ファイル | Git blob SHA1 |
|---|---|
| `scripts/ai-loop-v2/limits.py` | `9a385b5579fe098322013595b8baa98ecb707fbe` |
| `scripts/ai-loop-v2/test_limits.py` | `45c0bc58a19bcda7e3124e79bb618974f2a5ad3d` |
| `tests/extras/ta-118-ai-loop-v2-limits.sh` | `9c4a65f69b6f09cf8302dd4f1eacfa806a0373e1` |
| `tests/extras/_extra-contract.sh` | `f120333f3499efe5cf97d946ab0c19a59a685738` |

これは4ファイルだけのsnapshotであり、完全なcheckoutではない。
`test_limits.py`のglobによるsibling列挙も局所コピーの範囲に限られる。
別途ASTで`limits.py`の実際のimportが`__future__`のみであることを確認したが、全moduleの回帰検証とは主張しない。
`tests/run-tests.sh`、Delivery/Ratchetの全suite、owner-backed E2E、I3/I4レビュー、live-shadow収集は未実行。全体CIのローカル再実行も未実行。
TA-118のharness modeは小さなshimでcounterの挙動だけを確認し、全Test workflowとは区別した。

実行環境: Linux / Python 3.13.5。実行終了: 2026-11-02T16:39:12Z（2026-11-03 JST）。
全22コマンドの終了コードは下表。完全stdoutと再現runnerは会話添付の検証bundleに保存した（Git管理対象外）。

## 5ラウンド（検証・I0レビュー・記録修正・再確認）

runtime実装の5サイクルではなく、着手可能な局所検証と引継ぎ整合の5ラウンド。

| Round | 検証 | レビューで判明した点 | 是正 / 再確認 |
|---|---|---|---|
| R1 | 元blobの照合、単体5件 | partial snapshotの成功は全体PASSではない | 検証範囲・sibling列挙の制約を明記し単体を再実行 |
| R2 | TA-118、force-fail probe | wrapper経由でも失敗が伝播することの確認が必要 | probeでexit 1、通常実行へ戻すとexit 0を確認 |
| R3 | 定数変更3種＋byte定数追加3種 | byte不在検査は現在のscope固定であり、#1623では更新が必要 | 全6種がAssertionErrorで検出、各回の復元後PASS。計画に検査移行を追記 |
| R4 | helper欠落・誤interpreter・harness shim | current-stateのRevision 2.6表示がINDEXのexec表示と不一致 | Current欄を同期。歴史記録・Plan・承認artifactは変更しない |
| R5 | 元blob再照合・TA再実行、候補diffのscopeレビュー | 自己レビュー・旧main CIを新PRの独立承認へ流用できない | 未実行を明記し、exact-head CI/独立レビュー/C-4を別のmerge条件として残す |

変異は各回の使い捨てコピーにだけ適用し、元snapshot・リポジトリには適用していない。
6種はいずれも`AssertionError`を確認した。import失敗を検出力と誤認していない。
静的import検査がdynamic importを網羅しない既存の残存脅威は、解消済みと扱わない。

## 実行結果

単体suiteは5件。TA-118 standaloneは`1 passed, 0 failed`。
22コマンドで期待exit codeと実測が一致した。正常系だけでなく、意図したexit 1/2を含む。

| 検査 | 期待exit | 実測exit |
|---|---|---|
| R1-original-unit-suite | 0 | 0 |
| R1-after-scope-review | 0 | 0 |
| R2-original-TA118 | 0 | 0 |
| R2-wrapper-force-fail | 1 | 1 |
| R2-after-probe-restoration | 0 | 0 |
| R3-mutant-input-count | 1 | 1 |
| R3-restored-input-count | 0 | 0 |
| R3-mutant-required-verifiers | 1 | 1 |
| R3-restored-required-verifiers | 0 | 0 |
| R3-mutant-ref-length | 1 | 1 |
| R3-restored-ref-length | 0 | 0 |
| R3-mutant-byte-limit | 1 | 1 |
| R3-restored-byte-limit | 0 | 0 |
| R3-mutant-fixed-overhead | 1 | 1 |
| R3-restored-fixed-overhead | 0 | 0 |
| R3-mutant-envelope-overhead | 1 | 1 |
| R3-restored-envelope-overhead | 0 | 0 |
| R4-missing-helper | 1 | 1 |
| R4-wrong-interpreter | 2 | 2 |
| R4-after-negative-checks | 0 | 0 |
| R4-harness-mode-shim-not-full-suite | 0 | 0 |
| R5-final-TA118 | 0 | 0 |

## 再現手順

完全な作業環境では、まず上記commitまたは各blobの一致を確認する。
局所再現の入口は次の2つ。全体回帰は最後の別コマンドで確認する（今回は未実行）。

```sh
PYTHONDONTWRITEBYTECODE=1 python3 scripts/ai-loop-v2/test_limits.py -v
PYTHONDONTWRITEBYTECODE=1 sh tests/extras/ta-118-ai-loop-v2-limits.sh
# 完全checkoutで別途必要。今回の局所実測には含めない。
sh tests/run-tests.sh
```

force-fail probeはテスト専用であり、Production hookの迂回ではない。

```sh
PG_EXTRA_CONTRACT_PROBE=force-fail \
PG_EXTRA_CONTRACT_TARGET=ta-118-ai-loop-v2-limits \
PYTHONDONTWRITEBYTECODE=1 \
sh tests/extras/ta-118-ai-loop-v2-limits.sh
# 期待: probe発火を表示し、exit 1。
```

変異表: `MAX_INPUT_REFS=0`、`MAX_REQUIRED_VERIFIERS=0`、`MAX_REF_CHARS=72`、
`MAX_DECISION_EVENT_BYTES=1`追加、`DECISION_FIXED_OVERHEAD=1`追加、`ENVELOPE_OVERHEAD=1`追加。
各変異を独立した使い捨てコピーへ1種類ずつ適用しTA-118を実行する。期待exitは1、AssertionErrorが必要。
元の`limits.py` bytesへ復元してTA-118を実行し、exit 0と元blob一致を確認する。

## 次の実行単位（既存ownerを維持）

| 順序 | 対象 | 実行内容 | 完了根拠 / 停止条件 |
|---|---|---|---|
| S0 | #1391/#1392/#1393 | C-3実物とPlanを照合、base SHAと必要preflightを固定 | 記録だけで実行しない。不一致はHumanへ |
| S1 | #1391/#1623 | Event構造・各可変fieldの上限・serializerを先に固定 | 構造確定とruntime完成を混同せず相互待ちを解く。scope変更は承認対象 |
| S2 | #1623 | 最大Eventからbyte定数を導出、既存のbyte不在検査を適切に移行 | 上限超過拒否とterminal reserveまでowner別に検証。#1393のC-3を流用しない |
| S3 | #1391 | Phase 1BのEvent/binding/projection契約をRED/GREEN | 下流必要subsetがconsumable。formal Schema等を追加しない |
| S4A/B | #1392/#1393 | Model B CASと純関数Decisionを契約固定後に並行実装 | 同一runtime_rootのCAS、crash/回復、FAIL優先、全caller移行 |
| S5 | #1395 | stimulusとoracleを分離して正式ownerを統合 | outcome/no_progress/scope_okを入力しない。budget・共通lock domainを確認 |
| S5b | #1391 D-12 | producer成立後にEV-28b/EV-28fを有効化 | 既存決定どおりPlan差分・再C-3が必要。無言でGateを変えない |
| S6 | #1383 | 修復収束とNO_PROGRESS停止の2経路を実証 | exact-head CI、必要I3/I4、Evidence bundle。#870全体は閉じない |
| S7 | #1381 | 実VerifierからDecisionまでのAC-6を実証 | known-bad停止と正常negative control。simulationを昇格しない |

#1329は対象差分のpreflightを実施する。全Issueのcloseを直列の前提に増やさない。
#1465の実live-shadow、#1468/#1473の外部attestationは別トラックであり、今回の局所PASSでは前進扱いにしない。

## Review / merge handoff

自己レビュー結果はscope限定でPASS、全体Delivery判定はBLOCKED。
本PRのexact-head CI、独立レビュー、必要なHuman C-4は別途確認する。
同一assistantの5ラウンドを独立レビューの代替にしない。

出典は同じbaseの`INDEX.md`、`plan.md`、`status.md`、#1395、#1623、#1329と上記4ファイル。
Currentの同期はprojectionのみで、Plan hashや承認artifactを変更しない。
