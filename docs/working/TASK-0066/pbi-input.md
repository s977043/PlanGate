# PBI INPUT PACKAGE: TASK-0066 (v8.6.0 改善 PR5)

## Why
PR1〜PR4 で v8.6.0 機能の privacy 強制と自動化を整えたが、整合性検査の **常時運用** が未整備だった。
- `bin/plangate doctor` が v8.6.0 機能を見ない
- events.ndjson の整合性を CLI から確認する手段がない
- `validate-schemas` が baseline.json を見ていない
- Hook EH-8 が CI で動いていない

本 PBI で 4 改善を 1 PR にまとめる。

## What
- F-3: bin/plangate doctor 拡張（v8.6.0 セクション、12 check）
- H-1: bin/plangate metrics --validate 追加
- J-1: schema_mapping.py に eval-baseline.schema.json 追加
- E-4: .github/workflows/metrics-privacy.yml 新設（Hook EH-8 を CI 強制）

## Mode
high-risk（CLI 拡張 + CI workflow 新設、ただし opt-in / additive）

## AC
- [ ] doctor に v8.6.0 セクションが追加され、PASS / FAIL を報告する
- [ ] doctor が events.ndjson の gitignore 状態を検査する
- [ ] doctor が EH-8 hook の executable を検査する
- [ ] metrics --validate が valid events で PASS、forbidden field で exit 1
- [ ] schema_mapping.py に baseline mapping が登録され、validate-schemas で baseline.json が検査される
- [ ] .github/workflows/metrics-privacy.yml が Hook EH-8 を strict mode で実行
- [ ] CI workflow が events.ndjson tracked を検出して fail する
- [ ] tests/extras/ta-09 に H-1 / J-1 / F-3 cases 追加（4 cases）
- [ ] 既存テスト 0 件 regress
