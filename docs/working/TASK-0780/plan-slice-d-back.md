# TASK-0780 (Slice D 後半) Implementation Plan — arbiter が run メタを record に刻む

> Issue: #780 Slice D 後半 / 前提: #813 マージ済み（入力契約確定）・#812 で metrics.py が run 構造を消費する側は実装済み

## Goal

arbiter.py の入力に任意フィールド `run` を受理し、decision record（provenance）に刻む。
これにより #812 の metrics.py が実データで first-pass rate 等を算出できるようになる（現状は全 record が legacy）。

## 前提の実測検証

| 前提 | 検証コマンド | 実測結果 | 判定 |
|------|-------------|---------|------|
| metrics が期待する run 構造 | `git show origin/main:scripts/ai-loop/metrics.py | grep run_id` | run_id:str/round_index:int/task_id:str | ✅ |
| 現 arbiter 入力に run が無い | `git show origin/main:scripts/ai-loop/arbiter.py | grep -n '"run"'` | 0 | ✅ |
| POLICY_REF は @v1 | 同上 grep POLICY_REF | auto-approve-lite-clean@v1 | ✅ |

## 設計（additive・後方互換）

1. **入力**: `run` は**任意**フィールド。`{"run_id": str, "round_index": int, "task_id": str, "repair_action"?: str}`。
   - 存在する場合は型検証: run_id 非空 str / round_index int（bool 除外）/ task_id str / repair_action は任意 str。不正型は InputError（exit 1）
   - 欠落時は record に `"run": null`（既存呼び出し互換 — validate は通す）
2. **provenance**: build_provenance に `run` を追加し、全裁定経路（fail-closed 含む）で刻む
3. **POLICY_REF は @v1 据え置き**: run は provenance の additive 拡張であり裁定ロジック（gate 挙動）を変えないため policy 改版ではない
4. **SKILL 4 配置**: Step 1 入力例に run 追加 + 「run_id は run-NNN・round_index は再試行ごとに +1・task_id は対象 PBI」を運用手順として明記。Step 4 の record 保存はそのまま（arbiter が刻む）
5. **decision-table.md §5**: provenance フィールド表に run（run_id/round_index/task_id/repair_action）を追記

## Out of scope

- 固定 4 タスクベンチマーク（run が実データに溜まってから別 PBI）
- metrics.py 側の変更（#812 で消費側は完成済み・触らない）

## Testing Strategy

- run あり record が正しく刻まれる（4 サブフィールド）/ run なし → null / 各型不正 → exit 1
- **end-to-end**: run 付き入力 2 件（round 1 reject→round 2 AUTO の同一 run_id）を arbiter で処理して record 2 個生成 → metrics.py に食わせて first_pass 判定が正しく出る（arbiter→metrics 結合の実証。これが本 slice の価値）

## Replan Triggers / Stop Condition

- metrics の run 構造と食い違いが判明 → 停止して metrics 側の仕様を正とする（消費側優先）
- 既存 record 25 件は不変（append-only）

## Mode判定

**モード**: standard（additive・gate 挙動不変・ファイル数 6-7）。C-3: ユーザー自律実行指示の範囲（standard・受入基準 ≤5・影響が plan Files に閉じる）で autonomous APPROVE。承認境界（HO 9 カテゴリ）非接触。
