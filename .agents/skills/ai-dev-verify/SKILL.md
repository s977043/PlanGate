---
name: ai-dev-verify
description: "PlanGate の V-1〜V-4 受け入れ検査と handoff.md 発行を行う。Use when: exec 完了後に受け入れ検査を実行し PR 準備したい時。"
---

# AI-Driven Verify (PlanGate / Codex 共用)

PlanGate ワークフローの **verify & handoff フェーズ（WF-05）** を Codex / Claude Code 両方で実行する skill。Rule 5（最終成果物は毎回 handoff に集約）を担保する。

> 本スキルは **bundled resources**（`references/`）で自己完結する。
>
> **パス表記の規約（重要）**: 本 SKILL.md 中の `references/…` は、すべて **本スキル
> ディレクトリからの相対パス**（= `<skill_dir>/…`）であって、導入先リポジトリのルートからの
> 相対パスではない。実行時はまず `<skill_dir>`（このファイルが置かれているディレクトリ）を
> 解決してから使う:
>
> | 環境 | `<skill_dir>` |
> | --- | --- |
> | plugin 導入先（Claude marketplace） | `<plugin_root>/skills/ai-dev-verify/` |
> | `install.sh --claude` 導入先 | `.claude/skills/ai-dev-verify/` |
> | Codex 導入先 | `.codex/skills/ai-dev-verify/` |
> | 上流リポジトリ（正本側） | `.agents/skills/ai-dev-verify/` |
>
> 導入先が独自の正本（上流リポジトリの `docs/` 配下に相当するもの）を別途保持している
> 場合は、そちらを優先すること。

## Read First

### 参照解決順（導入先で必ずこの順に探す）

本 Skill は **上流リポジトリ基準の `docs/**` パスを直接参照しない**（#1232）。`docs/**` は
`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**であり、
書いた時点で導入先では必ず空振りするためである。参照の解決は次の順で行う:

1. **`<skill_dir>` 配下の同梱物（`references/`）を第一に読む** — 契約 doc と handoff
   テンプレートは本スキルに同梱されている（「同梱リファレンス」節の一覧）
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
| `rules/*.md`（下記 3〜6） | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 4 へ）** |
| 契約 doc・handoff テンプレート | **`<skill_dir>/references/` に同梱（解決可）** | **`<skill_dir>/references/` に同梱（解決可）** | **`<skill_dir>/references/` に同梱（解決可）** |
| `bin/**`（CLI） | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` | コピー対象外（解決不可） | `<plugin_root>/scripts/` は存在するが `install-plangate-skills.sh` のみ（`apply-claude-settings.sh` / `check-settings-wiring.sh` 等は解決不可） | 未配置（解決不可） |

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

`docs/working/TASK-XXXX/*`（下記 7）は**配布物ではなく導入先で作成する作業成果物**なので、
導入先リポジトリ内でそのまま解決する。

### 同梱リファレンス（`<skill_dir>/references/`）

| ファイル | 役割 |
|---------|------|
| `references/handoff.md` | handoff.md 6 要素の正本テンプレート |
| `references/c3-prime-contract.md` | `approval_kind: "c3-prime"` の受理契約（§3〜§5）の正本 |
| `references/settings-wiring-contract.md` | settings wiring 契約（必要 hook の定義） |
| `references/core-contract.md` | 実行契約（Iron Law / Stop rules / Output discipline）の正本 |
| `references/plangate.md` | PlanGate 概要ガイド |

### 読む順序

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`（handoff 必須化・6 要素・settings タスクロックの正本）
4. `.claude/rules/hybrid-architecture.md` → fallback `<plugin_root>/rules/hybrid-architecture.md`（Rule 5）
5. `.claude/rules/review-principles.md` → fallback `<plugin_root>/rules/review-principles.md`（V-3 外部レビュー観点）
6. `.claude/rules/mode-classification.md` → fallback `<plugin_root>/rules/mode-classification.md`（V-2/V-3/V-4 の mode 別適用）
7. `docs/working/TASK-XXXX/plan.md` / `test-cases.md` / `status.md`
8. `references/handoff.md`（**同梱**。handoff.md 6 要素の正本テンプレート。導入先が独自テンプレートを持つ場合はそちらを優先）

## V-1〜V-4 の概要

mode 別の適用範囲は `.claude/rules/mode-classification.md`（fallback `<plugin_root>/rules/mode-classification.md`）のフェーズ適用マトリクスを正本とする。各フェーズの趣旨:

- **V-1 受け入れ検査**: test-cases.md の各 AC を機械的に PASS/FAIL 突合（推測ではなく実行結果のみ）。FAIL は exec へ差し戻し。evidence: `evidence/test-runs/`, `evidence/verification/`。
- **V-2 コード最適化** (high-risk / critical): 動作不変で可読性・効率性改善。テスト再実行で回帰なしを保証。
- **V-3 外部モデルレビュー** (standard 以上): 5 観点 + Severity 判定。R-NNN 採番で `review-external.md` 追記専用。
- **V-4 リリース前チェック** (critical): ドキュメント整合 / マイグレーション / ロールバック / セキュリティ。

## settings タスクロック（V-1 / handoff 完了の前提条件）

`plangate doctor --check-settings` PASS を **V-1 / handoff 完了の前提**として要求（`.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md` が正本）。未配線時は **Shadow Configuration 防止**のため handoff を完了扱いにできない。settings 適用は Human-owned（`sh scripts/apply-claude-settings.sh` を Human が実行。**`scripts/apply-claude-settings.sh` は配布対象外**なので、導入先には存在しない）。

> **導入先でも CLI が利用できれば `doctor --check-settings` で対象 settings を検査できる**。
> project root は `--project-root` → `PLANGATE_PROJECT_ROOT` → cwd git root → CLI root fallback
> の順で解決される。ただし #1144 により enforcement scripts 自体はまだ導入先へ配布されないため、
> wiring の存在確認と enforcement の実在・発火を混同しない。downstream `doctor --fix` は
> rc=2 / no-write で拒否される。CLI が無い場合は導入先の `.claude/settings.json` を直接確認し、
> 未検証を「PASS」と書かない。
>
> **必要 hook の実体と、導入先での判定の落とし所**: 「必要な hook」の定義の正本は
> `scripts/check-settings-wiring.sh`（**配布対象外**）と同梱 `references/settings-wiring-contract.md`
> で、`Edit|Write` matcher に EH-1 `check-plan-exists.sh` / EH-2
> `check-c3-approval.sh` / EH-3 `check-plan-hash.sh`（+ 引数 `${PLANGATE_HOOK_FILE:-}`） /
> EH-6 `check-forbidden-files.sh`、`Bash` matcher に EH-9
> `check-delegation-commit-boundary.sh` が配線されていることを要求する。ただし
> **hook 本体（`scripts/hooks/*.sh`）も plugin に含まれない**（`plugin/plangate/hooks/` は
> `.gitkeep` のみ）ため、導入先の `hooks.PreToolUse` がこれらを指すことは構造上ありえず、
> 是正手段の `scripts/apply-claude-settings.sh` も配布されない。したがって導入先では
> settings タスクロックを **`N/A（hook 非配布）`** と handoff.md に明記し、その代替として
> **「CLI 不在時のフォールバック」の plan_hash 突合を必須**とする（実施結果を handoff.md に
> 記載）。**`N/A` を「PASS」と書き換えてはならない**。上流リポジトリで作業している場合は
> 従来どおり `doctor --check-settings` PASS が前提条件として生きる（`N/A` に落とせない）。

## handoff.md 発行（必須・Rule 5）

同梱 `references/handoff.md` を雛形に発行する（導入先が独自テンプレートを持つ場合はそちらを優先）。**6 要素の正本**は `.claude/rules/working-context.md`（fallback `<plugin_root>/rules/working-context.md`）の「handoff（WF-05 完了資産 / Rule 5）」節および同梱 `references/handoff.md` を参照。light モード以下で簡易版を採用する場合も本テンプレートを踏襲（該当なしは「該当なし」明記）。PR マージ後も削除しない（完了資産）。

## Output

- `docs/working/TASK-XXXX/handoff.md`（6 要素必須）
- `docs/working/TASK-XXXX/evidence/` 追記
- `docs/working/TASK-XXXX/status.md` 追記（V-1〜V-4 結果サマリ）

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

**呼び出し表記**: 上流 clone の cwd では `bin/plangate`、導入先で PATH を通した場合は
`plangate`。明示対象は `--project-root <dir>`。

| 用途 | 上流リポジトリの cwd | 導入先 + PATH に `plangate` あり | 導入先 + PATH に無い（**既定**） |
|------|---------------------|----------------------------------|--------------------------------|
| V-1 機械検証 | `bin/plangate validate TASK-XXXX` | `plangate validate TASK-XXXX` | 次節のフォールバック（sha256 突合） |
| V-3 外部 AI レビュー | `bin/plangate review TASK-XXXX --phase v3` | selected project root を使うが外部送信を伴うため、通常どおり機密・reviewer設定を確認して実行 | 手動レビュー |
| settings 検証 | `bin/plangate doctor --check-settings` | `plangate doctor --check-settings`（read-only） | `.claude/settings.json` を直接確認 |
| 8 観点 eval | `bin/plangate eval TASK-XXXX` | script-relative runner のため **#1497 downstream 保証外** | 利用不可 / 手動評価 |
| metrics 収集 | `bin/plangate metrics TASK-XXXX --collect\|--report` | collector/reporter は script-relative root を持つため **#1497 downstream 保証外** | 利用不可 |

> **project root 契約**: `validate` / `review` / read-only `doctor` は共通 resolver で選択した
> project root を対象にする。script-relative Python runner へ委譲するコマンドは個別に対応確認する。

**handoff.md 発行コマンドは未実装****handoff.md 発行コマンドは未実装**（環境を問わず手動）。skill 利用者が同梱 `references/handoff.md` をコピーし手動で 6 要素を記載する。

### CLI 不在時のフォールバック（導入先では既定）

1. **V-1 の plan_hash 突合を標準コマンドで代替する（スキップしない）** — まず
   `approvals/c3.json` に `approval_kind` キーがあるかを strict JSON で読んで**経路を分ける**。

   **(a) legacy c3.json（`approval_kind` キー無し）の場合** — `plangate validate` の
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

   上記 **4 手段がすべて無い場合に限り**スキップし、その事実を handoff.md と
   `decision-log.jsonl` に記録して **「機械検証済み」と書かない**
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
   検証済みと扱うと、残り 5 artifact と `source_sha` の stale を見逃す。この場合は item 3 の
   上流 clone 経由 `plangate validate --dir` で機械検証するか、機械検証できない旨を
   handoff.md と `decision-log.jsonl` に記録し **V-1 を PASS と書かない**
2. **AC 突合そのものは手動で行う** — test-cases.md の各 AC を実行結果と 1 件ずつ突合する。
   推測ではなく実行結果のみで PASS/FAIL を付ける原則は CLI の有無に関わらず不変
3. CLI による機械検証が必要なら PlanGate の clone を用意し、導入先 repo の cwd から
   `plangate validate TASK-XXXX`、または `plangate --project-root <導入先repo> validate TASK-XXXX`
   を実行する。既存の `validate --dir <TASKディレクトリ>` も利用できる

## 次フェーズへ

handoff 完了後は PR 作成 → C-4 ゲート（GitHub 上の人間レビュー）→ マージ。
