---
name: plangate-setup
description: PlanGate 初期セットアップを対話的に進めるためのチェックリスト、5 要素対応観点、Human-owned 操作の script 提示テンプレ。doctor を単一検証源とする。
---

# PlanGate Setup — チェックリスト & 観点

> 入力: doctor の構造化出力（`--json`）/ Human からの「完了」報告
> 出力: 不足項目リスト / Human-owned 操作の提示文 / 進捗チェックリスト
> 想定 phase: 初期セットアップ
> カテゴリ: ガイド型セットアップ
> 役割: 手順テンプレと検証観点を再利用単位で保持する

## Setup の 5 要素対応

| 5 要素 | 対応物 | 検証 | 不足時の提示文 |
|--------|--------|------|-------------|
| Context files | `CLAUDE.md` / `AGENTS.md` | ファイル存在確認 | 「CLAUDE.md を作成してください（プロジェクトルール記述）」 |
| Global instructions | `.claude/settings.json` wiring | `doctor --check-settings` | 「`sh scripts/apply-claude-settings.sh` を実行してください」 |
| Folder/Project instructions | `docs/working/` 構造 + TASK 配下 | ディレクトリ存在確認 | 「`mkdir -p docs/working/TASK-XXXX` で新規 TASK を作成してください」 |
| Plugins | `.claude/agents/` / `.claude/skills/` / `.claude/commands/` | ディレクトリ存在確認 | 「`.claude/` 配下に必要な agents/skills/commands を配置してください」 |
| Connectors | Hook（EH-3, EH-8, …）/ CI / MCP | `doctor --json` の `checks[]` で各 Hook 項目を検査 | 「該当 Hook を `.claude/settings.json` の hooks セクションに wire してください」 |

## doctor 出力の解釈観点

`doctor --json` の出力は以下を満たす（PlanGate プロジェクトの設計契約ノートを参照）:

```json
{
  "scope": "...",
  "checks": [
    {"name": "...", "ok": true|false, "level": "fail|warn|info", "detail": "..."}
  ]
}
```

### 不足項目抽出

```
不足項目  := [c for c in checks if c.ok == false]
WARN 項目 := [c for c in checks if c.ok == true && c.level == "warn"]
overall_pass := all(c.ok for c in checks if c.level == "fail")
```

### 提示時の順序

1. `level=fail` の `ok=false` 項目（必須）
2. `level=warn` の `ok=false` 項目（推奨）
3. `level=info` の補足

## Human-owned 操作テンプレ（**提示文のみ・実行禁止**）

セットアップ Agent はこれらを**ユーザーに提示する**だけで、自分では実行しない:

```sh
# settings wiring 適用
sh scripts/apply-claude-settings.sh

# 個別 Hook の有効化（例）
# .claude/settings.json の hooks セクションに該当エントリを追加
```

## チェックポイント記録

各 Step 完了ごとに `status.md` / `decision-log.jsonl` に追記する（[`working-context.md`](../../../.claude/rules/working-context.md) settings タスクロック準拠）:

- `status.md`: Markdown 形式で完了マーカー
- `decision-log.jsonl`: append-only JSON エントリ（pending → resolved）

### 解消不能 FAIL の脱出経路

doctor FAIL が環境制約等で解消困難な場合、以下のいずれかを提示する:

1. **フォローアップ PBI 起票誘導**: `/ai-dev-workflow TASK-XXXX brainstorm` で別 PBI 起票
2. **承知スキップ**: ユーザーが「承知の上で skip」を選択 → `status.md` に skip 理由を明示記録

## 完了条件

setup が完了したと判定する条件:

- `doctor --json` で `overall_pass == true`（`level=fail` の `ok=false` ゼロ）
- かつ `doctor --check-settings` の出力が `^\[check-settings\] PASS:` で始まる
- ユーザーが対話内で完了を確認

## 完了サマリのフォーマット

`status.md` 末尾に以下のセクションを追記:

```markdown
## Setup Summary - YYYY-MM-DD

- 完了項目: [...]
- スキップ項目（承知の上）: [...]
- 残課題: [...]
- 次のアクション候補:
  - 新規 PBI 作成: `/ai-dev-workflow TASK-XXXX brainstorm`
  - 既存 PBI 確認: `/working-context TASK-XXXX`
```
