# TEST CASES — TASK-0133 (#567)

## AC → TC
### AC-01: alternatives_rejected の additive 追加・既存不変
- TC-01: `grep "alternatives_rejected" docs/working/templates/decision-log-schema.md` がヒットし、フィールド表に `option` / `rationale` の表記がある（Refs: R-002）。種別: 機械
- TC-02: 既存フィールド(ts/phase/task/type/decision/reason/alternatives/chosen_by)が全て schema に残る。種別: 機械(grep 各名)
### AC-02: brainstorming skill の記録規約
- TC-03: brainstorming SKILL.md に「不採用案を alternatives_rejected で記録・必須=high-risk/critical/human」が記載。種別: レビュー+grep
### AC-03: 正本関係明記
- TC-04: pbi-input Notes と decision-log の正本(=decision-log)関係が記載。pbi-input.md 不在時の fallback 先（working-context.md）が確定記述される（Refs: R-003）。種別: レビュー
### AC-04-bis: alternatives_rejected 構造検証（Refs: R-002）
- TC-06: decision-log-schema.md の `alternatives_rejected` サンプル JSONL 行が `jq '.alternatives_rejected[] | .option, .rationale'` でパースでき、option/rationale を持つ。種別: 機械

### AC-04: 後方互換
- TC-05: alternatives_rejected を持たない既存サンプル行が schema 上 valid（任意フィールド）であることが注記され、jq でパース可能。種別: 機械

## Edge cases
- EC-01: alternatives_rejected 空配列 / 省略の両方を許容
- EC-02: rationale 自由文（構造強制しない）
- EC-03: 全 mode 必須化しない（standard 以下は任意）
