# #1163 参照解決順 機械ゲート — 検出器 設計書

> **本書は設計のみ。実装（`scripts/` / `.github/workflows/` / `tests/`）は含まない。**
> 差分は本書内に提示する。

| 項目 | 値 |
|---|---|
| 起点 | `origin/main` = `645220b` |
| 対象 issue | [#1163](https://github.com/s977043/PlanGate/issues/1163) |
| 先例 | PR #1158（クラス C の plugin root 段除去 / 変異 M2・M4） / PR #1164（クラス A 梯子追加・**OPEN**） |
| 検証環境 | 使い捨てサンドボックス（本書 §7 参照。リポジトリには残さない） |

---

## 0. 前提となるクラス定義

| クラス | 参照先 | plugin 配布実体 | 正しい解決順 |
|---|---|---|---|
| **クラス A** | `.claude/rules/*.md` | `plugin/plangate/rules/` に **6 件実在**（実測） | 導入先 → **plugin root 配下** → 未参照明示 |
| **クラス C** | `docs/**` / `schemas/**` | `plugin/plangate/docs` / `plugin/plangate/schemas` は **tracked 0 件**（実測） | 導入先 → 未参照明示（**plugin root 段を置かない**） |

実測（`git ls-tree -r HEAD --name-only`）:

- `plugin/plangate/docs` + `plugin/plangate/schemas` … **0 件**
- `plugin/plangate/rules` … **6 件**（hybrid-architecture / mode-classification / orchestrator-mode / responsibility-classes / review-principles / working-context）

**この非対称（rules は配布される / docs・schemas は配布されない）が 3 不変条件すべての根拠**である。

---

## 1. 走査 root の宣言と enforcement scope

**root は宣言的に列挙し、宣言した root が不在なら enforcement 対象か否かに関わらず violation** とする（`scripts/check-codex-skill-spec.sh` の #1109 R-001 と同じ思想。「見に行く先が無い」を緑にしない）。

| root | tracked SKILL.md | 配布経路上の役割 | I-1 | I-2 | I-3 | 根拠 |
|---|---:|---|:--:|:--:|:--:|---|
| `.agents/skills` | 39 | **正本**（sync / codex installer の source） | 強制 | 強制 | 強制 | `sync-plugin-plangate.sh` の `SKILLS_DIR` / `install-plangate-skills-to-codex.sh` の `SOURCE_DIR` |
| `plugin/plangate/skills` | 39 | **配布実体**（marketplace が読む） | 強制 | 強制 | 強制 | `install.sh` の `PLUGIN_DIR` |
| `.claude/skills` | 29 | **どの配布経路の source でもない** | 対象外 | 対象外 | 対象外 | §1.1 |
| `.codex/skills` | 39 | drift 中・**#956 判断待ち** | report-only | report-only | report-only | §10 |

配布 source の実測（3 経路とも `.claude/skills` を source にしていない）:

- `install.sh:16` … `PLUGIN_DIR` は `plugin/plangate`
- `scripts/sync-plugin-plangate.sh:24` … `SKILLS_DIR` は `.agents/skills`
- `scripts/install-plangate-skills-to-codex.sh:25` … `SOURCE_DIR` は `.agents/skills`（環境変数で上書き可）

issue 本文は `install.sh:17` としているが `645220b` の実体は **16 行目**。行番号アンカーは stale 化するため、本書は **宣言変数名**を主アンカーとし行番号を補助とする。

### 1.1 `.claude/skills` を 3 不変条件の対象外にする理由

`.claude/skills` は上記 3 経路のいずれの source でもない。ここに閉じた skill は **導入先へ配布されないため、`docs/` も `.claude/rules/` も常にローカルで解決する**。したがって梯子も解決順注記も不要であり、対象に含めると AC-3 の 4 skill（`hypothesis-logger` / `plan-quality-reviewer` / `plangate-working-discipline` / `pr-watch`）で誤検出する。

**実測**: `.claude/skills` を強制対象にすると I-3 が **10 件**発火し、うち `hypothesis-logger` / `plangate-working-discipline` / `pr-watch` を含む。→ **対象外が正しい**。

`.claude/skills` は「**宣言はするが 3 不変条件は適用しない root**」として理由付きで manifest に残す。ディレクトリごと消えた場合は root 不在 violation で気づける。

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

**句点で打ち切ることが必須**である。`plan-review-gate` の注記は「… (2) 見つからなければ … 推測で内容を補わない。**plugin root 配下の探索は docs には適用しない**: …」の形で、**禁止文が手順 (2) の直後に続く**。句点で切らないと禁止文が手順 (2) に吸収され、健全な現行 main が誤検出になる。

### 2.5 ターゲット束縛（近接ヒューリスティック禁止）

手順が扱う**ターゲットのクラス**を次で決める。

1. 手順テキスト内に明示パスがあればそれ（`docs/` / `schemas/` / `rules/`。`.claude/rules/x.md` や plugin root 配下の `rules/x.md` も `rules` と判定する）
2. 明示が無いときのみ、**そのブロックのスコープ宣言**（起点セグメント）のクラスを継承する

「直前の行 / 近い行」という距離は一切使わない。§2.1 の 2 行の例では、2 行目は自身に `rules/` を持つため `rules` に束縛され、1 行目の `docs` を継承しない。**この 1 点を落とすと `ui-ux-lane.md` が確実に誤検出になる**（プロトタイプで実際に 2 件出た）。

---

## 3. I-1 の判定アルゴリズム

> **`.claude/rules/*.md` を参照する配布 skill は plugin root 配下 `rules/` の梯子を持つ。**

対象: **強制 root** 配下の全 `*.md`（`SKILL.md` と `references/*.md` の両方。フェンス内は除外）。

- `referenced` … 本文中の `.claude/rules/<basename>` 参照の basename 集合
- `laddered` … plugin root プレースホルダ（角括弧形 / `CLAUDE_PLUGIN_ROOT` 形 / `plugin/plangate` リテラル）に続く `rules/<basename>` の basename 集合。`rules/*.md` というワイルドカード梯子は全 basename を満たすとみなす
- **violation = `referenced` から `laddered` を引いた差集合**

**ファイル単位ではなくターゲット単位で束縛することが要点**。ファイル単位（「梯子が 1 個でもあれば OK」）にすると、既に別ターゲットの梯子を持つファイルに新しい rules 参照を足しただけで検出できない — PR #1158 の変異 **M2**「マーカーが file 内 1 箇所あれば全体を免除」と同型の FN になる。実証は §7 の **M1a**。

---

## 4. I-2 の判定アルゴリズム

> **`docs/**` / `schemas/**` の解決順に plugin root 段を含まない。**

2 つの副検査に分ける。片方だけでは不十分であることを §7 で実証する。

### 4.1 I-2a — トークン束縛（リテラル形）

セグメント単位で、plugin root プレースホルダの**直後のパス要素**を見る。それが `docs` / `schemas` なら violation。

検討して**採らなかった**案:

- **「plugin root と docs が同一セグメントに同居したら violation」** … クラス A と C を 1 本のリストで共用している skill（#1158 が「手順 2 は rules に対して実際に機能するため削除できない」と結論した 7 本）が全部誤検出になる。実測で **12 件の誤検出**（`ai-dev-verify` / `working-context` / `subagent-team-design` / `ui-ux-lane`）。
- **「プレースホルダは必ず `/rules/` を伴うべし」** … `plugin/plangate/skills` `plugin/plangate/commands` `plugin/plangate/hooks` などの**正当な配布物パス言及**まで巻き込み **97 件**の誤検出。

採用形（**直後が docs / schemas のときだけ violation**）は現 main で **0 件**。

### 4.2 I-2b — 梯子ブロック単位（ブロック形 / M4 対策）

§2.3 の梯子ブロックを取り、§2.4 の手順に分解し、§2.5 でターゲットを束縛したうえで:

- **手順が plugin root に言及し**（プレースホルダ **または** 散文の「plugin root」「plugin ルート」）
- **かつ 束縛クラスが docs / schemas を含み**
- **かつ 手順自身が rules を明示していない**

とき violation。

**散文も見る**のが要点。#1158 の F-5 でプレースホルダを注記から全廃した結果、「2. 無ければ plugin root 配下の同名パスを探す」という**リテラルを含まない欠陥段**が書けてしまう。これは I-2a では原理的に捕まらない（§7 M3 / M3b で実証）。

**禁止文が誤検出にならない理由**は、それが**手順ではない**から。マーカーによる免除ではなく、構造（`(N)` 記法・順序付きリスト項目でない）で除外している。したがって #1158 の M2 型 FN（マーカー 1 個で file 全体を免除）は原理的に発生しない。実証は §7 の **M5**。

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
- **violation = `used` のうち docs / schemas であって `covered` に無いもの**（クラス単位）

### 5.3 消費側 artifact の除外（誤検出ガード）

`docs/working/TASK-XXXX/**` / `docs/working/PBI-*/**` / `docs/working/` 単体は、**導入先で PlanGate 実行時に生成される作業成果物**であり上流リポジトリの配布物ではない。常に導入先で解決するため注記の対象外とする。

除外しないと `breakdown-gate`（`docs/working/TASK-XXXX/todo.md`）/ `plangate-setup`（`docs/working/` 構造）/ `evidence-ledger` / `ref-integrity-scan` が誤検出になり **AC-3 に反する**。実測: 除外前 33 件 → 除外後 22 件、減った 11 件はすべてこのクラス。
`docs/working/templates/*.md` は上流資産なので**除外しない**。

### 5.4 既知の弱み（明示）

I-3 は**クラス単位・ファイル単位**の被覆であり、「同一ファイル内で docs 参照が 10 個あって注記が 1 個」でも通る。パス単位に締めると現 main で **257 件**発火する（注記が個々のパスを列挙していないため）ので、本 PBI では採らない。
**この弱みは I-2b が別方向から塞ぐ**（欠陥のある梯子は注記の有無に関わらず検出される）。パス単位化は follow-up（§12 L-1）。

---

## 6. 現 main（`645220b`）での実測 — AC-1

**強制 root（`.agents/skills` + `plugin/plangate/skills`、`*.md` 111 件）**:

| 不変条件 | violation | 判定 |
|---|---:|---|
| **I-1** | **18** | **0 ではない**（未是正。内訳は §6.1） |
| **I-2a** | **0** | PASS |
| **I-2b** | **0** | PASS |
| **I-3** | **22** | **0 ではない**（未是正。内訳は §6.2） |

### 6.1 I-1 の 18 件 — 未是正の欠陥（**是正しない。報告のみ**）

`.agents/skills` 単独では **6 件 / 4 skill**。PR #1164（**OPEN・未マージ**）の是正対象と**完全に一致**する。

| ファイル | 参照しているのに梯子が無い正本 |
|---|---|
| `.agents/skills/design-gate/SKILL.md` | `mode-classification.md` |
| `.agents/skills/intent-classifier/SKILL.md` | `mode-classification.md` |
| `.agents/skills/plan-review-gate/SKILL.md` | `mode-classification.md` / `review-principles.md` / `working-context.md` |
| `.agents/skills/skill-policy-router/SKILL.md` | `mode-classification.md` |

`plugin/plangate/skills` は上記の sync コピー 6 件 **＋ 新規クラス 6 件**:

| ファイル | 参照しているのに梯子が無い正本 |
|---|---|
| `plugin/plangate/skills/ai-loop-cycle/references/agentic-six-stage-loop.md` | `hybrid-architecture.md` / `orchestrator-mode.md` / `responsibility-classes.md` |
| `plugin/plangate/skills/ai-loop-cycle/references/arbiter-policy.md` | `responsibility-classes.md` |
| `plugin/plangate/skills/ai-loop-cycle/references/loopspec.md` | `working-context.md` |
| `plugin/plangate/skills/ai-loop-cycle/references/related-specs.md` | `responsibility-classes.md` |

**`.agents/skills/ai-loop-cycle/` には `references/` が存在しない**（`SKILL.md` のみ）。これらは配布時に別経路で生成される 20 ファイルであり、**正本側に対応物が無いため今まで誰も是正していない**。#1163 が予測した「新しいクラスの穴」の実例。

**PR #1164 がマージされても 6 件（ai-loop-cycle references）は残る。**

### 6.2 I-3 の 22 件 — 未是正の欠陥（**是正しない。報告のみ**）

- `.agents/skills/ai-loop-cycle/SKILL.md` … 1 件（`docs/workflows/ai-loop/` を注記なしで参照）
- `plugin/plangate/skills/ai-loop-cycle/**` … 21 件（`SKILL.md` 1 + `references/` 20。うち 2 件は `schemas/`）

**22 件すべてが `ai-loop-cycle` 系**であり、§6.1 の 6 件と同じ「配布 references が正本側に存在しない」構造に由来する。

### 6.3 参考: 強制対象外 root の実測（report-only）

| root | I-1 | I-2a | I-2b | I-3 |
|---|---:|---:|---:|---:|
| `.claude/skills`（対象外） | n/a | 0 | 0 | 10 |
| `.codex/skills`（#956 待ち） | 6 | 0 | 0 | 23 |

`.codex/skills` の I-1 6 件は `.agents` 側と同じ 4 skill。`.agents` に追随していないため、**#1158 finding 3 が言う 31 file の drift がそのまま数字に出ている**。

---

## 7. 変異注入の設計と結果 — AC-2

サンドボックス（`.agents/skills` + `plugin/plangate/skills` を tmp へコピー）に変異を 1 つずつ適用し、baseline との差分で KILL / SURVIVE を判定した。

baseline（変異なし）は **I-1 = 18 / I-2a = 0 / I-2b = 0 / I-3 = 22**。

| ID | 対象 | 変異内容 | 形式 | 期待 | 結果 |
|---|---|---|---|---|---|
| **M1a** | `breakdown-gate/SKILL.md` | 既に `mode-classification` の梯子を持つファイルに、梯子なしの `review-principles.md` 参照を**追記** | 追記 / 混在ファイル | I-1 +1 | **KILL**（I-1 = 19） |
| **M1b** | `diff-audit/SKILL.md` | ファイル内で唯一の梯子（**4 行にまたがる `(2)` 手順ブロック**）を削除し非梯子手順へ置換 | **ブロック** | I-1 +1 | **KILL**（I-1 = 19） |
| **M2** | `subagent-dispatch/SKILL.md` | docs 梯子に plugin root プレースホルダ + `/docs/...` 段を**リテラルで**再導入 | 行 | I-2a +1 | **KILL**（I-2a = 1 / I-2b も 1） |
| **M3** | `subagent-dispatch/SKILL.md` | 同じ位置に**散文で**「(2) 無ければ plugin root 配下の同名パスを探す。」を挿入（**リテラル無し**） | 散文 | I-2b +1 かつ **I-2a は 0 のまま** | **KILL**（I-2a = **0** / I-2b = 1） |
| **M3b** | `context-packager/SKILL.md` | 「参照解決順」の語を**使わず**、docs 宣言行と「2. 無ければ plugin root 配下の同名パス」を**別々の行**に置いた梯子を新設 | **ブロック / 複数行 / マーカー無し** | I-2b +1 | §2.3(b) 導入前 **SURVIVE** → 導入後 **KILL**（I-2b = 1） |
| **M4** | `breakdown-gate/SKILL.md` | 注記の無い状態で `docs/ai/plan-metrics-verification.md` 参照を追記 | 追記 | I-3 +1 | **KILL**（I-3 = 23） |
| **M5** | `review-gate/SKILL.md` | **クラス A ブロックは健全なまま**、クラス C ブロックにだけ散文の plugin root 段を挿入（#1158 M2 と同型） | ブロック / 混在ファイル | I-2b +1 | **KILL**（I-2b = 1） |

### 7.1 M4 型（行スコープで取り逃すもの）の扱い

- **M3** は plugin root の言及にリテラルが無いため、`grep` 相当の**行スコープ検査では原理的に 0 件**になる。実測でも **I-2a = 0 / I-2b = 1**。**「行スコープでは取り逃す / 段落スコープなら捕る」を同一変異で両側から示した唯一の証拠**。
- **M3b** はさらに「docs 宣言と plugin root 段が別行」「見出しに『参照解決順』の語が無い」。**§2.3 の (a) だけの梯子検出では実際に SURVIVE した**。(b)（番号 1 始まりの順序付きリスト + 解決語彙）を足して初めて KILL。
  → **梯子検出そのものをマーカー非依存にすることが AC-2 の必須要件**であり、本設計に組み込み済み。

### 7.2 fail-closed（root 不在）の検出力

宣言 root が存在しないディレクトリに対して実行すると `declared root not found` を出力し rc=1（実測）。**「見に行く先が消えたら緑」を作らない。**

---

## 8. 偽陽性の確認 — AC-3

強制 root での実行結果を、指定の 7 skill 名で grep した結果は **0 件**（`NO FINDINGS`）。

| skill | 所在 | 発火 | 発火しない理由 |
|---|---|:--:|---|
| `breakdown-gate` | `.agents/skills` | なし | I-1: `mode-classification` の梯子が 3 箇所ある / I-3: `docs/working/TASK-XXXX/todo.md` は §5.3 の消費側 artifact |
| `plangate-setup` | `.agents/skills` | なし | I-1: 梯子 2 箇所 / I-3: `docs/working/` 構造の言及のみ（§5.3） |
| `local-exec-handoff` | `.agents/skills` | なし | I-1: 梯子 2 箇所 / I-3: 注記あり |
| `hypothesis-logger` | `.claude/skills` のみ | なし | §1.1 により root ごと対象外 |
| `plan-quality-reviewer` | `.claude/skills` のみ | なし | 同上 |
| `plangate-working-discipline` | `.claude/skills` のみ | なし | 同上 |
| `pr-watch` | `.claude/skills` のみ | なし | 同上 |

**7 skill すべてが実在することも確認済み**（`ls -d` で 7/7）。「対象に無いから発火しない」と「対象だが健全だから発火しない」の区別を上表で明示している（前者を後者と混同すると、対象外設定が壊れたときに気づけない）。

---

## 9. CI 配線の設計 — AC-4（最重要）

### 9.1 前提の実測

`tests/run-tests.sh` は `tests/extras/ta-*.sh` を **glob で自動 source** する（`tests/run-tests.sh:164-171`。`EXTRAS_DIR` を for ループの glob に展開し、`[ -f ]` で存在チェックしてから `.` で source）。許可リストは存在しない。

実測での裏取り:

- `ls tests/extras/ta-*.sh` の件数 = **65**
- 同一 glob を同一条件で回した件数 = **65**（同値）

そして `.github/workflows/test.yml:28` が `sh tests/run-tests.sh` を **`pull_request` と `push:main` の両方**で回す。

→ **`tests/extras/ta-NN-*.sh` を 1 ファイル置くだけで CI 経路に載る。`.github/`（HO）に触らずに済む唯一の経路であり、最小コスト。**

参考: `scripts/release-prep.sh` の `run_checks` も検査集約点だが、**どの workflow からも呼ばれていない**（実測: `.github/workflows/` に `release-prep` の参照ゼロ）。ここに足しても CI は赤くならない。

### 9.2 「検査を外すと CI が赤くなる」の担保設計

前例 4 件（#937 / #984 / #1087 / `check-stale-skill-refs.py`）はいずれも「**検査は書いたが呼び出し側が無い**」型。外し方は 3 通りあるので、3 通りすべてに赤を対応させる。

| 外し方 | 何が起きるか | 赤にする仕組み | 層 |
|---|---|---|---|
| **(1) 検査本体を消す / 壊す** | `scripts/check-ref-resolution.py` 不在 | `ta-70` の TC-01 が「存在・python3 で実行可能・`--selftest` rc=0」を assert（`ta-64` TC-01 と同型） | extras |
| **(2) 検査は残るが rc が握り潰される** | violation が出ても緑 | `ta-70` は**本番ツリーに対して既定引数で実行**し rc と出力の両方を assert。`--warn-only` 相当のオプションを**そもそも実装しない** | extras |
| **(3) `ta-70` 自体を消す** | glob が拾わないので**静かに緑** ← 前例と同型の穴 | **`ta-69-distribution-checks.sh` に配線レジストリ TC を追加**（§9.3） | 別レーン |

### 9.3 (3) を塞ぐ配線レジストリ

`tests/extras/` に共有ファイルを新設することは規約上できない（`_extra-contract.sh` が唯一の例外と `tests/extras/README.md` に明記）。したがって**既存の別レーンの extras に宣言を置く**。

- 置き場所: **`tests/extras/ta-69-distribution-checks.sh`**（#1087「配布物検査の CI 未配線」を扱うレーン。責務が一致する）
- 内容: 「配布物検査 とその呼び出し元」の対応表を**明示列挙**し、各行について (1) 検査本体が存在すること (2) その検査を実行する extras ファイルが存在すること を assert する

提示する追加（設計。本 PBI では未適用）:

```sh
# 配布物検査 と 呼び出し元 のレジストリ（#1163 AC-4 / #1087 と同じ「未配線を機械検出する」思想）
# 1 行 = "<検査スクリプト> <その検査を CI 経路へ載せる extras ファイル>"
# 行を消すのは 1 行の意識的なコード変更であり diff / レビューに必ず現れる。
_T69_WIRING='scripts/check-ref-resolution.py tests/extras/ta-70-ref-resolution.sh'

printf '%s\n' "$_T69_WIRING" | while read -r _script _wiring; do
  [ -n "$_script" ] || continue
  if [ -f "$_T69_ROOT/$_script" ] && [ -f "$_T69_ROOT/$_wiring" ]; then
    t69_pass "TC-W1 wiring present: $_script"
  else
    t69_fail "TC-W1 wiring missing: $_script / $_wiring"
  fi
done
```

（`while` をパイプで回すとサブシェルで `pass` / `fail` が更新されないため、実装時は here-doc + `read` ループなど**サブシェルを作らない書法**にすること。`tests/extras/README.md` の set -e 互換書法も併せて遵守する。）

**絶対件数は書かない**。`tests/extras/` は増え続けるディレクトリであり、これは行の**同値照合**であって件数契約ではない。

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

> **推奨は「`tests/extras/` 経由（§9.2 の 3 層）を本体とし、§9.4 の workflow step を Human 適用の任意強化として併記する」。独立 workflow は新設しない。**

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

**勝手に enforcement へ入れない根拠（実測）**: `.codex/skills` は現状 I-1 = **6**、I-3 = **23** で、含めると **即座に CI が赤くなる**。しかも #1158 が実測したとおり `.codex/skills/plan-review-gate/SKILL.md` には #956 が審議中の「C-1 追加品質ゲート」節が実在し、**再同期は判断材料を消す**。是正は #956 の裁定後。

report-only の出力形（設計）:

```text
[ref-resolution] .codex/skills: 29 findings (deferred: #956 -- not counted in rc)
[ref-resolution]   [deferred:#956] .codex/skills/plan-review-gate/SKILL.md: working-context.md referenced without plugin-root ladder
```

---

## 11. 実装形（既存流儀の踏襲）

`scripts/check-*.py` / `check-*.sh` を実測した結果、本検査は **単体 Python スクリプト**（`check-stale-skill-refs.py` / `check-skill-frontmatter.py` / `check-skill-name-collisions.py` と同系）が適切。`check-codex-skill-spec.sh` の sh ラッパ + 埋め込み Python 形は「`--warn-only` の rc 方針を shell 側 1 箇所に集約する」ためのものだが、本検査は `--warn-only` を持たない（AC-4 の趣旨に反する）ので不要。

踏襲する流儀:

| 流儀 | 出典 | 本検査での適用 |
|---|---|---|
| 走査 root を**宣言定数**で持ち、不在は violation | `check-codex-skill-spec.sh` の `DEFAULT_TARGETS` / #1109 R-001 | `DECLARED_ROOTS` / `ENFORCED_ROOTS` / `DEFERRED_ROOTS` / `EXEMPT_ROOTS` |
| **絶対件数を契約値にしない** | `ta-69` の #1087 AC-9 | 検査は集合比較のみ。テストも「注入した違反が出力に含まれる」で契約 |
| skip したものは件数と理由を必ず出す | #1109 | 対象外 root / フェンス / 消費側 artifact の除外件数を出力 |
| `--selftest` を持つ | `check-stale-skill-refs.py` | 内蔵 fixture で 7 変異を自己検証 |
| rc: 0 = 違反なし / 1 = 違反あり / 2 = 引数エラー | `check-stale-skill-refs.py` | 同一 |
| 行番号アンカーを正本に書かない | #1089 | 参照は宣言変数名・記号アンカーで書く |

### 11.1 提示する新規ファイル（骨子）

```text
scripts/check-ref-resolution.py
  DECLARED_ROOTS = (".agents/skills", ".claude/skills", ".codex/skills", "plugin/plangate/skills")
  ENFORCED_ROOTS = (".agents/skills", "plugin/plangate/skills")
  DEFERRED_ROOTS = (".codex/skills",)     # #956 裁定待ち。1 行削除で enforcement 入り
  EXEMPT_ROOTS   = (".claude/skills",)    # 配布 source でない（install.sh / sync / codex installer 実測）

  segment(lines)          -- 2.1 セグメンテーション
  sections(lines)         -- 2.2 セクション
  ladder_blocks(segs)     -- 2.3 梯子ブロック（(a) 語 + (b) 構造。マーカー非依存）
  steps_of(seg)           -- 2.4 手順抽出（(N) 記法・句点終端）
  bind_class(step, block) -- 2.5 ターゲット束縛（明示 -> ブロック宣言。距離は使わない）

  check_i1 / check_i2a / check_i2b / check_i3    -- 3 / 4 / 5 節
  main() -> rc 0|1|2
```

```text
tests/extras/ta-70-ref-resolution.sh
  TC-01  scripts/check-ref-resolution.py が存在し python3 で実行可能
  TC-02  --selftest が rc=0
  TC-03  本番ツリー（既定引数）で I-2a / I-2b が 0
  TC-04  sandbox に M2 を注入 -> rc=1 かつ出力に I-2a が含まれる
  TC-05  sandbox に M3b（M4 型）を注入 -> rc=1 かつ I-2b が含まれ I-2a は 0
  TC-06  sandbox に M1a を注入 -> rc=1 かつ I-1 が含まれる
  TC-07  宣言 root を消した sandbox -> rc=1 かつ "declared root not found"
  TC-08  AC-3 の 7 skill 名が本番ツリーの出力に現れない
  (件数は assert しない / #1087 AC-9)
```

### 11.2 baseline が 0 でないことへの対処

§6 のとおり現 main には I-1 = 18 / I-3 = 22 の未是正が残る。したがって **TC-03 で「全体 rc=0」を assert してはならない**。取りうる形は 2 つ:

- **(A) 段階導入（推奨）**: **I-2a / I-2b のみ rc に寄与**させ、I-1 / I-3 は `[known-gap]` として出力のみにする。known-gap flag ファイル方式は v8.20.0 の `tests/fixtures/eh3-known-gap-1089.flag` に前例がある。PR #1164 のマージと ai-loop-cycle 系の是正が完了した時点で flag を削除し full enforcement へ。
- **(B) 先に是正**: #1164 をマージし、ai-loop-cycle references の 28 件を別 PBI で是正してから full enforcement。

**推奨は (A)**。(B) は「検知器を作る」作業と「検知器が見つけたものを直す」作業の混在であり、#1087 が意識的に避けた形。

---

## 12. 既知の限界 / follow-up

| # | 内容 | 対応 |
|---|---|---|
| **L-1** | I-3 はクラス単位・ファイル単位の被覆。同一ファイル内の一部参照だけ注記が無い状態は通る（§5.4） | パス単位化は別 PBI。現 main で 257 件出るため段階的に |
| **L-2** | `ta-69` と `ta-70` を同時に消せば静かに緑（§9.3） | §9.4 の workflow patch を Human が適用すれば解消 |
| **L-3** | `plugin/plangate/skills/ai-loop-cycle/references/**` は正本側（`.agents/skills/ai-loop-cycle/`）に対応物が無い。是正には生成元（`docs/workflows/ai-loop/`）側の変更が要る | 本 PBI 対象外。**新規 issue 候補**（§6.1 + §6.2 の計 28 件） |
| **L-4** | 散文検出（`plugin root` / `plugin ルート`）は日本語表記ゆれに弱い | 語彙リストを検査本体に明示定数で持ち、追加は 1 行の意識的変更にする |
| **L-5** | `.codex/skills` は report-only（§10） | #956 裁定後に 1 行削除 |
| **L-6** | 現 main の I-1 = 18 / I-3 = 22 は**未是正の欠陥**（§6） | 本 PBI では是正しない。#1164 マージで 12 件解消、残り 28 件は L-3 |
| **L-7** | 梯子ブロック検出 (b) は「番号 1 始まりの順序付きリスト + 解決語彙」。番号を使わない箇条書きの梯子は取り逃す | 語彙側で補うか、`-` リストにも (b) を拡張するかは実装時に再測定して決める |

---

## 付録: 本書の実測に用いたコマンド

すべて worktree 内の使い捨てディレクトリで実施し、成果物は本書のみ。

| 目的 | コマンド |
|---|---|
| 配布実体の件数 | `git ls-tree -r HEAD --name-only -- plugin/plangate/docs plugin/plangate/schemas` / `... -- plugin/plangate/rules` |
| 配布 source | `sed -n` で `install.sh` / `sync-plugin-plangate.sh` / `install-plangate-skills-to-codex.sh` の宣言行を確認 |
| extras glob | `ls tests/extras/ta-*.sh` の件数と for ループ展開の件数を同値照合 |
| 検出器 | プロトタイプ（Python）を tmp に置き、4 root それぞれに対して実行 |
| 変異注入 | `.agents/skills` + `plugin/plangate/skills` を tmp にコピーし 7 変異を個別適用、baseline と件数差分で判定 |
