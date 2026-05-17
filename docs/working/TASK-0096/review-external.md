# V-3 外部レビュー（Codex）— TASK-0096 / #198

## 結果サマリ
critical: 0 / major: 3 / minor: 2 / info: 6（初回 NOT APPROVE → 全反映）

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | code_keep_rate が docs/schema を「コード」に誤算入（成果物残存率化）| `_is_code()` allowlist 導入（コード拡張子 + scripts/src/lib/app/tests/ + bin/plangate のみ、docs/ 配下と *.md/*.json 除外）。docs/schema PBI は「no code files」= unknown に正規化 |
| MJ-2 | major | `git log --grep=<task_id>` が substring 偽陽性（無関係 commit/近接 ID 誤検出）| `-E` + token 境界正規表現 `(^|[^0-9A-Za-z-])TASK-XXXX([^0-9A-Za-z-]|$)` に変更 |
| MJ-3 | major | plan_keep_rate が docstring「plan_hash 一致前提」だが未検証（C-3 後 todo 改変で誤集計）| c3.json の plan_hash と plan.md の sha256 を**実検証**、不一致なら `unknown (plan.md changed after C-3)`。docstring も実検証へ更新 |
| mn-1 | minor | acceptance_keep_rate が test-cases AC ID 未突合（別ID/欠落でも PASS 比率を出す）| test-cases.md の AC ID 集合を抽出し handoff AC 行数と突合、不足時 `reason: partial coverage` を付記 |
| mn-2 | minor | schema_mapping 登録が差分外で判定不能 | 登録済（keep-rate-result.json → keep-rate-result.schema.json）。stash 復元時の merge で 3 エントリ統合・確認済 |
| info×6 | info | subprocess 配列実行/timeout 安全 / unknown は reason 付きで 0 と区別 / value oneOf 整合 / advisory 一貫 / metrics event schema 非変更 / privacy file path/集計値のみ | 対応不要 |

## 判定
major 3 / minor 2 を全反映。critical 0。回帰 V-1: smoke（TASK-0095/0087）/
_is_code allowlist / token 境界 / plan_hash 実検証 / AC 突合 / schema validate
全 PASS。stash 復元時の bin/plangate・schema_mapping コンフリクトも解消
（plan-check#213 + keep-rate#198 両立）。
