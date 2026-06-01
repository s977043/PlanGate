# TASK-0122 テストケース定義

## 受入基準 → テストケースマッピング

| AC | テストケース |
|----|------------|
| AC-1 | TC-01, TC-02 |
| AC-2 | TC-03, TC-04 |
| AC-3 | TC-05, TC-06 |
| AC-4 | TC-07 |
| AC-5 | TC-08 |
| AC-6 | TC-09（ta-24 全体） |
| AC-7 | TC-10, TC-11 |

## テストケース一覧

### TC-01: v2.0 配列形式の schema valid 検証

- **前提条件**: `schemas/plangate-reviewers.schema.json` が v2.0 に更新されている
- **入力**: c2 フェーズに 2 件の reviewerSpec 配列を持つ `.plangate-reviewers.yaml`（v2.0）
- **期待出力**: jsonschema validation PASS
- **種別**: Unit（schema validation）
- **対応 AC**: AC-1

### TC-02: v2.0 command 配列形式の schema valid 検証

- **前提条件**: `schemas/plangate-reviewers.schema.json` が v2.0 に更新されている
- **入力**: `command` フィールドが文字列配列の reviewerSpec
- **期待出力**: jsonschema validation PASS
- **種別**: Unit（schema validation）
- **対応 AC**: AC-1

### TC-03: 配列指定時の並列実行検証

- **前提条件**: `.plangate-reviewers.yaml` に c2 フェーズで 2 件の reviewer 配列を設定。各 reviewer の command は即時 exit する mock コマンド
- **入力**: `bin/plangate review TASK-XXXX --phase c2`
- **期待出力**: `review-external.md` に R-001 と R-002 の両方が出力される
- **種別**: Integration（mock コマンド）
- **対応 AC**: AC-2

### TC-04: review-external.md の R-NNN 連番付与検証

- **前提条件**: TC-03 と同じ環境
- **入力**: `bin/plangate review TASK-XXXX --phase c2`
- **期待出力**: `review-external.md` の指摘 ID が `R-001`、`R-002` の順に連番付与されている
- **種別**: Integration
- **対応 AC**: AC-2

### TC-05: mode_threshold フィルタによるスキップ検証（threshold 超過）

- **前提条件**: reviewer A に `mode_threshold: high-risk`、タスクの mode が `standard`
- **入力**: `bin/plangate review TASK-XXXX --phase c2`
- **期待出力**: reviewer A がスキップされ `review-external.md` に reviewer A の出力が含まれない
- **種別**: Integration（mock コマンド）
- **対応 AC**: AC-3

### TC-06: mode_threshold フィルタによる実行検証（threshold 以上）

- **前提条件**: reviewer A に `mode_threshold: high-risk`、タスクの mode が `high-risk`
- **入力**: `bin/plangate review TASK-XXXX --phase c2`
- **期待出力**: reviewer A が実行され `review-external.md` に reviewer A の出力が含まれる
- **種別**: Integration（mock コマンド）
- **対応 AC**: AC-3

### TC-07: v1.0 単体指定の後方互換検証

- **前提条件**: `.plangate-reviewers.yaml` が v1.0 形式（command が文字列単体）
- **入力**: `bin/plangate review TASK-XXXX --phase c2`
- **期待出力**: 既存と同一の動作（単一レビューア実行、フォーマット不変）
- **種別**: Integration
- **対応 AC**: AC-4

### TC-08: v1.0 設定が v2.0 schema で valid のまま検証

- **前提条件**: `schemas/plangate-reviewers.schema.json` が v2.0 に更新されている
- **入力**: 現行 `.plangate-reviewers.example.yaml` の v1.0 形式（`version: "1.0"`）
- **期待出力**: jsonschema validation PASS（invalid にならない）
- **種別**: Unit（schema validation）
- **対応 AC**: AC-5

### TC-09: ta-24 テスト全件 PASS

- **前提条件**: `tests/extras/ta-24-parallel-review.sh` が存在する
- **入力**: `sh tests/extras/ta-24-parallel-review.sh`
- **期待出力**: exit 0
- **種別**: Automated（CI）
- **対応 AC**: AC-6

### TC-10: markdownlint PASS

- **前提条件**: `docs/ai/external-reviewer-interface.md` が更新されている
- **入力**: `markdownlint docs/ai/external-reviewer-interface.md`
- **期待出力**: exit 0（警告・エラーなし）
- **種別**: Lint
- **対応 AC**: AC-7

### TC-11: 既存テスト regression なし

- **前提条件**: ta-01〜ta-21 が存在する
- **入力**: `sh tests/extras/ta-05-validate-schemas.sh` など関連テスト
- **期待出力**: 全件 exit 0
- **種別**: Regression
- **対応 AC**: AC-7

## エッジケース

### EC-01: `.plangate-reviewers.yaml` が存在しない場合

- 期待動作: 既存フォールバック（`PLANGATE_EXTERNAL_REVIEWER` 環境変数 or デフォルト codex）で動作
- 確認方法: `.plangate-reviewers.yaml` を削除 / 未配置の状態で `bin/plangate review` を実行

### EC-02: python3 が未インストールの場合

- 期待動作: warn を出力し既存フォールバック動作に切り替える
- 確認方法: `PATH=""` で python3 を無効化した状態でテスト

### EC-03: 配列内の一部 reviewer コマンドが失敗する場合

- 期待動作: 失敗した reviewer を warn 扱いでスキップし、成功した reviewer の結果のみ review-external.md に出力
- 確認方法: 一方の mock コマンドを `exit 1` に設定してテスト

### EC-04: mode_threshold の値がタスクの mode と一致しない文字列の場合

- 期待動作: バリデーションエラーを出力し処理を中断（schema 層で事前検証）
- 確認方法: schema validation テストで不正値を確認

### EC-05: 配列が空配列の場合

- 期待動作: schema validation FAIL（`minItems: 1` 制約）
- 確認方法: TC-01 の fixture に空配列版を追加
