# TASK-0122 EXECUTION TODO

## 🤖 Agent タスク

### 準備フェーズ

- [ ] `bin/plangate` の `cmd_review()` 実装全体を再確認し、既存フロー（PLANGATE_EXTERNAL_REVIEWER / codex / gemini）の動作境界を把握する
- [ ] `schemas/plangate-reviewers.schema.json` の現行 v1.0 構造を確認する（oneOf / definitions の互換性）
- [ ] `tests/extras/` の既存テストパターン（ta-05-validate-schemas.sh 等）を参照し fixture 設計を決める

### 実装フェーズ

- [ ] **Step 1**: `schemas/plangate-reviewers.schema.json` を v2.0 に additive 拡張
  - `version` enum に `"2.0"` 追加
  - `reviewerSpec.command` を `oneOf [string, array]` に変更
  - `reviewerSpec` に `lane`（optional string）と `mode_threshold`（optional enum）を追加
  - `reviewers.c2` / `reviewers.v3` を `oneOf [reviewerSpec, array of reviewerSpec]` に変更
  - 🚩 schema 検証: v1.0 設定が valid、v2.0 配列設定が valid、不正な値が invalid
- [ ] **Step 2**: `.plangate-reviewers.example.yaml` に v2.0 並列構成例を追加
  - `version: "2.0"` 構成例（c2 に配列 reviewer 2 件）を追記
  - 🚩 markdownlint は不要だが yaml syntax 確認
- [ ] **Step 3**: `bin/plangate` の `cmd_review()` を拡張
  - `.plangate-reviewers.yaml` の検出・Python3 yaml パース処理を追加
  - 単体 spec フロー（後方互換）を維持
  - 配列 spec フロー: mode_threshold フィルタ → 並列実行（& + wait）→ tmpfile 集約 → R-NNN 連番付き review-external.md 出力
  - python3 / PyYAML 未インストール時の fallback（warn + 既存フロー）
  - 🚩 `bin/plangate review TASK-XXXX --phase c2` でフォールバック動作が変わらないことを確認
- [ ] **Step 4**: `docs/ai/external-reviewer-interface.md` に v2.0 仕様節を追記
  - `## v2.0: 並列実行・Mode 連動スケール` 節を追加
  - `.plangate-reviewers.yaml` v2.0 構成例を示す
  - `mode_threshold` の値と動作を説明
  - 🚩 markdownlint PASS
- [ ] **Step 5**: `tests/extras/ta-24-parallel-review.sh` を作成
  - fixture: v1.0 単体設定、v2.0 配列設定（mode_threshold あり）
  - mock コマンド（echo で固定出力）を使い並列実行を検証
  - AC-1〜AC-6 に対応するアサーション
  - 🚩 `sh tests/extras/ta-24-parallel-review.sh` exit 0

### 検証フェーズ

- [ ] L-0: `sh tests/extras/ta-05-validate-schemas.sh` で schema 検証 PASS
- [ ] L-0: `markdownlint docs/ai/external-reviewer-interface.md` PASS
- [ ] V-1: `sh tests/extras/ta-24-parallel-review.sh` PASS（AC-1〜6）
- [ ] V-1: `sh tests/extras/ta-05-validate-schemas.sh` regression なし
- [ ] V-1: 既存テスト ta-01〜ta-21 の regression 確認（関連するものを優先）

### 完了フェーズ

- [ ] `docs/working/TASK-0122/current-state.md` を最終状態に更新
- [ ] `docs/working/TASK-0122/handoff.md` を生成（V-1 PASS 後）

## 👤 Human タスク

- [ ] **C-3 ゲート**: plan.md / todo.md / test-cases.md / review-self.md を確認し APPROVE / CONDITIONAL / REJECT を決定
  - depends_on: agent の C-1 セルフレビュー（review-self.md）完成
  - HO 対象パスを含むため Standard 同期 C-3 固定
- [ ] **C-4 ゲート**: GitHub PR をレビューし APPROVE / REQUEST CHANGES / REJECT を決定

## 依存関係

```
準備フェーズ完了
  → Step 1 (schema v2.0)
  → Step 2 (example.yaml)
  → Step 3 (bin/plangate) ← Step 1 の schema 定義を参照
  → Step 4 (docs)
  → Step 5 (tests) ← Step 1/2/3 完了後
  → L-0/V-1
  → C-3 [Human]
  → exec
  → L-0/V-1 再実行
  → handoff
  → PR
  → C-4 [Human]
```
