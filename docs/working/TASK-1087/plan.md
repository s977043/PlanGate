# EXECUTION PLAN — TASK-1087 (#1087)

> 配布物検査 3 本を **CI に配線できる状態にする**。
> 2 本の rc=1 は **検査側の誤り**であることを全件実測で確定させ、
> **偽陽性だけを落として真陽性の検出力は残す**。
> `.github/workflows/*` は Hardening Override 対象のため **patch 提示まで（AI は適用しない）**。

## Goal

`check-skill-name-collisions.py` と `check-stale-skill-refs.py` が
**「実態と一致した判定」で rc=0 を返す**状態にし、
**CI に配線しても偽陽性で赤にならず、かつ真の違反では確実に赤になる**ことを
変異注入で実証する。そのうえで CI 配線 patch を提示する。

## 中核判断: 「なぜ 46 件が偽陽性なのか」の構造的根拠

`plugin/plangate/` は **手書きの第 2 定義ではない**。
`scripts/sync-plugin-plangate.sh` が `.claude/` から **生成する export** である。

```
.claude/agents/<name>.md    ──sync-plugin-plangate.sh──▶  plugin/plangate/agents/<name>.md
.claude/commands/<name>.md  ──sync-plugin-plangate.sh──▶  plugin/plangate/commands/<name>.md
.agents/skills/<name>/      ──sync-plugin-plangate.sh──▶  plugin/plangate/skills/<name>/
        ▲
        └─ skill の正本は .agents/skills（check-skill-frontmatter.py が「正本」と明記）。
           .claude/skills は Claude Code レーンの同一スキルで、**機械的な同期は無い**
```

> **実測で判明した非対称（2026-08-18）**: skill だけ経路が違う。
> `plugin/plangate/skills/` は `.claude/skills/` ではなく **`.agents/skills/`** から生成される
> （`scripts/sync-plugin-plangate.sh` の skills ループは `SKILLS_DIR=.agents/skills` を読む）。
> `.claude/skills/` ⇄ `.agents/skills/` の**内容一致を検査する機構は存在しない**
> （`check-skill-frontmatter.py` は 4 root を見るが frontmatter の妥当性のみで、内容 parity は見ない）。
> 現存する 3 件の description 差分（`context-load` / `codex-multi-agent` / `ai-loop-cycle`）は
> すべてこの未担保レーンに存在する。**下表の担保はこの非対称を反映して書く**。

したがって repo-local ⇄ plugin:plangate の同名対は
**「2 つの独立した定義が名前を取り合っている」のではなく「1 つの定義とその配布コピー」**である。
`.claude/rules/hybrid-architecture.md` が
「**本リポジトリ内の Agent 定義は このリポジトリの成果物そのもの**」
「他リポジトリへ export する場合は `plugin/plangate/` 配下の export 版で固有名を抽象化する」
と明記しているのは、この生成関係を指している。

元 issue #692 の動機（interactive-ocean で `self-review` が
repo-local / growth-core / plangate の **3 重定義**）は
**「異なる供給元が同じ名前を主張する」クラス**であり、本件とは別クラスである。
現行実装は両者を区別していないため、producer repo では常に 46 件を出し続ける。

### この設計が「担保の空白」を作らない根拠（重要）

ミラー対を衝突から外すと、**source ⇄ export の内容 drift** は collisions 側では見なくなる。
しかしそれは **既存 CI がすでに hard fail で担保している**:

| ミラー対 | 内容一致の担保 | 発火条件 | 失敗の強さ |
|---------|--------------|---------|-----------|
| `.claude/agents/X` ⇄ `plugin/plangate/agents/X` | `sync-plugin-plangate.yml` の `drift-check` job | `.claude/**` / `.agents/skills/**` / `plugin/plangate/**` を触る **全 PR** | `exit 1` |
| `.claude/commands/X` ⇄ `plugin/plangate/commands/X` | 同上 | 同上 | `exit 1` |
| `.claude/skills/X` ⇄ `plugin/plangate/skills/X` | **部分的**。plugin 側 ⇄ `.agents/skills/X` は `drift-check` が担保するが、**`.claude/skills/X` ⇄ `.agents/skills/X` は未担保** | — | — |

agent / command は **責務の移譲であって放棄ではない**
（collisions は「名前の取り合い」を、drift-check は「コピーの一致」を見る）。

**skill レーンだけは、ミラー除外により内容 drift の検出が
「元々どこにも無かった状態」に戻る**（本 PBI が奪ったのではなく、
collisions の 46 件常時 rc=1 が**偶然そこに居ただけ**で、
そもそも description 差分しか見ておらず本文 drift は見ていなかった）。
これは **既知の残存ギャップとして handoff に上げ、別 PBI とする**
（本 PBI で `.claude/skills` ⇄ `.agents/skills` の parity 検査を新設するのは
スコープ外。#1144 / #1086 と同じ配布レーン整理の領域）。

## Approach Overview

### A. `check-skill-name-collisions.py` — ミラー分類の導入 + 検出力の追加

1. `Definition` に `root: Path` を持たせ、**root 内相対パス**（`skills/<n>/SKILL.md` ではなく
   `<n>/SKILL.md`）を取得可能にする。REPO_ROOT 非依存にすることで
   sandbox（ta-52）/ selftest の tmp root でも同じ判定が成立する。
2. `find_collisions` の抽出条件を
   **「distinct root_label が 2 以上」→「同一 (kind,name) の定義が 2 以上」**へ変更する。
   これにより **同一 root 内の重複**（現行は原理的に検出不能）が新たに検出対象になる = **検出力の追加**。
3. 各グループを 2 分類する:

   | 分類 | 条件（**全て**満たす） | rc への影響 |
   |------|----------------------|------------|
   | **accepted mirror** | ① 定義がちょうど 2 つ ② 一方の root_label が `repo-local` ③ 他方が `plugin:<p>` ④ **root 内相対パスが一致** | 影響しない（**情報として印字**） |
   | **true collision** | 上記以外すべて | **rc=1** |

4. レポートは **両方を印字**する（ミラーを黙って捨てない = AC-8。
   「出力から消える」ことによる第 2 の false green を作らない）。
5. doctor 契約（rc 0/1/その他 の 3 値）は不変（AC-12）。

#### 引き続き検出されるクラス（= 除外が広すぎないことの主張）

| クラス | 例 | 現行 | 変更後 |
|-------|---|------|-------|
| 3 定義以上 | repo-local + plugin-a + plugin-b（**#692 の動機ケース**） | 検出 | **検出** |
| plugin 同士の同名 | plugin-a + plugin-b（repo-local 無し） | 検出 | **検出** |
| 非ミラー位置での同名 | `.claude/skills/foo/` と `plugin/p/skills/bar/`（両方 `name: foo`） | 検出 | **検出** |
| **同一 root 内の重複** | `.claude/skills/a/` と `.claude/skills/b/` が両方 `name: x` | **検出不能** | **新規に検出** |

#### 検出しなくなるクラス（AC-7）

| 見逃しクラス | 内容 | 他層での担保 |
|------------|------|------------|
| **M-1a** | agent / command のミラー対の内容差 | `sync-plugin-plangate.yml drift-check`（**PR 単位で exit 1**） |
| **M-1b** | **skill** のミラー対（`.claude/skills` ⇄ `plugin/plangate/skills`）の内容差 | **未担保**。`.claude/skills` ⇄ `.agents/skills` の parity 検査が存在しない（既知の残存ギャップ / 別 PBI） |
| **M-2** | 本リポジトリ内で agent が `diff-audit` と `plangate:diff-audit` の両方を見るという **intra-repo の曖昧さそのもの** | 担保しない（`hybrid-architecture.md` が**設計どおり**と明記。規範側の決定） |

> M-1 は **description のみ**が対象ではない点に注意。ミラー対と判定された時点で
> 内容差は collisions では一切見ない。これは drift-check が本文まで含めて
> 完全一致を要求しているため、collisions 側で二重に見る必要が無いことによる
> （TASK-1093 R-002 の「判定を書き写さない」原則と同じ）。

### B. `check-stale-skill-refs.py` — 2 つの真のバグ修正

#### B-1. インラインコード内の Markdown リンク記法を **リンクとして扱わない**

現行 `extract_candidates` は生の行に `MD_LINK_RE`（`](...)`）を当てるため、
**コードスパンの中に書かれたリンク記法のリテラル**を実リンクとして拾う。

```
- **ファイル参照のリンク化**: … `` `[file.md](./file.md)` `` 形式でリンク化し …
                                    ^^^^^^^^^^^^^^^^^^^^^^ 記法の説明であってリンクではない
```

修正: コードスパン（バッククォート 1 個以上の対）を **マスクしてから** `MD_LINK_RE` を当てる。
コードスパンの中身自体は従来どおり候補として拾う（挙動不変）。

- **見逃しクラス S-1**: コードスパン内に**リンク記法として**書かれた stale パス。
  これはレンダリング上リンクにならない「記法の例示」であり、参照ではない。**意図どおり**。

#### B-2. **gitignore 対象パスを stale としない**

`.claude/settings.json` は `.gitignore:14` で ignore されている
= **リポジトリに存在しないことが正常**な、各利用者がローカル生成するファイル。
現行実装は `Path.exists()` だけを見るため:

- CI（settings.json 無し） → **5 件の WARN**
- 開発機（settings.json 有り） → **0 件**

という **実行環境依存**の判定になっている。これは検知器として不適格
（開発者がローカルで再現できない CI 失敗を生む）。

修正: 候補パスを **1 回のバッチ** `git check-ignore --stdin` に通し、
ignore 対象は stale 判定から外す。

- **見逃しクラス S-2**: gitignore パターンに合致し、かつ実際に誤っている参照。
  本リポジトリの `.gitignore` は具体パス列挙が中心のため範囲は極めて狭い
  （例: `.claude/settingz.json` のような typo は ignore パターンに合致せず**引き続き検出**）。
- **縮退**: `git` 不在 / `rc=128` 時は **何も除外しない**（= 現行挙動）。安全側。

### C. `.claude/skills/codex-multi-agent/SKILL.md` — 検査ではなくドキュメント側を直す

残る 1 件 `app/admin` は、派遣プロンプトの**例示**として書かれた具体パス:

```
- 「`app/admin` 配下でこの UI に関係する既存パターンを 3 点探して報告する」
```

**ここで検査側に「引用の中は見ない」除外を入れるのは誤り**である。
具体パスを例示に使っていること自体が
「参照と例示が機械的に区別できない」というドキュメント側の欠陥であり、
検査を弱めずに **プレースホルダ表記へ直せば解決する**（既存の placeholder ガードが効く）。

→ **検査の除外条件を 1 つ増やさずに済む**。見逃しクラスは発生しない。

`plugin/plangate/` 側は生成物のため、`sh scripts/sync-plugin-plangate.sh` で同期する。

## Files / Components to Touch

| ファイル | 変更 | HO |
|---------|------|-----|
| `scripts/check-skill-name-collisions.py` | ミラー分類 + 同一 root 重複検出 + selftest 拡張 | 対象外 |
| `scripts/check-stale-skill-refs.py` | コードスパンマスク + gitignore 除外 + selftest 拡張 | 対象外 |
| `.claude/skills/codex-multi-agent/SKILL.md` | 例示パスをプレースホルダ化 | 対象外 |
| `plugin/plangate/skills/codex-multi-agent/SKILL.md` | 上記の sync 生成物 | 対象外 |
| `tests/extras/ta-52-doctor-skill-collision.sh` | TC-03 を真の衝突構成へ / ミラー非衝突 TC 追加 | 対象外 |
| `tests/extras/ta-69-distribution-checks.sh` | **新規**。両検査の分類境界と変異 kill を検証 | 対象外 |
| `docs/ai/skill-collision-detection.md` | ミラー分類と見逃しクラスを追記 | 対象外 |
| `docs/ai/stale-ref-detection.md` | 2 バグ修正と見逃しクラスを追記 | 対象外 |
| `docs/working/TASK-1087/ci-wiring.patch` | **CI 配線 patch（未適用）** | 生成物。適用先は **HO** |

**触らない**: `.github/workflows/*`（HO・patch 提示のみ） / `bin/plangate`（HO） /
`scripts/hooks/*.sh`（HO） / `scripts/check-approval-token-write.sh`・`tests/extras/ta-25-*`（別ワーカー）

## Testing Strategy

| 層 | 内容 |
|----|------|
| **Unit（内蔵 selftest）** | 両スクリプトの `--selftest` に分類境界ケースを追加 |
| **Integration（`tests/extras/ta-69`）** | サンドボックスに **ミラー / 3 重定義 / plugin 同士 / 非ミラー位置 / 同一 root 重複** を構築し rc を突合 |
| **回帰（`ta-52`）** | doctor 統合の rc 3 値契約が不変であること |
| **変異注入** | 下記 2 系統。**call site を壊す**（関数定義ではなく） |
| **本番経路** | ta-69 の各 TC は **引数なしの既定経路**（`--extra-root` 等のテスト専用経路に偏らせない） |

### 変異の 2 系統（AC-11 / diff-audit Phase 6 item 6）

| 系統 | 変異 | 期待 |
|------|------|------|
| **レーン全体** | 分類呼び出しを `True` 固定（全部ミラー扱い）にする call site 変異 | 真の衝突 TC が FAIL |
| **レーン内部** | ミラー条件 4 項のうち **1 項ずつ**を落とす（例: root 内相対パス一致の判定を外す） | 対応する分類 TC のみが FAIL（レーン全体変異では露出しない穴） |

### 件数契約の禁止（AC-9）

`46` / `7` を assert しない。
`.claude/` と `plugin/` は運用で増減するため、**集合の性質**で契約する:

- 「本番スキャンで **true collision = 0**」
- 「本番スキャンで **stale = 0**」
- 「注入した違反が **出力集合に含まれる**」

## Risks & Mitigations

| # | リスク | 対応 |
|---|-------|------|
| R1 | ミラー除外が広すぎ真の衝突を通す | 4 条件の合接に限定 + レーン内部変異で各条件の必要性を実証 |
| R2 | `ta-52` の破壊 | TC-03 を真の衝突構成へ作り替え、ミラー非衝突 TC を追加 |
| R3 | gitignore 除外の `git` 依存 | 不在時は除外なしへ縮退（安全側） |
| R4 | CI patch が HO に触れる | **適用しない**。`git apply --check` のみ実施 |
| R5 | `claude plugin validate` が CI ランナーに存在しない | patch 側で **存在検査を明示**し、**無ければ job を失敗させる**（silently skip しない = #1109 の教訓） |

## 走査 root の射程（コーディネータ指摘 2 への回答 / 2026-08-18 追記）

### 事実

**2 本の検査で走査範囲が食い違っている**:

| 検査 | 走査範囲 | 配布物を見ているか |
|------|---------|------------------|
| `check-skill-name-collisions.py` | `.claude/{skills,commands,agents}` **+ `plugin/*/{skills,commands,agents}`** | **見ている**（46 件のミラー検出がその証拠） |
| `check-stale-skill-refs.py` | **`.claude/**` のみ** | **見ていない** |

この非対称のため、本 PR 自身が持ち込んだ `.codex/skills` の追従漏れが
**stale-refs では緑のまま通った**。「検査は動いているが実際に配布される
成果物を見ていない」という #1109 と同型の構造であり、指摘は妥当である。

### 判断: **(b) 本 PBI では拡張せず、射程を明文化して follow-up 起票**

拡張しなかった理由は**実測に基づく**。各 root へ試行走査した結果:

| root | 検出数 | 内訳 |
|------|-------|------|
| `.agents/skills` | 6 | 大半が**真の stale**（`../../rules/hybrid-architecture.md` は `.agents/rules/` が存在せず解決不能 / `scripts/arbiter.py` の実体は `scripts/ai-loop/arbiter.py`） |
| `plugin/plangate/skills` | 24 | うち **16 件は新規の false-positive クラス** |
| `.codex/skills` | 6 | — |

**16 件の新規 FP クラス**は `scripts/ai-loop/arbiter.py:909-965` のような
**行範囲サフィックス付きパス**である。`_strip_anchor_and_query` は `#` と `?`
しか剥がさないため、**実在するファイルを stale と誤判定**する。

したがって root を広げるには以下が同時に必要になる:

1. **行範囲サフィックスの FP ガード新設**（検査側の変更）
2. **検出された真の stale の是正**（ai-loop レーンの skill 群 = 別領域の欠陥）
3. **`.codex/skills` の扱いの確定** — #1086 で untrack 予定のため、
   既定 root への組み込みはその裁定後が適切

これは「**検知器を直す**」本 PBI と「**検知器が見つけたものを直す**」別作業の
混在であり、1 PR に入れるとレビュー不能になる。
また rc=1 のまま CI に配線すれば、#1087 が防ごうとしている
「赤いまま放置される検査」そのものを再生産する。

### 本 PBI が「検査しない範囲」（明示）

- `.agents/skills/**` / `.codex/skills/**` / `plugin/plangate/skills/**` の
  **stale パス参照**
- 上記 root 配下でのみ発生する参照崩れ
  （例: `.claude/skills` から `.agents/skills` へコピーした際、
  `../../rules/...` の相対リンクが `.agents/rules/` を指して壊れるクラス）

明文化先: `scripts/check-stale-skill-refs.py` の `DEFAULT_TARGET_GLOBS` 直上コメント /
[`docs/ai/stale-ref-detection.md`](../../ai/stale-ref-detection.md)。

### follow-up issue（起票内容）

> **タイトル**: `check-stale-skill-refs.py` の走査 root を配布 root へ拡張する
>
> **背景**: 現在の走査 root は `.claude/**` のみで、実際に配布される
> `.agents/skills` / `plugin/plangate/skills`（および `.codex/skills`）を見ていない。
> 一方 `check-skill-name-collisions.py` は `plugin/*` を見ており、
> 2 本の検査で射程が食い違っている。#1087 ではこの非対称により、
> PR 自身が持ち込んだ `.codex` の追従漏れが検査で緑のまま通った。
>
> **やること**:
> 1. 行範囲サフィックス（`path.py:909-965`）を剥がす FP ガードを追加し、
>    変異注入で検出力が落ちていないことを実証する
> 2. `.agents/skills` の真の stale を是正する
>    （`../../rules/*` の解決不能リンク / `scripts/arbiter.py` → `scripts/ai-loop/arbiter.py`）
> 3. `DEFAULT_TARGET_GLOBS` に `.agents/skills/**` と `plugin/plangate/skills/**` を追加
> 4. `.codex/skills` は **#1086 の untrack 裁定後**に判断する
> 5. CI 配線 patch（#1087 同梱）の対象コマンドを更新する
>
> **完了条件**: 拡張後の既定経路で rc=0 / 真の stale 注入で rc=1 /
> 行範囲サフィックスが FP にならないことの TC
>
> **関連**: #1087（本件の射程を明文化）/ #1086（`.codex/skills` untrack）/ #1109（false green の先例）

## 4 root 追従漏れの検出可否（コーディネータ指摘 4 への回答）

### 結論: **内容一致による一般的な検出は不可能**。代わりに固定リテラルの回帰ガードを置いた

4 root の内容一致を不変条件にできるかを実測した（2026-08-18）:

| 比較 | 共通 skill 数 | 一致 | **正当に相違** |
|------|-------------|------|--------------|
| `.agents` vs `plugin/plangate` | 39 | **39** | 0 |
| `.agents` vs `.codex` | 39 | 13 | **26** |
| `.agents` vs `.claude` | 24 | 16 | **8** |

- `.agents` == `plugin` のみが全数一致であり、これは
  `sync-plugin-plangate.sh` が生成し `drift-check` job が担保している**既存の不変条件**
- **`.codex` は `.agents` の byte copy ではない**（39 中 26 が相違）。
  `codex-multi-agent` がたまたま一致する 13 件の側だった
- したがって「4 root が一致すべき」という assert は **26 件の正当な相違で即座に落ちる**
- root ごとの skill 数（39 / 29 / 39 / 39）も運用で増減するため
  **件数 assert は時限爆弾**（`.claude/rules/` の教訓と一致）

### 置いたもの: `ta-69` の **TC-R1**

「移行済みの具体例パス（固定リテラル）が**どの root にも残っていない**」という
**ゼロ集合の assert**。増減する母集団に依存せず、#1138 型の「是正の再導入」を捕捉する。

**実測で kill を確認**: `.codex/skills/codex-multi-agent/SKILL.md` を
`origin/main` の内容へ戻すと

```
[FAIL] TC-R1: legacy example path still present in: .codex/skills/codex-multi-agent/SKILL.md
TA-69 standalone: 18 passed, 1 failed
```

**本 PR が実際に持ち込んだ退行を、TC-R1 が捕捉することを実証した。**

存在しない root はスキップするため、#1086 で `.codex/skills` が untrack されても
TC は壊れない。

## Questions / Unknowns

- なし（全件実測済み）

## Mode 判定

**モード**: `high-risk`

**判定根拠**:

| 軸 | 実測 | モード |
|----|------|-------|
| 変更ファイル数 | 9（scripts 2 / skills 2 / tests 2 / docs 2 / patch 1。Plan Package を除く） | 高 |
| 受入基準数 | 12 | 高 |
| 変更種別 | 検知器のロジック変更（`code`） | 高 |
| リスク | **検査を弱める方向**。誤ると違反を恒久的に見逃す | 高 |
| 影響範囲 | 2 スクリプト + doctor 統合 + CI 配線設計に波及 | 高 |
| ロールバック | 計画的に必要（scripts 単位で revert 可能） | 高 |

- Hardening Override 対象パス: **含まない**
  （`.github/workflows/*` は **patch 提示のみで未適用**。`.claude/skills/` と
  `scripts/*.py`（`scripts/hooks/` を除く）は `mode-classification.md` の注記により HO 対象外）
- **最終判定**: `high-risk`
  → `lite_eligible=false` / C-2 必須 / **C-3 は人間**（autonomous APPROVE 不可）
  → 本タスクでは **`c3.json` を発行しない**
