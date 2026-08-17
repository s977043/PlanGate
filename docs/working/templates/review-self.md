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

## C-1 チェック項目数（正本）

**本テンプレートが C-1 チェック項目の正本**であり、現行は **全 25 項目**。
他ドキュメントは項目数を再定義せず、本節を参照すること。

| 区分 | 項目 | 数 |
|------|------|---:|
| Plan | `C1-PLAN-01`〜`07` + `C1-PLAN-08-AEE` / `09-AEE` | 9 |
| Plan 品質追加（Superpowers 由来 / #581） | `C1-SUP-PLAN-01` / `02` | 2 |
| ToDo | `C1-TODO-08`〜`12` + `C1-TODO-RB` | 6 |
| TestCases | `C1-TEST-13`〜`15` | 3 |
| B-1/B-2 結合 | `C1-B1B2-16` / `17` | 2 |
| セキュリティ（#578） | `C1-SEC-01` | 1 |
| スコープ規律（#578） | `C1-SCOPE-DISC-01` | 1 |
| UI（#579・`is_ui_task` 時のみ） | `C1-UI-01` | 1 |
| **合計** | | **25** |

> **「17 項目」は歴史的なコア番号帯の通称**（`C1-PLAN-01`〜`C1-B1B2-17` の
> 連番 17 個 = Plan 7 + ToDo 5 + TestCases 3 + 結合 2）であり、
> 現行テンプレートの総数ではない。項目数を書く場合は **25**（コア帯を
> 指す場合はその旨を明記）を用いること。
>
> 項目数は追加 PBI で増減しうるため、**総数を契約値として他所へ複写しない**。
> 実測は `grep -c '^### C1-' docs/working/templates/review-self.md`。

## サマリー

| result | 件数 |
|--------|------|
| PASS | {25} |
| WARN | {0} |
| FAIL | {0} |

## Plan チェック（7項目 + AEE 2項目 / #544 Phase1）

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

### C1-PLAN-08-AEE: Stop Condition 記入（#544 Phase1）

- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {plan に Stop Condition が記入されているか（未記入は WARN。強制は Phase2/#543）}
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-09-AEE: Replan Triggers 機械値（#544 Phase1）

- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {plan の Replan Triggers に機械値が1つ以上記入されているか（未記入は WARN。強制は Phase2/#543）}
- **evidence_ref**: —
- **impacted_files**: []

## Plan 品質追加チェック（Superpowers 由来 / #581）

> Superpowers を依存として導入するのではなく、`writing-plans` の考え方を PlanGate の C-1 に翻訳する。目的は、plan を「説明文」ではなく、AI実装者が安全に実行できる作業指示書にすること。

### C1-SUP-PLAN-01: No Placeholders Rule
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {plan.md / todo.md / test-cases.md / design.md に、未解決の `TBD` / `TODO` / `後で実装` / `必要に応じて` / `適切に` / `いい感じに` / 未定義の関数・型・ファイルパス、および具体性を欠く『エラーハンドリングを追加』『テストを書く』『Task N と同様』が残っていないか}
- **evidence_ref**: —
- **impacted_files**: []
- **failure_policy**: {standard以上は重大な曖昧表現をFAIL。ultra-light/lightでもexecに必要なファイル・コマンド・期待結果が欠ける場合はFAIL}

### C1-SUP-PLAN-02: Task Sizing Rules
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {各Taskが独立して検証可能で、reviewerがTask単位でapprove/rejectできる粒度か。変更対象ファイル、公開インターフェース、検証コマンド、期待結果、依存関係が具体的か}
- **evidence_ref**: —
- **impacted_files**: []
- **failure_policy**: {high-risk/criticalではTask単位の検証不能・責務混在・依存不明をFAIL}

## ToDo チェック（6項目）

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

### C1-TODO-RB: rollback（戻し手順）
- **result**: PASS / WARN / FAIL
- **category**: todo
- **finding**: {high-risk/critical の実装タスクに `rollback:` が記述されているか。欠落は FAIL}
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

### C1-SEC-01: 秘密情報 非接触（#578）
- **result**: PASS / WARN / FAIL / N/A
- **category**: plan
- **finding**: {`.env` / APIキー / トークン / 個人パス / ローカル設定に触れない設計か。扱う可能性がある場合、secret scan / `git diff` 確認を Verification Plan に含めているか。秘密情報を扱わない変更は N/A}
- **evidence_ref**: —
- **impacted_files**: []

### C1-SCOPE-DISC-01: 発見事項の予防的分離（#578）
- **result**: PASS / WARN / FAIL
- **category**: plan
- **finding**: {実装中に発見したスコープ外の改善・不具合を、その場で直さず別 Issue / メモ（handoff V2 候補・既知課題）へ分離する方針か}
- **evidence_ref**: —
- **impacted_files**: []

### C1-UI-01: UI デザインシステム準拠（#579・is_ui_task 時のみ）
- **result**: PASS / WARN / FAIL / N/A
- **category**: plan
- **finding**: {is_ui_task の場合: states(default/hover/focus/disabled/loading/error) / design token / component 再利用+variant / accessibility を design.md 視覚設計に明示し、未定義デザイン値を発明せず提案扱い。DESIGN.md 存在時は参照。non-UI は N/A}
- **evidence_ref**: —
- **impacted_files**: []

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| {C1-PLAN-03} | {Non-goals に IT_RANKING 除外を追記} | {plan.md} |

<!--
共通schema フィールド定義:
- check_id: 一意の識別子（C1-PLAN-01〜C1-B1B2-17 / C1-SUP-PLAN-01〜02）
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