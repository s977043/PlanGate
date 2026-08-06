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
