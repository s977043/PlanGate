# V-3 外部レビュー（Codex）— TASK-0091 / #213

## 結果サマリ
critical: 0 / major: 3 / minor: 2 / info: 3（初回 NOT APPROVE → 全反映）

## 指摘と対応
| ID | severity | 指摘 | 対応 |
|----|----------|------|------|
| MJ-1 | major | skill 入力種別 `plan/risk/done/combined` が schema enum `*_check` と不一致（利用者が enum 違反 JSON を生成）| skill を `plan_check/risk_check/done_check/combined` に統一 |
| MJ-2 | major | CLI --init 雛形が score:0 なのに decision:needs_clarification（doc 閾値 0-59=insufficient と意味論不整合・誤状態が schema 通過）| 雛形 decision を `insufficient` に修正 |
| MJ-3 | major | schema-validate.yml が schemas/** trigger でも docs/working/*.json しか検証せず、schema/mapping 単独破損を skip。schema_mapping.py が trigger 外 | trigger に scripts/schema_mapping.py 追加 + 「schema files and mapping integrity」ステップ追加（全 schema json.tool + schema_mapping import + 参照先存在検証）。ローカル実機シミュレーション成功 |
| mn-1 | minor | skill 想定 Phase に `C-3` 固有 gate 名（Rule 2 違反）| gate 名除去「計画レビュー前後の軽量確認（計画作成直後・実装着手前）」、Rule 2 機械検出 0 件 |
| mn-2 | minor | score_breakdown が部分内訳も valid（doc は「軸固定」）| score_breakdown.required に 5 軸追加（任意フィールドだが存在時は完全性要求）|
| info×3 | info | CLI heavy 非起動・sh -n OK / 承認境界一貫 / gstack Non-goal 明記 — 問題なし | 対応不要 |

## 判定
major 3 / minor 2 を全反映。critical 0。回帰 V-1 全 PASS・CLI --validate PASS・
workflow ステップ実機シミュレーション成功・Rule 2 機械検出 0 件・schema valid。
