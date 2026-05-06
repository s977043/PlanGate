# Handoff: TASK-0067 (v8.6.0 改善 PR6 / workflow 統合 + observability)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 handoff §7 Metrics summary | template に「7. Metrics summary（v8.6.0+、任意）」追加 | ✅ PASS |
| AC-02 current-state Metrics スナップショット | 「## Metrics スナップショット（v8.6.0+、任意）」節追加 | ✅ PASS |
| AC-03 reporter text by_mode | `--aggregate` 出力に「By mode (H-3)」節を確認 | ✅ PASS |
| AC-04 reporter json by_mode | `--json --aggregate` 出力に `by_mode` キー含む | ✅ PASS |
| AC-05 collector mode regex 強化 | TASK-0059 / 0061 で `mode=light` を抽出 | ✅ PASS |
| AC-06 CLAUDE.md v8.6.0 section | 「v8.6.0 Metrics & Governance」セクション追加 + 8 リンク | ✅ PASS |
| AC-07 metrics.md 加筆 | §3.5 mode 別集計 / §3.6 整合性検証を追記 | ✅ PASS |
| AC-08 ta-09 +2 cases | 46 → **48 PASS** (H-3 text / H-3 json) | ✅ PASS |
| AC-09 既存 regress なし | tests/hooks 48 PASS / 既存 21 cases PASS 維持 | ✅ PASS |

**全 9/9 PASS**

## 2. 既知課題

なし。

## 3. V2 候補

- handoff §7 を `bin/plangate metrics --report --markdown-section` 等で自動挿入
- current-state を session start / end hook で metrics スナップショットを自動更新
- by_mode に approval_discipline / verification_honesty 等の eval 観点を追加（PBI-HI-002 / #196 と連動）
- CLAUDE.md v8.6.0 セクションの自動同期（リリース毎に更新）

## 4. 妥協点

- reporter の by_mode は **TASK ID → mode を index 化** してから集計するため、plan_generated event が無い old TASK は集計対象外（mode 不明）
- collector の mode regex は 3 形式（`**モード**` / `## Mode 判定` / `## Mode` 直下）に対応。それ以外は最初の light/standard/...キーワードで fallback
- handoff §7 / current-state Metrics 節は任意。強制ではない（既存運用と互換）

## 5. 引き継ぎ文書

修正:
- `scripts/metrics_reporter.py`:
  - `summarize()` に `by_mode` bucket（C-3 / V-1 / C-4 / hook_violations）と V-1 PASS rate (%)
  - TASK ID → mode index による正確な mode 解決
  - `render_text()` に「## By mode (H-3)」節
- `scripts/metrics_collector.py`:
  - mode regex を 3 形式対応 + fallback で強化（後方互換維持）
  - `ev["mode"]` を lowercase 化
- `docs/working/templates/handoff.md`: §7 Metrics summary 追加
- `docs/working/templates/current-state.md`: Metrics スナップショット節追加
- `CLAUDE.md`: v8.6.0 Metrics & Governance セクション（8 リンク）
- `docs/ai/metrics.md`: §3.5 mode 別集計 / §3.6 整合性検証
- `tests/extras/ta-09-metrics.sh`: +2 cases (H-3 text / H-3 json)

新規:
- `docs/working/TASK-0067/{pbi-input,plan,test-cases,handoff}.md`

## 6. テスト結果サマリ

- `tests/run-tests.sh`: **48 PASS** (46 → 48)
- `tests/hooks/run-tests.sh`: **48 PASS** (regression 0)
- 動作確認:
  - TASK-0059 / 0061 collect → mode=light が events.ndjson に記録
  - `--report --aggregate` → "By mode (H-3)" + V-1 PASS rate (%)
  - `--report --aggregate --json` → `summary.by_mode` キー
  - `bin/plangate doctor` → v8.6.0 セクション全 PASS
- 影響範囲: opt-in 拡張のみ（既存挙動 0 影響、template は任意項目、reporter 既存 fields は維持）
