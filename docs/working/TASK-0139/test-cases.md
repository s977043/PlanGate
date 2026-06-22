# TEST CASES — TASK-0139 (#550)

## 受入基準マッピング

| AC | TC |
|----|-----|
| AC-01: read -r 化（cmd_approve） | TC-01 |
| AC-02: read -r 化（maintenance L4） | TC-02 |
| AC-03: FAKE_PPID_COMM 本番ガード | TC-03 |
| AC-04: c3.json 上書き block（--force なし） | TC-04 |
| AC-05: ADR ファイル存在 | TC-05 |
| AC-06: ta-40 run-tests 認識 | TC-06 |
| AC-07: 既存テスト回帰 | TC-07 |

## テストケース一覧

### TC-01: cmd_approve read -r — backslash が展開されない

- 前提: `--reason` に backslash を含む入力（echo に依存しない）
- 期待: `_ap_reason` が `\` を保持する（展開されない）
- 種別: unit

### TC-02: maintenance read -r — L4 nonce の read が -r

- 確認方法: `grep 'read -r _ack\|read -r _ap_reason\|read -r _ap_conditions' bin/plangate`
- 期待: 3 行が -r 付きで存在
- 種別: static check

### TC-03: FAKE_PPID_COMM が PLANGATE_TEST_MODE 未設定時に L3 に影響しない

- 前提: `PLANGATE_FAKE_PPID_COMM=claude_agent` / `PLANGATE_TEST_MODE` 未設定
- 実行: presence gate の L3 判定を simulate
- 期待: `_pcomm` が実際の親プロセス名を使う（注入されない）
- 種別: unit

### TC-04: c3.json 上書き — --force なし → abort

- 前提: `approvals/c3.json` が既存
- 実行: `bin/plangate approve TASK-XXXX`（--force なし）
- 期待: exit 2（error メッセージ）、c3.json が変更されない
- 種別: unit

### TC-05: c3.json 上書き — --force 付き → 継続

- 前提: `approvals/c3.json` が既存
- 実行: `bin/plangate approve TASK-XXXX --force`
- 期待: 通常の presence gate に進む（abort しない）
- 種別: unit

### TC-06: ta-40 が run-tests.sh で認識

- 実行: `sh tests/run-tests.sh` | grep ta-40
- 期待: ta-40 の TC が出力に含まれる
- 種別: integration

### TC-07: 既存 approve テスト回帰 PASS

- 実行: `sh tests/run-tests.sh`（ta-15 等）
- 期待: FAKE_PPID 使用テストが PLANGATE_TEST_MODE=1 で引き続き PASS
- 種別: regression

## エッジケース

- `--force` と `--reject` の組み合わせ → overwrite block は APPROVED 経路のみか確認
- `PLANGATE_TEST_MODE=1` 単独（FAKE_PPID_COMM 未設定）→ L3 変化なし（副作用なし）
