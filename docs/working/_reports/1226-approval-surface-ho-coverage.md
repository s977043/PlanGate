# #1226 — 承認手順の定義面と Hardening Override の被覆ギャップ（全数照合と是正案）

> 測定基点: **`origin/main` = `b3565b2`** / 2026-09-07。issue 本文の実測は `6370573`、issue コメントの Phase 0 実測は `ecfef5b` 時点。**本書はすべて `b3565b2` で測り直した値**であり、件数は測定値であって契約値ではない。
> 適用可能な patch は別冊 [`1226-approval-surface-patch-applicable.md`](./1226-approval-surface-patch-applicable.md)。
> 本セッションで AI が作成したのは `docs/working/_reports/` 配下の `.md` 2 本のみ。`scripts/` / `tests/` / `.claude/` / `.codex/` / `.cursor/` / `bin/` / `schemas/` / `.github/` / `plugin/` は **1 バイトも変更していない**。
> 責務: HO 対象ファイルの変更提案は patch 文書提示まで（AI-owned）。**適用・merge・ruleset 操作は Human-owned**。本書は承認境界を緩める提案を一切含まない。

---

## 0. 結論先行

| 問い | 答え |
|---|---|
| **issue の 6 ファイル表は現 main でも成立するか** | **成立する**。6 ファイルすべて現存し、HO は `.claude/rules/working-context.md` の 1 本のみ（§2） |
| **6 本で全数か** | **いいえ。全数ではない。** 承認手順を定義・実装している面は **規範層 20 面 / 実装層 22 面**あり、issue の 6 本はそのごく一部（§3）。issue コメントが挙げた 7 面目 `.cursor/skills/plan-review-gate` は**実体ファイルではなく symlink**（§3.4） |
| **最も重い新規発見** | **`.codex/skills/**/SKILL.md` は正本 `.agents/skills/` の無変換コピーであるべきなのに、40 件中 10 件が実際に乖離しており、うち 7 件が承認手順の定義面**。`plan-review-gate` の Codex 版からは「機械 block が無いことを理由に C-3 を省略しない」という規範ブロックが**欠落している**（§4）。issue が「起こりうる」と書いた事象は**既に main で起きている** |
| **次に重い発見** | **Codex / Cursor の enforcement 配線が 1 つも HO でない**。`.claude/settings*.json` は HO なのに `.codex/hooks.json` / `.cursor/hooks.json` / `.cursor/hooks/*.sh` は非 HO。さらに **EH-13（承認トークンガード）本体 `scripts/check-approval-token-write.sh` 自身が非 HO**（§3.2） |
| **推奨** | **A′（HO の最小・非対称解消のみ拡張）＋ B′（`.codex` レーンの内容 drift を PR CI で必須化）の併用**。案 A の広域適用（skills / plugin を HO へ）と案 C（plugin を repo から外す）は棄却（§5） |
| **この提案で塞がらないもの** | Bash 経路 / symlink / worktree / 導入先 / **CI が required check でないこと**（実測: required は `Markdown lint` 1 本、承認 0 人）（§7） |

---

## 1. HO 判定の方法（再現手順）

HO 判定の正本は `scripts/hooks/check-plan-hash.sh` の **`_override=0` 直後の `case` ブロック（`esac` まで）**。行番号ではなくブロックで参照する。`b3565b2` 時点の内容は次のとおり（**ラベル 9 行 / パターン 15 個**）:

```sh
_override=0
case "$_ho_key" in
  .claude/rules/*.md) _override=1 ;;
  .claude/settings.json|.claude/settings.local.json|.claude/settings.example.json) _override=1 ;;
  .claude/commands/*.md|.claude/commands/*/*.md) _override=1 ;;
  .claude/agents/*.md|.claude/agents/*/*.md) _override=1 ;;
  scripts/hooks/*.sh) _override=1 ;;
  bin/plangate) _override=1 ;;
  schemas/*.schema.json) _override=1 ;;
  .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
  agents.md|claude.md) _override=1 ;;
esac
```

判定入力は `_ho_key`＝`_pg_fold_path(..., lower=1)` の出力（`./` 除去 / `//` 畳み込み / `..` 字句畳み込み / repo root 除去 / 小文字化を経たもの）。

**照合の実施方法**: 上記 15 パターンを Python の `fnmatch.fnmatchcase` に写し、対象パスを小文字化して照合した。POSIX `case` の glob と `fnmatchcase` は本ブロックで使われる演算子（`*` と `|` の分岐と literal）について同値である — 特に **`case` の `*` は `/` を跨いで一致し、`fnmatchcase` も同じ**（`fnmatch` と異なり `fnmatchcase` は正規化を行わない）。

### 検出力の確認（positive / negative control）

`sh scripts/hooks/check-plan-hash.sh` の実走は本セッションの実行環境が `sh` 起動を拒否するため行えていない。代わりに replica の妥当性を control で示した:

| 種別 | パス | 期待 | 実測 |
|---|---|---|---|
| positive | `.claude/rules/working-context.md` | HO | **HO** (`.claude/rules/*.md`) |
| positive | `scripts/hooks/check-plan-hash.sh` | HO | **HO** (`scripts/hooks/*.sh`) |
| positive | `bin/plangate` | HO | **HO** (`bin/plangate`) |
| positive | `schemas/c3-approval.schema.json` | HO | **HO** (`schemas/*.schema.json`) |
| positive | `CLAUDE.md` / `AGENTS.md` | HO | **HO** (`claude.md` / `agents.md`。小文字化経由) |
| positive | `.claude/agents/orchestrator.md` | HO | **HO** |
| positive | `.github/workflows/ci.yml` | HO | **HO** |
| positive | `.claude/commands/ai-dev-workflow.md` | HO | **HO** |
| negative | `docs/ai/plan-normalization-gate.md` | 非 HO | **非 HO** |
| negative | `README.md` | 非 HO | **非 HO** |

**9 件の positive control すべてが一致し、negative control は発火しない。** 「常に HO と答える」「常に非 HO と答える」いずれの空振りでもないことが示された。**この照合は静的な replica であり、hook 実走の rc 実測ではない**（残存 / §7）。

---

## 2. issue の 6 ファイル表の再実測（`b3565b2`）

| # | ファイル | 存在 | HO 該当 | 一致したパターン | 承認手順のどの部分を定義しているか | issue の記載と一致 |
|---|---|---|---|---|---|---|
| 1 | `.claude/rules/working-context.md` | YES | **HO** | `.claude/rules/*.md` | C-3 三値の意味 / CONDITIONAL の 5 段順序（R-NNN 集約 → 1 回確定反映 → 簡易 C-1 → APPROVED `c3.json` → exec）/ Autonomous APPROVE 判定マトリクス / 条件付き降格 AC-8〜AC-10 / settings タスクロック | **一致** |
| 2 | `.agents/skills/plan-review-gate/SKILL.md` | YES | 非 HO | — | C-1 25 項目 / C-2 2 レーン / **C-2 → 確定反映 → Plan Normalization → 簡易 C-1 → `c3.json` 発行 の厳守順序** / CLI 不在時フォールバック 5 項目 | **一致** |
| 3 | `.codex/skills/plan-review-gate/SKILL.md` | YES | 非 HO | — | 同上（ただし**正本から乖離**。§4） | **一致**（ただし issue は乖離に触れていない） |
| 4 | `plugin/plangate/skills/plan-review-gate/SKILL.md` | YES | 非 HO | — | 同上（正本と byte 一致） | **一致** |
| 5 | `docs/ai/plan-normalization-gate.md` | YES | 非 HO | — | **定義していない**。本文が「手順・契約・PASS 条件の正本は skill 側」「規範的な記述は置かない」と明示的に自己否認している | **不一致（issue が過大）**。是正対象としての優先度は低い |
| 6 | `scripts/check-plan-normalization.py` | YES | 非 HO | — | Plan Normalization の機械判定（no-op / 必須見出し欠落 / 契約 ID 消失 / **契約 ID ゼロの vacuous truth ガード** → exit 1） | **一致** |

**6/6 現存、5/6 が非 HO。issue の主張は現 main でも成立する。** ただし #5 は「承認手順を定義している」とは言えず、6 面のうち実質的な定義面は 5 面である。

---

## 3. 全数照合 — 「6 本」は全数ではない

### 3.1 探索手順

「承認手順を定義・実装している」の作業定義を次のように置いた:

> **(a) C-3 / exec の受理条件を宣言している**（何を満たせば exec に進めるか）、または
> **(b) C-3 到達前に踏むべき必須手順を宣言している**、または
> **(c) 承認トークン（`approvals/c3.json` 等）の妥当性・受理を機械的に判定している**

recall を優先した粗い掃き出しから始め、読んで narrowing した。`git grep -E` は `\s` / `\b` を解釈しないため `-P` を使った。

```sh
# 粗い掃き出し（recall 優先）
git grep -lPn 'APPROVED のみ|c3_status|plan_hash|lite_eligible' \
  -- . ':!docs/working' ':!CHANGELOG.md' ':!tests' ':!AGENT_LEARNINGS.md'   # 約 180 件

# 実装層の掃き出し
git grep -lP 'c3\.json|c3_status|plan_hash|APPROVED|autonomous.approve|normalization' \
  -- '*.sh' '*.py' 'bin/*' '*.json' '.github/**'

# ミラー構造の掃き出し
git ls-files | grep -E 'plan-review-gate|plan-normalization|check-plan-normalization'
git ls-files | grep -E '(^|/)(rules|commands|agents)/' | grep -v '^docs/working/'
```

**positive control（掃き出しに検出力があること）**: `git grep -lP 'APPROVED の c3\.json のみ受理'` は `.agents/` / `.codex/` / `plugin/` の 3 面を返した — 既知の定義面が実際に拾えている。
**negative control**: 同じ掃き出しは `README.md` / `CHANGELOG.md` も返す（＝ recall 過剰）。したがって**掃き出し結果をそのまま「定義面」と呼ばず、1 件ずつ読んで (a)(b)(c) で narrowing した**。この読み分けを経ていない件数は本書に載せていない。

### 3.2 実装層（承認トークンの受理を機械的に決める面）— 22 件

| ファイル | HO | どの受理判定を行うか |
|---|---|---|
| `bin/plangate` | **HO** | `cmd_exec`: `approvals/c3.json` 不在 → `C-3 gate not cleared` / legacy `c3_status != APPROVED` → block / 記録 `plan_hash` vs `sha256sum plan.md` → `plan_hash mismatch`。`cmd_approve` がトークンを発行 |
| `scripts/hooks/check-plan-hash.sh` | **HO** | EH-3。HO 常時 block / `plan_hash` 不一致 / maintenance / doc-light |
| `scripts/hooks/check-c3-approval.sh` | **HO** | EH-2。`c3_status != APPROVED` → block |
| `scripts/hooks/check-merge-approvals.sh` | **HO** | EH-7。`c3_status` と `c4_status` 双方 APPROVED |
| `scripts/hooks/cursor-adapter.sh` | **HO** | rc → `{"permission":"deny"/"allow"}` |
| `schemas/c3-approval.schema.json` | **HO** | legacy トークンの構造的妥当性（`c3_status` enum / `plan_hash` pattern / `additionalProperties:false`） |
| `schemas/c3-prime.schema.json` | **HO** | c3-prime トークン（`approval_kind` const / `decision=AUTO_APPROVED` ⇒ 両レビュアー `approve`） |
| `.claude/settings.example.json` | **HO** | Claude レーンの EH-2 / EH-3 / EH-13 配線 |
| **`scripts/check-approval-token-write.sh`** | **非 HO** | **EH-13。`c3.json` / `parent-c3.json` / `parent-integration.json` / `maintenance.json` への AI 書込を fail-closed で block する本体** |
| `scripts/check-plan-normalization.py` | 非 HO | Plan Normalization 機械判定 |
| `scripts/plan_hash_util.py` | 非 HO | Python 側 `plan_hash` 読み出し（不正 JSON は承認記録として信用しない） |
| `scripts/ai-loop/c3prime_verify.py` | 非 HO | c3-prime の受理判定（`decision != AUTO_APPROVED` → exec 不可 / `source_sha` / `plan_hash` / レビュアー独立性） |
| `scripts/ai-loop/c3_contract.py` | 非 HO | 受理判定が使う契約定数と述語（`c3_status` キー混入を禁止） |
| `scripts/ai-loop/arbiter.py` | 非 HO | **autonomous approve の可否そのもの**（HO 接触 → ESCALATE / `lite_check` 4 軸 / `SIZE_OK_MAX_FILES` / `approve-approve` → AUTO_APPROVED） |
| `scripts/ai-loop/plan_package.py` | 非 HO | `C1-VERDICT: PASS` / `C2-VERDICT: approve` マーカーと plan hash の突合 |
| `scripts/ai-loop/delivery.py` | 非 HO | Delivery 側の c3-prime 再検証（legacy `c3.json` → BLOCK） |
| `scripts/ai-loop/run_evidence_verify.py` | 非 HO | RunEvidence の c3 束縛 / terminal state 再計算 |
| `scripts/codex-guarded.sh` | 非 HO | pre-flight `bin/plangate validate` / post-flight plan.md hash drift → exit 2 |
| **`scripts/ai-dev-common.sh`** | **非 HO** | **第 2 の C-3 受理経路**: `grep -Eq '^## C-3 Gate: APPROVED$'` のみ。`c3.json` も `plan_hash` も見ない |
| `scripts/ai-dev-workflow` / `scripts/ai-dev-prepare-cloud.sh` | 非 HO | 上記マーカー判定の呼び出し元（exec / cloud packet 生成を block） |
| **`.codex/hooks.json`** | **非 HO** | **Codex レーンの EH-1/2/3/6/9 配線** |
| **`.codex/hooks/eh-bridge.sh`** | **非 HO** | rc → allow/deny 翻訳。**未知 rc は `allow`（fail-open）** |
| **`.cursor/hooks.json` / `.cursor/hooks/plangate-eh2-c3.sh` / `plangate-eh1-plan.sh`** | **非 HO** | **Cursor レーンの EH-1/2 配線**（`failClosed: false`） |

**8 / 22 が HO。14 が非 HO。**

**この層で最も重い非対称**: Claude レーンの配線（`.claude/settings*.json`）は HO なのに、Codex / Cursor レーンの配線は 1 つも HO でない。`.cursor/hooks/plangate-eh2-c3.sh` は現状 3 行のシェルスクリプトで、`exit 0` に書き換えるだけで Cursor セッションの EH-2 が消える。**HO を 1 つも踏まずに。** 同様に **EH-13 は承認トークンを守るガードだが、ガード本体が AI 編集可能な位置にある**。

### 3.3 規範層（散文で必須条件・必須手順を宣言している面）— 20 件

| ファイル | HO | 何を宣言しているか |
|---|---|---|
| `.claude/rules/working-context.md` | **HO** | C-3 の正本（§2 #1） |
| `.claude/rules/mode-classification.md` | **HO** | `lite_eligible` の正本 / **HO 9 カテゴリ一覧そのもの** / 承認境界周辺 → 最低 high + 同期 C-3 固定 |
| `.claude/rules/responsibility-classes.md` | **HO** | C-3 / C-4 は Human-owned / 自己設置 Gate 非緩和原則 |
| `.claude/rules/orchestrator-mode.md` | **HO** | `ChildExecAllowed`（`c3.json` の `decision == "APPROVED"` 必須）/ AS-2 / AS-5 |
| `.claude/commands/ai-dev-workflow.md` | **HO** | 「C-3 未承認では exec を実行しない」 |
| `plugin/plangate/rules/{working-context,mode-classification,responsibility-classes,orchestrator-mode}.md` | 非 HO ×4 | 上記 4 本の **byte 一致コピー**。**導入先が読むのはこちら** |
| `plugin/plangate/commands/ai-dev-workflow.md` | 非 HO | 同上 |
| `.agents/skills/plan-review-gate/SKILL.md` | 非 HO | C-3 手順の正本（§2 #2） |
| `.agents/skills/plan-normalization/SKILL.md` | 非 HO | Plan Normalization の 7 手順 + PASS 条件 9 項目（「C-3 がまだ発行されていない」を含む） |
| `.agents/skills/ai-dev-exec/SKILL.md` | 非 HO | **exec 入口条件の正本**（`c3.json` 存在 + `approval_kind` 別条件 + validate 相当 PASS） |
| `.agents/skills/ai-dev-plan/SKILL.md` | 非 HO | CLI 不在時の `plan_hash` 整合検証は「スキップしない」/ AC-11 |
| `.agents/skills/ai-dev-verify/SKILL.md` | 非 HO | V-1 の `plan_hash` 突合を必須と規定 |
| `.agents/skills/{local-exec-handoff,manual-cloud-task,intent-classifier}/SKILL.md` | 非 HO ×3 | 「APPROVED 確認は省略不可」「AI は `c3.json` を代理発行しない」 |
| `.codex/skills/**` / `plugin/plangate/skills/**` の同名ファイル | 非 HO | 上記 skill 群のコピー（**`.codex` 側は乖離あり。§4**） |
| `docs/ai/core-contract.md` | 非 HO | Iron Law #1「C-3 承認前に production code を変更しない」/ phase 完了条件 |
| `docs/ai/contracts/approve-wait.md` / `execute.md` | 非 HO | phase 契約（`c3.json` に記録される値 / plan_hash 改竄 → block） |
| `docs/c3-approval-command.md` | 非 HO | **承認トークン発行の唯一の正規経路**（L1-L4 Human presence 検証。不成立なら `c3.json` は生成されない） |
| `docs/workflows/ai-loop/c3-prime-contract.md` / `lite-criteria.md` | 非 HO | C-3′ の受理条件 / lite 4 軸（**「lite 基準の制定・改版は Human-owned 固定」と自称**） |
| `docs/ai/plan-review-readiness-gate.md` + `docs/workflows/03_solution_design.md` | 非 HO | C-1 の前に必ず通す readiness gate（7 項目 / 判定不能は安全側） |
| `workflows/{standard,high-risk,critical,light}.yaml` | 非 HO ×4 | **機械可読の gate 定義**: `gate_enforcement.c3.{required_artifacts, approval_file, plan_hash_check}` |
| `.plangate.yml` | 非 HO | `c3_approval.mode: cli`（発行経路の選択） |
| `docs/ai/hook-enforcement.md` | 非 HO | EH-2 / EH-3 の block 条件の説明正本 |
| `.cursor/rules/plangate.mdc` | 非 HO | Iron Law #1 の Cursor 向け言い換え |

**5 / 20 が HO。15 が非 HO。**

### 3.4 issue コメントの「7 面目」について（訂正）

issue コメントは `.cursor/skills/plan-review-gate` を 7 面目として挙げているが、実測では**これは実体ファイルではない**:

```text
git ls-files -s .cursor/skills/plan-review-gate
120000 5d6082f...  .cursor/skills/plan-review-gate      ← mode 120000 = symlink
readlink → ../../.agents/skills/plan-review-gate
```

したがって**内容としては 7 面目ではない**（`.agents/` の面と同一実体）。ただし**書込経路としては独立**であり、しかも EH-3 の正規化は字句のみで symlink を解決しない（#1101 の Non-goal）。**`.agents/skills/**` を HO に入れても `.cursor/skills/plan-review-gate/SKILL.md` 経由の書込は素通りする。** この事実が §5 の案 A 広域適用を棄却する主要根拠になる。

副次的に、**`git grep` ベースの検出器は symlink 面を列挙しない**（git が追跡するのは symlink であってファイルではない）。内容 drift 検査（案 B 系）は実体を比較するので影響を受けないが、**パス列挙で完全性を主張する設計は成立しない**。

### 3.5 まとめ — issue の一覧との差分

| 観点 | issue 本文 | 本書の実測（`b3565b2`） |
|---|---|---|
| 面の数 | 6 | 規範層 20 / 実装層 22（重複除く） |
| HO の数 | 1 | 規範層 5 / 実装層 8 |
| 漏れていた重要な面 | — | **`.codex/hooks.json` / `.cursor/hooks*` / `scripts/check-approval-token-write.sh`（enforcement 配線と EH-13 本体）**、**`scripts/ai-dev-common.sh` の第 2 受理経路**、`workflows/*.yaml` の機械可読 gate 定義、`docs/c3-approval-command.md` の発行経路、`.agents/skills/ai-dev-exec` の exec 入口条件、`plugin/plangate/rules/**` の 4 本 |
| 過大だった面 | `docs/ai/plan-normalization-gate.md` | 規範的記述を置かないと自己宣言しており、定義面ではない |
| 誤りだった面 | （コメントの）`.cursor/skills/plan-review-gate` | symlink であり独立の内容面ではない（§3.4） |

**「6 本で全数」は成立しない。** 本書の 20 / 22 という数字も**測定値であって全数の証明ではない** — (a)(b)(c) の作業定義に依存し、`docs/working/` 配下の過去 TASK 成果物と `tests/` は除外している。**この種の数は契約値にしてはならない。**

---

## 4. 最重要の実測 — 正本と配布物が既に乖離している

`.codex/skills/<name>/SKILL.md` は `scripts/install-plangate-skills-to-codex.sh` が `.agents/skills/<name>/SKILL.md` を**無変換 `cp`** した結果である（frontmatter の正規化は `agents/openai.yaml` 側にのみ適用される）。したがって byte 一致であるべきだが:

```sh
for d in .agents/skills/*/; do n=$(basename "$d"); cmp -s "$d/SKILL.md" ".codex/skills/$n/SKILL.md" || echo "DIFFER $n"; done
```

| レーン | 対象数 | 乖離 |
|---|---|---|
| `plugin/plangate/skills/*/SKILL.md` vs `.agents/skills/*/SKILL.md` | 40 | **0** |
| `plugin/plangate/rules/*.md` vs `.claude/rules/*.md`（`working-context` / `mode-classification`） | 2 | **0** |
| **`.codex/skills/*/SKILL.md` vs `.agents/skills/*/SKILL.md`** | 40 | **10** |

乖離 10 件のうち **7 件が承認手順の定義面**（`ai-dev-plan` 116 行 / `ai-dev-verify` 94 行 / `ai-dev-exec` 82 行 / `ai-loop-cycle` 68 行 / `plan-review-gate` 13 行 / `intent-classifier` 7 行 / `local-exec-handoff` 7 行）。

`plan-review-gate` の乖離内容（最小の実例）— `.codex/` 版には正本にある次の規範ブロックが**無い**:

- 「機械 block が無いことを理由に C-3 を省略しない。」
- 「CLI が無いことを理由に手順を黙って省略し、実施済みと読める記録を残してはならない。」

**Codex セッションは、弱められた C-3 定義を読んでいる。**

### なぜ片方のレーンだけ一致しているのか

| レーン | 内容 drift の機械検出 | 結果 |
|---|---|---|
| `plugin/plangate/**` | **あり** — `.github/workflows/sync-plugin-plangate.yml` の `drift-check` job が PR で `sh scripts/sync-plugin-plangate.sh` → `git diff --quiet -- plugin/plangate/` | **0 / 40 乖離** |
| `.codex/skills/**` | **なし** — `scripts/check-codex-skill-spec.sh` はディレクトリ集合の presence しか見ず、CI では `--warn-only`。さらに同 workflow の `pull_request.paths` に **`.codex/**` が含まれない**ため `.codex/` だけ変える PR では job が起動すらしない | **10 / 40 乖離** |

**同じ配布メカニズムでも、CI で照合しているレーンだけが一致している。** これは案 B（機械検出）の有効性の実証であると同時に、**配線されていない検査は存在しないのと同じ**（#1259 と同型）という実測でもある。

---

## 5. 是正案の比較と推奨

### 5.1 案の評価

| 案 | 内容 | 副作用 / 短所 | 判定 |
|---|---|---|---|
| **A（広域）** | HO に `**/skills/plan-review-gate/SKILL.md` 等、承認手順の散文正本を全部追加 | (1) **`.cursor/skills/plan-review-gate` は symlink** であり、`.agents/...` を HO にしても `.cursor/...` 経由の書込は素通りする（§3.4）→ **塞いだつもりになる**。(2) HO は c3 + `plan_hash` 承認下でも**常時 block**（AI は永久に編集不可）。40 skill × 3 レーンを HO にすると skill 保守がすべて Human patch 経由になり、**運用コストが是正の便益を上回る**。(3) `plugin/**` は生成物であり、HO にすると `Edit/Write` は止まるが `Bash` 経由の同期スクリプト実行は EH-3 Bash レーン no-op（#1104）で止まらない ＝**正直な編集だけ止めて回避経路は残る** | **棄却** |
| **A′（最小・非対称解消のみ）** | HO に **`.codex/hooks.json` / `.cursor/hooks.json` / 両者の `hooks/*.sh` / `scripts/check-approval-token-write.sh`** を追加（9 → 12 カテゴリ、15 → 20 パターン） | AI がこれらを編集できなくなる（= 既存の `.claude/settings*.json` / `scripts/hooks/*.sh` と同じ扱い）。対象は 6 ファイルで、直近の変更は 2026-05 / 2026-06 の機能 PR のみ ＝ 通常保守の頻度が低く、コストが小さい | **採用** |
| **B（内容 drift の CI 検出）** | 正本とコピーの byte 一致を CI で検査 | 「手順」の機械的定義が要る、と issue は書くが — **手順を定義する必要はない。「正本と配布物が byte 一致か」だけで足りる**。既に `plugin/` レーンで実装され、実測で 0 乖離を達成している | — |
| **B′（`.codex` レーンへの拡張）** | 既存 `drift-check` job に `.codex/skills/*/SKILL.md` と `.agents/skills/*/SKILL.md` の `cmp` を追加し、`pull_request.paths` に `.codex/skills/**` を追加 | **適用時点で 10 件が FAIL する**（＝実在する欠陥の顕在化）。`sh scripts/install-plangate-skills-to-codex.sh --force` の実行とコミットが同時に必要 | **採用** |
| **C（正本更新の必須化）** | skill 側の手順変更時に `working-context.md` の対応節が同一 PR で変わっていなければ FAIL | 「対応関係」の宣言が要り、宣言自体が非 HO ファイルになる（自己参照）。また skill と rules は**同じ手順を別の粒度で書いている**ため、機械的な対応付けが安定しない | **棄却**（B′ が同じ実害をより安く塞ぐ） |
| **D（plugin を repo から外す）** | 配布時に生成 | 配布・インストール機構の変更で影響が大きく、`.codex/` / `.cursor/` は解決しない。#1263 の案 C と同一で、そちらに委ねる | **棄却** |
| **E（required check 化）** | 上記 CI 検査を GitHub ruleset の required status check にする | ruleset 操作は Human-owned。**実測: 現在の required は `Markdown lint` 1 本のみ、`required_approving_review_count: 0`** → **検査が赤でもマージできる** | **Human 判断へ送る**（#928 の一部） |

### 5.2 推奨: A′ + B′

- **A′** が塞ぐのは「HO を踏まずに enforcement 配線を無効化する」経路。**B′** が塞ぐのは「HO を踏まずに承認手順の配布物を書き換える／正本と乖離させたまま出荷する」経路。**この 2 つで issue の主張の実害面の中核が埋まる。**
- 散文正本（`.agents/skills/**` / `docs/**` / `workflows/*.yaml`）そのものの改変は**依然 HO 外のまま残す**。これは意図的な取り残しであり、§7 に残存として明記する。B′ が守るのは「正本とコピーの一致」であって「正本そのものの改変」ではない。
- patch の詳細・`git apply` 手順・変異注入・適用チェックリストは [`1226-approval-surface-patch-applicable.md`](./1226-approval-surface-patch-applicable.md)。

### 5.3 是正案の自己検証（新しい穴を作っていないか）

| 疑い | 検証 | 結果 |
|---|---|---|
| A′ が正常な編集まで止めないか | 追加対象 6 ファイルの直近変更を `git log` で確認 | `.codex/hooks.json` = 2026-05 の PR #347 が最後、`.cursor/hooks.json` = 2026-06 の PR #292 が最後。日常保守の対象ではない。**偽陽性の実害は小さい** |
| A′ が skills / docs を巻き込まないか | patch 適用後のパターン集合で `.codex/skills/plan-review-gate/SKILL.md` / `.agents/skills/**` / `docs/**` を照合 | いずれも **非 HO のまま**（§ patch 文書 §4 M-3）。`case` の `*` が `/` を跨ぐため、`.codex/hooks/*.sh` は `.codex/skills/**` を巻き込まない（`hooks/` セグメントが literal） |
| A′ が既存 HO を弱めないか（AC-6） | before/after で既存 15 パターンの一致を比較 | `.claude/rules/working-context.md` / `scripts/hooks/check-plan-hash.sh` 等は **HO → HO** で不変。**削除ゼロの追加のみ** |
| A′ 自体が「正本を更新しない」病を再生産しないか | `case` ブロックだけでなく `.claude/rules/mode-classification.md` の HO 一覧も**同一 patch に含めた** | 片側適用が構造的に起きない |
| A′ が **allowlist 改変で素通りしないか** | HO 判定は allowlist ではなく denylist（`_override=1` で無条件 exit 2）。`maintenance.json` の `allowed_paths` は HO 判定の**後**に評価される（判定順 (ii) → (iii)） | **maintenance 窓では迂回できない**。ただし判定ブロック自体を書き換える経路は `scripts/hooks/*.sh`（HO）で守られる — **循環ではなく既存の自己防護** |
| B′ の検査が空振りしないか | 現 main で 10 件検出することを実測（§4） | **空振りではない**。`\|\| true` を入れる変異で検出が消えることも確認（patch 文書 §4 M-4） |
| B′ が削除を見逃さないか | `.codex/skills/<n>/SKILL.md` 不在も FAIL にした。正当な除外が無いことを確認（`.agents/skills` に symlink 0 件、40/40 が `.codex` 側に存在、`.codex/skills/.system` 不在） | **missing も検出**。`continue` だけの変異で削除が素通りすることを確認（M-5） |
| B′ が **実行時導出で素通りしないか** | installer を CI で走らせて `git diff` を見る方式だと **installer 自身の改変で検査が空振りする**。これを避けて `cmp` による直接比較にした | installer とは独立に「正本 = 配布物」を主張する |
| B′ が **そもそも起動するか** | 既存 workflow の `pull_request.paths` に `.codex/**` が無いことを実測 | **paths への追加を同一 hunk に含めた**。含めなければ検査は存在しても発火しない（M-6） |
| 提案が承認境界を緩めていないか | 追加のみ / 削除ゼロ。C-4・merge・ruleset・Policy は一切触れない | **緩和なし**。E（required 化）も Human 判断へ送るに留めた |

### 5.4 #1263 との差分（重複回避）

| 観点 | #1263 | 本書 |
|---|---|---|
| 対象 | ガバナンス正本 30 件 → `plugin/plangate/{rules,agents,commands}` の byte 一致コピー | **承認手順（C-3 / lite_eligible / plan_hash / c3.json 受理）に限定した定義面と、その enforcement 配線** |
| 測定の中心 | 正本と plugin ミラーの一致（**実測 24/30 一致、6 件は model frontmatter 正規化**） | **`.codex/skills` レーンの乖離（10/40）** と **Codex / Cursor 配線の非 HO 性** — いずれも #1263 が扱っていない |
| 案 B の位置づけ | 「`ta-26-plugin-sync.sh` の拡張で足りる可能性」＝未実装前提 | **既に `.github/workflows/sync-plugin-plangate.yml` の `drift-check` job として PR CI に実装済みで、plugin レーンでは 0 乖離を達成していることを実測**。本書の B′ はその**未配線レーンへの横展開**であって新規機構ではない |
| HO 拡張の対象 | `plugin/plangate/{rules,agents,commands}/**` | **`plugin/` は対象にしない**（生成物 / Bash 経路で迂回可能）。代わりに **enforcement 配線 3 種 + EH-13 本体** |
| 重複 | — | **なし**。#1263 の案 A（plugin を HO へ）は本書が棄却する立場だが、これは矛盾ではなく**同じ実害に対する手段の選好差**であり、#1263 側で別途裁定されるべき |

---

## 6. 検証コマンドと exit code

| # | コマンド | rc |
|---|---|---|
| 1 | `git fetch origin && git checkout -B docs/1226-approval-ho-coverage origin/main` | 0 |
| 2 | `git grep -lPn 'APPROVED のみ\|c3_status\|plan_hash\|lite_eligible' -- . ':!docs/working' ...`（掃き出し） | 0 |
| 3 | `git grep -lP 'APPROVED の c3\.json のみ受理'`（positive control） | 0 / 3 件 |
| 4 | HO replica（`fnmatch.fnmatchcase` / positive 9 件・negative 2 件） | 0 |
| 5 | `for d in .agents/skills/*/; do ... cmp -s ...; done`（`.codex` drift） | 0 / DIFFER 10 件 |
| 6 | `for f in plugin/plangate/skills/*/SKILL.md; do ... cmp ...; done` | 0 / 0 件 |
| 7 | `gh api repos/s977043/plangate/rulesets/14939019`（required check 実測） | 0 |
| 8 | `git apply --check /tmp/1226-approval-surface.patch`（**repo root**） | **0** |
| 9 | `git apply --stat /tmp/1226-approval-surface.patch` | 0 / 3 files, +29 / -2 |
| 10 | `npx markdownlint-cli2 docs/working/_reports/1226-*.md` | 本 PR の記載に従う |

---

## 7. 残存リスク（この提案で塞がらないもの）

| # | 残存 | 追跡 |
|---|---|---|
| 1 | **Bash 経路**: `Bash` matcher は `tool_input.command` しか持たず `target_file` が空になるため HO 判定に一致しない。`sed -i` / heredoc での書換は A′ 適用後も止まらない | #1104 |
| 2 | **symlink / FS エイリアス**: EH-3 の正規化は字句のみ。`.cursor/skills/plan-review-gate` が実在する symlink であることが具体例 | #1264 / #1234 |
| 3 | **worktree 配下**: `_ho_key` が `REPO_ROOT` 前置きに固定される | #1277 |
| 4 | **CI が advisory**: 実測で required status check は `Markdown lint` 1 本のみ、承認 0 人。**B′ の検査が赤でもマージできる** | #928 |
| 5 | **散文正本そのものの改変**: `.agents/skills/**` / `docs/**` / `workflows/*.yaml` は HO 外のまま。B′ は「正本とコピーの一致」を守るのであって「正本の改変」を止めない。**本 issue の主張の一部は意図的に未解決のまま残る** | 本 issue / #1263 |
| 6 | **第 2 の C-3 受理経路**: `scripts/ai-dev-common.sh` の `^## C-3 Gate: APPROVED$` マーカー判定は `c3.json` も `plan_hash` も見ない。本書は指摘に留め、統合は提案していない | 新規（follow-up 候補） |
| 7 | **`.codex/hooks/eh-bridge.sh` の未知 rc = allow**（fail-open）/ **`.cursor/hooks.json` の `failClosed: false`** / **EH-13 が Codex・Cursor に未配線** | Human 判断（patch 文書 §7） |
| 8 | **HO 判定を hook 実走で確認していない**: 本書の判定は `fnmatch` replica。`sh` 起動が本セッションの実行環境で拒否されるため rc 実測ができていない | 本書 §1 |
| 9 | **本書の面の数（20 / 22）は全数の証明ではない**: (a)(b)(c) の作業定義に依存し、`docs/working/` の過去 TASK 成果物と `tests/` を除外している。**契約値にしてはならない** | 本書 §3.5 |
| 10 | **導入先**: plugin 配布物に `scripts/hooks/` も CLI も含まれないため、導入先には HO そのものが存在しない | #1144 |

EH-3 の HO block は**多層防御の 1 層**にすぎない。承認境界の最終的な保証主体は **C-4 Human レビュー**と **GitHub ruleset** であり、本書の提案をもって承認境界が完全になるとは主張しない。

---

## 8. 関連

- **#1226**（本 issue）/ **#1263**（一般形・§5.4 で差分を明示）/ **#1221**（実例）
- **#1101 / #1104 / #928 / #1234 / #1264 / #1277 / #1278 / #1259**（既知の残存）
- `docs/ai/hook-enforcement.md` の「既知の残存・6 系統」— いずれも「**HO への書き込みを止められない**」型。本書の型は「**HO を踏まずに承認の中身を変えられる**」であり、6 系統のどれとも異なる **7 番目のクラス**にあたる（追記は follow-up）
- 適用可能 patch: [`1226-approval-surface-patch-applicable.md`](./1226-approval-surface-patch-applicable.md)
