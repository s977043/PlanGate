# TASK-0871 INDEX — 正本定義統合・PoC 制約分離

- issue: [#871](https://github.com/s977043/plangate/issues/871) / 親 EPIC: [#870](https://github.com/s977043/plangate/issues/870)
- 現在フェーズ: **C-3 承認済み（2026-07-19 Human APPROVE）→ c3.json 発行待ち → exec（T-03〜）着手待ち**
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
| [review-self.md](./review-self.md) | 作成済（C-1・WARN。監査スナップショット・編集禁止） |
| [review-external.md](./review-external.md) | 作成済（C-2 2 レーン・R-001〜R-012 + 監査表） |
| status.md / handoff.md | 未着手（後続フェーズ） |

## 次のアクション

1. c3.json 発行（Human: `bin/plangate approve TASK-0871`・plan_hash = C-3 確定版 plan.md の SHA256）
2. PR #879 merge（C-4）
3. exec 着手（T-03〜。c3.json APPROVED が前提 — Iron Law #1）
