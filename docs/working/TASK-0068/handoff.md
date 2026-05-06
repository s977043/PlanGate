# Handoff: TASK-0068 (v8.6.0 改善 PR7 / 機械可読化 + 自動化)

## 1. 要件適合確認結果

| AC | 検証 | 判定 |
|----|------|------|
| AC-01 --markdown-section 構造 | "## 7. Metrics summary" / 観点表 / by_mode 表 / privacy 注記を確認 | ✅ PASS |
| AC-02 --markdown-section privacy 注記 | "Privacy: §3 Allowed only. See `docs/ai/metrics-privacy.md`." 含む | ✅ PASS |
| AC-03 --since ISO datetime / YYYY-MM-DD 両対応 | YYYY-MM-DD 略記時に T00:00:00Z 補完 | ✅ PASS |
| AC-04 --since 範囲外 event_count=0 | --since 2030-01-01 で 0 (元 7) | ✅ PASS |
| AC-05 --since 範囲内 全 event 維持 | --since 2026-01-01 で 7 (元 7) | ✅ PASS |
| AC-06 doctor --json scope/checks/failures/passed | 16 checks / passed=True を JSON で出力 | ✅ PASS |
| AC-07 doctor --json failures>0 で exit 1 | doctor_check.py の return code logic で保証 | ✅ PASS |
| AC-08 handoff template 例追記 | "--markdown-section" コマンド例を §7 に追加 | ✅ PASS |
| AC-09 metrics.md §3.7 | K-1/K-2/K-3 解説を追記 | ✅ PASS |
| AC-10 ta-09 +5 cases | 48 → **52 PASS** (K-1 / K-2×2 / K-3 / [追加で earlier H-3 keep]) | ✅ PASS |
| AC-11 既存 regress なし | tests/hooks 48 PASS / 既存 ta-09 23 cases PASS 維持 | ✅ PASS |

**全 11/11 PASS**

## 2. 既知課題

なし。

## 3. V2 候補

- `--since` の相対指定（`-7d` / `last-week` 等）
- doctor --json で全セクション (CLI Tools / Plugin / Required Files / Rules / Optional Provider) を網羅
- handoff §7 自動挿入を `bin/plangate metrics --inject-handoff <TASK>` で実現
- baseline drift 検知 cron の出力に doctor --json を統合（CI 単一エンドポイント化）

## 4. 妥協点

- `doctor --json` は v8.6.0 metrics & privacy セクション **16 check** に限定。他セクションの JSON 化は v2 候補
- `--markdown-section` は `--json` と排他（同時指定時は markdown を優先）
- `--since` の最大解像度は秒（ts も秒精度）。ms / 比較演算子 (>/<=) は v2

## 5. 引き継ぎ文書

新規:
- `scripts/doctor_check.py` (executable、16 check、scope=v8.6.0 固定)
- `docs/working/TASK-0068/{pbi-input,plan,test-cases,handoff}.md`

修正:
- `scripts/metrics_reporter.py`:
  - `render_markdown_section()` を新設（handoff §7 用 markdown 表）
  - `filter_since()` を新設（YYYY-MM-DD 略記対応）
  - argparse に `--markdown-section` / `--since` 追加
  - main() の出力分岐に markdown を優先順位最上位で配置
- `bin/plangate`:
  - `cmd_doctor` 冒頭で `--json` フラグを早期検出して python script へリダイレクト
  - `cmd_metrics` の usage / passthrough に `--markdown-section` / `--since` を追加
- `docs/working/templates/handoff.md` §7 に `--markdown-section` コマンド例を追記
- `docs/ai/metrics.md` §3.7 (K-1/K-2/K-3 解説) を追記
- `tests/extras/ta-09-metrics.sh`: +5 cases (markdown / since 範囲外/内 / since 略記 / doctor --json)

## 6. テスト結果サマリ

- `tests/run-tests.sh`: **52 PASS** (48 → 52)
- `tests/hooks/run-tests.sh`: **48 PASS** (regression 0)
- 動作確認:
  - `bin/plangate metrics --report --aggregate --markdown-section` → handoff §7 形式 markdown
  - `bin/plangate metrics --report --aggregate --since 2030-01-01` → events 0
  - `bin/plangate metrics --report --aggregate --since 2026-01-01` → 全 events 残存
  - `bin/plangate doctor --json` → 16 check JSON、passed=True、exit 0
- 影響範囲: opt-in CLI 拡張のみ、既存挙動 0 影響、privacy 強制 4 層は維持
