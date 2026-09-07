# #1226 — 承認手順の定義面を HO / CI の被覆に載せる（`git apply` 可能形 patch / **Human 適用**）

> 測定基点: **`origin/main` = `b3565b2`** / 2026-09-07。以下の実測はすべてこの ref のワークツリーに対するもの。
> 調査本体・全数照合・案の比較は [`1226-approval-surface-ho-coverage.md`](./1226-approval-surface-ho-coverage.md)。本書は **patch と適用手順だけ**を持つ。
> 位置づけ: **既存ギャップの是正**（退行ではない）。`scripts/hooks/*.sh` / `.claude/rules/*.md` / `.github/workflows/*.yml` はいずれも Hardening Override 対象のため、**AI は patch 提示まで・適用は Human-owned**。
> 本書で AI が作成したのは `docs/working/_reports/` 配下の `.md` 2 本のみ。`scripts/` / `tests/` / `.claude/` / `.codex/` / `.cursor/` / `bin/` / `schemas/` / `.github/` は **1 バイトも変更していない**。
> 先例と同じ marker 規則: [`1234-eh3-outside-repo-patch-applicable.md`](./1234-eh3-outside-repo-patch-applicable.md) / [`1278-log-event-fail-closed-patch-applicable.md`](./1278-log-event-fail-closed-patch-applicable.md)。
>
> **重要（未適用時の読み方）**: 本書が「12 カテゴリ」と書くのは **patch 適用後の状態**である。
> **現 main の Hardening Override は 9 カテゴリ / 15 パターンのまま**であり、patch を適用するまで
> リポジトリ内のどの宣言面も 9 カテゴリのままで正しい。本 patch は実装（`case` ブロック）と
> **全宣言面を同一 patch で同時に更新**するため、片側だけ 12 になる中間状態は生じない（§4）。

---

## 0. 結論先行

| 項目 | 結論 |
|---|---|
| **PATCH-A** | HO 9 カテゴリ → **12 カテゴリ**（パターン 15 → 20）。追加するのは**他 Provider の enforcement 配線 3 種**（`.codex/hooks.json` / `.cursor/hooks.json` / 両者の `hooks/*.sh`）と**承認トークンガード本体**（`scripts/check-approval-token-write.sh`）。`.claude/settings*.json` が既に HO であることとの**非対称の解消**にあたる |
| **PATCH-A の同時変更（実装 + 全宣言面）** | `case` ブロックだけ変えると本 issue と同じ「正本を更新しない」状態を自作する。したがって **HO 一覧を宣言している面を全数列挙し（§4）、HO / 非 HO を問わず同一 patch のハンクに含める** |
| **PATCH-A の適用前提（重要）** | **`.claude/rules/mode-classification.md` は `plugin/plangate/rules/mode-classification.md` と byte 一致の生成ミラー**であり、`.github/workflows/sync-plugin-plangate.yml` の `drift-check` job は `pull_request.paths` の `.claude/**` で起動する。**patch だけ当てると同 job が `exit 1` で即 FAIL する。`sh scripts/sync-plugin-plangate.sh` を実行してミラー差分をコミットする工程とセットで適用すること**（§5 手順 4） |
| **PATCH-B** | `.codex/skills/**` と正本 `.agents/skills/**` の **byte 一致を PR CI で必須化**（既存 `plugin/plangate/` drift-check と同じ形）。`pull_request.paths` に `.codex/skills/**` を追加しないと**そもそも job が起動しない**ため、それも同一ハンク |
| **PATCH-B の適用前提（重要）** | **現 main で 40 skill 中 10 件が既に drift している**（§2 表）。patch だけ当てると CI は即 FAIL する。**`sh scripts/install-plangate-skills-to-codex.sh --force` を実行して結果をコミットする工程とセットで適用すること**（§5 手順 5） |
| **適用しても塞がらないもの** | Bash 経路（#1104）/ symlink・FS エイリアス（#1264 / #1234）/ worktree 配下（#1277）/ hook 未配線の導入先 / `PLANGATE_BYPASS_HOOK=1` / **CI が required check でないこと**（#928）/ **`scripts/` 直下から wire される他 2 guard**（§6 / §7-6） |
| **`git apply --check`** | repo root で **rc=0**（§5 に実測を記載） |

---

## 1. PATCH-A が埋める非対称（実測）

HO 判定は `scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case` ブロックが正本。同ブロックのパターン集合を Python の `fnmatch.fnmatchcase` で忠実に再現し（`case` の `*` は `/` を跨いで一致する。`fnmatchcase` も同じ）、対象パスを小文字化して照合した結果:

| ファイル | 役割 | 現状 |
|---|---|---|
| `.claude/settings.example.json` | Claude Code の EH-2 / EH-3 / EH-13 配線 | **HO**（`.claude/settings.example.json` に一致） |
| `.codex/hooks.json` | Codex CLI の EH-1 / EH-2 / EH-3 / EH-6 / EH-9 配線 | **非 HO** |
| `.codex/hooks/eh-bridge.sh` | Codex の rc → allow/deny 翻訳（未知 rc は **allow**） | **非 HO** |
| `.cursor/hooks.json` | Cursor の EH-1 / EH-2 配線（`failClosed: false`） | **非 HO** |
| `.cursor/hooks/plangate-eh2-c3.sh` | Cursor の EH-2 入口（`scripts/hooks/cursor-adapter.sh` へ exec） | **非 HO** |
| `scripts/hooks/cursor-adapter.sh` | Cursor 用アダプタ本体 | **HO**（`scripts/hooks/*.sh` に一致） |
| `scripts/check-approval-token-write.sh` | **EH-13**（`c3.json` / `maintenance.json` への AI 書込を block する承認トークンガード） | **非 HO**（`scripts/hooks/` ではなく `scripts/` 直下にあるため） |

つまり **Claude レーンの配線は HO で守られているが、Codex / Cursor レーンの配線は 1 つも守られていない**。`.cursor/hooks/plangate-eh2-c3.sh` を `exit 0` の 1 行に書き換えれば、HO を 1 つも踏まずに Cursor セッションの EH-2 を無効化できる。EH-13 も同様で、**承認トークンを守るガードそのものが AI 編集可能**な位置にある。

これは本 issue の型（HO を踏まずに承認の中身を変えられる）と同一である。

### `scripts/` 直下から wire されている guard の全数（数え落としを残さない）

`.claude/settings.example.json` が `scripts/` **直下**（= `scripts/hooks/*.sh` の HO パターン外）から呼んでいるスクリプトは、EH-13 本体だけではない。実測（`grep -o 'scripts/[A-Za-z0-9_./-]*' .claude/settings.example.json | sort | uniq -c`）:

| スクリプト | 役割 | 本 patch で HO にするか | 理由 |
|---|---|---|---|
| `scripts/check-approval-token-write.sh` | **EH-13** 承認トークン直書き block（`Edit\|Write` と `Bash` の両経路に配線） | **する** | **承認境界そのもの**を守るガード。本 issue の対象領域 |
| `scripts/check-git-destructive.sh` | EH-12 protected branch 上の `reset --hard` / `push --force` block | **しない** | 守るのは **git 破壊操作**であって承認トークンではない。本 issue のスコープ外。HO 化の是非は §7-6 の Human 判断へ |
| `scripts/gh-pin-account.sh` | gh CLI の active account 固定（sockpuppet 防止の補助） | **しない** | 同上。承認境界の**周辺**ではあるが承認トークンの受理判定を持たない。§7-6 へ |

`scripts/hooks/` 配下（`check-plan-hash.sh` / `check-c3-approval.sh` / `check-plan-exists.sh` / `check-forbidden-files.sh` / `check-post-edit-diff.sh` / `check-stop-diff-status.sh` / `check-delegation-commit-boundary.sh`）は既に `scripts/hooks/*.sh` で HO。**「非対称の解消」を掲げる以上、上記 2 本を意図的に外していることを本書で明示し、§7 の Human 判断に送る**（黙って落とさない）。

### 追加候補から外したもの（副作用評価）

| 候補 | 外した理由 |
|---|---|
| `.agents/skills/**/SKILL.md`（承認手順の散文正本） | (1) `.cursor/skills/plan-review-gate` は `.agents/skills/plan-review-gate` への **symlink**（`git ls-files -s` で mode `120000`）であり、EH-3 の正規化は字句のみで symlink を解決しない（#1101 Non-goal）。`.agents/...` を HO にしても `.cursor/...` 経由の書込は素通りする＝**塞いだつもりになる**。(2) HO は c3 + plan_hash 承認下でも**常時 block** であり、40 skill の通常保守がすべて Human patch 経由になる。**代わりに PATCH-B の内容 drift 検査で扱う** |
| `plugin/plangate/**` | **生成物**。正本を編集すれば同期スクリプトが再生成する。HO にすると AI の `Edit/Write` は止まるが、`Bash` から同期スクリプトを走らせる経路は EH-3 の Bash レーンが no-op（#1104）で止まらない。**「正直な編集だけ止めて回避経路は残る」**逆進的な防御になる。#1263 の担当範囲でもある |
| `.claude/skills/**` | 現行 override パターン外であることが `mode-classification.md` に明示（R-003/R-006）。本 patch で方針変更しない。**したがって §4 の宣言面のうち `.claude/skills/plangate-working-discipline/` の 2 本は非 HO であり、AI が編集可能である**（それでも本 patch のハンクに含める。理由は §4） |

---

## 2. PATCH-B が埋めるギャップ（実測）

`.codex/skills/<name>/` は `scripts/install-plangate-skills-to-codex.sh` が `.agents/skills/<name>/` から生成する。**同スクリプトが配るものは 4 種**であり、byte 比較できるのはうち 2 種だけである（実測: `cp "$skill_file" "$target_skill_file"` / `sync_references()` / `cp "$_a" "$target_assets_dir/"` / `{ ... } > "$target_openai_yaml"`）:

| 配布物 | 変換 | 本検査の対象 | 理由 |
|---|---|---|---|
| `SKILL.md` | **無変換 `cp`** | **対象** | 正本と byte 一致であるべき |
| `references/*.md` | **無変換 `cp`**（+ 正本に無いファイルの削除） | **対象**（本 patch で追加） | 同上。実測で正本側 2 skill（`review-gate` / `skill-creator`）が保持し、現時点の乖離は **0 件** |
| `assets/*` | `plugin/plangate/assets` からコピー | **対象外** | 出所が **per-skill の正本ではない**（skill ごとの canon が存在しない） |
| `agents/openai.yaml` | **生成**（frontmatter の icon 補完・正規化を適用） | **対象外** | 変換後の成果物であり byte 比較の対象にできない。presence の検査は既存 `scripts/check-codex-skill-spec.sh` が担う |

### SKILL.md の乖離（現 main の実測）

```sh
for d in .agents/skills/*/; do n=$(basename "$d"); cmp -s "$d/SKILL.md" ".codex/skills/$n/SKILL.md" || echo "DIFFER $n"; done
```

**変更行数の定義**（旧版は数え方を書いておらず、かつ `grep -c '^-[^-]'` 方式で
**内容が `-` / `+` で始まる行**（Markdown の箇条書き）を取りこぼしていた。以下は
`diff <canon> <mirror> | grep -c '^[<>]'` ＝ **`<` / `>` 行の合計**で数え直した値）:

| skill | 変更行数（`diff` の `<`/`>` 行） | 承認手順を定義するか |
|---|---|---|
| `ai-dev-plan` | 128 | **YES**（`plan_hash` 整合検証の CLI 不在フォールバック / AC-11） |
| `ai-dev-verify` | 98 | **YES**（V-1 の `plan_hash` 突合を必須と定義） |
| `ai-dev-exec` | 87 | **YES**（exec 入口条件: `c3.json` 存在 + `approval_kind` 別条件） |
| `ai-loop-cycle` | 81 | **YES**（C-3′ 経路） |
| `ai-dev-brainstorm` | 79 | NO |
| `plan-review-gate` | 15 | **YES**（C-3 の必須手順そのもの） |
| `plangate-setup` | 9 | NO |
| `intent-classifier` | 8 | **YES**（「AI は c3.json を代理発行しない」） |
| `local-exec-handoff` | 8 | **YES**（「`approvals/c3.json` の APPROVED 確認は省略不可」） |
| `working-context` | 8 | NO |

**10 / 40 が drift。うち 7 件が承認手順の定義面。** 対照として `plugin/plangate/skills/*/SKILL.md` は 40/40 が byte 一致である（既存 CI の drift-check が効いているため）。**同じ配布メカニズムでも、CI で照合しているレーンだけが一致している。**

### drift の中身（最も短い実例 / `plan-review-gate`）

`.codex/` 版には正本にある次の 2 つの規範ブロックが**無い**:

- 「機械 block が無いことを理由に C-3 を省略しない。」
- 「CLI が無いことを理由に手順を黙って省略し、実施済みと読める記録を残してはならない。」

**Codex セッションは、弱められた C-3 定義を読んでいる。** これは #1226 が予測した事象が既に main で実現している証拠である。

### 検査の方向（旧版の片方向を双方向へ）

旧版の検査は `.agents/skills/*/` を回す **canon → mirror の一方向**のみで、
**`.codex/skills/` にだけ存在する skill**（正本に無い承認手順を持ち込む面）を検出できなかった。
本 patch は **mirror → canon の逆方向ループを追加**する。

- 現 main の実測: 逆方向の検出は **0 件**（`.codex/skills/` の 40 ディレクトリすべてに `.agents/skills/` の対応がある）。
- 空振りでないことの確認（positive control）: 仕込みフィクスチャ（`.codex/skills/rogue/` と
  正本に無い `references/extra.md`）に対して **2 件を検出し rc=1**（§4 M-8）。

### `.codex/skills/.system` について（旧版の記述の訂正）

旧版は「`.codex/skills/.system` も不在」と書いていたが**誤り**である。同ディレクトリは
**`.gitignore:32` に `.codex/skills/.system/` として登録された ignore 対象**であり、
Codex CLI が実行時に作る。作業チェックアウトには実在しうる（`git check-ignore -v` で確認できる）。
本 worktree のような tracked ファイルのみの checkout には存在しない。

**結論は変わらない**: (1) CI は fresh checkout なので `.system` は存在しない、
(2) そもそも検査ループは `.agents/skills/*/` と `.codex/skills/*/` を回すが、
`.system` は canon 側に対応が無いため **逆方向ループの偽陽性になりうる** — ただし ignore
対象であり CI の checkout には出現しないため実害はない。ローカルで本検査を手動実行する
場合にのみ 1 件の偽陽性が出る点を、この節の注記として残す。

### なぜ既存の検査が見つけないか

| 既存の検査 | 何を見るか | なぜ見つけないか |
|---|---|---|
| `.github/workflows/sync-plugin-plangate.yml` の `drift-check` job | `sh scripts/sync-plugin-plangate.sh` 後の `git diff --quiet -- plugin/plangate/` | 対象が `plugin/plangate/` のみ。`.codex/` は同期スクリプトの出力先ではない |
| 同 workflow の `pull_request.paths` | `.claude/**` / `.agents/skills/**` / `plugin/plangate/**` 等 | **`.codex/**` を含まない** → `.codex/` だけ変える PR では job が起動すらしない |
| `scripts/check-codex-skill-spec.sh` | ディレクトリ集合の **presence** と `SKILL.md` / `agents/openai.yaml` の対応 | **内容を一切見ない**。さらに CI では `--warn-only` で呼ばれる |
| `tests/extras/ta-77-approval-surface-gate.sh` + `tests/fixtures/ta-77/approval-surfaces.tsv` | 承認手順の**宣言ブロック**（宣言行 + その行を含む連続非空行ブロック）の sha256 先頭 12 桁 | **ファイル全体を見ない**（§2-bis） |

### §2-bis. 既存ゲート `ta-77` との関係（本書の追記 / `tests/` は読取のみ）

repo には既に #1226 用のゲート `tests/extras/ta-77-approval-surface-gate.sh`（834 行）と
台帳 `tests/fixtures/ta-77/approval-surfaces.tsv`（33 エントリ）が存在する。
旧版の本書と調査報告はこれにまったく言及していなかった。**読んだうえで**の整理:

**(a) 本提案との関係 — 直交する。重複しない。**

| | ta-77 | PATCH-B |
|---|---|---|
| 見るもの | 承認手順の**宣言ブロック**（`digest`）と `path` / `class` の三つ組 | 配布物ファイルの **byte 一致（全体）** |
| 見る面 | `.agents` / `.claude` / `.codex` / `docs` / `plugin` を横断（33 エントリ） | `.agents/skills` ↔ `.codex/skills` の 1 対 |
| 検出する事象 | 承認手順の**記述が変わったこと**（正本・コピーを問わず） | 正本と配布物の**乖離** |
| 発火 | `tests/` 実行時 | PR CI（`pull_request.paths` 一致時） |

ta-77 は「承認手順の記述が変わったら diff に出す」ためのもの、PATCH-B は「正本と配布物が
一致していることを PR で必須にする」ためのもの。**片方が他方を代替しない。**
なお ta-77 自身が冒頭で「得られるのは diff 可視性であって承認境界ではない」
（台帳も ta-77 本体も HO 対象外で、同一 PR で書き換えれば期待値を動かせる）と自己申告しており、
この点は本書 §6 の残存と同じ立場である。

**(b) なぜ台帳が digest 一致を報告するのに drift があるのか — 宣言ブロックの外で乖離しているため。**

台帳は `.codex/skills/ai-dev-plan/SKILL.md` と `.agents/skills/ai-dev-plan/SKILL.md` に
**同一の digest `79c0d8551308`** を記録している。一方 §2 の実測では同ファイルは **128 行**
乖離している。矛盾ではない:

- ta-77 の digest は `digest_of(lines, idx)` — **検出器がマッチした宣言行 idx とその周辺の
  連続非空行ブロックだけ**を連結した sha256 であり、**ファイル全体のダイジェストではない**
  （ta-77 本体の冒頭コメント: 「digest は『宣言行 + その行を含む連続非空行ブロック』を連結した
  sha256 先頭 12 桁」）。
- したがって `.codex` 版から**宣言ブロックの外側**が削られている限り digest は動かない。
  実際 §2 の乖離 10 件のうち台帳に `.codex` 側エントリがあるのは 5 件だけで、
  `ai-dev-verify` / `ai-dev-exec` / `ai-loop-cycle` / `ai-dev-brainstorm` / `working-context` は
  そもそも台帳に載っていない（検出器が宣言面と認識していない）。

**この 2 つを合わせると、ta-77 は「承認手順の宣言が変わったか」を守り、PATCH-B は
「配布物が正本と同じか」を守る。#1226 が問題にしているのは後者であり、ta-77 の存在は
本提案を不要にしない。**

---

## 3. 設計判断

| 判断 | 理由 |
|---|---|
| PATCH-A で `case` ブロックと**全宣言面**（HO / 非 HO を問わず）を**同一 patch** にする | 片方だけ変えることが本 issue の病名そのもの。実装と正本宣言の同時変更を patch の単位で強制する（§4） |
| 非 HO の宣言面も「今の PR では書き換えず patch のハンクとして持つ」 | patch 未適用の段階で文書だけ「12 カテゴリ」にすると、**実装が 9 のまま文書が 12 を主張する逆向きの不整合**になる。本 PR は patch を提示するだけで、リポジトリ本体は 9 カテゴリのまま整合している |
| PATCH-A のパターンを `.codex/hooks/*.sh` のように**ディレクトリ限定 glob**にする | `case` の `*` は `/` を跨ぐため `.codex/**` 相当になる。`.codex/skills/**` まで巻き込まないよう `hooks/` に限定する |
| patch に `index` 行を残す | 3-way merge には pre-image blob が要る。**`index` 行があれば `git apply -3` が使える**（旧版の patch は `index` 行を持たず、`-3` を案内しながら実際には「repository lacks the necessary blob」で失敗していた。§8-5 の実測） |
| PATCH-B を**新規 workflow ではなく既存 `drift-check` job のステップ**として足す | 実行環境・permissions・concurrency を再定義しない。既存の「同期漏れを PR で落とす」規約の素直な延長 |
| PATCH-B で **missing も FAIL** にする | 現 main は 40/40 対応が成立しており正当な除外が無い。`continue` で見逃すと「削除すれば検査が消える」穴になる |
| PATCH-B を**双方向**にする | 一方向では `.codex/skills/` にだけ存在する面（正本に無い承認手順）を検出できない（§2「検査の方向」） |
| PATCH-B の対象を `SKILL.md` + `references/*.md` に限る | installer の実測に基づく。`agents/openai.yaml` は生成物、`assets/` は per-skill の正本を持たない（§2 表） |
| PATCH-B の各パイプを `\|\| true` で閉じる | GitHub Actions の既定シェルは `bash -eo pipefail`。`diff -u ... \| head -40` は `head` の早期終了で rc=1 になり、**errexit でステップが即終了して 1 件目しか報告されない**（§4 M-7 で実測） |
| PATCH-B は `cmp` で照合し、**installer を CI で走らせない** | installer を走らせて `git diff` を見る方式は installer 自身の変更で検査が空振りする。`cmp` は installer とは独立に「正本 = 配布物」を主張する |
| EH-13 の Codex / Cursor 配線追加は**本 patch に含めない** | `.codex/hooks.json` に `check-approval-token-write.sh` が配線されていない非対称は実在するが、**新しい block クラスを増やす** Human 判断事項。§7 に送る |
| `scripts/check-git-destructive.sh` / `scripts/gh-pin-account.sh` を HO にしない | 守る対象が承認トークンではない（§1「`scripts/` 直下から wire されている guard の全数」）。判断は §7-6 へ |

---

## 4. 「9 カテゴリ」を宣言している面の全数（同一 patch で更新する）

### 4.1 列挙手順（再現可能・positive / negative control 付き）

```sh
# 掃き出し（recall 優先）
git grep -n "9 カテゴリ"
git grep -n "15 パターン\|パターン 15 個"
# 派生値（9 - 1 = 8 のような、カテゴリ数から導かれる数）
git grep -n "残る 8 カテゴリ"
```

- **positive control**: 上記は `.claude/rules/mode-classification.md`（HO 一覧の正本）と
  `scripts/hooks/check-plan-hash.sh`（実装）の両方を返す — 既知の 2 面が実際に拾えている。
- **negative control**: 同じ掃き出しは `docs/ai/metrics-privacy.md` の「禁止 9 カテゴリ」
  （privacy の話であり HO と無関係）も返す。したがって**掃き出し結果をそのまま採用せず、
  1 件ずつ読んで「HO のカテゴリ数を宣言しているか」で narrowing した**。
- 除外の方針: **リリース履歴（`CHANGELOG.md` / `docs/changelog.md` / `README.md` /
  `CLAUDE.md` のリリースノート節）と、適用済み one-shot スクリプト（`scripts/apply-*.sh`）は
  「その時点で 9 カテゴリだった」という過去の記録であり、更新すると履歴の改竄になる**ため
  対象外。

### 4.2 更新対象（12 面 / patch のハンクに含める）

| # | ファイル | HO | 何を宣言しているか | 変更 |
|---|---|---|---|---|
| 1 | `scripts/hooks/check-plan-hash.sh` | **HO** | `case` ブロック本体 + 直上コメント「ラベル 9 行 / パターン 15 個」 | 実装 5 パターン追加 + 「12 行 / 20 個」 |
| 2 | 同上（#1089 の経緯コメント） | **HO** | 「判定内容・9 カテゴリ・…は不変」 | **9 という数を消し、#1089 時点の話であることを明示**（成長する値を現在形の契約として残さない） |
| 3 | `.claude/rules/mode-classification.md` | **HO** | HO 一覧の**正本**（9 カテゴリ + パス列挙） | 12 カテゴリ + 3 行追加 |
| 4 | `.claude/skills/plangate-working-discipline/SKILL.md` | 非 HO | 正本一覧表の「HO 9 カテゴリ」 | 12 |
| 5 | `.claude/skills/plangate-working-discipline/approval-gate-template.md` | 非 HO | **承認ゲート Step 0 のチェックリストで HO 対象パスを列挙** | パス 3 種追加 + 12 |
| 6 | `docs/ai/hook-enforcement.md`（5 箇所 + 派生値 1 箇所） | 非 HO | EH-3 の block 対象 / 「HO 9 カテゴリ 15 パターンすべて」/ 「残る 8 カテゴリ」 | 12 / 20 / 11 |
| 7 | `docs/ai/ho-change-workflow.md` | 非 HO | HO パターン定義の参照（「9 カテゴリ正本」） | 12 |
| 8 | `docs/ai/repo-guard.md` | 非 HO | `bin/plangate` が HO である根拠（「9 カテゴリ正本」） | 12 |
| 9 | `docs/ai/subagent-delegation/README.md`（2 箇所） | 非 HO | 委譲時の HO 非該当判定 | 12 |
| 10 | `docs/ai/subagent-delegation/plangate-flow-integration.md` | 非 HO | 派遣プロンプトの HO 制約 | 12 |
| 11 | `docs/ai/w6-autonomous-approve-introduction.md`（2 箇所） | 非 HO | 他 repo への W-6 導入時の HO 一覧参照 | 12 |
| 12 | `plugin/plangate/rules/mode-classification.md` | 非 HO（**生成物**） | #3 の byte 一致ミラー | **patch のハンクにしない**。`sh scripts/sync-plugin-plangate.sh` の実行で再生成する（§5 手順 4） |

**#5 が最も重い**: `approval-gate-template.md` は承認ゲート Step 0 のチェックリストで
HO 対象パスを**列挙**しており、更新しないと新カテゴリ（`.codex/hooks*` / `.cursor/hooks*` /
`scripts/check-approval-token-write.sh`）に触れる PBI が
「最低 high + `lite_eligible=false`」の**規範判定から漏れる**（機械 block は効くが、
mode 判定と承認境界の規範側が追随しない）。

### 4.3 対象外（履歴・適用済み one-shot / 意図的に変更しない）

| ファイル | 種別 | 変更しない理由 |
|---|---|---|
| `CHANGELOG.md` / `docs/changelog.md` | リリース履歴 | v8.x 時点の記録 |
| `CLAUDE.md` / `README.md` の v8.21.0 リリースノート節 | リリース履歴 | #1089 当時の事実の記述 |
| `scripts/apply-1101-ho-normalization.sh` / `scripts/apply-eh3-ho-always.sh` / `scripts/apply-ai-loop-phase1-command.sh` / `scripts/apply-claude-md-v8210.sh` | 適用済み one-shot | 再実行不要と明記済み。過去の適用内容の記録 |
| `tests/extras/ta-77-approval-surface-gate.sh` | テスト | **本 PR では `tests/` を読取のみに限定**（並行作業中）。適用時に 9 → 12 の追随が要るかは §8-6 の follow-up |

### 4.4 適用後の残存差集合（機械照合）

適用後、履歴と one-shot を除いた面に「9 カテゴリ」が残らないことを次で確認する（§5 手順 3）:

```sh
git grep -n "9 カテゴリ\|15 パターン\|残る 8 カテゴリ" \
  -- . ':!CHANGELOG.md' ':!docs/changelog.md' ':!docs/working' ':!scripts/apply-*.sh' \
  | grep -v "設定時に 9 カテゴリ" | grep -v "当時は 9 カテゴリ"
```

**positive control（この grep に検出力があること）**: 適用**前**に同じ grep を実行すると
23 行が返る（実測。`.claude/rules/mode-classification.md` と
`scripts/hooks/check-plan-hash.sh` を含む）。常に 0 件を返す空振り検査ではない。

**適用後の期待（残ってよい 4 種）**:

| 残る面 | 理由 |
|---|---|
| `CLAUDE.md:16` / `README.md:81` | v8.21.0 リリースノート節の履歴記述（§4.3） |
| `plugin/plangate/rules/mode-classification.md:49` | **生成物**。§5 手順 4 の `sh scripts/sync-plugin-plangate.sh` で 12 に変わる。手順 4 の**後**に再実行してこの行が消えることを確認する |
| `scripts/hooks/check-plan-hash.sh:327` | 「当時は 9 カテゴリ」に書き換わるため上の `grep -v` で除外される（0 行） |
| `tests/extras/ta-77-approval-surface-gate.sh:69` | §4.3 の理由で本 patch の対象外（§8-6 の follow-up） |

**これら以外が残っていたら宣言面の取りこぼしである。**

---

## 5. patch（`git apply` 用 / **検証済**）

抽出は marker 基準（#1104 / #1234 と同じ規則。marker 行と fence 行の 2 行ずつを落とす）:

````sh
sed -n '/^<!-- PG-PATCH-BEGIN -->$/,/^<!-- PG-PATCH-END -->$/p' \
  docs/working/_reports/1226-approval-surface-patch-applicable.md \
  | sed -e '1d' -e '$d' | sed -e '1d' -e '$d' > /tmp/1226-approval-surface.patch
git apply --check /tmp/1226-approval-surface.patch   # rc=0 実測
git apply --numstat /tmp/1226-approval-surface.patch
````

<!-- PG-PATCH-BEGIN -->
`````diff
diff --git a/.claude/rules/mode-classification.md b/.claude/rules/mode-classification.md
index 13dfd5b..25f4e67 100644
--- a/.claude/rules/mode-classification.md
+++ b/.claude/rules/mode-classification.md
@@ -46,7 +46,7 @@
 - データベーススキーマ変更 → 最低でも「高」
 - 公開 API の破壊的変更 → 最低でも「超高」
 - **承認境界周辺の変更 → 最低でも「高」** (TASK-0106 Retrospective Try 由来 / TASK-0112)
-  - 対象パス (Hardening Override 対象と完全一致 / [`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) の **`_override=0` 直後の `case` ブロック**（`esac` まで）= **9 カテゴリ** 正本。行番号で参照しないこと — 行番号アンカーは実装の移動で黙って別ブロックを指す / #1089):
+  - 対象パス (Hardening Override 対象と完全一致 / [`scripts/hooks/check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh) の **`_override=0` 直後の `case` ブロック**（`esac` まで）= **12 カテゴリ** 正本。行番号で参照しないこと — 行番号アンカーは実装の移動で黙って別ブロックを指す / #1089):
     - `.claude/rules/*.md`
     - `.claude/settings.json` / `.claude/settings.local.json` / `.claude/settings.example.json`
     - `.claude/commands/*.md`
@@ -56,6 +56,9 @@
     - `schemas/*.schema.json`
     - `.github/workflows/*.yml` / `.github/workflows/*.yaml`
     - `AGENTS.md` / `CLAUDE.md`
+    - `.codex/hooks.json` / `.cursor/hooks.json` (#1226)
+    - `.codex/hooks/*.sh` / `.cursor/hooks/*.sh` (#1226)
+    - `scripts/check-approval-token-write.sh` (#1226 / EH-13 本体)
   - (注: `.claude/skills/` と `scripts/_*.py` は現行 override パターン**外**、本ルールでも追加しない — R-003/R-006)
   - 上記パスに touch する PBI は **`lite_eligible=false` 強制 + Standard C-3 同期固定** ([`working-context.md`](./working-context.md) C-3 条件付き降格 §AC-10 Hardening Override と整合 / R-007)
   - 監査ログ (`docs/working/_audit/`) の **データ一括変更 CLI** も承認境界相当として扱い、最低「高」 (例: TASK-0110 skip-decision-log batch acknowledge)
diff --git a/.claude/skills/plangate-working-discipline/SKILL.md b/.claude/skills/plangate-working-discipline/SKILL.md
index 79488af..7d5bff3 100644
--- a/.claude/skills/plangate-working-discipline/SKILL.md
+++ b/.claude/skills/plangate-working-discipline/SKILL.md
@@ -162,7 +162,7 @@ CI/CD・デプロイ設定変更 / 外部 API・料金・規約に影響する
 |---|---|
 | `docs/ai/core-contract.md` | Iron Law / Stop rules / Output discipline（実行契約の正本） |
 | `.claude/rules/review-principles.md` | レビュー観点・Severity・auto-approve 判定（C-2 / CI / コードレビュー） |
-| `.claude/rules/mode-classification.md` | 5 段階モード・**HO 9 カテゴリ**・lite_eligible（承認境界の機械判定） |
+| `.claude/rules/mode-classification.md` | 5 段階モード・**HO 12 カテゴリ**・lite_eligible（承認境界の機械判定） |
 | `.claude/rules/responsibility-classes.md` | AI/Human/CI/Workflow の責務 4 分類・自己設置 Gate 非緩和 |
 | `.claude/rules/working-context.md` | C-3/C-4 ゲート・handoff・作業コンテキスト構造 |
 | `docs/ai/subagent-delegation/` | 派遣プロンプト 8 要素・OUTCOME 契約・行動規範（委譲の契約層） |
diff --git a/.claude/skills/plangate-working-discipline/approval-gate-template.md b/.claude/skills/plangate-working-discipline/approval-gate-template.md
index 44c3501..2222dba 100644
--- a/.claude/skills/plangate-working-discipline/approval-gate-template.md
+++ b/.claude/skills/plangate-working-discipline/approval-gate-template.md
@@ -7,7 +7,7 @@
 
 | #   | 観点                 | 例                                                   |
 | --- | -------------------- | ---------------------------------------------------- |
-| 0   | **Hardening Override（HO）対象パス接触** | `.claude/rules/*.md`・`.claude/settings*.json`・`.claude/commands/*.md`・`.claude/agents/*.md`・`scripts/hooks/*.sh`・`bin/plangate`・`schemas/*.schema.json`・`.github/workflows/*`・`AGENTS.md`/`CLAUDE.md`（正本: `mode-classification.md` の HO 9 カテゴリ）。**該当なら他観点にかかわらず無条件 yes + 最低 high** |
+| 0   | **Hardening Override（HO）対象パス接触** | `.claude/rules/*.md`・`.claude/settings*.json`・`.claude/commands/*.md`・`.claude/agents/*.md`・`scripts/hooks/*.sh`・`bin/plangate`・`schemas/*.schema.json`・`.github/workflows/*`・`AGENTS.md`/`CLAUDE.md`・`.codex/hooks.json`/`.cursor/hooks.json`・`.codex/hooks/*.sh`/`.cursor/hooks/*.sh`・`scripts/check-approval-token-write.sh`（正本: `mode-classification.md` の HO 12 カテゴリ）。**該当なら他観点にかかわらず無条件 yes + 最低 high** |
 | 1   | データ削除           | レコード削除・ファイル削除・履歴の破棄               |
 | 2   | DB schema 変更       | migration・カラム削除・型変更                        |
 | 3   | 認証・認可変更       | 権限モデル・ロール・トークン・セッション             |
diff --git a/.github/workflows/sync-plugin-plangate.yml b/.github/workflows/sync-plugin-plangate.yml
index dfabf54..9a1c2d3 100644
--- a/.github/workflows/sync-plugin-plangate.yml
+++ b/.github/workflows/sync-plugin-plangate.yml
@@ -20,6 +20,7 @@ on:
     paths:
       - '.claude/**'
       - '.agents/skills/**'
+      - '.codex/skills/**'
       - 'docs/ai/ai-loop/**'
       - 'docs/workflows/ai-loop/**'
       - 'scripts/ai-loop/**'
@@ -60,6 +61,55 @@ jobs:
           fi
           echo "plugin/plangate/ is in sync with sources."
 
+      - name: Verify .codex/skills mirrors .agents/skills canon (#1226)
+        # 対象は installer が無変換 cp する SKILL.md と references/*.md のみ。
+        # agents/openai.yaml は frontmatter を正規化して生成されるため byte 比較の
+        # 対象外。assets/ は plugin/plangate/assets が出所で per-skill 正本を持たない
+        # （scripts/install-plangate-skills-to-codex.sh 実測）。
+        # 既定シェルは bash -eo pipefail。`diff | head` は head の早期終了で rc=1 に
+        # なり errexit でステップが即終了して 1 件目しか報告されないため、パイプは
+        # `|| true` で閉じ、全件を報告してから最後に rc を返す。
+        run: |
+          rc=0
+          # canon -> mirror（欠落・乖離）
+          for _d in .agents/skills/*/; do
+            _n=$(basename "$_d")
+            for _c in "${_d}SKILL.md" "${_d}references"/*.md; do
+              [ -f "$_c" ] || continue
+              _b=$(basename "$_c")
+              case "$_c" in
+                *references/*) _m=".codex/skills/$_n/references/$_b" ;;
+                *) _m=".codex/skills/$_n/$_b" ;;
+              esac
+              if [ ! -f "$_m" ]; then
+                echo "::error::$_m missing (canon: $_c)"
+                rc=1
+              elif ! cmp -s "$_c" "$_m"; then
+                echo "::error::$_m diverges from $_c -- re-run scripts/install-plangate-skills-to-codex.sh --force and commit the result"
+                diff -u "$_c" "$_m" | head -40 || true
+                rc=1
+              fi
+            done
+          done
+          # mirror -> canon（正本に無い面が .codex 側にだけ存在しないこと）
+          for _m in .codex/skills/*/; do
+            _n=$(basename "$_m")
+            if [ ! -d ".agents/skills/$_n" ]; then
+              echo "::error::.codex/skills/$_n has no canon under .agents/skills/"
+              rc=1
+              continue
+            fi
+            for _r in "${_m}references"/*.md; do
+              [ -f "$_r" ] || continue
+              _b=$(basename "$_r")
+              if [ ! -f ".agents/skills/$_n/references/$_b" ]; then
+                echo "::error::$_r has no canon under .agents/skills/$_n/references/"
+                rc=1
+              fi
+            done
+          done
+          exit "$rc"
+
   sync:
     if: github.event_name != 'pull_request'
     permissions:
diff --git a/docs/ai/ho-change-workflow.md b/docs/ai/ho-change-workflow.md
index e181287..d900442 100644
--- a/docs/ai/ho-change-workflow.md
+++ b/docs/ai/ho-change-workflow.md
@@ -49,7 +49,7 @@ HO パスの変更を伴う PBI は以下に分割する:
 ## 関連
 
 - 責務4分類正本: [`responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
-- HO パターン定義: `check-plan-hash.sh` の **`_override=0` 直後の `case` ブロック**（`esac` まで。9 カテゴリ正本）。
+- HO パターン定義: `check-plan-hash.sh` の **`_override=0` 直後の `case` ブロック**（`esac` まで。12 カテゴリ正本）。
   **行番号で参照しない** — 行番号アンカーは実装の移動で黙って別ブロックを指す（#1089 / 記号アンカー化）。
   機械抽出: `awk '/_override=0/{g=1;next} g&&/^[[:space:]]*esac/{exit} g' scripts/hooks/check-plan-hash.sh`
 - WF-04 Build & Refine / WF-05 Verify & Handoff
diff --git a/docs/ai/hook-enforcement.md b/docs/ai/hook-enforcement.md
index 308ca7c..c678287 100644
--- a/docs/ai/hook-enforcement.md
+++ b/docs/ai/hook-enforcement.md
@@ -99,7 +99,7 @@ tracked な [`.claude/settings.example.json`](../../.claude/settings.example.jso
 |---------|-------|------|---------|
 | **`Edit\|Write`** | PreToolUse | [`check-plan-exists.sh`](../../scripts/hooks/check-plan-exists.sh)（EH-1）| plan.md 存在チェック |
 | **`Edit\|Write`** | PreToolUse | [`check-c3-approval.sh`](../../scripts/hooks/check-c3-approval.sh)（EH-2）| C-3 承認ゲート |
-| **`Edit\|Write`** | PreToolUse | [`check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh)（EH-3）| **Hardening Override 9 カテゴリ + plan.md ゲート + plan_hash 改竄** |
+| **`Edit\|Write`** | PreToolUse | [`check-plan-hash.sh`](../../scripts/hooks/check-plan-hash.sh)（EH-3）| **Hardening Override 12 カテゴリ + plan.md ゲート + plan_hash 改竄** |
 | **`Edit\|Write`** | PreToolUse | [`check-forbidden-files.sh`](../../scripts/hooks/check-forbidden-files.sh)（EH-6）| forbidden_files（scope 逸脱） |
 | **`Edit\|Write`** | PreToolUse | [`check-approval-token-write.sh`](../../scripts/check-approval-token-write.sh)（EH-13）| 承認トークン直書き |
 | **`Bash`** | PreToolUse | [`check-approval-token-write.sh`](../../scripts/check-approval-token-write.sh)（EH-13）| 承認トークン直書き（**唯一の両経路配線**） |
@@ -112,7 +112,7 @@ tracked な [`.claude/settings.example.json`](../../.claude/settings.example.jso
 
 #### 明示: ファイル書き込みガードは `Edit|Write` 経路のみ
 
-- **HO 9 カテゴリ / plan.md ゲート / plan_hash 改竄検知（EH-3）**、
+- **HO 12 カテゴリ / plan.md ゲート / plan_hash 改竄検知（EH-3）**、
   **forbidden_files（EH-6）**、**C-3 承認ゲート（EH-2）**、**plan 存在チェック（EH-1）** は
   **`Edit|Write` matcher にのみ配線されている**。
   したがってこれらは **Edit / Write tool 経由の書き込みでのみ強制**され、
@@ -213,9 +213,9 @@ PlanGate の **Iron Law のうち runtime 強制可能な不変条件**（現状
 - **対応**: Hook が次の operation を block。再承認を要求
 - **基盤**: Iron Law #5（承認済 plan と実装差分の整合性）
 
-> **Hardening Override（HO）9 カテゴリの block（`Edit|Write` 経路限定 / #1089 是正済み・`9043536`）**
+> **Hardening Override（HO）12 カテゴリの block（`Edit|Write` 経路限定 / #1089 是正済み・`9043536`）**
 >
-> EH-3 は plan_hash 検知に加え **HO 9 カテゴリの block**
+> EH-3 は plan_hash 検知に加え **HO 12 カテゴリの block**
 > （正本: [`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
 > 承認境界周辺の変更節）を担う **唯一のガード**である
 > （`check-forbidden-files.sh` は HO パスを守らない）。
@@ -234,7 +234,7 @@ PlanGate の **Iron Law のうち runtime 強制可能な不変条件**（現状
 > - 回帰テスト: `tests/extras/ta-65-eh3-ho-task-context.sh`。**期待値の既定は
 >   「TASK 文脈でも block される」**。コードが元の構造へ戻ると CI が RED になる
 > - `.claude/settings*.json` は Claude Code 自身の self-mod ガード（harness 層）でも
->   守られるが、**残る 8 カテゴリに同等の別ガードは確認されていない**
+>   守られるが、**残る 11 カテゴリに同等の別ガードは確認されていない**
 > - **「常時 block」は文字どおりには成立しない（既知の残存・6 系統）**:
 >   1. **経路の欠落（[#1104](https://github.com/s977043/plangate/issues/1104)）**:
 >      `Edit|Write` 以外の書き込みは素通り（§0.1）。**PR #1267 が `Bash` matcher へ
@@ -270,7 +270,7 @@ PlanGate の **Iron Law のうち runtime 強制可能な不変条件**（現状
 >
 >   **2 の実測（旧記述の訂正）**: 旧版はこの残存を **4 ケース**と書いていたが**過少**だった。
 >   #1101 の実測では変換クラスは **7 種**（`..` 往復 / `//` / `/./` / 先頭 `./` / 大小文字 /
->   末尾空白 / repo root 跨ぎの絶対パス）あり、**HO 9 カテゴリ 15 パターンすべて**に対して
+>   末尾空白 / repo root 跨ぎの絶対パス）あり、**HO 12 カテゴリ 20 パターンすべて**に対して
 >   適用できる（`.md` の表記揺れに限らず、`..` 経由で CLI 本体 `bin/plangate` の HO も
 >   迂回できる。実測 rc=0）。
 >
diff --git a/docs/ai/repo-guard.md b/docs/ai/repo-guard.md
index 70ed6d5..07de4be 100644
--- a/docs/ai/repo-guard.md
+++ b/docs/ai/repo-guard.md
@@ -113,7 +113,7 @@ issue #684 は「`plangate doctor` に『必須 git hooks が導入済みか』
 チェック項目を追加」も要望しているが、`bin/plangate` は Hardening
 Override 対象パス
 （[`mode-classification.md`](../../.claude/rules/mode-classification.md)
-の 9 カテゴリ正本）に該当し、**AI が直接編集できない**（常時 block）。
+の 12 カテゴリ正本）に該当し、**AI が直接編集できない**（常時 block）。
 
 したがって、doctor への「pre-push guard 導入済みか」チェック追加は **別
 PBI として起票し、Standard モード・同期 C-3（人間承認）を経て実施する**。
diff --git a/docs/ai/subagent-delegation/README.md b/docs/ai/subagent-delegation/README.md
index f0f0b4e..21882a1 100644
--- a/docs/ai/subagent-delegation/README.md
+++ b/docs/ai/subagent-delegation/README.md
@@ -68,7 +68,7 @@ Agent）へ調査・レビュー・実装を委譲する際の**標準プロト
 同名・同一責務の直接衝突は **無し**（`docs/ai/subagent-delegation/` は新規、既存に
 該当ファイルなし）。ただし整合（棲み分け明記）が必要な隣接資産が 4 つある。§2.5
 で扱う。なお `docs/ai/subagent-delegation/` は
-[`check-plan-hash.sh`](../../../scripts/hooks/check-plan-hash.sh) の 9 カテゴリ HO
+[`check-plan-hash.sh`](../../../scripts/hooks/check-plan-hash.sh) の 12 カテゴリ HO
 パターンに非該当（`docs/` 配下）で承認境界にも抵触せず、mode 引き上げ対象外。
 
 ### 2.5 既存資産との棲み分け（demarcation）
@@ -119,7 +119,7 @@ Agent）へ調査・レビュー・実装を委譲する際の**標準プロト
 
 非 HO の追加導線として `README.md` 主要ドキュメント一覧表・
 [`docs/orchestrator-mode.md`](../../orchestrator-mode.md) の棲み分け節にも直接追記
-できる（HO 9 カテゴリ非該当のため apply-script 不要）。
+できる（HO 12 カテゴリ非該当のため apply-script 不要）。
 
 ## 3. オーケストレータ責務（#710 方針 1 の転記）
 
diff --git a/docs/ai/subagent-delegation/plangate-flow-integration.md b/docs/ai/subagent-delegation/plangate-flow-integration.md
index 71a6df3..3864804 100644
--- a/docs/ai/subagent-delegation/plangate-flow-integration.md
+++ b/docs/ai/subagent-delegation/plangate-flow-integration.md
@@ -91,7 +91,7 @@ issue #715 のやること「`SendMessage` で同一サブエージェントへ
 
 - **C-3 / C-4 ゲート**: 変更しない。サブエージェントが `review=true` でリスク監査（表 1 の #2/#3）を返しても、APPROVE / CONDITIONAL / REJECT（C-3）や APPROVE / REQUEST CHANGES / REJECT（C-4）の**判定主体は人間のまま**（[`working-context.md`](../../../.claude/rules/working-context.md)）
 - **AS-1〜5 / `ChildExecAllowed` / `ParentDone`**（[`.claude/rules/orchestrator-mode.md`](../../../.claude/rules/orchestrator-mode.md)）: 変更しない。親子 PBI の Gate 通過判定に本プロトコルは関与しない。子 PBI exec 中に発生する「Execution 中の限定実装」委譲（表 1 の #4）は、`ChildExecAllowed` が既に成立している前提でのみ行う
-- **`lite_eligible` / C-3 条件付き降格**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md)）: 本プロトコルは lite 判定基準を変更しない。Hardening Override 対象パス（`.claude/rules/*.md` 等 9 カテゴリ）への実装委譲は、[`dispatch-template.md` 4-B](./dispatch-template.md#4-b-実装エージェント向け) の制約欄で **Write/Edit 禁止**を明記する（HO は常時 AI 直接編集不可。[`ho-change-workflow.md`](../ho-change-workflow.md)）
+- **`lite_eligible` / C-3 条件付き降格**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md)）: 本プロトコルは lite 判定基準を変更しない。Hardening Override 対象パス（`.claude/rules/*.md` 等 12 カテゴリ）への実装委譲は、[`dispatch-template.md` 4-B](./dispatch-template.md#4-b-実装エージェント向け) の制約欄で **Write/Edit 禁止**を明記する（HO は常時 AI 直接編集不可。[`ho-change-workflow.md`](../ho-change-workflow.md)）
 - **`subagent-dispatch`（並列 dispatch）との関係**: 高 mode（high-risk/critical）でのロール別並列実行・`dispatch/` ファイル授受は [`plugin/plangate/skills/subagent-dispatch`](../../../plugin/plangate/skills/subagent-dispatch/SKILL.md) の責務のまま。本プロトコルは個々の派遣プロンプトの自己完結性契約を提供するのみで、並列化の判断・分配構造を代替しない（[`README.md`](./README.md) §2.5 参照）
 
 ## 6. HO への接続（本ファイルは非HO）
diff --git a/docs/ai/w6-autonomous-approve-introduction.md b/docs/ai/w6-autonomous-approve-introduction.md
index 6de6bbf..062615b 100644
--- a/docs/ai/w6-autonomous-approve-introduction.md
+++ b/docs/ai/w6-autonomous-approve-introduction.md
@@ -98,7 +98,7 @@ Standard・同期 C-3 を強制。
 ```
 
 > 対象リポジトリの Hardening Override 対象パス一覧（`mode-classification.md` の
-> 9 カテゴリ）が plangate 本体と異なる場合は、貼り付け前に「HO 対象パスを含む変更」
+> 12 カテゴリ）が plangate 本体と異なる場合は、貼り付け前に「HO 対象パスを含む変更」
 > の判定基準を対象リポジトリの実際のパス構成に合わせて調整すること（機械的なコピペ
 > だけで終わらせない）。
 
@@ -211,7 +211,7 @@ W6IntroductionGapDetected =
 - [`.claude/rules/working-context.md`](../../.claude/rules/working-context.md)
   「C-3 Autonomous APPROVE」節（W-6 正本）
 - [`.claude/rules/mode-classification.md`](../../.claude/rules/mode-classification.md)
-  （5 段階モード分類 + AC-10 Hardening Override 対象パス 9 カテゴリ）
+  （5 段階モード分類 + AC-10 Hardening Override 対象パス 12 カテゴリ）
 - [`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
   （AI-owned / Human-owned 境界の正本）
 - [`docs/ai/project-rules.md`](./project-rules.md)（AI 運用 4 原則）
diff --git a/scripts/hooks/check-plan-hash.sh b/scripts/hooks/check-plan-hash.sh
index 5cf7762..0a47f85 100755
--- a/scripts/hooks/check-plan-hash.sh
+++ b/scripts/hooks/check-plan-hash.sh
@@ -324,8 +324,8 @@ fi
 # ===== Hardening Override 判定（#1089 / TASK-1089）=====
 # TASK 文脈（PLANGATE_HOOK_TASK / $1）の有無に依存せず評価する。TASK-0106 では
 # 本判定が no-task 分岐の内側にあったため、TASK 設定時は plan_hash 検証パスへ
-# 抜けて 9 カテゴリすべてが一度も評価されなかった（#1089）。
-# 判定内容・9 カテゴリ・「maintenance 窓内でも常時 block」は不変（R-003/R-015）。
+# 抜けて HO 判定が一度も評価されなかった（#1089。当時は 9 カテゴリ）。
+# 判定内容・HO カテゴリ集合・「maintenance 窓内でも常時 block」は #1089 では不変（R-003/R-015）。
 # 優先順は BYPASS > Override > (no-task: maintenance/doc-light/SKIP_REASON,
 # task: plan_hash 検証)。
 # (i) target_file 正規化（R-028）
@@ -361,7 +361,7 @@ fi
 
 # (ii) Hardening Override 物理先頭判定（R-003/R-015、maintenance より上）
 # 判定対象は _ho_key（小文字化済み）。したがって case は**小文字側で受ける**。
-# ラベル 9 行 / パターン 15 個。9 カテゴリの正本は
+# ラベル 12 行 / パターン 20 個。12 カテゴリの正本は
 # .claude/rules/mode-classification.md の Hardening Override 節（内容は不変）。
 _override=0
 case "$_ho_key" in
@@ -374,6 +374,11 @@ case "$_ho_key" in
   schemas/*.schema.json) _override=1 ;;
   .github/workflows/*.yml|.github/workflows/*.yaml) _override=1 ;;
   agents.md|claude.md) _override=1 ;;
+  # (#1226) 他 Provider の enforcement 配線と承認トークンガード本体。
+  # .claude/settings*.json が HO であることとの非対称の解消。skills は対象外。
+  .codex/hooks.json|.cursor/hooks.json) _override=1 ;;
+  .codex/hooks/*.sh|.cursor/hooks/*.sh) _override=1 ;;
+  scripts/check-approval-token-write.sh) _override=1 ;;
 esac
 if [ "$_override" = "1" ]; then
   # AC-9: 監査ログと reason には**生の要求パス**を残す（正規化後の値ではない）。
`````
<!-- PG-PATCH-END -->

### 適用手順（Human / repo root で実行）

1. 上記 `sed` で patch を抽出し、`git apply --check` が rc=0 であることを確認する
2. `git apply /tmp/1226-approval-surface.patch`
   （**先に #1234 の patch を当てている場合は `git apply -3` または `patch -p1`。§8-5 の実測に従う**）
3. **§4.4 の grep を実行し、`tests/extras/ta-77-approval-surface-gate.sh` 以外に「9 カテゴリ」が残らないことを確認する**（実装だけ 12 で規範が 9 のまま、という本 issue と同型の状態を作らない）
4. **`sh scripts/sync-plugin-plangate.sh` を実行し、`plugin/plangate/rules/mode-classification.md` の差分をコミットする**
   — **これを飛ばすと `sync-plugin-plangate.yml` の `drift-check` job が `exit 1` で即 FAIL する**。
   同 job は `pull_request.paths` の `.claude/**` で起動し、本 patch は `.claude/rules/` と
   `.claude/skills/` を変更するため**必ず起動する**。`plugin/plangate/rules/mode-classification.md` は
   正本と byte 一致のミラーである（適用前実測: `cmp` rc=0）
5. **`sh scripts/install-plangate-skills-to-codex.sh --force` を実行し、`.codex/skills/` の差分をコミットする**
   — これを飛ばすと PATCH-B の新ステップが既存 10 件の drift で即 FAIL する
6. `sh tests/run-tests.sh` を実行し、**適用前に取った baseline と比較**して新規 FAIL が無いことを確認する（絶対件数を契約値にしない）。
   `tests/extras/ta-77-approval-surface-gate.sh` は台帳更新を要求しうる（§8-6）
7. `sh scripts/apply-claude-settings.sh` は**不要**（settings 変更なし）
8. PATCH-A 適用後は `.codex/hooks.json` / `.cursor/hooks*` / `scripts/check-approval-token-write.sh` が **AI から編集不能**になる。以後これらの変更は本書と同形の patch 文書経由になる

> 手順 4 と 5 は**同じ型の前提**である（生成物を再生成してコミットしないと CI が落ちる）。
> どちらか一方だけを警告する非対称を残さないため、両方を同じ強度で記載している。

---

## 6. 残存脅威モデル（完全性を主張しない）

### 守る（PATCH-A / PATCH-B 適用後）

- `Edit`/`Write` 経路での、字句上の表記揺れを含む Codex / Cursor 配線ファイルおよび EH-13 本体への書込（#1101 の正規化が効く範囲で）
- `.codex/skills/**` の `SKILL.md` / `references/*.md` が正本 `.agents/skills/**` から乖離した状態での PR マージ（CI が赤くなる範囲で）
- `.codex/skills/` にだけ存在する skill / references（逆方向検査）

### 守らない

| 残存 | 内容 | 追跡 |
|---|---|---|
| Bash 経路 | `Bash` matcher は `file_path` を持たず `target_file` が空になるため HO 判定に一致しない。`sed -i` / heredoc での書換は止まらない | #1104 |
| symlink / FS エイリアス | EH-3 の正規化は字句のみ。`.cursor/skills/plan-review-gate` が実在する symlink であることが具体例 | #1264 / #1234 |
| worktree 配下 | `_ho_key` が `REPO_ROOT` 前置きに固定される | #1277 |
| **CI が advisory** | 実測（`gh api repos/s977043/plangate/rulesets/14939019`）: required status check は **`Markdown lint` 1 本のみ**、`required_approving_review_count: 0`。**PATCH-B の検査が赤でもマージできる** | #928 |
| **`scripts/` 直下の他 2 guard** | `scripts/check-git-destructive.sh`（EH-12）/ `scripts/gh-pin-account.sh` は `.claude/settings.example.json` から wire されているが `scripts/hooks/*.sh` に該当せず**非 HO のまま**。本 patch は承認トークンを守る EH-13 だけを HO にした。**「非対称の解消」は EH-13 に限った部分適用である** | §7-6（Human 判断） |
| **`agents/openai.yaml` / `assets/`** | PATCH-B の byte 比較の対象外（生成物 / per-skill 正本なし）。`openai.yaml` の内容改竄は本検査では検出しない | 新規（follow-up 候補） |
| 導入先 | plugin 配布物に `scripts/hooks/` も CLI も含まれない。導入先では HO そのものが存在しない | #1144 |
| `PLANGATE_BYPASS_HOOK=1` | 常時 exit 0 | 既知 |
| 散文正本の面 | `.agents/skills/**` / `docs/**` / `workflows/*.yaml` は依然 HO 外。PATCH-B が守るのは「正本とコピーの一致」であって「正本そのものの改変」ではない | 本 issue の残り・#1263 |
| **宣言面の追随の機械強制** | §4 の 12 面は**本 patch で一度に揃える**が、以後「新しい宣言面が増えたら追随する」ことを機械で強制する仕組みは無い（ta-77 は宣言ブロックの digest を見るが、カテゴリ数の記述は宣言ブロック外にありうる） | 新規（follow-up 候補） |
| hook 実走での確認 | 本書の HO 判定は `fnmatch` 再現による静的照合であり、`sh scripts/hooks/check-plan-hash.sh` の rc を実測していない | §7 |

EH-3 の HO block は**多層防御の 1 層**にすぎない。承認境界の最終的な保証主体は **C-4 Human レビュー**と **GitHub ruleset** である。

---

## 7. Human 判断に送る事項

1. **EH-13 を Codex / Cursor にも配線するか**（現在は `.claude/settings.example.json` のみ。新しい block クラスを増やす判断）
2. **`.codex/hooks/eh-bridge.sh` の未知 rc = `allow`（fail-open）を `deny` に倒すか**（可用性とのトレードオフ）
3. **PATCH-B の検査を required status check に加えるか**（#928 の一部。ruleset 操作は Human-owned）
4. **`.cursor/hooks.json` の `failClosed: false` を `true` にするか**
5. **`.agents/skills/**` の散文正本を HO に入れるか**（本書は symlink 迂回と保守コストを理由に入れない設計にした。入れる場合は symlink 解決を先に片付ける必要がある — #1264）
6. **`scripts/check-git-destructive.sh`（EH-12）と `scripts/gh-pin-account.sh` を HO に入れるか**
   — `.claude/settings.example.json` から wire される `scripts/` 直下の guard は EH-13 を含めて **3 本**あり、本 patch は EH-13 だけを HO にした（§1）。
   前者 2 本は「承認トークンの受理判定」を持たないためスコープ外としたが、
   **`check-git-destructive.sh` は main への `push --force` を止める最後の技術層**であり、
   AI が編集できる位置にある点は EH-13 と同型の非対称である。
   入れる場合はパターンを個別列挙にするか `scripts/check-*.sh` にするかも同時に決める必要がある
7. **本 patch の HO 判定を hook 実走で検証するか**（本書は `fnmatch` 再現による静的照合。適用後に `tests/extras` で rc を実測する TC を起こすかどうか）

---

## 8. 適用チェックリスト

| # | 項目 | 結果 |
|---|---|---|
| 1 | repo root で `git apply --check` | §5 の実測に記載（**rc=0**） |
| 2 | HO 判定の before/after | §1 表 + §4 変異（次節） |
| 3 | `.codex/skills` drift の実測 | §2 表（10 / 40。行数の定義は §2 に明記） |
| 4 | 偽陽性の確認（skills を HO にしない） | 変異 M-3 |
| 5 | `#1234` / `#1278` の patch との併用順 | **§8-5 の実測に従う（旧版の記述は誤り）** |
| 6 | `tests/extras` の新規 TC | **未作成**（`.sh` は本セッションで作成不可。`tests/` は並行作業中のため読取のみ）。仕様は変異表。`ta-77` の台帳追随要否も適用時に確認 |
| 7 | `docs/ai/hook-enforcement.md` 残存脅威モデルへの追記 | **本 patch のハンクで 9 → 12 の数だけ更新済み**。「7 番目のクラス」の追記は follow-up |
| 8 | 宣言面の全数更新 | §4（12 面）+ §4.4 の差集合 grep |
| 9 | plugin ミラーの再生成 | §5 手順 4 |

### 8-5. `#1234` / `#1278` との併用（サンドボックス実測 / 旧版の訂正）

旧版は「hunk 非重複ゆえ不問。#1234 を先に当てると行番号が動くため `git apply -3` もしくは
本 patch を先に当てること」と書いていたが、**両方とも誤り**だった。実測:

- **3 本とも `scripts/hooks/check-plan-hash.sh` を触り、#1234 と本 patch は行番号が干渉する**。
  順序を入れ替えても**失敗が移動するだけ**である。
- 旧版の 3 本の patch は**いずれも `index` 行を持たなかった**ため、`git apply -3` は
  3-way merge に必要な blob を引けず `repository lacks the necessary blob to perform
  3-way merge` で失敗する（`-3` の案内は成立していなかった）。
- **本 patch は `index` 行を持つ形に改めた**ため、`git apply -3` が使える。

サンドボックス（`git init` した最小 repo に対象 3 ファイルを置いた実測）:

| 順序 | 2 本目の適用 | 実測 rc |
|---|---|---|
| #1234 → #1226 | `git apply`（旧 patch） | **1**（`patch failed: scripts/hooks/check-plan-hash.sh:361`） |
| #1234 → #1226 | `git apply -3`（旧 patch / `index` 行なし） | **1**（`repository lacks the necessary blob`） |
| #1234 → #1226 | `patch -p1` | **0** |
| #1226 → #1234 | `git apply` | **1**（`patch failed: scripts/hooks/check-plan-hash.sh:375`） |
| #1226 → #1234 | `patch -p1` | **0** |
| #1278 → #1226 | `git apply` | **0** |
| #1226 → #1278 | `git apply` | **0** |

**確定した手順**:

1. **#1278 は順序不問**（`git apply` で両順序 rc=0。`log_event`（`@@ -23`）だけを触り干渉しない）
2. **#1234 と #1226 は同一領域（`@@ -358` / `@@ -361`）で干渉する**。どちらを先に当てても
   2 本目の `git apply` は失敗する。**2 本目は `patch -p1` で当てる**（両順序 rc=0 実測）。
   本 patch は `index` 行を持つため `git apply -3` も選べるが、**#1234 の patch 文書側は
   依然 `index` 行を持たない**ので、#1226 → #1234 の順では `patch -p1` が唯一の手段になる
3. 実測した通し手順（3 本すべて / rc すべて 0）:

   ```sh
   git apply /tmp/1278-log-event.patch          # rc=0
   git apply /tmp/1226-approval-surface.patch   # rc=0
   patch -p1 < /tmp/1234-eh3-outside-repo.patch # rc=0
   ```

   適用後の `case` ブロックで**既存 15 パターンが逐語不変**であること、および
   `*.rej` / `*.orig` が生成されないことを実測済み

### 変異注入（検出力）

| 変異 | 期待 | 実測 |
|---|---|---|
| M-1: PATCH-A の `.cursor/hooks/*.sh` 行を削除 → `.cursor/hooks/plangate-eh2-c3.sh` を照合 | `non`（block されない） | `non`（fnmatch 再現。patch 適用形では `HO`） |
| M-2: PATCH-A の `scripts/check-approval-token-write.sh` 行を削除 → 同パスを照合 | `non` | `non`（適用形では `HO`） |
| M-3: PATCH-A 適用形で `.codex/skills/plan-review-gate/SKILL.md` を照合 | `non`（skills は意図的に対象外） | `non` — **偽陽性なし** |
| M-4: PATCH-B の `cmp` を `cmp -s ... \|\| true` に変異 | 常に rc=0 | 現 main の 10 件 drift を検出しなくなる |
| M-5: PATCH-B の missing 分岐を `continue` のみに変異 | `.codex/skills/plan-review-gate/` を削除しても PASS | 削除が素通り |
| M-6: PATCH-B を適用し `pull_request.paths` の `.codex/skills/**` 追加を外す | `.codex/` のみの PR で job 不起動 | 検査が存在しても発火しない（#1259 と同型） |
| **M-7: `diff -u ... \| head -40` から `\|\| true` を外す**（＝旧版の形） | `bash -eo pipefail` 下で 1 件目の乖離でステップ終了 | **実測: `::error::` 1 行のみ・`LOOP_END` に到達せず rc=1。`\|\| true` 付きでは 10 件すべて報告し `LOOP_END rc=1`**（positive control） |
| **M-8: 逆方向ループを削除** | `.codex/skills/` にだけ存在する面が素通り | **実測: フィクスチャ（`.codex/skills/rogue/` + 正本に無い `references/extra.md`）に対し逆方向ループ有りで 2 件検出 rc=1、現 main に対しては 0 件 rc=0**（positive / negative control 両方） |

**HO 判定の再現方法の妥当性**: `case` の glob と `fnmatch.fnmatchcase` の一致は、現行 15 パターンに対する positive control（`.claude/rules/working-context.md` / `scripts/hooks/check-plan-hash.sh` / `bin/plangate` / `schemas/c3-approval.schema.json` / `CLAUDE.md` / `AGENTS.md` / `.claude/agents/orchestrator.md` / `.github/workflows/ci.yml` / `.claude/commands/ai-dev-workflow.md` の 9 件すべてが `HO`）と negative control（`docs/ai/plan-normalization-gate.md` / `README.md` が `non`）で確認した。**hook 本体を `sh` で実走した測定ではない**（本セッションの実行環境が `sh` 起動を拒否する）。この点は §6 に残存として記載する。
