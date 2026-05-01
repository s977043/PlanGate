# EXECUTION PLAN: TASK-0050 / Issue #170

> Mode: **light**

## Goal

`tests/run-tests.sh` を base + extras loader 構造に変える。後続 PBI が `tests/extras/` にファイル追加するだけでテスト追加完了する仕組みにし、末尾領域コンフリクトを根絶する。

## Approach

1. `tests/extras/` 新設 + 既存 TA-04〜TA-07 を 4 ファイルに分離（コピー、内容無変更）
2. `tests/run-tests.sh` から旧 TA-04〜TA-07 を削除し、`for extra in "$EXTRAS_DIR"/ta-*.sh; do . "$extra"; done` を追加
3. `tests/extras/README.md` で source 規約 + 新規追加手順を明示
4. `sh tests/run-tests.sh` で 21 件 PASS 維持を確認

## 変更ファイル

| ファイル | 種別 |
|---------|------|
| `tests/extras/ta-04-check-pr-issue-link.sh` | 新規（既存 TA-04 移動）|
| `tests/extras/ta-05-validate-schemas.sh` | 新規（既存 TA-05 移動）|
| `tests/extras/ta-06-hooks.sh` | 新規（既存 TA-06 移動）|
| `tests/extras/ta-07-eval-runner.sh` | 新規（既存 TA-07 移動）|
| `tests/extras/README.md` | 新規（規約 + 追加手順）|
| `tests/run-tests.sh` | 編集（loader 化、TA-04〜07 を削除）|
| `docs/working/TASK-0050/*` | 新規 |

## Mode判定

light（CI 影響なし、テスト構造の純粋なリファクタリング、後方互換維持）

## Risks & Mitigations

| Risk | Mitigation |
|------|----------|
| source 順序が glob で安定しない環境がある | `ta-NN-` プレフィクス + POSIX `set -e` で順序を明示 |
| extras/ 内で `set -eu` を再宣言 → 干渉 | extras 側は `set` 不宣言（base に任せる）|
| シェル変数 scope の違い | source は同一プロセスなので `pass` / `fail` がそのまま参照される |

## 確認方法

- `sh tests/run-tests.sh` → `Results: 21 passed, 0 failed`
- diff で TA-04〜07 のロジックが完全コピーであること確認
