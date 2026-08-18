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

## CLI 呼び出し

**呼び出し表記は実行環境で変わる**。相対パス形式（`bin/plangate`）が成立するのは
**上流リポジトリ（`s977043/plangate`）を clone した cwd に居るときだけ**で、導入先には `bin/` が
配置されない。導入先で PATH を通した場合のコマンド名は **`plangate`**（`bin/plangate` ではない）。
いずれも**補助**であり、本 skill の読み書きはファイルを直接扱えば CLI 無しで完結する。

下表の 2 列目は「導入先 + PATH に `plangate` あり」「導入先 + PATH に無い」で結論が同じ
（`resume` / `context` / `status` はいずれも `--dir` 相当を持たず導入先の TASK を対象にできない）
ため、**PATH 有無で差がないので 2 列に統合している**。

| 用途 | 上流リポジトリの cwd | 導入先（PATH の有無を問わず） |
|------|---------------------|------------------------------|
| current-state 表示 | `bin/plangate resume TASK-XXXX` | **導入先の TASK には使えない**（下記注意）→ `current-state.md` を直接読む |
| 動的 context 取得（opt-in / Issue #199） | `bin/plangate context TASK-XXXX --phase <classify\|plan\|approve-wait\|execute\|review\|verify\|handoff>`（**`--phase` 必須**） | 同上 → L0〜L3 プロトコルに従って手動で読む |
| 状態確認 | `bin/plangate status TASK-XXXX` | 同上 → `INDEX.md` / `status.md` を直接読む |

> **注意: `TASK-XXXX` 位置引数は cwd ではなく CLI 本体の位置を基準に解決される。**
> `bin/plangate` は自身のパスから `plangate_root`（= `bin/` の親）を求め、
> `<CLI の repo root>/docs/working/TASK-XXXX` を読み書きする。`bin/` は導入先に配置されない
> ため、PATH 上の `plangate` は必ず**別の場所にある上流 clone** の実体を指す。cwd 非依存で
> パスを明示できる `--dir` を持つのは `validate` / `validate-schemas` **だけ**で、
> `resume` / `context` / `status` に相当オプションは無い（＝導入先の TASK は対象にできない）。

## 次フェーズへ

セッション再開後は現フェーズに応じて `ai-dev-plan` / `plan-review-gate` / `ai-dev-exec` / `ai-dev-verify` を呼ぶ。
