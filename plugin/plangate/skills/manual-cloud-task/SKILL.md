---
name: manual-cloud-task
description: "tracked handoff packet を使って Codex Cloud task を手動起動するための指示を組み立てる。Use when: Codex Cloud で exec 相当の作業を手動で進めたい時（PlanGate ではローカル実行が原則・本 skill は optional）。"
---

# Manual Cloud Task (PlanGate / optional)

> **PlanGate での位置付け**: PlanGate は Claude Code / Codex CLI どちらも**ローカル実行が原則**。Codex Cloud を使う場合のみ本 skill を使う（optional）。ローカル exec 再開には `local-exec-handoff` skill を参照。

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
| `.codex/**` / `docs/**` | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |

`install.sh --claude` のコピー対象は `agents` / `skills` / `commands` / `rules` の 4 ディレクトリ
のみ。Codex 経由（`install_codex()`）は `install-plangate-skills.sh` を呼ぶだけで **skills しか
配置されない**ため、rules 参照は解決順 1・2 とも成立せず必ず手順 3 に落ちる。

### 読む順序

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`
   （C-3 / handoff 要件）
   - どちらでも解決できない場合は、下記「Rules」節の C-3 未承認時の停止条件
     （`approvals/c3.json` APPROVED 必須）を代替正本とし、Cloud task 指示に
     「正本 `working-context.md` を参照できなかった」旨を記録する
4. `.codex/manual-cloud-task.md`（**配布対象外**。上流リポジトリで作業する場合のみ解決する。
   導入先では下記「Deliverable」の転記先を導入先の任意パスに読み替える）

## Rules

- Cloud task は人間が手動起動する（AI が自動起動しない）
- GitHub コメント経由で exec を起動しない
- C-3 未承認なら停止する（`approvals/c3.json` APPROVED 必須）
- Cloud task は tracked handoff packet を**唯一の作業指示**として扱う
- `docs/working/` の ticket ファイルはローカル側の作業材料であり、Cloud task から直接読める前提にしない

## Deliverable

Cloud task にそのまま貼れる短い実行指示を作成。承認済み内容は `.codex/manual-cloud-task.md` に転記する。

## CLI 呼び出し

- packet 作成: `./scripts/ai-dev-workflow TASK-XXXX prepare-cloud`
- Cloud task 実行後の同期: `./scripts/ai-dev-workflow TASK-XXXX sync-cloud`

## ローカル実行に切り替えるとき

Codex Cloud を使わずローカル Codex CLI で exec する場合は本 skill ではなく `local-exec-handoff` + `ai-dev-exec` を使う。
