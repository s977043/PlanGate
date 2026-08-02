---
name: ai-dev-exec
description: "PlanGate の exec フェーズを TDD で実行する。Use when: C-3 APPROVED 後にコード実装を開始したい時、workflow-conductor 配下で実装タスクを進めたい時。"
---

# AI-Driven Exec (PlanGate / Codex 共用)

PlanGate ワークフローの **exec フェーズ（WF-04 Build & Refine）** を Codex / Claude Code 両方で実行する skill。

## 前提条件（exec 開始ゲート）

- `docs/working/TASK-XXXX/approvals/c3.json` が存在し `c3_status: APPROVED`
- `plangate validate` PASS（plan_hash 整合 / artifact 整合 / EH-3 整合）
- `plangate exec` は APPROVED c3.json のみ受理（CLI 側で機械チェック）

これらが満たされなければ exec を**開始しない**。コマンド表記・`TASK-XXXX` の解決先・
CLI が無い環境での代替手順は「CLI 呼び出し」節を参照する（**CLI が無いことを理由に
ゲートを省略しない**）。

> **settings タスクロック** (`plangate doctor --check-settings`) は **V-1 / handoff 完了の前提条件**（`.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md` が正本）。exec 入口では block しない。詳細は `ai-dev-verify` skill。

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
| `rules/*.md`（下記 3〜5） | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `bin/**`（CLI） | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` | コピー対象外（解決不可） | `<plugin_root>/scripts/` は存在するが `install-plangate-skills.sh` のみ（`ai-dev-workflow` / `codex-guarded.sh` 等は解決不可） | 未配置（解決不可） |

`docs/working/TASK-XXXX/*`（下記 6〜7）は**配布物ではなく導入先で作成する作業成果物**なので、
導入先リポジトリ内でそのまま解決する（存在しなければ plan フェーズが未完了）。

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

**呼び出し表記は実行環境で変わる**。相対パス形式（`bin/plangate` / `./scripts/...`）が成立するのは
**上流リポジトリ（`s977043/plangate`）を clone した cwd に居るときだけ**で、導入先には `bin/` も
`scripts/`（の CLI 本体）も配置されない。導入先で PATH を通した場合のコマンド名は
**`plangate`**（`bin/plangate` ではない）。どちらの環境かを確定してから使う。

| 用途 | 上流リポジトリの cwd | 導入先 + PATH に `plangate` あり | 導入先 + PATH に無い（**既定**） |
|------|---------------------|----------------------------------|--------------------------------|
| exec dispatch | `bin/plangate exec TASK-XXXX [--mode <mode>]` | `plangate exec TASK-XXXX` は**実在するが対象が CLI 側**（下記注意）→ 導入先の TASK には使えず手動で TDD 実行 | 手動で TDD 実行 |
| plan_hash / artifact 機械検証 | `bin/plangate validate TASK-XXXX` | `plangate validate --dir docs/working/TASK-XXXX` | 次節のフォールバック（sha256 突合） |

> **注意: `TASK-XXXX` 位置引数は cwd ではなく CLI 本体の位置を基準に解決される。**
> `bin/plangate` は自身のパスから `plangate_root`（= `bin/` の親）を求め、
> `<CLI の repo root>/docs/working/TASK-XXXX` を読み書きする。`bin/` は導入先に配置されない
> ため、PATH 上の `plangate` は必ず**別の場所にある上流 clone** の実体を指す。つまり導入先で
> `plangate exec TASK-XXXX` を実行しても、対象は導入先の `docs/working/` ではなく
> **その clone 側の `docs/working/`** になる。cwd 非依存でパスを明示できる `--dir` を持つのは
> `validate` / `validate-schemas` **だけ**で、`exec` / `resume` / `status` / `review` / `eval` /
> `metrics` / `context` / `render` / `approve` に相当オプションは無い。

- 並行で `./scripts/ai-dev-workflow TASK-XXXX exec` も利用可（**上流リポジトリの cwd のみ**。`scripts/ai-dev-workflow` は配布対象外）
- **Codex CLI 経由の場合は `scripts/codex-guarded.sh --task TASK-XXXX exec --full-auto` を推奨**（**上流リポジトリの cwd のみ**。pre-flight で validate + doctor --check-settings 実行、post-flight で plan.md drift 検知）

> ✅ **Codex CLI 物理 hook 等価達成 (PR #347)**: `.codex/hooks.json` + `.codex/hooks/eh-bridge.sh` で EH-1/2/3/6/9 が Codex session 中の Write/Edit/Bash 呼び出しに対しても発火する。`scripts/codex-guarded.sh` の session 前後検知と合わせて Claude Code と等価な強制力。**ただしこれらも配布対象外**なので、導入先では下記フォールバックでゲートを人手維持する。

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
   （正本: `docs/workflows/ai-loop/c3-prime-contract.md` §3〜§5）。
   **c3-prime を手動 sha256 のみで代替してはならない** — `plan.md` 単体の hash 一致だけで
   入口ゲート確認済みとして exec に進むと、残り 5 artifact と `source_sha` の stale を見逃す。
   この場合は item 4 の上流 clone 経由 `plangate validate --dir` で機械検証するか、
   機械検証できない旨を `decision-log.jsonl` に記録して **exec を保留する**
3. **hook も配布されない前提で運用する** — plan_hash を照合する hook（EH-3）は導入先には配線され
   ないため、item 2 の突合は **exec 開始前に自分で実行する**。CLI が無いことを理由に C-3 を省略しない
4. CLI による機械検証が必要なら、上流リポジトリを clone して
   `bin/plangate validate --dir <導入先の TASK ディレクトリの絶対パス>` を実行する。
   **位置引数形式（`validate TASK-XXXX`）は使わない** — 上表の注意のとおり clone 側の
   `docs/working/TASK-XXXX` を見に行ってしまい、導入先の TASK は検査されない

## 次フェーズへ

exec 完了後は `ai-dev-verify` skill で V-1〜V-4 + handoff.md 発行。L-0〜V-4 は workflow-conductor が自動進行。
