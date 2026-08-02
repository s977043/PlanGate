---
name: local-exec-handoff
description: "PlanGate のローカル実行（Codex CLI / Claude Code）で exec を再開・引き継ぐための短い指示パケットを作る。Use when: セッション断後に exec を再開したい時、別エージェント・別ツールに作業を引き継ぎたい時。"
---

# Local Exec Handoff (PlanGate / Codex 共用)

PlanGate は Claude Code / Codex CLI ともローカル実行が原則。本 skill は **ローカルでの exec 再開・ツール間引き継ぎ** に使う短いパケットを組み立てる（Codex Cloud 用は `manual-cloud-task` を参照）。

## Read First

### 参照解決順（導入先で必ずこの順に探す）

本 skill の参照は上流リポジトリ（`s977043/plangate`）基準の相対パスで書かれている。
導入先ではそのままでは解決できないものがあるため、**次の順で探索する**:

1. 導入先リポジトリの相対パス（`.claude/rules/working-context.md`）
2. 無ければ plugin root 配下（`<plugin_root>/rules/working-context.md`）
   - **`<plugin_root>` は Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して得た絶対パス**。
     Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
     という文字列をそのまま Read しても必ず失敗する
   - **変数が空・未設定なら glob（`~/.claude/plugins/cache/**` 等）で推測せず 3 へ進む**
3. どちらにも無い場合は **「解決できなかった」と明示**し、推測で内容を補わない
   （packet に「正本 `<path>` を参照できなかった」旨を書く）

> **手順 3 に落ちても判定基準は緩めない**: 正本が引けない場合でも、本 skill「Rules」節
> （C-3 未承認なら exec 再開を拒否 / EH-8 Privacy 準拠 / 受け手の環境に合わせたコマンド表記）と
> 「Deliverable」の必須項目は**すべて満たす**。正本を参照できないことを理由に判定基準・
> ゲートを緩めてはならない（とくに `approvals/c3.json` の APPROVED 確認は省略不可）。

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md`（下記 3） | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `bin/**`（CLI） | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` | コピー対象外（解決不可） | `<plugin_root>/scripts/` は存在するが `install-plangate-skills.sh` のみ（`codex-guarded.sh` 等は解決不可） | 未配置（解決不可） |

`docs/working/TASK-XXXX/*`（下記 4〜7）は**配布物ではなく導入先で作成する作業成果物**なので、
導入先リポジトリ内でそのまま解決する。

### 読む順序

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`（current-state.md / status.md 役割分担の正本）
4. `docs/working/TASK-XXXX/INDEX.md`
5. `docs/working/TASK-XXXX/current-state.md`
6. `docs/working/TASK-XXXX/status.md`（最終セクション）
7. `docs/working/TASK-XXXX/approvals/c3.json`（APPROVED 確認）

## Rules

- C-3 未承認なら exec 再開を拒否（`approvals/c3.json` が承認済みであること。**legacy は `c3_status: APPROVED`、c3-prime（`approval_kind: "c3-prime"`）は `decision: "AUTO_APPROVED"` + Plan Package 束縛検証**。判定手順の正本は `ai-dev-exec` skill「前提条件（exec 開始ゲート）」節）
- handoff packet は **次の担当者が 1 分で再開できる粒度**
- 機密情報（events.ndjson / 個人情報 / 認証情報）を含めない（EH-8 Privacy 準拠）
- ツール依存（Claude Code 固有コマンド等）を含めず、PlanGate 共通 CLI（`plangate` / `./scripts/ai-dev-workflow`）に統一する。**コマンド表記は packet の受け手の実行環境に合わせる**（上流リポジトリの cwd なら `bin/plangate`、導入先で PATH を通しているなら `plangate`、CLI が無いなら手順を文章で書く。「CLI 呼び出し」節参照）。**`ai-dev-workflow` は PATH に載るインストール経路が無い**ため、単体名で書かず必ず `./scripts/ai-dev-workflow TASK-XXXX <sub>` と書く（成立するのは**上流リポジトリの cwd のみ**。`scripts/` は配布対象外なので導入先の packet には書かない）

## Deliverable

以下を含む短い再開指示（10〜30 行程度）:

- **TASK ID**
- **現在のフェーズ**: exec / verify / handoff のどれか
- **直近の完了タスク**: todo.md 該当行
- **次にやること**: 1〜3 件の具体的な手順
- **触ってよいファイル範囲**: plan.md「Files / Components to Touch」抜粋
- **触ってはいけないファイル**: forbidden_files / Hardening Override 領域
- **再開コマンド**: 「CLI 呼び出し」節の表から**受け手の実行環境に合う行だけ**を書き写す（両方の表記を並べない）。CLI が無い環境では「`current-state.md` を読んで再開」と手順を書く

## CLI 呼び出し

**呼び出し表記は実行環境で変わる**。相対パス形式（`bin/plangate` / `./scripts/...`）が成立するのは
**上流リポジトリ（`s977043/plangate`）を clone した cwd に居るときだけ**で、導入先には `bin/` も
`scripts/`（の CLI 本体）も配置されない。導入先で PATH を通した場合のコマンド名は
**`plangate`**（`bin/plangate` ではない）。

| 用途 | 上流リポジトリの cwd | 導入先 + PATH に `plangate` あり | 導入先 + PATH に無い（**既定**） |
|------|---------------------|----------------------------------|--------------------------------|
| current-state 表示 | `bin/plangate resume TASK-XXXX` | **導入先の TASK には使えない**（`--dir` 相当なし）→ `current-state.md` を直接読む | `current-state.md` を直接読む |
| フェーズ確認 | `bin/plangate status TASK-XXXX` | 同上 → `status.md` / `INDEX.md` を直接読む | `status.md` / `INDEX.md` を直接読む |
| exec 継続 | `bin/plangate exec TASK-XXXX` | 同上 → 手動で TDD 実行（ゲート確認は `ai-dev-exec` skill） | 手動で TDD 実行 |
| 検証 | `bin/plangate validate TASK-XXXX` | `plangate validate --dir docs/working/TASK-XXXX` | `ai-dev-exec` skill の sha256 突合フォールバック |

> **注意: `TASK-XXXX` 位置引数は cwd ではなく CLI 本体の位置を基準に解決される。**
> `bin/plangate` は自身のパスから `plangate_root`（= `bin/` の親）を求め、
> `<CLI の repo root>/docs/working/TASK-XXXX` を読み書きする。`bin/` は導入先に配置されない
> ため、PATH 上の `plangate` は必ず**別の場所にある上流 clone** の実体を指す。cwd 非依存で
> パスを明示できる `--dir` を持つのは `validate` / `validate-schemas` **だけ**で、
> `resume` / `status` / `exec` に相当オプションは無い。

packet 自体は手動構築。専用 CLI は環境を問わず未提供（CLI がある環境では `resume` + `status` の出力を整形し、無い環境では `current-state.md` / `status.md` を読んで整形する）。

## ツール別読み替え

- **Codex CLI**: `.codex/` 配下にパケットを置く必要なし。`plangate resume` 出力（無ければ `current-state.md`）と本 skill Deliverable で十分。**上流リポジトリで作業する場合の exec 再開は `scripts/codex-guarded.sh --task TASK-XXXX exec --full-auto`** を推奨（pre/post-flight で plan_hash 整合・settings タスクロック検証）。session 中の物理 hook は `.codex/hooks.json` で EH-1/2/3/6/9 が自動発火する (PR #347)。**`scripts/codex-guarded.sh` と `.codex/hooks.json` はどちらも配布対象外**なので、Codex への導入経路（skills のみ配置）ではこれらは存在せず、ゲートは packet 内の手順で人手維持する。
- **Claude Code**: `/working-context` skill と組み合わせて利用。上流リポジトリでは `PreToolUse:Write/Edit` hook が EH-3/EH-6/EH-9 を強制するため wrapper 不要。**導入先では hook が配線されているとは限らない**ため、packet に「plan_hash 突合を exec 開始前に自分で実行する」旨を明記する。
