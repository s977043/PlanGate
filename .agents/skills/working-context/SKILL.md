---
name: working-context
description: "PlanGate の TASK-XXXX 作業コンテキストを Progressive Disclosure で読込・更新する。Use when: セッション再開時、フェーズ遷移時、status.md/current-state.md/handoff.md を更新したい時。"
---

# Working Context (PlanGate / Codex 共用)

PlanGate の `docs/working/TASK-XXXX/` 配下を **L0〜L3 の Progressive Disclosure プロトコル** で読み込み、更新する skill。プロトコル詳細は `.claude/rules/working-context.md` を正本とする（**導入先での解決手順は下記「参照解決順」**）。

## Read First (L0 / 常に読む)

### 参照解決順（導入先で必ずこの順に探す）

本 skill の参照は上流リポジトリ（`s977043/plangate`）基準の相対パスで書かれている。
本 skill は正本を再掲せず参照するため、**正本が引けないと「正本に基づく運用」はできない**
（その場合は手順 3 の代替プロトコルに落とし、正本未参照であることを明示する）。次の順で探索する:

1. 導入先リポジトリの相対パス（`.claude/rules/working-context.md`）
2. 無ければ plugin root 配下（`<plugin_root>/rules/working-context.md`）
   - **`<plugin_root>` は Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して得た絶対パス**。
     Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
     という文字列をそのまま Read しても必ず失敗する
   - **変数が空・未設定なら glob（`~/.claude/plugins/cache/**` 等）で推測せず 3 へ進む**
3. どちらにも無い場合は **「解決できなかった」と明示**し、推測で内容を補わない。
   L0〜L3 の段取り・出力先は本 skill 本文で代替し、正本未参照である旨を `status.md` に記録する

**plugin root 配下の探索は `docs/**` には適用しない**（手順 2 は `rules/*.md` 等の
配布対象にのみ適用する）: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の
定義ディレクトリのみで `docs/`（本 skill が参照する `docs/working/templates/*.md` を含む）を
配布対象として認識せず、plugin root 配下に相当する配布物が存在しないため必ず空振りする。
`docs/**` は手順 1 で解決できなければ手順 2 を飛ばして手順 3 へ進む。

> **手順 3 に落ちても判定基準は緩めない**: 正本が引けない場合の代替は「L0=`INDEX.md` →
> `current-state.md`、L1=フェーズ該当ファイル、L2=`evidence/` / `decision-log.jsonl`、
> L3=`status.md` 全体」の段取りと本 skill「Rules」節（`YYYY-MM-DD HH:mm` 必須・handoff 6 要素
> 必須・逸脱記録）であって、**省略ではない**。正本を参照できないことを理由に判定基準・
> ゲートを緩めてはならない。

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md`（下記 3） | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `docs/working/templates/*.md` | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `bin/**`（CLI） | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` | コピー対象外（解決不可） | `<plugin_root>/scripts/` は存在するが `install-plangate-skills.sh` のみ（`context-engine.py` 等は解決不可） | 未配置（解決不可） |

`docs/working/TASK-XXXX/*`（下記 4〜5 / Output）は**配布物ではなく導入先で作成する作業成果物**
なので、導入先リポジトリ内でそのまま解決する。

### 読む順序

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`（ディレクトリ構造・段階別出力・handoff 必須化・L0〜L3 プロトコルの正本）
4. `docs/working/TASK-XXXX/INDEX.md`
5. `docs/working/TASK-XXXX/current-state.md`

## L1 / L2 / L3 の読み込み対象

`.claude/rules/working-context.md`（fallback `<plugin_root>/rules/working-context.md`）の「コンテキスト読み込みプロトコル（Progressive Disclosure）」表を参照（重複を避けるため本 skill では再掲しない）。**どちらでも解決できない場合**は、L0=`INDEX.md` → `current-state.md`、L1=フェーズ該当ファイル、L2=`evidence/` / `decision-log.jsonl`、L3=`status.md` 全体、の段取りで進め、正本未参照である旨を `status.md` に記録する。

## Output

- `docs/working/TASK-XXXX/status.md`（フェーズ履歴・追記）
- `docs/working/TASK-XXXX/current-state.md`（今の状態スナップショット・上書き）
- `docs/working/TASK-XXXX/handoff.md`（WF-05 完了時のみ、Rule 5 / 6 要素は正本参照）

## Rules

- INDEX.md が無ければフォールバックで status.md を直接読む（旧形式互換）
- セッション開始は L0 → L1 の順で必要分だけ読む（不要 read を抑制）
- 計画からの逸脱は status.md「計画からの変更点」セクションに記録
- **status.md のフェーズ履歴は `YYYY-MM-DD HH:mm`（分まで）を必須**とする（#463）。日付のみ・時刻欠落は不可。セッション跨ぎ・同日複数フェーズ遷移の順序を一意に追跡するため。テンプレート: `docs/working/templates/status.md`（**配布対象外**。解決できない環境では本ルールの書式要求のみを満たす）
- handoff.md は WF-05 完了時に 1 回発行（6 要素は `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md` および `docs/working/templates/handoff.md` を正本とする。**テンプレートは配布対象外**なので、解決できない環境では rules 側の「handoff（WF-05 完了資産 / Rule 5）」節を唯一の正本とする）

## Context Lifecycle / fresh-context transition (#1410)

会話履歴を次セッションへ持ち越すのではなく、**現在の canonical state を checkpoint して
fresh context から再開する**。fresh context は workflow reset ではなく、C-3/C-4・plan
binding・evidence・Human-owned authority はそのまま維持する。

### checkpoint → fresh context の trigger

以下は checkpoint 後に fresh context へ切り替える:

- **必須（standard 以上）**: worker / agent / model / runtime の変更、独立 reviewer の開始、worker 間 handoff、
  外部待ち・使用量上限による意図的中断
- **推奨**: compaction / context pressure が近い、phase 遷移で必要 working set が変わる、
  repair/review loop で superseded な議論が蓄積した

ultra-light / light では上記の「必須」も任意とする。`docs/ai/context-lifecycle.md` §8
（simple tasks do not gain mandatory ceremony）を満たすため、既存の working-context
ファイル以上の checkpoint を簡易タスクへ課さない。

provider 非依存の token 閾値は推測で作らない。usage が信頼できる形で取得できる場合のみ
補助情報として使う。

### checkpoint 手順

1. material な最終判断を canonical `plan.md` / `decision-log.jsonl` / ADR へ反映する。
2. `INDEX.md` と `current-state.md` を実態に合わせて更新する。
3. test/review の結果は既存 evidence/report/Review Artifact に保存し、L0 には参照と要約だけを残す。
4. ownership が変わる場合は `local-exec-handoff` または
   `context-packager` + `dispatch/*` を使う。
5. 次 context は会話 transcript を渡さず **L0 → phase-required L1 → L2/L3 on demand** で再開する。

必須 state が missing / stale と分かっている場合、それを resumable checkpoint として扱わない。
degrade を記録して canonical state を修復してから引き継ぐ。

**保存禁止**: hidden chain-of-thought、raw chat transcript、既存 evidence で代替できる raw tool
stream、secret / credential / personal data。独立 reviewer は implementer の会話 reasoning を
引き継がず review package + diff + evidence から開始する。

上流 integration map: `docs/ai/context-lifecycle.md`（導入先では docs が配布されないため、
解決できなくても本節の運用契約は維持する）。

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

本 skill 自体はファイルを直接扱えば CLI 無しで完結する。

| 用途 | 上流リポジトリの cwd | 導入先 + PATH に `plangate` あり | 導入先 + PATH に無い（**既定**） |
|------|---------------------|----------------------------------|--------------------------------|
| current-state 表示 | `bin/plangate resume TASK-XXXX` | `plangate resume TASK-XXXX` | `current-state.md` を直接読む |
| 動的 context 取得（opt-in / Issue #199） | `bin/plangate context TASK-XXXX --phase <...>` | context-engine は script-relative root のため **#1497 downstream 保証外** → L0〜L3を手動で読む | L0〜L3を手動で読む |
| 状態確認 | `bin/plangate status TASK-XXXX` | `plangate status TASK-XXXX` | `INDEX.md` / `status.md` を直接読む |

> **project root 契約**: `resume` / `status` は選択済み project root の
> `docs/working/TASK-XXXX` を参照する。明示対象は `--project-root <dir>`。
> `context` は Python helper 側の root 契約が別なので、#1497 の保証対象として扱わない。

## 次フェーズへ

セッション再開後は現フェーズに応じて `ai-dev-plan` / `plan-review-gate` / `ai-dev-exec` / `ai-dev-verify` を呼ぶ。
