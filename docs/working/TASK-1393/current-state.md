# TASK-1393 Current State

> 更新: 2026-11-03（main `0d8d9468b815ed7068b31b1a5742667d745ad202` を照合）
> 本ファイルは状態の投影であり、承認artifact・実行許可・独立レビューではない。

## フェーズ: exec

## 進捗

Plan の最新改訂は Revision 2.10。`INDEX.md` には C-3 APPROVED（2026-10-29T10:09:18Z、plan_hash `sha256:ed637f48…`）と記録されている。
`limits.py` の件数・文字数3定数は #1622、TA-118 のCI配線は #1624 でmainに入った。
**exec は定数部分のみ着手済みであり、Decision core本体・caller migration・owner-backed Delivery E2Eは未完了。**

C-3実物は承認worktreeのuntrackedファイルにあるとの記録で、今回のGitHub経由確認では取得・照合していない。
上記の記録だけを実行許可に使わず、着手環境で現行Planと実物を照合する。承認artifactはAIが新規発行・変更しない。

## 直近の完了タスク

- #1619: Planのref形式と文字数制限を改訂。現行PlanにはRevision 2.10までの履歴がある。
- #1622: `MAX_INPUT_REFS=256` / `MAX_REQUIRED_VERIFIERS=16` / `MAX_REF_CHARS=71` を葉moduleに配置。
- #1624: `test_limits.py` をTA-118から実行する配線を追加。
- #1626: INDEXへ実装着手と承認記録を反映。本更新は残っていたcurrent-stateの古いRevision 2.6表示を同期する。
- 今回: Git blob SHAを照合した4ファイルの局所コピーで単体5件とTA-118を実行。変異6種類をAssertionErrorで検出。全体CI／Delivery E2Eの代替ではない。

検証範囲・生ログ・制約: [2026-11-03 検証記録](evidence/verification-2026-11-03.md)。

## 現在のタスク

正式runtimeの着手前提と、#1623のbyte上限供給順序の整合。新しいGateや第二のDecision/Event storeは作らない。

## ブロッカーと解除条件

| 対象 | 残る条件 | Owner / 解除条件 |
|---|---|---|
| 承認実物 | 記録はあるが今回の環境からc3.jsonは未確認 | 実行環境で現行Planと実物を照合。不一致ならHumanへ |
| #1391 | Phase 1Bの必要契約、#1329 preflight、reviewed_at_sha | #1391。API・binding・語彙を機械検証しconsumableにする |
| #1392 | RunState入力形状・遷移契約 | #1392。契約が固定されれば#1393はCAS本体の完成を待たず並行実装可能 |
| #1422 | B-8/B-13等の語彙・適用時点とruntime実証の照合 | #1391/#1395。Plan承認だけでbinding invariantをPASS扱いしない |
| #1623 | byte系3定数・I-11 byte検査・terminal reserve | Event構造の固定→最大byte算出→各ownerへ接続。別follow-upの承認境界を確認 |
| #1393 | PF-1〜PF-8、records/progress/decision/adapterと全caller移行 | 承認済みPlanと依存を照合してRED/GREEN。Ratchet/TA-92も対象 |
| #1395 | budgetと正式owner統合 | budgetとMAX_INPUT_REFSを整合し、Path A/Bをruntimeから導出 |

## 次のアクション

1. 承認実物・正確なbase SHA・レビュー水準を確認する。#1329全体のcloseを待つのではなく、対象差分のpreflightを実施する。
2. #1391/#1623の順序を既存Planと照合する。構造確定とruntime完成を分離する案を優先するが、承認済みscopeの変更はHuman判断へ戻す。
3. #1623では`test_no_byte_constants`を単に削除せず、最大Eventの導出・上限超過拒否・reserveの検査へ置き換える。
4. #1391がconsumableになったら#1392と#1393を可能な範囲で並行実装する。Decisionは純関数を維持する。
5. #1395でproducerを接続し、#1391 D-12のPlan改訂・再C-3後にEV-28b/EV-28fを有効化する。
6. #1383の修復収束／NO_PROGRESS停止を実証し、その後#1381 AC-6へ進む。

この順序は対応提案であり、新しいC-3/C-4・preflight免除・Production昇格の記録ではない。
TA-92 simulation、局所PASS、Issueのチェック数をowner-backed E2Eやlive-shadow実績に読み替えない。

## 計画からの乖離

本更新でPlanを変更していない。過去の設計変更は`plan.md`のRevision履歴と`review-external.md`を参照する。
R-083（scope導出・RT-04）/ R-084（注入方法・例外のERROR写像）は引き続きexec時要件である。
