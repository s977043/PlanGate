# テストケース定義 — TASK-1180

## 受入基準 → テストケース マッピング

| 受入基準 | テストケース |
|---------|-------------|
| AC-1（fixture が是正されている） | TC-01 |
| AC-2（SURVIVE → KILL の遷移） | TC-02 / TC-03 |
| AC-3（回帰なし） | TC-04 / TC-05 |
| AC-4（1 ファイル 1 行に閉じる） | TC-06 |

## テストケース一覧

### TC-01: fixture の是正

- **前提条件**: 作業ブランチが `origin/main` から作られている
- **入力**: `sed -n '229p' tests/extras/ta-69-distribution-checks.sh`
- **期待出力**: `_t69_skill "plugin/plangate/skills" "elsewhere" "shifted" "plugin side" || true`
- **種別**: 静的確認（自動化可）

### TC-02: 修正前は変異が SURVIVE する（検出力ゼロの証拠）

- **前提条件**: TC-C6 fixture が未修正（`plugin/pa/skills`）／変異 M2b 適用済
  （`_same_intra_root_path` が常に `True` を返す）
- **入力**: `bash tests/extras/ta-69-distribution-checks.sh`
- **期待出力**: `[PASS] TC-C6: same name at non-mirrored paths -> rc=1` かつ `27 passed, 0 failed`
- **種別**: 変異テスト（自動化可）

### TC-03: 修正後は変異が KILL される（検出力の回復）

- **前提条件**: TC-C6 fixture が修正済／変異 M2b 適用済
- **入力**: `bash tests/extras/ta-69-distribution-checks.sh`
- **期待出力**: `[FAIL] TC-C6: expected rc=1 for a non-mirrored same-name pair, got 0`
  かつ `26 passed, 1 failed`
- **種別**: 変異テスト（自動化可）

### TC-04: 修正後 baseline に回帰がない

- **前提条件**: TC-C6 fixture が修正済／変異が revert 済
- **入力**: `bash tests/extras/ta-69-distribution-checks.sh`
- **期待出力**: `TA-69 standalone: 27 passed, 0 failed`
- **種別**: 回帰テスト（自動化可）

### TC-05: harness 経路（sourced）でも回帰がない

- **前提条件**: 同上
- **入力**: `bash tests/run-tests.sh`
- **期待出力**: 失敗 0 件（ta-69 が sourced モードでも通る）
- **種別**: 回帰テスト（自動化可）

### TC-06: 変更範囲が閉じている

- **前提条件**: 検証完了後
- **入力**: `git diff --name-only origin/main` / `git diff --stat origin/main`
- **期待出力**: `tests/extras/ta-69-distribution-checks.sh` のみ、`1 insertion(+), 1 deletion(-)`
- **種別**: 静的確認（自動化可）

## エッジケース

| ケース | 扱い |
|-------|------|
| :204（TC-C4）/ :216（TC-C5）の `plugin/pa` | **修正しない**。`plugin/pa` + `plugin/pb` の対で plugin 同士の衝突を測る意図的な fixture |
| 変異の revert 忘れ | TC-06 の `git diff --name-only` で検出する（本番コードが出たら FAIL） |
| 他者の未 commit 変更（`docs/working/_audit/skip-decision-log.jsonl`） | commit 対象に含めない。`git diff --cached` で混入なしを実測 |
| 空 sandbox による恒真 PASS | ta-69 の `_t69_assert_defs` が TC-C6 の前提（定義 2 件）を明示検証済み |
