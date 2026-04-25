# Worktree Policy ルール（正本）

> 正本。git worktree を使った隔離実行の適用条件はこのファイルのみで管理する。
> 参照元: `skill-policy-router`（`requiresWorktree` フラグ）、`mode-classification.md`、`completion-gate.md`

## 目的

git worktree を使った隔離実行の適用条件を定義する。
main ブランチへの直接コミットを防ぎ、コードレビューの前にメインラインへの影響を隔離する。

## Mode 別 worktree 要件

| Mode | worktree | 理由 |
|------|----------|------|
| ultra-light | 不要 | typo 修正・設定変更は直接コミット可 |
| light | 不要 | 1 ファイル変更のため影響範囲が限定 |
| standard | 推奨 | 複数ファイル変更 → ブランチ分離が望ましい |
| high-risk | **必須**（推奨） | 機能追加・複数レイヤー変更 → 隔離必須 |
| critical | **必須**（強制） | アーキテクチャ変更 → main への直接コミット禁止 |

## `requiresWorktree` フラグとの接続

`plugin/plangate/skills/skill-policy-router/SKILL.md` が返す GatePolicy に `requiresWorktree` フラグを持つ。

```json
{
  "requiresWorktree": true
}
```

- `requiresWorktree: true` → worktree での実行を要求
- `requiresWorktree: false` → worktree は任意

Mode 別の `requiresWorktree` 初期値:

| Mode | requiresWorktree |
|------|-----------------|
| ultra-light | `false` |
| light | `false` |
| standard | `false`（ただし推奨） |
| high-risk | `true` |
| critical | `true` |

## worktree 命名規則

```text
feature/task-XXXX-{説明}
```

**例**:

- `feature/task-0033-agent-control-worktree-pr`
- `feature/task-0021-hybrid-architecture`

命名は kebab-case で統一し、タスク番号と内容の概要を含める。

## ブロック条件

critical モードで worktree なしに実装を進めている場合、Completion Gate への移行を推奨警告する。

```text
WARNING: Mode=critical で worktree が検出されていません。
main ブランチへの直接コミットは禁止です。
worktree を作成してから実装を再開してください。
```

ただし、worktree の有無を機械的に検出できない場合は、人間の確認を求める。

## worktree の作成手順

```bash
# 新しい worktree を作成してブランチに切り替える
git worktree add ../<ブランチ名> -b <ブランチ名>

# または既存ブランチを worktree として追加する
git worktree add ../<ブランチ名> <ブランチ名>
```

## 関連

- Skill: `skill-policy-router`（`requiresWorktree` フラグ）
- Rule: `completion-gate.md`（Completion Gate 条件との統合）
- Rule: `mode-classification.md`（Mode 定義）
- Iron Law: `GATE POLICY IS DETERMINED BY MODE, NOT BY INTENT`（`skill-policy-router` より）
