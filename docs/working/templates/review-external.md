---
task_id: TASK-XXXX
artifact_type: review-external
schema_version: 1
status: draft
verdict: PASS
reviewer_tool: codex
created_by: orchestrator
---

# TASK-XXXX 外部AIレビュー結果（C-2）

> レビュー日: YYYY-MM-DD
> レビューア: orchestrator → {backend-specialist, frontend-specialist, explorer}
> 判定: **PASS** / **WARN** / **FAIL** — critical={0}, major={0}, minor={0}

## サマリー

| result | 件数 |
|--------|------|
| PASS | {0} |
| WARN | {0} |
| FAIL | {0} |

## バックエンド観点（backend-specialist）

### C2-BE-01: {チェック項目名}
- **result**: PASS / WARN / FAIL
- **category**: {design / security / perf}
- **finding**: {発見内容（1-2文）}
- **evidence_ref**: —
- **impacted_files**: [{影響ファイルパス}]

### C2-BE-02: {チェック項目名}
- **result**: PASS / WARN / FAIL
- **category**: {design / security / perf}
- **finding**: {発見内容（1-2文）}
- **evidence_ref**: —
- **impacted_files**: [{影響ファイルパス}]

## フロントエンド観点（frontend-specialist）

### C2-FE-01: {チェック項目名}
- **result**: PASS / WARN / FAIL
- **category**: {design / security / perf}
- **finding**: {発見内容（1-2文）}
- **evidence_ref**: —
- **impacted_files**: [{影響ファイルパス}]

## 探索観点（explorer）

### C2-EXP-01: {チェック項目名}
- **result**: PASS / WARN / FAIL
- **category**: {design / security / perf}
- **finding**: {発見内容（1-2文）}
- **evidence_ref**: —
- **impacted_files**: [{影響ファイルパス}]

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| {C2-BE-02} | {test-cases.md に負荷想定メモを追記} | {test-cases.md} |

<!--
共通schema フィールド定義:
- check_id: 一意の識別子（C2-{観点}-{連番}。例: C2-BE-01, C2-FE-01, C2-EXP-01）
- category: design / security / perf / test / plan
- result: PASS / WARN / FAIL
- finding: 発見内容（1-2文）
- evidence_ref: evidence/ 内のファイルパス（FAIL時必須、PASS時は「—」）
- impacted_files: 影響を受けるファイルパス

WARN/FAIL 時の追加フィールド:
- suggested_action: 推奨対応
- owner: agent / human
- resolved: true / false（自動修正後にtrue）

観点プレフィックス:
- C2-BE: バックエンド（backend-specialist）
- C2-FE: フロントエンド（frontend-specialist）
- C2-EXP: 探索（explorer）
- C2-SM: プロセス（scrum-master）※必要に応じて追加
-->
