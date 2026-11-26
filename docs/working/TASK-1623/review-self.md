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

## 簡易 C-1 再実行（Rev 3 / 2026-11-26、C-2 R1 反映後）

> 対象: plan.md Rev 3（D-2 と R-001〜R-012 を反映、commit `1e133ce6`）/ todo.md / test-cases.md。作成者と同一の AI セルフレビュー。

**判定: WARN**（FAIL 0 / WARN 2）

| ID | 判定 | 所見 |
|---|---|---|
| 前回 C-2 確認点（自己参照） | 解消（計画上） | 定義行 sha256 照合（MC-2a）と一方向の番兵（MC-3 / AC-5）に置換。TC-03 / TC-11 と mutation に写像。実効性は exec と R2 で検証 |
| C1-PLAN-01 受入基準網羅性 | PASS | AC-4 / AC-5 を追加し TC-10 / TC-11 に写像。AC-1 の validator 通過は #1391 側条件（H-1391-1）と明記 |
| C1-PLAN-02 Unknowns | WARN（残） | Q-2 未確定。期限 5 営業日（RT-3）と定数値を書かない Stop Condition あり |
| C1-PLAN-06 依存関係 | 解消 | D-2 で前半 C-4 は #1391 PR の CI に依存しない。循環は解消 |
| C1-PLAN-09 Replan 機械値 | PASS | RT-2（定義行ハッシュ）/ RT-3（5 営業日）/ RT-7（実行行 0・`skipped=`）/ RT-8（後半予約）。打ち切りも機械値（R-009） |
| C1-SCOPE | WARN（新） | Files に `tests/extras/ta-118-ai-loop-v2-limits.sh` が加わった（HO 非該当）。`.github/workflows/` 不要は ta-118 実測（`:40-48`）に基づく見込みで、exec で外れたら RT-6 で停止 |
| C1-TODO-RB | PASS | 追加の T-05b に rollback あり |
| C1-TEST | PASS | mutation に「V2 tree で main 用分岐を強制」「印の部分一致」「skip 注入」を追加 |

残 WARN: Q-2 未確定 / ta-118 改修の範囲（RT-6 の発火可能性）。C-2 R2 は §7-quater に従い R1 是正（番兵・ハッシュ照合・収集判定）の回避経路を疑う。

## 簡易 C-1 再実行（Rev 4 / 2026-11-26、C-2 R2 反映後）

> 対象: plan.md Rev 4（R-013〜R-017 を反映、commit `60540c4d`）/ todo.md / test-cases.md。作成者と同一の AI セルフレビュー。

**判定: WARN**（FAIL 0 / WARN 3）

| ID | 判定 | 所見 |
|---|---|---|
| R2 自己参照ハッシュ（R-013） | 解消（計画上） | CI 照合は偶発破損の検出に格下げ、写像の正しさは MC-2a の Human 突き合わせ（C-3・前半 C-4 の 2 回）。残存脅威モデルに「同時編集は CI で検出不能」を明記 |
| R2 番兵の素通り（R-014） | 解消（計画上） | 振る舞い判定に変更、mutation に改名・移設を追加（TC-11 d/e）。実効性は exec と R3 で検証 |
| C1-PLAN-01 受入基準網羅性 | PASS | AC-4（R-016 で改訂）・AC-5（R-014 で改訂）を TC-10 / TC-11 に、MC-4 を TC-13、MC-2a を TC-12 に写像 |
| C1-PLAN-02 Unknowns | WARN（残） | Q-2 未確定。期限 5 営業日（RT-3）と定数値を書かない Stop Condition あり |
| C1-PLAN-06 依存関係 | WARN（新） | MC-2a は Human 確認（H-03 / H-03b）に、MC-4 は前半マージ後の対外投稿（T-12、名指し承認要）に依存。前半 C-4 の前提に Human 作業が 1 件増えた |
| C1-PLAN-09 Replan 機械値 | PASS | RT-7 を必須テスト名・分岐明示行に拡張、RT-9（突き合わせ不一致）を追加 |
| C1-SCOPE | WARN（残） | ta-118 改修が `verbosity=2`・固定リスト照合まで拡大（HO 非該当）。`.github/workflows/` 不変は AI 推奨で、C-3 で Human が覆すと HO に当たり別承認（RT-6） |
| C1-TODO-RB | PASS | 追加の T-05c / T-12 に rollback 記載 |
| §7-quater 打ち切り | 未収束 | R2 で新クラス 4 件 → R3 を実施（plan レビューレーン計画） |

残 WARN: Q-2 未確定 / Human 依存の追加（MC-2a・MC-4）/ ta-118 改修範囲と workflows 不変の判断。C-3 前に R3 を実施する。

## 簡易 C-1 再実行（Rev 5 / 2026-11-26、D-3 と C-2 R3 反映後）

> 対象: plan.md Rev 5（D-3 と R-018〜R-023 を反映、commit `66bb1a45`）/ todo.md / test-cases.md。作成者と同一の AI セルフレビュー。

**判定: WARN**（FAIL 0 / WARN 3）

| ID | 判定 | 所見 |
|---|---|---|
| R3 番兵系（R-018 / R-019 / R-020） | 対象消滅（D-3） | 前半に写像検査・分岐・番兵が無くなり、指摘対象が前半から消えた。設計条件は H-1391-4 / H-1391-6 に移した |
| R-021 固定リスト | 解消（縮小） | AC-4 を `skipped=` 0 件・rc=0 に戻した。未収集・改名による未実行は残存脅威モデルに明記し H-1391-5 へ |
| R-022 MC-4 の gate | 解消（計画上） | 本文案と投稿先の Human 確認（H-03c）を前半 C-4 の前提に、投稿 URL を #1623-b の C-3 前提にした |
| R-023 MC-2a の形式 | 解消（計画上） | コマンド・行範囲（T-02 で測る）・保存先 `evidence/mc2a-{c3,c4}.txt`・確認記録先 status.md を確定 |
| C1-PLAN-01 受入基準網羅性 | PASS | AC-1（byte 再現まで）/ AC-1a / AC-1b / AC-3 / AC-4 が前半、AC-2 / AC-2a は後半、AC-5 は #1391 後半と割当が表で一意 |
| C1-PLAN-02 Unknowns | WARN（残） | Q-2 未確定。期限 5 営業日（RT-3）と定数値を書かない Stop Condition あり |
| C1-PLAN-06 依存関係 | WARN（残） | 前半 C-4 は Human 作業 2 件（H-03b MC-2a 2 回目・H-03c MC-4 本文案）に依存。#1623-b の C-3 は T-12（マージ後投稿）に依存 |
| C1-PLAN-09 Replan 機械値 | PASS | RT-7 を `skipped=` / rc に縮小、RT-9 を fixture 測り直しに、RT-10（D-3 前提の崩れ）を追加 |
| C1-SCOPE | PASS | 前半 Files は limits / test_limits / fixture / ta-118（`skipped=` 判定のみ）/ evidence。HO 非該当。移管項目は削除せず「D-3 で移管」と明記 |
| 残存脅威 | WARN（新） | 前半マージ〜#1391 後半の間、構造ズレは CI で検出されない。保証の主体は MC-2a の Human 突き合わせと #1391 後半の実照合（plan.md 残存脅威モデル） |
| §7-quater 打ち切り | 打ち切り（設計モデル変更） | R2:4, R3:3 → D-3。完全性は主張しない。R4 は実施せず、縮小後の前半は exec 後の敵対レビュー 2 ラウンドで扱う |

残 WARN: Q-2 未確定 / 前半 C-4 の Human 依存（MC-2a 2 回目・MC-4 本文案）/ 前半〜#1391 後半の構造ズレ未検出期間。

## 簡易 C-1 再実行（Rev 6 / 2026-11-26、D-4 と C-2 R4 反映後）

> 対象: plan.md Rev 6（D-4 と R-024〜R-028 を反映、commit `5b92ff27`）/ todo.md / test-cases.md。作成者と同一の AI セルフレビュー。

**判定: WARN**（FAIL 0 / WARN 4）

| ID | 判定 | 所見 |
|---|---|---|
| R-024 受け手の gate | 解消（計画上・外部作業待ち） | D-4 で H-1391-1〜6 を #1391 スライス B の C-4 前提に位置づけ、#1623-b の C-3 条件を H-1391-1〜6 すべてに拡張。TASK-1391 文書への記載はオーガナイザー作業で未実施（TC-13 (3) で確認） |
| R-025 gate の時間順 | 解消（計画上） | 行範囲を plan MC-2a に実測で記載（`6756a597:run_event.py` 39-43 / 52-74 / 81-84 / 136-171 / 467-474）。C-3 時点は文章仕様との突き合わせ（T-00、exec 成果物に非依存）、fixture 実物は C-4 時点（T-05c）。todo 依存を H-03 ← T-00 に修正 |
| R-026 H-1391 の文面 | 解消 | H-1391-1 / 2 を「#1391 後半で新設する実照合」と「その実行確認」に書き直し、番兵は H-1391-4 の検討結果に従う形にして食い違いを除去。MC-4 本文にこの文面を使う旨を明記 |
| R-027 未実行の他の形 | 解消（一部は残存脅威） | ta-118 の FAIL 条件に `expected failures=` / `Ran 0 tests` を追加（AC-4 / Files / RT-7 / TC-08 / TC-10）。早期 return・トートロジー assert は残存脅威モデルに明記 |
| R-028 AC-1 の達成範囲 | 解消 | AC-1 前半を「数値の自己再現」と明記、切り上げ幅を出典逸脱時の最大 byte 増への余裕として根拠づける方針を WB3 に記載 |
| C1-PLAN-01 受入基準網羅性 | PASS | AC-4 の拡張を TC-10 (b)(c) に写像。D-4 の記載確認を TC-13 (3) に追加 |
| C1-PLAN-02 Unknowns | WARN（残） | Q-2 未確定。期限 5 営業日（RT-3）と定数値を書かない Stop Condition あり |
| C1-PLAN-06 依存関係 | WARN（残・更新） | C-3 は T-00（MC-2a C-3 時点分）の Human 確認に依存。前半 C-4 は H-03b / H-03c、#1623-b の C-3 は T-12 と H-1391-1〜6 の evidence に依存 |
| C1-PLAN-09 Replan 機械値 | PASS | RT-7 に `expected failures=` / `Ran 0 tests` を追加 |
| C1-SCOPE | PASS | 本 TASK の変更は `docs/working/TASK-1623/` のみ。TASK-1391 文書への記載（D-4）は本 TASK の Files 外でオーガナイザーが行う |
| 外部依存（D-4） | WARN（新） | TASK-1391 文書への C-4 前提の記載が未実施。記載先と commit を exec 前に status.md へ記録する必要がある |
| 残存脅威 | WARN（残） | 前半マージ〜#1391 後半の構造ズレ未検出、早期 return・トートロジー assert は ta-118 で検出しない |
| §7-quater | 推移記録 | R2:4, R3:3, R4:1。R4 の新クラス（gate の判定材料が gate の後に作られる）は是正済み。完全性は主張しない |

残 WARN: Q-2 未確定 / C-3・C-4 の Human 依存 / TASK-1391 文書への D-4 記載が未実施 / 前半〜#1391 後半の構造ズレ未検出期間と ta-118 で検出しない実質未検査。

## 簡易 C-1 再実行（Rev 7 / 2026-11-26、C-2 R5 反映後）

> 対象: plan.md Rev 7（R-029〜R-032 を反映、commit `45811756`）/ todo.md / test-cases.md。作成者と同一の AI セルフレビュー。

**判定: WARN**（FAIL 0 / WARN 4）

| ID | 判定 | 所見 |
|---|---|---|
| R-029 mc2a-c4 の鮮度 | 解消（計画上） | T-05c の depends_on に T-09・T-11 を追加し C-4 前の最後に作るタスクにした。fixture blob SHA と PR head SHA を記録し H-03b で現 head と照合（TC-12） |
| R-030 mc2a-c3 と tip | 解消（計画上） | T-00 で tip SHA と RT-2 diff を `mc2a-c3.txt` に同時記録。T-02 は記録 tip からの変化の再確認に変更。2026-11-26 実測: `git diff 6756a597 3a7373f0 -- scripts/ai-loop-v2/run_event.py` は空 |
| R-031 正本循環 | 解消 | plan の引き継ぎ節から文面を除き、ID と 1 行要約（正本でない旨明記）と正本 `c4-preconditions.md`（`3a7373f0`）の参照だけにした。両方を同じ変更で更新する規則を記載。`grep "H-1391-[1-6]:" plan.md` 0 件 |
| R-032 TASK-1391 todo からの参照 | WARN（Human 待ち） | exec 開始条件として H-01e を追加。TASK-1391 の status / todo の未 commit 変更の扱いは Human が決める |
| R-027 補足 | 解消 | AC-4 / Files / T-05b / TC-10 に行頭固定の正規表現・要約行限定を記載 |
| C1-PLAN-01 受入基準網羅性 | PASS | AC 割当は不変。TC-12 / TC-13 に R-029〜R-032 の期待を追加 |
| C1-PLAN-02 Unknowns | WARN（残） | Q-2 未確定（RT-3・Stop Condition あり） |
| C1-PLAN-06 依存関係 | WARN（残・更新） | exec 開始は H-03 と H-01e に依存。T-05c は T-09・T-11（前半 PR の CI）の後で、C-4 直前に Human 確認が集中する |
| C1-SCOPE | PASS | 変更は `docs/working/TASK-1623/` のみ。TASK-1391 は変更していない |
| 残存脅威 | WARN（残） | 前半〜#1391 後半の構造ズレ未検出期間、早期 return・トートロジー assert |
| §7-quater | 推移記録 | R2:4, R3:3, R4:1, R5:1（正本循環）。R-029 / R-030 は R4 クラスの同型の是正漏れ。新クラスが 1 件ずつ出続けており完全性は主張しない |

残 WARN: Q-2 未確定 / Human 依存（H-01e の TASK-1391 todo 追記・C-4 前の H-03b 集中）/ 前半〜#1391 後半の構造ズレ未検出期間と ta-118 で検出しない実質未検査。
