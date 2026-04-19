# TASK-0018 Skills/Commands 呼び出し検証結果

> 実施日: 2026-04-19

## 検証スコープ

**実施した検証（静的検証）**:
1. plugin 配下の skills/commands がすべて配置されていること
2. ソースと plugin 側のファイル内容が完全一致
3. 既存 `.claude/skills/` / `.claude/commands/` が破壊されていないこと
4. plugin 構造が Claude Code plugin 仕様に準拠（TASK-0017 evidence 参照）

**未実施の検証（runtime E2E）**:
- Claude Code を plugin 有効化状態で起動し、`plangate:<skill>` で呼び出して応答を確認
- legacy 側との同時呼び出しでの識別（dual-run）

### 理由

Runtime 検証は Claude Code セッションの再起動と plugin 登録（marketplace or local install）を伴うため、本 TASK の PR マージ後に別途実施する。静的検証で plugin 構造と内容の正しさを担保し、runtime 検証は TASK-0019（agents 移植）完了後にまとめて実施する方針。

## 静的検証結果

### 1. 配置件数

```
plugin/plangate/skills/  → 5 dirs (brainstorming, self-review, subagent-driven-development, systematic-debugging, codex-multi-agent)
plugin/plangate/commands/ → 2 files (working-context.md, ai-dev-workflow.md)
```

✅ PASS — 期待値一致

### 2. コンテンツ一致

全 5 skills の SKILL.md および 2 commands の .md が、`.claude/` ソースと完全一致（`diff -rq` で差分 0）。

✅ PASS

### 3. 非破壊確認

```bash
git diff --stat 90207dc4cb6f7d608f6e01eadd601430b844d4ae -- .claude/skills/ .claude/commands/
```

→ 出力空（変更 0 件）

✅ PASS — デュアル運用成立

### 4. 構造適合性

- skills: `<skill-name>/SKILL.md` 形式（Claude Code plugin 仕様準拠）
- commands: `<command-name>.md` 直置き（Claude Code plugin 仕様準拠）
- frontmatter（`name`, `description`）は既存ファイルを維持

✅ PASS

## Runtime 検証（TASK-0019 完了後に実施予定）

### 予定テスト

| Test ID | 手順 | 期待結果 |
|---------|------|---------|
| RT-1 | CC で plugin を local install し、`plangate:brainstorming` を実行 | plugin 側の brainstorming が起動 |
| RT-2 | 同様に残り 4 skills | 全 5 skills が plugin 経由で起動 |
| RT-3 | `/working-context` を呼び出し、plugin/legacy の応答を識別 | いずれかが起動し、応答から由来が判別できる |
| RT-4 | `/ai-dev-workflow` 同様 | 起動し、由来判別 |
| RT-5 | legacy `brainstorming`（prefix なし）を呼び出し | legacy 側が起動 |

実施は TASK-0019 (agents 移植) 完了後の **統合 runtime 検証** に含める。
