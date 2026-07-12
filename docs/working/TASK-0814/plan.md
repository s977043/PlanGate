# TASK-0814 Implementation Plan — arbiter.py リファクタリング（動作不変）

> Issue: #814 / 前提: #780 Slice D 後半マージ済み（arbiter.py の run 刻印確定後・同一ファイル衝突回避）
> 種別: refactor（機能変更ゼロ）。gate 挙動・不変条件・priority 順序を変えない。

## Goal

arbitrate の priority 分岐（定型 3 行 × 7）をデータ駆動テーブル化し、判定前処理を抽出して 185 行 → 100 行以下に。動作は record バイト一致で保証。

## 前提の実測検証

| 前提 | 検証コマンド | 実測 | 判定 |
|------|-------------|------|------|
| arbitrate は 185 行 | `sed -n '551,735p' arbiter.py | wc -l` | 185（#809 時点） | ✅（Slice D 後半で微増見込・着手時に再測） |
| priority 分岐は 7 個 | grep 'priority [0-9]' | 0/1/1.5/2/3/4/5/6 | ✅ |
| 全テストがベースライン | `python3 -m unittest discover -s scripts/ai-loop` | Slice D 後半後の件数 | 着手時測定 |

## Approach

- **Step 1（テスト先行）**: 全 priority を網羅する characterization test を追加。各 priority について入力 → (decision, boundary, scope_check, reason 先頭, run 刻印) を固定。これが後の「バイト一致」の基準
- **Step 2（R-2 抽出）**: boundary_check / check_allowed_paths / lite_check / verdict 正規化を `_evaluate_signals(data, ho_patterns) -> Signals` に集約。arbitrate は signals を受けて priority 分岐のみ
- **Step 3（R-1 テーブル化）**: priority 0〜6 を `[(guard: Callable, decision, scope_check, reason_builder)]` のリスト + for ループに。ただし priority 5（approve-reject の C/D 裁定）は分岐が複雑なため**テーブルの後に個別処理として残す**（無理にテーブルへ押し込まない＝over-engineering 回避）
- **Step 4（R-3）**: validate_input の list 正規化 2 箇所を `_require_normalized_path_list(value, field)` へ

## Files

- scripts/ai-loop/arbiter.py / test_arbiter.py + sync 伝播（plugin）。**metrics.py・docs・HO 非接触**

## Testing Strategy

- characterization: 全 priority の provenance record を JSON 化し、リファクタ前後で `assertEqual`（バイト一致相当）
- 既存全テスト GREEN 維持（各 Step 後）

## Replan Triggers / Stop Condition

- record バイト一致が崩れたら即停止（動作変化＝リファクタ失敗）→ 当該 Step を revert
- priority 5 のテーブル化が複雑化を招くなら個別処理のまま（設計判断を報告）

## Mode判定

**モード**: standard（refactor・動作不変・ファイル 3-4）。承認境界非接触。characterization test による動作保証が前提。
