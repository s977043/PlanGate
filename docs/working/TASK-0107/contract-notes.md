# TASK-0107 Contract Notes — T-01 + T-02 Output

> Source: plan.md Step 1 + Step 2
> Generated: 2026-05-22
> Status: contract-notes 確定（後続 T-03〜T-08 の正本）

---

## 1. `bin/plangate doctor --json` 実 schema（U6 解決）

実行: `bin/plangate doctor --json`

### 実 schema（2026-05-22 確認）

```json
{
  "scope": "v8.6.0 Metrics & Privacy",
  "checks": [
    {
      "name": "schemas/plangate-event.schema.json",
      "ok": true,
      "level": "fail",
      "detail": null
    },
    {
      "name": "EH-8 hook is executable",
      "ok": true,
      "level": "warn",
      "detail": null
    },
    {
      "name": "events.ndjson git-ignored (verified)",
      "ok": true,
      "level": "info",
      "detail": "events.ndjson absent (opt-in not yet exercised)"
    }
    // ... (16 checks 確認)
  ]
}
```

### 各キー仕様

| キー | 型 | 役割 |
|------|---|------|
| `scope` | string | doctor の検査スコープ識別子（例: `"v8.6.0 Metrics & Privacy"`） |
| `checks[]` | array | 検査項目リスト |
| `checks[].name` | string | 検査対象（ファイルパス or 検査名） |
| `checks[].ok` | boolean | PASS=true / FAIL=false |
| `checks[].level` | string | 重要度: `fail` / `warn` / `info` |
| `checks[].detail` | string\|null | 補足説明（null 可） |

### Agent 抽出ロジック

```
不足項目 := [c for c in checks if c.ok == false]
WARN 項目 := [c for c in checks if c.ok == true && c.level == "warn"]
overall_pass := all(c.ok for c in checks if c.level == "fail")
```

**重要**: 現状の出力には `passed` / `failures` / `warnings` フィールドは**存在しない**（Codex 事前確認情報と差異あり）。Agent は `checks[]` のみに依存する。

---

## 2. `bin/plangate doctor --check-settings` 出力（AC-12 ゲート用）

実行: `bin/plangate doctor --check-settings`

### 出力例（テキスト、JSON ではない）

```
[check-settings] PASS: settings wiring 契約準拠(target=user)
```

FAIL 時:
```
[check-settings] FAIL: <reason>
```

### Agent 判定ロジック

```
exit_code, stdout = run("bin/plangate doctor --check-settings")
passed := exit_code == 0 AND stdout matches '^\[check-settings\] PASS:'
```

JSON 化されていないため文字列マッチで判定。V-1 / handoff 完了前の必須ゲート。

---

## 3. Agent tools 最小集合（U1 解決）

`setup-coordinator` Agent の tools 定義:

```yaml
tools: Read, Grep, Bash
model: inherit
```

### 各 tool の用途

| tool | 用途 | 制限 |
|------|------|------|
| **Bash** | `bin/plangate doctor --json` / `bin/plangate doctor --check-settings` 実行 | **Human-owned 操作の実行禁止**: `apply-claude-settings.sh` を含む settings 変更スクリプトは絶対に実行しない |
| **Read** | contract-notes.md / pbi-input.md / status.md / decision-log.jsonl / .claude/agents/ / .claude/skills/ / doctor 出力 | 読み取り専用 |
| **Grep** | doctor 出力解析（補助）/ status.md 既存記録の検索 | 読み取り専用 |

### 除外（持たせない tool）

- ❌ **Write**: status.md / decision-log.jsonl への書き込みも Bash 経由（heredoc）で実施する。Write tool を Agent に持たせると Human-owned ファイル（`.claude/settings.json` 等）の書き込みリスクが残る
- ❌ **Edit**: 同上
- ❌ **Glob**: Grep + Bash で代替可能

> **Note**: 設計上「status.md/jsonl への append」が必要だが、Write tool を tools から外し、**Bash `cat >> file` 経由**で実施することで、誤書き込みのリスクを下げる。Agent definition 本文に明示。

---

## 4. Command Agent invocation 方式（U4 解決）

### 既存パターン調査（2026-05-22 確認）

`.claude/commands/` 内の既存 Command:
- `ai-dev-workflow.md`: ワークフロー実行 Command。引数説明 + 本文で Agent 委譲を記述
- `working-context.md`: 作業コンテキスト管理 Command
- `README.md`: コマンド一覧

### `/plangate-setup` Command 構造

`.claude/commands/plangate-setup.md` の最小構造:

```markdown
# /plangate-setup

PlanGate の初期セットアップを対話的に実行する。

ルール詳細: `.claude/rules/working-context.md`
Agent: `.claude/agents/setup-coordinator.md`
Skill: `.claude/skills/plangate-setup/SKILL.md`

## 引数

なし（カレントディレクトリから TASK ID を動的解決）

## 起動フロー

1. `setup-coordinator` Agent を呼び出す
2. Agent が TASK ID を動的解決
3. Agent が `bin/plangate doctor --json` を実行
4. Agent が不足項目を提示
5. ユーザーが Human-owned 操作を実行
6. Agent が doctor 再実行で実体検証
7. 完了時にサマリ出力
```

**重要**: Command は**起動口のみ**（Rule 1 準拠）。実装手順や doctor 解釈ロジックは Agent / Skill に置く。

---

## 5. TASK ID 動的解決ロジック（U7 解決）

### Task-local 方式（採用）

`setup-coordinator` Agent 起動時の判定手順:

```
Step 1: Working directory 確認
  cwd = current_working_directory()

Step 2: docs/working/TASK-XXXX/ 配下かどうか判定
  if cwd matches "*/docs/working/TASK-[0-9]+/*" or cwd ends with "/docs/working/TASK-XXXX":
    task_id := extract_task_id(cwd)
    goto Step 4

Step 3: TASK ID 不明時 guard
  candidates := list_dirs("docs/working/TASK-*")

  if len(candidates) == 0:
    # 0 件: 新規 TASK 必要
    print("Task ID が見つかりません。新規 TASK を作成してください")
    print("候補: /ai-dev-workflow TASK-XXXX brainstorm")
    exit 1

  elif len(candidates) == 1:
    # 1 件のみ
    task_id := candidates[0]
    print(f"Task ID を自動選択: {task_id}")
    confirm_with_user()

  else:
    # 複数: ユーザー選択
    print("複数の TASK 候補が見つかりました:")
    for c in candidates: print(f"  - {c}")
    task_id := prompt_user_choice(candidates)

Step 4: 記録先確定
  status_path := f"docs/working/{task_id}/status.md"
  jsonl_path := f"docs/working/{task_id}/decision-log.jsonl"
```

### 不明時 guard の対話

ユーザー応答例:
- 「TASK ID を指定してください: TASK-XXXX」
- 「新規 TASK を作成してください: `/ai-dev-workflow TASK-XXXX brainstorm`」

---

## 6. 三層責務境界表（T-02 Output）

| 層 | Input | Output | 単一責務 |
|----|------|--------|---------|
| **Command** `/plangate-setup` | ユーザー入力 | Agent invocation | **起動口**（薄い）— 実装手順は持たない |
| **Agent** `setup-coordinator` | Command からの invocation + doctor 出力 + ユーザー応答 | 不足項目提示 / 再検証ループ / status.md+jsonl 追記 / 完了サマリ | **Human action の追跡・Gate 保持・対話・進捗管理** |
| **Skill** `plangate-setup` | Agent からの参照要求 | チェックリスト / 5 要素対応観点 / script 提示テンプレ | **再利用単位の手順本体** |
| **CLI**（既存） `bin/plangate doctor` | `--json` / `--check-settings` フラグ | JSON / テキスト判定 | **機械的検証**（変更しない） |

### 入出力の境界

- Command → Agent: コマンド起動メッセージのみ
- Agent → doctor: `Bash("bin/plangate doctor --json")` / `Bash("bin/plangate doctor --check-settings")`
- Agent → status.md/jsonl: `Bash("cat >> file <<EOF ... EOF")` でリレー
- Agent → Skill: `Read(".claude/skills/plangate-setup/SKILL.md")` でチェックリスト参照

---

## 7. Cowork 5 要素 ⇄ PlanGate 対応表（AC-6）

| Cowork 5 要素 | PlanGate 対応物 | doctor で検証可能 | Agent 検知方法 |
|--------------|----------------|------------------|--------------|
| **Context files** | `CLAUDE.md` / `AGENTS.md` | △（doctor は wiring のみ） | `Bash("test -f CLAUDE.md && test -f AGENTS.md")` |
| **Global instructions** | `.claude/settings.json` wiring | ✅ `--check-settings` | `Bash("bin/plangate doctor --check-settings")` |
| **Folder/Project instructions** | `docs/working/` 構造 | △ | `Bash("test -d docs/working")` + TASK ID 動的解決 |
| **Plugins** | `.claude/{agents,skills,commands}` | △（個別存在） | `Bash("test -d .claude/agents")` 等 |
| **Connectors** | Hook（EH-3 / EH-8 等）/ CI / MCP | ✅ doctor の Hook 検査項目 | doctor --json の `checks[].name` で抽出 |

### Skill 内のチェックリスト構成（U5 解決）

`.claude/skills/plangate-setup/SKILL.md` には以下を含める:

1. **5 要素対応表**（上記）— 各要素ごとに Agent が問うべき質問・確認方法
2. **doctor --json チェック項目抜粋**（全 16 項目から代表項目を選定）
3. **Human-owned 操作テンプレ**: `sh scripts/apply-claude-settings.sh` 等の**提示文**（実行ではない）

---

## 8. 完了サマリの配置（U3 解決）

**採用**: `status.md` 末尾に追記（独立 setup-summary.md は作らない）

- 完了サマリは `status.md` の末尾に `## Setup Summary - YYYY-MM-DD` セクションとして追記
- handoff.md（Rule 5 必須 6 要素）とは別ファイル（命名混同を回避）
- Agent は完了時に `Bash("cat >> status.md <<EOF ... EOF")` で書き込む

---

## 9. 設計確定事項サマリ

| Unknown | 解決 |
|---------|------|
| U1 Agent tools | `Read, Grep, Bash` のみ。Write/Edit 不採用 |
| U3 完了サマリ配置 | `status.md` 末尾に追記 |
| U4 Command invocation | 既存 ai-dev-workflow/working-context パターン踏襲（薄い起動口） |
| U5 Skill チェックリスト粒度 | 5 要素対応表 + 代表 doctor 項目（抜粋） |
| U6 doctor --json schema | `{scope, checks[{name, ok, level, detail}]}`。`passed`/`failures` 不在 |
| U7 TASK ID 解決 | Task-local 方式（cwd → docs/working/TASK-XXXX 検出 → 0/1/複数 で分岐） |

これらは T-03（Skill）/ T-04（Command）/ T-05（Agent）/ T-06（永続ロック）の実装正本。

---

## 参照

- [`plan.md`](./plan.md) Step 1 + Step 2
- [`pbi-input.md`](./pbi-input.md) §5 Unknowns
- [`review-external.md`](./review-external.md) R-008（U7）
- 既存実装: `bin/plangate doctor`（`bin/plangate` 内部）
- 既存 Agent: `.claude/agents/acceptance-tester.md` / `linter-fixer.md`
- 既存 Command: `.claude/commands/ai-dev-workflow.md` / `working-context.md`
