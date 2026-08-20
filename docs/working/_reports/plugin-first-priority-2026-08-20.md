# Plugin-first 再優先付け — open bug 41 件（2026-08-20）

> **測定基点**: `origin/main` = `e52118b6153352f7bcf1de7d1cca2026b6309330`
> （`fix(skills): docs/** 参照の解決順注記をクラス C 残存 20 件へ追加 (#954) (#1195)`）
> **方針（ユーザー指示・2026-08-20）**: 「PlanGate の基本機能は Plugin で提供をメインで進めていきたい」
> **本レポートは読み取りのみで作成した。** issue / PR への書き込み（コメント・close・ラベル・編集）は一切行っていない。
> `sync-plugin-plangate.sh` / `install-plangate-skills-to-codex.sh` / `apply-*.sh --apply` は実行していない。
> `sh <任意の .py>` は実行していない。
>
> **既存 3 レポート（`bugfix-execution-plan-2026-08-20.md` / `bug-triage-2026-08-20-{lower,upper}.md`）の
> 判定はそのまま写していない。** 主張はすべて `e52118b` に対して再測定し、食い違った 5 点は §7 に記録した。

---

## 0. 前提 — 何を「配布物」と数えたか

### 0-1. 3 導入経路と、それぞれが consumer に届けるもの（実測）

```text
$ git show origin/main:.claude-plugin/marketplace.json
  plugins[0].source = "./plugin/plangate"

$ git ls-tree origin/main plugin/plangate/
  .claude-plugin/  .codex-plugin/  README.md  agents/  assets/
  commands/  hooks/  rules/  scripts/  skills/

$ git show origin/main:install.sh | grep -n 'for dir in'
  105:  for dir in agents skills commands rules; do
  127:        cp -r "$f" "$dst/$base"        # DEST = ${TARGET_DIR:-$(pwd)/.claude}
```

| 経路 | 届くもの | 届かないもの |
|---|---|---|
| **marketplace**（`plugin marketplace add` → `plugin install`） | `plugin/plangate/**` 一式（skills 39 + README.md / agents 17 + README.md / commands 5 + README.md / rules 6 / assets 1 / scripts 1） | `bin/` / `scripts/hooks/` / `docs/` / `.claude/settings*.json` / `.codex/hooks*` |
| **install.sh --claude** | 上記のうち `agents skills commands rules` の 4 ディレクトリのみを `<project>/.claude/` へ `cp -r` | `hooks/` `scripts/` `assets/` `README.md`、および `bin/` `scripts/hooks/` `docs/` |
| **install.sh --codex** | `plugin/plangate/scripts/install-plangate-skills.sh` が `plugin/plangate/skills/` → `.codex/skills/` を展開 | 同上 |

**この表の帰結が本レポートの並べ替え軸そのもの**である:

- `docs/**` は **どの経路でも 1 ファイルも届かない**（`plugin/plangate/` に `docs/` ディレクトリが存在しない）。
- `scripts/hooks/*.sh`（17 本）は **どの経路でも 1 本も届かない**（`plugin/plangate/hooks/` は `.gitkeep` のみ）。
- `bin/plangate` は **どの経路でも届かない**（`git ls-tree -r --name-only origin/main plugin/ | grep 'bin/'` → 0 件）。
- 逆に `.claude/rules/*.md` は **install.sh 経路でだけ解決する**（`plugin/plangate/rules/` → `<project>/.claude/rules/`）。
  **marketplace 経路では解決しない**（plugin 実体は `~/.claude/plugins/.../plangate/rules/` に置かれる）。
  → 「`.claude/rules/` を参照する配布物」は **経路によって当たり外れが変わる**。

### 0-2. `.codex/skills/` の位置づけ（優先度が最も大きく動いた点）

```text
$ git show origin/main:plugin/plangate/scripts/install-plangate-skills.sh | head -12
  2: # install-plangate-skills.sh — plugin/plangate/skills/ を .codex/skills/ に展開
 10: SKILLS_SRC="${PLANGATE_SKILLS_DIR:-$PLUGIN_DIR/skills}"
```

**consumer の `.codex/skills/` は `plugin/plangate/skills/` から生成される。**
リポジトリに commit 済みの `.codex/skills/`（39 skill）は **上流自身のドッグフーディング用コピー**であり、
どの導入経路でも consumer には配られない。

→ **`.codex/skills/` の drift（#956 / #1170 / #1086）は、plugin-first の観点では consumer に一切届かない。**
これは規模・独立性で並べた既存 3 レポートとの最大の差分である（§7 S-2）。

### 0-3. `.agents/skills/` == `plugin/plangate/skills/`（drift ゼロを実測）

```text
$ git diff --stat origin/main:.agents/skills origin/main:plugin/plangate/skills -- '*/SKILL.md'
  (出力なし = 40 skill すべての SKILL.md が一致)

# 陽性コントロール（同じコマンド形で .codex を比較すると 33 件出る）
$ git diff --stat origin/main:.codex/skills origin/main:plugin/plangate/skills -- '*/SKILL.md'
  33 files changed, 214 insertions(+), 91 deletions(-)
```

**配布物の正本は `.agents/skills/` である。**
`.claude/skills/`（30 skill）は別集合で、plugin へは同期されない（§8 O-2）。

### 0-4. EH-3 の現在の挙動（オーガナイザー実測・本レポートの実行層判定の前提）

```text
PLANGATE_HOOK_TASK 未設定時:
  docs/**.md（basename が plan.md のものは BLOCK）/ .agents/skills/**.md
  .claude/skills/**.md / .codex/skills/**.md / plugin/**/*.md   → rc=0 書ける
  scripts/*.py / tests/extras/*.sh                              → rc=2 書けない
  .claude/rules/*.md / .claude/agents/*.md / .claude/settings*.json
  scripts/hooks/*.sh / bin/plangate / schemas/*.schema.json
  .github/workflows/* / AGENTS.md / CLAUDE.md                    → rc=2 HARDENING_OVERRIDE
```

**実行層の定義**: **L1** = `.md` のみ・`PLANGATE_HOOK_TASK` 不要 / **L2** = `.py` / `.sh` を書く
（`PLANGATE_HOOK_TASK` セッションが要る）/ **L3** = HO 対象パス（AI は patch 提示まで・適用は Human）/
**LH** = Human の設計判断が先。

---

## 1. 分類サマリ

対象は `gh issue list --state open --label bug --limit 100` の **41 件**
（既存の統合実行計画は 39 件。`#1196` / `#1197` が後から起票されている — §7 S-5）。

| 分類 | 定義 | 件数 | issue |
|---|---|---:|---|
| **P0 — 配布物が機能しない** | 導入先で動かない / 誤った情報が届く。Plugin をメインにするなら先に直さないと出せない | **7** | #1144 / #1151 / #1057 / #963 / #954 / #982 / #1081 |
| **P1 — 配布物の品質** | 動くが解決できない参照・stale な記述・junk が届く | **4** | #1196 / #978 / #863 / #960 |
| **P2 — 上流のみ** | 上流リポジトリの開発体験の問題。今日の配布物には影響しない | **25** | §4 |
| **P3 — 判断待ち** | consumer 可視の欠陥が無く、Human の設計判断だけが残っている | **5** | #956 / #1086 / #1018 / #984 / #866 |

**合計 41。**

> **P3 の読み方に注意**: P0 の 7 件も本文で案 A/B/C を提示しており Human 判断を要する（§5 の「判断」列）。
> P3 に置いたのは **「判断が付くまで consumer 側で何も直せない」もの**だけである。
> P0 は「判断が付けば即座に consumer 側の症状が消えるもの」なので、判断待ちを理由に後回しにしてはならない。

---

## 2. P0 — 配布物が機能しない（7 件）

各行の「導入先で何が起きるか」は **利用者側の症状**で書いた（上流での症状ではない）。

### P0-1. #1144 — enforcement 層（hook 17 本）が 3 経路すべてで 1 件も配布されていない

**導入先で何が起きるか**: PlanGate を install した利用者は skill と agent は手に入るが、
**C-3 未承認の編集も HO パスの編集も plan.md 不在の編集も 1 つも止まらない**。
ゲートは「モデルが読めば従うかもしれない文章」でしかなく、決定論的な強制力は 0。

**実測**:

```text
$ git ls-tree -r origin/main plugin/plangate/hooks/
  100644 blob e69de29...  plugin/plangate/hooks/.gitkeep     # 空ファイル 1 個のみ

$ git ls-tree -r --name-only origin/main plugin/ | grep -i hook
  plugin/plangate/hooks/.gitkeep                              # hooks.json は存在しない

$ git show origin/main:.claude/settings.example.json | grep -oE '"command": "[^"]*"' | sort -u
  10 本すべてが ${CLAUDE_PROJECT_DIR}/scripts/... を指す（うち 7 本は scripts/hooks/）
  → いずれも配布先に存在しないパス

$ git grep -l 'CLAUDE_PLUGIN_ROOT' origin/main -- scripts/hooks/     # → 0 件 (rc=1)
$ git grep -l 'REPO_ROOT' origin/main -- scripts/hooks/              # → 17 件（陽性コントロール）
$ git grep -hn 'ROOT=' origin/main -- scripts/hooks/
  17/17 が REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
```

**補足（誤解を避けるため）**: `plugin/plangate/README.md` は
「`plugin/plangate/hooks/` は現バージョンでは **reserved（未実装）**」「EH-1/2/3/6/9 を使うには手動設定が必要」
と **明示的に開示している**（L201・L315-324・L451）。つまり false claim ではなく **既知の未実装**である。
ただし同じ README の L324 が案内する詳細先は `[docs/ai/settings-wiring-contract.md](../../docs/ai/settings-wiring-contract.md)` で、
**この相対パスは plugin 導入先では解決しない**（`plugin/plangate/` に `docs/` は無い）。
→ 「hook を自分で配線しろ、詳細はここ」と言われた先が届かない、という二重の詰み。

---

### P0-2. #1151 — settings.example.json が上流メンテナ個人の GitHub アカウント名を SessionStart に配線

**導入先で何が起きるか**: hook 配線の雛形を採用した利用者は、**毎セッション開始時に
「あなたは `s977043` にログインしていない」というエラーを出され、gh の active account を
上流メンテナのアカウントへ切り替えようとされる**。

**実測**:

```text
$ git show origin/main:.claude/settings.example.json  → SessionStart / matcher なし
  "command": "sh ${CLAUDE_PROJECT_DIR}/scripts/gh-pin-account.sh"

$ git show origin/main:scripts/gh-pin-account.sh | grep -n 's977043'
   2: # gh-pin-account.sh — plangate 作業時に gh CLI active account を s977043 に固定
   9: #   sh scripts/gh-pin-account.sh                      # デフォルト: s977043
  21: DESIRED_USER=${PLANGATE_GH_USER:-s977043}
  42: printf 'gh-pin-account: %s is not in `gh auth status` (run: gh auth login -u %s)\n' ...
```

**今日は届いていない**（`settings.example.json` は 3 経路のいずれでも配布されない）。
**#1144 がこれをそのまま配り始めた瞬間に全 consumer が踏む。** → §3 の唯一の双方向依存。

---

### P0-3. #1057 — Marketplace で `bin/plangate` が配布されず、`${CLAUDE_PLUGIN_ROOT}` も Bash で解決できない

**導入先で何が起きるか**: 配布された 13 個の artifact が `bin/plangate ...` の実行を指示するが、
**その実行ファイルはどこにも無い**。skill を呼んだ利用者はコマンド not found を見るか、
モデルがコマンドを捏造した出力を見る。

**実測**（`bin/plangate` を字義どおり呼ぶ配布物 = 13 ファイル）:

```text
$ git ls-tree --name-only origin/main bin/          → bin/plangate （リポジトリには在る）
$ git ls-tree -r --name-only origin/main plugin/ | grep 'bin/'   → 0 件 (rc=1)

$ git grep -l 'bin/plangate\|`plangate ' origin/main \
    -- 'plugin/plangate/skills/*/SKILL.md' 'plugin/plangate/commands/*.md' 'plugin/plangate/agents/*.md'
  agents/setup-coordinator.md          agents/workflow-conductor.md
  commands/plangate-setup.md           skills/ai-dev-exec/SKILL.md
  skills/ai-dev-plan/SKILL.md          skills/ai-dev-verify/SKILL.md
  skills/ai-loop-cycle/SKILL.md        skills/intent-classifier/SKILL.md
  skills/local-exec-handoff/SKILL.md   skills/plan-review-gate/SKILL.md
  skills/plangate-setup/SKILL.md       skills/skill-policy-router/SKILL.md
  skills/working-context/SKILL.md
```

---

### P0-4. #963 — 5 つの配布 skill が、リポジトリのどこにも存在しない rules を「正本」として参照している

**導入先で何が起きるか**: `design-gate` / `pr-decision` / `subagent-dispatch` / `subagent-team-design` /
`context-packager` を起動した利用者に対し、AI は
**「判定基準の正本は `review-gate.md` を見よ」と言うが、そのファイルはどの導入経路にも、
そもそも上流リポジトリにも存在しない**。AI は skill 本文の要約だけで判定を自走する。

**実測**（8 参照 / 5 skill / 参照先 6 ファイルはリポジトリ全体で 0 件）:

```text
$ git grep -no 'design-gate\.md\|evidence-ledger\.md\|review-gate\.md\|subagent-roles\.md\
                \|worktree-policy\.md\|completion-gate\.md' origin/main -- 'plugin/plangate/skills/'
  skills/context-packager/SKILL.md:104:      subagent-roles.md
  skills/design-gate/SKILL.md:176:          design-gate.md
  skills/pr-decision/SKILL.md:232:          completion-gate.md
  skills/pr-decision/SKILL.md:233:          evidence-ledger.md
  skills/pr-decision/SKILL.md:234:          review-gate.md
  skills/subagent-dispatch/SKILL.md:113:    subagent-roles.md
  skills/subagent-dispatch/SKILL.md:113:    completion-gate.md
  skills/subagent-team-design/SKILL.md:33:  subagent-roles.md

$ git ls-tree -r --name-only origin/main | grep -E '(completion-gate|subagent-roles|worktree-policy)\.md'
  → 0 件 (rc=1)

$ git ls-tree --name-only origin/main plugin/plangate/rules/
  hybrid-architecture.md  mode-classification.md  orchestrator-mode.md
  responsibility-classes.md  review-principles.md  working-context.md      # 6 本のみ
```

**なお `.claude/rules/*.md` として参照される 6 本は 6/6 が `plugin/plangate/rules/` に実在する**
（`working-context` 38 参照 / `mode-classification` 34 / `review-principles` 13 /
`responsibility-classes` 10 / `hybrid-architecture` 10 / `orchestrator-mode` 2）。
壊れているのは **#963 が挙げる別の 6 本**だけである。

---

### P0-5. #954（残） — 11 の配布 skill が、届かない `docs/**` を注記なしで参照している

**導入先で何が起きるか**: `docs/workflows/02_requirement_expansion.md` などを「読め」と指示されるが、
**plugin には `docs/` ディレクトリが 1 つも無い**。#1195 で 24 skill には「参照解決順」の注記が入ったが、
**残る 11 skill は注記が無く、AI は参照先が届かないことにすら気づかない**。

**実測**:

```text
$ git grep -l 'docs/' origin/main -- 'plugin/plangate/skills/*/SKILL.md' | wc -l   → 34
$ git grep -l '解決順' origin/main -- 'plugin/plangate/skills/*/SKILL.md' | wc -l  → 24
$ comm -23 <docs参照あり> <注記あり>
  acceptance-criteria-build  architecture-sketch  context-load  edgecase-enumeration
  feature-implement  known-issues-log  nonfunctional-check  pr-decision
  ref-integrity-scan  requirement-gap-scan  risk-assessment              # 11 件

# 11 件が参照している docs（全数）
  docs/workflows/01_context_bootstrap.md     docs/workflows/02_requirement_expansion.md (5)
  docs/workflows/03_solution_design.md (2)   docs/workflows/04_build_and_refine.md
  docs/workflows/05_verify_and_handoff.md (2)  docs/ai/skill-collision-detection.md
  docs/working/  docs/  docs/*
```

**注記の配布状況（4 root 比較）**: plugin 24 / `.agents` 24 / `.codex` 13 / `.claude` 9。

---

### P0-6. #982 — 存在しない CLI サブコマンド `plangate ai-loop run` を 5 つの配布ファイルが案内している

**導入先で何が起きるか**: ai-loop の「Plan-first 正式入口」として案内されたコマンドを叩くと **必ず失敗する**。
`bin/plangate` を PATH に通した利用者ですら（= #1057 を回避しても）失敗する。

**実測**:

```text
$ git show origin/main:bin/plangate | grep -nE '^  [a-z][a-z0-9-]*\)'      # dispatch 23 件
  init brainstorm plan gate verify handoff doctor status validate validate-schemas
  eval metrics plan-check report context keep-rate review exec abort timeline
  resume maintenance render approve
  → ai-loop は無い

$ git grep -n 'ai-loop' origin/main -- bin/plangate
  887: # scripts/ai-loop/c3prime_verify.py で Plan Package 束縛を全数再検証する   （コメント）
  894:   _c3d_verify="$plangate_root/scripts/ai-loop/c3prime_verify.py"          （未配布パス）

$ git grep -c 'ai-loop run' origin/main -- 'plugin/plangate/'
  skills/ai-loop-cycle/SKILL.md:1                        skills/.../execution-runbook.md:2
  skills/.../loopspec.md:2                               skills/.../run-evidence-contract.md:1
  skills/ai-loop-cycle/schemas/run-evidence.schema.json:2
```

---

### P0-7. #1081 — junk が model 可視一覧に露出し、`commands/` と `skills/` で名前が 3 件衝突している

**導入先で何が起きるか**: 利用者の skill / agent 一覧に **`README` という名前の skill と agent が出る**。
`codex-mvp-split` / `plangate-setup` / `working-context` は skill と command の両方に同名で存在し、
どちらが起動されるかが利用者から見て不定になる。

**実測**:

```text
$ git ls-tree --name-only origin/main plugin/plangate/skills/    → 40 件（うち README.md）
$ git ls-tree --name-only origin/main plugin/plangate/agents/    → 18 件（うち README.md）
$ git ls-tree --name-only origin/main plugin/plangate/commands/  → 6 件（うち README.md）

衝突（commands ∩ skills）: codex-mvp-split / plangate-setup / working-context   → 3 件
junk: skills/README.md, agents/README.md, commands/README.md                    → 3 件

# install.sh 経路も同じ junk を配る（top-level entry を無条件に cp -r）
$ git show origin/main:install.sh | sed -n '105,128p'
  105: for dir in agents skills commands rules; do
  110:   for f in "$src"/*; do                # README.md も対象
  127:     cp -r "$f" "$dst/$base"
```

**本セッションの実環境での観測（一次証跡ではあるが 1 環境のみ・要 runtime 再測定）**:
`plangate` plugin から **`plangate:README` が agent 一覧に登録されている**ことを確認した。
一方、`growth-core:` / `river-review:` / `codex:` は slash command を列挙しているのに対し、
**`plangate:` の slash command は 1 件も列挙されていない**。
これは #1081 の前提（「commands/*.md が Skills として登録され」）と **逆向きの症状**であり、
新規 issue 候補 N-1 として §6 に分離した。

**#1081 の記述のうち 1 点は既に解消**: `plangate-setup` の frontmatter は
`description: "..."` と quote 済み（§7 S-3）。

---

## 3. P0 の依存関係

### 3-1. 双方向に言及し合っているペア（= 依存と呼べるもの）

issue 本文の相互参照を全数照合した結果、**双方向の言及は 1 組しかない**。

| ペア | #A → #B | #B → #A | 判定 |
|---|---|---|---|
| **#1144 ↔ #1151** | #1144 本文が `scripts/gh-pin-account.sh` と `#1151` を挙げる | #1151 本文が `#1144（発見元）` を挙げる | **双方向 ✔ = 依存** |
| #1144 → #1057 | #1144 本文が「#1057（同クラス）」 | #1057 本文は他 issue を 1 件も挙げない（`claims_fixed_by: none named`） | **片方向 ✘ = 依存と呼ばない** |
| #963 → #954 | #963 本文が「#954（同方向で進行中）」 | #954 本文は #863 / #943 / #771 / #790 のみ | **片方向 ✘** |
| #1196 → #954 | #1196 本文が「#954（親）」 | #954 は #1196 起票前 | **片方向 ✘** |
| #954 → #863 | #954 本文が「#863（クラス B を担当・相互排他）」 | #863 本文は #860 / #842 / #862 のみ | **片方向 ✘（ただし #954 側が「相互排他」と宣言）** |
| #1170 → #956 | #1170 本文が「#956 の判断待ち」と自己 deferred 宣言 | #956 は #1170 起票前 | **片方向 ✘** |

**結論**: **#1151 を #1144 より先に（または同時に）解く。**
これが「先に解くと他が解ける」唯一の、双方向で裏の取れた依存である。
理由は方向性が非対称だからである — #1144 は「hook を配る仕組み」を作る PBI であり、
その **配る中身**が `settings.example.json` + `scripts/gh-pin-account.sh`。
順序を逆にすると、#1144 のマージ時点で全 consumer が他人の gh アカウントを pin される。

### 3-2. 依存ではないが、同じ 1 つの決定に従属するもの（実測ベース）

「片方向の言及」を依存と数えない代わりに、**同じファイルを触る / 同じ設計判断を待っている**関係を
機械的に測った。

**共有ファイル行列**（各 issue 本文が挙げるファイル ∩ 実測で存在するもの）:

| ファイル | 触る P0/P1 issue |
|---|---|
| `plugin/plangate/.claude-plugin/plugin.json` | **#1144** / **#1081** |
| `plugin/plangate/hooks/` | **#1144** / **#1081** / **#1057** |
| `.claude/settings.example.json` | **#1144** / **#1151** / #984 / #975 |
| `bin/plangate` | **#1057** / **#982** / #863 / #1105 / #1101 / #1197 |
| `plugin/plangate/skills/*/SKILL.md` | **#954** / **#963** / **#1081** / **#1057** / #863 / #866 |

**1 つ解けば連鎖する設計判断**:

> **「plugin は実行可能物（hook スクリプト / CLI）をどう配り、配布先で自分の root をどう解決するか」**

- #1144 本文は「残る設計分岐は root 解決をどう直すか」と自ら述べている。
- #1057 本文は `${CLAUDE_PLUGIN_ROOT}` が素の Bash で空展開する、と同じ層を指している。
- 実測: `scripts/hooks/*.sh` は 17/17 が `$0` ベースで `../..` を repo root と仮定しており、
  `CLAUDE_PLUGIN_ROOT` の参照は **0 本**（陽性コントロール: `REPO_ROOT` は 17 本ヒット）。

この 1 決定が付けば **#1144 / #1057 / #982 の案 A（CLI 同梱）/ #863** が同時に着手可能になる。
**逆に、この決定が付かないうちに個別の `.md` 表記だけ直しても、根本の「実行ファイルが無い」は動かない。**

### 3-3. P0 に見えて P0 でないもの（配り始めるまで届かない）

hook 層の欠陥 **#1104 / #1101 / #1105 / #984 / #975 / #937 / #1197** は、
**hook が 1 本も配布されていない今日、consumer には一切届いていない**。
今日は P2 だが、**#1144 が配り始めた瞬間にそのまま欠陥ごと配布される**。

実測で確認した #1104 の中身（`settings.example.json` の matcher 全数）:

```text
SessionStart  (matcher なし)     gh-pin-account.sh                     ← #1151
PreToolUse    Edit|Write         check-plan-exists.sh                  ← Bash 迂回可
PreToolUse    Edit|Write         check-c3-approval.sh                  ← Bash 迂回可
PreToolUse    Edit|Write         check-plan-hash.sh $TASK $FILE        ← Bash 迂回可
PreToolUse    Edit|Write         check-forbidden-files.sh              ← Bash 迂回可
PreToolUse    Bash               check-delegation-commit-boundary.sh
PreToolUse    Edit|Write         check-approval-token-write.sh
PreToolUse    Bash               check-approval-token-write.sh
PreToolUse    Bash               check-git-destructive.sh
PostToolUse   Edit|Write|MultiEdit  check-post-edit-diff.sh            ← Bash 迂回可
Stop          (matcher なし)     check-stop-diff-status.sh
```

→ #1104 の「5 本が `Edit|Write` のみ」は `e52118b` で **そのとおり**（上記の 5 行）。

**推奨**: #1144 の配布対象を確定するときに、**#1104 / #1151 / #984 を同じ PBI の受入基準に含める**。
「壊れた enforcement を正しく配る」ことに価値は無い。

---

## 4. P2 — 上流のみ（25 件）

**consumer の配布物に影響しない**ことを、issue が挙げる対象ファイルと §0-1 の配布表の突合で判定した。

### 4-1. テスト / CI harness（16 件） — 配布物に一切含まれない

`#1178` `#1180` `#1165` `#1162` `#1044` `#1021` `#1011` `#1010` `#1009` `#1004` `#997` `#994` `#991` `#990` `#947` `#942` `#921`

対象は `tests/extras/**` / `tests/run-tests.sh` / `.github/workflows/**` / `scripts/sync-plugin-plangate.sh` /
`scripts/release-prep.sh`。**`plugin/plangate/` にも `<project>/.claude/` にも入らない。**
（`#1162` `#1165` `#997` は `scripts/ai-loop/*.py` にも触れるが、これらは
`plugin/plangate/skills/ai-loop-cycle/scripts/` へ同梱されるため §4-3 に併記。）

### 4-2. hook 層（7 件） — 今日は届かないが #1144 の payload

`#1104` `#1101` `#1105` `#984` `#975` `#937` `#1197`

→ §3-3。**#1144 と同時に扱うこと。単独で「後回し」にすると #1144 が欠陥を配る。**

### 4-3. `.codex/skills` drift（2 件） — consumer は plugin から再生成するので届かない

`#956` `#1170`（`#1086` は P3）

**実測による再優先付けの根拠**:

```text
consumer の .codex/skills/ の生成元:
  plugin/plangate/scripts/install-plangate-skills.sh:10
    SKILLS_SRC="${PLANGATE_SKILLS_DIR:-$PLUGIN_DIR/skills}"

plugin/plangate/skills == .agents/skills （SKILL.md 40/40 一致・§0-3）

→ consumer が Codex 経路で受け取る skill 内容は「正本と一致した内容」であり、
   リポジトリに commit 済みの .codex/skills/ の 33 件 drift は consumer に届かない。
```

**ただし CI 検出機構が無いのは事実**（`git grep -l '\.codex' origin/main -- .github/workflows/` → **0 件**。
陽性コントロール: `plugin` は 1 件ヒット = `sync-plugin-plangate.yml`）。
そして drift は **上流が是正するたびに増える**: 統合実行計画（base `684949e`）の時点で
SKILL.md drift 32/39、`e52118b`（#1195 適用後）で **33/39**（§7 S-2）。
これは上流の開発体験の劣化であり、consumer 影響ではない。

---

## 5. P1 — 配布物の品質（4 件）

| # | 導入先で何が起きるか | 実行層 | 規模 |
|---|---|---|---|
| **#1196** | 配布された ai-loop reference を読むと、参照先が **裸のファイル名だけ**になっており、上流のどこを見ればよいかが分からない | L2（`scripts/_ai_loop_link_rewrite.py` は `.py` = rc=2）+ L1（再生成物） | 中 |
| **#978** | 導入先が `ho-paths.md` を置き忘れると **plugin 同梱の plangate 用雛形（21 パターン）が読まれ**、priority 0 の fail-closed が発火せず、**導入先の HO が無保護のまま auto-approve 経路に乗る** | L2（`scripts/ai-loop/arbiter.py`）+ LH（案 A/B/C 未決） | 中 |
| **#863** | README の CLI 依存列挙が 7 個で実測と不一致。PATH を通しても skill 本文が `bin/plangate` 相対形式なので字義実行が失敗する | L1（`.md`）+ L3（HO 4 件） | 小 |
| **#960** | 配布される rules / agents / commands が **C-1 を「17 項目」と宣言**するが実体は 25。導入先の運用者が何項目やればよいか判断できない | L1 + L3（`.claude/rules/*.md` は HO） | 中〜大（15 系統） |

**#1196 の実測**（配布バンドル内で、脱リンクされて裸のファイル名になっている参照）:

```text
$ git ls-tree --name-only origin/main plugin/plangate/skills/ai-loop-cycle/references/   → 23 ファイル

$ git grep -ho '`[a-z0-9-]*\.md`' origin/main -- 'plugin/plangate/skills/ai-loop-cycle/references/*'

  バンドル外 = 到達手段が無い:
    responsibility-classes.md 21   working-context.md 13   mode-classification.md 12
    plan-review-readiness-gate.md 7   review-principles.md 6   phase3-impact-report.md 6
    orchestrator-mode.md 6   asset-inventory.md 5   run-001-frictions.md 4
    review-external.md 4
```

うち `responsibility-classes.md` / `working-context.md` / `mode-classification.md` /
`review-principles.md` / `orchestrator-mode.md` は **`plugin/plangate/rules/` に実在する**
（= 利用者は持っているのにパスが無いので辿れない）。
`plan-review-readiness-gate.md` / `phase3-impact-report.md` / `asset-inventory.md` /
`run-001-frictions.md` は **真に到達不能**。

**#978 は #1057 が解けた時点で P0 に昇格する**（今日は CLI が届かないので ai-loop 自体が導入先で走らない）。

---

## 6. 新規 issue 候補（Plugin メインに必要だが、どの既存 issue でもカバーされていない）

> **起票はしていない。** 以下は候補の提示のみ。

### 判定表 — 指示された 6 項目が既存 issue でカバーされるか

| 項目 | カバーする issue | 判定 |
|---|---|---|
| hook が 1 件も配布されていない | **#1144** | ✅ カバー（本文が 3 経路 × 17 本を全数で述べている） |
| `bin/plangate` が marketplace で配布されない | **#1057** | ✅ カバー |
| `commands/*.md` が Skills として登録され名前衝突 | **#1081** | ⚠️ **部分**（junk 3 + 衝突 3 は正確。ただし実環境で観測した症状は逆向き → **N-1**） |
| `.codex/skills` の drift | **#956 / #1170** | ✅ カバー（ただし consumer 影響は無い → §4-3） |
| リンク変換で上流パスが消える | **#1196** | ✅ カバー |
| 導入先で `docs/**` が解決できない | **#954** | ⚠️ **部分**（残 11 skill は #954 の射程内。ただし「注記」方式は参照先を届けない → **N-3**） |

### N-1（候補）— plugin の commands / agents / hooks が manifest で宣言されておらず、実際の登録結果が未検証

```text
$ git show origin/main:plugin/plangate/.claude-plugin/plugin.json
  "skills": "./skills/"          ← 宣言はこれ 1 つだけ
  （commands / agents / hooks のキーは無い）

$ git show origin/main:plugin/plangate/.codex-plugin/plugin.json
  "skills": "./skills/"          ← 同上
```

本セッションの実環境では `plangate:` の **agent は 18 件登録されている**（`plangate:README` を含む）が、
**slash command は 1 件も列挙されていない**（同一環境で `growth-core:` / `river-review:` / `codex:` は列挙される）。
`plugin/plangate/commands/` の 5 本（`ai-dev-workflow` / `ai-loop-workflow` / `codex-mvp-split` /
`plangate-setup` / `working-context`）が **届いていない可能性**がある。

- #1081 は「commands が **Skills として登録され**て一覧が水増しされる」という **逆の症状**を前提にしている。
- どちらが正しいかは **runtime 実測（`claude plugin details plangate@plangate` の Component inventory）**
  でしか決着しない。**未確認**。
- 「Plugin をメインにする」なら、**`plugin.json` が何を宣言し、harness が実際に何を登録したかを
  照合する検査**が要る。既存 issue には無い。

### N-2（候補）— CI が「上流との content 一致」しか測っておらず、consumer 位置からの機能検証が 0 件

```text
$ git grep -l 'plugin' origin/main -- .github/workflows/     → sync-plugin-plangate.yml のみ（1 件）
$ git show origin/main:.github/workflows/sync-plugin-plangate.yml
  drift-check:  sh scripts/sync-plugin-plangate.sh && git diff --quiet -- plugin/plangate/
```

このゲートが保証するのは **`plugin/plangate/` == 正本** だけである。
**正本自身が「届かない `docs/**` を参照している」場合、drift は 0 のまま欠陥が配布される。**
実際、§2 の P0-3 / P0-4 / P0-5 / P0-6 は **すべて drift 0 の状態で成立している**。

必要なのは「plugin ディレクトリを consumer の位置に置いたとき、
(a) 相対参照が解決するか (b) 指示されたコマンドが存在するか (c) 宣言した component が登録されるか」
を測るゲート。**#1196 が同型の指摘を link 変換 1 点に限って述べているが、
配布物全体に対する consumer-position 検証は既存 issue に無い。**

### N-3（候補）— `docs/**` を plugin に同梱するか否かの判断が未起票

```text
git ls-tree origin/main plugin/plangate/
  → docs/ ディレクトリは存在しない

git grep -l 'docs/' origin/main -- 'plugin/plangate/skills/*/SKILL.md' | wc -l
  → 34（分母 40）
```

`#954` の是正方式は **「参照解決順の注記を書く」**であり、**参照先そのものは届かない**。
34/40 の配布 skill が届かない `docs/` を参照する状態は、注記を 40/40 に広げても解消しない。

`plugin/plangate/skills/ai-loop-cycle/references/` には既に **23 ファイルの docs が bundle されている**
（= 同梱する仕組みは存在する）。`docs/workflows/0N_*.md`（6 本）を同様に bundle するかどうかは
**設計判断であり、どの issue でも議論されていない**。#954 本文は「クラス C を bundled references 方式にするか、
A と同じフォールバック明記にするか」を **クラス単位**で述べるが、**`docs/workflows/` の同梱は射程外**。

---

## 7. 既存資料の記述で stale だったもの

| ID | 既存資料の記述 | `e52118b` の実測 | 影響 |
|---|---|---|---|
| **S-1** | `#866` = 「intent-classifier / skill-policy-router の正本宣言が三つ巴で矛盾（`.claude/skills`=新版・`.agents/skills`&`plugin`=旧版）」 | `git diff origin/main:.claude/skills/intent-classifier/SKILL.md origin/main:plugin/plangate/skills/intent-classifier/SKILL.md` → **rc=0（差分なし）**。`skill-policy-router` も同じく差分なし。3 root すべてが「Intent 8 分類」で `exploratory` を含む | **症状は解消済み。** 既存資料の CLOSE-AFTER-1 判定は方向として正しいが、「三つ巴で矛盾」という現況記述はもう成り立たない。本レポートでは P3 に置いた |
| **S-2** | 統合実行計画 §0-2 D-1: `.codex` drift = 「33 / 42（うち SKILL.md **32 / 39**）」（base `684949e`） | `git diff --stat origin/main:.codex/skills origin/main:plugin/plangate/skills -- '*/SKILL.md'` → **33 files changed**（分母 39） | **+1。** #1195 が plugin / `.agents` 側 20 件へ注記を足し `.codex` が追従していないため。**上流の是正 1 本ごとに drift が増える構造**を数値で確認 |
| **S-3** | `#1081` = 「+ `plangate-setup` の frontmatter unquoted」 | `git show origin/main:plugin/plangate/skills/plangate-setup/SKILL.md \| head -8` → `description: "PlanGate 初期セットアップを…"` と **quote 済み** | #1081 の 3 症状のうち 1 つは解消済み。残るのは junk 3 + 衝突 3 |
| **S-4** | 統合実行計画 §0-2 D-4: `#954` の梯子保有は `.agents/skills` **19 / 22** | 4 root の注記保有: plugin **24 / 40** / `.agents` **24 / 40** / `.codex` **13 / 39** / `.claude` **9 / 30**。`docs/` を参照しつつ注記が無い plugin skill = **11 件**（§2 P0-5 に全数列挙） | 統合実行計画の base は #1195 **前**。#954 の残件は「22 中 3 残」ではなく「**34 中 11 残**」（分母が `docs/` 参照ベースに変わった） |
| **S-5** | 統合実行計画の対象集合 = **39 件** | `gh issue list --state open --label bug --limit 100` → **41 件**。追加は **#1196**（リンク変換）/ **#1197**（ai-loop の Human 決定が実行不能） | 統合実行計画は #1196 / #1197 を扱っていない。本レポートは 41 件を対象にした |

**stale ではないが、既存資料と結論が変わった点（優先度の再定義）**:

既存 3 レポートは `#956` / `#1086` / `#1170`（`.codex` 系）を **LH / BLOCKED** として上位の
判断待ちに置いていた。本レポートは §4-3 の実測（consumer の `.codex/skills` は plugin から再生成される）に基づき
**P2（上流のみ）へ降格**した。これは規模・独立性の軸と plugin-first の軸で結論が割れる代表例である。

---

## 8. スコープ外で見つけた問題（手を出していない・報告のみ）

| ID | 内容 | 実測 | 起票有無 |
|---|---|---|---|
| **O-1** | 上流リポジトリ自身の `.claude/commands/README.md` が slash command として登録されている（本セッションの実環境で `README: Slash Commands` を観測）。#1081 と同型の junk が **plugin 側だけでなく上流の `.claude/` 側にもある** | 実環境観測（1 環境） | **未確認** |
| **O-2** | `.claude/skills/`（30）と `.agents/skills/`（40）は **別集合**で、plugin へ配られるのは `.agents/skills/` のみ。`.claude/skills/` にしか無い 5 skill — `hypothesis-logger` / `plan-quality-check` / `plan-quality-reviewer` / `plangate-working-discipline` / `pr-watch` — は **どの導入経路でも配布されない** | `comm` による名前集合差分（§0-3 のコマンド形） | **未確認**（#866 は 2 skill の内容差分のみを扱い、集合差分は扱っていない） |
| **O-3** | `plugin/plangate/README.md` L324 が hook 配線の詳細先として案内する `../../docs/ai/settings-wiring-contract.md` は、**plugin 導入先では解決しない相対パス**。#1144 の「手動配線しろ」という唯一の逃げ道が導入先で切れている | `git ls-tree origin/main plugin/plangate/` に `docs/` 無し | **#1144 / #954 の隙間**（どちらの本文にも README L324 は挙がっていない） |
| **O-4** | `plugin/plangate/skills/ai-loop-cycle/scripts/` に `.py` が同梱されており（`arbiter.py` / `plan_package.py` ほか）、これらは `bin/plangate` を参照する。#1169 の `sh` 誤起動ガード（`PG-SH-GUARD`）が **配布された `.py` 側にも入っているか**は未測定 | 未測定 | **未確認** |

---

## 9. 推奨着手順

**P0 → P1 の順。各項目は「これを直すと導入先で何が変わるか」で並べた。**

| 順 | # | 対象ファイル（実測した集合） | 実行層 | 規模 | これを直すと導入先で何が変わるか |
|---:|---|---|---|---|---|
| **1** | **#1151** | `.claude/settings.example.json`（SessionStart ブロック 1 つ）/ `scripts/gh-pin-account.sh`（L21 の既定値・L42 のメッセージ） | **L3**（`.claude/settings*.json` は HO。patch は AI・適用は Human） | **小**（2 ファイル / 数行） | **#1144 が配り始める前に、他人の gh アカウントを pin する雛形を潰す。** これ単体では導入先の見た目は変わらない（今日は届いていない）が、**§3-1 の唯一の双方向依存なので順序は動かせない** |
| **2** | **#1144** | `plugin/plangate/hooks/`（`.gitkeep` のみ）/ `plugin/plangate/.claude-plugin/plugin.json` / `scripts/hooks/*.sh`（**17/17** が `$0` ベース root 解決）/ `.claude/settings.example.json`（10 配線）/ `install.sh`(L105) / `plugin/plangate/README.md`(L201,L315-324,L451) | **L3**（`scripts/hooks/*.sh` / `settings*.json` が HO）+ **LH**（案 A/B/C と root 解決方式が未決） | **大** | **enforcement が 0% → 実配布になる。** 導入先の利用者が初めて「C-3 未承認の編集が実際に止まる」PlanGate を手にする。**#1104 / #984 を同じ受入基準に入れること**（§3-3。壊れた enforcement を正しく配っても意味が無い） |
| **3** | **#1057** | `bin/plangate`（同梱判断）+ 表記是正 **13 ファイル**: `agents/{setup-coordinator,workflow-conductor}.md` / `commands/plangate-setup.md` / `skills/{ai-dev-exec,ai-dev-plan,ai-dev-verify,ai-loop-cycle,intent-classifier,local-exec-handoff,plan-review-gate,plangate-setup,skill-policy-router,working-context}/SKILL.md` | **分割推奨**: 表記是正のみ **L1**（正本 `.agents/skills/**.md` は rc=0）/ CLI 同梱は **L3+LH** | 表記 **小** / 同梱 **中** | **13 個の skill が「実行できない指示」を出さなくなる。** L1 部分（PATH 解決形式への統一 + degrade 明記）だけ先行すれば、CLI 同梱の設計判断を待たずに **今日から導入先の失敗が減る**。#863 と同一ファイル群なので**併合を推奨** |
| **4** | **#963** | `plugin/plangate/skills/{context-packager,design-gate,pr-decision,subagent-dispatch,subagent-team-design}/SKILL.md`（**8 参照**）/ 正本 `.agents/skills/` の同 5 本 / 復元候補 `rules/{completion-gate,design-gate,evidence-ledger,review-gate,subagent-roles,worktree-policy}.md`（**リポジトリ全体で 0 件**） | **L1**（正本 `.agents/skills/**.md` = rc=0）+ **LH**（案 A 復元 / B 参照差し替え+inline / C 部分復元） | **小〜中**（8 参照 / 5 skill。案 A なら 6 ファイル復元） | **「正本は X を見よ」と言われて X が存在しない、という状態が消える。** 5 つの gate 系 skill が判定基準を持てるようになる |
| **5** | **#954（残 11）** | `plugin/plangate/skills/{acceptance-criteria-build,architecture-sketch,context-load,edgecase-enumeration,feature-implement,known-issues-log,nonfunctional-check,pr-decision,ref-integrity-scan,requirement-gap-scan,risk-assessment}/SKILL.md` + 正本 `.agents/skills/` の同 11 本 | **L1**（rc=0） | **小**（11 ファイル / 各 1 ブロック追記） | **注記保有が 24/40 → 35/40 になり、AI が「参照先が届かない」ことを自覚したうえで判定を明示する。** ただし **参照先そのものは届かない**（→ N-3 の同梱判断が別途要る） |
| 6 | **#982** | `bin/plangate`（dispatch 23 件に `ai-loop` 無し）/ 配布側 5 ファイル: `skills/ai-loop-cycle/SKILL.md` / `references/{execution-runbook,loopspec,run-evidence-contract}.md` / `schemas/run-evidence.schema.json` | **L3**（案 A = `bin/plangate` = HO）/ **L1**（案 B = 記述側を実在コマンドへ） | 小 | 存在しないコマンドの案内が消える。**#1057 の CLI 同梱決定と同時に裁定するのが自然**（片方だけ直しても導入先では動かない） |
| 7 | **#1081** | `plugin/plangate/{skills,agents,commands}/README.md`（junk 3）/ `plugin/plangate/.claude-plugin/plugin.json` / 衝突 3 名（`codex-mvp-split` / `plangate-setup` / `working-context`） | **要実測**（`plugin.json` は `.md` でも HO 9 カテゴリでもない → EH-3 の rc **未確認**）+ **LH**（案 a/b/c） | 小 | 利用者の一覧から `README` skill / `README` agent が消える。**N-1 の runtime 実測を先に済ませること**（症状の向きが未確定） |
| 8 | **#1196** | `scripts/_ai_loop_link_rewrite.py` / 再生成される `plugin/plangate/skills/ai-loop-cycle/references/**`（23 ファイル） | **L2**（`.py` = rc=2）+ **LH**（案 A/B） | 中 | 配布 reference の裸ファイル名（到達不能 4 種 / 位置不明 6 種）が解決手がかりを取り戻す |
| 9 | **#863** | `plugin/plangate/README.md`(L36) / CLI 依存 skill（#1057 と同一集合） | **L1** + **L3**（HO 4 件） | 小 | **#1057 の L1 部分と同一作業。3 と併合すべき** |
| 10 | **#978** | `scripts/ai-loop/arbiter.py`(L177-190) / `plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md`（同梱雛形） | **L2** + **LH** | 中 | 導入先の HO が無保護のまま auto-approve に乗る経路が閉じる。**#1057 が解けた時点で P0 に昇格** |

### 着手順の要点

1. **#1151 → #1144 の順は動かせない**（§3-1 の唯一の双方向依存）。
2. **#1057 / #863 は併合し、L1 部分を先行させる**（設計判断を待たずに導入先の失敗が減る唯一の項目）。
3. **#963 / #954 / #1081 は `.md` のみの L1 で、`PLANGATE_HOOK_TASK` セッションを要さない**
   （正本 `.agents/skills/**.md` は EH-3 rc=0）。**#1144 の設計判断と並行して進められる**。
4. **P2 の 25 件（うちテスト harness 16 件）は、Plugin メインの観点では 1 件も consumer に届かない。**
   既存の統合実行計画が L2 に 22 件を集中させていたのは、この 16 件を含んでいたためである。

---

## 10. 本レポートの限界（未確認事項）

- **N-1（plugin の component 登録結果）は runtime 実測をしていない。** 本セッションの実環境での観測 1 件に基づく
  仮説であり、`claude plugin details plangate@plangate` の Component inventory で裏を取る必要がある。
- **#1081 の実行層（`plugin.json` に対する EH-3 の rc）は未測定。** HO 9 カテゴリにも `plugin/**/*.md` にも
  該当しないため、着手前に実測が要る。
- **O-4（配布 `.py` の `PG-SH-GUARD` 保有）は未測定。** `sh <.py>` を実行しない制約下で
  静的 grep のみでは「ガード実体があるか」を判定できない（#1178 が指摘するのと同じ落とし穴）ため、
  意図的に測っていない。
- **P2 の 25 件は、対象ファイルが配布経路に載らないことを §0-1 の表と突合して判定した。**
  各 issue 本文の主張そのもの（例: 「ta-42 が中断残骸で誤 FAIL する」）は **再現していない**。
  plugin-first の観点では再現の要否が低いと判断したためであり、
  **これらを着手する際は本文の主張を個別に測り直すこと。**
