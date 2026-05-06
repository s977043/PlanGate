# PBI INPUT PACKAGE: TASK-0063 (v8.6.0 改善 PR1)

## Why

v8.6.0 で Metrics v1 (#195) と Privacy Policy (#202) を導入したが、policy の **実効強制** が doc レベルに留まっていた。`metrics-privacy.md` §10 では pre-commit hook 等を「v8.7+ 候補」と位置付けていたが、policy 違反は本 v8.6.0 範囲で物理的に防ぐべきリスク。

加えて、issue-governance.md §3.3 で定義した `priority:P0`〜`P3` ラベルが GitHub 上に未作成だった。

本 PBI では v8.6.0 範囲の改善として、privacy 強制と governance 完結を行う。

## What

In scope:
- A-3: `scripts/hooks/check-metrics-privacy.sh` 新規（events.ndjson staging 検出 + Forbidden field 検出）
- C-2: `tests/extras/ta-09-metrics.sh` に「emit される event に Forbidden field なし」test 追加
- D-1: `tests/extras/ta-09-metrics.sh` に schema negative test 追加（Forbidden field 入り event は schema validation で reject）
- A-4: GitHub label `priority:P0`〜`P3` を実体化（PR 外で完了済）
- doc: `metrics-privacy.md` §10 を「v8.6.0 実装済」へ更新

Out of scope:
- settings.example.json への EH-8 登録（git 操作 matcher の設計が必要、v8.7+）
- redaction 自動適用（PBI-HI-001 V2 候補）
- CI で baseline snapshot の Forbidden 自動検査（v8.7+）
- 完全 DLP / 暗号化ストレージ / 外部 DB（明示的 Non-goal）

## AC

- [ ] `scripts/hooks/check-metrics-privacy.sh` が存在する
- [ ] hook が events.ndjson staging を検出する（default: WARNING / strict: BLOCK）
- [ ] hook が JSON / NDJSON 内の Forbidden field を検出する（同上）
- [ ] `PLANGATE_BYPASS_HOOK=1` で bypass できる
- [ ] `tests/hooks/run-tests.sh` に EH-8 test 追加（6 cases）
- [ ] `tests/extras/ta-09-metrics.sh` で C-2 (collector が Forbidden を emit しない) を検証
- [ ] `tests/extras/ta-09-metrics.sh` で D-1 (schema が Forbidden を reject) を検証
- [ ] `metrics-privacy.md` §10 が実装済の現状を反映している
- [ ] GitHub `priority:P0`〜`P3` ラベルが存在する
- [ ] 既存テスト 0 件 regress

## Mode 判定

high-risk（hook 新規 + テスト追加 + doc 更新、policy 強制力の追加）
