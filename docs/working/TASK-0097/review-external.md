# V-3 外部レビュー（Codex）— TASK-0097 / #199

## 結果サマリ
critical: 0 / major: 2 / minor: 2 / info: 5（初回 NOT APPROVE → 全反映）

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | _BUDGET が mode のみで profile の max_context_policy を無視。doc は「model-profiles と整合」だが未読 | model-profiles.yaml の profile max_context_policy を読み、**mode 由来と profile 由来の保守側（compact<standard<expanded 小さい方）**を採用。PyYAML 不在/未定義は mode のみ。doc に解決規則明記 |
| MJ-2 | major | c3.json 在で plan_hash 抽出不可時 approved_plan が present+「consistent」表示＝未照合承認 plan を contract に見せ承認境界を弱める | c3 在 & plan_hash 抽出不可 → approved_plan を stale/invalidated・plan_hash_match=false・note「missing/unverified — contract not usable」・exit 1 |
| mn-1 | minor | doc「動的取得」が実装（記述子のみ）と乖離し engine に git 実行責務と誤読 | 「取得候補を列挙（記述子のみ・実取得は呼び出し側）」へ修正 |
| mn-2 | minor | help `[--mode][--profile]` 値なし表記 | `[--mode <m>] [--profile <k>]` に整形 |
| info×5 | info | EH-3 と plan_hash 抽出同方向 / subprocess 不使用 / schema_mapping 登録 / additionalProperties 整合 / opt-in 本物・keep-rate#198 非混入 | 対応不要 |

## 判定
major 2 / minor 2 を全反映。critical 0。回帰: profile 保守側解決（gpt-5_mini/
gpt-5_5_pro+light→compact）/ c3 有 plan_hash 無→invalidated+exit1 / 正常系
rc=0 / schema validate / plan_hash 整合 全 PASS。EH-3 をゲート代替せず補完。
