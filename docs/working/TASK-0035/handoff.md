# Handoff Package — TASK-0035 / TASK-0036

> TASK-0035（setup-team スキル追加）と TASK-0036（full → high-risk 残存置換）を統合した handoff。
> PR #66 でまとめてリリース済み。

## メタ情報

```yaml
task: TASK-0035 / TASK-0036
related_pr: https://github.com/s977043/plangate/pull/66
author: qa-reviewer (Claude Code)
issued_at: 2026-04-26
v1_release: c7aa327 (PR #66 squash merge)
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| TASK-0035: setup-team SKILL.md が plugin/plangate/skills に存在する | PASS | `plugin/plangate/skills/setup-team/SKILL.md` 作成済み |
| TASK-0035: .claude/skills に存在する | PASS | `.claude/skills/setup-team/SKILL.md` 作成済み |
| TASK-0035: .agents/skills に存在する | PASS | `.agents/skills/setup-team/SKILL.md` 作成済み |
| TASK-0035: codex-multi-agent の broken reference が解消される | PASS | 参照先ファイルが存在するようになった |
| TASK-0036: plugin/plangate 側の full → high-risk 置換完了 | PASS | 9 ファイルすべて修正済み（code-optimizer 含む） |
| TASK-0036: .claude/ 側の full → high-risk 置換完了 | PASS | mode-classification.md 含む全ファイル修正済み |
| TASK-0036: Markdownlint CI パス | PASS | PR #66 CI 確認済み |

**総合**: `7/7 基準 PASS`

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| TASK-0037: pg-check × skill-policy-router 連携明示が未完（本タスク時点） | minor | → TASK-0037 で対応済み | No |

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 |
|--------|------|----------|
| setup-team スキルの受け入れテスト（test-cases.md）作成 | 今回は文書のみ、検証スキップ | Low |
| codex-multi-agent の broken reference を全体スキャンして他にないか確認 | 今回は既知の1件のみ対応 | Low |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| TASK-0035/0036 を同一 PR (#66) でまとめてリリース | 別々の PR で分割リリース | 変更規模が小さく分割コストが高いため統合 |
| .agents/skills/setup-team/ に同一ファイルをコピー | .agents/skills からの symlink | symlink は git 管理が複雑になるためコピーで統一 |
| full → high-risk の注記なし置換 | 「full は非推奨 (deprecated: high-risk を使用)」コメント追加 | plugin 版 mode-classification.md には既に注記があり重複になるため省略 |

## 5. 引き継ぎ文書

### 概要

TASK-0035 では、`/setup-team` コマンド呼び出し時に参照されるスキルファイルが存在しなかった問題を解決した。
`plugin/plangate/skills/setup-team/SKILL.md` を新規作成し、`.claude/skills/` および `.agents/skills/` にも配置することで、
`codex-multi-agent/SKILL.md` の broken reference も解消した。

TASK-0036 では、`full` モードラベルを `high-risk` に統一するための残存置換を実施した。
`plugin/plangate/rules/mode-classification.md` は Phase 1 (TASK-0029) で既に更新済みだったが、
`workflow-conductor.md`・`working-context.md`・`ai-dev-workflow.md`・`code-optimizer.md` など
参照側のファイルが未更新のままだった。全9ファイルを修正してリポジトリ全体で `full` モード表記を撲滅した。

### 触れないでほしいファイル

- `plugin/plangate/rules/mode-classification.md`: full → high-risk の正本。既に更新済みのため再変更不要

### 次に手を入れるなら

- v7.3.0 リリース（CHANGELOG 更新 + git タグ）
- setup-team スキルを実際に呼び出してみて動作確認

### 参照リンク

- PR #66: https://github.com/s977043/plangate/pull/66
- plugin README: `plugin/plangate/README.md`
- setup-team SKILL: `plugin/plangate/skills/setup-team/SKILL.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| Markdownlint CI | 1 | 1 | 0 |
| 文書確認（TASK-0035 受入基準） | 3 | 3 | 0 |
| 文書確認（TASK-0036 受入基準） | 4 | 4 | 0 |
