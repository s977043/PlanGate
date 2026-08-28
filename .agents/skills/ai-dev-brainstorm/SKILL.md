---
name: ai-dev-brainstorm
description: "アイデアや曖昧な要件を PlanGate の PBI INPUT PACKAGE に対話的に整理する。Use when: docs/working/TASK-XXXX/pbi-input.md を新規作成したい時、要件をブレストして PBI に落としたい時。"
---

# AI-Driven Brainstorm (PlanGate / Codex 共用)

PlanGate ワークフローの **brainstorm フェーズ** を Codex / Claude Code 両方で実行する skill。

> 本スキルは **bundled resources**（`references/`）で自己完結する。
>
> **パス表記の規約（重要）**: 本 SKILL.md 中の `references/…` は、すべて **本スキル
> ディレクトリからの相対パス**（= `<skill_dir>/…`）であって、導入先リポジトリのルートからの
> 相対パスではない。実行時はまず `<skill_dir>`（このファイルが置かれているディレクトリ）を
> 解決してから使う:
>
> | 環境 | `<skill_dir>` |
> | --- | --- |
> | plugin 導入先（Claude marketplace） | `<plugin_root>/skills/ai-dev-brainstorm/` |
> | `install.sh --claude` 導入先 | `.claude/skills/ai-dev-brainstorm/` |
> | Codex 導入先 | `.codex/skills/ai-dev-brainstorm/` |
> | 上流リポジトリ（正本側） | `.agents/skills/ai-dev-brainstorm/` |
>
> 導入先が独自の正本（上流リポジトリの `docs/` 配下に相当するもの）を別途保持している
> 場合は、そちらを優先すること。

## Read First

### 参照解決順（導入先で必ずこの順に探す）

本 Skill は **上流リポジトリ基準の `docs/**` パスを直接参照しない**（#1232）。`docs/**` は
`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**であり、
書いた時点で導入先では必ず空振りするためである。参照の解決は次の順で行う:

1. **`<skill_dir>` 配下の同梱物（`references/`）を第一に読む** — ワークフロー正本と実行契約は
   本スキルに同梱されている（「同梱リファレンス」節の一覧）
2. 導入先リポジトリが独自の正本（上流の `docs/` 配下に相当するもの）を保持していれば、
   そちらを優先する
3. **rules（`rules/*.md`）だけは配布経路によって着地が異なる**ため、次の順で探す:
   1. 導入先リポジトリの相対パス（例: `.claude/rules/working-context.md`）。
      ただし **本 skill が参照する節（例: `working-context.md` の「pbi-input.md」節）が実在することを確認する**。同名でも別内容なら PlanGate の正本ではないため次へ進む
   2. 無ければ plugin root 配下（例: `<plugin_root>/rules/working-context.md`）。
      `<plugin_root>` は **Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して展開・確認した
      絶対パス**（Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
      という文字列をそのまま Read しない）。変数が空・未設定ならキャッシュを glob で推測せず次へ進む
4. いずれでも解決できなければ **「正本 `<path>` を参照できなかった」と明示**し、同梱
   `references/` と本 Skill の記述を代替正本として扱い、推測で内容を補わない

**plugin root 直下に `docs/` を探しに行かないこと**: plugin が配布するのは
`agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として
認識せず、plugin root 配下に相当する配布物が存在しないため必ず空振りする。

導入経路ごとに配置されるものが違う:

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md` | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 4 へ）** |
| ワークフロー正本・実行契約 | **`<skill_dir>/references/` に同梱（解決可）** | **`<skill_dir>/references/` に同梱（解決可）** | **`<skill_dir>/references/` に同梱（解決可）** |
| `scripts/**` / `bin/**` | コピー対象外（解決不可） | 目的の CLI は不在（解決不可） | 未配置（解決不可） |

> **例外（上流リポジトリ内のドッグフーディング経路 / #1249 MINOR-3）**: 上表「Codex 経由」の
> 「同梱（解決可）」が成立するのは **配布物経由**（`plugin/plangate/scripts/install-plangate-skills.sh`。
> source は `plugin/plangate/skills/`）に限る。上流リポジトリ自身が `.codex/skills/` を作る
> `scripts/install-plangate-skills-to-codex.sh` は source が `.agents/skills/` であり、そこには
> 本 skill の `references/` が **存在しない**（`references/` は `scripts/sync-plugin-plangate.sh` が
> `plugin/plangate/skills/**` にだけ生成する）。したがって上流 repo の
> `.codex/skills/<skill>/references/` は **構造上つねに不在**であり、この経路では契約 doc・
> テンプレートは手順 4（解決できなかったと明示）に落ちる。上流では `docs/**` の正本を直接
> 読めるため実害は無いが、上表の「解決可」を上流の `.codex/` にまで拡大解釈しないこと。
> 経路自体の是正（source の一本化）は #1086 の裁定待ち。

`install.sh --claude` のコピー対象は `agents` / `skills` / `commands` / `rules` の 4 ディレクトリ
のみ。Codex 経由（`install_codex()`）は `install-plangate-skills.sh` を呼ぶだけで **skills しか
配置されない**ため、rules 参照は解決順 3-1・3-2 とも成立せず必ず手順 4 に落ちる。

### 同梱リファレンス（`<skill_dir>/references/`）

| ファイル | 役割 |
|---------|------|
| `references/ai-driven-development.md` | ワークフロー全体像・ゲート条件・成果物の保存先 |
| `references/core-contract.md` | 実行契約（Iron Law / Stop rules / Output discipline）の正本 |
| `references/plangate.md` | PlanGate 概要ガイド |

### 読む順序

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`
   （PBI INPUT PACKAGE の必須要素・ディレクトリ構造の正本）
   - どちらでも解決できない場合は下記「Rules」節を代替正本とし、
     pbi-input.md に「正本 `working-context.md` を参照できなかった」旨を記録する
4. `references/ai-driven-development.md`（**同梱**。導入先が独自正本を持つ場合はそちらを優先）
   - 最低限: `## ワークフロー全体像`、`## ゲート条件`、`## 成果物の保存先`
5. `docs/working/TASK-XXXX/status.md`（**導入先で作成する作業成果物**。存在する場合）

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

> 下記は **上流リポジトリ（`s977043/plangate`）を clone し、そのリポジトリルートで
> 実行する場合にのみ成立する**。上の表のとおり `scripts/**` / `bin/**` は 3 経路とも
> 導入先に配布されないため、plugin 経由・Codex 経由の環境では実行できない。

- 実コマンド: `./scripts/ai-dev-workflow TASK-XXXX brainstorm`（`--dry-run` で生成先の確認のみ）
- skill 側はプロンプト規約のみ（Rule 2 遵守）

### CLI 不在時のフォールバック（導入先では既定）

CLI が無くても brainstorm は成立する。同コマンドは **作業ディレクトリを作って `status.md`
スタブを置き、「ai-dev-brainstorm skill を適用せよ」というプロンプトでエージェントを起動する
だけのランチャ**であり、対話も生成も本 skill の手順が担っている。

1. **本 skill の手順をそのまま実行する** — 「Read First」の読む順序 →「Rules」
   （1 問ずつ・最大 3 問・plan/todo/test-cases は作らない）→「Output」という順序と
   出力契約は **CLI の有無に関わらず不変**
2. **作業ディレクトリは自分で用意する** — CLI が行うのは `docs/working/TASK-XXXX/` の
   作成と `status.md` スタブ生成だけ。導入先では同じパス（または導入先の working context
   に相当するパス）を手で作り、`pbi-input.md` と `status.md` をそこに置く
3. **後続ゲートを省略しない** — brainstorm の出力は `pbi-input.md` までであり、
   plan / C-1 / C-2 / C-3 は CLI が無くても従来どおり必要。CLI が使えないことを理由に
   `ai-dev-plan` 以降のゲートを飛ばさない
4. CLI 実行そのものが必要なら、上流リポジトリ（`s977043/plangate`）を clone して
   そこから実行する

## 次フェーズへ

brainstorm 完了後は `ai-dev-plan` skill で B-1→B-2→B-3 フローを実行する。
