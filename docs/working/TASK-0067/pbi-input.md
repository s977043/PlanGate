# PBI INPUT PACKAGE: TASK-0067 (v8.6.0 改善 PR6)

## Why
PR1〜PR5 で privacy / metrics 自動化 / baseline / 整合性検査を整えたが、ワークフロー成果物（handoff / current-state）と AI agent 入口（CLAUDE.md）への組込みが不足。さらに reporter は集計を mode 別に分けないため、harness 変更を mode で比較するのが手動だった。

## What
- F-1: handoff template に「7. Metrics summary」セクション追加（任意項目）
- F-2: current-state template に metrics サブセクション追加
- H-3: metrics_reporter.py の summary に by_mode (TASK の mode を解決して C-3/V-1/C-4/hook を mode 別集計、V-1 PASS rate %)
- H-3 prerequisite: metrics_collector.py の mode regex 強化（"## Mode 判定" / "## Mode\nlight" 形式に対応）
- I-1: CLAUDE.md に v8.6.0 機能サマリ追加（metrics / privacy / governance / baseline / hook EH-8 / doctor / templates）

## Mode
high-risk（reporter ロジック追加 + collector regex 改善 + テンプレ + CLAUDE.md）

## AC
- [ ] handoff template に §7 Metrics summary
- [ ] current-state template に Metrics スナップショット節
- [ ] reporter --aggregate text に By mode (H-3) 節
- [ ] reporter --json で by_mode キー
- [ ] collector が "## Mode 判定" / "## Mode\nlight" 形式で mode 抽出
- [ ] CLAUDE.md に v8.6.0 機能サマリリンク
- [ ] tests/extras/ta-09 +2 cases (H-3 text / H-3 json)
- [ ] 既存テスト 0 件 regress
