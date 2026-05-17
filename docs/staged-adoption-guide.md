# 段階的導入ガイド（ultra-light → standard 成長パス）

> PlanGate をチーム / プロジェクトへ段階的に導入するための正本ロードマップ。
> 初回導入の心理的ハードルを「Day 1 で体験できる」レベルに下げる。
> 関連: [#226](https://github.com/s977043/plangate/issues/226) / TASK-0088 /
> [`plangate.md`](./plangate.md) / [`.claude/rules/mode-classification.md`](../.claude/rules/mode-classification.md) /
> [`ai/hook-enforcement.md`](./ai/hook-enforcement.md) /
> [`ai/versioning-stability-policy.md`](./ai/versioning-stability-policy.md)

## 0. 考え方

PlanGate は 5 モード × 10 hook × 23 agent × 多数 skill の組み合わせを持つが、
**全部入りは前提ではない**。導入は「使うものだけを段階的に増やす」。各
フェーズには **使わなくてよいもの（最小セットの否定形）** を明示する。

| フェーズ | いつ | モード | ゲート | 主目的 |
|---------|------|--------|--------|--------|
| Phase 0 | Day 1 | ultra-light | なし | 体験する |
| Phase 1 | Week 1 | light | C-1 簡易 | 計画を書く |
| Phase 2 | Week 2-3 | standard | C-1 + C-3 | ゲートで止める |
| Phase 3 | Month 1+ | standard + strict | C-1〜C-4 + V-3 | フル運用 |

> モード判定の正本は [`mode-classification.md`](../.claude/rules/mode-classification.md)。
> 本ガイドは「**人が運用習熟度に応じて選ぶ初期値**」を示す（タスク規模での
> 自動判定とは別軸。習熟が進めば規模判定に従う）。

## Phase 0: 体験（Day 1）

**ゴール**: ultra-light モードで 1 タスクを最後まで完了し、3 コマンドの
流れを体感する。

- **使うもの**: `bin/plangate init <TASK>` → 手動実装 → `bin/plangate doctor`
- **モード**: ultra-light（plan 省略・ゲート省略・直接実装）
- **エージェント**: 0（手動作業でよい）
- **フック**: なし（`.claude/settings.json` の hooks 未配線でも可）
- **成果物**: 変更そのもの（pbi-input/plan は任意）

### 使わなくてよいもの（Phase 0）
plan.md / C-1〜C-4 / V-1〜V-4 / 全エージェント / 全フック / metrics。

## Phase 1: 計画導入（Week 1）

**ゴール**: pbi-input.md → plan.md の生成を体験し、「計画してから書く」
習慣をつくる。

- **モード**: light（簡易 plan + C-1 簡易 7 項目）
- **エージェント**: 2 体 — `project-planner`（plan 生成）+ `implementer`（実装）
- **フック**: `EH-1`（plan.md なし production code 編集ブロック /
  `check-plan-exists.sh`）のみを **warning** で配線
- **成果物**: pbi-input.md / plan.md / handoff.md（簡易）

### 使わなくてよいもの（Phase 1）
C-2 外部レビュー / C-3 ゲート / V-2〜V-4 / EH-2〜EH-9 / 残り 21 エージェント /
metrics 収集。

## Phase 2: ゲート導入（Week 2-3）

**ゴール**: C-1 セルフレビューと C-3 計画承認ゲートを有効化し、「承認なしに
exec しない」運用を確立する。

- **モード**: standard（plan + C-1 17 項目 + C-3 + V-1 + V-3）
- **エージェント**: 4 体 — + `qa-reviewer`（C-1/受け入れ）+
  `workflow-conductor`（フェーズ制御）
- **フック**: `EH-1` + `EH-2`（C-3 承認なし exec ブロック /
  `check-c3-approval.sh`）+ `EH-3`（plan_hash 改竄検知）を **warning**
- **成果物**: + review-self.md / approvals/c3.json / test-cases.md

### 使わなくてよいもの（Phase 2）
C-2 外部レビュー / V-4 / EHS-1〜3 / strict 配線 / 残りエージェント /
Orchestrator Mode（親子 PBI）。

## Phase 3: フル運用（Month 1+）

**ゴール**: ゲートを strict 化し、外部レビューとメトリクスを回す。

- **モード**: standard / high-risk / critical（規模で自動判定に移行）
- **エージェント**: 必要に応じ全 23 体（高リスク時 `orchestrator` +
  専門 reviewer 群）
- **フック**: `EH-1`〜`EH-7` を **strict**（block）配線 + `EH-9`（委譲
  commit/push 境界）。critical は `EHS-1`（V-3 必須）/ `EHS-2`（handoff 6
  要素）/ `EHS-3`（fix loop 上限 escalation）
- **外部レビュー**: C-2 / V-3 に river-reviewer 等を接続（#227 IF 参照）
- **メトリクス**: `bin/plangate metrics <TASK> --collect`（[metrics.md](./ai/metrics.md)）

### 使わなくてよいもの（Phase 3）
プロジェクトに不要なら Orchestrator Mode は任意（単一 PBI のみなら不要）。

## 1. フック有効化の推奨順序

| 順序 | フック | 段階 | モード |
|------|--------|------|--------|
| 1 | EH-1（plan 存在） | Phase 1 | warning |
| 2 | EH-2（C-3 承認） / EH-3（plan_hash） | Phase 2 | warning |
| 3 | EH-4（test-cases）/ EH-5（検証ログ）/ EH-6（scope 外） | Phase 3 | block へ昇格 |
| 4 | EH-7（2 段階レビュー）/ EH-9（委譲境界） | Phase 3 | block |
| 5 | EHS-1〜3（strict 追加条件） | Phase 3 (critical) | block |

> warning → block の昇格は破壊的変更（[versioning-stability-policy.md](./ai/versioning-stability-policy.md)
> §2.2 で major）。チーム合意の上でフェーズ境界に合わせて昇格する。

## 2. エージェント最小セット（23 体中）

| 段階 | 必須エージェント | 体数 |
|------|----------------|------|
| Phase 0 | （なし） | 0 |
| Phase 1 | project-planner, implementer | 2 |
| Phase 2 | + qa-reviewer, workflow-conductor | 4 |
| Phase 3 | + orchestrator, reviewer 群（規模に応じ） | 〜23 |

残り 19 エージェントは Phase 3 まで明示的に不要。必要になった時点で
`.claude/agents/` から個別に参照する（全部入り前提にしない）。

## 3. チーム展開チェックリスト

- [ ] Day 1: 各メンバーが Phase 0 で 1 タスク完了
- [ ] Week 1: light モードで plan 生成を 1 回体験
- [ ] Week 2: C-3 ゲートを warning で配線しチームレビュー運用開始
- [ ] Week 3: C-1 17 項目をレビュー文化として定着
- [ ] Month 1: strict 配線 + メトリクス収集開始、規模自動判定へ移行

## 4. 関連

- [`plangate.md`](./plangate.md) — 全体像 / 3 コマンドフロー
- [`.claude/rules/mode-classification.md`](../.claude/rules/mode-classification.md) — 5 モード正本（規模自動判定）
- [`ai/hook-enforcement.md`](./ai/hook-enforcement.md) — フック正本（EH-1〜EHS-3）
- [`ai/versioning-stability-policy.md`](./ai/versioning-stability-policy.md) — warning→block 昇格の互換性扱い
- [#224](https://github.com/s977043/plangate/issues/224) — Plugin 成熟化（導入配布パス）
- [#227](https://github.com/s977043/plangate/issues/227) — river-reviewer 外部レビュー IF（Phase 3 C-2/V-3）
