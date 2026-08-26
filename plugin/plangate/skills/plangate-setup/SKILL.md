---
name: plangate-setup
description: "PlanGate 初期セットアップを対話的に進めるためのチェックリスト、5 要素対応観点、Human-owned 操作の script 提示テンプレ。doctor を単一検証源とする。Use when: 「PlanGate をセットアップして」「導入したい」「初期設定」「doctor が FAIL する」と依頼された時、または導入直後の環境検証時。"
---

# PlanGate Setup — チェックリスト & 観点

> 入力: doctor の構造化出力（`--json`）/ Human からの「完了」報告
> 出力: 不足項目リスト / Human-owned 操作の提示文 / 進捗チェックリスト
> 想定 phase: 初期セットアップ
> カテゴリ: ガイド型セットアップ
> 役割: 手順テンプレと検証観点を再利用単位で保持する

## 参照解決順（導入先で必ずこの順に探す）

本 skill の参照は上流リポジトリ（`s977043/plangate`）基準の相対パスで書かれている。
導入先ではそのままでは解決できないものがあるため、**次の順で探索する**:

1. 導入先リポジトリの相対パス（例: `.claude/rules/working-context.md`）
2. 無ければ plugin root 配下（例: `<plugin_root>/rules/working-context.md`）
   - **`<plugin_root>` は Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して得た絶対パス**。
     Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
     という文字列をそのまま Read しても必ず失敗する
   - **変数が空・未設定なら glob（`~/.claude/plugins/cache/**` 等）で推測せず 3 へ進む**
3. どちらにも無い場合は **「解決できなかった」と明示**し、推測で内容を補わない
   （`status.md` に「正本 `<path>` を参照できなかった」旨を記録する）

> **手順 3 に落ちても判定基準は緩めない**: 正本が引けない場合の代替は「5 要素対応」表の
> 「検証」列を導入先のファイルで直接確認する手動検証であって、**確認の省略ではない**。
> 正本を参照できないことを理由に判定基準・ゲートを緩めてはならない（未検証項目を
> 「doctor PASS」「確認済み」と書かず、未検証である事実を `status.md` に残す）。

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md` | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `bin/**`（CLI） | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` | コピー対象外（解決不可） | `<plugin_root>/scripts/` は存在するが `install-plangate-skills.sh` のみ（`apply-claude-settings.sh` 等は解決不可） | 未配置（解決不可） |

## CLI 前提（doctor が何を検査するか）

> **前提（Human 決定 #1144）**: plugin / `install.sh --claude` / Codex が導入先へ配るのは
> **読み物層（`skills` / `rules` / `agents` / `commands`）だけ**であり、**CLI（PlanGate CLI 本体）も
> enforcement 層（`scripts/hooks/`）も配布物に含まれない**。`doctor` を実行できるのは
> **上流リポジトリ（`s977043/plangate`）の clone がある環境だけ**である。導入先の
> セットアップ検証で `doctor` に到達したら「CLI が無いため実行できない／上流リポジトリの
> clone が必要」と**明示して停止する**か、下記「5 要素対応」表の「検証」列を導入先の
> ファイルを直接見て手動確認へ置き換える。**CLI が無いことを理由に検証を黙って省略し、
> 「doctor PASS」と読める記録を残してはならない。**

本 skill は `doctor` を単一検証源とするが、**`doctor` は cwd ではなく CLI 本体の位置を基準に
検査する**。`bin/plangate` は自身のパスから `plangate_root`（= `bin/` の親）を求め、
`doctor` / `doctor --json` / `doctor --check-settings` はいずれも
`<CLI の repo root>` 配下（`.claude/settings.json` / `.claude/rules/` / `docs/working/` /
`schemas/` 等）を対象にする。`--dir` 相当のオプションも無い。

| 実行環境 | doctor の可否 | 対象 |
|---------|--------------|------|
| 上流リポジトリの cwd | `bin/plangate doctor [--json] [--check-settings]` | その clone 自身（＝意図どおり） |
| 導入先 + PATH に `plangate` あり | 実行はできるが**セットアップ検証には使えない** | 別の場所にある上流 clone |
| 導入先 + PATH に無い（**既定**） | 実行不可（`bin/` は配布されない） | — |

**導入先プロジェクトのセットアップを検証する用途では、doctor の結果を根拠にしてはならない。**
その場合は下記「5 要素対応」表の「検証」列を**導入先のファイルを直接見て**手動で確認し、
手動確認である旨を `status.md` に記録する（**未検証を「doctor PASS」と書かない**）。

## Setup の 5 要素対応

| 5 要素 | 対応物 | 検証 | 不足時の提示文 |
|--------|--------|------|-------------|
| Context files | `CLAUDE.md` / `AGENTS.md` | ファイル存在確認 | 「CLAUDE.md を作成してください（プロジェクトルール記述）」 |
| Global instructions | `.claude/settings.json` wiring | `doctor --check-settings` | 「`sh scripts/apply-claude-settings.sh` を実行してください」 |
| Folder/Project instructions | `docs/working/` 構造 + TASK 配下 | ディレクトリ存在確認 | 「`mkdir -p docs/working/TASK-XXXX` で新規 TASK を作成してください」 |
| Plugins | `.claude/agents/` / `.claude/skills/` / `.claude/commands/` | ディレクトリ存在確認 | 「`.claude/` 配下に必要な agents/skills/commands を配置してください」 |
| Connectors | Hook（EH-3, EH-8, …）/ CI / MCP | `doctor --json` の `checks[]` で各項目を検査（scope: `v8.6.0 Metrics & Privacy`、EH-8 実行可能属性を含む） | 「該当 Hook を `.claude/settings.json` の hooks セクションに wire してください」 |

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
WARN 項目 := [c for c in checks if c.level == "warn"]
overall_pass := all(c.ok for c in checks if c.level == "fail")
```

### 提示時の順序

1. `level=fail` の `ok=false` 項目（必須）
2. `level=warn` 項目（推奨）
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

各 Step 完了ごとに `status.md` / `decision-log.jsonl` に追記する（`.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md` の settings タスクロック準拠。解決手順は「参照解決順」節）:

- `status.md`: Markdown 形式で完了マーカー
- `decision-log.jsonl`: append-only JSON エントリ（pending → resolved）

### 解消不能 FAIL の脱出経路

doctor FAIL が環境制約等で解消困難な場合、以下のいずれかを提示する:

1. **フォローアップ PBI 起票誘導**: `/ai-dev-workflow <new-task-id> brainstorm` で別 PBI 起票（`<new-task-id>` は次の空き番号）
2. **承知スキップ**: ユーザーが「承知の上で skip」を選択 → `status.md` に skip 理由を明示記録

## 完了条件

setup が完了したと判定する条件（**doctor が導入先を対象にできる環境＝上流リポジトリの cwd の場合**）:

- `doctor --json` で `overall_pass == true`（`level=fail` の `ok=false` ゼロ）
- かつ `doctor --check-settings` の出力が `^\[check-settings\] PASS:` で始まる
- ユーザーが対話内で完了を確認

**doctor が使えない / 別 repo を見てしまう環境**（「CLI 前提」節の 2・3 行目）では、上記 2 条件を
以下の手動確認で代替する。判定根拠が doctor ではなく手動確認であることを `status.md` に明記する:

- 「5 要素対応」表の各行を導入先のファイルで直接確認（存在確認・`.claude/settings.json` の
  `hooks.PreToolUse` に必要な hook が配線されているか）
- ユーザーが対話内で完了を確認

## 完了サマリのフォーマット

`status.md` 末尾に以下のセクションを追記:

```markdown
## Setup Summary - YYYY-MM-DD

- 完了項目: [...]
- スキップ項目（承知の上）: [...]
- 残課題: [...]
- 次のアクション候補:
  - 新規 PBI 作成: `/ai-dev-workflow <new-task-id> brainstorm`
  - 既存 PBI 確認: `/working-context <task_id>`（Agent が Step 0 で動的解決した値）
  - C-3 レビュー確認: `plangate render <task_id>`（v8.14.0〜: HTML でレビュー資料を確認）
  - C-3 承認: `plangate approve <task_id>`（v8.14.0〜: Human ワンアクション承認）
```

> **CLI 行の表記は実行環境に合わせて書き換える**。上流リポジトリの cwd では `bin/plangate render`
> / `bin/plangate approve`、導入先で PATH を通しているなら `plangate ...`。ただし
> `render` / `approve` の `<task_id>` 位置引数も **CLI 本体の位置**を基準に
> `<CLI の repo root>/docs/working/<task_id>` へ解決され、**どちらのサブコマンドも
> パスを明示するオプションを公開していない**ため、**導入先の TASK は対象にできない**
> （上流 clone があれば `python3 scripts/render_review.py --task <id> --work-dir <パス>` で
> render だけは外部ディレクトリを描画できるが、`approve` に同等の逃げ道は無い）。
> CLI が導入先を見られない環境では、この 2 行を
> 「`plan.md` / `review-self.md` を直接読んでレビューし、`approvals/c3.json` を人間が発行」
> に置き換えて記載する。
