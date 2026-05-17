# V-3 外部レビュー（Codex）— TASK-0093 / #203

## 結果サマリ
critical: 0 / major: 2 / minor: 3 / info: 4（初回 NOT APPROVE → 全反映）

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | schema に tool_error の conditional 無く category 欠落 event が valid | allOf に `if event==tool_error then required:[tool_error_category, schema_version], schema_version const 1.1` を additive 追加。jsonschema で欠落/1.0 が REJECT、正常/既存1.0 が PASS を確認 |
| MJ-2 | major | taxonomy の release_blocker と eval-result release_blocker_violations(enum 別) を整合と誤記 | 「別軸（tool error category vs 評価 aspect）・同一視しない」明記 + 概念対応表追加（機械的等価でない旨） |
| mn-1 | minor | schema_version 1.0 でも tool_error 許容で版境界曖昧 | MJ-1 conditional で schema_version const 1.1 固定（解消）|
| mn-2 | minor | delegation_unavailable が retryable だが実体は topology fallback | classification に `retryable*` + 「retry でなく topology fallback・回数 retry しない」注記 |
| mn-3 | minor | metrics.md §3.5 が既存 mode別集計と重複 | tool_error を §3.8（末尾・mode別集計/整合性/機械可読化の後）へ正規配置、3.x 一意化 |
| info×4 | info | enum/additionalProperties 非矛盾 / 既存 conditional 非干渉 / Privacy 一貫 / 責務分離 OK | 対応不要 |

## 判定
major 2 / minor 3 を全反映。critical 0。回帰 V-1 全 PASS・schema 正/異常/非破壊
を jsonschema で機械確認・metrics 採番一意化。
