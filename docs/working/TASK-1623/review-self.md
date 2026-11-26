# TASK-1623 セルフレビュー結果（C-1）

> 2026-11-26、AI セルフレビュー（作成者と同一。独立レビューではない）。対象: plan.md / todo.md / test-cases.md / pbi-input.md（Rev 1）。

## サマリー

**判定: WARN**（FAIL 0 / WARN 3 / PASS 他全項目）。C-3 前に Human 判断 Q-1 が必須。C-2 は未実施（high-risk のため必須）。

## Plan チェック

| ID | 判定 | 所見 |
|---|---|---|
| C1-PLAN-01 受入基準網羅性 | PASS | AC-1/AC-2 と Scope 由来の reserve 参照を TC に写像 |
| C1-PLAN-02 Unknowns処理 | WARN | Q-1（順序）・Q-2（可変 field 上限）が未決。exec 前に解消必須と明記済み |
| C1-PLAN-03 スコープ制御 | PASS | #1391 append 本体・#1392 reserve 本体・#1393 core を Out of scope |
| C1-PLAN-04 テスト戦略 | PASS | fixture・境界・drift・mutation・2 ラウンド |
| C1-PLAN-05 Work Breakdown Output | PASS | 各 Step に Output |
| C1-PLAN-06 依存関係 | WARN | T-06（I-11）は #1393 core 依存で、H-10 と衝突。案ごとの依存を Q-1 表に記載 |
| C1-PLAN-07 動作検証自動化 | PASS | 全 TC 自動化可（TC-04/05 は前提待ち）|
| C1-PLAN-08-AEE Stop Condition | PASS | 3 条件 |
| C1-PLAN-09-AEE Replan Triggers 機械値 | WARN | RT-2 / RT-4 / RT-5 は機械値あり。RT-1 / RT-3 は Human 決定・回数基準 |
| C1-SUP-PLAN-01 No Placeholders | PASS | 定数値を書いていない（意図どおり）。fixture ファイル名のみ exec 確定と明記 |
| C1-SUP-PLAN-02 Task Sizing | PASS | |

## ToDo / TestCases / その他

| ID | 判定 | 所見 |
|---|---|---|
| C1-TODO-08〜12 | PASS | 粒度・depends_on・🚩・完了条件あり |
| C1-TODO-RB | PASS | 実装タスク全てに rollback |
| C1-TEST-13〜15 | PASS | escape・最大桁・任意 field・件数内 byte 超過を Edge に含む |
| C1-B1B2-16/17 | PASS | Q-1 比較表（4 案）・計算方式比較 |
| C1-SEC-01 | PASS | 秘密情報非接触 |
| C1-SCOPE-DISC-01 | PASS | V-3（構造が main に無い）を前提検証に分離記録 |

## 主な指摘

1. **R-C1-01（WARN）**: H-10「#1623 先行マージ」と AC-2（`DecisionInputError` / I-11 は #1393 core）が両立しない。main 実測で裏付け（plan.md「前提の実測検証」V-1〜V-3）。Human が Q-1 で案を選ぶまで C-3 APPROVE 不可。
2. **R-C1-02（WARN）**: 案 B を採る場合、「#1623 を先にマージ」の単位が #1623-a に変わる。issue の Open 維持と drift テストの #1391 PR での実行配線を C-3 条件にすること。
3. **R-C1-03（info）**: 下書きにない論点として、V2 `decision_made` 構造自体が main に無い（`6756a597` のみ）。AC-1 も固定 SHA 写像なしには main 単独で満たせない。

## 自動修正ログ

なし。

## 簡易 C-1 再実行（Rev 2 / 2026-11-26 17:42）

> 対象: plan.md Rev 2（D-1 反映）/ todo.md / test-cases.md / status.md。作成者と同一の AI セルフレビュー。

**判定: WARN**（FAIL 0 / WARN 2）

| ID | 判定 | 所見 |
|---|---|---|
| R-C1-01 | 解消 | Q-1 は D-1（案 B）で決定。前半は AC-2 を対象外とし、AC 文面は不変 |
| R-C1-02 | 解消（計画上） | MC-1（Open 維持・`Refs` のみ）/ MC-2（#1391 PR CI での実行確認）/ MC-3（main で skip しない）を前半受入条件に明記、TC-08/09・T-11・RT-7 に写像。実行は exec 後 |
| C1-PLAN-01 受入基準網羅性 | PASS | AC ごとのスライス割当表あり。AC-2 は後半と明記し前半で合格扱いしない（Stop Condition） |
| C1-PLAN-02 Unknowns | WARN（残） | Q-2（可変 field 上限）が未確定。定数値を書かない Stop Condition あり |
| C1-PLAN-06 依存関係 | WARN（新） | T-11（MC-2）は前半を取り込んだ #1391 PR の CI run に依存し、本 TASK 単独で完結しない。MC-2 を CI 既存収集経路で満たせない場合は HO（`.github/workflows/`）に当たる（RT-6） |
| C1-PLAN-09 Replan 機械値 | PASS | RT-7 は機械値（実行行 0 件）。RT-1/RT-3 は Human・回数基準のまま |
| C1-SCOPE | PASS | Files は前半に限定、後半は参考扱い |

C-2 で特に見てほしい点: MC-3 の「main で skip せず固定 SHA 写像を検査」が、写像と実 validator を突き合わせない main 上では自己参照の検査にならないか（同型の素通り）。
