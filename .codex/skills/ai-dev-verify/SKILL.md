---
name: ai-dev-verify
description: "PlanGate の V-1〜V-4 受け入れ検査と handoff.md 発行を行う。Use when: exec 完了後に受け入れ検査を実行し PR 準備したい時。"
---

# AI-Driven Verify (PlanGate / Codex 共用)

PlanGate ワークフローの **verify & handoff フェーズ（WF-05）** を Codex / Claude Code 両方で実行する skill。Rule 5（最終成果物は毎回 handoff に集約）を担保する。

## Read First

### 参照解決順（導入先で必ずこの順に探す）

本 skill の参照は上流リポジトリ（`s977043/plangate`）基準の相対パスで書かれている。
導入先ではそのままでは解決できないものがあるため、**次の順で探索する**:

1. 導入先リポジトリの相対パス（例: `.claude/rules/working-context.md`）
2. 無ければ plugin root 配下（例: `<plugin_root>/rules/working-context.md`）
   - **`<plugin_root>` は Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して得た絶対パス**。
     Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
     という文字列をそのまま Read しても必ず失敗する
   - **変数が空・未設定なら glob（`~/.claude/plugins/cache/**` 等）で推測せず 3 へ進む**
3. どちらにも無い場合は **「解決できなかった」と明示**し、推測で内容を補わない

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md`（下記 3〜6） | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `docs/working/templates/*.md`（下記 8） | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `bin/**`（CLI） | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` | コピー対象外（解決不可） | `<plugin_root>/scripts/` は存在するが `install-plangate-skills.sh` のみ（`apply-claude-settings.sh` / `check-settings-wiring.sh` 等は解決不可） | 未配置（解決不可） |

`docs/working/TASK-XXXX/*`（下記 7）は**配布物ではなく導入先で作成する作業成果物**なので、
導入先リポジトリ内でそのまま解決する。

**テンプレート（下記 8）が解決できない環境では、handoff の 6 要素は
`.claude/rules/working-context.md`（fallback `<plugin_root>/rules/working-context.md`）の
「handoff（WF-05 完了資産 / Rule 5）」節を唯一の正本として使い**、テンプレート未参照である旨を
handoff.md に記録する（推測でテンプレート構成を捏造しない）。

### 読む順序

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`（handoff 必須化・6 要素・settings タスクロックの正本）
4. `.claude/rules/hybrid-architecture.md` → fallback `<plugin_root>/rules/hybrid-architecture.md`（Rule 5）
5. `.claude/rules/review-principles.md` → fallback `<plugin_root>/rules/review-principles.md`（V-3 外部レビュー観点）
6. `.claude/rules/mode-classification.md` → fallback `<plugin_root>/rules/mode-classification.md`（V-2/V-3/V-4 の mode 別適用）
7. `docs/working/TASK-XXXX/plan.md` / `test-cases.md` / `status.md`
8. `docs/working/templates/handoff.md`（handoff.md 6 要素の正本テンプレート。**配布対象外**。上流リポジトリで作業する場合のみ解決する）

## V-1〜V-4 の概要

mode 別の適用範囲は `.claude/rules/mode-classification.md`（fallback `<plugin_root>/rules/mode-classification.md`）のフェーズ適用マトリクスを正本とする。各フェーズの趣旨:

- **V-1 受け入れ検査**: test-cases.md の各 AC を機械的に PASS/FAIL 突合（推測ではなく実行結果のみ）。FAIL は exec へ差し戻し。evidence: `evidence/test-runs/`, `evidence/verification/`。
- **V-2 コード最適化** (high-risk / critical): 動作不変で可読性・効率性改善。テスト再実行で回帰なしを保証。
- **V-3 外部モデルレビュー** (standard 以上): 5 観点 + Severity 判定。R-NNN 採番で `review-external.md` 追記専用。
- **V-4 リリース前チェック** (critical): ドキュメント整合 / マイグレーション / ロールバック / セキュリティ。

## settings タスクロック（V-1 / handoff 完了の前提条件）

`plangate doctor --check-settings` PASS を **V-1 / handoff 完了の前提**として要求（`.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md` が正本）。未配線時は **Shadow Configuration 防止**のため handoff を完了扱いにできない。settings 適用は Human-owned（`sh scripts/apply-claude-settings.sh` を Human が実行。**`scripts/apply-claude-settings.sh` は配布対象外**なので、導入先には存在しない）。

> **導入先では `doctor --check-settings` で検証できない**。`doctor` 系は cwd ではなく
> **CLI 本体の位置**を基準に `<CLI の repo root>/.claude/settings.json` を検査するため、
> 上流 clone から実行しても対象は clone 側の settings であって導入先ではない
> （`--dir` 相当のオプションも無い）。導入先では **導入先自身の `.claude/settings.json` の
> `hooks.PreToolUse` を直接読んで**必要な hook が配線されているかを確認し、その確認方法と結果を
> handoff.md に明記する（**未検証を「PASS」と書かない**）。
>
> **必要 hook の実体と、導入先での判定の落とし所**: 「必要な hook」の定義の正本は
> `scripts/check-settings-wiring.sh` と `docs/ai/settings-wiring-contract.md`（**どちらも
> 配布対象外**）で、`Edit|Write` matcher に EH-1 `check-plan-exists.sh` / EH-2
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

`docs/working/templates/handoff.md` を雛形に発行（**配布対象外**。解決できない環境は「参照解決順」の注記に従う）。**6 要素の正本**は `.claude/rules/working-context.md`（fallback `<plugin_root>/rules/working-context.md`）の「handoff（WF-05 完了資産 / Rule 5）」節および `docs/working/templates/handoff.md` を参照。light モード以下で簡易版を採用する場合も本テンプレートを踏襲（該当なしは「該当なし」明記）。PR マージ後も削除しない（完了資産）。

## Output

- `docs/working/TASK-XXXX/handoff.md`（6 要素必須）
- `docs/working/TASK-XXXX/evidence/` 追記
- `docs/working/TASK-XXXX/status.md` 追記（V-1〜V-4 結果サマリ）

## CLI 呼び出し

**呼び出し表記は実行環境で変わる**。相対パス形式（`bin/plangate`）が成立するのは
**上流リポジトリ（`s977043/plangate`）を clone した cwd に居るときだけ**で、導入先には `bin/` が
配置されない。導入先で PATH を通した場合のコマンド名は **`plangate`**（`bin/plangate` ではない）。

| 用途 | 上流リポジトリの cwd | 導入先 + PATH に `plangate` あり | 導入先 + PATH に無い（**既定**） |
|------|---------------------|----------------------------------|--------------------------------|
| V-1 機械検証 | `bin/plangate validate TASK-XXXX` | `plangate validate --dir docs/working/TASK-XXXX` | 次節のフォールバック（sha256 突合） |
| V-3 外部 AI レビュー | `bin/plangate review TASK-XXXX --phase v3` | **導入先の TASK には使えない**（`--dir` 相当なし）→ 手動レビュー | 手動レビュー |
| settings 検証 | `bin/plangate doctor --check-settings` | **導入先は検査できない**（上記「settings タスクロック」の注記）→ `.claude/settings.json` を直接確認 | `.claude/settings.json` を直接確認 |
| 8 観点 eval | `bin/plangate eval TASK-XXXX` | **導入先の TASK には使えない**（`--dir` 相当なし） | 利用不可 |
| metrics 収集 | `bin/plangate metrics TASK-XXXX --collect\|--report` | **導入先の TASK には使えない**（`--dir` 相当なし） | 利用不可 |

> **注意: `TASK-XXXX` 位置引数は cwd ではなく CLI 本体の位置を基準に解決される。**
> `bin/plangate` は自身のパスから `plangate_root`（= `bin/` の親）を求め、
> `<CLI の repo root>/docs/working/TASK-XXXX` を読み書きする。`bin/` は導入先に配置されない
> ため、PATH 上の `plangate` は必ず**別の場所にある上流 clone** の実体を指す。cwd 非依存で
> パスを明示できる `--dir` を持つのは `validate` / `validate-schemas` **だけ**で、
> `review` / `eval` / `metrics` / `doctor` に相当オプションは無い。

**handoff.md 発行コマンドは未実装**（環境を問わず手動）。skill 利用者が `docs/working/templates/handoff.md` をコピーし手動で 6 要素を記載する。テンプレートが解決できない環境の扱いは「参照解決順」の注記に従う。

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
   （正本: `docs/workflows/ai-loop/c3-prime-contract.md` §3〜§5）。
   **c3-prime を手動 sha256 のみで代替してはならない** — `plan.md` 単体の hash 一致だけで
   検証済みと扱うと、残り 5 artifact と `source_sha` の stale を見逃す。この場合は item 3 の
   上流 clone 経由 `plangate validate --dir` で機械検証するか、機械検証できない旨を
   handoff.md と `decision-log.jsonl` に記録し **V-1 を PASS と書かない**
2. **AC 突合そのものは手動で行う** — test-cases.md の各 AC を実行結果と 1 件ずつ突合する。
   推測ではなく実行結果のみで PASS/FAIL を付ける原則は CLI の有無に関わらず不変
3. CLI による機械検証が必要なら、上流リポジトリを clone して
   `bin/plangate validate --dir <導入先の TASK ディレクトリの絶対パス>` を実行する。
   **位置引数形式（`validate TASK-XXXX`）は使わない** — clone 側の `docs/working/TASK-XXXX` を
   見に行ってしまい、導入先の TASK は検査されない

## 次フェーズへ

handoff 完了後は PR 作成 → C-4 ゲート（GitHub 上の人間レビュー）→ マージ。
