# PBI INPUT PACKAGE: TASK-0065 (v8.6.0 改善 PR4)

## Why
PR #208 で導入した baseline.json は doc レベルの構造定義のみで、JSON Schema が未整備。再生成も手動。後続 PBI-HI-002 (#196 Eval expansion) で baseline を機械的に比較対象とするには、schema による形式保証 + 自動再生成スクリプトが必要。

## What
- C-1: schemas/eval-baseline.schema.json 新設
- C-3: scripts/baseline-snapshot.py 新設（代表 TASK 集合 → baseline JSON 自動生成）
- D-2: ta-09 で baseline schema validation テスト追加

## Mode
high-risk（schema + script + tests + doc）

## AC
- [ ] schemas/eval-baseline.schema.json 存在、$schema / $id / required / additionalProperties:false 設定
- [ ] 既存 2026-05-04-baseline.json が新 schema で valid
- [ ] scripts/baseline-snapshot.py が --dry-run / --out 対応
- [ ] snapshot 出力が schema 妥当
- [ ] privacy §4 違反なし（host_os は platform.system + release のみ）
- [ ] ta-09 で baseline schema valid / negative / snapshot dry-run の 3 case 追加
- [ ] eval-baselines/2026-05-04-baseline.md §7.1 §8 に schema / 再生成手順を記載
- [ ] 既存テスト 0 件 regress
