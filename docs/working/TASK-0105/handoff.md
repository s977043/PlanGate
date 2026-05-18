# Handoff — TASK-0105 / #282 check-plan-hash.sh 不正JSON strict 化
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 strict 抽出（sed 廃止・plan_hash_util 意味一致）| PASS |
| AC2 ta-11 全 parity（正常/注入/無/不正JSON）| PASS（4/4）|
| AC3 EH-3 回帰なし（正常PASS/改竄BLOCK exit1/no-task SKIP）| PASS（実リポジトリ a/b/c + run-tests 68/0 + hooks 77/0）|
| AC4 python3 可搬性（:108 既出依存）| PASS |
| AC5 承認境界=安全側を hook-enforcement.md 明記 | PASS |
V-1 全 PASS。V-3（Codex・承認境界厳格評価）APPROVE・critical/major 0・minor 1 反映。

## 2. 経緯
ユーザーが「EH-3 承認境界変更として #282 着手」を明示承認（Human トリガ・
Codex が要件としていた条件成立）。設計メモ（#282 issue コメント）通り実装。
V-3 で ta-11 冒頭コメント旧仕様矛盾/未使用関数を是正。

## 3. 既知課題 / V2
- 「不正 c3 を作って EH-3 を回避」する経路は EH-3 単体でなく c3 発行 /
  schema validation / 承認ファイル保護側の境界（Codex 指摘・別領域）。
- shell→Python util の意味一致は inline 再実装（shell から import 困難）。
  ta-11 が両者 parity を契約固定し drift を検出。

## 4. 妥協点
- 抽出のみ strict 化（block/warn 判定・plan_hash 形式・c3 schema・util は不変）。
- python3 heredoc は fail-open（空→SKIP）だが repo 全体 Python 前提・:108 前例。
- **意図的に inline 維持（plan_hash_util.py を import しない）**。#285
  gemini-code-assist が DRY 重複排除（util 直接 import）を minor 指摘したが
  **不採用**。EH-3 は承認境界の実行正本であり、`scripts/plan_hash_util.py`
  への import 依存を足すと「util の移動/削除/構文エラー/path 解決ミス →
  import 失敗 → 空 → 黙って SKIP」で承認境界の検知可用性が低下する
  （inline は `python3 + stdlib json` のみで自己完結＝より堅牢）。
  重複は ~10 行・minor で DRY の実利は限定的（YAGNI）。plan_hash_util.py
  docstring の Non-goal「EH-3 shell 実行経路は変更しない」とも整合。
  `plan_hash_util` との意味一致は **ta-11 が parity 契約で固定**。将来
  hook import 方針を正式化する場合は plan_hash_util.py docstring の
  「EH-3 shell 正本」前提も同時更新すること（Codex 相談合意・V-3 補強）。

## 5. 引き継ぎ
#282 完遂。check-plan-hash.sh の plan_hash 抽出を寛容 sed→strict python
（plan_hash_util.recorded_plan_hash 意味一致）。不正/欠落/非object/prefix
不一致は空＝SKIP（不正な承認記録を改竄検知の根拠にしない安全側）。正常
PASS・改竄 BLOCK・no-task SKIP は不変。ta-11 全 parity 契約化。承認境界は
より厳格＝安全側（hook-enforcement.md 明記）。**これで dogfooding/reuse
follow-up（#281/#282）完遂・残オープン issue ゼロ見込み**。

## 6. テスト結果
V-1 AC1-5 + V-3 反映後: ta-11 4/4 parity / 実リポジトリ (a)PASS (b)不正→SKIP
(c)改竄→BLOCK exit1 / run-tests 68/0 / hooks 77/0 / sh -n / scope 限定。
