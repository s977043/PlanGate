# Review Gate

計画（Plan Phase 出力）のレビューテンプレート。
レビューは**生成者と独立した視点**で行う（自己レビューのみで通さない）。

> **正本との関係**: レビュー観点・Severity・auto-approve 判定の正本は
> `.claude/rules/review-principles.md`（C-2 / CI / コードレビューはそちらに従う）。
> 本テンプレートは **Plan Phase 出力（計画）のレビュー用チェックリスト**として
> それを補完するものであり、観点・Severity を再定義しない。

```markdown
# Review Gate — <TASK-ID / 計画名>

## Summary

<計画の 3 行要約。何を・なぜ・どう検証するか>

## Requirement Fit

<要件との整合。AC を 1 件ずつ照合し、計画のどのステップが満たすかを対応づける>

| 要件 / AC | 対応する計画ステップ | 判定 |
| --------- | -------------------- | ---- |

## Existing Design Fit

<既存設計との整合。実コードを読んだ上で: 命名・責務分離・既存パターンとの適合。
**読んだ証拠として該当ファイル:節（または行）を最低 1 件引用する**（引用ゼロの
Existing Design Fit は「読んでいない」と見なす）>

## Risk Assessment

<不可逆操作・共有状態・承認境界・外部影響。高リスク箇所が計画の早い段階に
配置されているか>

## Security Review

<入力検証・認証認可・機密情報・インジェクション。該当なしなら「該当なし」と明記>

## Testability Review

<Verification Method は実在するコマンド・観測可能な結果で書かれているか。
テストしにくい構造を作らないか>

## Maintainability Review

<変更が将来の変更を難しくしないか。ドキュメント・命名の負債を作らないか>

## Overengineering Check

<要求外の機能・単発用途の抽象化・不要な依存追加が混ざっていないか。
「小さな修正が大規模リファクタに拡大していないか」>

## Alternatives

<検討した代替案と、採用案が優る理由。代替なしなら「単一案である理由」>

## Missing Information

<判定に不足している情報。憶測で埋めた前提があればここで顕在化させる>

## Decision

approved / needs_revision / blocked / rejected

<判定理由を 1〜3 行で>

## Required Changes Before Execution

<needs_revision の場合の必須修正リスト。approved なら「なし」>

- [ ] <修正項目>
```

## 判定基準

| 判定             | 条件                                                            |
| ---------------- | --------------------------------------------------------------- |
| `approved`       | 全観点で懸念なし、または懸念がすべて計画内で対処済み            |
| `needs_revision` | 修正可能な不備あり（Required Changes を明示して Plan へ戻す）   |
| `blocked`        | 判定に必要な情報が不足（Missing Information の解消が先）        |
| `rejected`       | 要件不整合・原則違反など計画の根本が成立しない（Intake へ戻す） |

判定に迷う場合は安全側（`needs_revision` / `blocked`）へ倒す。

**レビュアーの停止規律**: 適用順はまず「**迷い**（正誤が判定できない）か
**軽微な懸念**（正誤は明確だが実害が軽い）か」を判定する — 迷いなら上記の安全側原則
（`needs_revision` / `blocked`）が優先し、懸念のみの場合に本規律を適用する。
実害のある欠陥（実装をブロックすべきもの）のみ `needs_revision` /
`needs_revision`（根本不成立なら `rejected` = Intake 行き）とし、注記・記録で管理可能な
懸念は `approved` + 指摘の記録に回す。
完璧主義による無限差し戻しは非停止の一形態であり、`needs_revision`→改訂→再レビューは
ラウンド上限（3）内で収束させる（超過は人間へ）。改訂は追記方式で行い、
旧ラウンドの計画は「レビュアーが何を見たか」の監査記録として不変に保つ。
