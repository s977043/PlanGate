# TASK-0016 統合 Runtime 検証結果

> 実施日: 2026-04-20
> 対象: plugin `plangate` v0.1.0
> 検証コマンド: `claude --plugin-dir /Users/user/Documents/GitHub/plangate/plugin/plangate --print`

## 検証環境

- Claude Code: v2.1.114
- 検証方式: `--plugin-dir` フラグで session-local に plugin をロード
- 検証 host: 本リポジトリ内から非対話 `--print` モードで発火

## 検証結果サマリ

| ID | 検証項目 | 結果 | 根拠 |
|----|---------|------|------|
| V-1 | Plugin manifest validation | ✅ PASS | `claude plugin validate` が warnings のみで成功（既存 commands に frontmatter 欠落、legacy 側と同じ状態） |
| V-2 | Plugin 認識 | ✅ PASS | `plangate:` prefix 付き 5 skills + 6 agents が discovery される |
| V-3 | Skill 呼び出し | ✅ PASS | `plangate:brainstorming` が `/Users/user/Documents/GitHub/plangate/plugin/plangate/skills/brainstorming` から起動 |
| V-4 | Agent 呼び出し | ✅ PASS | `plangate:acceptance-tester` が正しい定義で応答 |
| V-5 | Commands 認識 | ✅ PASS | `/working-context`, `/ai-dev-workflow` が 2 copies（plugin + legacy）で登録 |
| V-6 | Rules 参照解決 | ✅ PASS | `plangate:workflow-conductor` が `plugin/plangate/rules/mode-classification.md` を報告 |
| V-7 | Dual-run 成立 | ✅ PASS | legacy 側は `.claude/` に温存、plugin は session-local で併存 |

## 詳細ログ

### V-1: Manifest Validation

```bash
$ claude plugin validate plugin/plangate
Validating plugin manifest: /Users/user/Documents/GitHub/plangate/plugin/plangate/.claude-plugin/plugin.json
Validating command: .../commands/working-context.md
  ⚠ frontmatter: No frontmatter block found
Validating command: .../commands/ai-dev-workflow.md
  ⚠ frontmatter: No frontmatter block found
✔ Validation passed with warnings
```

警告は legacy 側 `.claude/commands/*.md` と同様の状態（本 TASK のスコープ外、既存の仕様）。

### V-2: Plugin Discovery

プロンプト: `What plangate-prefixed skills/agents/commands are available to you right now?`

応答:
```
Skills:
- plangate:systematic-debugging
- plangate:self-review
- plangate:brainstorming
- plangate:codex-multi-agent
- plangate:subagent-driven-development

Agents:
- plangate:acceptance-tester
- plangate:code-optimizer
- plangate:implementer
- plangate:linter-fixer
- plangate:spec-writer
- plangate:workflow-conductor
```

### V-3: Skill Invocation

プロンプト: `Invoke the plangate:brainstorming skill briefly. Report the skill's base directory path.`

応答（抜粋）:
```
スキルが正常にロードされました。
ベースディレクトリ: /Users/user/Documents/GitHub/plangate/plugin/plangate/skills/brainstorming
```

### V-4: Agent Invocation

プロンプト: `Invoke Task tool with subagent_type=plangate:acceptance-tester. Report its definition.`

応答（抜粋）:
```
エージェント応答:
> 私は V-1 受け入れ検査エージェントで、test-cases.md の完了条件と実行結果を機械的に突合し、PASS/FAIL を判定する役割です。

解決方法:
- Agent ツール（Task tool）に subagent_type=plangate:acceptance-tester を指定して起動
- 定義: "PlanGate V-1 受け入れ検査エージェント。test-cases.md の完了条件を1つずつ機械的に突合し、PASS/FAIL を判定する。推測ではなく実行結果のみで判定する。"（Tools: Read, Grep, Glob, Bash）
```

### V-5: Commands Discovery

プロンプト: `List commands containing 'working' or 'ai-dev'.`

応答:
```
- /working-context
- /ai-dev-workflow
（/working-context と /ai-dev-workflow は 2 件ずつリストに登場）
```

2 copies = plugin 側と legacy 側の両方が認識されている（dual-run 成立の証跡）。

### V-6: Rules Reference Resolution

プロンプト: `Invoke plangate:workflow-conductor. Ask it to report the path it uses for mode-classification.md.`

応答:
```
workflow-conductor が報告した参照パス（逐語）:
plugin/plangate/rules/mode-classification.md
```

TASK-0019 で書き換えた plugin 内パスが、実際の runtime で正しく読み込まれている。

## 結論

**TASK-0016 Claude Code plugin 化は静的・動的の両面で完全に機能している。**

- Plugin インストール → skill/agent/command/rules の自動 discovery
- Plugin prefix（`plangate:`）での明示呼び出しが機能
- Legacy `.claude/` 構成との dual-run が成立
- rules 参照 path が plugin 内に正しく解決

受入条件（親 PBI + 子 4 TASK）の全項目が runtime で実証され、**plugin 0.1.0 は他プロジェクトへの配布が技術的に可能**。

## 残課題（将来）

1. Commands の frontmatter 整備（既存 legacy 側も同じ状態、plugin 固有の問題ではない）
2. Marketplace 公開（`claude plugin install plangate` で入手可能にする）
3. Hooks の実装（現バージョンは空の枠のみ）
4. `test-engineer` / `release-manager` agent の新規作成（critical モード対応の完備）

## 付帯データ

- ランタイム検証日: 2026-04-20
- Claude Code バージョン: 2.1.114
- Plugin バージョン: 0.1.0
- Plugin path: `/Users/user/Documents/GitHub/plangate/plugin/plangate`
- Base commit (main): `391a700`
