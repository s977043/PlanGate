---
task_id: TASK-XXXX
artifact_type: review-self
schema_version: 1
status: draft
verdict: PASS
created_by: orchestrator
---

# TASK-XXXX セルフレビュー結果（C-1）

> レビュー日: YYYY-MM-DD
> 判定: **PASS** / **WARN** / **FAIL** — critical={0}, major={0}, minor={0}

## サマリー

| result | 件数 |
|--------|------|
| PASS | {17} |
| WARN | {0} |
| FAIL | {0} |

## Plan チェック（7項目）

### C1-PLAN-01: 受入基準網羅性
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {受入基準の全項目がWork Breakdownにマッピングされているか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-02: Unknowns処理
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {Questions/Unknownsが0、または解決手段が明記されているか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-03: スコープ制御
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {Non-goalsが明確で、スコープクリープの兆候がないか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-04: テスト戦略
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {Unit/Integration/E2Eの対象が具体的か}
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-05: Work Breakdown Output
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {各Stepに具体的なOutputがあるか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-06: 依存関係
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {Step間の依存が矛盾なく順序付けられているか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-07: 動作検証自動化
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {Verification Automationが具体的か}
- **evidence_ref**: —
- **impacted_files**: []

## ToDo チェック（5項目）

### C1-TODO-08: タスク粒度
- **result**: PASS / WARN / FAIL
- **category**: todo
- **finding**: {各タスクが2〜5分で完了できる粒度か}
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-09: depends_on設定
- **result**: PASS / WARN / FAIL
- **category**: todo
- **finding**: {依存関係が明示されているか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-10: チェックポイント設定
- **result**: PASS / WARN / FAIL
- **category**: todo
- **finding**: {各StepにToDo更新タイミングが設定されているか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-11: Iron Law遵守
- **result**: PASS / WARN / FAIL
- **category**: todo
- **finding**: {承認前コード実行・スコープ逸脱の危険がないか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-TODO-12: 完了条件
- **result**: PASS / WARN / FAIL
- **category**: todo
- **finding**: {各タスクに完了条件が記述されているか}
- **evidence_ref**: —
- **impacted_files**: []

## テストケースチェック（3項目）

### C1-TEST-13: 受入基準→テストケース網羅性
- **result**: PASS / WARN / FAIL
- **category**: test
- **finding**: {全受入基準に対応するテストケースがあるか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-14: テストケースの具体性
- **result**: PASS / WARN / FAIL
- **category**: test
- **finding**: {入力値・期待値が具体的か（「正しく動作する」ではなく値レベル）}
- **evidence_ref**: —
- **impacted_files**: []

### C1-TEST-15: エッジケースの考慮
- **result**: PASS / WARN / FAIL
- **category**: test
- **finding**: {境界値・異常系・空入力が含まれているか}
- **evidence_ref**: —
- **impacted_files**: []

## B-1/B-2チェック（2項目）

### C1-B1B2-16: B-1確認質問
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {PBI INPUTの曖昧な箇所を確認質問で解消したか、または曖昧さがないことを確認したか}
- **evidence_ref**: —
- **impacted_files**: []

### C1-B1B2-17: B-2アプローチ比較
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {2案以上のアプローチを比較し、推薦案の選定理由を明記したか}
- **evidence_ref**: —
- **impacted_files**: []

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| {C1-PLAN-03} | {Non-goals に IT_RANKING 除外を追記} | {plan.md} |

<!--
共通schema フィールド定義:
- check_id: 一意の識別子（C1-PLAN-01〜C1-B1B2-17）
- category: plan / todo / test
- result: PASS / WARN / FAIL
- finding: 発見内容（1-2文）
- evidence_ref: evidence/ 内のファイルパス（FAIL時必須、PASS時は「—」）
- impacted_files: 影響を受けるファイルパス（[]で空配列）

WARN/FAIL 時の追加フィールド:
- suggested_action: 推奨対応
- owner: agent / human
- resolved: true / false（自動修正後にtrue）
-->
