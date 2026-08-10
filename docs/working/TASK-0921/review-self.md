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
