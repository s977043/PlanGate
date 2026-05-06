# Handoff: TASK-0066 (v8.6.0 改善 PR5 / 整合性検査強化)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 doctor v8.6.0 section | `bin/plangate doctor` 出力に「=== v8.6.0 Metrics & Privacy ===」+ 12 行のチェック含む | ✅ PASS |
| AC-02 events.ndjson gitignore check | doctor が `[PASS] docs/working/_metrics/events.ndjson is .gitignore-d` を出力 | ✅ PASS |
| AC-03 EH-8 executable check | doctor が `[PASS] EH-8 hook is executable` を出力 | ✅ PASS |
| AC-04 metrics --validate PASS | 5 valid events で `[PASS] all events valid` 出力 | ✅ PASS |
| AC-05 metrics --validate FAIL | forbidden field 追加で exit 1 + `[FAIL] line N: schema violation` | ✅ PASS |
| AC-06 schema_mapping J-1 | `2026-05-04-baseline.json` → `eval-baseline.schema.json` mapping 追加 | ✅ PASS |
| AC-07 validate-schemas integration | `validate-schemas.py docs/ai/eval-baselines/2026-05-04-baseline.json` → PASS=1 | ✅ PASS |
| AC-08 CI workflow 存在 | `.github/workflows/metrics-privacy.yml` 新規（85 行）| ✅ PASS |
| AC-09 ta-09 +4 cases | 42 → **46 PASS** (H-1×2 / J-1 / F-3) | ✅ PASS |
| AC-10 既存 regress なし | tests/hooks 48 PASS, ta-09 既存 17 cases PASS 維持 | ✅ PASS |

**全 10/10 PASS**

## 2. 既知課題

なし。

## 3. V2 候補

- `metrics --validate` を CI で全 events に対して実行（現状はローカル CLI のみ）
- `plangate doctor --json` で機械可読出力 (CI 統合用)
- baseline drift 自動検知（毎週 cron で snapshot 差分）
- schema validation の依存（jsonschema）を CI 同梱で確実化

## 4. 妥協点

- `metrics --validate` は heredoc 経由で python3 を呼ぶため inline。専用 script 化は将来候補
- CI workflow の Hook EH-8 strict 実行は PR / push 共に動くが、events.ndjson tracked 検出は `git ls-files --error-unmatch` ベース（fail-fast）
- doctor の EH-8 executable check は実ファイル属性のみ。setup.sh 等の install 時自動付与は v2

## 5. 引き継ぎ文書

修正:
- `bin/plangate`:
  - `cmd_doctor` に v8.6.0 セクション（12 check）追加
  - `cmd_metrics` に `--validate` モード追加（jsonschema validate）
  - help に `--validate` を反映
- `scripts/schema_mapping.py`: `2026-05-04-baseline.json` mapping 追加（NDJSON は CLI --validate で別途）
- `tests/extras/ta-09-metrics.sh`: +4 cases (H-1 valid/invalid, J-1, F-3)

新規:
- `.github/workflows/metrics-privacy.yml`: PR / push で events.ndjson tracked 検出 + Hook EH-8 strict 実行
- `docs/working/TASK-0066/{pbi-input,plan,test-cases,handoff}.md`

## 6. テスト結果サマリ

- `tests/run-tests.sh`: **46 PASS** (42 → 46)
- `tests/hooks/run-tests.sh`: **48 PASS** (regression 0)
- 動作確認:
  - `bin/plangate doctor` → v8.6.0 section に 12 check 全 PASS
  - `bin/plangate metrics --validate` → events.ndjson 不在時 INFO、5 events 時 PASS、forbidden 含で FAIL
  - `python3 scripts/validate-schemas.py docs/ai/eval-baselines/2026-05-04-baseline.json` → PASS=1
- 影響範囲: opt-in CLI 拡張 + 新 CI workflow、既存挙動 0 影響、privacy 強制は CI 層が追加されて 4 層に強化
