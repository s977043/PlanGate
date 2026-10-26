# TASK-1608 status

## モード判定

high-risk（根拠は plan.md「Mode 判定」）。`lite_eligible=false`。autonomous C-3 不可。

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|------|---------|------|
| 2026-10-24 04:00 | plan | pbi-input / plan / todo / test-cases を生成（base: origin/main `dd7a0204`） |
| 2026-10-24 04:10 | C-1 | セルフレビュー WARN（Human 判断事項 Q-1〜Q-4） |
| 2026-10-24 04:10 | C-3 待ち | draft PR #1611 で Human 判断待ち |
| 2026-10-24 04:35 | C-3 待ち | Human 回答（Q-1〜Q-4 すべて推奨案）を plan / pbi-input（AC-10）/ test-cases / decision-log（D-004〜D-008）へ確定反映。簡易 C-1 PASS |
| 2026-10-24 04:25 | exec | C-3 APPROVED（Human 発行、plan_hash sha256:a1ddda40…、承認 2026-10-23T19:30:01Z。`approvals/c3.json` は untracked のまま）。exec 開始 |
| 2026-10-24 04:32 | exec | T-1 実測 / T-2 回帰テスト追加（旧実装で 19 FAIL / 2 ERROR、`e8a975e9`） |
| 2026-10-24 08:52 | exec | T-3〜T-7 ブロック状態機械へ置き換え（`bcdc9340` 07:17）、T-9 変異注入の生存 2 件を是正（`cf440056`） |
| 2026-10-24 09:31 | verify（V-3） | 敵対レビュー R1 是正（`6a4803fe`）/ R2 是正（`7e358c7f`）/ R3 是正（`a849dcfa`） |
| 2026-10-24 09:40 | BLOCKED | R4 で plan の Stop Condition に該当（同層の新クラス 2 連続）。R4 critical は未是正で停止（D-010） |
| 2026-10-24 10:00 | C-3 待ち | Human 裁定 (c)「守備範囲を縮める」（D-011）。plan D-1b・pbi-input AC-11・test-cases TC-CB-*・todo T-13〜T-16 を改訂、簡易 C-1 PASS。既存 c3.json は初版の plan_hash で本改訂には無効（未編集） |
| 2026-10-25 01:15 | exec | C-3 再承認（Human、plan_hash 439f1620…、approved_at 2026-10-24T16:15:34Z）。T-13 TC-CB 追加（現実装で 7 FAIL、`9cf433f9`） |
| 2026-10-25 01:24 | verify | T-14 D-1b 実装 / T-15 変異注入（`57673063`）。単体 57 件 OK・ta-116・ta-70・現行データ 7 / 5 不変。T-16 の敵対レビューはオーガナイザー側で実施 |
| 2026-10-25 02:00 | verify | R5（critical 1 / major 2 / minor 2）を是正。C-1 を再現し in_list を container に一本化（D-013）、M17 を M17a / b に分割、adv_r1_02 を到達可能な入力で復元。単体 61 件 OK（**誤記。実測は `Ran 60 tests`、R6 m-2**）・ta-116・ta-70・現行データ 7 / 5 不変・変異 36 種 KILLED |
| 2026-10-25 10:00 | C-3 待ち | R6（major 1 = 入れ子の喪失 / minor 2）で Stop Condition。Human 裁定「入れ子をすべて拒否」（D-014）を plan D-1c・test-cases TC-NEST-*・todo T-17〜T-22 に反映、簡易 C-1 PASS。現行データの入れ子 0 行を実測。既存 c3.json（439f1620…）は本改訂に無効（未編集） |
| 2026-10-25 10:15 | exec | C-3 再承認（Human、plan_hash 24a35af0…、approved_at 2026-10-25T00:33:14Z）。T-17 RED（12 FAIL / 1 ERROR、`43ebb79b`） |
| 2026-10-25 10:30 | verify | T-18〜T-21（`72d55dac`）。単体 `Ran 66 tests` OK・ta-116・ta-70・現行データ 7 / 5 不変・変異 41 種すべて KILLED。T-22 の敵対レビューはオーガナイザー側 |
| 2026-10-26 07:06 | verify（V-3） | R7（`ca9a8b33`）で新クラス（列 4〜5 の入れ子の素通り）。Human 決定「検証設計を変える」。R-001〜R-004 を review-external に集約（plan 反映は EH-3 により保留） |
| 2026-10-26 10:00 | C-3 待ち | **C-3 再承認待ち（plan_hash 変更）**。L1 レビュー（issuecomment-6404932159）を R-005〜R-012 に集約し、HD-1=y / HD-2=y（D-016）と合わせて plan 改訂 3（D-1d・検証モデル）・todo T-23〜T-29 / H-5 / H-6・test-cases TC-NEST-C* / TC-DIFF-* / TC-CORPUS-* に 1 回で確定反映。簡易 C-1 WARN（閾値の根拠・H-6 依存）。HO patch と適用スクリプトを `ho/` に置き dry-run rc=0。既存 c3.json（24a35af0…）は本改訂に無効（未編集） |
| 2026-10-27 10:00 | C-3 待ち | **C-3 再承認待ち（plan_hash 変更）**。L2 レビュー（issuecomment-6407222034）を R-013〜R-018 に集約し、Human 裁定 D-017（hashFiles ガード・HO を #1611 より先に main へ）と合わせて plan 改訂 4・todo（依存順序の組み直し）・test-cases（TC-DIFF 更新・TC-DIFF-10・TC-HO-*）に 1 回で確定反映。ho/ の patch と適用スクリプトを是正し dry-run rc=0。簡易 C-1 WARN（軸別下限値と時間上限は exec で実測） |
| 2026-10-27 14:00 | C-3 待ち | **C-3 再承認待ち（M-1 / M-2 限定確認後。plan_hash 変更）**。L3 レビュー（issuecomment-6427012568）を R-019〜R-024 に集約し、Human 裁定 D-018 と合わせて plan 改訂 5（差分テストを別 job `seed-delta-reference` に分離・存在対照 TC-DIFF-11・verify 強化・base 検証）・todo（H-6 位置と依存注記）・test-cases（TC-DIFF-11・TC-HO-04〜07）に 1 回で確定反映。HO dry-run rc=0、スクラッチで新 job 構造と verify の FAIL 3 系統を確認。簡易 C-1 WARN（新 job timeout は T-26 で確定）。根拠: main Test 直近 9 回の job 所要 297〜441 秒 |

## 残タスク

- [x] H-1 C-3 判断と `approvals/c3.json` の発行（Human）
- [x] T-1〜T-10（T-3〜T-7 は 1 commit にまとめた）
- [x] T-11 収束判定 — R4 で不収束、Human 裁定 (c) で plan 改訂（D-011）
- [x] H-3 改訂 plan の C-3 再承認（Human）
- [x] T-13〜T-15
- [x] T-16 敵対レビュー R5（是正済み）/ R6（Stop Condition で停止、D-014）
- [x] H-4 改訂 2 の plan の C-3 再承認（Human）
- [x] T-17〜T-21
- [x] T-22 敵対レビュー R7（新クラス → 改訂 3 へ）
- [ ] D-018 M-1 / M-2 の是正部分に限った短い確認（オーガナイザー側）
- [ ] H-5 改訂 5 の plan の C-3 再承認（Human。plan_hash 変更、上記確認の後）
- [ ] H-6 HO patch（`ho/test-yml.patch`）を feature ブランチ → PR で main に先行 merge（Human、T-26 後）
- [ ] T-23〜T-29（改訂 3、H-5 後）
- [ ] T-12 PR を ready にする（T-16 後）
- [ ] T-12 PR を ready にする（BLOCKED 解除後）

## 計画からの変更点

- Q-1〜Q-4 を決定済みに更新し、pbi-input に AC-10（Q-3 の読み替え）を追加（2026-10-24）
- T-3〜T-7 を 1 commit（`bcdc9340`）で実装した（単一ファイルの置き換えで分割の実益が無かったため）
- test-cases の TC-BLK-04 / 05 は、リスト直後だと CommonMark 上リスト継続になる（code にならない）ため、前置きを `## 概要` に変えて意図どおりの「indented code」を検証した。リスト継続側は TC-BLK-04b / 05b として追加
- 敵対レビューの是正で plan に無いテスト（adv_r1_* 〜 adv_r3_*）と判定を追加した。確認値の判定モデルを変更（D-009）
- 敵対レビューは plan の下限 2 に対し 4 ラウンド実施し、R4 で Stop Condition に該当（D-010）
- T-14 で既存テスト 4 件の fixture / 期待メッセージを調整（D-012）。#1574 由来の `test_non_seed_heading_without_date_is_accepted` は、AC-1 と TC-CB-05（リスト直後の空行なし見出しを拒否）が衝突したため、fixture に空行 1 行を挟んだ。判定の意図（日付の無い見出しは受理）は不変
- 変異 M17 の等価判定は R5 M-1 で撤回（C-1 経路で到達可能だった）。M17a / M17b に分けて KILLED
- T-18 で、本 PR で追加した既存テスト 3 件（adv_r3_01 の `1. ~~~` / `> - <div>`、test_nested_confirmation_does_not_hide_a_second_marker、TC-BLK-01 のリスト内見出し）は、入力が入れ子・オフセット規則で先に拒否されるようになったため、期待メッセージに新しい理由を加えるか空行を挟んだ（拒否されること自体は不変）。TC-NEST-07 は test-cases の期待（nested container）に対し、番号付きリストが T-19 のオフセット規則で先に拒否されるため `nested container|content offset` で検証した
- コンテナ状態をブロックの中身で更新しないよう変更（D-015。plan D-1c の前提を満たすための実装上の判断）
- T-21 で生存した M12 に対し test_t21_non_canonical_second_marker_is_counted を追加
- adv_r1_02 は D-012 で期待メッセージだけ変えていたが、R5 M-2 を受けて「トップレベル fence は 4 空白の行では閉じない」を到達可能な入力で検証する形に戻した
- ta-116 の standalone ログは evidence に保存できなかった（エージェント実行環境が sh の出力リダイレクトを拒否）。実行結果は 2 passed / 0 failed（rc=0）を目視確認し、CI の plangate CLI tests でも通過

## 参照

- Issue #1608 / PR #1574（回避クラス台帳 R1〜R4）
- `.claude/rules/review-principles.md` §7-quater
