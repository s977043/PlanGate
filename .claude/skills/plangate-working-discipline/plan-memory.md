# PlanGate Memory

セッション・/compact を跨いで判断を失わないためのテンプレート。
`docs/working/TASK-XXXX/` 配下（または相当の作業コンテキスト）に置き、
**タスク完了ごとに更新・完了系は確定後のみ記載（未確定は PENDING-VERIFY 前置）**。

```markdown
# PlanGate Memory — <TASK-ID / 作業名>

## Project Context

<このタスクが属するプロジェクト・前提の 2〜3 行。次のセッションが最初に読む>

## Current Goal

<現在のゴール一文 + 観測可能な完了条件>

## Accepted Decisions

<採用した判断。各行に「何を・なぜ」>

- <判断>: <理由>（<日付 / 根拠へのリンク>）

## Rejected Options

<却下した案。同じ検討を繰り返さないための最重要セクション>

- <案>: 却下

## Rejection Reasons

- <案> → <却下理由。制約・コスト・リスクのどれか>

## Existing Constraints

<既存設計・運用上の制約。「この枠内でしか動けない」もの>

- <制約>（出典: <ファイル/issue>）

## Known Failure Patterns

<このタスク・この領域で繰り返し起きた/起きそうな失敗>

- <パターン> → 対策: <回避手順>

## Verification Commands

<このプロジェクトで実在する検証コマンドのみ。捏造禁止>

- `<command>` — <何を検証するか>

## Risk Register
<リスクゼロの場合も「なし（<確認日>時点）」と明記する（空欄と区別）>

| リスク | 影響 | 状態（open / mitigated / accepted） | 対応 |
| ------ | ---- | ----------------------------------- | ---- |

## Open Questions

<未解決の論点。owner（AI / Human）を明記>

- [ ] <論点>（owner: <AI/Human>）

## Next Actions

<優先度付き。「いま最もリスクが高い場所」から>

- [ ] P0: <アクション>（owner: <AI/Human>）
- [ ] P1: <アクション>

## Last Updated

<YYYY-MM-DD HH:mm> / 更新者: <AI セッション / Human>
```

## 運用ルール

- **書くタイミング**: フェーズ遷移時・セッション終了時・/compact 実行前（必須）。
- **PENDING-VERIFY**: マージ・テスト成功・起票などの完了系は一次証跡で実測してから
  確定記載する。実測前に書く場合は `PENDING-VERIFY:` を前置し、次セッションが
  検証してから確定化する。
- **Rejected Options を消さない**: 採用案が変わっても却下履歴は追記で残す
  （/compact 後に同じ案を再提案する事故を防ぐ）。
