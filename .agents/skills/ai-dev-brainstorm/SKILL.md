---
name: ai-dev-brainstorm
description: "アイデアや曖昧な要件を PlanGate の PBI INPUT PACKAGE に対話的に整理する。Use when: docs/working/TASK-XXXX/pbi-input.md を新規作成したい時、要件をブレストして PBI に落としたい時。"
---

# AI-Driven Brainstorm (PlanGate / Codex 共用)

PlanGate ワークフローの **brainstorm フェーズ** を Codex / Claude Code 両方で実行する skill。

## Read First

### 参照解決順（導入先で必ずこの順に探す）

本 skill の参照は上流リポジトリ基準の相対パスで書かれている。導入先ではそのままでは
解決できないものがあるため、**次の順で探索する**:

1. 導入先リポジトリの相対パス（例: `.claude/rules/working-context.md`）
2. 無ければ plugin root 配下（例: `<plugin_root>/rules/working-context.md`）。
   `<plugin_root>` は **Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して展開・確認した
   絶対パス**（Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
   という文字列をそのまま Read しない）。変数が空・未設定ならキャッシュを glob で推測せず 3 へ進む
3. どちらにも無い場合は **「正本 `<path>` を参照できなかった」と明示**し、推測で内容を補わない

導入経路ごとに配置されるものが違う:

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md` | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `docs/**` | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` / `bin/**` | コピー対象外（解決不可） | 目的の CLI は不在（解決不可） | 未配置（解決不可） |

`install.sh --claude` のコピー対象は `agents` / `skills` / `commands` / `rules` の 4 ディレクトリ
のみ。Codex 経由（`install_codex()`）は `install-plangate-skills.sh` を呼ぶだけで **skills しか
配置されない**ため、rules 参照は解決順 1・2 とも成立せず必ず手順 3 に落ちる。

### 読む順序

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`
   （PBI INPUT PACKAGE の必須要素・ディレクトリ構造の正本）
   - どちらでも解決できない場合は下記「Rules」節を代替正本とし、
     pbi-input.md に「正本 `working-context.md` を参照できなかった」旨を記録する
4. `docs/ai-driven-development.md`（**配布対象外**。上流リポジトリで作業する場合のみ解決する）
   - 最低限: `## ワークフロー全体像`、`## ゲート条件`、`## 成果物の保存先`
   - 解決できない場合は 3 の rules を優先正本とする
5. `docs/working/TASK-XXXX/status.md`（存在する場合）

## Output

- `docs/working/TASK-XXXX/pbi-input.md`
- 必要に応じて `docs/working/TASK-XXXX/status.md`（フェーズ進捗の初期記録）

## Rules

- 1 問ずつ進める（最大 3 問の確認質問・多肢選択推奨）
- まだ `plan.md` / `todo.md` / `test-cases.md` は作成しない
- `pbi-input.md` の必須要素は `.claude/rules/working-context.md` の「pbi-input.md」節を参照
  （解決できない場合は「参照解決順」に従い `<plugin_root>/rules/working-context.md` →
  それも無ければ必須要素を **Context / Why・What（In / Out of scope）・受入基準・Notes from
  Refinement・Estimation Evidence（Risks / Unknowns / Assumptions）** として扱い、
  正本未参照である旨を pbi-input.md に記録する）
- 既存コードや関連制約はコードベースを確認してから要約する

## CLI 呼び出し

- 実コマンド: `./scripts/ai-dev-workflow TASK-XXXX brainstorm`
- skill 側はプロンプト規約のみ（Rule 2 遵守）

## 次フェーズへ

brainstorm 完了後は `ai-dev-plan` skill で B-1→B-2→B-3 フローを実行する。
