# PBI INPUT PACKAGE — TASK-1101

> Issue: [#1101](https://github.com/s977043/PlanGate/issues/1101)
> 作成: 2026-08-15 / 起点セッション: bugfix ウェーブ（#1092 Phase 6 完了後）

## Context / Why

**Hardening Override（HO）が `bin/../bin/plangate` のような正規化されないパスで迂回できる。** `bin/plangate` は HO 9 カテゴリの 1 つであり、**CLI 本体を AI が編集できてしまう**。

#1089（HO が `PLANGATE_HOOK_TASK` 設定時に発火しない）は PR #1097 で是正されたが、**正規化の穴は隣接する別の欠陥として残存**している。

### 実測（2026-08-15 / `origin/main` = `dfaeebb`）

`scripts/hooks/check-plan-hash.sh` の `_norm_target`（HO 判定の入力）が行う正規化は **2 つだけ**:

```sh
_norm_target="${target_file:-}"
case "$_norm_target" in
  ./*) _norm_target="${_norm_target#./}" ;;          # (1) 先頭 ./ の除去
esac
case "$_norm_target" in
  "$REPO_ROOT"/*) _norm_target="${_norm_target#$REPO_ROOT/}" ;;  # (2) repo root の除去
esac
```

一方、**同じファイル内の `plan.md` 判定**は、より強い正規化を行っている:

```sh
_tf_lc=$(printf '%s' "$target_file" | sed 's/[[:space:]]*$//' | tr 'A-Z' 'a-z')
```

**同一 hook 内で、承認境界を守る HO 判定のほうが、plan.md 判定より正規化が弱い。** これが本 PBI の中核。

### 迂回が成立するケース（C-2 で実測・**`ta-65` TC-07 の 4 件は部分集合だった**）

`ta-65` TC-07 は 4 ケースを KNOWN-GAP として固定しているが、C-2 の実測で**変換クラスは 7 種**あり、**FS に実到達する迂回**が多数あることが判明した（R-004）。**FS 到達性は APFS で `cat` により実測**。

| 変換クラス | 例 | rc | FS 到達 | TC-07 収録 |
|---|---|---|---|---|
| `..` 往復 | `docs/../CLAUDE.md` / `bin/../bin/plangate` | 0 | **到達** | あり |
| 大小文字 | `CLAUDE.MD` / `Bin/plangate` / `scripts/hooks/x.SH` / `.claude/Settings.json` / `.github/workflows/x.YML` / `schemas/x.SCHEMA.json` | 0 | **到達** | 一部のみ |
| 連続スラッシュ | `bin//plangate` / `.//CLAUDE.md` / `.claude//rules/x.md` | 0 | **到達** | **なし** |
| `/./` セグメント | `bin/./plangate` / `.claude/./rules/x.md` | 0 | **到達** | **なし** |
| repo root 跨ぎ | `$REPO_ROOT//CLAUDE.md` / `$REPO_ROOT/./CLAUDE.md` / `$REPO_ROOT/docs/../CLAUDE.md` | 0 | **到達** | **なし** |
| 末尾空白 | `"CLAUDE.md "` | 0 | **到達しない** | あり |
| 到達不能（対応不要） | `/CLAUDE.md` / `CLAUDE.md/` / `" CLAUDE.md"` / `bin\plangate` | 0 | 到達しない | — |

**重要な訂正（R-010）**: 末尾空白は **実ファイルに到達しない**（`cat "CLAUDE.md "` → `No such file`）。実到達するのは**大小文字**のほう。末尾空白を塞ぐのは「実害の遮断」ではなく **ガードの一貫性**のため。

**重要な発見（R-004）**: 大小文字による迂回は `AGENTS.md` / `CLAUDE.md` に限らず **HO 9 カテゴリすべてで成立**する。

一方 `scripts/hooks/../hooks/check-plan-hash.sh` は **rc=2** だが、これは**設計ではなく偶然**（`scripts/hooks/*.sh` の glob が先頭一致する形だったため）。**穴はパターン形状に依存**しており、体系的に塞がれていない。

実測記録: [`evidence/c2-review/ho-bypass-surface.md`](./evidence/c2-review/ho-bypass-surface.md) / [`review-external.md`](./review-external.md) R-004

### なぜ今やるか

`ta-65` TC-07 は「**将来これらを塞いだ時点で本 TC が RED になり、更新が強制される**」設計で**意図的に固定**されているが、**追跡先の issue が無いまま**「別 PBI 候補」とだけ記されていた（PR #1100 で文書化、#1101 で起票）。追跡が切れると「消えた項目」になる。

### 深刻度

| 観点 | 評価 |
|---|---|
| 攻撃面 | HO **9 カテゴリすべて**（`bin/plangate` / `.claude/settings*.json` / `scripts/hooks/*.sh` / `.claude/rules/*.md` 等） |
| 前提 | AI が `..` を含むパスを Edit / Write の `file_path` に指定するだけ。**特別な権限は不要** |
| 現実性 | 通常作業で `..` を使うことは稀だが、**意図的に使えば確実に通る**。EH-3 は HO を守る**唯一のガード**（`check-forbidden-files.sh` は HO を見ない） |
| 実害の観測 | **なし**（本 repo で `..` 経由の HO 編集は確認されていない） |

「**AI は自分の実行許可を発行できない**」という承認境界の前提に関わるため、実害未観測でも塞ぐ。

## What（Scope）

### In scope

1. `scripts/hooks/check-plan-hash.sh` の HO 判定を強化し、**変換クラス 7 種すべてで HO が発火**するようにする（**M-5 で 3 クラス → 7 クラスへ是正**。AC-1 と一致させる）
   - `..` セグメントの解決
   - 大小文字の吸収
   - 末尾空白の除去
   - **連続スラッシュ（`//`）の畳み込み**
   - **`/./` セグメントの除去**
   - **先頭 `./` の除去（反復）**
   - **repo root 跨ぎ**（`$REPO_ROOT/./…` / `$REPO_ROOT//…` / `$REPO_ROOT/…/../…`）
   - および上記の **2 種複合**（`./bin/../bin/plangate` / `.//BIN/plangate` 等）
2. HO の `case` パターンを、強化後の正規化形式と**整合させる**（大小文字を吸収するなら `AGENTS.md|CLAUDE.md` は小文字側で受ける必要がある）
3. `ta-65` TC-07 を **fixed 期待へ反転**（現在は「通過すること」を固定している）
4. `docs/ai/hook-enforcement.md` の「既知の残存」記述を更新（PR #1100 で追加した箇所）

### Out of scope

- `check-forbidden-files.sh` への HO 判定の追加（**HO の二重化**は別論点）
- HO 9 カテゴリの**定義変更**（対象パスは増減させない）
- `PLANGATE_SKIP_TOKEN_GUARD` / `PLANGATE_BYPASS_HOOK` の扱い（明示 bypass は設計どおり）
- `plan.md` 判定側の正規化（既に実装済み・本 PBI では触らない）
- `..` を含むパスを Edit/Write が受理すること自体の是非（ツール層の話）

## 受入基準

> **C-2 反映版（v2）**。R-001〜R-013 / S-1〜S-4 を織り込み、**「実装したこと」ではなく「穴が塞がったこと」を測る**形へ書き換えた。旧 AC-2 は AC-5 に統合（R-013）。

| ID | 内容 |
|----|------|
| **AC-1** | **HO 9 カテゴリ（15 パターン）× 変換クラス 7 種**（`./` 前置 / `//` / `/./` / `..` 往復 / repo root 跨ぎ / 大小文字 / 末尾空白）**およびその 2 種複合**の直積を HO 判定に投入し、**全件 rc=2**。既知 4 ケースの狙い撃ちでは PASS しない構成にする（R-004 / R-011） |
| **AC-2** | **`_norm_target` の値が既存 consumer に対して不変**であること。回帰表明 3 本: (1) maintenance `allowed_paths` の `fnmatchcase` 一致 (2) `docs/working/TASK-*/approvals/c3.json` の conversation 経路 (3) doc-light の拡張子判定（R-001） |
| **AC-3** | **偽陽性の防止**: 既存 TC-06 の 10 件 **+ 変換を施した非 HO ケース**（`docs/x/../AGENTS.md` / `scripts/hooks/../hooks/x.py` / `bin/../bin/other` / `docs/working/TASK-T65/../TASK-T65/CLAUDE.md.bak`）が両文脈で block されない（R-006） |
| **AC-4** | **可搬性**: **正規化関数を `sh` / `dash` / `bash` / `zsh` で直接評価**した入出力が全シェルで一致する。**`ta-65` 経由での確認は不可**（hook を常に `sh` で起動するため false green / R-002・R-003） |
| **AC-5** | **検出力**: 正規化ステップを 1 つずつ外す変異を**関数内**に注入し（call site ではない）、対応する TC が **FAIL** する。変異は変換クラス 7 種に対応させる。**patch 未適用の hook に対して新 TC が FAIL する**ことも含む（旧 AC-2 を統合 / R-013）。**加えて第 8 変異「`_norm_target` 自体に `_ho_key` の正規化（特に小文字化）を適用する」＝ v1 設計を注入し、TC-02/03/04 と `ta-45` が FAIL すること**（M-4。これが無いと AC-2 の回帰網は空振りのまま） |
| **AC-6** | `sh tests/run-tests.sh` が **rc=0**。**HO / `_norm_target` 下流を検査する既存 4 本**（`ta-65` / `ta-12` TC-24・TC-33 / `ta-39` TC-03・TC-06 / `ta-45`）が PASS（S-4）。baseline は着手時に現 main で再測定し、**絶対件数を契約値にしない** |
| **AC-7** | `docs/ai/hook-enforcement.md` の「既知の残存」が更新され、**残存項目ゼロ、または残存に対する追跡 issue 番号が本文に存在する**（#1101 自身が「追跡先の issue が無いまま残った」ことを理由に起票されている以上、同じ穴を再生産しない）。**かつ (a) 記述が `Edit\|Write` 経路に限定されることを明示し、(b) `Bash` 経路は #1104 を追跡先として本文に残す**（M-8。これが無いと「HO は常時 block」へ戻り、Bash 経路の穴が文書上消える）。**あわせて旧記述が変換クラスを「`..` / 大小文字 / 末尾空白」の 3 種しか挙げていなかった点を、実測した 7 種へ訂正する**（S-3 / **m-7 で表現を是正** — 旧記述は「ta-65 TC-07 が 4 ケースを KNOWN-GAP として固定している」と **TC の内容**を述べており、**迂回総数を 4 件と主張してはいない**。訂正対象は「総数」ではなく「**列挙した変換クラスの不足**」） |
| **AC-8** | **fail-closed（2 条件）**: 畳み込み後に **(a) 先頭 `..` が残る** / **(b) セグメント数が上限（256）を超える** 場合は **block（rc=2）** へ倒す（R-005 / R-007）。**「絶対パスが残る」は条件に含めない**（N-1/N-2 で確定 — 下記） |
| **AC-9** | **監査ログが生の要求パスを保持**する。HO block 時の **`reason` と `_audit/hook-events.log`** に、正規化後ではなく **Edit/Write が要求した原文**が残る（S-1。攻撃を塞ぐ変更が攻撃検知の情報を消さない）。**対象から `skip-decision-log.jsonl` を除外する**（M-4' / M-1 — 実測: HO block 経路は `log_event` → `hook-events.log` のみを呼び、`skip-decision-log.jsonl` は **SKIP 3 経路でしか書かれない**。要求すると **TC が永久 RED か、HO 保護ファイルへ新規ログ出力を足す（= Human 適用範囲の拡大）かの二択**になる。新規ログ出力は本 PBI の scope 外） |
| **AC-10** | **適用の安全性**: apply スクリプトが `--revert` を実装し、`--apply` 直後に **smoke check**（HO 1 件が rc=2 / 非 HO 1 件が rc≠2 / 実行時間が閾値内）を自動実行して**失敗時は自動 revert** する（R-007） |
| **AC-11** | **性能**: 正規化の追加による **fork 数の増加がゼロ**（純シェル実装）。`sed` / `tr` を新規に足さない（R-012。実測: `sed` 1 回で ≒8ms/回 vs 純シェル ≒1〜2ms/回、hook 全体は 0.048s） |

## Notes from Refinement

### 実装方針の候補と評価

| 方式 | 評価 |
|---|---|
| `realpath` / `readlink -f` | **不採用**。ただし**理由を訂正**（R-009）— macOS にも `/bin/realpath` は**存在し** `readlink -f` も動く。真の不採用理由は **(1) BSD 実装は存在しないパスで rc=1（GNU の `realpath -m` 相当が無い）→ Write の新規ファイル作成時に正規化できず fail-open する (2) シンボリックリンクを解決してしまい意味論が変わる** |
| **純シェルの字句的畳み込み（パラメータ展開）** | **採用**。外部コマンド非依存（**fork 増加ゼロ** / AC-11）・シンボリックリンクを解決しない。ガードとしては「畳み込んで HO に当たれば block」＝**安全側** |
| `IFS=/` + 未クォート `$var` の for ループ | ❌ **採用不可（R-002）**。**zsh では単語分割が起きず正規化が丸ごと no-op になる**（実測: `docs/../CLAUDE.md` が無変換）。`${v%/*}` / `${v#*/}` のパラメータ展開ループを使う |
| `case` パターンを小文字で書き直す + target を小文字化 | 必要。ただし **`_norm_target` には適用しない**（R-001）— HO 判定専用の派生変数に対してのみ行う |

### 注意点

- **⚠️ 最重要（R-001）**: `_norm_target` は **HO 判定専用ではない**。L152 の `docs/working/TASK-*/approvals/c3.json`（大文字 `TASK-`）、L207-225 の `fnmatch.fnmatchcase`（**明示的に大小文字を区別**）、L193 の doc-light 拡張子判定、L177/198/200/273 の監査ログが同じ値を消費する。**破壊的に書き換えると maintenance 窓が全滅し、C-3 conversation mode が silent に死ぬ**
- **⚠️ zsh（R-002）**: 単語分割に依存する実装は zsh で no-op になる。しかも **`ta-65` は hook を常に `sh` で起動する**ため、この欠陥は `ta-65` 経由では**検出不可能**。AC-4 は関数の直接評価で測る
- **大小文字の吸収は「block する側へ倒す」のが安全側**。macOS では `CLAUDE.MD` が実ファイルに到達する（実測確認済み）が Linux では別ファイル。Linux で別ファイルを block するのは**軽微な偽陽性**であり、迂回を許すより望ましい
- **末尾空白は実ファイルに到達しない**（R-010）。塞ぐのは実害遮断ではなく**ガードの一貫性**のため
- TC-06 の `docs/AGENTS.md` は小文字化しても `agents.md` に一致しない（前置パスがあるため）。**C-2 で mutation を当てて 10 件全件 rc=0 / HO=no を実測済み**（偽陽性なし）。ただし TC-06 は**正規化しても値が変わらないパスばかり**で測定装置として不十分なため、AC-3 で拡充する
- **HO の `case` ラベルは 9 行だがパターンは 15 個**（`|` 分割後 / R-011）。全数確認では両方を数える

### ⚠️ 正規化の適用順序（RiverReview の critical を受けて確定 / v4）

**RiverReview が、C-1 → C-2 3 レーン → 簡易 C-1 の 4 回を通過した critical を検出した。**

v3 の順序 `(1)末尾空白 → (2)先頭 ./ 除去 → (3)畳み込み → (4)repo root 除去` では、**`.//CLAUDE.md` が skip される**:

```
.//CLAUDE.md
  → (2) は ${v#./} で先頭 2 文字だけを剥がす  →  /CLAUDE.md
  → (3) は // が無いので何もしない
  → (4) は repo root に一致しない
  → どの HO パターンにも当たらず skip = 穴が開いたまま
```

**`.//CLAUDE.md` は実ファイルに到達する**（実測: `ls -la .//CLAUDE.md` → 6,572 bytes の実体）。つまり **本 PBI が塞ごうとしている対象そのものが、v3 どおり実装すると開いたまま**だった。

**これは v3 が作り込んだ退行**でもある。v2 にあった「(5) 先頭 `/` 除去」がこのケースを偶然塞いでいたが、絶対パス偽陽性（N-1）への対応で削除した結果、`.//CLAUDE.md` が開いた。**「指摘に対応した結果、別の穴が開く」**クラス。

**確定（v4）: 畳み込みを最初に置く。**

```
(1) 末尾空白の除去
(2) // の畳み込み / . セグメントの除去 / .. の字句的畳み込み   ← 最初に
(3) 先頭 ./ の除去（反復・(2) の残余対策）
(4) repo root の除去
(5) 小文字化                                                  ← _ho_key のみ
```

実測で両立を確認済み:

```
.//CLAUDE.md          → CLAUDE.md              block ✅
bin//plangate         → bin/plangate           block ✅
bin/./plangate        → bin/plangate           block ✅
bin/../bin/plangate   → bin/plangate           block ✅
/private/tmp/x/note.md → /private/tmp/x/note.md  先頭 / を保持 = skip ✅
```

### 絶対パスの扱い（簡易 C-1 の N-1 / N-2 を受けて確定）

簡易 C-1 で、v2 の 3 箇所が矛盾していることが判明した:

| 箇所 | 記述 |
|---|---|
| plan §Non-goals | `/CLAUDE.md` は **対象外**（FS 到達しない） |
| test-cases §エッジケース | `/CLAUDE.md` → **skip** |
| plan §正規化の順序 (5) + AC-8 | 先頭 `/` を除去 → `CLAUDE.md` に一致して **block**。かつ AC-8 が「絶対パスが残ったら block」 |

**実測で決着した**（オーガナイザーが現 main で確認）:

```
/private/tmp/claude-502/.../scratch/note.md   rc=0   ← scratchpad への書き込み
/tmp/foo.txt                                   rc=0
/Users/.../other-repo/CLAUDE.md                rc=0   ← 別リポジトリ
/CLAUDE.md                                     rc=0
```

**「畳み込み後に絶対パスが残ったら block」を採ると、repo 外への書き込みが全部止まる**（scratchpad を含む）。これは受け入れられない偽陽性。

**確定**:

1. **正規化順序から (5) 先頭 `/` の除去を削除する**
2. **AC-8 から「絶対パスが残る」を削除する**（残る条件は 先頭 `..` / セグメント上限 の 2 つ）
3. `/CLAUDE.md` の期待値は **skip** に統一（Non-goals・エッジケース表と一致）

**(5) は冗長でもあった**。R-005 の repo root 跨ぎは **(3) 畳み込みを (4) repo root 除去より前に置いた時点で既に塞がっている**:

```
$REPO_ROOT//CLAUDE.md   → (3) //畳み込み → $REPO_ROOT/CLAUDE.md → (4) → CLAUDE.md → block ✅
$REPO_ROOT/./CLAUDE.md  → (3) . 除去     → $REPO_ROOT/CLAUDE.md → (4) → CLAUDE.md → block ✅
//CLAUDE.md             → (3)            → /CLAUDE.md → (4) 不一致 → skip（FS root は repo に到達しない）✅
```

> **AC-8 の「絶対パスが残る」は到達不能な条件でもあった**（N-2）。(5) がある限り (5) 通過後に絶対パスは残らないため、TC-11 の該当行は**空振り fixture** になっていた。削除により AC-8 の 2 条件はいずれも具体的な入力値で検査できる。

### 責務

- **`scripts/hooks/check-plan-hash.sh` は Hardening Override 対象パス**
- **AI は patch 提示まで・適用は Human**（#1089 / PR #1091 で確立した apply スクリプト方式を踏襲）
- `tests/extras/ta-65-*.sh` は HO 対象外のため **AI が直接編集可能**

## Estimation Evidence

### Risks

| リスク | 影響 | 緩和 |
|---|---|---|
| 正規化強化による**偽陽性**（触ってよいパスを塞ぐ） | 開発が止まる | AC-3（TC-06 の 10 件）+ 追加ケースで表明 |
| シェル差で `..` 畳み込みの挙動が割れる | 環境により穴が残る | AC-4 で 4 シェル実測 |
| `..` 畳み込みの実装ミスで**無限ループ / パス破壊** | hook 自体が壊れる（全編集が止まる） | 単体で切り出してテスト。**EH-3 は全 Edit/Write の前段**なので影響が大きい |
| 変更が HO 対象パス自身 | AI が適用できない | patch + apply スクリプト方式（#1091 前例） |

### Unknowns

- `..` 畳み込みを純 sh で書いたときの**性能**（EH-3 は全 Edit/Write で走るため、ループ実装のコストを実測する）
- `tr 'A-Z' 'a-z'` が**マルチバイト環境（ja_JP.UTF-8）**で想定どおり動くか（日本語ファイル名がある場合の挙動）

### Assumptions

- HO 9 カテゴリの**定義は変えない**（対象パスの増減は別 PBI）
- `ta-65` は **HO 対象外**なので AI が直接編集できる
- Mode は **`high-risk`（ユーザー override / C-3 で承認を要する事項）**。承認境界そのものの判定ロジック変更のため `mode-classification.md` の例外ルールにより **`lite_eligible=false` 強制・Standard 同期 C-3** は確定。

  **⚠️ 定量基準では `critical` 帯（M-3）**: 正本の定量表は **受入基準数 `11+` = 超高**、判定ロジックは「各軸の最大値を採用」。AC を 7 → **11** に増やした結果、帯を跨いでいる。

  | 軸 | 値 | 帯 |
  |---|---|---|
  | 変更ファイル数 | 6 | high-risk |
  | **受入基準数** | **11** | **critical** |
  | 変更種別（承認境界） | — | high-risk（例外ルール） |

  **override の根拠**: AC が 11 件あるのは「**穴が塞がったこと**を測るために検証条件を分解した結果」であり、**変更の危険度が critical 相当に上がったわけではない**。実体は「HO 判定ロジックの局所変更 + テスト」で、`critical` が要求する **V-2 / V-4**（横断リファクタ・リリース前チェック）を要する規模ではない。正本の「**ユーザーがオーバーライドした場合はそちらを優先**」に該当。

  **2026-08-15 ユーザー承認済み**（選択肢 A=critical へ引上げ / **B=override して high-risk 維持** / C=AC 統合で 10 件以下 のうち **B** を選択）。**C-3 でこの override ごと承認を得ること。**

## 関連

- **#1089**（HO が TASK 文脈で発火しなかった問題。PR #1097 で是正済み。**本 PBI はその隣接する別の穴**）
- **#1092**（bugfix 優先計画）
- `tests/extras/ta-65-eh3-ho-task-context.sh` TC-06 / TC-07
- `docs/ai/hook-enforcement.md`（PR #1100 で本穴を「既知の残存」として明記）
- `.claude/rules/mode-classification.md`（HO 対象パス = 9 カテゴリの正本。**行番号ではなく記号アンカーで参照すること** / #1089）
