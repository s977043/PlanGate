# /pg-check

差分レビューと安全確認を行う。

## 目的

コミット・PR 前に変更の安全性を確認する。severity 付き finding を出力し、リスクを可視化する。

## Iron Law

`NO MERGE WITHOUT TWO-STAGE REVIEW`

severity=critical の finding がある場合、fix なしに完了しない。

## 引数

`$ARGUMENTS` にレビュー対象（PR 番号またはブランチ名）を渡す。省略時は現在のブランチの差分。

## GatePolicy との連携

`skill-policy-router` が `check` を `requiredSkills` に含む場合、このコマンドが自動的に要求される。

| Mode | check の扱い |
|------|-------------|
| ultra-light | optionalSkills（任意） |
| light | requiredSkills（必須） |
| standard 以上 | requiredSkills（必須） |

GatePolicy が `{ "requiredSkills": ["check", ...] }` を返した場合、ワークフローは `/pg-check` の実行を求める。`/pg-check` で critical finding が出た場合は fix なしに次ステップへ進めない。

## 実行フロー

1. **Diff Summary**: 変更差分の概要を把握する（`git diff --stat`）
2. **Findings**: 変更内容を読み、severity 付きの指摘事項を列挙する
3. **Spec Compliance**: 受入基準との適合を確認する（test-cases.md があれば参照）
4. **Risk Notes**: リスクのある変更を特定する
5. **Recommended Fixes**: critical/major の指摘に対する修正案を提示する
6. **Verification Commands**: 変更を検証するためのコマンドを列挙する

## Severity 定義

| Severity | 定義 |
|---------|------|
| **critical** | 本番障害・データ不整合・脆弱性 |
| **major** | ロジック誤り・テスト不足・設計違反 |
| **minor** | 改善提案・命名・コードスタイル |
| **info** | FYI・将来課題 |

## 出力フォーマット

### Diff Summary

\<変更ファイル一覧と概要\>

### Findings

| Severity | 指摘 | ファイル | 修正案 |
|---------|------|--------|------|
| critical | \<指摘\> | \<ファイル\> | \<修正案\> |
| major | \<指摘\> | \<ファイル\> | \<修正案\> |

### Spec Compliance

| 受入基準 | 適合 |
|---------|------|
| \<AC-1\> | PASS / FAIL / WARN |

### Risk Notes

- \<リスク 1\>

### Recommended Fixes

\<critical/major の修正案\>

### Verification Commands

```bash
# 変更を検証するコマンドを列挙する
```
