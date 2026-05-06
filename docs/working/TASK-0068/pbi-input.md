# PBI INPUT PACKAGE: TASK-0068 (v8.6.0 改善 PR7)

## Why
PR1〜6 で機能を整えたが、機械的な再利用と自動化が不足。
- handoff §7 を毎回手書きするのは負担（reporter から自動生成すべき）
- baseline 比較や週次レポートで「特定期間」の絞り込みができない
- doctor 結果が人間可読のみで CI から扱いにくい

## What
- K-1: metrics_reporter.py に --markdown-section オプション（handoff §7 用）
- K-2: --since <date> フィルタ（ISO date / YYYY-MM-DD 略記対応）
- K-3: scripts/doctor_check.py + bin/plangate doctor --json（v8.6.0 セクション 16 check の機械可読出力）

## Mode
high-risk（reporter / doctor 拡張、CLI 表面拡張）

## AC
- [ ] reporter --markdown-section で handoff §7 markdown 出力
- [ ] markdown 出力に privacy 注記が含まれる
- [ ] reporter --since が ISO datetime / YYYY-MM-DD 両対応
- [ ] --since 範囲外で event_count が 0
- [ ] --since 範囲内で全 event 維持
- [ ] doctor --json で JSON 出力 + scope/checks/failures/passed
- [ ] doctor --json failures > 0 で exit 1
- [ ] handoff template に --markdown-section 例を追記
- [ ] metrics.md §3.7 で K-1/K-2/K-3 を解説
- [ ] tests/extras/ta-09 +5 cases (K-1 / K-2×2 / K-3 / [既存] H-3)
- [ ] 既存テスト 0 件 regress
