# PBI INPUT PACKAGE: 責務ベース Agent 5 体を整備する

> 作成日: 2026-04-20
> PBI: [TASK-0021-C] 責務ベース Agent 5 体を整備する
> チケットURL: https://github.com/s977043/plangate/issues/25
> 親チケット: https://github.com/s977043/plangate/issues/22

---

## Context / Why

FE/BE/QA のような役職ベースではなく、**責務ベースで subagent を再定義**する（逆輸入改善点④）。requirements / design / implement / verify に寄せることで、案件ごとのロール変更に強くする。Rule 3 に従い、Agent は責務だけを持つ。

---

## What（Scope）

### In scope

- `.claude/agents/` に責務ベース Agent 5 体を配置（うち `orchestrator` は既存 `workflow-conductor` と並立、`.claude/agents/orchestrator.md` を**新規作成** — 同名の既存ファイルなし）
- 各 Agent に以下を定義:
  - 責務（何をする agent か）
  - 委譲関係（次にどの agent に渡すか）
  - allowed-tools（Bash / Edit / Write / Read 等）
  - 呼び出す Skill（#24 で整備される 10 個から参照）
- 既存 `.claude/agents/` 18 体との責務重複マッピング表作成
- 実行シーケンスの図示（orchestrator → 各 agent → handoff）

### 対象 Agent（5 体・責務ベース）

| Agent | 責務 |
|-------|------|
| `orchestrator` | ワークフロー遷移管理 / 誰に何を渡すか決める / 完了条件判定 |
| `requirements-analyst` | 初期要求を仕様に変換 / 曖昧さ・抜け漏れ・対象外を整理 |
| `solution-architect` | 実装構造を設計 / 依存制約や技術的妥協点を明文化 |
| `implementation-agent` | コードを書く / 小さな単位で自己レビュー / 既知課題を残す |
| `qa-reviewer` | 要件適合・回帰・未考慮ケースを確認 / V1/V2 の境界整理 |

### 実行シーケンス

1. `orchestrator` が WF-01 を開始
2. `requirements-analyst` が `requirement-gap-scan` で仕様拡張
3. `qa-reviewer` が `edgecase-enumeration` + `acceptance-criteria-build` で締める
4. `solution-architect` が WF-03 で実装構造化
5. `implementation-agent` が WF-04 で実装
6. `qa-reviewer` が WF-05 で要件照合
7. `orchestrator` が handoff を出す

### Out of scope

- 既存 Agent（18 体）の削除・改変（共存、責務マッピングのみ作成）
- Agent 実行エンジン（Claude Code Task ツールを利用）
- plugin 同梱（TASK-0018/0019 と同様のコピーは将来別タスク）

---

## 受入基準

- [ ] 5 体の Agent が `.claude/agents/` に新規配置
- [ ] 各 Agent に 責務 / 委譲関係 / allowed-tools / 呼び出す Skill が定義
- [ ] Rule 3 遵守（責務のみ、ツール固有/案件固有なし）
- [ ] 既存 18 agents との責務マッピング表が作成
- [ ] 実行シーケンスが動作可能な形で文書化

---

## Notes from Refinement

### 既存 Agent との関係

既存 `.claude/agents/` 18 体:
- workflow-conductor, spec-writer, implementer, test-engineer※, linter-fixer, acceptance-tester, code-optimizer, release-manager※, 他
- ※ test-engineer / release-manager は実在せず（TASK-0019 で判明）

新規 5 体と既存の対応:
| 新規 | 類似既存 | 関係 |
|-----|---------|------|
| orchestrator | workflow-conductor | **責務ベース**で再定義、workflow-conductor は技術特化、orchestrator は汎用 |
| requirements-analyst | spec-writer | 部分重複、requirements-analyst は「曖昧さ解消」に特化 |
| solution-architect | （新規） | 既存に該当なし、WF-03 独立化の中核 |
| implementation-agent | implementer | 類似、implementation-agent は「小単位自己レビュー」を明示 |
| qa-reviewer | acceptance-tester | 部分重複、qa-reviewer は「V1/V2 境界整理」を含む |

### 想定モード判定

**standard**（中）を想定。

- 変更ファイル数: 7（5 Agent + マッピング表 + シーケンス図）
- 受入基準数: 5
- 変更種別: 責務ベース Agent 新規整備
- リスク: 中（既存 Agent との責務重複・役割分担）

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Rule 3 違反（ツール固有・案件固有を持つ） | Medium | レビュー時にチェック、固有情報は CLAUDE.md に寄せる |
| 既存 Agent との責務重複でどちらを使うか不明瞭 | Medium | マッピング表で明示、将来的には責務ベース 5 体に集約する方向性を記載 |
| 委譲関係がループ / 行き止まり | Low | シーケンス図で検証、orchestrator を起点に明示 |

### Unknowns

- 各 Agent の allowed-tools 具体リストは agent ごとに確定（例: implementation-agent → Edit/Write/Bash、qa-reviewer → Read/Grep/Bash）
- plugin 同梱の判断は本 TASK 外

### Assumptions

- `.claude/agents/` の frontmatter 形式は既存と同じ（name, description, tools）
- Claude Code Task ツール経由で subagent_type 指定で呼び出せる

---

## 依存

- **前提**: #23（Workflow 定義）完了、**#24（Skill 定義）完了**（`呼び出す Skill` 名凍結のため）
- **後続**: #26 / #27 から参照される
