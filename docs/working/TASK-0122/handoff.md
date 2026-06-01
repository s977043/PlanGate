---
task_id: TASK-0122
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-06-01
author: qa-reviewer
v1_release: ""
---

# Handoff Package — TASK-0122

## メタ情報

```yaml
task: TASK-0122
related_issue: https://github.com/s977043/plangate/issues/424
author: qa-reviewer
issued_at: 2026-06-01
v1_release: cb0a237
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: schema v2.0 additive 拡張 | PASS | `schemas/plangate-reviewers.schema.json` に `"2.0"` enum 追加、lane/mode_threshold フィールド追加、command の oneOf 拡張。TC-01〜03 全 PASS |
| AC-2: 配列形式検出時の並列実行 + R-NNN 連番 | PASS | `bin/plangate` に `_review_parallel()` 追加。TC-06b で R-001/R-002 マージ確認 |
| AC-3: mode_threshold フィルタリング | PASS | Python ロジックで mode_rank 比較を実装。TC-05/06 で low/high_risk を検証 |
| AC-4: v1.0 後方互換（yaml 未配置時のフォールバック） | PASS | `.plangate-reviewers.yaml` 不在時はレガシーフロー（PLANGATE_EXTERNAL_REVIEWER）。TC-04 PASS |
| AC-5: v1.0 設定が v2.0 schema で valid | PASS | jsonschema 検証で v1.0 設定が PASS。TC-02/08 PASS |
| AC-6: ta-24 テスト全件 PASS | PASS | `sh tests/run-tests.sh` → 220 passed, 0 failed |
| AC-7: docs 追記 + regression なし | PASS | `external-reviewer-interface.md` §8 追記、既存テスト regression なし |

**総合**: `7/7 基準 PASS`

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| bin/plangate の `_review_parallel` が bin の dispatch ループに含まれるためソースできない（TC-06b で回避済み） | minor | workaround | No |
| mode_threshold フィルタが `current-state.md` の `**Mode**:` 行のみを対象とするため書式が微妙に違うと検出できない | minor | accepted | Yes |
| 並列実行タイムアウト未実装（plan で v2.1 候補とした） | minor | accepted | Yes |

**Critical 課題**: なし

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|------------|
| 並列実行タイムアウト設定 | 長時間実行レビューアで hang するリスク | Medium | なし |
| mode 検出の正規化（current-state.md フォーマット統一） | 現在は grep 正規表現で脆弱 | Low | なし |
| events.ndjson への parallel_review イベント統合 | #230 gate-event-normalization と統合 | Low | #230 |

## 4. 妥協点

| 選択 | 採用しなかった選択肢 | 理由 |
|-----|------------------|------|
| Python3 の PyYAML で yaml パース | jq / 純シェル yaml パーサ | PyYAML は既に bin/plangate が前提としており追加依存なし |
| `_review_parallel` を bin/plangate に統合 | 別スクリプトとして外出し | bin/plangate の dispatch loop を壊さずに済む |
| TC-06b で Python スクリプトファイルを tmpdir に書き出して実行 | ヒアドキュメント内で直接実行 | heredoc 内の改行問題（SyntaxError）を回避 |

## 5. 引き継ぎ文書

### 概要

`bin/plangate review` コマンドに `.plangate-reviewers.yaml` の配列形式サポートを追加した。
v2.0 では各フェーズに複数 reviewer を配列で指定すると並列実行され、結果が `R-001`, `R-002`
形式で `review-external.md` に集約される。`mode_threshold` フィールドにより、タスクの
Mode が指定レベル未満のレビューアは自動スキップされる。

### 変更ファイル

- `schemas/plangate-reviewers.schema.json`: v2.0 additive 拡張
- `.plangate-reviewers.example.yaml`: v2.0 並列構成例に更新
- `bin/plangate`: `cmd_review` 拡張 + `_review_parallel` 関数追加
- `docs/ai/external-reviewer-interface.md`: §8 v2.0 仕様追記
- `tests/extras/ta-24-parallel-review.sh`: 新規テスト

### 動作フロー

1. `.plangate-reviewers.yaml` が存在 & python3 + PyYAML あり → `_review_parallel` 実行
2. 配列形式検出 → mode_threshold フィルタ適用 → `&` 並列起動 → `wait` → R-NNN マージ
3. 単体形式 → 既存 yaml フロー（後方互換）
4. yaml なし or python3 なし → レガシーフォールバック（`PLANGATE_EXTERNAL_REVIEWER`）

## 6. テスト結果サマリ

```
sh tests/run-tests.sh → 220 passed, 0 failed
ta-24-parallel-review:
  TC-01: PASS - schema v2.0 enum 存在
  TC-02: PASS - v1.0 後方互換 valid
  TC-03: PASS - v2.0 配列形式 example valid
  TC-04: PASS - レガシーフォールバック動作
  TC-05: PASS - mode_threshold フィルタ（スキップ）
  TC-06: PASS - mode_threshold フィルタ（実行）
  TC-06b: PASS - 並列実行 R-001/R-002 マージ
  TC-07: PASS - markdownlint エラー数 許容範囲内
```
