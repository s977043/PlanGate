# PlanGate × Cursor クイックスタート

> Cursor 向けの公式導入手順（Issue [#291](https://github.com/s977043/PlanGate/issues/291)）。
> 設計の正本: [`docs/rfc/provider-cursor.md`](../rfc/provider-cursor.md)

PlanGate を Cursor で使うときの推奨構成は **「CLI でゲート検証 + Agent で計画・実装 + Hook で不変条件」** です。

## 前提

- PlanGate リポジトリ（または submodule）を Cursor で開いている
- `git`, `python3` が利用可能（`jq` は任意・あれば hook パースが速い）

## Level 1 — plan 承認のみ（約 10 分）

```bash
bin/plangate init TASK-0001
# docs/working/TASK-0001/pbi-input.md を編集
```

Cursor Agent に依頼:

```text
docs/plangate.md の plan フェーズに従い、TASK-0001 の plan.md / todo.md / test-cases.md /
review-self.md を生成してください。スキル ai-dev-plan（.agents/skills/ai-dev-plan/SKILL.md）を読んでから作業してください。
```

人間が `plan.md` をレビューし、`approvals/c3.json` で `c3_status: APPROVED` を記録。

```bash
bin/plangate validate TASK-0001
```

## Level 2 — 実装と handoff

C-3 承認後、Agent に `plan.md` と `todo.md` に沿った TDD 実装を依頼。完了後:

```bash
bin/plangate validate TASK-0001 --mode standard
# handoff.md を docs/working/templates/handoff.md に沿って作成
```

## Level 3 — Hook 強制（推奨）

### 1. 作業 TASK を環境変数で固定

```bash
export PLANGATE_HOOK_TASK=TASK-0001
export PLANGATE_HOOK_STRICT=1   # 違反時に編集をブロック（省略時は warning のみ）
```

Cursor を **プロジェクトルートから** 開き直す（hooks はプロジェクト相対パス）。

### 2. Hook の有効化

リポジトリに同梱の `.cursor/hooks.json` が読み込まれます。未反映の場合は
Cursor Settings → Hooks で有効化を確認してください。

初回のみ実行権限:

```bash
chmod +x .cursor/hooks/*.sh scripts/hooks/cursor-adapter.sh scripts/hooks/check-*.sh
```

### 3. 動作確認

`plan.md` を削除した状態で production パス（例: `bin/plangate`）の編集を試すと、
EH-1 が警告またはブロックします。C-3 未承認のまま実装ファイルを編集すると EH-2 が発火します。

## スキルの使い方

| 用途 | スキル | パス |
| --- | --- | --- |
| PBI 整理 | `ai-dev-brainstorm` | `.agents/skills/ai-dev-brainstorm/SKILL.md` |
| plan 生成 | `ai-dev-plan` | `.agents/skills/ai-dev-plan/SKILL.md` |
| C-3 判定 | `plan-review-gate` | `.agents/skills/plan-review-gate/SKILL.md` |
| セルフレビュー | `self-review` | `.agents/skills/self-review/SKILL.md` |
| 作業コンテキスト | `working-context` | `.agents/skills/working-context/SKILL.md` |

プロジェクト `.cursor/skills/` には上記への **symlink** を置いています。Agent はスキル名を指定するか、
`.cursor/rules/plangate.mdc` の指示に従って読み込みます。

Codex と同様、**`.claude/skills/` は Cursor では正本にしない**でください（`.codex/instructions.md` 参照）。

## エージェントについて

| PlanGate | Cursor |
| --- | --- |
| `workflow-conductor` | 親 Agent がフェーズを手動で進行 |
| `implementer` | Agent モード + `feature-implement` スキル |
| `qa-reviewer` | `acceptance-review` スキル + 検証プロンプト |

`.codex/agents/*.toml` / `.claude/agents/*.md` はそのままでは読み込まれません。役割はスキルとプロンプトで代替します。

## exec フェーズ

```bash
export PLANGATE_IMPL_AGENT=cursor
bin/plangate exec TASK-0001
```

現状は **Cursor への手動引き継ぎメッセージ** を表示します（API 自動起動は Phase 2）。
表示された `plan.md` パスを Cursor Agent に渡して実装してください。

## トラブルシュート

| 症状 | 対処 |
| --- | --- |
| Hook が動かない | `PLANGATE_HOOK_TASK` が未設定 → export してセッション再開 |
| 常に許可される | `PLANGATE_HOOK_STRICT` 未設定 → warning のみ |
| スキルが見つからない | `.cursor/skills/` の symlink が切れていないか確認 |
| `plangate doctor` が Claude のみ指摘 | Cursor 配線は `test -f .cursor/hooks.json` で確認（doctor Cursor 検査は Phase 1） |

## 次に読むもの

- [`docs/plangate.md`](../plangate.md) — 全フェーズ詳細
- [`docs/ai/tool-roles.md`](../ai/tool-roles.md) — Claude / Codex 併用（Cursor は実装側を Cursor に置き換え）
- [`docs/ai/hook-enforcement.md`](../ai/hook-enforcement.md) — EH-1〜EH-10 一覧
