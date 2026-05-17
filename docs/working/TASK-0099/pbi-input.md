# PBI INPUT — TASK-0099 / /simplify follow-up（#198/#199 局所クリーンアップ）

## Context / Why
/simplify 3 並列レビュー（reuse/quality/efficiency）で #198 keep-rate.py /
#199 context-engine.py に behavior-preserving な改善余地を検出。単一ファイル内・
スコープ内の高価値指摘を follow-up で反映（共有モジュール化=4ファイル横断は別 PBI）。

## What
- In: scripts/keep-rate.py / scripts/context-engine.py（局所リファクタのみ・出力不変）
- Out: 共有 plan_hash_util / paths モジュール新設（reuse H-1/M-2＝横断 PBI）/ 機能変更

## 受入基準
- AC1: keep-rate.py — git show を全 SHA 一括（N fork 回避）/ _unknown・_ratio
  ヘルパで重複集約 / UNKNOWN・REFERENCED 定数化 / c3 を json 読込 / hashlib top import
- AC2: context-engine.py — _POLICY_ORDER 単一化（逆引き重複除去）/ c3 を json 読込 /
  _contract の plan_hash 分岐ネスト緩和 / WHAT narration コメント trim
- AC3: 両ファイルの出力が改善前と完全等価（複数 TASK で in-place 検証）
- AC4: 回帰維持（context-engine MJ-2 stale→invalidated+exit1 / schema validate）

## Notes
merged コード（main）の品質改善。機能・受入・V-3 反映は不変。等価性は
in-place 比較で機械検証。

## Estimation
Risks: 等価性崩れ（緩和: in-place 出力 diff 検証）/ Unknowns: なし
