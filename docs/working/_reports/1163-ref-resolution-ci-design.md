# #1163 参照解決順 機械ゲート — 検出器 設計書

> **本書は設計のみ。実装（`scripts/` / `.github/workflows/` / `tests/`）は含まない。**
> 差分は本書内に提示する。

| 項目 | 値 |
|---|---|
| 起点 | `origin/main` = `33d8de8` |
| 対象 issue | [#1163](https://github.com/s977043/PlanGate/issues/1163) |
| 先例 | PR #1158（クラス C の plugin root 段除去 / 変異 M2・M4） / **PR #1164 = MERGED**（`7134f68`。クラス A の梯子を 4 skill に追加） |
| 検証環境 | 使い捨てサンドボックス（本書 §7 / 付録。リポジトリには残さない） |
| 版 | **rev1**。独立 2 本のレビュー（RiverReview / 敵対レビュー）の統合指摘 F-1〜F-19 を反映し、§6 の実測値を **`33d8de8` で全面再測定**した |

## rev1 で変わった点（先に読む）

| # | 変更 | 根拠 |
|---|---|---|
| 1 | known-gap を件数ではなく **`(file, target)` の tracked allowlist** で pin する。list 外の violation は rc=1 / list にあるのに検出されない entry は **stale として FAIL** | F-1（両レビュー独立一致）。`ta-65` の 3 性質を継承 |
| 2 | §9.2 と §11.2 の矛盾を解消。**I-1 / I-3 も rc に寄与する**（allowlist との差分に対して） | F-1 |
| 3 | plugin root プレースホルダ語彙を**実測ベースの明示定数**へ差し替え（角括弧形は現 main に **0 件**、実体は山括弧形 38 件） | F-6 |
| 4 | `rules/*.md` ワイルドカード免除条項を**削除**。代わりに **パラメタ化梯子のスコープ束縛**を導入 | F-3 ＋ 本 rev1 の新規実測（§3.3） |
| 5 | `referenced` を **rules 正本 basename の実行時導出 × 本文出現**へ（`.claude/` 前置の有無を問わない） | F-15 |
| 6 | **AC-1 は現 scope では達成不能**であることを明記し、**AC-1 の再定義を C-3 の Human 判断事項として起票**（AI は選ばない） | F-7 |
| 7 | 走査 root を `plugin/*/skills` の **glob 列挙**へ。enforced root ごとに **走査ファイル数 > 0** を rc 寄与条件に追加 | F-17 / F-18 |
| 8 | `ta-70` の骨子に #921 実行契約（marker / bootstrap / init / finalize）を明記。`ta-69` の配線レジストリを `-f` から**実行証跡の照合**へ | F-19 / F-16 |

---

## 0. 前提となるクラス定義

| クラス | 参照先 | plugin 配布実体 | 正しい解決順 |
|---|---|---|---|
| **クラス A** | `.claude/rules/*.md` | `plugin/plangate/rules/` に **6 件実在**（実測） | 導入先 → **plugin root 配下** → 未参照明示 |
| **クラス C** | `docs/**` / `schemas/**` | `plugin/plangate/docs` / `plugin/plangate/schemas` は **tracked 0 件**（実測） | 導入先 → 未参照明示（**plugin root 段を置かない**） |

実測（`git ls-tree -r 33d8de8 --name-only -- <path>`）:

- `plugin/plangate/docs` + `plugin/plangate/schemas` … **0 件**（ツリー自体が不在）
- `plugin/plangate/rules` … **6 件**（集合として列挙）:
  `hybrid-architecture.md` / `mode-classification.md` / `orchestrator-mode.md` /
  `responsibility-classes.md` / `review-principles.md` / `working-context.md`

**この非対称（rules は配布される / docs・schemas は配布されない）が 3 不変条件すべての根拠**である。
この 6 件は **検査実行時に `plugin/plangate/rules/*.md` から導出**する（ハードコードしない）。
`ta-65` が HO カテゴリを hook 本体の `case` 文から導出するのと同じ思想であり、
正本が増減しても検査が黙って狭くならない。

---

## 1. 走査 root の宣言と enforcement scope

**root は宣言的に列挙し、宣言した root が不在なら enforcement 対象か否かに関わらず violation** とする（`scripts/check-codex-skill-spec.sh` の #1109 R-001 と同じ思想。「見に行く先が無い」を緑にしない）。

| root | tracked SKILL.md | tracked `*.md` | 配布経路上の役割 | I-1 | I-2 | I-3 | 根拠 |
|---|---:|---:|---|:--:|:--:|:--:|---|
| `.agents/skills` | 39 | 45 | **正本**（sync / codex installer の source） | 強制 | 強制 | 強制 | `sync-plugin-plangate.sh` の `SKILLS_DIR` / `install-plangate-skills-to-codex.sh` の `SOURCE_DIR` |
| `plugin/plangate/skills` | 39 | 66 | **配布実体**（marketplace が読む） | 強制 | 強制 | 強制 | `install.sh` の `PLUGIN_DIR` |
| `.claude/skills` | 29 | 41 | **どの配布経路の source でもない** | 対象外 | 対象外 | 対象外 | §1.1 |
| `.codex/skills` | 39 | 42 | drift 中・**#956 判断待ち** | report-only | report-only | report-only | §10 |

強制 root の `*.md` 合計は **111**（45 + 66）。

配布 source の実測（3 経路とも `.claude/skills` を source にしていない）:

- `install.sh` … `PLUGIN_DIR` は `plugin/plangate`
- `scripts/sync-plugin-plangate.sh` … `SKILLS_DIR` は `.agents/skills`
- `scripts/install-plangate-skills-to-codex.sh` … `SOURCE_DIR` は `.agents/skills`（環境変数で上書き可）

**アンカーは宣言変数名（`PLUGIN_DIR` / `SKILLS_DIR` / `SOURCE_DIR`）を主とし、行番号は書かない。**
行番号は実装の移動で黙って別の行を指す（#1089）。本書 rev0 は issue 本文の行番号を
「訂正」しようとして逆に誤っていた（F-2）ため、訂正記述自体を削除した。

### 1.1 `.claude/skills` を 3 不変条件の対象外にする理由

`.claude/skills` は上記 3 経路のいずれの source でもない。ここに閉じた skill は **導入先へ配布されないため、`docs/` も `.claude/rules/` も常にローカルで解決する**。したがって梯子も解決順注記も不要であり、対象に含めると AC-3 の 4 skill（`hypothesis-logger` / `plan-quality-reviewer` / `plangate-working-discipline` / `pr-watch`）で誤検出する。

**実測（`33d8de8`）**: `.claude/skills` を強制対象にすると I-3 が **10 件**発火する（集合）:

`README.md` / `ai-loop-cycle/SKILL.md` / `hypothesis-logger/SKILL.md` /
`plan-quality-check/SKILL.md`（docs・schemas の 2 件）/
`plangate-working-discipline/SKILL.md` / `plangate-working-discipline/approval-gate-template.md` /
`plangate-working-discipline/verification-report-template.md` / `pr-watch/SKILL.md` /
`subagent-driven-development/SKILL.md`

→ AC-3 の 4 skill のうち 3 本（`hypothesis-logger` / `plangate-working-discipline` / `pr-watch`）が含まれる。**対象外が正しい。**

`.claude/skills` は「**宣言はするが 3 不変条件は適用しない root**」として理由付きで manifest に残す。ディレクトリごと消えた場合は root 不在 violation で気づける。

### 1.2 root 集合の宣言の仕方（F-17）

`DECLARED_ROOTS` を**固定文字列だけ**で持つと、`plugin/<新プラグイン>/skills` が
追加されたときに **宣言していないので不在にもならず、violation 0 件で緑になる**。
v8.20.0 で `plugin/plangate/.codex-plugin/` が新設された（#1085）ように、配布経路は増える。

先行検査 `scripts/check-skill-frontmatter.py` の `discover_skill_roots()` は
**`plugin/*/skills` を動的列挙**している（`plugin_dir.iterdir()` で子ディレクトリを走査）。
本検査もこれに合わせる:

- `.agents/skills` / `.claude/skills` / `.codex/skills` は固定宣言
- **`plugin/*/skills` は glob 列挙**（実測: 現 main の `plugin/` 配下は `plangate` のみ。
  glob 化しても実測値は変わらない）
- `DECLARED_ROOTS` は「**除外の宣言**」（`EXEMPT_ROOTS` / `DEFERRED_ROOTS`）に限定し、
  「対象の宣言」を固定リストに閉じない

### 1.3 root が「存在するが空」のとき緑にしない（F-18）

「宣言 root が不在なら violation」は**ディレクトリの存在しか見ていない**。
`.agents/skills/` が存在して中身 0 件（sparse checkout / `actions/checkout` の filter 誤設定 /
glob 失敗 / シンボリックリンク化）だと violation 0 → rc=0 → **緑**になる。

したがって **`ENFORCED_ROOTS` の各々について「走査対象 `*.md` が 1 件以上」を rc 寄与条件に加える**。

これは絶対件数の契約ではなく**下限（> 0）**であり、#1087 AC-9 の禁止対象ではない。
先例として `ta-61` は `TA-61 discovery: runtime inventory non-empty ($_T61_DISC_COUNT files)`
（`-gt 0`）と `TC-25(1): covered set minus self is non-empty` の 2 段で非空を assert している。

---

## 2. スコープ設計（段落／セクション単位）

**行スコープは使わない。** PR #1158 のレビューで、行スコープは「docs 参照の行」と「plugin root 段の行」が別行に分かれたブロック形式の欠陥を取り逃す（**変異 M4 が生存**）ことが実証済み。

### 2.1 セグメンテーション規則

Markdown を以下の境界で **セグメント**に分割する（1 パス・状態機械）。

| 境界 | 扱い |
|---|---|
| 空行 | セグメント終了 |
| ATX 見出し | それ自体が 1 セグメント（かつ**セクション境界**） |
| 表の行（行頭が縦棒） | 1 行 = 1 セグメント（表の各行は互いに独立した主張） |
| リスト項目（`-` / `*` / `+` / `N.` / `N)`） | **項目ごとに新セグメント**。継続行（インデント）は同一セグメントに連結 |
| 引用（行頭 `>`）の開始 | 直前が引用でなければ新セグメント |
| フェンス（3 連バッククォート / チルダ） | フェンス全体で 1 セグメント。**判定からは除外**（例示コードを欠陥にしない） |

**リスト項目を必ず割ることが要点**である。`review-gate/references/ui-ux-lane.md` の「関連」節は

- 1 行目: `docs/ai/external-reviewer-interface.md` を指す**裸の参照** + 「plugin root 段は docs には適用しない」という禁止注記
- 2 行目: `.claude/rules/mode-classification.md` を指す**別ターゲットの fallback**（plugin root 梯子あり）

という並びで、**裸参照の直後の行から別ターゲット用の fallback が始まる**。行距離・段落連結では必ず誤判定する（実測: 段落連結版では 2 件の誤検出が出た）。

### 2.2 セクション

見出しから次の見出しの直前までを **セクション**とする。I-3 の「注記の作用範囲」に用いる。

### 2.3 梯子ブロック（ladder block）の抽出 — **マーカー非依存**

「参照解決順」という語の有無に依存させない。以下のいずれかを梯子ブロックの起点とする。

- **(a)** 「参照解決順」を含むセグメント（見出し・段落・引用・リスト項目のいずれでも可）
- **(b)** **番号 1 から始まる順序付きリスト**であって、そのリスト全体が解決語彙（`無ければ` / `見つからなければ` / `参照できなかった` / `どちらにも無い` / `次の順で探す` / `この順に探す`）を含むもの

起点から、後続の「順序付きリスト項目」または「`(N)` 手順記法を含むセグメント」を、見出し・表・フェンスに当たるまで連結してブロックとする。**(b)** の場合はリスト直上の導入段落をブロックに含める（Markdown の list lead-in は構造上そのリストのスコープ宣言である。**行距離ではなく構造で結合する**）。

**(b) を入れる理由**: (a) だけだと「参照解決順」という語を使わずに梯子を書いた新規 skill を取り逃す。実証: §7 の変異 **M3b** が (a) のみの版で **SURVIVE**、(b) 追加後に **KILL**。

### 2.4 手順（step）の切り出しと文末終端

ブロック内の手順は次のように切り出す。

- 順序付きリスト項目 → 1 項目 = 1 手順（最初の句点まで）
- 段落・引用の中の `(N)` / 全角括弧記法 → 次の記法直前まで、**ただし最初の句点で打ち切る**

**句点で打ち切ることが必須**である。`plan-review-gate` のクラス C 注記は「… (2) 見つからなければ … 推測で内容を補わない。**plugin root 配下の探索は `docs/**` には適用しない**: …」の形で、**禁止文が手順 (2) の直後に続く**。句点で切らないと禁止文が手順 (2) に吸収され、健全な現行 main が誤検出になる。

#### 2.4.1 句点打ち切りの既知の破れ方（F-11 / 変異 M3c）

句点打ち切りは「禁止文を手順から外す」ためのものだが、**欠陥段そのものが 2 文で書かれると第 2 文が手順から外れる**という逆方向の穴を持つ。例:

```text
(2) 無ければ次の候補を探す。plugin root 配下の同名パス。
```

第 1 文には plugin root の言及が無いため I-2b は発火しない。人が自然に書く注記は複文になりやすく、これは意図せず踏める。

したがって **変異 `M3c`（M3 の注入テキストを 2 文に分割）を §7 に追加し、現行アルゴリズムで SURVIVE することを実証したうえで**、打ち切り条件を「句点」から **否定文・禁止文の構造**（`〜しない` / `〜適用しない` / `〜は置かない` を含む節で切る）へ改める。SURVIVE の実証を先に置くのは、変異が本当に穴を突いているかを記録に残すためである（M3b と同じ扱い）。

### 2.5 ターゲット束縛（近接ヒューリスティック禁止）

手順が扱う**ターゲットのクラス**を次で決める。

1. 手順テキスト内に明示パスがあればそれ（`docs/` / `schemas/` / `rules/`。`.claude/rules/x.md` や plugin root 配下の `rules/x.md` も `rules` と判定する）
2. 明示が無いときのみ、**そのブロックのスコープ宣言**（起点セグメント）のクラスを継承する

「直前の行 / 近い行」という距離は一切使わない。§2.1 の 2 行の例では、2 行目は自身に `rules/` を持つため `rules` に束縛され、1 行目の `docs` を継承しない。**この 1 点を落とすと `ui-ux-lane.md` が確実に誤検出になる**（プロトタイプで実際に 2 件出た）。

---

## 3. I-1 の判定アルゴリズム

> **`.claude/rules/*.md` を参照する配布 skill は plugin root 配下 `rules/` の梯子を持つ。**

対象: **強制 root** 配下の全 `*.md`（`SKILL.md` と `references/*.md` の両方。フェンス内は除外）。

### 3.1 plugin root プレースホルダ語彙（**実測ベースの明示定数** / F-6）

rev0 は「角括弧形 / `CLAUDE_PLUGIN_ROOT` 形 / `plugin/plangate` リテラル」と書いていたが、
**角括弧形は現 main に 1 件も存在しない**。強制 root（`*.md` 111 件）での実測:

| 表記 | 出現ファイル数（`33d8de8`） | 採否 |
|---|---:|---|
| `[plugin_root]`（角括弧形） | **0** | 記述誤り。削除 |
| `<plugin_root>`（山括弧形） | **38** | **採用**（実体はこちら） |
| `${CLAUDE_PLUGIN_ROOT}` | **38** | **採用** |
| `$CLAUDE_PLUGIN_ROOT`（波括弧なし） | 0 | 将来形として採用（明示定数に含める） |
| `plugin/plangate`（リテラル） | 18 | **採用** |
| `<plugin-root>` / `[plugin root]` / `{plugin_root}` | 0 | 採らない |
| 散文 `plugin root` | 46 | I-2b の散文検出でのみ使う（§4.2） |
| 散文 `plugin ルート` | **0** | 現時点で不在。L-4 の語彙リストには残す |

実体例: `.agents/skills/skill-creator/references/review-default.md`
「Otherwise `<plugin_root>/rules/review-principles.md` for the Claude marketplace plugin.」

**記述どおりに literal 実装した場合の実測影響**（山括弧形を語彙から外して測定）:
I-1 が **6 → 42**（+36 の偽陽性）。誤検出には `skill-creator/references/review-default.md` /
`acceptance-review` / `ai-dev-exec` / `ai-dev-plan` / `ai-dev-verify` / `local-exec-handoff` /
`review-gate` / `ui-ux-lane.md` などが含まれる。
**設計書の記述とプロトタイプ実装が一致していなかった箇所であり、rev1 で実測へ合わせた。**

### 3.2 `referenced` の取り方（**パス表記に依存しない** / F-15）

rev0 は `referenced` を「本文中の `.claude/rules/<basename>` 参照の basename 集合」と
定義していた。これは**プレフィクスなしで正本を名指しする書き方が素通りする**。

実例（`33d8de8`）: `.agents/skills/review-gate/SKILL.md` の
「- Rule: `mode-classification.md`（Mode 別フェーズ適用マトリクス・発火条件の正本）」
は正本の名指しだが `.claude/rules/` を伴わないため **I-1 が原理的に発火しない**。

さらに悪いことに、導入後は「**I-1 に引っかかるので `.claude/rules/` を消す**」のが
最も安い回避策になる（梯子を書くより短く、diff は 1 語の削除、レビューでは
「パス表記の整理」に見える）。**検出器が回避行動を教育する構造**である。

したがって rev1 では:

- `referenced` = **rules 正本 basename の集合**（§0 のとおり `plugin/plangate/rules/*.md` から
  **実行時導出**）**× 本文（フェンス除外）への出現**。`.claude/` の有無を問わない
- `laddered` = §3.3 の規則で束縛された basename 集合
- **violation = `referenced` − `laddered`**（`(file, basename)` の対）

**実測影響**（`33d8de8` / 強制 root）: I-1 が **6 → 33**（+27）。増加分のファイル集合:

`.agents/skills/acceptance-review/SKILL.md` / `.agents/skills/ai-dev-plan/SKILL.md` /
`.agents/skills/review-gate/SKILL.md` / `.agents/skills/review-gate/references/ui-ux-lane.md` /
`plugin/plangate/skills/` の同名 4 本 /
`plugin/plangate/skills/ai-loop-cycle/references/` の
`00_concept.md` / `execution-runbook.md` / `flow-detect.md` / `ho-paths.md` /
`hotl-merge-entry-criteria.md` / `lite-criteria.md` / `review-feedback-loop.md` /
`stop-rollback.md` / `unknown-discovery.md`（および既出 4 本の追加ターゲット）

この +27 は**新たに壊れたのではなく、rev0 の検出器が構造的に見えていなかった実在の欠陥**である。
§6 の AC-1 判断（F-7）に直接効くため、増分を明示して Human 判断へ送る。

**偽陽性リスクと緩和**: 「正本と同名の別ファイル」を語っている文脈まで拾いうる。
緩和は (i) フェンス除外、(ii) §11.2 の known-gap allowlist（`(file, target)` 単位で
`reason` 付きで pin できる）、(iii) AC-3 の偽陽性チェックを §8 のとおり
「走査されたうえでゼロ」と「対象外だから出ない」に分けて検証すること。

### 3.3 `laddered` の取り方 — ワイルドカード免除の削除とパラメタ化梯子（F-3 + rev1 実測）

rev0 は「`rules/*.md` というワイルドカード梯子は全 basename を満たすとみなす」としていた。
**これは削除する。**

理由 1（rev0 内部の矛盾）: 同じ §3 の 2 段落後で「ファイル単位（梯子が 1 個でもあれば OK）に
すると PR #1158 の変異 M2 と同型の FN になる」と書いており、両立しない。

理由 2（**rev1 実測**）: `33d8de8` の強制 root で「`rules/*.md` を含み、かつ同一セグメントに
plugin root プレースホルダを持つ」ファイルは **24 / 111**（12 skill × 2 root）:

`acceptance-review` / `ai-dev-brainstorm` / `ai-dev-exec` / `ai-dev-plan` / `ai-dev-verify` /
`breakdown-gate` / `codex-mvp-split` / `local-exec-handoff` / `manual-cloud-task` /
`plangate-setup` / `review-gate` / `working-context`（いずれも `.agents/skills` と
`plugin/plangate/skills` の両方）

ワイルドカード条項を実装すると、この 24 ファイルは **以後どんな rules 参照を足しても I-1 が
発火しない**。`breakdown-gate` は §7 の変異 **M1a** の注入先そのものであり、実際に検証した:

| 条件 | baseline I-1 | M1a 注入後 I-1 | 判定 |
|---|---:|---:|---|
| ワイルドカード条項 **なし**（rev1 採用形） | 6 | **7** | **KILL** |
| ワイルドカード条項 **あり**（rev0 記述どおり） | 6 | **6** | **SURVIVE** |

→ **rev0 の記述どおりに実装すると AC-2 の主要変異が 1 本死ぬ。** 削除が正しい。

一方、`33d8de8` には**パラメタ化された梯子**が実在する。`plan-review-gate/SKILL.md` は

- 導入段落で `working-context.md` / `review-principles.md` / `mode-classification.md` の
  3 本を名指しし「（3 本それぞれに適用する）」と宣言
- 手順 2 で `<plugin_root>/rules/<name>.md` と書く（basename が変数）

これは正しい梯子だが、basename 単位の素朴な束縛では **3 件の偽陽性**になる（`.agents` と
`plugin/plangate` の両方で計 6 件）。しかも `plan-review-gate` は AC-3 の 7 skill に無いため
§8 の偽陽性チェックをすり抜ける。

したがって rev1 は §2.5 と同じ「距離ではなく構造」で解く:

> **パラメタ化梯子の束縛規則**: 梯子ブロック内に plugin root プレースホルダと
> `rules/<変数>.md`（`<...>` 形の placeholder、または `*`）が現れる場合、
> その梯子は **同一ブロックのスコープ宣言に現れる basename** を laddered とする。
> **「全 basename」ではない。**

- スコープ宣言に basename が 1 つも無ければ laddered は**空**（＝免除しない）。
  よって `rules/*.md` だけを書いた「梯子もどき」に免除効果は無く、M2 型 FN は再発しない
- 検証: この規則は `645220b` の I-1 = 18 を変えず（保守的）、`33d8de8` の
  `plan-review-gate` 6 件のみを解消する（18 → 18 / 12 → 6）

### 3.4 ターゲット単位の束縛（不変）

**ファイル単位ではなくターゲット単位で束縛することが要点**。ファイル単位（「梯子が 1 個でもあれば OK」）にすると、既に別ターゲットの梯子を持つファイルに新しい rules 参照を足しただけで検出できない — PR #1158 の変異 **M2**「マーカーが file 内 1 箇所あれば全体を免除」と同型の FN になる。実証は §7 の **M1a**。

---

## 4. I-2 の判定アルゴリズム

> **`docs/**` / `schemas/**` の解決順に plugin root 段を含まない。**

2 つの副検査に分ける。片方だけでは不十分であることを §7 で実証する。

### 4.1 I-2a — トークン束縛（リテラル形）

セグメント単位で、plugin root プレースホルダ（§3.1 の明示定数）の**直後のパス要素**を見る。それが `docs` / `schemas` なら violation。

検討して**採らなかった**案:

- **「plugin root と docs が同一セグメントに同居したら violation」** … クラス A と C を 1 本のリストで共用している skill（#1158 が「手順 2 は rules に対して実際に機能するため削除できない」と結論した 7 本）が全部誤検出になる。実測で **12 件の誤検出**（`ai-dev-verify` / `working-context` / `subagent-team-design` / `ui-ux-lane`）。
- **「プレースホルダは必ず `/rules/` を伴うべし」** … `plugin/plangate/skills` `plugin/plangate/commands` `plugin/plangate/hooks` などの**正当な配布物パス言及**まで巻き込み **97 件**の誤検出。

採用形（**直後が docs / schemas のときだけ violation**）は現 main（`33d8de8`）で **0 件**。

### 4.2 I-2b — 梯子ブロック単位（ブロック形 / M4 対策）

§2.3 の梯子ブロックを取り、§2.4 の手順に分解し、§2.5 でターゲットを束縛したうえで:

- **手順が plugin root に言及し**（プレースホルダ **または** 散文の「plugin root」「plugin ルート」）
- **かつ 束縛クラスが docs / schemas を含み**
- **かつ 手順自身が rules を明示していない**

とき violation。

**散文も見る**のが要点。#1158 の F-5 でプレースホルダを注記から全廃した結果、「2. 無ければ plugin root 配下の同名パスを探す」という**リテラルを含まない欠陥段**が書けてしまう。これは I-2a では原理的に捕まらない（§7 M3 / M3b で実証）。

**禁止文が誤検出にならない理由**は、それが**手順ではない**から。マーカーによる免除ではなく、構造（`(N)` 記法・順序付きリスト項目でない）で除外している。したがって #1158 の M2 型 FN（マーカー 1 個で file 全体を免除）は原理的に発生しない。実証は §7 の **M5**。

既知の破れ方（2 文構成）は §2.4.1 / 変異 **M3c**。

---

## 5. I-3 の判定アルゴリズム

> **skill 本文の `docs/` / `schemas/` 参照は参照解決順の注記を伴う。**

### 5.1 注記スコープ

次のいずれかを「解決順注記のスコープ」とする。

- 見出しに「参照解決順」を含む**セクション全体**（見出し〜次の見出し直前）
- 「参照解決順」「参照できなかった」「配布対象外」のいずれかを含む**単一セグメント**（#1139 / #1154 が採った 1 行インライン注記形。例: `acceptance-criteria-build` の「関連」節の 1 行）

**セクション形が必須**である理由: `acceptance-review` は「参照解決順」見出しの**次の段落**に `docs/**` というスコープ宣言を置く。単一セグメント判定だけだと宣言を見落として誤検出する。

### 5.2 判定

- `covered` … 注記スコープ内に現れるクラス（docs / schemas）
- `used` … 本文（フェンス除外）に現れるクラス
- **violation = `used` のうち docs / schemas であって `covered` に無いもの**（`(file, class)` の対）

パス表記は「`docs/` または `schemas/` の直後に 1 文字以上のパス要素が続く」ものだけを取る。
`schemas/` 単体の言及（例: `plangate-setup` の doctor 検査対象の列挙）は参照ではないため対象外。
この 1 条件を落とすと `plangate-setup` が誤検出になり AC-3 に反する（rev1 実測で確認）。

### 5.3 消費側 artifact の除外（誤検出ガード / **否定リスト 1 本** / F-13）

rev0 は `docs/working/TASK-XXXX/**` / `docs/working/PBI-*/**` / `docs/working/` 単体を
列挙していたが、`TASK-XXXX` がリテラルかパターンか未定義で、リテラル実装だと実在の
`TASK-0822` などが除外されない。**実測分布（`33d8de8` / 強制 root、`docs/working/` の
直下要素で集計）**:

| 直下要素 | 出現数 |
|---|---:|
| `TASK-XXXX`（プレースホルダ） | 164 |
| `templates` | 37 |
| （`docs/working/` 単体） | 22 |
| `ai-loop-runs` | 14 |
| `_audit` | 2 |
| `TASK-0822` | 2 |
| `discussions` / `TASK-0123` / `TASK-0655` / `_metrics` / `**` | 各 1 |

`ai-loop-runs` / `_audit` / `_metrics` / `discussions` / 実番号の `TASK-NNNN` はいずれも
「導入先で PlanGate 実行時に生成される作業成果物」という除外理由に完全に当てはまるのに
rev0 の列挙外だった。列挙を足し続ける形は必ず漏れる。

したがって **否定リスト 1 本**へ置き換える:

> **`docs/working/` 配下は既定で除外する。ただし `docs/working/templates/**` は除外しない**
> （上流リポジトリの配布資産であるため）。

除外しないと `breakdown-gate`（`docs/working/TASK-XXXX/todo.md`）/ `plangate-setup`（`docs/working/` 構造）/ `evidence-ledger` / `ref-integrity-scan` が誤検出になり **AC-3 に反する**。

### 5.4 既知の弱み（明示）と自己無効化ベクトル（F-12）

I-3 は**クラス単位・ファイル単位**の被覆であり、「同一ファイル内で docs 参照が 10 個あって注記が 1 個」でも通る。パス単位に締めると現 main で **257 件**（`645220b` 実測）発火するので、本 PBI では採らない。
**この弱みは I-2b が別方向から塞ぐ**（欠陥のある梯子は注記の有無に関わらず検出される）。パス単位化は follow-up（§12 L-1）。

**それとは別に、I-3 だけがマーカー免除を残している**点を明示する。I-1 はターゲット単位で束縛し、I-2b は「マーカーによる免除ではなく構造で除外」しているのに、**I-3 はクラス単位＝実質ファイル単位のマーカー免除**である。つまり:

> **既存の violation ファイルに「配布対象外」を含む 1 行を無関係な文脈で足すだけで、
> I-3 を能動的に無効化できる。**

rev0 は受動的な弱み（一部に注記が無くても通る）しか書いておらず、この**自己無効化ベクトル**に触れていなかった。7 変異にも注記を足す方向のものが 1 件も無い（M4 は逆方向＝注記の無い参照を足す）。

したがって §7 に変異 **M7**（既存 violation ファイルの無関係な段落に `配布対象外` を含む 1 行を追加 → I-3 が減ることを確認）を追加する。減ることが確認できたら、注記スコープを**セクション限定**（単一セグメント形は「同一セグメント内のクラスにのみ効く」）へ絞る。

---

## 6. 現 main（`33d8de8`）での実測 — AC-1

> ### AC-1 は現 scope では達成不能（**C-3 の Human 判断事項** / F-7）
>
> issue #1163 の **AC-1**「3 不変条件それぞれについて、現 main で violation 0 件であることを
> 検査が示す」と、同 issue の **Out of scope**「既存の欠陥の是正（#1159/#1158/#1154 で完了済み）」は
> **両立しない**。
>
> 設計の実測は `33d8de8` で **I-1 = 6（rev1 の §3.2 を採ると 33）/ I-3 = 22** であり、
> **issue の前提（既存欠陥は是正済み）は事実と異なる**ことが本設計で判明した。
> 是正は Out of scope なので「先に直して 0 にする」も選べない。**AC が内部矛盾している。**
>
> **本書は AC-1 の読み替えを行わない。** AC-1 をどう再定義するかは **C-3 で人間が決める**。
> 参考として選択肢を並べるが、**本書はどれも選択していない**:
>
> | 案 | 内容 | 影響 |
> |---|---|---|
> | **案 1** | AC-1 を「**検査導入時点の baseline を known-gap allowlist として pin し、以後の増加を 0 にする**」へ再定義 | §11.2 の allowlist 機構がそのまま使える。issue の Out of scope を維持できる |
> | **案 2** | Out of scope を改め、**既存欠陥の是正を #1163 に含める**（`ai-loop-cycle` 系 + `plan-review-gate` 系） | 「検知器を作る」と「検知器が見つけたものを直す」が混在（#1087 が意識的に避けた形） |
> | **案 3** | 是正を**別 PBI に切り出し**、#1163 は検査導入のみ・full enforcement は別 PBI のマージ後 | #1163 単体では CI に載らない期間が生じる |
> | **案 4** | AC-1 を **I-2a / I-2b に限定**して満たす（I-1 / I-3 は report-only） | rev0 の §11.2(A) 相当。**issue が訴えた欠陥クラス（I-1 / I-3）を止めないゲートになる**ため rev1 では非推奨と明記する |
>
> `§3.2`（bare 参照を `referenced` に含めるか）も同じ C-3 で決める必要がある。
> 採ると baseline が 6 → 33 に増え、案 1 の allowlist 初期サイズが変わる。

**強制 root（`.agents/skills` + `plugin/plangate/skills`、`*.md` 111 件 = 45 + 66）**:

| 不変条件 | `645220b`（rev0 時点） | **`33d8de8`（rev1 再測定）** | 判定 |
|---|---:|---:|---|
| **I-1**（§3.3 パラメタ化梯子あり / §3.2 bare なし） | 18 | **6** | **0 ではない**（未是正。内訳は §6.1） |
| I-1（§3.2 bare 参照を採る場合） | — | **33** | 参考値。C-3 判断待ち |
| **I-2a** | 0 | **0** | PASS |
| **I-2b** | 0 | **0** | PASS |
| **I-3** | 22 | **22** | **0 ではない**（未是正。内訳は §6.2） |

**再測定の妥当性検証**: rev1 のために書き起こした**第 3 の独立再実装**を `645220b` に対して
実行し、rev0 が報告した **I-1 = 18 / I-2a = 0 / I-2b = 0 / I-3 = 22** を
**ファイル単位・basename 単位まで完全に再現**した。そのうえで同じ実装を `33d8de8` に
適用した結果が上表である（差分は #1164 のマージのみ）。

### 6.1 I-1 の 6 件 — 未是正の欠陥（**是正しない。報告のみ**）

**件数ではなく集合で記載する**（再測定時に同値照合できるようにするため）。

`.agents/skills` 単独では **0 件**（PR #1164 `7134f68` が `design-gate` / `intent-classifier` /
`skill-policy-router` の梯子を追加し、`plan-review-gate` は §3.3 のパラメタ化梯子で解決）。

残る 6 件はすべて `plugin/plangate/skills/ai-loop-cycle/references/` 配下:

| ファイル | 参照しているのに梯子が無い正本 |
|---|---|
| `plugin/plangate/skills/ai-loop-cycle/references/agentic-six-stage-loop.md` | `hybrid-architecture.md` / `orchestrator-mode.md` / `responsibility-classes.md` |
| `plugin/plangate/skills/ai-loop-cycle/references/arbiter-policy.md` | `responsibility-classes.md` |
| `plugin/plangate/skills/ai-loop-cycle/references/loopspec.md` | `working-context.md` |
| `plugin/plangate/skills/ai-loop-cycle/references/related-specs.md` | `responsibility-classes.md` |

**`.agents/skills/ai-loop-cycle/` には `references/` が存在しない**（`SKILL.md` のみ）。
`plugin/plangate/skills/ai-loop-cycle/references/` は **23 件の `*.md`**（集合）:

`00_concept.md` / `README.md` / `adaptive-production-loop.md` / `agentic-six-stage-loop.md` /
`arbiter-policy.md` / `c3-prime-contract.md` / `concept.md` / `decision-table.md` /
`delivery-state-machine.md` / `design-philosophy.md` / `execution-runbook.md` / `flow-detect.md` /
`ho-paths.md` / `hotl-merge-entry-criteria.md` / `lite-criteria.md` / `loop-safety-gates.md` /
`loopspec.md` / `related-specs.md` / `review-feedback-loop.md` / `rollout-policy.md` /
`run-evidence-contract.md` / `stop-rollback.md` / `unknown-discovery.md`

（rev0 は「20 ファイル・うち 2 件は schemas」と書いていたが誤り。`schemas/` は
`plugin/plangate/skills/ai-loop-cycle/schemas/run-evidence.schema.json` として
`references/` とは**別ディレクトリ**に 1 件ある。）

これらは配布時に別経路で生成され、**正本側に対応物が無いため今まで誰も是正していない**。
これは #1163 が予測した「新しいクラスの穴」の実例である。

### 6.2 I-3 の 22 件 — 未是正の欠陥（**是正しない。報告のみ**）

`(file, class)` の集合として列挙する。`645220b` と `33d8de8` で**集合は完全に一致**した
（#1164 はクラス C の注記を変更していないため）。

| ファイル | クラス |
|---|---|
| `.agents/skills/ai-loop-cycle/SKILL.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/SKILL.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/00_concept.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/adaptive-production-loop.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/agentic-six-stage-loop.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/arbiter-policy.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/concept.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/decision-table.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/design-philosophy.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/execution-runbook.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/flow-detect.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md` | **schemas** |
| `plugin/plangate/skills/ai-loop-cycle/references/lite-criteria.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/loop-safety-gates.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/loopspec.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/related-specs.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/review-feedback-loop.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/rollout-policy.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/run-evidence-contract.md` | docs |
| `plugin/plangate/skills/ai-loop-cycle/references/run-evidence-contract.md` | **schemas** |
| `plugin/plangate/skills/ai-loop-cycle/references/stop-rollback.md` | docs |

**22 件すべてが `ai-loop-cycle` 系**であり、§6.1 と同じ「配布 references が正本側に存在しない」構造に由来する。

### 6.3 参考: 強制対象外 root の実測（report-only / `33d8de8`）

| root | I-1 | I-2a | I-2b | I-3 |
|---|---:|---:|---:|---:|
| `.claude/skills`（対象外） | 8 | 0 | 0 | 10 |
| `.codex/skills`（#956 待ち） | 6 | 0 | 0 | 23 |

`.codex/skills` の I-1 6 件は `design-gate` / `intent-classifier` / `plan-review-gate`（3 ターゲット）/ `skill-policy-router` の 4 skill。
**PR #1164 が `.codex/skills` に追随していない**ため、`645220b` 時点の `.agents` 側と同じ内訳がそのまま残っている
（#1158 finding 3 が言う drift が数字に出ている）。

### 6.4 PR #1164 のマージが変えたこと（F-8）

- **#1164 は MERGED**（`7134f68`。rev0 は「OPEN・未マージ」としていた）。現 `origin/main` = `33d8de8`
- 変更は `.agents/skills` / `.claude/skills` / `plugin/plangate/skills` の 10 ファイル。
  `design-gate` / `intent-classifier` / `skill-policy-router` は**具体 basename の梯子**、
  `plan-review-gate` は**パラメタ化梯子**（§3.3）
- 結果、強制 root の I-1 は **18 → 6**（§3.2 を採らない場合）
- **rev0 の「#1164 がマージされても 6 件残る」という予測は結果として当たったが、
  その理由の一部は誤っていた**。rev0 は `.agents` の 6 件すべてが #1164 で解消されると
  想定していたが、`plan-review-gate` の 3 ターゲット（×2 root = 6 件）はパラメタ化梯子で
  あり、§3.3 の束縛規則を入れなければ**偽陽性として残っていた**。rev1 でこの規則を明文化した
- 残債は **`ai-loop-cycle` 1 skill に集中**しており、(B)（先に是正）のコストは rev0 の
  想定より低い。§6 冒頭の案 2 / 案 3 の判断材料になる

---

## 7. 変異注入の設計と結果 — AC-2

サンドボックス（`.agents/skills` + `plugin/plangate/skills` を tmp へコピー）に変異を 1 つずつ適用し、baseline との差分で KILL / SURVIVE を判定した。

baseline（変異なし / `33d8de8` / §3.2 の bare 参照は採らない形）は **I-1 = 6 / I-2a = 0 / I-2b = 0 / I-3 = 22**。

**注入 root を必ず記録する**（rev0 は記録していなかった / F-10）。

| ID | 対象 | 注入 root | 変異内容 | 形式 | 期待 | 結果 |
|---|---|---|---|---|---|---|
| **M1a** | `breakdown-gate/SKILL.md` | `.agents/skills` | 既に `mode-classification` の梯子を持つファイルに、梯子なしの `review-principles.md` 参照を**追記** | 追記 / 混在ファイル | I-1 +1 | **KILL**（I-1 = 7。rev1 で `33d8de8` 上で再実行） |
| **M1b** | `diff-audit/SKILL.md` | `.agents/skills` | ファイル内で唯一の梯子（**4 行にまたがる `(2)` 手順ブロック**）を削除し非梯子手順へ置換 | **ブロック** | I-1 +1 | **KILL**（`645220b`） |
| **M2** | `subagent-dispatch/SKILL.md` | `.agents/skills` | docs 梯子に plugin root プレースホルダ + `/docs/...` 段を**リテラルで**再導入 | 行 | I-2a +1 | **KILL**（I-2a = 1 / I-2b も 1） |
| **M3** | `subagent-dispatch/SKILL.md` | `.agents/skills` | 同じ位置に**散文で**「(2) 無ければ plugin root 配下の同名パスを探す。」を挿入（**リテラル無し**） | 散文 | I-2b +1 かつ **I-2a は 0 のまま** | **KILL**（I-2a = **0** / I-2b = 1） |
| **M3b** | `context-packager/SKILL.md` | `.agents/skills` | 「参照解決順」の語を**使わず**、docs 宣言行と「2. 無ければ plugin root 配下の同名パス」を**別々の行**に置いた梯子を新設 | **ブロック / 複数行 / マーカー無し** | I-2b +1 | §2.3(b) 導入前 **SURVIVE** → 導入後 **KILL** |
| **M4** | `breakdown-gate/SKILL.md` | `.agents/skills` | 注記の無い状態で `docs/ai/plan-metrics-verification.md` 参照を追記 | 追記 | I-3 +1 | **KILL** |
| **M5** | `review-gate/SKILL.md` | `.agents/skills` | **クラス A ブロックは健全なまま**、クラス C ブロックにだけ散文の plugin root 段を挿入（#1158 M2 と同型） | ブロック / 混在ファイル | I-2b +1 | **KILL** |

### 7.1 rev1 で追加する変異（未実施 / 実装 PBI で実行する）

| ID | 対象 | 注入 root | 変異内容 | 狙い | 出典 |
|---|---|---|---|---|---|
| **M3c** | `subagent-dispatch/SKILL.md` | `plugin/plangate/skills` | M3 の注入テキストを **2 文に分割**（`(2) 無ければ次の候補を探す。plugin root 配下の同名パス。`） | §2.4 の句点打ち切りが 2 文構成を取り逃すことを **SURVIVE で実証** → 打ち切り条件を否定文構造へ改める | F-11 |
| **M6** | `review-gate/SKILL.md` | `plugin/plangate/skills` | `.claude/rules/review-principles.md` を **`review-principles.md`（bare）に書き換える**（参照表記を弱める） | §3.2 未採用なら **SURVIVE**（＝回避策が成立することの実証）。採用なら KILL | F-15 |
| **M7** | `ai-loop-cycle/references/loopspec.md` | `plugin/plangate/skills` | 無関係な段落に `配布対象外` を含む 1 行を追加 | I-3 の**自己無効化ベクトル**（§5.4）。I-3 が減れば注記スコープをセクション限定に絞る | F-12 |
| **M8** | `ai-loop-cycle/references/arbiter-policy.md` | `plugin/plangate/skills` | `references/` 配下に I-1 欠陥を追加（`SKILL.md` ではない） | 走査グロブが `*/SKILL.md` に退行しても気づけるようにする | F-10 |

### 7.2 変異注入 root の偏りとその実害（F-10）

rev0 の 7 変異は **すべて `.agents/skills` の `SKILL.md` 直下**に注入されていた。

- **走査グロブが `*/SKILL.md` に退行しても 7 変異すべて KILL のまま緑になる。**
  強制 root の `*.md` は 111 件だが `SKILL.md` は **78 件**（39 + 39）。
  退行時に視界から消えるのは **`references/` 配下の 33 件**であり、
  §6.1 の I-1 6 件と §6.2 の I-3 20 件（`references/` 分）＝**計 26 findings がまるごと消える**
- **導入先ユーザーが読むのは `plugin/plangate/skills`** であり、#1163 が守る実体はそちら。
  片 root にしか注入していないと、ミラー 2 root のうち片方だけを走査する退行に気づけない
- M1a の baseline 差分が +1 であることは「片 root にしか注入していない」ことの帰結である
  （両 root に注入すれば +2）

したがって rev1 では **(a) 注入 root 列を必須**（上表）、**(b) `references/` 配下への注入（M8）を追加**、
**(c) 既存 TC-04〜06 のうち少なくとも 1 本を `plugin/plangate/skills` 側のみへの注入に切り替える**。

### 7.3 M4 型（行スコープで取り逃すもの）の扱い

- **M3** は plugin root の言及にリテラルが無いため、`grep` 相当の**行スコープ検査では原理的に 0 件**になる。実測でも **I-2a = 0 / I-2b = 1**。**「行スコープでは取り逃す / 段落スコープなら捕る」を同一変異で両側から示した唯一の証拠**。
- **M3b** はさらに「docs 宣言と plugin root 段が別行」「見出しに『参照解決順』の語が無い」。**§2.3 の (a) だけの梯子検出では実際に SURVIVE した**。(b)（番号 1 始まりの順序付きリスト + 解決語彙）を足して初めて KILL。
  → **梯子検出そのものをマーカー非依存にすることが AC-2 の必須要件**であり、本設計に組み込み済み。

### 7.4 fail-closed（root 不在 / root 空）の検出力

- 宣言 root が存在しないディレクトリに対して実行すると `declared root not found` を出力し rc=1（実測）
- **rev1 追加**: enforced root が存在するが `*.md` が 0 件のときも rc=1（§1.3）。
  変異としては「`.agents/skills` の中身だけを空にする」を TC で回す

---

## 8. 偽陽性の確認 — AC-3

強制 root での実行結果を、指定の 7 skill 名で grep した結果は **0 件**（`NO FINDINGS`）。
7 skill すべてが `33d8de8` に実在することも確認済み。

| skill | 所在 | 発火 | 発火しない理由 | 区分 |
|---|---|:--:|---|---|
| `breakdown-gate` | `.agents/skills` / `plugin/plangate/skills`（`.claude/skills` にも同名あり） | なし | I-1: `mode-classification` の梯子が 3 箇所 / I-3: `docs/working/TASK-XXXX/todo.md` は §5.3 の消費側 artifact | **走査済みで健全** |
| `plangate-setup` | `.agents/skills` / `plugin/plangate/skills`（同上） | なし | I-1: 梯子 2 箇所 / I-3: `docs/working/` 構造と `schemas/` 単体の言及のみ（§5.2 / §5.3） | **走査済みで健全** |
| `local-exec-handoff` | `.agents/skills` / `plugin/plangate/skills` | なし | I-1: 梯子 2 箇所 / I-3: 注記あり | **走査済みで健全** |
| `hypothesis-logger` | `.claude/skills` のみ | なし | §1.1 により root ごと対象外 | **対象外** |
| `plan-quality-reviewer` | `.claude/skills` のみ | なし | 同上 | **対象外** |
| `plangate-working-discipline` | `.claude/skills` のみ | なし | 同上 | **対象外** |
| `pr-watch` | `.claude/skills` のみ | なし | 同上 | **対象外** |

**「対象に無いから発火しない」と「対象だが健全だから発火しない」は必ず分けて検証する。**
前者を後者と混同すると、対象外設定が壊れたときにも走査が全面的に壊れたときにも同じく緑になる。
したがって TC も 1 本にまとめず 2 本に割る（§11.1 の TC-08a / TC-08b / F-14）。

**rev1 の追加注意**: AC-3 の 7 skill は偽陽性チェックの**十分条件ではない**。
§3.1 で判明した `skill-creator`（7 skill に無い）や §3.3 で判明した `plan-review-gate`（同）は、
アルゴリズムを誤ると誤検出するのに **§8 をすり抜ける**。実装 PBI では
「**前回実行との findings 集合の差分**」も併せて見る（新規に増えたファイルは必ず目視確認する）。

---

## 9. CI 配線の設計 — AC-4（最重要）

### 9.1 前提の実測

`tests/run-tests.sh` は `tests/extras/ta-*.sh` を **glob で自動 source** する（`EXTRAS_DIR` を for ループの glob に展開し、`[ -f ]` で存在チェックしてから `.` で source）。許可リストは存在しない。

実測での裏取り:

- `ls tests/extras/ta-*.sh` の件数 = **65**
- 同一 glob を同一条件で回した件数 = **65**（同値）

そして `.github/workflows/test.yml` が `sh tests/run-tests.sh` を **`pull_request` と `push:main` の両方**で回す。

→ **`tests/extras/ta-NN-*.sh` を 1 ファイル置くだけで CI 経路に載る。`.github/`（HO）に触らずに済む唯一の経路であり、最小コスト。**

参考: `scripts/release-prep.sh` の `run_checks` も検査集約点だが、**どの workflow からも呼ばれていない**（実測: `.github/workflows/` に `release-prep` の参照ゼロ）。ここに足しても CI は赤くならない。

### 9.2 「検査を外すと CI が赤くなる」の担保設計

前例 4 件（#937 / #984 / #1087 / `check-stale-skill-refs.py`）はいずれも「**検査は書いたが呼び出し側が無い**」型。
rev0 は外し方を 3 通りとしていたが、レビューで **さらに 2 通り**が指摘された（F-9 / F-16）。5 通りすべてに赤を対応させる。

| 外し方 | 何が起きるか | 赤にする仕組み | 層 |
|---|---|---|---|
| **(1) 検査本体を消す / 壊す** | `scripts/check-ref-resolution.py` 不在 | `ta-70` の TC-01 が「存在・python3 で実行可能・`--selftest` rc=0」を assert（`ta-64` TC-01 と同型） | extras |
| **(2) 検査は残るが rc が握り潰される** | violation が出ても緑 | `ta-70` は**本番ツリーに対して既定引数で実行**し rc と出力の両方を assert。`--warn-only` 相当のオプションを**そもそも実装しない**（§11.2 の allowlist が唯一の緩衝であり、それも tracked） | extras |
| **(3) `ta-70` 自体を消す** | glob が拾わないので**静かに緑** | **`ta-69-distribution-checks.sh` に配線レジストリ TC**（§9.3） | 別レーン |
| **(4) 走査範囲を縮める**（F-9） | `ENFORCED_ROOTS` から 1 行消す / glob を `*/SKILL.md` に狭める → violation が減って緑 | **実行時の同値照合 TC**（§9.3.1） | extras |
| **(5) `ta-70` を残したまま中身を空にする**（F-16） | marker + init + finalize だけの殻。glob は拾い、`[ -f ]` も通る | **`ta-69` のレジストリを実行証跡の照合にする**（§9.3.2） | 別レーン |

**(4) と (5) が rev0 の盲点だった理由**: rev0 の「外し方 3 通り」はいずれも**ファイル削除**を前提にしていた。
しかし `scripts/check-ref-resolution.py` は **HO 対象外**である（`scripts/hooks/check-plan-hash.sh` の
`_override=0` 直後の `case` ブロックは `scripts/hooks/*.sh` のみを含み、`scripts/*.py` を含まない）。
`tests/extras/` も HO 外。→ **AI が no-task セッションで自由に編集できる**。
1 行削除や中身の空洞化は、2 ファイル同時削除より**格段に安い**。

### 9.3 (3)(4)(5) を塞ぐ仕掛け

`tests/extras/` に共有ファイルを新設することは規約上できない（`_extra-contract.sh` が唯一の例外と `tests/extras/README.md` に明記）。したがって**既存の別レーンの extras に宣言を置く**。

- 置き場所: **`tests/extras/ta-69-distribution-checks.sh`**（#1087「配布物検査の CI 未配線」を扱うレーン。責務が一致する）
- **挿入位置の制約**: `pg_extra_contract_finalize`（ファイル末尾の呼び出し）**より前**に置くこと。
  finalize 以降に書いた assert は集計されない

#### 9.3.1 (4) 走査範囲の縮小を塞ぐ — 実行時の同値照合

`ta-70` に以下を持たせる。**ハードコード件数ではなく実行時の同値照合**であり、
`tests/extras/` と同じく増え続ける対象に絶対件数を書かない（#1087 AC-9 に抵触しない）。

- テスト側が独立に `ENFORCED_ROOTS` 相当の集合を列挙し、検査が出力する `roots=` 一覧と**集合同値**を assert
- テスト側が独立に `find <roots> -name '*.md' | wc -l` を計算し、検査が出力する `scanned=N` と**同値**を assert
- 各 enforced root について `scanned_<root> > 0`（§1.3 の下限）

`ta-69` の既存レジストリ（`[ -f ]` の存在確認のみ）は `ENFORCED_ROOTS` の 1 行削除に無反応なので、この層は `ta-70` 側で持つ。

#### 9.3.2 (3)(5) を塞ぐ配線レジストリ — 存在確認から**実行証跡**へ

rev0 の案は `[ -f ]` の存在確認だけで、(5)（空の `ta-70`）に無反応だった。
さらに `ta-61` が新規ファイルに課すのは marker 1 個 / init の basename 一致 / `sh -n` / finalize 到達だけで、
**「各 extras が最低 1 件 assert すること」を課す TC は存在しない**
（`non-empty` 系 assert は discovery 集合・covered 集合・実行ループ回数にのみ存在する）。

したがってレジストリを**実行証跡の照合**に変える:

```sh
# 配線レジストリ（#1163 AC-4 / #1087 と同じ「未配線を機械検出する」思想）
# 1 行 = "<検査スクリプト> <その検査を CI 経路へ載せる extras ファイル> <その extras が export する TC カウンタ名>"
# 行を消すのは 1 行の意識的なコード変更であり diff / レビューに必ず現れる。
_T69_WIRING='scripts/check-ref-resolution.py tests/extras/ta-70-ref-resolution.sh _T70_TC_COUNT'

# サブシェルを作らない書法（here-doc + read）で回す。パイプ経由の while は
# pass/fail カウンタがサブシェルに閉じて更新されない。
# 判定は 3 段:
#   (a) 検査本体が存在する
#   (b) その検査を実行する extras ファイルが存在する
#   (c) (b) が実際に assert を回した証跡（カウンタ変数）が 0 より大きい
#       -> 空洞化した ta-70 は (c) で FAIL する。下限照合なので件数契約ではない
```

`ta-70` 側は自身の assert 回数を `_T70_TC_COUNT` に積み、`ta-69` はそれを `-gt 0` で照合する。
`ta-69` は `ta-70` より後に source される必要があるため、ファイル名の辞書順（`ta-69` < `ta-70`）と
矛盾する。実装時は **`ta-70` が finalize 前にカウンタを export し、`ta-69` は
「変数が未定義なら FAIL」**とすることで順序依存を明示的な失敗に変える
（順序に依存して静かに緑になる形を作らない）。

**絶対件数は書かない**。`tests/extras/` は増え続けるディレクトリであり、これは行の**同値照合**と**下限照合**であって件数契約ではない。

**残存リスクの明示**: `ta-69` と `ta-70` を**同時に**消せば依然として静かに緑になる。これは 2 ファイル・2 レーンの削除であり、#1109 R-001 と同じく「**気づかずに起きる**」から「**意識的にやらないと起きない**」への格下げが本設計の到達点である。完全な fail-closed は §9.4 の Human 適用が必要。

### 9.4 併せて提示する（Human 適用）ワークフロー patch — 任意・推奨

`.github/workflows/` は HO のため AI は適用できない。`ta-69` + `ta-70` の 2 ファイル同時削除まで塞ぎたい場合は下記を Human が適用する。

```diff
--- a/.github/workflows/test.yml
+++ b/.github/workflows/test.yml
@@
       - name: Run CLI tests
         run: sh tests/run-tests.sh
+
+      - name: skill 参照解決順の不変条件（#1163）
+        run: python3 scripts/check-ref-resolution.py
```

この step を消すことは `.github/workflows/`（HO 9 カテゴリ）の変更であり、承認境界に乗る。

### 9.5 推奨

> **推奨は「`tests/extras/` 経由（§9.2 の 5 層）を本体とし、§9.4 の workflow step を Human 適用の任意強化として併記する」。独立 workflow は新設しない。**

根拠:

1. `.github/workflows/` は HO で、AI が no-task セッションから適用できない。独立 workflow を主経路にすると **適用されないまま close される**（#1087 と同じ失敗）。
2. `tests/extras/` の glob 自動 source は **65/65 で実測確認済み**であり、`test.yml` が `pull_request` / `push:main` の両方で回す。ファイルを置いた瞬間に CI 経路に載る。
3. 独立 workflow を新設すると `.github/workflows/` が 11 本目になり、required checks 設定に**また同じ穴**（#984「10 本中 5 本が checks に無い」）を開けるリスクがある。既存 `test.yml` に相乗りする §9.4 の形なら required check の再設定が不要。

---

## 10. `.codex/skills` の扱い（#956）

**走査対象には含めるが enforcement には含めない（report-only）。** 判断を先送りするのではなく、**先送りしていること自体を宣言で可視化する。**

| 観点 | 設計 |
|---|---|
| 宣言 | `DECLARED_ROOTS` に **`.codex/skills` を残す**。不在なら root violation |
| enforcement | `ENFORCED_ROOTS` から外す。findings は `[deferred:#956]` 接頭辞で**必ず出力**する（silent skip 禁止 / #1109 の「見ていないものを緑にしない」） |
| rc | `.codex/skills` の findings は rc に**寄与しない** |
| 解除条件 | #956 が `.codex/skills` の去就（再同期 or untrack）を決めた時点で `DEFERRED_ROOTS` から 1 行削除するだけで enforcement に入る |
| #1086 で untrack する場合 | `DECLARED_ROOTS` から 1 行削除する。**削除しない限り CI が赤くなる**ので検査範囲が静かに半減しない |

**勝手に enforcement へ入れない根拠（`33d8de8` 実測）**: `.codex/skills` は I-1 = **6**、I-3 = **23** で、含めると **即座に CI が赤くなる**。しかも #1158 が実測したとおり `.codex/skills/plan-review-gate/SKILL.md` には #956 が審議中の「C-1 追加品質ゲート」節が実在し、**再同期は判断材料を消す**。是正は #956 の裁定後。

report-only の出力形（設計）:

```text
[ref-resolution] .codex/skills: 29 findings (deferred: #956 -- not counted in rc)
[ref-resolution]   [deferred:#956] .codex/skills/plan-review-gate/SKILL.md: working-context.md referenced without plugin-root ladder
```

### 10.1 deferred 出力を検証する TC（F-4）

rev0 は「silent skip 禁止・findings を必ず出力」だけを安全性の根拠にしていたが、
**出力は誰も読まなくても CI を止めない**。deferred 出力を検証する TC が 1 本も無いと、
`.codex/skills` の走査が丸ごと落ちても赤くならず、「見ていないものを緑にしない」という
主張が実質的に成立しない。

したがって以下を追加する:

- **TC-09**: 本番ツリー実行の出力に `[deferred:#956] .codex/skills` を含む行が **1 行以上**現れ、
  かつ **rc は変わらない**（下限照合であり件数契約ではない）
- **TC-10（stale 検出 / `ta-65` 同形）**: `.codex/skills` の findings が **0 件になったら**
  deferred 宣言を **stale として FAIL** する。是正済み or 走査が壊れたのどちらかであり、
  どちらも黙って緑にしてはならない

`ta-65` は「flag があるのに実装が fixed（＝ patch は当たったが flag 未削除）なら stale 宣言として FAIL」
という同型の構造を持つ。本 TC はその写像である。

---

## 11. 実装形（既存流儀の踏襲）

`scripts/check-*.py` / `check-*.sh` を実測した結果、本検査は **単体 Python スクリプト**（`check-stale-skill-refs.py` / `check-skill-frontmatter.py` / `check-skill-name-collisions.py` と同系）が適切。`check-codex-skill-spec.sh` の sh ラッパ + 埋め込み Python 形は「`--warn-only` の rc 方針を shell 側 1 箇所に集約する」ためのものだが、本検査は `--warn-only` を持たない（AC-4 の趣旨に反する）ので不要。

踏襲する流儀:

| 流儀 | 出典 | 本検査での適用 |
|---|---|---|
| 走査 root を**宣言定数**で持ち、不在は violation。ただし `plugin/*/skills` は**動的列挙** | `check-codex-skill-spec.sh` の `DEFAULT_TARGETS` / #1109 R-001 / `check-skill-frontmatter.py` の `discover_skill_roots()` | `DECLARED_ROOTS` / `ENFORCED_ROOTS` / `DEFERRED_ROOTS` / `EXEMPT_ROOTS`（§1.2） |
| **絶対件数を契約値にしない** | `ta-69` の #1087 AC-9 | 検査は集合比較のみ。テストは「注入した違反が出力に含まれる」「集合の同値照合」「下限（> 0）」で契約 |
| **正本集合を実行時に導出する** | `ta-65`（HO カテゴリを hook 本体の `case` から導出） | rules 正本 6 件を `plugin/plangate/rules/*.md` から導出（§0 / §3.2） |
| skip したものは件数と理由を必ず出す | #1109 | 対象外 root / フェンス / 消費側 artifact の除外件数を出力 |
| `--selftest` を持つ | `check-stale-skill-refs.py` | 内蔵 fixture で全変異を自己検証 |
| rc: 0 = 違反なし / 1 = 違反あり / 2 = 引数エラー | `check-stale-skill-refs.py` | 同一 |
| 行番号アンカーを正本に書かない | #1089 | 参照は宣言変数名・記号アンカーで書く |

### 11.1 提示する新規ファイル（骨子）

```text
scripts/check-ref-resolution.py
  DECLARED_ROOTS  = (".agents/skills", ".claude/skills", ".codex/skills") + glob("plugin/*/skills")
  ENFORCED_ROOTS  = (".agents/skills",) + glob("plugin/*/skills")
  DEFERRED_ROOTS  = (".codex/skills",)     # #956 裁定待ち。1 行削除で enforcement 入り
  EXEMPT_ROOTS    = (".claude/skills",)    # 配布 source でない（install.sh / sync / codex installer 実測）
  KNOWN_GAP_FILE  = "tests/fixtures/ref-resolution-known-gap.tsv"   # 11.2

  canonical_rules()       -- plugin/plangate/rules/*.md から実行時導出（§0）
  segment(lines)          -- 2.1 セグメンテーション
  sections(lines)         -- 2.2 セクション
  ladder_blocks(segs)     -- 2.3 梯子ブロック（(a) 語 + (b) 構造。マーカー非依存）
  steps_of(seg)           -- 2.4 手順抽出（(N) 記法・否定文構造で終端）
  bind_class(step, block) -- 2.5 ターゲット束縛（明示 -> ブロック宣言。距離は使わない）

  check_i1 / check_i2a / check_i2b / check_i3    -- 3 / 4 / 5 節
  main() -> rc 0|1|2
    出力に roots= / scanned= / skipped= を必ず含める（9.3.1 の同値照合の入力）
```

`tests/extras/ta-70-ref-resolution.sh` は **#921 の extras 実行契約**を満たすこと
（`tests/extras/README.md` の新規ファイル checklist 1〜4。**`ta-61` の `_pending_migration()`
allowlist は `ta-04`〜`ta-60` の移行期ファイルのみで `ta-70` を含まないため、`ta-70` は
covered set に入り、契約を欠くと `ta-61` の TC-09 / TC-10 で FAIL する**）。
雛形は `ta-69-distribution-checks.sh` の bootstrap ブロックをそのまま写す:

```sh
# tests/extras/ta-70-ref-resolution.sh
# PG_EXTRA_CAPABILITY: standalone-capable     <- marker（先頭 20 行以内・ちょうど 1 個）
# Sourced by tests/run-tests.sh -- uses $pass / $fail counters

# ---- extras execution contract bootstrap (#921) ----------------------------
if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ] && [ -n "${EXTRAS_DIR:-}" ]; then
  _pg_extra_mode=harness
  _pg_extra_dir="$EXTRAS_DIR"
else
  _pg_extra_mode=standalone
  _pg_extra_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
fi
_pg_extra_helper="$_pg_extra_dir/_extra-contract.sh"
if [ ! -r "$_pg_extra_helper" ]; then
  printf '  [FAIL] helper unresolved: %s\n' "$_pg_extra_helper" >&2
  if [ "$_pg_extra_mode" = harness ]; then fail=$((fail + 1)); return 0; fi
  exit 1
fi
. "$_pg_extra_helper"
pg_extra_contract_init ta-70-ref-resolution standalone-capable   # basename と一致させる

# ... TC 本体（rc 捕捉は必ず OR-list 形式。`(cd && cmd; echo $?)` は set -e 下で壊れる）...

_T70_TC_COUNT=$_t70_assert_count ; export _T70_TC_COUNT   # 9.3.2 の実行証跡
pg_extra_contract_finalize                                # 必ず最後
```

TC 一覧（rev1）:

```text
tests/extras/ta-70-ref-resolution.sh
  TC-01  scripts/check-ref-resolution.py が存在し python3 で実行可能
  TC-02  --selftest が rc=0
  TC-03  本番ツリー（既定引数）で I-2a / I-2b が 0、かつ known-gap allowlist と findings が同値
  TC-04  sandbox に M2 を注入 -> rc=1 かつ出力に I-2a が含まれる
  TC-05  sandbox に M3b（M4 型）を注入 -> rc=1 かつ I-2b が含まれ I-2a は 0
  TC-06  sandbox に M1a を注入 -> rc=1 かつ I-1 が含まれる（allowlist 外なので必ず rc に乗る）
  TC-07  宣言 root を消した sandbox -> rc=1 かつ "declared root not found"
  TC-07b enforced root は存在するが *.md が 0 件の sandbox -> rc=1（§1.3）
  TC-08a .agents/skills の 3 skill（breakdown-gate / plangate-setup / local-exec-handoff）が
         **走査されたうえで** violation ゼロ（出力の scanned 一覧に含まれ、かつ violation 行に無い）
  TC-08b .claude/skills の 4 skill が exempt root として **件数と理由付きで skip 出力に現れる**
  TC-09  出力に "[deferred:#956] .codex/skills" が 1 行以上あり、rc は変わらない（§10.1）
  TC-10  .codex/skills の findings が 0 になったら deferred 宣言を stale として FAIL（§10.1）
  TC-11  known-gap allowlist の stale 検出: list にあるのに検出されない entry があれば FAIL（§11.2）
  TC-12  走査範囲の実行時同値照合: roots 集合 / scanned 件数 / root ごとの下限（§9.3.1）
  TC-13  sandbox に M8（references/ 配下への I-1 注入）-> rc=1（グロブ退行検出 / §7.2）
  (絶対件数は assert しない / #1087 AC-9。集合の同値照合と下限照合のみ)
```

### 11.2 baseline が 0 でないことへの対処 — **known-gap allowlist**（F-1）

§6 のとおり現 main には I-1 = 6（§3.2 を採ると 33）/ I-3 = 22 の未是正が残る。
**したがって TC-03 で「全体 rc=0」を assert してはならない。**

rev0 は「(A) I-2a / I-2b のみ rc に寄与させ、I-1 / I-3 は `[known-gap]` として出力のみ」を
推奨していたが、**これは §9.2 の「`--warn-only` 相当のオプションをそもそも実装しない」と
正面から矛盾する**（I-1 / I-3 に対する恒久的な warn-only と同義）。
しかも rc に寄与する I-2a / I-2b は現 main でもサンドボックスでも 0 件＝**一度も自然発生
していないクラス**であり、#1163 の起票理由（6 PR 分の手作業是正）は I-1 / I-3 クラスそのものである。
→ **issue が訴えた欠陥を検出しても止めないゲートになる。**

派生して **TC-06 が (A) の下では原理的に成立しない**。サンドボックスは baseline の I-1 を
含むため、M1a を注入しても I-1 は rc に寄与せず rc=0 のままで、`rc=1` の assert が満たせない。

rev0 が引いた前例も誤っていた:

- `tests/fixtures/eh3-known-gap-1089.flag` は **`33d8de8` に存在しない**（前例は既に解除済み）
- `ta-65` は (i) **既定 = fixed（強制）** + tracked flag による**明示 opt-in**、
  (ii) gap mode でも**期待 rc を明示 assert**、(iii) **stale 宣言検出で FAIL** の 3 性質を持つ。
  rev0 は名前で引くだけで 3 つとも継承していなかった

**rev1 の採用形**: known-gap を**件数ではなく `(file, target)` の tracked allowlist** で pin する。

- 置き場所: `tests/fixtures/ref-resolution-known-gap.tsv`（tracked）
- 1 行 = `<invariant>\t<relative path>\t<target>\t<reason / issue>`
  例: `I-1\tplugin/plangate/skills/ai-loop-cycle/references/loopspec.md\tworking-context.md\t#1163 L-3`
- 判定:
  - **allowlist に無い violation は rc=1**（I-1 / I-3 も rc に寄与する）
  - **allowlist にあるのに検出されない entry は stale として FAIL**（是正済み or 検査が壊れた）
  - allowlist に一致する violation は `[known-gap]` 接頭辞で出力するが rc に寄与しない

`ta-65` の 3 性質の継承:

| `ta-65` の性質 | 本設計での対応 |
|---|---|
| (i) 既定 = 強制 / tracked flag による明示 opt-in | 既定 = strict。緩和は **tracked な TSV の行**でのみ成立し、行の追加は必ず diff に現れる |
| (ii) gap mode でも期待 rc を明示 assert | TC-03 は「allowlist と findings が**同値**」を assert（rc=0 を漫然と assert しない） |
| (iii) stale 宣言検出で FAIL | TC-11。allowlist にあるのに出ない entry は FAIL |

**#1087 AC-9 との関係**: これは**集合の同値照合**であり絶対件数の契約ではない。
`tests/extras/` の件数を assert しないのと同じ理由で許容される。
allowlist の**行数**はどこにも assert しない。

**AC-1 との関係**: この機構は「AC-1 を案 1 で再定義した場合の実装形」である。
**再定義するか否かは §6 冒頭のとおり C-3 の Human 判断**であり、本書は決めない。

---

## 12. 既知の限界 / follow-up

| # | 内容 | 対応 |
|---|---|---|
| **L-1** | I-3 はクラス単位・ファイル単位の被覆。同一ファイル内の一部参照だけ注記が無い状態は通る（§5.4） | パス単位化は別 PBI。`645220b` 実測で 257 件出るため段階的に |
| **L-2** | `ta-69` と `ta-70` を同時に消せば静かに緑（§9.3.2） | §9.4 の workflow patch を Human が適用すれば解消 |
| **L-3** | `plugin/plangate/skills/ai-loop-cycle/references/**`（23 件）は正本側（`.agents/skills/ai-loop-cycle/`）に対応物が無い。是正には生成元（`docs/workflows/ai-loop/`）側の変更が要る | 本 PBI 対象外。**新規 issue 候補**（§6.1 の I-1 6 件 + §6.2 の I-3 20 件） |
| **L-4** | 散文検出（`plugin root` / `plugin ルート`）は日本語表記ゆれに弱い。実測で `plugin ルート` は現 main に **0 件**（将来形として保持） | 語彙リストを検査本体に明示定数で持ち、追加は 1 行の意識的変更にする |
| **L-5** | `.codex/skills` は report-only（§10）。**解除トリガーは §10.1 の TC-09 / TC-10 で持つ**（rev0 は解除トリガーを持っていなかった） | #956 裁定後に 1 行削除 |
| **L-6** | 現 main（`33d8de8`）の I-1 = 6 / I-3 = 22 は**未是正の欠陥**（§6） | 本 PBI では是正しない。§11.2 の allowlist で pin する（AC-1 の再定義は C-3 判断） |
| **L-7** | 梯子ブロック検出 (b) は「番号 1 始まりの順序付きリスト + 解決語彙」。番号を使わない箇条書きの梯子は取り逃す | 語彙側で補うか、`-` リストにも (b) を拡張するかは実装時に再測定して決める |
| **L-8** | §2.4 の句点打ち切りは 2 文構成の欠陥段を取り逃す（§2.4.1） | 変異 **M3c** で SURVIVE を実証したうえで否定文構造による終端へ改める |
| **L-9** | §3.2（bare 参照）を採ると偽陽性リスクが増える。「正本と同名の別ファイル」を語る文脈を拾いうる | allowlist に `reason` 付きで pin できる。採否は C-3 判断（§6 冒頭） |
| **L-10** | AC-3 の 7 skill は偽陽性チェックの十分条件ではない（§8）。`skill-creator` / `plan-review-gate` は 7 skill 外なのに誤検出しうる位置にある | 実装 PBI で「前回実行との findings 集合差分」を併せて確認する |
| **L-11** | `scripts/*.py` と `tests/extras/*.sh` は **HO 対象外**（§9.2）。AI が no-task セッションで編集できる | §9.3 の 3 層 + §9.4 の Human patch で緩和。HO への追加は本 PBI の範囲外（承認境界の変更に当たる） |

---

## 付録: 本書の実測に用いたコマンド

すべて worktree 内の使い捨てディレクトリで実施し、成果物は本書のみ。
**測定 ref は必ず明示する**（作業ツリーの `ls` / `grep` は stale になりうるため使わない）。

| 目的 | コマンド |
|---|---|
| 対象ツリーの取得 | `git archive 33d8de8 -o <tmp>.tar` → `tar -xf <tmp>.tar -C <sandbox>` |
| 配布実体の件数 | `git ls-tree -r 33d8de8 --name-only -- plugin/plangate/docs plugin/plangate/schemas` / `... -- plugin/plangate/rules` |
| root ごとの `*.md` / `SKILL.md` 件数 | `git ls-tree -r 33d8de8 --name-only -- <root>` を集計 |
| 配布 source | `git show 33d8de8:install.sh` 等から `PLUGIN_DIR` / `SKILLS_DIR` / `SOURCE_DIR` の宣言行を確認（変数名で引く） |
| HO 対象パス | `git show 33d8de8:scripts/hooks/check-plan-hash.sh` の `_override=0` 直後の `case` ブロック |
| extras 契約 | `git show 33d8de8:tests/extras/ta-61-extra-contract.sh` / `... ta-65-eh3-ho-task-context.sh` / `... ta-69-distribution-checks.sh` |
| 先行検査の root 列挙 | `git show 33d8de8:scripts/check-skill-frontmatter.py` の `discover_skill_roots()` |
| 検出器 | プロトタイプ（Python）を tmp に置き、4 root それぞれに対して実行。**`645220b` で rev0 の 18 / 0 / 0 / 22 を再現できることを先に確認**してから `33d8de8` を測る |
| プレースホルダ語彙 | サンドボックスの強制 root 配下 `*.md` に対する部分文字列一致のファイル数 |
| ワイルドカード条項の影響 | 条項あり / なしの 2 版で M1a 注入前後の I-1 を比較（§3.3 の表） |
| 変異注入 | `.agents/skills` + `plugin/plangate/skills` をサンドボックスへコピーし変異を個別適用、baseline との差分で判定。**注入 root を必ず記録する** |
