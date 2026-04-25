# Handoff Package — TASK-0037

> WF-05 Verify & Handoff の必須出力。Rule 5 遵守。
> 配置: `docs/working/TASK-0037/handoff.md`

## メタ情報

```yaml
task: TASK-0037
related_pr: https://github.com/s977043/plangate/pull/67
author: qa-reviewer (Claude Code)
issued_at: 2026-04-26
v1_release: 0b88c23 (PR #67 squash merge → main / v7.3.0)
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| `/pg-check` と `skill-policy-router` の連携が明文化されている | PASS | `plugin/plangate/commands/pg-check.md` に `## GatePolicy との連携` セクションを追加。Mode 別の `check` 扱い表を記載 |
| light 以上で `check` が requiredSkills に含まれることが示されている | PASS | Mode 表で `light: requiredSkills`、`standard 以上: requiredSkills` と明記 |
| critical finding 時のブロック条件が記述されている | PASS | 「`/pg-check` で critical finding が出た場合は fix なしに次ステップへ進めない」と明記 |

**総合**: `3/3 基準 PASS`

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| なし | — | — | — |

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 |
|--------|------|----------|
| 他の `/pg-*` コマンド（think/hunt/verify）にも GatePolicy 連携セクションを追加 | pg-check と同様、skill-policy-router との接続を明示すると一貫性が増す | Low |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| pg-check.md のみ更新 | think/hunt/verify も同時更新 | TASK-0037 のスコープを最小限に限定。他コマンドは V2 候補として残す |

## 5. 引き継ぎ文書

### 概要

TASK-0037 は `pg-check.md` に `## GatePolicy との連携` セクションを追加し、`skill-policy-router` が `check` を `requiredSkills` に含む場合に `/pg-check` が自動要求される仕組みを明文化した。PR #67 (v7.3.0) に含まれてリリース済み。

### 次に手を入れるなら

- `/pg-think`・`/pg-hunt`・`/pg-verify` にも同様の GatePolicy 連携セクションを追加（V2 候補）

### 参照リンク

- PR #67: https://github.com/s977043/plangate/pull/67
- 対象ファイル: `plugin/plangate/commands/pg-check.md`
- 連携先: `plugin/plangate/skills/skill-policy-router/SKILL.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| 文書確認（AC 突合） | 3 | 3 | 0 |
| Markdownlint CI | 1 | 1 | 0 |
