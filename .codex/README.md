# Codex Settings

Codex 固有の設定はこのディレクトリに集約する。

## 起動方法

このリポジトリの設定を使うには、`CODEX_HOME` を repo 内の `.codex/` に向けて起動する。

```bash
sh ./scripts/codex-local.sh exec --json "確認のみ。1行で返答。"
```

## Files

- `config.toml` - Codex CLI の実行設定
- `instructions.md` - Codex 向けの読み込みガイド

## Skills

Codex で使うスキルはここに記録する。

- `self-review` - `.claude/skills/self-review/SKILL.md`
- `brainstorming` - `.claude/skills/brainstorming/SKILL.md`
- `systematic-debugging` - `.claude/skills/systematic-debugging/SKILL.md`
- `subagent-driven-development` - `.claude/skills/subagent-driven-development/SKILL.md`
- `engineer-skill-creator` - `.claude/skills/engineer-skill-creator/SKILL.md`
