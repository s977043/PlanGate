# TEST CASES — TASK-1093 (#1093)

> 実装先: `tests/extras/ta-67-release-prep-pending.sh`（新規・**`ta-65` は #1101 占有につき不可侵**）
> 判定対象: `scripts/release-prep.sh` の **`check_pending_applies()`**（関数名で参照。行番号は使わない）

## 受入基準 → テストケース マッピング

| AC | 内容 | TC | 穴 |
|----|------|----|----|
| **AC-1** | 未適用の apply script が pending として報告される | TC-01, TC-02, TC-03 | **(d)** |
| **AC-2** | 適用済みの script が pending に現れない（負の対照） | TC-04, TC-05 | — |
| **AC-3** | `apply-task-0146-ehs23-wiring.sh` が pending に現れない | TC-06 | **(b)** |
| **AC-4** | ERROR 終了時に「適用待ちなし」ではなく「判定不能」で READY を阻む | TC-07, TC-08 | **(a)** |
| **AC-5** | 通常 checkout と worktree で同じ結果 | TC-09, TC-10 | **(c)** |
| **AC-6** | `sync-plugin-installed.sh` が READY 条件から外れリリース後手順に移る | TC-11, TC-12 | NG-2 |
| **AC-7** | `sh tests/run-tests.sh` rc=0（baseline 維持） | TC-13 | — |
| （構造） | 台帳カバレッジ漏れを構造的に不可能にする | TC-14, TC-15 | (d) の再発防止 |
| （構造） | 台帳と script 実態の drift 検知 | TC-16 | R-2 |

## 穴 (a)(b)(c)(d) → TC 1:1 対応

| 穴 | 症状 | 塞ぐ機構 | 実証 TC |
|----|------|---------|--------|
| **(a) fail-open** | `2>/dev/null \|\| true` で ERROR が「適用待ちなし」に化ける | rc を捨てない + probe 評価不能 → `unknown` → **NG** | **TC-07 / TC-08** |
| **(b) 誤検出** | 無条件ヘッダの `[dry-run]` で適用済みが pending 扱い | script の stdout を見ず **対象ファイルの実装 marker** を probe | **TC-06** |
| **(c) 環境依存** | `.claude/settings.json` 不在で結果が変わる | probe を **tracked ファイルに限定**。untracked 対象は `scope=local` → `n/a` | **TC-09 / TC-10** |
| **(d) 検出漏れ** | `[dry-run]` を印字しない未適用 script が不可視 | 台帳が **全 script を必ず 1 行で網羅**し、stdout に依存しない | **TC-01 / TC-02 / TC-03 / TC-14 / TC-15** |

## テストケース一覧

### AC-1: 検出漏れの解消（正の証跡）

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-01** | sandbox に repo を複製し、`apply-eh3-ho-always.sh` の probe が**不成立**な状態を合成（`check-plan-hash.sh` の `_override=0` を `if [ -z "$task_id" ]` の**後ろ**に置いた状態。**`--apply` は使わない**） | `check_pending_applies()` | verdict に `apply-eh3-ho-always.sh` が **`pending`** として現れる / 全体 **NG** | Integration |
| **TC-02** | HEAD そのまま（`apply-rnnn-c4-extension.sh` は**真に未適用**。`.claude/rules/working-context.md` に `P-NNN（C-4 段階指摘の追記専用集約 / #689）` が無い） | `check_pending_applies()` | `apply-rnnn-c4-extension.sh` が **`pending`**（旧実装では `[dry-run]` ヒット 0 のため**不可視**だった） | Integration |
| **TC-03** | HEAD そのまま（`apply-task-0130-working-context.sh` は真に未適用。`working-context.md` に `Stop Condition / Resume Condition / Replan Triggers` が無い） | `check_pending_applies()` | `apply-task-0130-working-context.sh` が **`pending`** | Integration |

> **TC-02 / TC-03 は「未適用 × `[dry-run]` 非印字」を HEAD 実機で再現できる**ため、
> AC-1 の実証が履歴合成に依存しない（R-4 緩和）。

### AC-2: 負の対照（空振り検査でないこと）

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-04** | HEAD そのまま（`apply-eh3-ho-always.sh` は #1089 で**適用済み**。`_override=0` が `if [ -z "$task_id" ]` より**前**にある） | `check_pending_applies()` | `apply-eh3-ho-always.sh` が **`applied`** で pending に**現れない** | Integration |
| **TC-05** | TC-01 の sandbox（未適用合成）と TC-04（適用済み）で**同一 script の verdict が反転**する | 両方の verdict を比較 | `pending` ⇄ `applied` に反転する（**片方向だけでない**ことの実証） | Integration |

### AC-3: 誤検出の解消

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-06** | HEAD そのまま（`bin/plangate` に `# EHS-2 (TASK-0146 / #527)` が存在＝実装済み。旧実装では `[dry-run]` 無条件ヘッダ + rc=1 で pending 誤検出） | `check_pending_applies()` | `apply-task-0146-ehs23-wiring.sh` が **`applied`** で pending に**現れない** | Integration |

### AC-4: fail-open の解消

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-07** | sandbox で台帳の `probe_target` を**削除**（対象ファイル不在＝判定不能） | `check_pending_applies()` | **`unknown`** と報告され **NG**（`fail=1`）。「適用待ちなし」にならない | Integration |
| **TC-08** | sandbox で台帳行の `probe_expr` を**不正な値**にする（評価不能） | `check_pending_applies()` | **`unknown`** → **NG**。エラーメッセージに **script 名と probe_target を含む**（トレーサビリティ） | Integration |

### AC-5: 環境非依存

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-09** | 同一 sandbox を 2 部複製し、片方にのみ `.claude/settings.json` を配置 | 両方で `check_pending_applies()` | **出力が完全一致**（`diff` が空）。`apply-precompact-guard.sh` / `apply-eh-git-destructive-guard.sh` / `apply-claude-settings.sh` は両方で **`n/a (local)`** | Integration |
| **TC-10** | 通常 checkout（`/Users/.../plangate`）と worktree の**実機 2 環境** | 各 1 回実走し verdict を保存 | verdict が一致（**実機での証跡**。Human が両環境で実行して evidence に添付） | Manual + Evidence |

### AC-6: リリース後手順の分離

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-11** | — | `sh scripts/release-prep.sh --check` の出力 | **「plugin キャッシュ」を含む行が 0 件**。`sync-plugin-installed.sh` が READY 判定に寄与しない | Integration |
| **TC-12** | — | `docs/release-process.md` を grep | **リリース後**手順の節に `sync-plugin-installed.sh` の記載が **1 件以上**存在し、リリース**前**節に無い | Unit（doc 整合） |

### AC-7: baseline 維持

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-13** | 実装完了後 | `sh tests/run-tests.sh` | **rc=0**。件数は記録のみ（**絶対値を assert しない**） | Regression |

### 構造検査（再発防止）

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-14** | — | `ls scripts/apply-*.sh` の集合 vs 台帳の script 集合 | **集合が完全一致**（`comm -3` が空）。**件数の絶対値は使わない** | Unit |
| **TC-15** | sandbox に `scripts/apply-zz-dummy.sh` を追加（台帳登録なし） | `check_pending_applies()` | 当該 script が **`unknown`** → **NOT READY**（新規 script の登録漏れを構造的に検出） | Integration |
| **TC-16** | sandbox に `PLANGATE-APPLY-STATUS: applied` を出す dummy script を置き、台帳 probe は `pending` を返すよう設定 | `check_pending_applies()` | **`unknown`**（cross-check 不一致 → fail-closed）。片方を信じて緑にしない | Integration |

## 変異注入（検出力の実証 / `feedback_mutation_testing_for_new_tests`）

| ID | 変異（**call site を壊す**） | kill されるべき TC |
|----|---------------------------|------------------|
| **MUT-1** | `check_pending_applies()` を **旧実装**（`[dry-run]` 文字列一致 + `2>/dev/null \|\| true`）に戻す | TC-02, TC-03, TC-06, TC-07 |
| **MUT-2** | `unknown` の扱いを **NG → OK** に倒す | TC-07, TC-08, TC-15, TC-16 |
| **MUT-3** | 台帳カバレッジ照合の呼び出しを**削除** | TC-14, TC-15 |
| **MUT-4** | `scope` を見ず**全 script に `n/a` を無条件付与** | TC-01, TC-02, TC-03, TC-06 |
| **MUT-5** | cross-check（status 行 vs probe）の呼び出しを**削除** | TC-16 |

各変異は **sandbox 内で適用**し、対象 TC が **FAIL する**ことを実測して
`evidence/mutation-kill.txt` に記録する。**1 つでも kill されない TC は空振り**として作り直す。

## エッジケース

| ID | ケース | 期待 |
|----|-------|------|
| **E-01** | 台帳に**空行 / `#` コメント行**がある | 無視される（パースエラーにしない） |
| **E-02** | 台帳に**同一 script の重複行**がある | **`unknown`**（曖昧を緑にしない）+ 明示エラー |
| **E-03** | 台帳の列が**タブ欠落**で不足 | **`unknown`** + 行番号付きエラー |
| **E-04** | `probe_target` が**シンボリックリンク / ディレクトリ** | **`unknown`** |
| **E-05** | `scope=local` なのに `probe_target` が **tracked ファイル** | テストで **FAIL**（`n/a` の抜け道化を防ぐ / R-6） |
| **E-06** | `ack` が**不正な形式**（`#` なし・非数値） | **`unknown`** 扱い（ack の誤記で NG を消させない） |
| **E-07** | `scripts/apply-*.sh` が **0 本**（将来の全撤去） | 台帳も空 → OK（集合同値なので成立） |
| **E-08** | script 名に**空白**を含む | 台帳が TSV のため列破損 → **`unknown`** + 明示エラー |

## 自動化可否

| TC | 自動化 |
|----|-------|
| TC-01〜TC-09, TC-11〜TC-16, E-01〜E-08, MUT-1〜MUT-5 | **自動**（`ta-67-release-prep-pending.sh`） |
| **TC-10** | **半自動**（判定スクリプトは自動だが、**実機 2 環境での実走は Human または別セッション**。evidence に verdict を添付） |
