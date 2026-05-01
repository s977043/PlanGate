# PBI INPUT PACKAGE: TASK-0050 / Issue #170

> Source: [#170 tests/run-tests.sh 拡張ポイント分離](https://github.com/s977043/plangate/issues/170)
> Mode: **light**

## Context / Why

retrospective 2026-05-01 P-2 / Try T-4。5 PBI 連続実装で `tests/run-tests.sh` 末尾領域が衝突源になり、3 PR でコンフリクト解決を要した。今後の PBI 連続実装で同じ問題を起こさないよう、拡張ポイントを別ファイルに分離する。

## What

### In scope
- `tests/extras/` ディレクトリ新設
- 既存 TA-04 / TA-05 / TA-06 / TA-07 を `tests/extras/ta-NN-*.sh` へ移動
- `tests/run-tests.sh` 末尾に `for extra in "$EXTRAS_DIR"/ta-*.sh; do . "$extra"; done` を追加
- `tests/extras/README.md` で拡張方法を記述

### Out of scope
- 既存 TA-01〜TA-03 の分離（base test として本体に残す）
- glob ソート順の保証（ta-NN プレフィクスで自然順序）

## Acceptance Criteria

- AC-1: `sh tests/run-tests.sh` が **21/21 PASS** を維持
- AC-2: 新 TA-NN 追加が `tests/extras/` への新規ファイル追加だけで完結（run-tests.sh 編集不要）
- AC-3: `tests/extras/README.md` に新規追加手順 + 規約が明文化
