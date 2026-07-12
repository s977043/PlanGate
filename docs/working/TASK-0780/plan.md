# TASK-0780 (Slice D) Implementation Plan — ai-loop 計測基盤

> Issue: #780 Slice D / 前提: TASK-0809（feat/809-arbiter-fail-closed）マージ後に着手（record スキーマが同一ファイルのため）

## Goal

decision record に run 系メタデータを追加し、first-pass rate 等を機械集計できるようにする。
「4 タスク中 3 件初回合格」型の主張を実測可能にする（外部評価 2026-07-11 の未達項目の解消）。

## 前提の実測検証

| 前提 | 検証コマンド | 実測結果 | 判定 |
|------|-------------|---------|------|
| 現 record に run 系フィールドなし | `python3 -c "import json,glob; print(sorted(json.load(open(sorted(glob.glob('docs/working/ai-loop-runs/*.json'))[-1])).keys()))"` | boundary_check/class_check/decision/issued_by/lite_check/policy_ref/target_sha/timestamp/w_check | ✅ |
| 既存 record は 21 件・歴史資産 | `ls docs/working/ai-loop-runs/*.json | wc -l` | 21（2026-07-11） | ✅ |
| provenance スキーマ正本は decision-table.md §5 | 該当節の実在 | あり（audit record 暫定の注記付き） | ✅ |

## 設計（Approach: additive・後方互換）

1. **入力 JSON に任意フィールド `run` を追加**: `{"run_id": "run-022", "round_index": 1, "task_id": "TASK-0809"}`。
   欠落時は record に `run: null`（入力エラーにしない＝既存呼び出し互換）。ただし ai-loop-cycle SKILL の Step 1/4 で記載を必須手順化（運用強制）
2. **派生フィールドは集計側で計算**: `first_pass = (round_index == 1 かつ decision == AUTO_APPROVED)`。record には生データのみ刻印（派生値を刻印すると改ざん面が増える）
3. **失敗系メタ**: reject 時の `failure_category` は既存 `w_check.reject_category` をそのまま利用（新設しない・重複定義回避）。再試行時の `repair_action`（1 行）を `run` 配下の任意フィールドに追加
4. **集計スクリプト `scripts/ai-loop/metrics.py`**: `docs/working/ai-loop-runs/*.json` を読み、
   run 単位に集約 → first-pass rate / escalate 率 / BLOCKED 率 / round 数分布 / failure_category 内訳を markdown + JSON で出力。
   run フィールドの無い旧 record は `legacy` として件数のみ報告（除外を明示 = 無言の truncation 禁止）
5. **正本追従**: decision-table.md §5 に `run` フィールド定義を追記（任意・運用必須の区別を明記）。ai-loop-cycle SKILL 4 配置の record 保存手順に run 記載を追加

## Out of scope（V2 へ）

- 固定 4 タスクベンチマーク（本 slice の集計が入ってから別 PBI）
- HUMAN_ESCALATED / BLOCKED の audit trail 正式定義（Phase 3 域・decision-table §5 注記どおり）

## Testing Strategy

- unit: run あり/なし record の刻印・metrics.py の集計値（既知 fixture で first-pass rate を厳密一致）・legacy 除外の明示出力
- integration: 実 record 21 件 + 新形式 fixture を混在させ集計が落ちない

## Replan Triggers / Stop Condition

- #809 実装で record 形状が想定から変わる → 本 plan を差分改訂
- 既存 record の変更が必要になった → 停止（append-only 資産）

## Mode判定

**モード**: standard（additive・安全機構の変更なし・ファイル数 5-6）。C-3: ユーザーの自律実行指示（TASK-0809 status.md に verbatim 記録済み・本 slice も同一指示の範囲）により autonomous APPROVE 予定（standard・受入基準 5 以下・影響が plan Files に閉じる）
