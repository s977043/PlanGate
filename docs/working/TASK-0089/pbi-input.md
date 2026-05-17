# PBI INPUT — TASK-0089 / #227 river-reviewer 外部レビューア標準 IF

## Context / Why
C-2/V-3 は外部レビューアを呼ぶ設計だが river-reviewer との接続方法・出力
マッピング・責務分担が未文書化。両ツール併用時に設定で迷い責務重複も起きる。

## What
- In: `docs/ai/external-reviewer-interface.md`（正本）/ `schemas/plangate-reviewers.schema.json` /
  `.plangate-reviewers.example.yaml` / review-principles §7-bis・contracts/review.md への接続
- Out: bin/plangate review の実装変更 / river-reviewer 側変更 / events 発火実装

## 受入基準
- AC1: `.plangate-reviewers.yaml` IF 定義（version/reviewers.c2/v3/provider/command/output_mapping）
- AC2: river-reviewer Finding → review-external 変換表 + severity 1:1 マッピング表
- AC3: 責務分担表（C-1/C-2/V-1/V-3 × PlanGate/river-reviewer）
- AC4: 3 導入パターン（PlanGate だけ/river だけ/両方）が示される
- AC5: JSON Schema が用意され example が schema validate を通る
- AC6: review-principles §7-bis（2 レーン契約）と矛盾せず接続 IF として参照される

## Notes
§7-bis 契約・5 観点・Severity・判定基準は不変（IF は接続のみ）。未知 severity は
安全側 major。severity 表変更は破壊的（versioning-stability-policy §2.1）。

## Estimation
Risks: 既存 C-2 責務契約との二重定義（緩和: §7-bis を正本参照し IF は接続限定） /
Unknowns: events 発火（別 PBI 明記） / Assumptions: river-reviewer Finding 構造は #802 準拠
