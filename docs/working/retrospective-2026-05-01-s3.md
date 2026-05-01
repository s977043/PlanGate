# 振り返り 2026-05-01 (s3): #168 session log parser + v8.4.0 リリース

> 対象 PR: [#178](https://github.com/s977043/PlanGate/pull/178) / [#179](https://github.com/s977043/PlanGate/pull/179)
> Issue: [#168](https://github.com/s977043/plangate/issues/168)（CLOSED）
> リリース: [v8.4.0](https://github.com/s977043/PlanGate/releases/tag/v8.4.0)
> 期間: 2026-05-01（同日 3 セッション目、Auto Mode）

## サマリ

直前 retrospective（s2）で残していた V2 候補 2 件（#168 / #169）のうち **#168 session log NDJSON parser** を完走（high-risk 想定 → standard で実装）。さらに v8.3.0 以降の累積 18 PR を **v8.4.0 リリース**として節目化、CHANGELOG / git tag / GitHub Release を発行。残 1 件（#169）は v8.5 候補へ送付。

| 指標 | 値 |
|------|---|
| 完了 PBI | **1**（TASK-0054 / #168）|
| マージ PR | **2 件**（#178 実装 + #179 release）|
| Issue auto-close | **1 件**（#168）|
| **新規 release tag** | **v8.4.0**（plangate 0.1.0 → 0.2.0、eval-runner 1.0.0 → 1.2.0）|
| ローカル test | 21 → **24 件 PASS**（+ TA-08 3 件）|
| 同日累計（s1〜s3） | **20 PR マージ / 11 Issue close / 12 PBI 完走** |

## 対応マッピング

| Issue | PR | TASK | mode | 主成果物 |
|-------|----|----|------|---------|
| #168 | #178 | TASK-0054 | high-risk → standard | scripts/parsers/codex_log_parser.py + eval-runner `--session-log` + 24 件 PASS |
| — | #179 | — | release | CHANGELOG v8.4.0 章 + bin/plangate v0.2.0 + tag v8.4.0 + GitHub Release |

## Keep（うまくいったこと）

### K-1. high-risk → standard への scope 縮減判断が機能した

#168 は当初 high-risk（codex / claude-cli 両方の log parser を要求）想定だったが、実物調査で **claude-cli session log（`~/.claude/sessions/*.json`）には対話履歴が含まれない**ことが判明 → claude-cli 対応を v2 candidate に分離して codex のみ scope 縮減。Phase 1 の調査時間（10 分程度）が scope 確定の精度を大きく上げた。**実物先・推測後の原則**が活きた。

### K-2. v8.4.0 リリースで 18 PR の累積を節目化できた

v8.3.0（仕様）→ v8.4.0（実装）への昇格は、内容として overdue だった。CHANGELOG にカテゴリ別整理（Added / Changed / Fixed / DX / Process Notes / Next EPIC）で記録、release notes は CHANGELOG 抽出で gh release に一発投入。**release ハンドリングの軽量化**が実証された。

### K-3. set -e + command substitution + python interaction の hang を回避できた

TA-08（codex log parser テスト）の初版で trap + command substitution の組み合わせが原因不明の途中停止を起こした。**`out=$(... 2>&1) && rc=0 || rc=$?` で exit code を明示捕捉**、trap を使わずに rm 直接、というシンプル化で解決。今後の TA-NN 追加で再現するアンチパターンを記録できた。

### K-4. `_render_latency_line` ヘルパで Markdown / JSON の二重メンテを避けた

eval-result.json と eval-result.md の latency セクションは内容同一だが表現が異なる。ヘルパ関数化することで、表現変更時の修正箇所が 1 つに集約。次の metrics 追加時もパターンを踏襲しやすい。

### K-5. retrospective Try → V2 issue → 実装 → リリースのフルサイクルが 1 日で回った

s1 で起票した V2 候補 6 件のうち 5 件（#167 / #168 / #170 / #171 / #172）が同日中に解消し、v8.4.0 リリースに乗った。残 1 件（#169）は明示的に v8.5 候補として送付済。**「振り返り → 課題化 → 解消 → リリース」が 1 日 1 サイクル**で回った日として記録。

## Problem（課題・反省）

### P-1. tests/extras/ 分離はあったが、新規 TA 追加でなお set -e トラブルが起きた

#170（s2）で tests/extras/ 分離は完了したが、**個別 extras ファイル内の set -e 互換性は別問題**だった。今回 TA-08 の初版で trap + command substitution が干渉し python3 が exit すると外側 run-tests.sh が早期終了する現象。

**対策**: tests/extras/README.md に「source される前提のため `set -e` 互換: command substitution は `&&/||` で exit code 捕捉、trap は使わない」を追記する V2 候補（軽量、別 PBI）。

### P-2. claude-cli session log の保存場所が未調査

`~/.claude/sessions/*.json` に対話履歴がないことは確認できたが、**実際にどこにあるか**は調査未着手（`~/.claude/projects/...` 配下 or 別の path）。#168 v2 候補として残しているが、調査着手時の出発点が不明確。

**対策**: 次回 #168 v2 着手時にまず `find ~/.claude -type f -newer ... 2>/dev/null` で書き込み中ファイルを特定するなどの **発見プロトコル** を memory に記録。

### P-3. release PR の事前 dry-run / staging がなかった

v8.4.0 release PR を出すとき、CHANGELOG 編集 → version bump のみで PR 化したが、**release notes の自動抽出（awk）を本番で初めて試した**。幸い grep / awk が一発で動いたが、release ごとに awk パターンが安定動作する保証はない。

**対策**: `scripts/release-notes-extract.sh`（CHANGELOG → notes 抽出スクリプト）を別 PBI で作成、tests/extras/ に動作確認テストを追加（V2 候補）。

### P-4. v8.4.0 release は CHANGELOG + tag + Release のみで、検証実行（smoke test）がなかった

リリース後に `bin/plangate eval / validate-schemas / version` の動作確認を CI でも、smoke test でも自動化していない。手動確認した version のみ。**release validation が手薄**。

**対策**: `tests/smoke/release-v*.sh` で release tag を `git checkout` して全 CLI を `--help` 経由で叩く smoke を追加（V2 候補、release ごとに自動実行）。

## Try（次にやること）

### T-1. 残 #169（残 Hook 実装）の段階分割実行

EH-1 / EH-3〜EH-7 / EHS-1 = 7 hook を 3 セッションに分割推奨:
- セッション A: EH-1 + EH-3（plan.md 検査 + plan_hash 改竄検知、PreToolUse 系）
- セッション B: EH-4 + EH-5 + EH-6（test-cases / verification / forbidden_files、CLI + PreToolUse）
- セッション C: EH-7 + EHS-1（branch protection + V-3 必須化、外部システム連携）

優先度 **High**（v8.5 milestone の中核）。

### T-2. tests/extras/ のベストプラクティス追記

P-1 の対応。`tests/extras/README.md` に「set -e 互換書法」「trap 利用禁止」「exit code 捕捉パターン」を 1 セクション追記。優先度 **Low**（運用知見、軽量）。

### T-3. release-notes 抽出 + smoke test の自動化

P-3 / P-4 の対応。`scripts/release-notes-extract.sh` + `tests/smoke/release-v*.sh` を 1 PBI で実装。優先度 **Low**（次 release までに実装すれば十分）。

### T-4. claude-cli session log の発見プロトコル記録

P-2 の対応。memory に「次回 #168 v2 着手時の出発点」として記録。優先度 **Medium**（#168 v2 着手の前提）。

### T-5. v8.4.0 リリース後のメトリクス測定

`bin/plangate eval` を実 PBI（v8.4.0 配下 11 件）に対して走らせ、format adherence / approval discipline / AC coverage の数値を baseline-2 として記録。**v8.4 baseline** として `eval-comparison-template.md` に追加。優先度 **Medium**（#168 v2 と相互補完）。

## メトリクス

| 指標 | s3 単独 | 同日累計（s1〜s3）|
|------|--------|----------------|
| 計画 PR 数 | 2 | 17 |
| 計画外 PR | 0 | 0 |
| マージコンフリクト | 0 件 | 5 件（s1 で 3、s2 で 0、s3 で 0、tests/extras/ 効果実証）|
| handoff 必須 6 要素完備率 | 1/1 = 100% | **11/11 = 100%** |
| ローカル test PASS 率 | 24/24 = 100% | 24/24 = 100%（ピーク） |
| CI 緑率 | 2/2 = 100% | **20/20 = 100%** |
| Issue auto-close 率 | 1/1 = 100% | **11/11 = 100%** |
| **新 release tag** | **v8.4.0** | v8.3.0 → v8.4.0 |

## 関連リンク

- 親 retrospective: [`docs/working/retrospective-2026-05-01.md`](retrospective-2026-05-01.md) / [`-s2.md`](retrospective-2026-05-01-s2.md)
- マージ済 PR: #178 / #179
- 完了 PBI: TASK-0054
- 主要成果物:
  - [`scripts/parsers/codex_log_parser.py`](../../scripts/parsers/codex_log_parser.py)
  - [`bin/plangate eval --session-log`](../../bin/plangate)
  - [`tests/fixtures/codex-log/sample.jsonl`](../../tests/fixtures/codex-log/sample.jsonl)
- v8.4.0 リリース: <https://github.com/s977043/PlanGate/releases/tag/v8.4.0>
- 残 V2 issue: [#169](https://github.com/s977043/plangate/issues/169)（v8.5 候補）

## 同日累計のハイライト（s1〜s3）

| カテゴリ | 値 |
|---------|---|
| 完走 PBI | **12 件**（TASK-0045〜0054 + 既存 1 件 + retrospective × 3）|
| マージ PR | **20 件**（#161〜#179）|
| Issue closed | **11 件**（#155〜#159 + #167〜#172）|
| 新 V2 起票 → 同日解消 | 5 件（#167 / #170 / #171 / #172 / #168）|
| 残 Open | **#169 のみ**（v8.5 候補）|
| 新 CI workflow | 2（schema-validate / check-pr-issue-link）|
| 新 CLI コマンド | 2（validate-schemas / eval）|
| 新 hook | 3（EH-2 / EHS-2 / EHS-3）+ shim 1 |
| ローカル test | **10 → 24 件**（240% 増）|
| **release** | v8.3.0 → **v8.4.0** |
