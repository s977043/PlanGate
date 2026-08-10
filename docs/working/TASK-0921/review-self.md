# C-1 SELF REVIEW — TASK-0921

Review date: 2026-08-05（初版） / 2026-08-06（第 5 ラウンド PASS まで反映）

## Verdict

`PASS`

**critical 0 / major 0**（第 5 ラウンド実測）。`.claude/rules/working-context.md` の C-1 判定語彙は
**PASS / WARN / FAIL の三値**であり、PASS の定義は critical 0 かつ major 0 である。
第 4 ラウンド時点の中間語彙 `CONDITIONAL_PASS_PENDING_C1_R5` は「第 5 ラウンドの結果待ち」を
表すためだけの暫定表現だったため、結果が出た本版で三値へ収束させた。
**PASS は minor の残存と両立する**（第 5 ラウンドの minor 2 / info 3 は本版で全件解消済み。
`## Minor Findings` 参照）。

C-1 は第 5 ラウンド（2026-08-06 / 検証のみ）で PASS に到達した。以降の計画変更は
C-3 承認前に限り、**承認後の plan 編集は `plan_hash` を無効化するため禁止**する。

初版（2026-08-05）の Verdict は `NEEDS_REVISION_BEFORE_C3` であり、その根拠は
「runtime inventory」「**top-level trap 競合監査**」「**独立 C-2**」の 3 点だった。
このうち **2 点はすでに解消済み**である:

- **trap 競合監査は不要になった**。Human 決定 1 により **案 D（末尾 explicit finalize）を採用**し、
  helper は trap を張らない（`plan.md` の `案 D（末尾 explicit finalize）を採用する` および
  `注（案 D 採用により削除）`）。**案 C は不採用**であり、以降の記述は案 D を前提とする
- **独立 C-2 は実施済み**。[`review-external.md`](./review-external.md) に 2 レーン
  （設計妥当性 / コードベース整合）の結果を `R-001`〜`R-020` として集約済み
  （critical 0 / major 11 / minor 6 / info 3）。監査表の disposition は
  **reflected 18 / resolved-by-design 2 = 全 20 件処理済み**

残る未了は **runtime inventory の exec 開始時取得**（`plan.md` の `## C-1 Self Review Checklist`
で未チェック）のみであり、これは **exec の Task 1 で確定する設計上の未了**であって
C-1 の指摘ではない。

## C-1 ラウンド履歴

> 各ラウンドの指摘内容と是正の詳細は `plan.md` の `## C-1 Self Review Checklist` を正本とする。
> 本表は「いつ・何件・どうなったか」の要約のみを持つ。

| ラウンド | 判定 | 指摘 | 状態 |
|---|---|---|---|
| R1（簡易 C-1 再実行） | FAIL | major 3 / minor 6 | 是正済（MJ-A 層 0 の Slice 2 繰り延べ / MJ-B rc=3 反転の未伝播 / MJ-C Slice 1 単独 PR の DoD 未定義 ほか） |
| R2（第 2 ラウンド） | FAIL | major 2 / minor 7 | 是正済（MJ-E allowlist 述語が AC-5 後半条項に違反 → 明示台帳へ / MJ-D scope 節の未伝播 ほか） |
| R3（第 3 ラウンド） | FAIL | major 3 / minor 5 | 是正済（MJ-F / MJ-G 台帳の実行時依存と異常系 → contract TA 本体へ内蔵 / MJ-H TC-17 sandbox 手順の未定義 ほか） |
| R4（第 4 ラウンド） | FAIL | major 2 / minor 3 / info 2 | 是正済（`9f8af02`。MJ-I TC-25 の非空 assert が恒真 / MJ-J 本ファイルの stale / MN-G sandbox の `git archive` / MN-H M-14 (c) が再現不能 / MN-I 字面一致が不成立 / INFO-1 TC-11 を Slice 1 へ / INFO-2 decision-log の未 append） |
| R5（第 5 ラウンド） | **PASS** | critical 0 / major 0 / **minor 2 + info 3** | **収束（新規クラスなし）**。R1〜R4 で摘出された欠陥クラスの再発 0・新規クラス 0。minor / info は本コミットで全件解消（MN-K TC-25 assert ③ の計数点 / MN-L チェックボックス不一致 / info-1 sandbox の cwd 前提 / info-2 M-14 (c) の発火 assert 記録 / info-3 字面一致の対象項の明示） |

## Review Matrix

| View | Verdict | Note |
|---|---|---|
| Issue / pbi alignment | PASS | 層 A/B、rc 1/2、harness 不変を反映 |
| Dependency | PASS | #914 closed を確認 |
| Testability | PASS | **TC-01〜25 / M-01〜14**（Slice 1 / Slice 2 の割当は test-cases の Mutation Matrix と Exit Criteria が正本） |
| Early exit coverage | PASS | **案 D 採用により trap を張らない**ため競合監査は不要。早期 `exit 0` の実測 3 件（`ta-39` / `ta-43` / `ta-44`）は Task 5 で `pg_extra_contract_skip`（rc=3）へ置換し、末尾 explicit finalize の漏れは contract TA（TC-05 / TC-16 / M-07）が検出する |
| Source safety | PASS | harness では trap / counter reset / exit を行わない（TC-21 で `set -eu` source-safe と `register_cleanup` 非再定義を検査） |
| Dynamic all-file evidence | PASS | capability marker + target 指定 force-fail probe（TC-12 の (a)(b) 差分） |
| Count drift | PASS | runtime inventory 正本・hardcode 禁止（TC-20 は allowlist 対象外で全件） |
| Cleanup safety | PASS | 案 D により新規 trap を導入しないため既存 cleanup/trap の全件 inventory は前提でなくなった。top-level `trap ... EXIT` の実測 5 本（`ta-07` / `ta-09` / `ta-24` / `ta-28` / `ta-45`）とは非干渉（R-012） |
| Broad diff reviewability | PASS | Slice 1 = **15 ファイル / high-risk**、Slice 2 = **46**（着手時に Mode 再判定）に分割し、Slice 1 を単独 PR として C-4 / merge する（Exit Criteria が Slice 別に分離済み） |
| C-2 independence | PASS | **実施済**。2 レーン（設計妥当性 R-001〜R-011 / コードベース整合 R-012〜R-020）。critical 0 / major 11 / minor 6 / info 3、disposition は reflected 18 + resolved-by-design 2 |
| Allowlist leak（R4 で追加） | PASS | 新規追加ファイルの黙殺は TC-16 / M-06、移行済みファイルの残存と allowlist 過大化は TC-25 / M-14（**自己を除いた非空**・`pending ⊊ discovered`・実走件数 ≠ 0 の 3 assert）で塞ぐ |

## Major Findings

### C1-M1: 早期終了経路の担保方式（案 C → 案 D で決着済み）

初版の指摘は「共有 exit trap（案 C）は早期 exit を覆う一方、既存 extras の top-level trap と
競合しうるので、全件 inventory で競合 0 を実証するまで案 C を確定しない」だった。
**この指摘は案 C を採らないことで解消した**。Human 決定 1 により **案 D（末尾 explicit
finalize）を採用**し、helper は trap を張らないため既存の top-level trap（実測 5 本）と
構造的に競合しない。案 D の弱点（早期 return/exit の漏れを静的に完全検出できない）は
**contract TA の実走検査**（TC-05 / TC-12 の probe 差分 / TC-16 / M-07）で補償する。

### C1-M2: Helper loading modifies runner boundary

`tests/run-tests.sh` の集計ロジックは変えないが、helper source 追加は全 extras の実行前提になる。
helper 不在・syntax error・unexpected global mutation を RED test し、runner の変更行を
source 1 箇所に限定する。

### C1-M3: Probe environment is a new test interface

force-fail probe は全 file 動的検査に有効だが、通常運用で誤設定された場合に test が赤になる。
fail-safe であり security bypass ではない。C-2 での裁定を経て、**internal-only / target 必須 /
finalize 後の unset（TC-23）**を契約として明文化済み。

## Minor Findings

### 第 5 ラウンド（minor 2 / info 3）— **すべて本コミットで解消済み**

| ID | 種別 | 内容 | 状態 |
|---|---|---|---|
| MN-K | minor | TC-25 の assert ③ が計数点を「ループ**進入**時」に置いており、自らが反例として挙げる「ループ本体の先頭でフィルタして全件 `continue` する実装」を捕捉できない（英文の `entered` と plan 和文の「実際に実行した」も意味がずれていた） | **解消済み**。計数点を「フィルタ通過後、段 1 の実行（`sh "$file" </dev/null` の 1 回）を開始した時点」へ移動。**前提未充足（rc=3）に落ちる分は引き続き計数に含める**（TC-17 が正しく扱う正当な状態を確定 FAIL にしないため）。`test-cases.md` TC-25 ③ / `plan.md` Task 6 / `todo.md` T-06 の 3 箇所を同時修正 |
| MN-L | minor | `plan.md` の C-1 Self Review Checklist で C-2 項が本文「完了」に対し `[ ]` のままで、本ファイルの C-3 Readiness（`[x]`）と C-3 が読む 2 ファイル間で表示が食い違っていた | **解消済み**。`[x]` へ是正。あわせてチェックリスト全体を走査（結果は本節末尾） |
| info-1 | info | sandbox step 1 のコード片が cwd = repo ルートを暗黙に前提していた（`git ls-files` はサブディレクトリ実行で当該サブツリーしか返さない） | **解消済み**。`( cd "$(git rev-parse --show-toplevel)" && … )` をサブシェル内に追加し、呼び出し元の cwd を変えない旨と理由を併記 |
| info-2 | info | M-14 (c) は 4 経路で kill されるため、per-line 検査 2 単独の kill を ①②③ の動作証明と誤読しうる | **解消済み**。Mutation Matrix の期待値を「①②③ が**個別に**発火し、その 3 行が log に出力されていること」へ具体化 |
| info-3 | info | 字面一致は plan Task 6 **第 1 項** ↔ todo T-06 **第 1 項**でのみ成立し、第 2 項は plan 側の補足文により一致しない | **解消済み**。`test-cases.md` の合意対象を「第 1 項（移行 scope 定義）」と明示し、第 2 項が対象外である理由を記載 |

**MN-L の走査結果**: `plan.md` の `## C-1 Self Review Checklist` の**全項目**を確認し、
本文と box の不一致は **C-2 項の 1 件のみ**だった。ほかに是正したのは
「簡易 C-1 第 5 ラウンド」項で、これは本ラウンドの完了に伴い `[ ]` → `[x]`（結果を本文に追記）
としたもので、不一致の是正ではなく**状態の前進**である。
`runtime inventory をexec開始時に取得` と `Human C-3` は**実際に未了なので `[ ]` のまま**
残した（虚偽の完了申告をしない）。

### 恒常的な minor（設計上の留意点）

- capability marker と init argument の二重記述は drift しうる。marker から init を導出できない
  shell 構造のため、TC-10 で一致を強制する設計は妥当
- `ta-26` 移行は最も重いため最後にする。**Human 決定 3 により層 0（`ta-26` を含む 4 本）は
  Slice 2 へ繰り延べ**、Slice 1 = 15 ファイル / high-risk を維持する
- final rc precedence は original rc を保持する設計。元 rc と fail の両方を summary へ記録し、
  fail 情報を失わないこと（TC-06）

## Scope Check

- test content redesign: excluded
- runner subprocess redesign: excluded
- framework dependency: excluded
- README inventory cleanup: excluded
- #994 repair: separate issue

## C-3 Readiness

> 凡例: `[x]` = 充足済み、または設計変更により **要件そのものが消滅**した（理由を併記）/
> `[ ]` = **未充足**。虚偽の完了申告を避けるため、未充足のものは未チェックのまま残す。

- [ ] runtime inventory evidence — 静的分類（**4 + 12 + 36 + 5 = 57**）は plan に実測済みだが、
      **exec 開始時の Task 1 で再実測して確定する**手順が未実行（`plan.md` の
      `## C-1 Self Review Checklist` でも未チェック）
- [x] top-level trap / cleanup conflict table — **不要化**。案 D は trap を張らないため
      競合監査そのものが前提でなくなった（R-012 / Human 決定 1）
- [x] current baseline full suite — 実測済み（`sh tests/run-tests.sh` rc=0 / **231s** /
      541 passed, 0 failed）
- [x] C-2 独立レビュー — **2 レーン構成で実施済み**（`review-external.md` R-001〜R-020）。
      初版が列挙していた「POSIX shell / mutation・test architecture / PlanGate source-boundary」の
      3 分割は、`review-principles.md` §7-bis の 2 レーン責務契約（設計妥当性 / コードベース整合）
      へ置き換わっている
- [x] Human choice: shared trap vs explicit finalizer — **決着済み**（Human 決定 1 = 案 D）
- [x] C-1 第 5 ラウンドの完了 — **PASS**（critical 0 / major 0 / minor 2 / info 3）。
      minor / info は本コミットで全件解消。`## C-1 ラウンド履歴` の R5 行を正本とする
- [ ] Human C-3

---

# 確定反映後の簡易 C-1（R6 / 独立レビュアー）

> **上記の記述は一切書き換えていない**（C-1 の履歴保全）。本節は
> `.claude/rules/working-context.md`「C-2 指摘の差分管理」の順序規約
> **(1) R-NNN 集約 →(2) 1 回確定反映 →(3) 簡易 C-1 再実行 →(4) c3.json →(5) exec**
> のうち **(3)** に相当する追記である。

- **レビュー日**: 2026-08-10
- **レビュアー**: 独立 C-1（**本 plan の作成者ではない**。maker / checker 分離）
- **対象 head**: `7c622676ae80f6cf5009328dd9ec0d599f449632`（base `origin/main` = `00210dd`）
- **検証した反映**: `0597b53`（R-021〜R-037 の 1 回確定反映）+ `7c62267`（監査表への反映 SHA 追記）

## Verdict（R6）

**`PASS`** — critical 0 / major 0 / **minor 2** / info 0。

**C-3 に出せる状態である。** 反映ワーカーの申告のうち、C-1 として独立に再測定・
再現できた項目はすべて実物と一致した。残る minor 2 件はいずれも
**exec 開始前に解消可能**であり、承認境界にも AC の充足可否にも影響しない。

> 判定語彙は `.claude/rules/working-context.md` の三値（PASS / WARN / FAIL）に従う。
> PASS の定義は critical 0 かつ major 0 であり、**minor の残存と両立する**。

## サマリー

C-1 チェック項目の正本は [`docs/working/templates/review-self.md`](../templates/review-self.md)。
**自分で数えた項目数 = 25**（テンプレート冒頭のサマリー表 `PASS | {25}` とも一致）。内訳:

| ブロック | 項目 | 数 |
|---|---|---|
| Plan | C1-PLAN-01〜07 + 08-AEE / 09-AEE | 9 |
| Plan 品質追加（Superpowers / #581） | C1-SUP-PLAN-01〜02 | 2 |
| ToDo | C1-TODO-08〜12 + C1-TODO-RB | 6 |
| テストケース | C1-TEST-13〜15 | 3 |
| B-1/B-2 | C1-B1B2-16〜17 | 2 |
| 横断 | C1-SEC-01 / C1-SCOPE-DISC-01 / C1-UI-01 | 3 |
| **合計** | | **25** |

| result | 件数 |
|--------|------|
| PASS | 21 |
| WARN | 2 |
| FAIL | 0 |
| N/A | 2 |

## 独立に再実行した検証（実行コマンドと結果）

**推測で PASS にしていない。** 以下はすべて本 worktree（head `7c62267`）で実際に実行した。

### V-1: 早期脱出イディオムの再測定（R-021 の裏取り）

```console
$ grep -rn 'return 0 2>/dev/null' tests/extras/
tests/extras/ta-47-ehs23-wiring.sh:23:  return 0 2>/dev/null || true
tests/extras/ta-45-c3-mode-config.sh:52:  return 0 2>/dev/null || true
tests/extras/ta-43-eh2-strict-json.sh:56:  return 0 2>/dev/null || exit 0
tests/extras/ta-46-ehs-wiring.sh:23:  return 0 2>/dev/null || true
tests/extras/ta-44-eh457-cli-wiring.sh:49:  return 0 2>/dev/null || exit 0
tests/extras/ta-31-codex-plugin-status.sh:43:  … || { t31_fail "TC-05 mktemp 失敗"; return 0 2>/dev/null || true; }
tests/extras/ta-31-codex-plugin-status.sh:56:  … || { t31_fail "TC-06 mktemp 失敗"; return 0 2>/dev/null || true; }
tests/extras/ta-31-codex-plugin-status.sh:72:  … || { t31_fail "TC-07 mktemp 失敗"; return 0 2>/dev/null || true; }
tests/extras/ta-31-codex-plugin-status.sh:73:  … || { rm -rf "$_t31_bin"; t31_fail "TC-07 mktemp 失敗"; return 0 2>/dev/null || true; }
tests/extras/ta-39-eh3-doc-light.sh:59:    return 0 2>/dev/null || exit 0
tests/extras/ta-49-bias-export.sh:72:  return 0 2>/dev/null || true
（exit code 0 / 全 11 行）
```

**初見では「plan の 7 件は過少（実測 11 件）」に見えたが、これは誤読だった。**
plan.md:123 は **層 A（= Slice 1 の移行対象）に限って 7 件**と書いており、
`ta-31` の 4 箇所は「**分岐内のみ・`mktemp` 失敗時にだけ通る・harness-only 想定＝層 B のため
Slice 1 の対象外**」として**同じ行に明示的に控除**されている。7 + 4 = 11 で実測と一致する。

- 型別内訳も申告どおり: **`|| exit 0` 型 3 件**（`ta-39:59` / `ta-43:56` / `ta-44:49`）/
  **`|| true` 型 4 件**（`ta-45:52` / `ta-46:23` / `ta-47:23` / `ta-49:72`）。
  申告された 4 つの行番号は**すべて実測と一致**した
- 層帰属も裏取り済み: `pbi-input.md:96` の層 A 一覧
  （`ta-39`/`ta-43`/`ta-44`/`ta-45`/`ta-46`/`ta-47`/`ta-49`/`ta-50`〜`ta-53` + `ta-40` = 12 本）に
  **早期脱出 7 本がすべて含まれ**、`ta-31` は**含まれない**。控除は正当
- **「`exit 0` を起点にしない / 列位置で絞り込まない」という grep 規約**（plan.md:123）も
  妥当。列位置で絞ると実際にインデントされた `ta-39:59` を取りこぼす

→ **R-021 の反映は実物と整合している（PASS）**。

### V-2: シェル依存の再現（`-c` 経路ではなくスクリプトファイルを渡して実測）

`.c1probe/t_true.sh`（`return 0 2>/dev/null || true`）と `.c1probe/t_exit.sh`
（`return 0 2>/dev/null || exit 0`）を作成し、各シェルへ**ファイルとして**渡した
（検証後に `rm -rf .c1probe` 済み。commit には含まれない）。

| シェル | `\|\| true` 型 | `\|\| exit 0` 型 |
|---|---|---|
| `/bin/sh`（macOS = **bash 3.2.57**、`BASH_VERSION` で確認） | `BEFORE` + **`AFTER-BODY-RAN`** / rc=0 → **本体が走る** | `BEFORE` のみ / rc=0 → 終了 |
| `/bin/dash` | `BEFORE` のみ / rc=0 → **終了** | `BEFORE` のみ / rc=0 → 終了 |
| `/bin/zsh` | `BEFORE` のみ / rc=0 → **終了** | `BEFORE` のみ / rc=0 → 終了 |

**plan.md:124 および test-cases.md TC-29 の Rationale と完全に一致した。**
さらに `.github/workflows/test.yml:28` が `run: sh tests/run-tests.sh` であることを確認
（`ubuntu-latest` の `/bin/sh` は dash）。したがって

- **CI（dash）では `|| true` 型 4 本が末尾 `pg_extra_contract_finalize` に到達しない**
  ＝ 案 D の中核機構が CI で機能しない
- **bash 開発機では skip guard を素通りして本体が走る**＝ローカル GREEN が CI 正当性を含意しない

の双方が**実証された**。R-021 を critical / blocker とした判断は妥当であり、
**TC-29 / M-15 が dash・bash 双方での kill を要求する設計は必要十分**である。

### V-3: R-032 の `resolved-by-design` 判定の裏取り

```console
$ grep -n 'extras/\*\.sh' tests/run-tests.sh
（0 件 / exit code 1）
$ grep -n 'ta-\*\.sh' tests/run-tests.sh
7:#   - 拡張テスト: tests/extras/ta-*.sh を順次 source（Issue #170 で導入）
155:# ── Extras: tests/extras/ta-*.sh を順番に source（Issue #170）
165:  for extra in "$EXTRAS_DIR"/ta-*.sh; do
```

R-032 の検証コマンドは**本 head で既に PASS**しており、監査表の
`resolved-by-design` / `516e2f7` は**実態と一致**する（反映不要は正しい）。

### V-4: 承認境界・変更範囲

```console
$ git diff --name-only 00210dd..HEAD
docs/working/TASK-0921/plan.md
docs/working/TASK-0921/review-external.md
docs/working/TASK-0921/test-cases.md
docs/working/TASK-0921/todo.md
```

- **`approvals/` / `c3.json` は diff に含まれない**（AI が承認トークンを発行していない）✅
- **`tests/` / `scripts/` / `bin/` / `.github/` は 1 ファイルも変更されていない**✅
  — とくに HO 対象の `.github/workflows/**` が**不変**であることは、R-022 / R-026 を
  「patch 提示のみ」に留めた申告と一致する

## 重点観点の判定

| 観点 | 判定 | 根拠 |
|---|---|---|
| R-021 の反映が実物と整合するか | **PASS** | V-1 / V-2（再測定 + 両シェル再現）。行番号・型別件数・層帰属・控除理由がすべて一致 |
| Task 5 の 3 本 → 7 本が todo / test-cases / DoD へ追随 | **PASS** | `todo.md:171-175`（T-05 に 7 本 + 型別内訳）/ `todo.md:180`（dash・bash 双方で実走）/ `todo.md:357`（DoD の grep 0 件）/ `plan.md:624`（Task 5 本文）/ `plan.md:1103-1112` / `test-cases.md:513`（TC-17 の対象 7 本）/ `test-cases.md:583-586`（Slice 1 DoD に 7 本を列挙 + `ta-31` の層 B 控除）。**追随漏れなし** |
| 新規 TC-26〜29 / M-15〜19 の AC 紐づけ（孤児検査） | **PASS** | TC-26→AC-2 (b) / TC-28・TC-29→AC-1 / TC-29→AC-2 (c) / TC-27→補助的な設計制約表（R-029 行、`test-cases.md:530`）。M-15〜19 は Mutation Matrix `:474-478` に kill 対象 TC 付きで全件登録され、Slice 1 DoD `:581` に入る。**AC 無し TC・TC 無し AC ともゼロ**。TC-27 のみ AC 直属でないが、これは「AC 直属ではないが Exit Criteria に含む」と**明示された区分**であり孤児ではない |
| Human 判断事項が「AI が決めた」形になっていないか | **PASS** | `plan.md:1453` `## Human C-3 の判断事項` に **HJ-1（R-022）/ HJ-2（R-023）/ HJ-3（R-026）/ HJ-4（R-030）** を集約。HJ-1・HJ-3 は「**AI は適用しない**。以下は patch 案の提示であり、適用は Human-owned」と明記し diff 形式で提示のみ。HJ-2 は「前倒しする / Slice 2 に委ねる」の**両論を併記して未裁定**。HJ-4 は「(a) 2 値化 / (b) 保持 + 規約化 のいずれかを C-3 で確定」と明記。**AI による裁定は認められない**。さらに Slice 1 DoD `:601` に「HJ-1〜HJ-4 が C-3 で裁定済み」を必須ゲートとして置き、`plan.md:1445` に未確定のまま exec へ入ろうとした場合の停止条件も置いている |
| 承認境界（`approvals/` / `tests/` 等の不変） | **PASS** | V-4 |
| `review-external.md` 監査表の実態整合 | **PASS** | R-021〜R-037 の 17 行が `reflected` / `0597b53` で埋まり、**R-032 のみ `resolved-by-design` / `516e2f7`**（V-3 で裏取り済み）。staleness 再検証表（`:911-927`）も各行に検証コマンドと結果が記載され、R-023 / R-025 の**縮小**、R-036 の**未再確認**が正直に記録されている |

## Minor Findings（R6 / 2 件）

### MN-M（minor / C1-TEST-15）: `dash` 不在環境での TC-29 の挙動が未定義

TC-29（`test-cases.md:428-446`）は早期脱出 7 本を **`dash` と `bash` の双方**で実走することを
要求するが、**`dash` が実行環境に存在しない場合の扱いが定義されていない**。

- 本 PBI は同型の問題を **R-026 では既に処理している**: `timeout(1)` について
  「**`timeout(1)` 不在環境でも動くフォールバックを持ち**」を Slice 1 DoD
  （`test-cases.md:593-595`）に明記した。**`dash` については同等の規定がない**（非対称）
- 実害: `/bin/dash` は macOS では比較的新しい追加であり、開発機によっては不在たりうる
  （本 worktree の macOS 26.6 には存在した）。不在時に TC-29 が**黙って半分だけ実行されて
  PASS になる**と、それは本 PBI がまさに塞ごうとしている「静かに通る」クラスの再生産である
- **提案（exec 前に 1 行で解消可能）**: TC-29 の合格条件へ
  「**`command -v dash` が無い場合は fail-closed で FAIL**（SKIP にしない）。または
  `pg_extra_contract_skip` 相当の **rc=3 を明示**して evidence に不実行を記録する」を追加し、
  Slice 1 DoD の M-15 行（`:581-583`「両方で kill されたことが evidence に記録されている」）と
  **同じ強度**で揃える
- **severity 判断**: TC-29 が想定する CI（`ubuntu-latest` = dash 実在）では発火しないため
  **minor**。ただし「両シェル実走」という R-021 の是正の実効性を担保する条項なので、
  exec 開始前の解消を推奨する

### MN-N（minor / C1-B1B2-16）: `pbi-input.md` に「層 A の 3 本」が stale のまま残る

R-021 により **早期脱出は 2 型 7 件**へ是正されたが、**`pbi-input.md` は本反映の対象外**
（human-owned / diff にも含まれない）であり、以下が**旧記述のまま**である:

- `pbi-input.md:96`（層 A 行）: 「**うち 3 本は早期 `exit 0` 経路を持つ**（下記 A-2'）」
- `pbi-input.md:113`（見出し）: 「**### A-2'（MJ-4）: 層 A の 3 本**は…」

これが実害になりうるのは、**`plan.md:123` が「層 A 12 本の一覧は `pbi-input.md`」と
pbi-input を正本として参照している**ためで、ポインタを辿った読み手が
**7 と 3 の矛盾**に当たる。plan / todo / test-cases の 3 文書内では 7 に統一されており、
**計画本体の整合は取れている**（＝ exec の指示としては壊れていない）。

- **AI は pbi-input.md を書き換えていないし、書き換えるべきでもない**（Phase A は human-owned）
- **提案**: Human C-3 で以下のいずれかを選ぶ
  - (a) `pbi-input.md:96` / `:113` を「7 本」へ人間が是正する
  - (b) pbi-input は履歴として据え置き、`plan.md:123` の参照に
    「**早期脱出の件数は本 plan を正本とする（pbi-input の「3 本」は R-021 以前の記述）**」
    と 1 行の注記を足す（**ただし plan 本体の編集は C-3 承認前に限る**）
- **severity 判断**: 実装指示（plan / todo / test-cases）は正しく、AC の充足可否に影響しないため
  **minor**

## 25 項目の判定

> `evidence_ref` は本節の V-1〜V-4（実行コマンドと出力を本ファイル内に記録）を指す。
> 本 C-1 は**確定反映の差分を重点とする簡易 C-1**であり、差分が触れていない項目は
> 「R5（`PASS`）から変化なし」を diff で確認したうえで PASS としている。
> **確認できなかった項目は「確認不能」と明示した（該当 0 件）**。

### Plan チェック（9）

| check_id | result | 根拠 |
|---|---|---|
| C1-PLAN-01 受入基準網羅性 | **PASS** | `test-cases.md:508-520` の AC↔TC 表に AC-1〜AC-8 が全数あり、新規 TC-26〜29 が AC-1 / AC-2 (b) / AC-2 (c) へ接続済み。AC 側の追加・削除は本反映で発生していない |
| C1-PLAN-02 Unknowns 処理 | **PASS** | 未確定は `## Human C-3 の判断事項` の HJ-1〜HJ-4 に集約され、各々に選択肢・影響・責務分界が明記。`plan.md:1445` に「未確定のまま exec へ入ろうとした場合」の停止条件あり |
| C1-PLAN-03 スコープ制御 | **PASS** | `ta-31` の 4 箇所を「層 B ＝ Slice 1 対象外」と明示控除（`plan.md:123` / `:1112`）。変更ファイル数 15 は不変（`plan.md:407`）で Mode = high-risk を維持し、スコープクリープなし |
| C1-PLAN-04 テスト戦略 | **PASS** | 新規 TC-26〜29 と M-15〜19 が Verification 表（`plan.md:1283-1284`）と evidence パスつきで定義。dual-shell 実走の evidence 先も `evidence/test-runs/dual-shell-skip.log` と特定済み |
| C1-PLAN-05 Work Breakdown Output | **PASS** | Task 5 の Output が「7 本の `pg_extra_contract_skip` 置換」へ具体化（`plan.md:624` / `:1103-1112`） |
| C1-PLAN-06 依存関係 | **PASS** | revert 依存順 `T-04 / T-04b / T-05 / T-06 → T-03`（`todo.md:316`）は本反映後も維持。Task 5 の 7 本化は同一 Task 内の対象拡大であり Step 間順序を変えない |
| C1-PLAN-07 動作検証自動化 | **PASS** | TC-29 が「7 本 × dash / bash」で機械実行可能な形（rc==3 の一致 + 診断文字列の出現）に定義。ただし dash 不在時の分岐は未定義（**MN-M**、判定は WARN でなく本項は PASS — 自動化の具体性自体は満たすため） |
| C1-PLAN-08-AEE Stop Condition | **PASS** | `plan.md:1450-1451` に「`\|\| true` 型が dash / bash で異なる rc を返す状態のまま Task 6 の Verification に入ろうとした場合」、`:1445` に「HJ-1〜HJ-4 未確定で exec」の 2 条件が記入済み |
| C1-PLAN-09-AEE Replan Triggers 機械値 | **PASS** | `grep -rn 'return 0 2>/dev/null' tests/extras/` が層 A で 0 件でない、M-15 が片シェルでしか kill されない、等の機械判定可能な値が Stop / DoD に記入されている |

### Plan 品質追加（2）

| check_id | result | 根拠 |
|---|---|---|
| C1-SUP-PLAN-01 No Placeholders | **PASS** | `grep -nE "TBD\|後で実装\|必要に応じて\|いい感じに\|適切に" plan.md todo.md test-cases.md` → **0 件**（実行済み）。新規追加分にも未定義の関数名・パスなし |
| C1-SUP-PLAN-02 Task Sizing | **PASS** | Task 5 は 3 本 → 7 本へ拡大したが、対象ファイル名が全列挙され型別（`\|\| exit 0` 3 / `\|\| true` 4）に分解されており、Task 単位で approve / reject 可能。ファイル集合は層 A 12 本の内側で不変 |

### ToDo チェック（6）

| check_id | result | 根拠 |
|---|---|---|
| C1-TODO-08 タスク粒度 | **PASS** | T-05 の粒度は R5 から不変（対象本数の内訳が精緻化されただけ）。差分は `todo.md` +78 行で新規 Task の追加なし |
| C1-TODO-09 depends_on | **PASS** | `todo.md:316` の revert 依存順、`:15` の Slice 割当が維持 |
| C1-TODO-10 チェックポイント | **PASS** | T-05 に「dash と bash の双方で 7 本を standalone 実走」（`todo.md:180`）という検証チェックポイントが追加されている |
| C1-TODO-11 Iron Law 遵守 | **PASS** | HO 対象（`.github/workflows/**`）を AI が触らない旨が `plan.md:171` / `:1468-1469` に明記され、**実 diff でも不変**（V-4）。承認前コード実行の指示なし |
| C1-TODO-12 完了条件 | **PASS** | `todo.md:357` に「早期脱出 7 本が移行済みで grep が 0 件」を完了条件として追加 |
| C1-TODO-RB rollback | **PASS** | `grep -c "rollback:" todo.md` = **9**（実行済み）。Mode = high-risk の実装タスクに付与済みで、7 本化により新規タスクは増えていない |

### テストケースチェック（3）

| check_id | result | 根拠 |
|---|---|---|
| C1-TEST-13 AC→TC 網羅性 | **PASS** | 上記「孤児検査」。AC 無し TC / TC 無し AC ともゼロ |
| C1-TEST-14 テストケースの具体性 | **PASS** | TC-29 は「rc が **identical and equal to 3**」「`pg_extra_contract_skip` の診断が両方に出現」と値レベル。M-15 は「dash: probe が rc=0 / bash: 本体が走る」と kill の現れ方まで特定 |
| C1-TEST-15 エッジケース考慮 | **WARN** | **MN-M**: `dash` 不在環境での TC-29 の扱いが未定義（`timeout(1)` 不在には DoD で対処済みなのに非対称）。それ以外のエッジ（heredoc 内 marker / 行末スペース / 自己マッチ / vacuous PASS の明示記録）は R-027・INFO-1 で網羅済み |

### B-1/B-2 チェック（2）

| check_id | result | 根拠 |
|---|---|---|
| C1-B1B2-16 B-1 確認質問 | **WARN** | **MN-N**: `pbi-input.md:96` / `:113` の「層 A の 3 本」が R-021 是正後も stale。`plan.md:123` が pbi-input を層 A の正本として参照しているため、参照を辿ると 7 と 3 が矛盾する。plan / todo / test-cases 内は 7 に統一されており実装指示は正しい |
| C1-B1B2-17 B-2 アプローチ比較 | **PASS** | 案 C / 案 D の比較と決着（Human 決定 1）は維持。本反映で追加された HJ-1（(a) dash 明示 / (b) matrix）・HJ-4（(a) 2 値化 / (b) 保持 + 規約化）も**いずれも 2 案以上を併記して未裁定**のまま提示している |

### 横断（3）

| check_id | result | 根拠 |
|---|---|---|
| C1-SEC-01 秘密情報 非接触 | **N/A** | `.env` / APIキー / トークン / 個人パスを扱わない。導入する env（`PG_EXTRA_CONTRACT_PROBE` 系）は test-internal であり秘密情報ではない |
| C1-SCOPE-DISC-01 発見事項の予防的分離 | **PASS** | R-021 の発見を**その場で `.github/workflows/**` を直さず** HJ-1 の patch 提示に分離し、追跡 issue **#1026** を採番。`ta-31` の 4 箇所も Slice 2 へ分離（`plan.md:1057`） |
| C1-UI-01 UI デザインシステム準拠 | **N/A** | non-UI（shell テストハーネスの契約変更） |

## Human C-3 の判断事項（一覧 / C-3 はこの表を判断すればよい）

> **HJ-1〜HJ-4 は plan 側で AI が未裁定としたもの、HR-1〜HR-2 は本 C-1（R6）が新たに
> Human 判断へ回すもの。** いずれも AI は決めていない。

| ID | 論点 | 選択肢 | 出典 | AI の裁定 |
|---|---|---|---|---|
| **HJ-1** | CI の `sh` 実体を固定するか（**HO 対象・patch 提示のみ**） | (a) dash 明示 / (b) dash + bash matrix | R-022 / `plan.md:1458` | **していない**（適用は Human-owned） |
| **HJ-2** | 層 C の ROOT sentinel を Slice 1 へ前倒しするか | 前倒し / Slice 2 の D-2 (c) に委ねる | R-023 / `plan.md:1497` | **していない** |
| **HJ-3** | `timeout-minutes` の再見積り（**HO 対象・patch 提示のみ**） | HJ-1 の patch に同梱 / 別途 | R-026 / `plan.md:1529` | **していない**（適用は Human-owned） |
| **HJ-4** | 案 D における `original rc` の捕捉規約 | (a) 2 値化（**TC-06 の削除 / 再定義を伴う**）/ (b) 保持 + 規約化 | R-030 / `plan.md:1533` | **していない** |
| **HR-1**（本 C-1 で追加） | `dash` 不在環境での TC-29 の扱い | fail-closed で FAIL / rc=3 明示 + evidence 記録 / 現状のまま受容 | **MN-M** | **していない**（提案のみ） |
| **HR-2**（本 C-1 で追加） | `pbi-input.md` の stale な「層 A の 3 本」 | (a) pbi-input を人間が 7 本へ是正 / (b) plan 側に正本注記（**C-3 承認前に限る**）/ (c) 受容 | **MN-N** | **していない**（pbi-input は編集していない） |

**注**: HR-1 / HR-2 のいずれも「plan 本体の編集」を伴いうるが、
**C-3 承認後の plan 編集は `plan_hash` を無効化するため禁止**である
（本ファイル冒頭の R5 の記述と一貫）。修正するなら **`c3.json` 発行前**に行うこと。

## C-3 Readiness（R6 時点）

- [x] C-2（別系統 4 レーン）R-021〜R-037 の **1 回確定反映が完了**（`0597b53`）
- [x] **簡易 C-1 再実行が完了**（本節 = 順序規約 (3)）— **PASS / critical 0 / major 0 / minor 2**
- [x] 承認境界の不侵犯を実 diff で確認（`approvals/` 不在 / `tests/` `scripts/` `bin/` `.github/` 不変）
- [x] R-021 の是正が実物と整合することを**独立に再測定・再現**（V-1 / V-2）
- [ ] **HJ-1〜HJ-4（+ HR-1 / HR-2）の Human 裁定** — C-3 の判断対象
- [ ] **Human C-3 による `c3.json`（`c3_status=APPROVED`・確定後 plan の `plan_hash`）発行**
      — 順序規約 (4)。**本 C-1 は承認トークンを発行していない**
- [ ] runtime inventory の exec 開始時取得（Task 1 で確定する設計上の未了。R5 から不変）

## 本 C-1 の限界（過信しないための明示）

- 本レビューは **plan / todo / test-cases / review-external の記述と、それが参照する
  実ファイル（`tests/extras/*`・`tests/run-tests.sh`・`.github/workflows/test.yml`）の突合**まで。
  **contract TA / helper はまだ存在しない**ため、TC-01〜29 の実際の検出力は exec で初めて検証される
- V-2 のシェル再現は **macOS 26.6 のローカル実測**である。`ubuntu-latest` の実 CI 上で
  同じ分岐が起きることは `/bin/sh` = dash という前提からの推論であり、**実走では確認していない**
  （TC-29 がこれを exec 時に埋める設計になっている）
- R-036（open PR 状況）は監査表自身が「**未再確認**」と記録しており、本 C-1 でも再確認していない

---

# river-review 是正後の再確認（R7 / 独立レビュアー）

> **R6 までの記述は一切書き換えていない**（C-1 の履歴保全）。本節は R6（`949bae6`）の後に
> 入った 2 コミットに対する**再確認**である。

- **レビュー日**: 2026-08-10
- **レビュアー**: R6 と同一の独立 C-1（maker / checker 分離を維持）
- **対象 head**: **`5d6db49ab5b1909ddb982531f5c2880a577b257f`**
- **検証した差分**:
  - `77f3730` — 独立 river-review の **F1〜F7**（major 3 / minor 4）の是正
  - `5d6db49` — オーガナイザーによる追加修正（F1 是正が持ち込んだ禁止条項違反の解消）
- **対応ラウンド**: **3 回目**（R6 → river-review F1〜F7 → 本 R7）

## Verdict（R7）

**`PASS`** — critical 0 / major 0 / **minor 2** / info 0。

**新規に major 以上は検出していない。** F1〜F7 の 7 件はいずれも**形式的な字面合わせではなく
実質が解消**されており、独立に再測定・再現できた範囲ではすべて実物と整合した。
オーガナイザーの追加修正（`5d6db49`）も**妥当**であり、異論はない。

新規の minor 2 件（**MN-O** / **MN-P**）はいずれも
**設計判断・AC・TC の結論を変えない**（記述の過度な一般化 1 件 + 狭い条件でのみ成立する
エッジケース 1 件）。

## 収束判定

`pr-watch` の収束ルール（新規指摘が **minor / info のみ**になった時点で merge-ready 判定へ
進んでよい / 上限 3 を超えたら human escalate）に照らして:

| 判定軸 | 結果 |
|---|---|
| 本ラウンドの新規指摘 severity | **minor 2 / major 0 / critical 0** |
| 収束ルールの充足 | **充足**（新規は minor のみ）→ **merge-ready 判定へ進んでよい** |
| ラウンド数 | **3 回目 = 上限ちょうど**（超過していないため escalate 条件には未達） |
| **escalate の要否** | **不要**（major 以上の新規なし） |

> ただし**ラウンド上限に到達している**ため、MN-O / MN-P を**さらに 1 ラウンド回して直すことは
> 推奨しない**。どちらも C-3 の裁定事項（後掲 **HR-3** / **HR-4**）として Human に渡し、
> **`c3.json` 発行前に直すか受容するかを 1 回で決める**のが順序規約と整合する。

## 前ラウンド（R6）の指摘の disposition

| ID | R6 での指摘 | disposition | 根拠 |
|---|---|---|---|
| **MN-M** | `dash` 不在環境での TC-29 の扱いが未定義（`timeout(1)` 不在とは非対称） | **解消済み**（F6 として独立 river-review も同一指摘に到達） | `test-cases.md:451`「**If `dash` cannot be resolved, this case FAILs — it must not be skipped (F6).**」が **TC-29 の本体**に入った。R-026 の timeout 裁定との対称性まで明記（`:451-453`）。`plan.md:1327` / `:1400`（Verification 表）/ `todo.md:203` にも伝播。**私が求めた「TC の spec に入れる」形で入っている**（plan / todo だけの記載に留まっていない） |
| **MN-N** | `pbi-input.md` の「層 A の 3 本」が stale | **方式変更のうえ解決（私の案より良い）** | 私は「(a) pbi-input を人間が是正 / (b) plan 側に注記」を提示したが、**採られたのは HJ-5 = 裁定事項として Human へ委譲**。`pbi-input.md` は**未編集**（`git diff` で確認）。`plan.md:1691` は「**HJ-5 の裁定まで stale であり…3 と 7 が食い違う**」と**隠さず明記**し、`test-cases.md:534` にも同じ注記がある。**AC 正本を AI が書き換えない**という責務分界を保ったまま矛盾を可視化しており、私の案 (b)（plan 側に「plan を正本とする」と書く）より正しい — (b) は AC 正本の所在を AI 側にずらす副作用があった |

## F1〜F7 の再確認（実行コマンドと結果）

### F1（major）: `.` 失敗は `||` / `if` で捕捉できない — **解消・実測で確認**

主張が強い（POSIX special built-in の挙動）ため、**スクリプトファイルを渡して自分で再現**した
（`-c` 経路では再現しないため）。検証後 `rm -rf .c1probe2` 済み。

`. /nonexistent/helper.sh || { echo "DIAG-REACHED"; }` の後に `echo AFTER`:

| シェル | 結果 | rc |
|---|---|---|
| `/bin/dash`（= CI の `sh`） | `BEFORE` のみ。**DIAG も AFTER も出ない**（即終了） | **2** |
| `/bin/sh`（macOS = bash 3.2 の **POSIX mode**） | `BEFORE` のみ。**同上** | **1** |
| `/bin/zsh` | `BEFORE` / `DIAG-REACHED` / `AFTER`（継続） | 0 |
| `/bin/bash`（**非 POSIX mode**） | `BEFORE` / `DIAG-REACHED` / `AFTER`（**継続**） | 0 |

`if . /nonexistent/helper.sh; then … else …; fi` 形でも dash rc=2 / `/bin/sh` rc=1 で
**診断に到達しない**ことを別途確認した（`||` 固有ではない）。

- **`plan.md:603-607` の表は正確**である。表は `/bin/dash` / **`/bin/sh`（macOS = bash 3.2）** /
  `/bin/zsh` の 3 行であり、**「`/bin/sh`」と書いてあって「`bash`」とは書いていない**。
  私が追加で測った `/bin/bash`（非 POSIX mode）の挙動は表の主張と矛盾しない
- 差し替え後の `[ -r "$helper" ]` 先行プローブは **4 シェルすべてで診断に到達**することを確認
  （`/bin/dash` で `DIAG-REACHED: helper unreadable` + `AFTER` / rc=0）。**是正は実質的に有効**
- 原因記述の是正（「`set -eu` 下で」→「special built-in の失敗は `set -e` に依らない」）も
  `plan.md:609-611` に入っている。**ただしこの一文には過度な一般化がある** → **MN-O**

### F2（major）: `ta-49` は節単位の部分 SKIP — **解消・実測で確認**

```console
$ head -8 tests/extras/ta-49-bias-export.sh
…
# 2 層:
#   A. _resolve_validation_bias.py の機能テスト（常時実行・AI-owned ヘルパー）
#   B. bin/plangate 配線テスト（HO 未適用時は SKIP）
$ grep -n "return 0 2>/dev/null" tests/extras/ta-49-bias-export.sh
72:  return 0 2>/dev/null || true
$ awk 'NR<72 && (/pass=\$\(\(pass/ || /fail=\$\(\(fail/)' tests/extras/ta-49-bias-export.sh | wc -l
       8
```

- ファイル冒頭が **2 層構造を明示**し、`:72` の guard 直前は
  `# ---- 層 B: bin/plangate 配線（未適用なら SKIP）----`、SKIP 診断も
  **`[SKIP] TC-03/TC-05`** と**一部の TC のみ**を名指ししている
- **guard 到達前に `pass` / `fail` が 8 回更新される**ことを実測（`awk` で行番号 72 未満を計数）。
  指摘元・是正側の「8 箇所」と一致
- したがって **`ta-49` に一律 rc=3 を要求すると `fail>0` 時に precedence（rc=1）と衝突する**という
  F2 の指摘は**正しい**
- **是正の伝播も追随漏れなし**（私が R6 で最も事故りやすいと指摘した箇所）:
  `plan.md:170-193`（`#### 7 本は同質ではない` 新設・6 本 / 1 本の構造表 + カウンタ未更新の実測根拠）/
  `plan.md:723-725`（TC-17 の対象を 6 本へ）/ `plan.md:1210-1219`（Task 5 を 6+1 で分岐）/
  `plan.md:1400`（Verification 表の期待値を構造別へ）/
  `todo.md:187-202`・`:381-382` / `test-cases.md:444-449`（TC-29 を表形式へ）・`:618-619`（DoD 内訳）
- **TC-29 の再設計が適切**（`test-cases.md:444-449`）: 「**クロスシェルの rc 一致**が両群共通の
  検査対象で、期待値だけが構造で分かれる」と整理されており、`ta-49` は
  「**先行 TC の結果（0 or 1）— never 3**」。TC-17 側も `:272` で
  「前提未充足 + `fail>0` は rc=1 であり TC-17 の対象外」と既に整合している

### F3（major）: AC-2 (c) の対象を AI が独断拡張 — **解消（HJ-5 へ委譲）**

- `test-cases.md:545` の AC-2 (c) セルは
  「**対象本数は注記 1 を参照（正本は `pbi-input.md`・裁定待ち）**」へ戻され、
  **7 本という確定記述が撤去**されている
- **`HJ-5` が新設**され、plan（`:1676-1697`）/ todo（`H-06` = `:62`, `:70`）/
  test-cases（`:9`, `:532-534`, `:626`）へ一貫して伝播。`HJ-1〜HJ-5` の表記も
  plan `:1571` / `:1710-1715`、todo `:355` / `:383` で揃っている
- **`pbi-input.md` は未編集**（`git diff --name-only 949bae6..5d6db49` に含まれない）
- **実装対象と AC 文言を分離**した点が良い（`plan.md:1695-1697`）:
  「裁定が済むまで TC-17 / TC-29 / Task 5 は `#### 7 本は同質ではない` を対象定義として用いる
  （**AC の文言とは独立に、実装対象は 7 本で確定している**）」。
  これにより **exec がブロックされないまま AC 正本の書き換えだけを Human に残せる**

### F4: Traceability の AC-7 — **解消**

`test-cases.md:551` が **`M-01〜M-19`** へ是正され、Slice 列も
「**M-15〜M-19（全 Slice 1）を含む**」と具体化。`todo.md:274` も `M-01〜M-19` へ追随。

### F5: `EXTRAS_DIR` への新規 env 依存 — **解消・実測で確認**

```console
$ grep -n "^unset" tests/run-tests.sh
20:unset PLANGATE_SKIP_REASON PLANGATE_HOOK_TASK PLANGATE_HOOK_FILE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_STRICT PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE 2>/dev/null || true
$ grep -n "FIXTURES_DIR=\|EXTRAS_DIR=\|PG_HARNESS_SOURCED" tests/run-tests.sh
23:FIXTURES_DIR="…/fixtures"
24:EXTRAS_DIR="…/extras"
163:PG_HARNESS_SOURCED=1
```

- **plan の主張どおり**: unset は **7 個**で、**`EXTRAS_DIR` / `FIXTURES_DIR` は含まれない**
  （23-24 行で `export` なしに代入）。一方 **`PG_HARNESS_SOURCED` は 20 行で unset され
  163 行で自ら設定**されるため汚染耐性がある
- 是正後の mode 判定は **`PG_HARNESS_SOURCED` AND `FIXTURES_DIR`**（`plan.md:555`）で、
  **既存 extras と同一イディオム**（`ta-49:71` が実際に同じ判定式）。
  **新しい guarded 外 env 依存を増やしていない**
- `EXTRAS_DIR` は **harness 経路でのみ読む**（`plan.md:635-636`）ため、
  standalone で外部から `EXTRAS_DIR` を export されても届かない。**F5 の是正は有効**
- なお本 mode 判定には**狭いエッジケース**が残る → **MN-P**

### F6: `dash` 不在時の TC-29 — **解消**（R6 の MN-M と同一指摘）

前掲「MN-M の disposition」を参照。**TC-29 の本体**に入っている点が重要。

### F7: `timeout-minutes` の時間モデル — **解消**

- `plan.md:1429-1430` が **per-job wall clock**（`timeout-minutes` が効く軸）と
  **総 CI 分**（課金・キュー）の 2 軸表へ分離され、
  「`strategy.matrix` は**独立した job へ展開**され、`timeout-minutes` は **job 単位**」
  と明記。**GitHub Actions の実際のセマンティクスとして正しい**
- 20 分の根拠が **per-job wall clock のみ**に置き直され（`:1623-1625`）、
  「matrix 化は per-job wall clock を増やさない / 増えるのは総 CI 分」と結論も是正
- HJ-1 patch に `name:` 明示と **required checks の設定確認**を Human 前提条件として追記
  （matrix 化で job 名が変わり required check が外れる、という運用事故を先回りしている）

### `5d6db49`（オーガナイザー追加修正）の妥当性 — **妥当。異論なし**

```console
$ grep -n "return 0 2>/dev/null" docs/working/TASK-0921/plan.md
（該当は grep コマンド文字列・禁止条項の記述・是正の経緯注記のみ。
  tests/extras/ へ着地する規範スニペットには 1 件も残っていない）
```

- 差し替え後の bootstrap（`plan.md:565-572`）は
  **`_pg_extra_mode` を再利用して `return 0`（harness）と `exit 1`（standalone）を書き分ける**形で、
  **禁止イディオムを含まない**
- **`5d6db49` の判断根拠 (2) は特に妥当**である: 「Slice 1 DoD の
  `grep -rn 'return 0 2>/dev/null' tests/extras/` = 0 件という**機械検査が、例外を持つと
  人手判断を含む検査へ退化する**」— これは R6 で私が MN-M について述べた
  「黙って半分だけ実行して PASS になる」と同じ論理であり、**検査器の価値を保つ判断として正しい**
- 経緯が `plan.md:593-595` に**隠さず記録**されている（「是正を担当したワーカー自身が申告して
  発見された」）点も、監査可能性の観点で適切

## 新規 Minor Findings（R7 / 2 件）

### MN-O（minor / C1-PLAN-04）: 「`set -e` の有無に依らない」は非 POSIX mode の `bash` で成立しない

`plan.md:609-610` は F1 の原因記述を是正して
「**これは `set -e` の有無に依らない**。special built-in の失敗はそれ自体が非対話シェルの
終了要因であり、『`set -eu` 下で `.` が失敗すると』という説明は**不正確**」としている。
**結論（`[ -r ]` 先行プローブ）は全シェルで正しい**が、**この一文自体が過度な一般化**である。

実測（`. /nonexistent` → 診断到達と rc）:

| シェル | `set -eu` なし | `set -eu` あり |
|---|---|---|
| `/bin/dash` | 終了 / rc=2（診断に到達しない） | 終了 / rc=2 |
| `/bin/sh`（bash の POSIX mode） | 終了 / rc=1（同上） | — |
| **`/bin/bash`（非 POSIX mode）** | **継続 / rc=0（診断に到達する）** | **終了 / rc=1（到達しない）** |

- **`set -e` に依らない**のは **dash と POSIX mode の bash** のみ。
  **非 POSIX mode の `bash` では `set -e` の有無が結果を分ける**
- これが無視できない理由: **`tests/extras/` の対象ファイルは `set -eu` を持たない**
  （実測: `grep -c "set -eu" tests/extras/ta-39…/ta-45…/ta-49…` = **0 / 0 / 0**）。
  かつ **TC-29 は `bash` での実走を明示的に要求している**。したがって
  「`bash` で `. || 診断` は診断に到達しない」と読むと**実測と食い違う**組合せが
  本 PBI のテスト経路の中に実在する
- **影響範囲**: 設計判断・AC・TC の結論は**変わらない**（`[ -r ]` プローブは 4 シェルすべてで
  正しく動くことを確認済み）。影響するのは **plan の説明文の正確さ**のみ
- **提案**: `plan.md:609` を
  「**dash と POSIX mode の `sh`（= CI 経路）では `set -e` に依らず終了する**。
  非 POSIX mode の `bash` では `set -e` の有無で分かれるが、いずれにせよ
  `. → 失敗検知` は**移植可能な形にならない**」へ 1 文で精密化する
- **severity 判断**: **minor**。ただし本 plan は R-021 で
  「シェル挙動の過度な一般化」により critical を出した経緯があり、**同じクラスの誤りが
  是正文の中に再発している**点は記録に値する

### MN-P（minor / C1-TEST-15）: bootstrap の mode 判定は「env 由来」であり、汚染時に真 standalone で `return 0` を実行しうる

是正後の bootstrap（`plan.md:555-572`）は **env（`PG_HARNESS_SOURCED` AND `FIXTURES_DIR`）から
mode を導出**し、helper 未解決時にその mode で `return 0` / `exit 1` を選ぶ。
しかし **「実際に source されているか」は env ではなく起動方法の性質**であり、両者は乖離しうる。

**発火条件（3 つの同時成立が必要）**:
1. **standalone 実行**（真に `sh ta-XX.sh` として起動）
2. 外部環境から **`PG_HARNESS_SOURCED=1` かつ `FIXTURES_DIR` 非空**が継承されている
3. **helper が読めない**（配り忘れ / revert 順序誤り）

このとき bootstrap は **harness 分岐**を選び、`fail=$((fail+1))` の後に
**top-level の `return 0`** を実行する。実測（`fail=1` を立てた後に bare `return 0`）:

| シェル | 挙動 | rc |
|---|---|---|
| `/bin/dash` | **script がそこで終了** | **0** |
| `/bin/bash` / `/bin/sh` | `return: can only 'return' from a function or sourced script` を stderr へ出し **本体を継続** | **0** |

- **3 シェルとも rc=0**。すなわち **`fail>0` なのに rc=0** という、
  **本 PBI（issue #921）が塞ごうとしている「静かに通る」クラスそのもの**が再現する
  （`[FAIL] helper unresolved:` の診断は stderr に出るため完全な無音ではない）
- **なぜ既存 extras より悪化するか**: 既存 extras も同じ mode 判定イディオムを使うため
  **汚染窓自体は新規ではない**（`plan.md:633` の「新しい依存を増やさない」は正しい）。
  新規なのは、**その分岐の中に top-level `return 0` が置かれた**点である。
  `plan.md:576-591` は「禁止の根拠（shell 実体で挙動が割れる）が bootstrap にも当てはまる」と
  正しく述べているが、**bare `return 0` も真 standalone では同じく shell 実体で割れる**
- **提案（いずれか。exec 前に 1 行で解消可能）**:
  - (a) helper 未解決の分岐では **mode を信用せず常に `exit 1`** にする（harness でも
    suite は止まるが、helper 不在は**恒常的な配布事故**であり全滅させて気付く方が安全）
  - (b) `_pg_extra_mode=harness` の分岐で **`EXTRAS_DIR` の非空も AND 条件に加える**
    （発火条件 2 を潰す。`EXTRAS_DIR` は runner が必ず設定する）
  - (c) 受容する。ただし **`plan.md` の既知の残存リスクとして明記**し、handoff へ引き継ぐ
- **severity 判断**: **minor**。発火に 3 条件の同時成立を要し、`PG_HARNESS_SOURCED` は
  guarded env（TC-15 の対象）であるため通常運用では踏まない

## Human C-3 の判断事項（最終一覧）

> **HJ-1〜HJ-5 は plan 側で AI が未裁定としたもの**、**HR-1〜HR-4 は独立 C-1（R6 / R7）が
> Human 判断へ回すもの**。いずれも **AI は決めていない**。

| ID | 論点 | 選択肢 | 出典 | 状態 |
|---|---|---|---|---|
| **HJ-1** | CI の `sh` 実体を固定するか（**HO 対象・patch 提示のみ**） | (a) dash 明示 / (b) dash + bash matrix | R-022 / `plan.md:1478` | 未裁定。**適用は Human-owned**。patch に `name:` 明示 + **required checks 再設定の確認**が前提条件として付いた（F7） |
| **HJ-2** | 層 C の ROOT sentinel を Slice 1 へ前倒しするか | 前倒し / Slice 2 の D-2 (c) に委ねる | R-023 | 未裁定 |
| **HJ-3** | `timeout-minutes` の再見積り（**HO 対象・patch 提示のみ**） | HJ-1 の patch に同梱 / 別途 | R-026 | 未裁定。**20 分の根拠が per-job wall clock のみに是正済み**（F7） |
| **HJ-4** | 案 D における `original rc` の捕捉規約 | (a) 2 値化（**TC-06 の削除 / 再定義を伴う**）/ (b) 保持 + 規約化 | R-030 | 未裁定 |
| **HJ-5**（F3 で新設） | **AC-2 (c) の対象本数（3 本 → 7 本 = 全体ガード 6 + 節スキップ 1）を `pbi-input.md`（正本）へ反映するか** | (a) pbi-input を 7 本 / 6+1 構造へ更新 / (b) AC は 3 本のまま据え置き、残り 4 本は AC-1 で回収 | F3 / `plan.md:1676` | 未裁定。**`pbi-input.md` は未編集**。裁定まで pbi-input の「層 A の 3 本」は **stale であると明示済み**。**実装対象は 7 本で確定**しており exec はブロックされない |
| **HR-1**（R6） | `dash` 不在環境での TC-29 の扱い | — | R6 MN-M | **解決済み**（F6 で「SKIP せず FAIL」に確定。裁定不要） |
| **HR-2**（R6） | `pbi-input.md` の stale な「層 A の 3 本」 | — | R6 MN-N | **HJ-5 に統合**（重複のため本項は閉じる） |
| ~~**HR-3**（R7 で追加）~~ | ~~`plan.md:609`「`set -e` の有無に依らない」の精密化~~ | (a) 1 文で精密化 | **MN-O** | **裁定不要 — 案 (a) で是正済み（`a0e864b` / オーガナイザー）**。表に `/bin/bash`（非 POSIX モード = 継続 / rc=0）行を追加し、原因帰属を「**POSIX 準拠モードか否か**」へ是正。オーガナイザーが `/bin/bash` で独立再現したうえで反映。**結論・設計・AC・TC は不変**のため C-3 の裁定対象から外す |
| **HR-4**（R7 で追加） | bootstrap の helper 未解決分岐が汚染時に真 standalone で `return 0` を実行しうる | (a) 常に `exit 1` / **(b) `EXTRAS_DIR` 非空を AND 条件に追加** / (c) 既知リスクとして受容し handoff へ | **MN-P** | **裁定済み（2026-08-10 Human C-3）— (b) を採用**。`plan.md` の bootstrap スニペットと `### Mode resolution` を同一述語（`PG_HARNESS_SOURCED=1` AND `FIXTURES_DIR` 非空 AND `EXTRAS_DIR` 非空）へ反映済み。`tests/run-tests.sh:23` / `:24` が両 dir を設定するため**正規の harness 経路は不変**。**残存**: 3 変数すべてが汚染された場合は依然 harness 分岐へ落ちる（窓は狭まるが閉じない）→ handoff の既知課題へ記載 |

**注**: HR-3 / HR-4 の修正はいずれも `plan.md` の編集を伴う。
**C-3 承認後の plan 編集は `plan_hash` を無効化するため、直すなら `c3.json` 発行前**に行うこと。
受容する場合は plan / handoff に既知リスクとして残せばよく、**exec はブロックされない**。

## C-3 Readiness（R7 時点）

- [x] C-2（別系統 4 レーン）R-021〜R-037 の 1 回確定反映（`0597b53`）
- [x] 簡易 C-1 再実行（R6 / `949bae6`）— PASS / minor 2
- [x] **独立 river-review F1〜F7 の是正**（`77f3730`）+ **自己矛盾の追加修正**（`5d6db49`）
- [x] **是正後の再確認（R7 / 本節）— PASS / critical 0 / major 0 / minor 2**
- [x] **収束**（新規は minor のみ = merge-ready 判定へ進んでよい。**escalate 不要**）
- [x] 承認境界の不侵犯を再確認（`git diff --name-only 949bae6..5d6db49` = plan / test-cases / todo の
      3 ファイルのみ。**`approvals/` / `pbi-input.md` / `review-external.md` / `tests/` / `scripts/` /
      `bin/` / `.github/` はいずれも不変**）
- [ ] **HJ-1〜HJ-5（+ HR-3 / HR-4）の Human 裁定** — C-3 の判断対象
- [ ] **Human C-3 による `c3.json` 発行** — 順序規約 (4)。**本 C-1 は承認トークンを発行していない**
- [ ] runtime inventory の exec 開始時取得（Task 1 で確定する設計上の未了。R5 から不変）

## 本 R7 の限界

- 検証したのは **plan / todo / test-cases の記述と実ファイル（`tests/extras/*` /
  `tests/run-tests.sh` / `.github/workflows/test.yml`）の突合**、および
  **シェル挙動のローカル再現**まで。**contract TA / helper は未実装**であり、
  TC-01〜29 の実検出力は exec で初めて検証される
- シェル再現はすべて **macOS 26.6 のローカル実測**。`ubuntu-latest` 実 CI 上での再現は
  **確認していない**（`/bin/sh` = dash という前提からの推論）
- F1〜F7 の指摘元である river-review の**出力そのものは読んでいない**。
  本 R7 が確認したのは「**是正後の最終形が実物と整合するか**」であり、
  river-review が**見落とした指摘がないか**は本 R7 の保証範囲外である
  （ただし R7 で独自に MN-O / MN-P の 2 件を新規検出しており、
  **是正後の版に対する独立探索は行っている**）
