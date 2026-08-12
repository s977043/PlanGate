# TASK-1036 Current State

> 更新: 2026-08-12 05:10 UTC

## フェーズ: plan（B）完了 + C-1 完了 / Human C-3 待ち
## 進捗: branch `docs/1036-plan`（base `48f6971`）。Plan Package 一式作成済み・実装未着手

## 直近の完了

- pbi-input（base `408cebb`）の前提 P-1〜P-6 を現 main `48f6971` で全数再実測 → **すべて再現**（32/15/[SKIP]4・アンカー行番号も一致）
- 追加事実 4 点を plan に反映: ta-26 は #921 契約未移行（挿入点無傷）/ 新規 extras は #921 checklist 準拠必須 / ta-26 standalone 実測 約44 秒（TC-D コスト設計）/ ta-61 に同型 `PG_T61_NO_RECURSE`（V2 候補）
- 方式決着: **案 (d)**・TC 配置 = 新規 `ta-62`・変異 M-1（動的）/M-2（静的のみ・実行禁止）/M-3（sandbox）
- Mode 判定: **standard / lite_eligible=false**（pbi-input N-6 の条件付き確定と一致）
- C-1 セルフレビュー 17 項目実施（`review-self.md`）

## ブロッカー / 待ち

- H-01（Human C-3）: c3.json **初回発行**が必要（`approvals/` 不在）。判断事項は todo H-01 の 4 点

## 次のアクション

- C-3 APPROVED 後、T-03（RED: `ta-62` 作成 + 修正前 FAIL 証跡）から exec 開始
- exec 開始時に base からの `tests/` 差分有無を再確認（plan S-1 / R-P9）
