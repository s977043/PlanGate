# PBI INPUT PACKAGE — TASK-0954

> Issue: [#954](https://github.com/s977043/plangate/issues/954)（bug / area:docs / **priority:P2**）
> 由来: [#943](https://github.com/s977043/plangate/issues/943)（`ai-dev-plan` 単体の報告・CLOSED）の横展開。修正 PR は [#955](https://github.com/s977043/plangate/pull/955)（main `cda229b`）
> 境界: **クラス B（CLI 参照）は [#863](https://github.com/s977043/plangate/issues/863) の担当**（2026-08-02 に issue 本文でスコープ縮小済み）
> 作成: 2026-08-02（**main `cda229b` で実測**。件数は本文の実測表を正とし、issue 本文の数値とは差異がある）

## Context / Why

`.agents/skills/` 配下の skill は「この正本を読め」と宣言するが、そのパスが
**導入先の環境で解決できない**。skill が指した正本を読めないまま AI が自走すると、
判定基準が skill 本文の要約だけになる。plugin（marketplace）経由の導入者からは
「skill が壊れている」のか「そういう運用」なのか区別できず、切り分けコストが高い。

issue #943 は `ai-dev-plan` 1 本についてこれを報告し、PR #955 が **3 経路
（`install.sh --claude` / Claude marketplace / Codex）別の参照解決順**を明記して解決した。
**同型の未解決参照が他の skill に残っている**のが本 PBI。

### 実測による裏取り（main `cda229b`・2026-08-02）

| # | 主張 | 実測方法 | 結果 |
|---|------|---------|------|
| 1 | `.agents/skills/` の skill 総数 | `ls .agents/skills \| wc -l` | **39 エントリ = 38 skill + `README.md`**（issue の「全 38 skill」と一致） |
| 2 | クラス A（rules 参照）の実数は issue の 13 skill ではない | `grep -rlE '\.claude/rules/\|\.\./\.\./rules/' .agents/skills/` | **16 skill / 17 ファイル**（`ai-dev-plan`・`ai-loop-cycle` 除く）。issue 未掲載が 3 skill（下記 #3・#4） |
| 3 | **`skill-creator` が issue の表から漏れている** | `grep -rn '\.claude/rules/' .agents/skills/skill-creator/` | `skill-creator/references/review-default.md:16` に `.claude/rules/review-principles.md` 参照あり。**issue のどのクラスにも記載がない** |
| 4 | **`intent-classifier` / `skill-policy-router` は「クラス B のみ」ではない** | `grep -rn '\.\./\.\./rules/' .agents/skills/` | 両 skill が `../../rules/mode-classification.md` を参照（計 3 箇所）。issue は両者を B 専用として **#863 へ丸ごと移管**しているが、**rules 参照が残るため #954 側にも残留する** |
| 5 | **`../../rules/` 形式は「上流リポジトリでだけ壊れている」逆パターン** | `ls .agents/rules` / `ls .claude/rules` / `ls plugin/plangate/rules` / `ls .codex/rules` | `.agents/rules` **不在** / `.claude/rules` **存在（6 本）** / `plugin/plangate/rules` **存在（6 本）** / `.codex/rules` **不在**。つまり `../../rules/x.md` は **`.claude/` 配置と plugin 配置では解決し、正本 `.agents/` と `.codex/` では解決しない**（`.claude/rules/x.md` 形式とは真逆） |
| 6 | クラス C（上流 `docs/**` 参照）の実数 | `grep -rhoE '(\.\./)*docs/[^ ]+'` を skill 単位で集計（`docs/working/**` 除外） | **16 skill / 17 ファイル**（`ai-dev-plan`・`ai-loop-cycle` 除く）。**issue のクラス C 一覧 16 件と完全一致** |
| 7 | `docs/working/templates/**` 参照が issue のどのクラスにも入っていない | 同上（`docs/working/templates` を含めて再集計） | クラス C が **16 → 22 skill** に増える。新規は `brainstorming` / `context-packager` / `design-gate` / `subagent-dispatch` の 4 skill（他 2 件は既にクラス A で捕捉済）。**templates も配布対象外**（下記 #9）なので解決不能性は `docs/**` と同じ |
| 8 | 対象 skill の総数（A ∪ C・issue の定義） | 上記 A/C の和集合 | **27 skill / 28 ファイル**（issue の「26 skill」とは別集合。差分の内訳は Notes 参照）。`docs/working/templates` を含めると **31 skill** |
| 9 | **marketplace 実環境でクラス A は解決し、クラス C は解決しない** | `ls ~/.claude/plugins/cache/plangate/plangate/8.18.0/{rules,docs,skills}` | `rules/` = **6 本存在**（クラス A は `${CLAUDE_PLUGIN_ROOT}/rules/` で解決可）/ `docs/` = **不在**（クラス C は解決不可）/ `skills/` = 39。**issue の AC-5「marketplace 経由の環境で 1 件以上実測」は実行可能**（キャッシュが手元に実在） |
| 10 | **同一キャッシュに複数バージョンが並存する** | `find ~/.claude/plugins/cache/plangate -maxdepth 3 -type d` | `8.17.1` と `8.18.0` の 2 版が `.in_use` 付きで並存。#955 が `${CLAUDE_PLUGIN_ROOT}` を glob 推測してはならないとした根拠が実環境で再現している |
| 11 | **`ai-loop-cycle` の bundled resources は正本には無い** | `find .agents/skills/ai-loop-cycle -type f` / `find plugin/plangate/skills/ai-loop-cycle -type f` | 正本は **`SKILL.md` 1 本のみ**。`references/` 22 本 + `scripts/` 25 本が存在するのは **`plugin/plangate/skills/ai-loop-cycle/` だけ**で、`scripts/sync-plugin-plangate.sh`（L188-363）が同期時に生成している。**`.codex/skills/ai-loop-cycle/` には references/ も scripts/ も無い**（`SKILL.md` + `agents/openai.yaml` + `assets/` のみ） |
| 12 | 参照の総数（作業量の下限） | `grep -rn` の行数 | `.claude/rules/` 形式 **44 行** + `../../rules/` 形式 **5 行** + 上流 `docs/**`（`docs/working/` 除く）**69 行** = **118 箇所** |
| 13 | 既存の類似検査は本問題を捕捉しない | `head -25 scripts/check-stale-skill-refs.py` | 同スクリプトは「**上流リポジトリ内に実在しないパス**」を WARN するもので、`.claude/rules/*.md` は上流に実在するため検出されない。本 PBI の問題は「**導入先で解決できるか**」であり検査軸が別。かつ同スクリプトは doctor / L-0 / CI のいずれにも未配線（ファイル冒頭に明記） |

### なぜ問題か（故障確率）

- **正本と要約の入れ替わりが静かに起きる**: skill は「正本を読め」と書いてあるだけで、
  読めなかったときに何をすべきかを書いていない。AI は解決失敗を報告せず skill 本文の
  要約で代替してしまい、**判定基準がいつのまにか劣化する**（劣化が観測できない）
- **経路によって壊れ方が違う**: `.claude/rules/` 形式と `../../rules/` 形式で
  解決可否が真逆（実測 #5）。片方だけ直すと逆の経路が壊れる
- **クラス C は 3 経路すべてで解決不能**（実測 #9）。フォールバック明記だけでは
  「読めない」ことが分かるだけで、正本の内容自体は入手できない

## What（Scope）

### In scope

`.agents/skills/`（正本）の **クラス A / クラス C の解決不能参照**を解消する。

| クラス | 内容 | `install.sh --claude` | plugin（marketplace） | Codex |
|---|---|---|---|---|
| **A-1** | `.claude/rules/*.md` 形式（44 箇所） | 解決可（`.claude/rules/` に着地） | **未記載**（実体は `${CLAUDE_PLUGIN_ROOT}/rules/` にある） | **解決不可**（`.codex/rules/` 不在） |
| **A-2** | `../../rules/*.md` 形式（5 箇所・**issue 未掲載**） | 解決可（`.claude/rules/`） | 解決可（`plugin/plangate/rules/`） | **解決不可** |
| **C** | 上流 `docs/**`（`docs/working/**` を除く 69 箇所） | 解決不可 | 解決不可 | 解決不可 |

1. **クラス A**: 対象 skill の rules 参照に、#955（`ai-dev-plan`）と同型の
   **3 経路別フォールバック順**（導入先相対 → `${CLAUDE_PLUGIN_ROOT}/rules/` →
   解決不能なら明示）を記載する。A-2（`../../rules/` 形式）は A-1 と解決可否が
   真逆なため、**表記を統一するか経路別に注記するかを plan で決着**させる（U-1）
2. **クラス C**: `ai-loop-cycle` 方式（bundled references）で解決するか、A と同じ
   フォールバック明記で解決するかを **クラスごと（または skill ごと）に決定**し、
   判断根拠を残す。**bundled 方式は正本編集ではなく同期スクリプト拡張**であり
   Codex 経路には効かない（実測 #11）ため、方式選定は plan の第一論点（U-2）
3. **派生の再生成**: `.codex/skills/` と `plugin/plangate/skills/` は
   同期スクリプト経由で再生成する（手編集ゼロ）
4. **回帰**: `sh tests/run-tests.sh` の baseline 維持（**下記 AC-4 の注記を参照**）
5. **marketplace 実環境での実測**（実測 #9 のキャッシュを使う）

### Out of scope

- **クラス B（CLI 参照 = `bin/plangate` / `scripts/*`）全般 → [#863](https://github.com/s977043/plangate/issues/863) の担当**。
  #863 は方針決定済み（同梱維持 / degrade 手順明記 / `bin/plangate`→`plangate` 表記統一 /
  plugin README の依存列挙修正）。**本 PBI は CLI 参照に一切触れない**
  - ⚠️ **境界の緊張点（plan で必ず扱うこと）**: #863 は対象として
    `intent-classifier` / `skill-policy-router` を**名指し**している（#863 本文の
    「実測 10 個」）。一方この 2 skill は本 PBI のクラス A 対象でもある（実測 #4）。
    **同一ファイルを両 PBI が編集する**ため、順序（どちらが先に main へ入るか）を
    plan で確定し、後発側が rebase する前提を明記する。**スコープの重複ではなく
    ファイルの重複**であり、クラス B を本 PBI に取り込んではならない
- `install.sh` のコピー対象拡張（#943 の提案 3）。配布物の構成変更は影響範囲が広く別途判断
- `docs/working/TASK-XXXX/` への参照（導入先で作る成果物なので解決不能で正しい）
- `ai-dev-plan`（#943 / PR #955 で対応済み）
- **`.claude/skills/` の同名 skill**（29 ディレクトリ・うち 23 が `.agents/skills/` と同名で
  8 件が内容相違）。`scripts/sync-plugin-plangate.sh` の skill ソースは
  `.agents/skills` のみ（L24 `SKILLS_DIR`）であり、`.claude/skills/` は派生ではなく
  **独立した集合**。同名重複の是非は本 PBI の対象外（U-5 に記録）
- **`.codex/skills/` の commit 済み drift 2 件 → [#956](https://github.com/s977043/plangate/issues/956) の担当**。
  本 PBI で同期スクリプトを実行すると `ai-loop-cycle` / `plan-review-gate` が
  巻き込み更新される（実測は TASK-0956 の pbi-input 参照）ため、**#956 の解消を
  待つか、巻き込み分を明示的に分離するか**を plan で決める（U-4）

### 参考にすべき既存モデル

| モデル | 実態（実測） | 本 PBI での使いどころ |
|---|---|---|
| **#955（`ai-dev-plan`）** | `.agents/skills/ai-dev-plan/SKILL.md` に「参照解決順」節 + 3 経路の実態表 + 読む順序への fallback 併記を追加（+96 行 / 派生 2 本も同期済） | **クラス A のテンプレート**。ただし 1 skill あたり +96 行は 27 skill には過大（U-3） |
| **`ai-loop-cycle`（#771 / #790）** | 正本は `SKILL.md` 1 本のみ。`references/` 22 本 + `scripts/` 25 本は **`sync-plugin-plangate.sh` が plugin 側にだけ生成**（`scripts/_ai_loop_link_rewrite.py` でリンク書き換え）。**Codex 側には配られない** | **クラス C の候補**だが「正本を編集する」話ではなく「**同期スクリプトを拡張する**」話。Codex 経路が救われない点が最大の制約 |

## 受入基準

> issue #954 の AC-1〜5 を継承し、実測で判明した差異（対象集合・baseline）を反映して
> 検証可能性を上げたもの。plan で最終確定する。

- **AC-1（クラス A）**: 対象 skill の rules 参照に「導入先相対 → `${CLAUDE_PLUGIN_ROOT}/rules/`
  → 解決不能なら明示」のフォールバック順が明記されている。
  **対象は実測で確定した 16 skill / 17 ファイル**（issue 記載の 13 skill ではない。
  `skill-creator` / `intent-classifier` / `skill-policy-router` を含む）。
  **`../../rules/` 形式（A-2）についても解決可否が経路ごとに正しく記述されている**
  （`.claude` 配置と plugin 配置では解決し、`.agents` / `.codex` では解決しない）
- **AC-2（クラス C）**: bundled references 方式で解決するか A と同じフォールバック
  明記で解決するかが決定され、**判断根拠が残っている**。判断根拠には
  **「bundled 方式は Codex 経路に配られない」（実測 #11）を明示的に評価した記録**を含む。
  対象は **16 skill / 17 ファイル**（`docs/working/templates/**` を含めるかは U-6 で決定）
- **AC-3（派生の再生成）**: 正本 `.agents/skills/` を編集し、`.codex/skills/` と
  `plugin/plangate/skills/` は同期スクリプト経由で再生成されている（手編集ゼロ）。
  **検証は「同期スクリプト実行後に `git status` が clean」ではなく
  「正本と派生の blob hash 一致」で行う**（#956 の既存 drift 2 件が未解消のうちは
  `git status` clean が成立しないため。#955 は blob hash 一致で検証した前例あり）
- **AC-4（回帰）**: `sh tests/run-tests.sh` が **0 failed**。
  ⚠️ **passed 件数の baseline は環境依存**: issue は 453 とするが、本 worktree
  （main `cda229b`）での実測は **452 passed / 0 failed**。原因は
  `tests/extras/ta-13-plangate-setup.sh` L162 の `[ -d "$PG_T13_ROOT/.git" ]` で、
  **git worktree では `.git` がファイル（`gitdir:` ポインタ）のため TC-17 が SKIP** される。
  したがって **AC は「0 failed」+「作業開始時に同一環境で採った baseline と同値」**
  で判定し、453 という数字を literal に要求しない
- **AC-5（実環境実測）**: クラス A / クラス C の双方について「導入先で実際に解決するか」を
  **marketplace 経由の環境で 1 件以上実測**し、証跡を `evidence/` に残す。
  最低限、**クラス A が `${CLAUDE_PLUGIN_ROOT}/rules/` で解決すること**と
  **クラス C が解決しないこと**の両方を示す（片側だけでは fallback の有効性を示せない）
- **AC-6（追加 / 空振り防止）**: 「解決不能参照が残っていないこと」を
  **機械検査**で確認する。検査は skill 本文を対象に
  「rules 参照を持つがフォールバック記述を持たないファイル = 0 件」を判定し、
  **対象件数をハードコードしない**（将来の skill 追加でも検出できる）。
  この検査を回帰テストとして固定するか手動チェックに留めるかは plan で決める（U-7）
- **AC-7（追加 / #863 との非干渉）**: 本 PBI の差分に **CLI 参照
  （`bin/plangate` / `scripts/ai-dev-workflow` / `scripts/codex-guarded.sh` 等）の
  変更が 1 行も含まれない**。`git diff origin/main` に対する機械検査で固定する

## Notes from Refinement

### issue 本文の数値と実測の差異（本 PBI は実測値を正とする）

| 項目 | issue #954 の記載 | 実測（main `cda229b`） | 差異の理由 |
|---|---|---|---|
| 全 skill 数 | 38 | **38**（+ `README.md` で 39 エントリ） | 一致 |
| 対象 skill 数 | 26 | **27**（`docs/working/templates` を含めると 31） | 下記の内訳を参照 |
| クラス A | 13 skill | **16 skill / 17 ファイル** | +`skill-creator`（表から欠落）/ +`intent-classifier`・`skill-policy-router`（`../../rules/` 形式を見落とし、B 専用と誤分類） |
| クラス C | 16 skill | **16 skill / 17 ファイル** | 完全一致 |
| `ai-loop-cycle` の bundled | 「skill 直下に `references/` + `scripts/` を自己完結同梱」 | **正本には無い**。plugin 側にのみ同期スクリプトが生成。Codex 側には無い | 「再設計済み」の主体が正本ではなく同期スクリプトだった |
| test baseline | 453 passed / 0 failed | **452 passed / 0 failed**（worktree） | `ta-13` TC-17 が `[ -d .git ]` 判定で worktree では SKIP |

**26 → 27 の内訳**: issue の 26 件から、クラス B 専用として #863 へ移管される
`intent-classifier` / `skill-policy-router` を引くと **24**。そこへ実測で判明した
`skill-creator`（+1）と、rules 参照が残るため #954 に留まる
`intent-classifier` / `skill-policy-router`（+2）を戻して **27**。

### `../../rules/` 形式の意味（実測 #5 の解釈）

`../../rules/x.md` は **誤記ではなく、配布先レイアウトを前提にした正しい相対パス**である。

| SKILL.md の配置 | `../../rules/` の解決先 | 実在 |
|---|---|---|
| `.claude/skills/<s>/SKILL.md` | `.claude/rules/` | ✅ 6 本 |
| `plugin/plangate/skills/<s>/SKILL.md` | `plugin/plangate/rules/` | ✅ 6 本 |
| `.agents/skills/<s>/SKILL.md`（**正本**） | `.agents/rules/` | ❌ 不在 |
| `.codex/skills/<s>/SKILL.md` | `.codex/rules/` | ❌ 不在 |

つまり **正本の場所では壊れていて、配布先では動く**。`.claude/rules/x.md` 形式は
その逆（正本の場所では動き、plugin では壊れる）。**この 2 形式が混在していることが
本問題の構造原因**であり、単に「フォールバックを書き足す」だけでは
「どちらの形式に寄せるか」が未決のまま残る。

### 責務分界（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)）

| 対象 | クラス | 備考 |
|---|---|---|
| `.agents/skills/**`（正本編集） | **AI-owned** | HO 9 カテゴリに非該当（`scripts/hooks/check-plan-hash.sh` L124-134 の case 文を実測。`.agents/skills` / `.claude/skills` はいずれも対象外） |
| `.codex/skills/**` / `plugin/plangate/skills/**`（同期生成） | **AI-owned** | 同上。ただし手編集は禁止（スクリプト経由） |
| `scripts/sync-plugin-plangate.sh`（bundled 方式を採る場合） | **AI-owned** | `scripts/hooks/*.sh` ではないため HO 非該当 |
| PR マージ | **Human-owned** | C-4 |

**HO パスを踏む予定はない**（`.github/workflows/` / `bin/plangate` / `.claude/rules/` の
いずれにも触れない）。ただし AC-6 の機械検査を CI へ配線する案を採る場合は
`.github/workflows/` に触れるため **HO 該当となり、patch 提示 + Human 適用が必要**（U-7）。

### Mode 見込み: critical（plan で確定。スライス分割を強く推奨）

- **定量**: 正本 **28 ファイル**（27 skill）+ 派生 2 系統の再生成
  （`.codex/skills/` / `plugin/plangate/skills/`）→ 変更ファイル総数は **80 本超**。
  16+ = **critical 帯**。参照の書き換え箇所は **118 行**（実測 #12）
- **受入基準**: 7 件（AC-1〜7）→ **high 帯**（6-10）
- **定性**: 変更種別は `.md` のみ（**doc** 軸）だが、以下により **doc-light は不適用**:
  - bundled 方式（U-2）を採ると `scripts/sync-plugin-plangate.sh`（shell）に触れるため
    種別が **code** に上がる（安全側: 「境界が曖昧なら上位種別」）
  - skill 本文は AI の判断基準そのものであり、**コード側（同期スクリプト・
    plugin バンドル構成）の追従を要する契約文書**に該当（doc-light 除外条件）
  - 承認境界周辺の `.md`（`.claude/rules/` 等）は触れないため、この経路での
    「最低 high」強制は発生しない
- **判定: critical**（定量が支配。`lite_eligible=false` / 人間 C-3 / V-4 実行対象）
- **スライス案（plan で確定）**: クラス A（17 ファイル）とクラス C（17 ファイル）で
  分けても各々 high 帯上限（6-15）を超える。**skill 群ごとに 3〜4 スライス**へ割るか、
  critical 受容で一括するかを plan で決める。共通ブロックの参照化（U-3）が
  成立すれば 1 スライスあたりの実質差分は大きく下がる

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| **#863 と `intent-classifier` / `skill-policy-router` を同時編集して conflict** | どちらかの PR が rebase 地獄。最悪、片方の修正が消える | Out of scope の「境界の緊張点」に記載のとおり **順序を plan で確定**し、後発が rebase する前提を明記。#863 は priority:P1 で本 PBI は P2 のため **#863 先行が既定**と想定（plan で確認） |
| **#956 の既存 drift 2 件を巻き込む** | 同期スクリプト実行で `ai-loop-cycle` / `plan-review-gate` が意図せず更新され、本 PBI の PR に無関係な差分が混入する | U-4。**#956 の解消を待つ**か、巻き込み分を別 commit に分離して PR 本文で明示。AC-3 の検証を `git status` clean ではなく blob hash 一致にしたのはこのため |
| **#955 と同じ形式（+96 行）を 27 skill に複製する** | skill 本文が定型文で肥大化し、可読性と context 消費が悪化。将来の文言変更が 27 箇所の同時修正になる | U-3。共通ブロックを 1 箇所（例: `.agents/skills/README.md` or 各 skill 冒頭 3 行 + 参照）に集約する案を plan で比較。**ただし参照先自体が導入先で解決できなければ本末転倒**である点に注意 |
| **bundled references 方式が Codex 経路を救わない**（実測 #11） | 「クラス C を解決した」と宣言しても Codex 導入者は依然として読めない。AC-2 が空振りする | AC-2 で「Codex 経路に配られないことを明示的に評価した記録」を必須化済み。plan で Codex 側 bundled 同期を追加するか、Codex はフォールバック明記に留めるかを決める |
| **フォールバックを書いただけで「解決した」と誤認する** | 実態はクラス C が読めないままで、AC が形式的にしか満たされない | AC-5 で marketplace 実環境の実測（A=解決 / C=非解決の両側）を必須化 |
| **2 形式（`.claude/rules/` と `../../rules/`）のどちらかに寄せて逆側を壊す** | 例えば全部 `.claude/rules/` に統一すると、plugin 経由の相対解決が失われる | AC-1 で「経路ごとに解決可否が正しく記述されていること」を要求。統一するなら **統一後の全経路の解決可否を実測**する（U-1） |
| **`skill-creator/references/review-default.md` のような reference ファイルを見落とす** | SKILL.md だけを対象にすると 2 ファイル（`review-gate/references/ui-ux-lane.md` / `skill-creator/references/review-default.md`）が漏れる | 対象特定を `--include='*.md'` の再帰 grep で行い、**skill ディレクトリ配下の全 md** を走査する（本 pbi の実測手順をそのまま使う） |

### Unknowns

- **U-1（最優先）**: **rules 参照の表記をどちらに寄せるか**。
  (a) `.claude/rules/` 形式へ統一 + fallback 明記（#955 踏襲）/
  (b) `../../rules/` 形式へ統一（plugin と `.claude` 配置で無設定に解決するが、
  正本 `.agents/` と Codex では壊れたまま）/ (c) 両形式を許容し経路別に注記。
  **正本 `.agents/` に `rules/` を置く（symlink or 実体）** という第 4 の選択肢も
  評価対象（`.agents/rules/` が存在すれば (b) は正本でも成立する）
- **U-2（最優先）**: **クラス C の解決方式**。(a) bundled references
  （= `sync-plugin-plangate.sh` の拡張。Codex に配られない）/ (b) フォールバック明記のみ
  （読めないことが分かるだけ）/ (c) skill ごとに使い分け。
  bundled は plugin バンドルサイズと同期スクリプトの複雑度が増す
- **U-3**: **共通ブロックの重複をどう抑えるか**。#955 は 1 skill に +96 行。
  27 skill へ素朴に複製すると +2,500 行規模になる。集約案（README への切り出し・
  短縮版テンプレート・冒頭 3 行 + 参照）の損益分岐を plan で比較する
- **U-4**: **#956 の drift 2 件との実行順序**。#956 先行が素直だが、
  #956 は `.github/workflows/`（HO）を含み Human 適用待ちが入るため
  リードタイムが読めない。本 PBI を先行させる場合の分離手順を決める
- **U-5**: **`.claude/skills/` の同名 skill 8 件の内容相違**をどう扱うか。
  `.claude/skills/`（29 個）は `.agents/skills/`（38 個）の派生ではなく独立集合で、
  23 個が同名・うち 8 個が内容相違（`ai-loop-cycle` 159 行差 /
  `subagent-driven-development` 44 行差 / `intent-classifier` 13 行差 /
  `codex-multi-agent` 11 行差 / `context-load` 8 行差 / `skill-creator` 4 行差 /
  `skill-policy-router` 4 行差 / `nonfunctional-check` 2 行差）。
  **本 PBI では触らない**が、`.claude/skills/` 側の同名 skill にも同じ
  解決不能参照があるなら「直したはずが直っていない」状態になる。
  別 issue 化するかを plan で判断
- **U-6**: **`docs/working/templates/**` をクラス C に含めるか**。含めると対象が
  27 → 31 skill に増える。templates は 3 経路すべてで配布対象外であり、
  解決不能性は `docs/ai/**` と同じ
- **U-7**: **AC-6 の機械検査をどこに置くか**。`tests/extras/` の回帰テストに留めれば
  HO 非該当だが、CI へ配線すると `.github/workflows/`（HO）となり Human 適用が要る。
  #956 が同種の CI 追加を扱うため、**検査の配線を #956 側へ寄せる**選択肢もある
- **U-8**: **`skill-creator` / `review-gate` の `references/*.md`** に本文と同じ
  フォールバック節を入れるか、SKILL.md 側の記述に委ねるか

### Assumptions

- main `cda229b`（PR #955 マージ後）を作業の起点とする
- **#863 がクラス B（CLI 参照）を全面的に担当し、本 PBI は CLI 参照に触れない**
  （issue #954 が 2026-08-02 に明示したスコープ縮小に従う）
- `.agents/skills/` が skill の唯一の正本であり、`.codex/skills/` と
  `plugin/plangate/skills/` は同期生成物である（`scripts/sync-plugin-plangate.sh` L24 /
  `scripts/install-plangate-skills-to-codex.sh` L25 で実測）
- HO 9 カテゴリ（`scripts/hooks/check-plan-hash.sh` L124-134）に
  `.agents/skills/` は含まれない = 通常の Mode 判定でよい
- `sh tests/run-tests.sh` の baseline は **同一環境で作業開始時に採り直す**
  （worktree では 452 / main checkout では 453 になる。AC-4 の注記参照）
