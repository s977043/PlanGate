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

1. 導入先リポジトリの相対パス（例: `.claude/rules/working-context.md`）。
   ただし **本 skill が参照する節（例: `working-context.md` の「ゲート条件」節）が実在することを確認する**。同名でも別内容なら PlanGate の正本ではないため 2 へ進む
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
| `scripts/**` / `bin/**` | コピー対象外 | 目的の CLI は不在 | 未配置 |

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

> 下記は **上流リポジトリ（`s977043/plangate`）を clone し、そのリポジトリルートで
> 実行する場合にのみ成立する**。上の表のとおり `scripts/**` / `bin/**` は 3 経路とも
> 導入先に配布されないため、plugin 経由・Codex 経由の環境では実行できない。

- packet 作成: `./scripts/ai-dev-workflow TASK-XXXX prepare-cloud`
- Cloud task 実行後の同期: `./scripts/ai-dev-workflow TASK-XXXX sync-cloud`
- どちらも `--dry-run` を付けると前提条件の充足状況だけを表示して終了する

### CLI 不在時のフォールバック（導入先では既定）

CLI が無い環境では **packet を手で作る**。両コマンドの処理内容は固定なので、CLI 無しでも
同じ成果物に到達できる。**ゲートと停止条件は CLI の有無に関わらず不変**。

1. **`prepare-cloud` 相当を手で行う** — `plan.md` / `todo.md` / `test-cases.md` /
   `status.md` が揃っていることを確認したうえで、「Deliverable」の転記先に次の節を作り、
   plan / todo / test-cases / status（あれば review-self / review-external）の内容を
   転記する: Task（Task ID / branch 名 / C-3 承認状態 / 最終完了の owner = human）/
   Approved Scope / Constraints / Approved Plan / Todo / Test Cases / Status Notes /
   Self Review・External Review（存在する場合のみ）/ Open Questions・Non-Goals /
   Verification Policy / Approval Request Note / Startup Template
2. **C-3 チェックを省略しない** — CLI は `status.md` に `## C-3 Gate: APPROVED` の行が
   あるかを完全一致で検査し、無ければ packet を生成せず停止する。CLI が無いと
   この自動停止も失われるため、**同じ確認を人手で実行してから packet を作る**。
   未承認なら「Rules」のとおり停止する（CLI の不在は C-3 免除の理由にならない）
3. **`sync-cloud` 相当を手で行う** — packet の Task ID が対象 TASK と一致することを
   確認したうえで、packet に残った changed files / verification results / concerns /
   approval request note を `status.md` へ反映し、**packet に証拠があるものだけ**
   `todo.md` を完了扱いにする。`plan.md` と実装コードはこの同期では変更しない。
   Cloud task の完了は **仮完了（人間承認待ち）** である旨を `status.md` に残す
4. **転記先は導入先のパスに読み替える** — `.codex/manual-cloud-task.md` は配布対象外
   （「読む順序」4 の注記どおり）。導入先では任意のパスに読み替え、Cloud task には
   そのファイルの内容を貼る
5. CLI 実行そのものが必要なら、上流リポジトリ（`s977043/plangate`）を clone して
   そこから実行する

## ローカル実行に切り替えるとき

Codex Cloud を使わずローカル Codex CLI で exec する場合は本 skill ではなく `local-exec-handoff` + `ai-dev-exec` を使う。
