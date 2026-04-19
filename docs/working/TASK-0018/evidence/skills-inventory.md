# TASK-0018 Skills/Commands インベントリ

> 調査日: 2026-04-19
> 対象: `.claude/skills/` の 5 件 + `.claude/commands/` の 2 件

## Skills (5 件)

| 名称 | パス | 構造 | 備考 |
|-----|------|------|------|
| brainstorming | `.claude/skills/brainstorming/SKILL.md` | SKILL.md のみ | 相対参照なし |
| self-review | `.claude/skills/self-review/SKILL.md` | SKILL.md のみ | 相対参照なし |
| subagent-driven-development | `.claude/skills/subagent-driven-development/SKILL.md` | SKILL.md のみ | 相対参照なし |
| systematic-debugging | `.claude/skills/systematic-debugging/SKILL.md` | SKILL.md のみ | 相対参照なし |
| codex-multi-agent | `.claude/skills/codex-multi-agent/SKILL.md` | SKILL.md のみ | ⚠️ `../setup-team/SKILL.md` への参照あり（broken: setup-team 不在） |

## Commands (2 件)

| 名称 | パス | 備考 |
|-----|------|------|
| working-context | `.claude/commands/working-context.md` | 単一 md |
| ai-dev-workflow | `.claude/commands/ai-dev-workflow.md` | 単一 md |

## 相対参照の状況

- 4 skills と 2 commands: 相対参照なし（単純コピー可）
- `codex-multi-agent`: `../setup-team/SKILL.md` への参照があるが、参照先自体が既存 repo に不在（既存の broken reference）

## 処理方針

- **skills 5 件**: SKILL.md のみの単純構造。ディレクトリごとコピーで対応可
- **commands 2 件**: 単一 md ファイル。直接コピーで対応可
- **codex-multi-agent の broken reference**: 既存 repo で既に broken。plugin 移植時に修正するか悩む場合は「TASK-0018 スコープ外として維持、将来修正」と evidence に記録

## 採用方針

既存の状態をそのままコピー（broken reference も含めて）。理由:
- スコープ: 「コピーのみ、挙動変更禁止」
- 影響: setup-team 未実装のため影響軽微（codex-multi-agent 利用時にのみ発現）
- 責任分界: 既存 repo の不整合は本 TASK の責務外

将来的な修正は別 issue として起票推奨。
