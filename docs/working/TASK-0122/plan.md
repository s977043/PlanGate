# TASK-0122 EXECUTION PLAN

## Goal

`bin/plangate review` コマンドが `.plangate-reviewers.yaml` の配列形式を検出して並列実行し、Mode 連動フィルタ（`mode_threshold`）による自動スケールを実現する。あわせて `schemas/plangate-reviewers.schema.json` を v2.0 に additive 拡張し、既存 v1.0 設定との後方互換を維持する。

## Mode 判定

**モード**: `high-risk`

**判定根拠**:
- 変更ファイル数: 5（schemas/ × 1、bin/plangate × 1、example.yaml × 1、docs/ × 1、tests/ × 1）→ standard〜high-risk
- 受入基準数: 7 → high-risk
- 変更種別: HO 対象パス（`schemas/*.schema.json`、`bin/plangate`）を含む → **例外ルール: 最低 high-risk 強制**
- リスク: 既存レビューワークフローへの影響あり → high-risk
- **最終判定**: `high-risk`（HO 対象パス例外ルールにより強制）
- **lite_eligible**: `false`（HO 対象パス = AC-10 Hardening Override により lite_eligible=false 強制）
- **C-3**: 同期固定（lite_eligible=false のため条件付き降格なし）

## Constraints / Non-goals

- v1.0 → v2.0 は additive のみ（既存フィールド削除・変更なし）
- river-reviewer 側の変更は行わない
- C-3/C-4 ゲート判定ロジックは変更しない
- Metrics/events との統合は本 PBI スコープ外
- 並列実行タイムアウト設定は本 PBI スコープ外（v2.1 候補）

## Approach Overview

1. **schemas 拡張**: `plangate-reviewers.schema.json` に v2.0 定義を追加
   - `version` enum: `["1.0", "2.0"]`
   - `reviewerSpec` の `command` を `oneOf [string, array of string]` に拡張
   - `lane`（オプション文字列）と `mode_threshold`（オプション enum）を追加
   - `reviewers.c2` / `reviewers.v3` を `oneOf [reviewerSpec, array of reviewerSpec]` に拡張
2. **bin/plangate 拡張**: `cmd_review()` に `.plangate-reviewers.yaml` 読み込みと並列実行を追加
   - yaml 解析は Python3（`python3 -c` インライン）で行う
   - 配列形式検出時 `&` + `wait` で並列実行
   - `mode_threshold` フィルタリング
   - 結果マージと R-NNN 連番付与
3. **example.yaml 更新**: 並列構成例を追加
4. **docs 追記**: `external-reviewer-interface.md` に v2.0 仕様節を追記
5. **テスト追加**: `tests/extras/ta-24-parallel-review.sh`

## Work Breakdown

### Step 1: schemas/plangate-reviewers.schema.json v2.0 拡張

- Output: `schemas/plangate-reviewers.schema.json`（v1.0 との後方互換を持つ v2.0）
- Owner: agent
- Risk: additive のみなので既存 valid 設定が invalid になるリスクは低い
- 🚩 チェックポイント: `python3 -c "import json,sys; s=json.load(open('schemas/plangate-reviewers.schema.json')); print(s['properties']['version'])"` で `"1.0"` と `"2.0"` 両方が enum に含まれることを確認

### Step 2: .plangate-reviewers.example.yaml 更新

- Output: `.plangate-reviewers.example.yaml`（v2.0 並列構成例を追加）
- Owner: agent
- Risk: example ファイルのため既存動作への影響なし
- 🚩 チェックポイント: `python3 -c "import sys; sys.path.insert(0,''); import yaml; d=yaml.safe_load(open('.plangate-reviewers.example.yaml')); print(type(d['reviewers']['c2']))"` → list 型を含む例が存在

### Step 3: bin/plangate review コマンド拡張

- Output: `bin/plangate`（cmd_review 関数を拡張）
- Owner: agent
- Risk: 最大リスク。既存の単体指定動作を壊さないよう後方互換を徹底
- 実装方針:
  1. `.plangate-reviewers.yaml` の存在確認
  2. Python3 で yaml パース（`python3 -c` インライン or tmpscript）
  3. フェーズのエントリを取得
  4. 単体 spec の場合: 既存フロー（後方互換）
  5. 配列 spec の場合:
     - `mode_threshold` フィルタリング（タスクの current-state.md / plan.md から mode を読み取る）
     - 各コマンドを tmpfile に出力しつつ `&` で並列起動
     - `wait` で全完了を待つ
     - tmpfile 内容を R-001, R-002... と連番を付けて `review-external.md` に集約
- 🚩 チェックポイント: `bin/plangate review TASK-XXXX --phase c2` でフォールバック動作（.plangate-reviewers.yaml なし時）が変わらないことを確認

### Step 4: docs/ai/external-reviewer-interface.md 追記

- Output: `docs/ai/external-reviewer-interface.md`（v2.0 仕様節を追記）
- Owner: agent
- Risk: ドキュメントのみ
- 🚩 チェックポイント: `markdownlint docs/ai/external-reviewer-interface.md` PASS

### Step 5: tests/extras/ta-24-parallel-review.sh 追加

- Output: `tests/extras/ta-24-parallel-review.sh`
- Owner: agent
- Risk: テスト固有。fixture が必要
- 🚩 チェックポイント: `sh tests/extras/ta-24-parallel-review.sh` が exit 0

## Files / Components to Touch

| ファイル | 変更種別 | 理由 |
|---------|---------|------|
| `schemas/plangate-reviewers.schema.json` | 更新（additive） | v2.0 拡張（HO 対象） |
| `.plangate-reviewers.example.yaml` | 更新 | 並列構成例追加 |
| `bin/plangate` | 更新 | cmd_review 拡張（HO 対象） |
| `docs/ai/external-reviewer-interface.md` | 更新（追記） | v2.0 仕様記載 |
| `tests/extras/ta-24-parallel-review.sh` | 新規 | AC-6 テスト |

## Testing Strategy

- Unit: fixture ベースの shell テスト（ta-24）
- Integration: `bin/plangate review TASK-XXXX --phase c2` 実行（mock コマンド使用）
- Schema: `python3 -m jsonschema` による v1.0/v2.0 設定の valid/invalid 検証
- Regression: ta-01〜ta-21 の全件実行

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| bin/plangate が sh スクリプトのため yaml パースに外部依存（python3 必須）| python3 が無い場合は既存フォールバックに戻る旨を warn 出力 |
| 並列実行の出力が tmpfile に書き込まれる間に失敗するケース | wait の終了コードを個別に確認し、失敗レビューアを warn 扱いで skip |
| mode_threshold フィルタがタスクの mode を読み取れない場合 | current-state.md に mode 記述がなければ mode_threshold フィルタを無効化（全レビューア実行）|

## Questions / Unknowns

- Python3 の yaml パース: `PyYAML` がシステムに入っていない場合の対応（`python3 -c "import yaml"` で確認）
  → 入っていない場合は簡易正規表現 yaml パース（ただし複雑な yaml は非対応）を検討
