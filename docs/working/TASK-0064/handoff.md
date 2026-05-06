# Handoff: TASK-0064 (v8.6.0 改善 PR3 / metrics 自動化進化)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 hook_violation 自動 emit | ta-09 A-1: fixture audit log で hook_violation 2 件抽出 | ✅ PASS |
| AC-02 filter 動作 | PASS / BYPASS / 別 TASK の log は emit しないことを test | ✅ PASS |
| AC-03 hook_id mapping | `check-c3-approval` → `EH-2` 等、11 hook の固定マップ | ✅ PASS |
| AC-04 result mapping | VIOLATION → block, WARNING → warn | ✅ PASS |
| AC-05 pr_created 自動抽出 | TASK-0061 で `pr_number=208` 抽出を実機確認 | ✅ PASS |
| AC-06 schema 妥当 | jsonschema.validate を全 hook_violation event に通す test | ✅ PASS |
| AC-07 privacy §4 準拠 | audit log の message 列 / commit hash / branch / 著者は emit しない（schema additionalProperties:false が物理的に阻止）| ✅ PASS |
| AC-08 ta-09 拡張 | 34 → **39 PASS** (+5 cases) | ✅ PASS |
| AC-09 既存 regress なし | tests/hooks 48 PASS、既存 ta-09 9 cases も PASS 維持 | ✅ PASS |

**全 9/9 PASS**

## 2. 既知課題

なし。

## 3. V2 候補

- **c4_decided 自動取得**: GH API 必要（PR レビュー event 取得）。`gh api` が利用可能な環境では追加可能だが、network 依存 / rate limit / auth が絡むので scope 外に留めた
- audit log フォーマット v2 化（タブ区切り → JSON-Lines）→ message 列を構造化できれば更にフィールド追加余地
- 複数 TASK を一括 collect する `--all` オプション
- hook 側からの直接 NDJSON emit（audit log 経由を bypass する設計）

## 4. 妥協点

- pr_created は **handoff.md commit subject の `(#NN)` パターン依存**。non-squash merge / 別形式の merge commit からは抽出されない（silent skip）
- audit log を読む際、5 列未満の line は無視（古い format との互換性）
- subprocess が無い / git が無い環境では pr_created を silent skip（エラーにしない）

## 5. 引き継ぎ文書

修正:
- `scripts/metrics_collector.py`:
  - `HOOK_NAME_TO_ID` (11 entries)、`HOOK_LEVEL_TO_RESULT` (4 entries)、`GIT_COMMIT_PR_RE` を追加
  - `derive_hook_events()`、`derive_pr_event()` を新規追加
  - `derive_events()` 末尾で両者を呼び出し
- `tests/extras/ta-09-metrics.sh`: +5 cases (A-1 系)。fixture として一時 audit log を作成し、既存 audit log を backup / restore する trap を強化
- `docs/ai/metrics.md` §3.2 表に新 source 2 行追加、§3.3 / §3.4 を「自動取得済」へ書き換え

新規:
- `docs/working/TASK-0064/{pbi-input,plan,test-cases,handoff}.md`

## 6. テスト結果サマリ

- `tests/run-tests.sh`: **39 PASS** (34 → 39、+5 ta-09 cases)
- `tests/hooks/run-tests.sh`: **48 PASS** (regression 0)
- 動作確認:
  - `python3 scripts/metrics_collector.py TASK-0061 --dry-run` で `pr_created (#208)` を emit
  - `python3 scripts/metrics_collector.py TASK-0059 --dry-run` で `pr_created (#206)` を emit
  - 旧 hook_violation 手動 append 手順は `metrics.md` §3.3 末尾に「補助手段」として残置
- 影響範囲: opt-in 拡張のみ、既存挙動 0 影響、privacy 強制 3 層は全て維持
