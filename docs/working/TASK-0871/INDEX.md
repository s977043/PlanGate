# TASK-0871 INDEX — 正本定義統合・PoC 制約分離

- issue: [#871](https://github.com/s977043/plangate/issues/871) / 親 EPIC: [#870](https://github.com/s977043/plangate/issues/870)
- 現在フェーズ: **B 完了（plan 起草済み）→ C-1 待ち**
- Mode: **high-risk** / lite_eligible=false / C-3 同期・Human 必須

## ファイル索引

| ファイル | 状態 |
|---------|------|
| [pbi-input.md](./pbi-input.md) | 作成済（issue #871 本文の構造化） |
| [plan.md](./plan.md) | 作成済（正本方針比較 = B案推奨・矛盾一覧付録 A/B 付き） |
| [todo.md](./todo.md) | 作成済（T-01〜T-13 / H-01〜H-03） |
| [test-cases.md](./test-cases.md) | 作成済（AC 10 項目 → TC-01〜13 + EC-01〜06） |
| [current-state.md](./current-state.md) | 作成済 |
| decision-log.jsonl | 未作成（オーガナイザー側で初期化） |
| review-self.md / review-external.md / status.md / handoff.md | 未着手（後続フェーズ） |

## 次のアクション

1. C-1 セルフレビュー（17 項目）
2. C-2 外部 AI レビュー（high-risk のため必須）
3. C-3 Human 承認（同期）→ `approvals/c3.json` 発行後に exec
