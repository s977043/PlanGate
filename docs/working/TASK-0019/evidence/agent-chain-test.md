# TASK-0019 Agents 間参照検証

> 実施日: 2026-04-19

## 静的検証

### 6 agents 内の agent-to-agent 参照

```bash
grep -n "subagent_type\|Task(.*agent" plugin/plangate/agents/*.md
```

**結果**: 検出なし

target 6 agents（workflow-conductor, spec-writer, implementer, linter-fixer, acceptance-tester, code-optimizer）は、互いを Task ツールで直接呼び出す記述を持たない。workflow-conductor がフェーズ制御で他 agents を呼ぶ想定だが、定義ファイル内に明示的な呼び出し記述はなく、Claude Code の runtime が文脈に応じて自動選択する形式。

### Rules 参照の解決性

| Agent | Line | 参照 | plugin 内解決 |
|-------|------|------|-------------|
| workflow-conductor.md | 216 | `plugin/plangate/rules/mode-classification.md` | ✅ 参照先ファイル存在確認済み |

## Runtime 検証（未実施）

Claude Code に plugin を install した状態で以下を確認予定（TASK-0019 完了後の統合 runtime 検証）:

| Test | 手順 | 期待結果 |
|------|------|---------|
| AT-1 | `Task(subagent_type="plangate:workflow-conductor", ...)` を起動 | plugin 側 workflow-conductor が応答 |
| AT-2 | `plangate:spec-writer`, `plangate:implementer` 等を起動 | 各 agent が plugin 側で応答 |
| AT-3 | workflow-conductor 内から mode-classification.md を参照する処理が動作 | plugin/plangate/rules/ の内容が読み込まれる |
| AT-4 | legacy 側 `Task(subagent_type="workflow-conductor")` を起動 | legacy 側が応答（dual-run 成立） |

## 判定

静的検証範囲: ✅ PASS

- plugin 内 agents に相互参照の破損なし
- rules 参照が plugin 内パスに修正されている
- legacy 側と plugin 側が同名で並存、prefix で識別可能
