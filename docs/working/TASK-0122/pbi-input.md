# TASK-0122 PBI INPUT PACKAGE

## Context / Why

現行の C-2/V-3 外部レビューは「フェーズ × 1 プロバイダ」固定であり、1 モデルの死角がそのままレビュー漏れになる構造的問題がある。v8.10.0 リリース前検証で 5 エージェント並列レビューを手動実施し、単一モデルでは検出できなかった指摘が複数モデル並列で捕捉できることを確認済み。

この手動実績をワークフローに組み込み、「並列レビューの効果」を安定して享受できる仕組みを実装する。また Mode 連動フィルタにより、高リスク PBI には自動的に多くのレビューアを動員し、低リスク PBI では最小限に絞ることで費用対効果を最適化する。

## What (Scope)

### In scope

- `schemas/plangate-reviewers.schema.json` を v1.0 → v2.0 に additive 拡張
  - `command` フィールド: 文字列 OR 文字列配列の両形式を受け付ける（`oneOf`）
  - `lane` フィールドを各 reviewerSpec に追加（オプション）
  - `mode_threshold` フィールドを各 reviewerSpec に追加（オプション）
  - `version` enum に `"2.0"` を追加（`"1.0"` も引き続き valid）
- `.plangate-reviewers.example.yaml`: 並列構成例（複数 reviewer 配列）を追加
- `bin/plangate review <TASK> --phase c2|v3`:
  - `.plangate-reviewers.yaml` の配列形式を検出した場合に並列実行（`&` + `wait` パターン）
  - 各結果を `review-external.md` にマージ出力（R-NNN 連番付き）
  - `mode_threshold` による自動フィルタリング
- `docs/ai/external-reviewer-interface.md`: v2.0 仕様（並列構成・mode_threshold）を追記
- `tests/extras/ta-24-parallel-review.sh`: fixture を使い AC-1〜6 を自動検証

### Out of scope

- river-reviewer 側の変更
- C-3/C-4 ゲート判定ロジックの変更
- Metrics/events との統合（別 PBI）
- 並列実行の同時実行数上限・タイムアウト設定（v2.1 候補）
- CI 上での並列実行最適化

## 受入基準

- AC-1: `.plangate-reviewers.yaml` で `c2` フェーズに配列形式の reviewers を指定できる（schema v2.0 が valid を返す）
- AC-2: `bin/plangate review TASK-XXXX --phase c2` が配列指定時に各コマンドを並列実行し、全結果を `review-external.md` に R-NNN 連番付きでマージ出力する
- AC-3: `mode_threshold` を `high-risk` に設定した reviewer は、対象タスクの mode が `standard` 以下の場合にスキップされ、`high-risk` 以上の場合のみ実行される
- AC-4: 既存の単体指定（v1.0 形式）は変更なしで従来と同一挙動を維持する
- AC-5: `schemas/plangate-reviewers.schema.json` v2.0 は additive 拡張であり、既存 v1.0 の `.plangate-reviewers.yaml` が v2.0 schema で valid のまま
- AC-6: `tests/extras/ta-24-parallel-review.sh` が fixture を使い AC-1〜5 を網羅的に検証し、CI で PASS する
- AC-7: markdownlint PASS、既存テスト（ta-01〜ta-21）regression なし

## Notes from Refinement

- HO（Hardening Override）対象パス（`schemas/plangate-reviewers.schema.json`、`bin/plangate`）を変更するため Mode は `high-risk` 固定、`lite_eligible=false`、C-3 は同期固定
- 並列実行の実装は POSIX sh の `&` + `wait` パターンを基本とする（Python subprocess は bin/plangate の実装言語に依存するため実装時に確認）
- `output_mapping` は配列内の各 reviewer ごとに保持する（共通継承は v2.1 候補）
- v1.0 → v2.0 は additive のみ（フィールド削除なし）。`version` は enum 拡張で後方互換を保つ
- `.plangate-reviewers.yaml` が無い場合の既存フォールバック（`PLANGATE_EXTERNAL_REVIEWER` 環境変数）は維持する

## Estimation Evidence

### Risks

- `bin/plangate` の実装言語・構造によっては並列実行実装の方法が変わる（sh vs Python）
- 並列実行時の出力順序が非決定的になる可能性 → R-NNN 連番は実行完了後にソートして付番することで回避
- 複数レビューア間で重複指摘が出る場合の扱い → 本 PBI では重複除去なし、全件を R-NNN で列挙する方針

### Unknowns

- `bin/plangate` が sh vs Python どちらで実装されているか（実装着手前に確認必須）
- 既存の `--phase c2|v3` 処理が `.plangate-reviewers.yaml` をどのように読み込んでいるか

### Assumptions

- 並列実行は最大 10 プロセス程度であり resource 枯渇は問題にならない
- `mode_threshold` の値は `mode-classification.md` の 5 段階（ultra-light / light / standard / high-risk / critical）と完全一致する文字列を使う
- fixture は既存テストパターン（ta-XX）に倣い、シェルスクリプトで記述する
