# V-3 外部レビュー（Codex）— TASK-0094 / #204

## 結果サマリ
critical: 0 / major: 4 / minor: 1 / info: 4（初回 NOT APPROVE → 全反映）

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | `--harness-compare`/`--targets` を運用前提にしているが #196/PR#268 未マージで現行 CLI に無い | #196/PR#268 提供の前方参照と明記、未マージ環境は個別 `eval <TASK>` で選定、推奨マージ順 #268→本PR を §5 に記載、eval-runner.md 注記も依存明示 |
| MJ-2 | major | ambiguous-requirement で plan_check が exec をブロックと記述（plan-quality は非 blocking 助言）| Stop rule（実 blocking 機構）と plan_check（非 blocking 助言記録）を分離記述 |
| MJ-3 | major | simple-ui-change が ultra-light/light を一括りで gate 記述欠落 | ultra-light（直接実装+L-0+V-1簡易+PR+C-4）/ light（簡易plan+C-1簡易+C-3差分+TDD+L-0+V-1+PR+C-4・C-2/V-3スキップ）に分岐 |
| MJ-4 | major | high-risk-auth-change の「認可は critical」が mode-classification 正本に無い | 正本整合: セキュリティ変更=最低 standard、影響/破壊性で high-risk/critical 引き上げ、critical 例外は公開API破壊的変更。critical 固定記述を削除 |
| mn-1 | minor | eval-comparison.json target.task_ids が既存 artifact と未整合 | #196 提供 schema の「例」扱いに変更（本 PBI は schema 非変更を明記）|
| info×4 | info | 8 fixture 固定フォーマット揃い / 相対リンク 8 件解決 / schema 非変更 / Non-goal 概ね遵守 | 対応不要 |

## 判定
major 4 / minor 1 を全反映。critical 0。回帰 V-1 全 PASS・schema 非変更維持。
#196 は依存（推奨マージ順 PR #268 → 本 PR）。fixture（シナリオ固定）は単独有効。
