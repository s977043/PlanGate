# Parallelization Plan — PBI-116

> [`dependency-graph.md`](./dependency-graph.md) の DAG に基づく並行実行計画。

## Phase 構成

| Phase | 並行子 PBI | 推定セッション数 | 開始条件 |
|-------|-----------|--------------|---------|
| Phase 1 | PBI-116-01 単独 | 1（high-risk） | parent C-3 APPROVE 後 |
| Phase 2 | { PBI-116-02, PBI-116-04, PBI-116-06 } 並行 | 1 セッション分（並列） | Phase 1 完了 + Child C-3 × 3 |
| Phase 3 | PBI-116-03 単独 | 1（high-risk） | Phase 2 完了 + Child C-3 |
| Phase 4 | PBI-116-05 単独 | 1（standard） | Phase 3 完了 + Child C-3 |

合計 **4 phase / 推定 4 セッション**（並列で実時間短縮）。

## Phase 別詳細

### Phase 1: 基盤

| 項目 | 値 |
|------|---|
| 子 PBI | PBI-116-01 |
| Mode | high-risk |
| Parallelizable | false |
| 主要成果物 | `docs/ai/core-contract.md`, `CLAUDE.md` / `AGENTS.md` 薄型化 |
| 重要 Gate | Child C-3（Codex C-2 必須）, V-2/V-3 必須 |

### Phase 2: 拡張層（3 並行）

3 子 PBI を 3 つの worktree で同時実行可能。

| 子 PBI | Worktree 候補 | 主要成果物 |
|-------|--------------|----------|
| PBI-116-02 | `.claude/worktrees/PBI-116-02-model-profile/` | `docs/ai/model-profiles.yaml` + 4 プロファイル |
| PBI-116-04 | `.claude/worktrees/PBI-116-04-structured-outputs/` | schema × 4 + `docs/ai/structured-outputs.md` |
| PBI-116-06 | `.claude/worktrees/PBI-116-06-tool-policy/` | `docs/ai/tool-policy.md` 等 3 件 |

### 並行実行時の注意点

- 各 worktree は独立したブランチ（`feat/PBI-116-{02,04,06}-...`）
- merge 順序は `merge_after` の依存に従う（全て PBI-116-01 のみ）
- 相互の `allowed_files` 衝突なし（[`dependency-graph.md`](./dependency-graph.md) で確認済）
- review thread / Gemini 指摘は子 PBI 単位で対応

### Phase 3: 統合設計

| 項目 | 値 |
|------|---|
| 子 PBI | PBI-116-03 |
| Mode | high-risk |
| Parallelizable | false |
| 依存 | PBI-116-01 + PBI-116-02 |
| 主要成果物 | `docs/ai/prompt-assembly.md`, `bin/plangate-prompt-assemble` |
| 重要 Gate | Child C-3（Codex C-2 必須）, V-2/V-3 必須 |

### Phase 4: 検証層

| 項目 | 値 |
|------|---|
| 子 PBI | PBI-116-05 |
| Mode | standard |
| Parallelizable | false |
| 依存 | 全子 PBI |
| 主要成果物 | `docs/ai/eval-plan.md`, `docs/ai/eval-cases/*.md` × 7 件以上 |

## 並列度の選択基準

- **完全直列実行**: Phase 1 → 2-1 → 2-2 → 2-3 → 3 → 4（6 セッション、安全だが長い）
- **Phase 2 並列**: Phase 1 → { 2-1 / 2-2 / 2-3 並行 } → 3 → 4（**推奨、4 セッション**）
- **より積極的並列**: Phase 2 並列 + Phase 3 を 2-3 と並走（リスク高、推奨しない）

**推奨**: Phase 2 のみ並列。Phase 3 は Phase 2 全完了後に開始（依存関係上）。

## 失敗時の戻し方

- Phase 1 で C-3 REJECT → 親 PBI 再分解検討（DRAFT に戻す）
- Phase 2 のいずれかで失敗 → 当該子 PBI のみ block、他は継続
- Phase 3 で失敗 → Phase 2 の成果物を見直し、必要なら追加子 PBI を起票
- Phase 4 で eval FAIL → 該当 phase に戻り再修正

## Worktree 運用方針

- Phase 2 並列時は `git worktree add` で 3 つの worktree を作成
- 各 worktree は `feat/PBI-116-NN-...` ブランチに紐付け
- 完了後は worktree を削除（lock 解除 → remove）
