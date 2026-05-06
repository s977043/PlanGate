# Handoff: TASK-0065 (v8.6.0 改善 PR4 / baseline 正式化)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 schema 存在 | `schemas/eval-baseline.schema.json` (draft-2020-12、$defs、additionalProperties:false 全層) | ✅ PASS |
| AC-02 既存 baseline 妥当 | `jsonschema.validate(2026-05-04-baseline.json, schema)` 成功 | ✅ PASS |
| AC-03 snapshot --dry-run 動作 | TASK-0059 で実行 → schema valid JSON 出力 | ✅ PASS |
| AC-04 snapshot --out 書き込み | `--out /tmp/...` で書き込み + relative path display | ✅ PASS |
| AC-05 privacy §4 negative | task に `file_path` を追加した baseline は schema reject 確認 | ✅ PASS |
| AC-06 doc 更新 | `2026-05-04-baseline.md` §7.1 自動再生成 + §8 schema link 加筆 | ✅ PASS |
| AC-07 ta-09 + 3 cases | 39 → **42 PASS** (D-2 valid / D-2 negative / C-3 dry-run schema valid) | ✅ PASS |
| AC-08 既存 regress なし | tests/hooks 48 PASS / 既存 ta-09 14 cases PASS 維持 | ✅ PASS |

**全 8/8 PASS**

## 2. 既知課題

なし。

## 3. V2 候補

- baseline 自動更新の CI 統合（毎月実行で baseline drift を可視化）
- baseline 比較 CLI（`bin/plangate baseline diff <file1> <file2>`）
- baseline schema validation を `validate-schemas` に統合
- profile 別の baseline 集合管理（claude-opus / sonnet / codex 等）

## 4. 妥協点

- `host_os` は `platform.system() + platform.release()` のみで、hostname / IP / username は emit しない（privacy §4 準拠）
- session_log_supplied は本実装では常に false。session log を含めた baseline は v8.7+ Eval expansion (#196) で対応予定
- snapshot script は `eval-runner.py` を subprocess で呼ぶため、eval-runner の出力フォーマット変更時は本 script も追随が必要
- snapshot 結果に `notes` を追加する場合は `--note` を repeatable として渡す

## 5. 引き継ぎ文書

新規:
- `schemas/eval-baseline.schema.json` (draft-2020-12、$defs/task / verdictOrNa、additionalProperties:false 全層)
- `scripts/baseline-snapshot.py` (executable、eval-runner subprocess 経由、出力は schema 妥当 JSON)
- `docs/working/TASK-0065/{pbi-input,plan,test-cases,handoff}.md`

修正:
- `tests/extras/ta-09-metrics.sh`: +3 cases (D-2 valid / D-2 negative / C-3 dry-run schema valid)
- `docs/ai/eval-baselines/2026-05-04-baseline.md`:
  - §7.1 自動再生成手順を新規追加
  - §8 で schema link を追加

## 6. テスト結果サマリ

- `tests/run-tests.sh`: **42 PASS** (39 → 42)
- `tests/hooks/run-tests.sh`: **48 PASS** (regression 0)
- 動作確認:
  - `python3 scripts/baseline-snapshot.py --dry-run --baseline-id 2026-05-06-test --release v8.6.0 --tasks TASK-0059` → schema valid JSON
  - 既存 `2026-05-04-baseline.json` が新 schema で valid
  - 不正な field（`file_path`）追加 baseline は jsonschema が reject
- 影響範囲: schema + script + test + doc 追加のみ、既存挙動 0 影響、privacy 強制 3 層は維持
