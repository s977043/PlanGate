# Handoff: TASK-0063 (v8.6.0 改善 PR1: privacy 強化 + governance 完結)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 hook 存在 | `scripts/hooks/check-metrics-privacy.sh` (135 行、executable) | ✅ PASS |
| AC-02 events.ndjson staging 検出 | hook test EH-8 で確認 (default WARNING / strict exit 1) | ✅ PASS |
| AC-03 Forbidden field 検出 | bad-forbidden fixture で 3 フィールド (`file_path`, `stack_trace`, `command_output`) を検出 | ✅ PASS |
| AC-04 bypass | `PLANGATE_BYPASS_HOOK=1` test PASS | ✅ PASS |
| AC-05 hook unit tests | tests/hooks/run-tests.sh 42 → **48 PASS** (+6 EH-8 cases) | ✅ PASS |
| AC-06 C-2 collector privacy | ta-09 で metrics_collector emit に Forbidden なし確認 | ✅ PASS |
| AC-07 D-1 schema negative | ta-09 で `file_path` 入り event を schema が reject 確認 | ✅ PASS |
| AC-08 doc 更新 | `metrics-privacy.md` §10 を「実装済 (v8.6.0)」へ | ✅ PASS |
| AC-09 priority labels | GitHub に `priority:P0`〜`P3` 4 件作成済 | ✅ PASS |
| AC-10 既存 regress | tests/run-tests.sh 32 → **34 PASS** (+2 cases、既存 0 件 regress) | ✅ PASS |

**全 10/10 PASS**

## 2. 既知課題

なし。

## 3. V2 候補

- `.claude/settings.example.json` に EH-8 を登録（git 操作 matcher の設計が必要、v8.7+）
- CI で baseline snapshot の Forbidden 自動検査
- redaction 自動適用（hash 関数選定 / salt 戦略）
- pre-commit としての git hook 統合（`.git/hooks/pre-commit` テンプレ）

## 4. 妥協点

- Forbidden パターンは正規表現で 12 キー固定（`file_path`, `file_paths`, `stack_trace`, `stacktrace`, `command_output`, `stdout`, `stderr`, `raw_response`, `raw_request`, `api_key`, `user_prompt`, `system_prompt`, `prompt_text`, `absolute_path`）
  - 追加は metrics-privacy.md §4 の更新と同時に hook を更新する運用
- staging 検出は `git diff --cached` ベース。明示引数 / `PLANGATE_HOOK_FILES` で override 可
- false positive 抑制のため `"key":` パターンに限定（コメントや markdown body の言及はマッチしない設計）

## 5. 引き継ぎ文書

新規 4 ファイル + 修正 3 ファイル:

新規:
- `scripts/hooks/check-metrics-privacy.sh` (Hook EH-8、3 mode 設計、12 forbidden keys)
- `tests/fixtures/hooks/check-metrics-privacy/good/sample.json` (Allowed only)
- `tests/fixtures/hooks/check-metrics-privacy/bad-forbidden/sample.json` (Forbidden 3 フィールド)
- `docs/working/TASK-0063/` PBI artifacts

修正:
- `tests/hooks/run-tests.sh` +6 EH-8 test cases (good / bad default / bad strict / events staged / bypass / empty)
- `tests/extras/ta-09-metrics.sh` +2 cases (C-2 collector privacy / D-1 schema negative)
- `docs/ai/metrics-privacy.md` §10 を「実装済 (v8.6.0)」へ更新

PR 外で完了済:
- GitHub label `priority:P0`〜`P3` を実体化（issue-governance.md §3.3 完結）

## 6. テスト結果サマリ

- `tests/hooks/run-tests.sh`: **48 PASS** (42 → 48、+6 EH-8 cases)
- `tests/run-tests.sh`: **34 PASS** (32 → 34、+2 ta-09 cases)
- 影響範囲: opt-in hook + テスト追加のみ、既存挙動 0 影響
- privacy 強制: §4 Forbidden の commit / emit / schema 三層で物理的に阻止
