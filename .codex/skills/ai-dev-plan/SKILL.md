---
name: ai-dev-plan
description: "PBI INPUT PACKAGE から PlanGate の plan.md / todo.md / test-cases.md を B-1→B-2→B-3 フローで作成する。Use when: docs/working/TASK-XXXX/pbi-input.md を元に実行計画を作りたい時。"
---

# AI-Driven Plan (PlanGate / Codex 共用)

PlanGate ワークフローの **plan フェーズ（WF-02〜WF-03）** を Codex / Claude Code 両方で実行する skill。実行ロジックは `scripts/ai-dev-workflow` / `bin/plangate` CLI 側に集約し、skill は読む順序と入出力規約のみを担う。

## Read First

### 参照解決順（導入先で必ずこの順に探す）

本 skill の参照は上流リポジトリ基準の相対パスで書かれている。導入先ではそのままでは
解決できないものがあるため、**次の順で探索する**:

1. 導入先リポジトリの相対パス（例: `.claude/rules/mode-classification.md`）
2. 無ければ plugin root 配下（例: `${CLAUDE_PLUGIN_ROOT}/rules/mode-classification.md`）
   - **解決は Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して確認する**。
     Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
     という文字列をそのまま Read しても必ず失敗する
   - **変数が空・未設定なら glob（`~/.claude/plugins/cache/**` 等）で推測せず 3 へ進む**。
     キャッシュには複数バージョンが並存しうるため、当て推量は版の取り違えを招く
3. どちらにも無い場合は **「解決できなかった」と明示**し、推測で内容を補わない

導入経路は 3 つあり、配置されるものが違う（**「同じ 4 ディレクトリが配られる」わけではない**）:

- **`install.sh --claude` 経由**: コピー対象は `agents` / `skills` / `commands` / `rules`
  の 4 ディレクトリのみ（一次ソース: `install.sh` の `for dir in agents skills commands rules`）
- **plugin（Claude marketplace）経由**: バンドルは `agents` / `assets` / `commands` /
  `hooks` / `rules` / `scripts` / `skills` + `README.md` / `.claude-plugin/`。ただし
  `scripts/` の中身は `install-plangate-skills.sh` のみで、**`ai-dev-workflow` も
  `bin/plangate` も含まれない**
- **Codex（`install.sh --codex` / marketplace）経由**: 配置されるのは **skills だけ**。
  `install_codex()` は `install-plangate-skills.sh` を呼ぶのみで、同スクリプトは
  `rules` を一切扱わない（`.claude/rules/` は作られない）。`${CLAUDE_PLUGIN_ROOT}` も
  Claude Code の変数であり Codex には無い

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md` | `.claude/rules/` に着地（解決可） | `${CLAUDE_PLUGIN_ROOT}/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `docs/**` | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `bin/**` | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |
| `scripts/**` | コピー対象外（解決不可） | `${CLAUDE_PLUGIN_ROOT}/scripts/` は存在するが `install-plangate-skills.sh` のみ（目的の CLI は解決不可） | 未配置（解決不可） |

**Codex 経路では解決順 1・2 とも成立しない**ため、rules 参照は手順 3（解決できなかったと
明示）に落ちる。`docs/**` が解決できない環境と同様、正本の内容は **本 skill の記述で代替**
し、plan.md の Questions / Unknowns に「正本 `<path>` を参照できなかった」旨を記録する。

### 読む順序

> 下記 3〜5 の fallback にある `<plugin_root>` は、上の「参照解決順」手順 2 のとおり
> **Bash で `${CLAUDE_PLUGIN_ROOT}` を展開して得た絶対パス**を指す（変数を含む文字列を
> そのまま Read しない）。

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md` → fallback `<plugin_root>/rules/working-context.md`
   （B フェーズ 3 ファイル同時生成・段階別出力・ゲート条件の正本）
4. `.claude/rules/mode-classification.md` → fallback `<plugin_root>/rules/mode-classification.md`
   （5 段階 mode + `lite_eligible` 派生属性の正本）
5. `.claude/rules/hybrid-architecture.md` → fallback `<plugin_root>/rules/hybrid-architecture.md`
   （Rule 1〜5 / handoff 必須化）
6. `docs/ai-driven-development.md`（**配布対象外**。上流リポジトリで作業する場合のみ解決する）
   - 最低限: `## ワークフロー全体像`、`### タスク規模によるモード分岐（5 モード）`、`## ゲート条件`、`### Prompt 1: Plan + ToDo + Test Cases生成`
   - 解決できない場合は 3〜5 の rules を優先正本とし、本 skill の「Rules」節で代替する
7. `docs/working/TASK-XXXX/pbi-input.md`（導入先で作成する入力。無ければ plan を開始しない）

## Output

- `docs/working/TASK-XXXX/plan.md`
- `docs/working/TASK-XXXX/todo.md`
- `docs/working/TASK-XXXX/test-cases.md`
- `docs/working/TASK-XXXX/INDEX.md`（任意・無ければ生成）
- `docs/working/TASK-XXXX/decision-log.jsonl`（初期化）

## Rules

### フロー（詳細は正本参照）

- **B-1 / B-2 / B-3** フローおよび plan.md 必須セクション（確認事項 / アプローチ比較 / Mode判定 / lite_eligible 等）は `docs/ai-driven-development.md` の `### Prompt 1: Plan + ToDo + Test Cases生成` と `.claude/rules/mode-classification.md` を **正本** とする。skill は順序のみを示す。
- B-1（最大 3 問の確認質問）→ **事前メトリクス検証 (mandatory gate)** → B-2（2〜3 案の trade-off 比較）→ B-3（3 ファイル同時生成）

### 事前メトリクス検証 (B-1 → B-2 mandatory gate / #351 TASK-0117)

> 正本: [`docs/ai/plan-metrics-verification.md`](../../../docs/ai/plan-metrics-verification.md)
> （`docs/**` は配布対象外。解決できない環境では以下の要約に従い、正本未参照である旨を plan に記録する）

「全部 / 全件 / 残り N 件」系の対象は **実数を取得** してから B-2 へ進む。

**検証コマンド例** (.git / node_modules 等を除外):

```sh
grep -rln --exclude-dir={.git,node_modules,dist,docs/working} <symbol> --include='*.md' -- . | wc -l
find . -name <pattern> -not -path './.git/*' -not -path './node_modules/*' | wc -l
# 推奨: rg --files <path> | wc -l
```

**判定基準** (実数 / AI 見積もり):

- ≥ 3 倍 → **スコープ縮小 or 別タスクへ切替**
- 1〜3 倍 → 採用、plan の Risks に記録
- < 1 倍 → 採用、Mode を 1 段下げる候補

**plan.md template に `## Metrics Evidence` 欄を必須化** (実数 / 見積もり / ratio / 判定 を残す出力契約 / AC-8)。

**未取得時の分岐 (安全側 / R-001/R-004)**: 実数取得不能 / Plan Health 未算出 / 「全件」系の対象が曖昧な場合は **必ず Mode 引き上げ側に倒す** (`mode-classification.md` AC-8 安全側不変条件と一貫)。

### todo.md 規約

- タスク粒度 2-5 分、`Owner: agent / human` 必須、`depends_on` / `files` 必須
- L-0〜V-4・PR 作成は workflow-conductor が自動制御するため含めない
- 各タスクに `rollback:` を記載（戻し手順）。**必須=high-risk / critical の実装タスク**。standard 以下は任意、検証/読取のみは `rollback:不要` と明記可
- rollback 手順が長い場合はタスク直下に補助ブロックで記述してよい

### test-cases.md 規約

- 各 AC → テストケースのマッピング必須、Edge case を含める

### 監査

- decision-log.jsonl に B-1/B-2/B-3 の主要判断を append-only で記録
- mode が `critical` で `lite_eligible=true` の場合は人間の C-3 明示承認記録が前提（`mode-classification.md` AC-11）

## 計画の構造化観点（river-review rr-upstream-create-plan-001 由来 / #517 受け入れ）

plan.md 生成時、以下の観点を Work Breakdown / Risks に反映する:

1. **仮説と確定事項の分離** — 判断に必要な事実が欠けていれば Questions / Unknowns に
   質問として先出しし、仮説（未確認の前提）と確定事項を混ぜない。情報不足のまま
   推測で進めない
2. **リスクの 3 点セット** — Risks には `内容 / 検証手段 / Fallback` を揃える。
   不確実性（互換性・性能・移行・セキュリティ）ごとに検証方法が無いリスクを残さない
3. **人間ゲートの明示** — 設計確認・仕様確認など人間レビューが必要なブレーキ
   ポイントを Work Breakdown の 🚩 チェックポイントとして明示する（自己設置 Gate は
   勝手に解除しない — responsibility-classes.md 準拠）
4. **速く学べる順** — ステップは検証が早く回る順に並べ、クリティカルパスを明示。
   並列可能な作業はまとめて示す

> 出典: river-review `rr-upstream-create-plan-001`（skill インベントリ監査で
> 「plan を作る側 = PlanGate の責務」と整理され移管。s977043/river-review#1105）

## CLI 呼び出し

- 実コマンド: `./scripts/ai-dev-workflow TASK-XXXX plan`
- 機械検証: `bin/plangate validate TASK-XXXX`（plan_hash 整合）

### CLI 不在時のフォールバック（導入先では既定）

`scripts/ai-dev-workflow` と `bin/plangate` は **3 経路のいずれでも導入先に
配置されない**。根拠は経路ごとに異なる:

- `install.sh --claude` 経由: コピー対象が `agents` / `skills` / `commands` / `rules` の
  4 ディレクトリに限られ、`bin/` も `scripts/` も対象外
- plugin（Claude marketplace）経由: `${CLAUDE_PLUGIN_ROOT}/scripts/` は存在するが中身は
  `install-plangate-skills.sh` のみ。`bin/` はバンドルに無い
- Codex 経由: 配置されるのは skills のみ

上記コマンドが存在しない場合は次に従う:

1. **手動生成に切り替える** — 「Output」の 5 ファイルを skill の手順どおり手で作る。
   B-1 →（事前メトリクス検証）→ B-2 → B-3 の順序と出力契約は **CLI の有無に関わらず不変**
2. **`plan_hash` 整合検証は標準コマンドで代替する（スキップしない）** — `plangate validate`
   の plan_hash 検査は **`plan.md` の素の sha256**（正規化・前処理なし）と `c3.json` の
   `plan_hash` から `sha256:` prefix を除いた値の単純比較なので、CLI 無しで再現できる:

   ```sh
   # 算出（sha256sum が無い環境では shasum -a 256 を使う）
   sha256sum docs/working/TASK-XXXX/plan.md | awk '{print $1}'
   # 突合先: docs/working/TASK-XXXX/approvals/c3.json の "plan_hash": "sha256:<この値>"
   ```

   **不一致なら C-3 承認後に plan が改変されている** → exec に進まず、再承認
   （`c3.json` の `plan_hash` 更新）または plan の revert を行う。
   `sha256sum` / `shasum` の**両方とも無い場合に限り**スキップし、その事実を
   `decision-log.jsonl` と plan.md に記録して **「機械検証済み」と書かない**
   （未検証を検証済みと誤記しない）
3. **ゲートは人手で維持する** — plan_hash を照合する hook も導入先には配線されないため、
   item 2 の突合は **exec 開始前に自分で実行する**。C-3 は人間の明示承認記録
   （`docs/working/TASK-XXXX/approvals/c3.json` 相当）で成立させ、CLI が無いことを理由に
   C-3 を省略しない
4. CLI による機械検証が必要なら、上流リポジトリ（`s977043/plangate`）を clone して
   そこから実行する

## 次フェーズへ

plan 完了後は `plan-review-gate` skill で C-1 → C-2 → C-3（c3.json APPROVED）。exec は `ai-dev-exec` skill。
