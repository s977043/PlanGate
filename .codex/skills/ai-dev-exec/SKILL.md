---
name: ai-dev-exec
description: "PlanGate の exec フェーズを TDD で実行する。Use when: C-3 APPROVED 後にコード実装を開始したい時、workflow-conductor 配下で実装タスクを進めたい時。"
---

# AI-Driven Exec (PlanGate / Codex 共用)

PlanGate ワークフローの **exec フェーズ（WF-04 Build & Refine）** を Codex / Claude Code 両方で実行する skill。

> 本スキルは **bundled resources**（`references/`）で自己完結する。
>
> **パス表記の規約（重要）**: 本 SKILL.md 中の `references/…` は、すべて **本スキル
> ディレクトリからの相対パス**（= `<skill_dir>/…`）であって、導入先リポジトリのルートからの
> 相対パスではない。実行時はまず `<skill_dir>`（このファイルが置かれているディレクトリ）を
> 解決してから使う:
>
> | 環境 | `<skill_dir>` |
> | --- | --- |
> | plugin 導入先（Claude marketplace） | `<plugin_root>/skills/ai-dev-exec/` |
> | `install.sh --claude` 導入先 | `.claude/skills/ai-dev-exec/` |
> | Codex 導入先 | `.codex/skills/ai-dev-exec/` |
> | 上流リポジトリ（正本側） | `.agents/skills/ai-dev-exec/` |
>
> 導入先が独自の正本（上流リポジトリの `docs/` 配下に相当するもの）を別途保持している
> 場合は、そちらを優先すること。

## 前提条件（exec 開始ゲート）

1. `docs/working/TASK-XXXX/approvals/c3.json` が存在し、**その `approval_kind` に応じた承認条件**を
   満たすこと。判別は **python3 の strict JSON** で行う（非アンカーな `grep`/`sed` は c3-prime で
   誤動作する。契約 §5）:

   | record 種別 | 判別 | 承認済みと見なす条件 |
   |------------|------|--------------------|
   | **legacy** | `approval_kind` キー **なし** | `c3_status: APPROVED` |
   | **c3-prime** | `approval_kind: "c3-prime"` | `decision: "AUTO_APPROVED"`（**`c3_status` は契約 §5 で明示禁止**。含まれていたら FAIL）**かつ** Plan Package 束縛の全数検証 PASS（`plan_hash` / `artifact_hashes` 6 要素 / `plan_package_hash` / `source_sha` / reviewer verdict 整合）。正本: 同梱 `references/c3-prime-contract.md` §2〜§5 |
   | それ以外の値 | — | **受理拒否**（exec 不可） |

2. **validate 相当が PASS**（plan_hash 整合 / artifact 整合 / EH-3 整合）
3. **exec 入口も上記 1 と同じ分岐で承認済み record のみ受理する**（CLI がある環境では
   CLI 側が機械チェック済み。CLI が無い環境では自分で確認する）

これらが満たされなければ exec を**開始しない**。実際のコマンド表記（`bin/plangate` /
`plangate` / CLI 不在）・`TASK-XXXX` の解決先・CLI が無い環境での代替手順は
「CLI 呼び出し」節を参照する（**CLI が無いことを理由にゲートを省略しない**）。

> **settings タスクロック** (`plangate doctor --check-settings`) は **V-1 / handoff 完了の前提条件**（`.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md` が正本）。exec 入口では block しない。詳細は `ai-dev-verify` skill。

## Read First

### 参照解決順（導入先で必ずこの順に探す）

本 Skill は **上流リポジトリ基準の `docs/**` パスを直接参照しない**（#1232）。`docs/**` は
`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**であり、
書いた時点で導入先では必ず空振りするためである。参照の解決は次の順で行う:

1. **`<skill_dir>` 配下の同梱物（`references/`）を第一に読む** — 契約 doc は本スキルに
   同梱されている（「同梱リファレンス」節の一覧）
2. 導入先リポジトリが独自の正本（上流の `docs/` 配下に相当するもの）を保持していれば、
   そちらを優先する
3. **rules（`rules/*.md`）だけは配布経路によって着地が異なる**ため、次の順で探す:
   1. 導入先リポジトリの相対パス（例: `.claude/rules/working-context.md`）
   2. 無ければ plugin root 配下（例: `<plugin_root>/rules/working-context.md`）
      - **`<plugin_root>` は Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して得た絶対パス**。
        Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
        という文字列をそのまま Read しても必ず失敗する
      - **変数が空・未設定なら glob（`~/.claude/plugins/cache/**` 等）で推測せず次へ進む**
4. いずれでも解決できなければ **「解決できなかった」と明示**し、同梱 `references/` と本 Skill の
   記述を代替正本として扱い、推測で内容を補わない

**plugin root 直下に `docs/` を探しに行かないこと**: plugin が配布するのは
`agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として
認識せず、plugin root 配下に相当する配布物が存在しないため必ず空振りする。

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md`（下記 3〜5） | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 4 へ）** |
| 契約 doc（c3-prime 契約・settings wiring 契約 等） | **`<skill_dir>/references/` に同梱（解決可）** | **`<skill_dir>/references/` に同梱（解決可）** | **`<skill_dir>/references/` に同梱（解決可）** |
| `bin/**`（CLI） | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` | コピー対象外（解決不可） | `<plugin_root>/scripts/` は存在するが `install-plangate-skills.sh` のみ（`ai-dev-workflow` / `codex-guarded.sh` 等は解決不可） | 未配置（解決不可） |

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

`docs/working/TASK-XXXX/*`（下記 6〜7）は**配布物ではなく導入先で作成する作業成果物**なので、
導入先リポジトリ内でそのまま解決する（存在しなければ plan フェーズが未完了）。

### 同梱リファレンス（`<skill_dir>/references/`）

| ファイル | 役割 |
|---------|------|
| `references/c3-prime-contract.md` | `approval_kind: "c3-prime"` の受理契約（§2〜§5）の正本 |
| `references/settings-wiring-contract.md` | settings wiring 契約（必要 hook の定義・Codex CLI parity） |
| `references/core-contract.md` | 実行契約（Iron Law / Stop rules / Output discipline）の正本 |
| `references/plangate.md` | PlanGate 概要ガイド |

### 読む順序

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`（exec phase の出力規約）
4. `.claude/rules/hybrid-architecture.md` → fallback `<plugin_root>/rules/hybrid-architecture.md`（Rule 1〜5）
5. `.claude/rules/responsibility-classes.md` → fallback `<plugin_root>/rules/responsibility-classes.md`（AI-owned / Human-owned 境界）
6. `docs/working/TASK-XXXX/plan.md` / `todo.md` / `test-cases.md`
7. `docs/working/TASK-XXXX/current-state.md`

## Rules

- **TDD 厳守**: Red → Green → Refactor。test-cases.md の各 AC に対応するテストを先に書く。
- **todo.md 順守**: depends_on を尊重し、🚩 checkpoint ごとに current-state.md 更新。
- **計画逸脱の即時記録**: 計画外のリネーム / 削除 / 設計変更は status.md「計画からの変更点」に記録。
- **scope 越境禁止**: plan.md「Files / Components to Touch」外の変更は禁止。必要時は plan 再生成 + C-3 再承認。
- **L-0〜V-4 は workflow-conductor が自動制御**: 本 skill 範囲外。
- **AI 自己改変ガード尊重**: `.claude/settings*.json` / Hardening Override 対象は触らない（Human-owned）。
- **decision-log.jsonl 追記**: 主要判断は append-only で記録。

## Output

- 実装コード（plan.md「Files / Components to Touch」内）
- テストコード（test-cases.md と 1:1 対応）
- `docs/working/TASK-XXXX/current-state.md` 更新
- `docs/working/TASK-XXXX/status.md` 追記
- `docs/working/TASK-XXXX/decision-log.jsonl` 追記

## CLI 呼び出し

> **配布と対象 project root は別の問題（#962 / #1144）**: plugin / `install.sh --claude` / Codex は
> `bin/plangate` と enforcement scripts を導入先へ配布しない。そのため CLI を使うには
> PlanGate の clone と、その `bin/plangate` への PATH または絶対パスが必要。
> ただし #1497 以降、CLI が利用できる場合の対象 project root は全コマンド共通で
> **`--project-root` → `PLANGATE_PROJECT_ROOT` → cwd の git root → CLI root fallback**
> の順に解決される。導入先の git repo で PATH 上の `plangate` を実行すれば、その導入先が
> 既定の対象になる。CLI が無いことを理由にゲートや検証を黙って省略してはならない。
>
> #1497 で downstream 契約を明示検証したのは `status` / `validate` / `approve` /
> read-only `doctor`（および work-dir を明示する `render`）。`doctor --fix` は #1144 の
> enforcement 配布が解決するまで downstream では **rc=2 / no-write** で fail-closed。
> script-relative helper に委譲するコマンドは、root resolver が存在しても自動的に
> downstream 対応になるとは扱わず、下表・フォールバックの個別契約に従う。

**呼び出し表記**: 上流 clone の cwd では `bin/plangate`、導入先で PATH を通している場合は
`plangate`。別対象を明示する場合は `--project-root <dir>` を使う。

| 用途 | 上流リポジトリの cwd | 導入先 + PATH に `plangate` あり | 導入先 + PATH に無い（**既定**） |
|------|---------------------|----------------------------------|--------------------------------|
| exec dispatch | `bin/plangate exec TASK-XXXX [--mode <mode>]` | `plangate exec TASK-XXXX`（selected project root の C-3 / plan / HEAD を検査。agent 固有実行は各 runner 契約に従う） | 手動で TDD 実行 |
| plan_hash / artifact 機械検証 | `bin/plangate validate TASK-XXXX` | `plangate validate TASK-XXXX` | 次節のフォールバック（sha256 突合） |

> **project root 契約**: 位置引数は CLI 本体位置ではなく、共通 resolver が選んだ project root の
> `docs/working/TASK-XXXX` を基準に解決する。明示的に別repoを操作する場合は
> `--project-root <dir>` を使う。agent runner 自身が相対パスを使う場合は target repo の cwd から
> 実行すること。

- 並行で `./scripts/ai-dev-workflow- 並行で `./scripts/ai-dev-workflow TASK-XXXX exec` も利用可（**上流リポジトリの cwd のみ**。`scripts/ai-dev-workflow` は配布対象外）
- **Codex CLI 経由の場合は `scripts/codex-guarded.sh --task TASK-XXXX exec --full-auto` を推奨**（**上流リポジトリの cwd のみ**。pre-flight で validate + doctor --check-settings 実行、post-flight で plan.md drift 検知）

> ❌ ~~**Codex CLI 物理 hook 等価達成 (PR #347)**~~ **未達成（2026-08-13 実測）**: `.codex/hooks.json` は設定ファイル全体が parse 拒否されており、**hook は 1 件も登録されていない**。**EH-1/2/3/6/9 は Codex session で一度も発火していない**。`scripts/codex-guarded.sh` の session 前後検知は正規入口を経由した場合のみ機能する（入口を強制する機械ゲートは無い）。**Codex session 中の write は物理 block されないものとして扱い、ゲートは人手で維持すること。** 詳細は同梱 `references/settings-wiring-contract.md` §Codex CLI parity を参照。**これらは配布対象外**でもあるため、導入先では下記フォールバックでゲートを人手維持する。

### CLI 不在時のフォールバック（導入先では既定）

上表の「導入先 + PATH に無い（既定）」に該当する場合は次に従う:

1. **exec 本体は手動で TDD 実行する** — Red → Green → Refactor の順序と「Output」の出力契約は
   **CLI の有無に関わらず不変**
2. **exec 入口ゲート（前提条件）は自分で確認する** — まず `approvals/c3.json` に
   `approval_kind` キーがあるかを strict JSON で読んで**経路を分ける**
   （`python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print("approval_kind" in d)' <path>`）。

   **(a) legacy c3.json（`approval_kind` キー無し）の場合** — `c3_status` が
   `APPROVED` であることを読んで確認し、続けて plan_hash を突合する。`plangate validate` の
   plan_hash 検査は **`plan.md` の素の sha256**（正規化・前処理なし）と `c3.json` の `plan_hash`
   から `sha256:` prefix を除いた値の単純比較なので、CLI 無しで再現できる:

   ```sh
   # 算出（sha256sum → shasum -a 256 → openssl → python3 の順に、あるものを使う）
   sha256sum docs/working/TASK-XXXX/plan.md | awk '{print $1}'
   shasum -a 256 docs/working/TASK-XXXX/plan.md | awk '{print $1}'
   openssl dgst -sha256 docs/working/TASK-XXXX/plan.md | awk '{print $NF}'
   python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' docs/working/TASK-XXXX/plan.md
   # 突合先: docs/working/TASK-XXXX/approvals/c3.json の "plan_hash": "sha256:<この値>"
   ```

   **不一致なら C-3 承認後に plan が改変されている** → exec に進まず、再承認（`c3.json` の
   `plan_hash` 更新）または plan の revert を行う。上記 **4 手段がすべて無い場合に限り**
   スキップし、その事実を `decision-log.jsonl` に記録して **「機械検証済み」と書かない**
   （python3 は PlanGate ツールチェーンの事実上の必須依存なので、実際にはほぼ到達しない）

   **(b) `approval_kind: "c3-prime"` の record の場合** — 上記 (a) の手順は**使えない**。
   c3-prime は `c3_status` を持たず（契約 §5 で明示禁止）、`plan_hash` は legacy と同じ
   `sha256:<64hex>` 形式だが top-level と reviewer snapshot に**複数回出現**するため、
   非アンカーな `grep`/`sed` 抽出は多行マッチして誤動作する（契約 §5。読むなら python3 の
   strict JSON のみ）。さらに受理には **Plan Package 6 要素（`pbi-input.md` / `plan.md` /
   `todo.md` / `test-cases.md` / `review-self.md` / `review-external.md`）の `artifact_hashes`
   全数照合 + `plan_package_hash` + `source_sha`（検証時点の対象 SHA と一致）+ reviewer
   snapshot の三つ組一致 + `decision=AUTO_APPROVED`** までの束縛検証が必要
   （正本: 同梱 `references/c3-prime-contract.md` §3〜§5）。
   **c3-prime を手動 sha256 のみで代替してはならない** — `plan.md` 単体の hash 一致だけで
   入口ゲート確認済みとして exec に進むと、残り 5 artifact と `source_sha` の stale を見逃す。
   この場合は item 4 の上流 clone 経由 `plangate validate --dir` で機械検証するか、
   機械検証できない旨を `decision-log.jsonl` に記録して **exec を保留する**
3. **hook も配布されない前提で運用する** — plan_hash を照合する hook（EH-3）は導入先には配線され
   ないため、item 2 の突合は **exec 開始前に自分で実行する**。CLI が無いことを理由に C-3 を省略しない
4. CLI による機械検証が必要なら PlanGate の clone を用意し、導入先 repo の cwd から
   `plangate validate TASK-XXXX`、または任意の cwd から
   `plangate --project-root <導入先repo> validate TASK-XXXX` を実行する

## 次フェーズへ

exec 完了後は `ai-dev-verify` skill で V-1〜V-4 + handoff.md 発行。L-0〜V-4 は workflow-conductor が自動進行。
