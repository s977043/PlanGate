# V-3 外部レビュー（Codex）— TASK-0089 / #227

## 結果サマリ
critical: 0 / major: 1 / minor: 1 / info: 4

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | schema で output_mapping が任意かつ空 valid。doc/example は必須前提で不整合 | schemas: reviewerSpec.required に output_mapping 追加、output_mapping.required=severity/evidence/location。doc §2 に「必須・省略不可」明記。example は元から充足 → 修正後も validate PASS |
| mn-1 | minor | 「PlanGate だけ」行が「無し or c2/v3 未定義」だが schema minProperties:1 で後者は invalid | doc: 行を「ファイル自体を置かない」に修正 + パターン表直後に minProperties:1 注記追加 |
| info×4 | info | unknown→major / §7-bis 二重定義なし / example 非有効化 / schema draft-07 妥当 — いずれも問題なし | 対応不要 |

## 判定
major/minor を全反映。critical 0。回帰 V-1（T1/T4/T5）PASS・example schema validate PASS。
