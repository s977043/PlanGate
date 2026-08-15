# TEST CASES — TASK-1093 (#1093)

> 実装先: `tests/extras/ta-67-release-prep-pending.sh`（新規・**`ta-65` は #1101 占有につき不可侵**）
> 判定対象: `scripts/release-prep.sh` の **`check_pending_applies()`**（関数名で参照。行番号は使わない）
>
> **v2（C-2 REJECT 反映 / `Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007 R-008 R-009 R-010 R-011 R-012`）**
> — 判定は **script の `--dry-run` exit code**（0=applied / 10=pending / その他=undecidable）で行う。
> **stdout は判定に使わない**（v1 の marker probe / status 行 cross-check は廃止）。

## 受入基準 → テストケース マッピング

| AC | 内容 | TC | 穴 |
|----|------|----|----|
| **AC-1** | 未適用の apply script が pending として報告される | TC-01, TC-02, TC-03 | **(d)** |
| **AC-2** | 適用済みの script が pending に現れない（負の対照） | TC-04, TC-05, **TC-17** | — |
| **AC-3** | `apply-task-0146-ehs23-wiring.sh` が pending に現れない | TC-06 | **(b)** |
| **AC-4** | ERROR 終了時に「適用待ちなし」ではなく「判定不能」で READY を阻む | TC-07, TC-08, **TC-18**, **TC-19** | **(a)** |
| **AC-5** | 通常 checkout と worktree で同じ結果 | TC-09, TC-10 | **(c)** |
| **AC-6** | `sync-plugin-installed.sh` が READY 条件から外れリリース後手順に移る | TC-11, TC-12 | NG-2 |
| **AC-7** | `sh tests/run-tests.sh` rc=0（baseline 維持） | TC-13, **TC-24** | — |
| （構造） | 台帳カバレッジ漏れを構造的に不可能にする | TC-14, TC-15 | (d) の再発防止 |
| （構造） | **判定品質**（コメントだけで applied にならない） | **TC-16 / MUT-6** | **R-002** |
| （構造） | `defer` の挙動と保護 | **TC-20, TC-21, TC-22** | **R-004** |
| （構造） | `vX.Y.Z` 経路の fail-open 解消 | **TC-23** | **R-006** |

## 穴 (a)(b)(c)(d) → TC 1:1 対応

| 穴 | 症状 | v2 で塞ぐ機構 | 実証 TC |
|----|------|-------------|--------|
| **(a) fail-open** | `2>/dev/null \|\| true` で ERROR が「適用待ちなし」に化ける | rc を一次情報にし、**0/10 以外は `undecidable`→NG**。timeout も NG。`vX.Y.Z` 経路の `\|\| true` も撤廃 | **TC-07 / TC-08 / TC-18 / TC-19 / TC-23** |
| **(b) 誤検出** | 無条件ヘッダの `[dry-run]` で適用済みが pending 扱い | **stdout を判定に使わない**。印字内容は verdict に影響しない | **TC-06 / TC-17** |
| **(c) 環境依存** | `.claude/settings.json` 不在で結果が変わる | `scope=local` は**実行せず** `n/a` 固定 | **TC-09 / TC-10** |
| **(d) 検出漏れ** | `[dry-run]` を印字しない未適用 script が不可視 | 台帳が全 script を網羅し、**印字の有無に依存しない** | **TC-01 / TC-02 / TC-03 / TC-14 / TC-15** |

## テストケース一覧

### AC-1: 検出漏れの解消（正の証跡）

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-01** | sandbox に最小サブツリーを複製し、`apply-eh3-ho-always.sh` の対象が**未適用**な状態を合成（`_override=0` を `if [ -z "$task_id" ]` の**後ろ**に置く。**`--apply` は使わない**） | `check_pending_applies()` | `apply-eh3-ho-always.sh` が **`pending`**（rc=10）/ 全体 **NG** | Integration |
| **TC-02** | HEAD そのまま（`apply-rnnn-c4-extension.sh` は**真に未適用**。`grep -c 'P-NNN（C-4 段階指摘の追記専用集約 / #689）' .claude/rules/working-context.md` → **0** で実測済） | `check_pending_applies()` | **`pending`**（旧実装では `[dry-run]` ヒット 0 のため**不可視**だった） | Integration |
| **TC-03** | HEAD そのまま（`apply-task-0130-working-context.sh` は真に未適用。`grep -c 'Stop Condition / Resume Condition / Replan Triggers' .claude/rules/working-context.md` → **0** で実測済） | `check_pending_applies()` | **`pending`** | Integration |

### AC-2: 負の対照（空振り検査でないこと）

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-04** | HEAD そのまま（`apply-eh3-ho-always.sh` は #1089 で**適用済み**。`_override=0`@94 < `if [ -z "$task_id" ]`@119 で実測済） | `check_pending_applies()` | **`applied`**（rc=0）で pending に現れない | Integration |
| **TC-05** | TC-01 の sandbox（未適用）と TC-04（適用済み）を比較 | 両 verdict | **`pending` ⇄ `applied` に反転**（片方向だけでないことの実証） | Integration |
| **TC-17（新規 / R-002）** | HEAD そのまま | `check_pending_applies()` の全 verdict | **`scope=release` の全行**について verdict が `applied` / `pending` / `undecidable` のいずれかに確定し、**`applied` と出た行は TC-16（MUT-6）の対象集合に含まれる**（負の対照が 1〜2 本に閉じない。**集合で定義し件数を契約にしない**） | Integration |

### AC-3: 誤検出の解消

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-06** | HEAD そのまま。`apply-task-0146-ehs23-wiring.sh` は `[dry-run]` を**無条件ヘッダとして印字**し、判定本体は `scripts/_apply_task_0146_patches.py` にある（現行 rc=1） | `check_pending_applies()` | 契約適合後、**印字内容によらず** python の verdict に従う。`bin/plangate` に EHS-2 実装がある（`grep -c '# EHS-2 (TASK-0146 / #527)' bin/plangate` → **1**）状態で **pending に現れない** | Integration |

### AC-4: fail-open の解消

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-07** | sandbox で台帳 `targets` の対象ファイルを**削除** | `check_pending_applies()` | **`undecidable`** → **NG**（`fail=1`）。「適用待ちなし」にならない | Integration |
| **TC-08** | sandbox で script が **rc=2 / rc=127 など想定外**で終了するようにする | `check_pending_applies()` | **`undecidable`** → **NG**。メッセージに **script 名と実 rc を含む**（トレーサビリティ） | Integration |
| **TC-18（新規 / R-003）** | sandbox で script が **stdout を 1 行も出さず rc=0** で終了 | `check_pending_applies()` | **`applied`**（rc が一次情報。**stdout の有無で揺れない**ことの実証） | Integration |
| **TC-19（新規 / R-003）** | sandbox で script が **sleep して timeout を超過** | `check_pending_applies()` | **`undecidable`** → **NG**。検出器がハングしない | Integration |

### AC-5: 環境非依存

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-09** | 同一 sandbox を 2 部複製し、片方にのみ `.claude/settings.json` を配置 | 両方で `check_pending_applies()` | **出力が完全一致**（`diff` が空）。`apply-claude-settings.sh` / `apply-precompact-guard.sh` / `apply-eh-git-destructive-guard.sh` は両方で **`n/a (local)`** かつ **`bin/plangate doctor --check-settings` への導線が出力に含まれる**（R-008） | Integration |
| **TC-10** | 通常 checkout と worktree の**実機 2 環境** | 各 1 回実走し verdict を保存 | verdict 一致（実機証跡） | Manual + Evidence |

### AC-6: リリース後手順の分離

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-11** | — | `sh scripts/release-prep.sh --check` の出力 | 「plugin キャッシュ」を含む行が **0 件** | Integration |
| **TC-12（R-007 で改訂）** | — | `scripts/release-prep.sh` の **`run_checks()` 定義本体** | **`sync-plugin-installed` 参照が 0 件**（**実際に変化する対象**。v1 の「`docs/release-process.md` のリリース前節に無い」は変更前から真＝空振りだったため差し替え）。加えて `docs/release-process.md` の**リリース後**節に記載が 1 件以上 | Unit |

### AC-7: baseline 維持 + extras 契約

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-13** | 実装完了後 | `sh tests/run-tests.sh` | **rc=0**（件数は記録のみ・**絶対値を assert しない**。base 実測 = 本ブランチ head で **rc=0**） | Regression |
| **TC-24（新規 / R-005）** | — | (i) `sh tests/extras/ta-67-release-prep-pending.sh` を **standalone 実行** / (ii) `tests/extras/ta-61-extra-contract.sh` | (i) rc 契約（0/1/2/3）を満たす / (ii) **ta-61 が ta-67 を covered set として PASS**（`_pending_migration` に入れない＝新規は初日から full 準拠） | Contract |

### 構造検査（再発防止）

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-14** | — | `ls scripts/apply-*.sh` の集合 vs 台帳の集合 | **`comm -3` が空**（集合同値。**件数の絶対値は使わない** / R-012） | Unit |
| **TC-15** | sandbox に `scripts/apply-zz-dummy.sh` を追加（台帳登録なし） | `check_pending_applies()` | **`undecidable`** → **NOT READY** | Integration |
| **TC-16（新規 / R-002・MUT-6 の受け皿）** | sandbox で台帳 `targets` の**実装本体を壊し、コメント / marker は残す** | 当該 script の `--dry-run` rc | **rc=10（pending）に反転**する。反転しない＝**判定がコメントを測っている**として **FAIL + 名指し報告**（緑にしない / SC-6）。対象は **`scope=release` かつ `targets` が単一 tracked ファイルの全行**（集合で定義） | Mutation |
| **TC-20（新規 / R-004）** | 台帳に `pending` + `defer=#NNNN`（OPEN issue）を 1 行 | `check_pending_applies()` | **rc=0（READY を阻まない）かつ出力に script 名と issue 番号が必ず出る**（不可視化しない） | Integration |
| **TC-21（新規 / R-004）** | 台帳に `undecidable` になる行 + `defer=#NNNN` | `check_pending_applies()` | **NG のまま**（`defer` は `undecidable` に効かない / R-001 の「握りつぶす経路を作らない」） | Integration |
| **TC-22（新規 / R-004）** | `defer` 行を 1 行追加 | `git diff` / `decision-log.jsonl` | **`git diff` に 1 行として現れる**（監査可能性）かつ **`decision-log.jsonl` に対応エントリが無ければ NG**。参照 issue が **CLOSED なら NG** | Unit + Integration |
| **TC-23（新規 / R-006）** | NOT READY な状態 | `sh scripts/release-prep.sh vX.Y.Z` | **rc≠0**（`run_checks \|\| true` 撤廃。`--check` と同じ rc 伝播） | Integration |

## 変異注入（検出力の実証）

| ID | 変異（**call site / 実態を壊す**） | kill されるべき TC |
|----|--------------------------------|------------------|
| **MUT-1** | `check_pending_applies()` を**旧実装**（`[dry-run]` 文字列一致 + `2>/dev/null \|\| true`）に戻す | TC-02, TC-03, TC-06, TC-07, TC-18 |
| **MUT-2** | `undecidable` の扱いを **NG → OK** に倒す | TC-07, TC-08, TC-15, TC-19, TC-21 |
| **MUT-3** | 台帳カバレッジ照合（`comm -3`）の呼び出しを**削除** | TC-14, TC-15 |
| **MUT-4** | `scope` を見ず**全 script に `n/a` を無条件付与** | TC-01, TC-02, TC-03, TC-06, TC-17 |
| **MUT-5** | `defer` の検査（OPEN / decision-log / `undecidable` 除外）を**削除** | TC-20, TC-21, TC-22 |
| **MUT-6（新規 / R-002）** | **判定品質を kill する変異**: `targets` の**実装本体だけを壊し marker / コメントは残す** | **TC-16**（反転しなければ当該 script の判定が弱い＝FAIL） |
| **MUT-7（新規 / R-006）** | `vX.Y.Z` 経路に `\|\| true` を戻す | TC-23 |

各変異は **sandbox 内で適用**し、対象 TC が **FAIL する**ことを実測して
`evidence/mutation-kill.txt` に記録する。**1 つでも kill されない TC は空振り**として作り直す。

> **MUT-6 は v1 に欠けていた「probe / 判定の品質そのものを殺す変異」**である。
> MUT-1〜5 が検出器の call site を壊すのに対し、MUT-6 は**判定対象の実態**を壊す。

## エッジケース

| ID | ケース | 期待 |
|----|-------|------|
| **E-01** | 台帳に**空行 / `#` コメント行** | 無視（パースエラーにしない） |
| **E-02** | 台帳に**同一 script の重複行** | **`undecidable`** + 明示エラー |
| **E-03** | 台帳の列が**タブ欠落**で不足 | **`undecidable`** + 行番号付きエラー |
| **E-04** | `targets` が**シンボリックリンク / ディレクトリ** | **`undecidable`** |
| **E-05** | `scope=local` なのに `targets` に **tracked ファイル**が 1 つでもある | テストで **FAIL**（`n/a` の抜け道化防止） |
| **E-06** | `defer` が**不正形式**（`#` なし・非数値・CLOSED issue） | **`undecidable`** 扱い（誤記で NG を消させない） |
| **E-07** | `scripts/apply-*.sh` が **0 本** | 台帳も空 → OK（集合同値で成立） |
| **E-08** | script 名に**空白**を含む | TSV 列破損 → **`undecidable`** + 明示エラー |
| **E-09（新規）** | script が **rc=10 だが stdout に何も出さない** | **`pending`**（stdout に依存しない / R-003） |
| **E-10（新規）** | script が **rc=0 だが diff を大量に印字** | **`applied`**（印字は判定に影響しない / R-003） |

## 自動化可否

| TC | 自動化 |
|----|-------|
| TC-01〜TC-09, TC-11〜TC-24, E-01〜E-10, MUT-1〜MUT-7 | **自動**（`ta-67-release-prep-pending.sh`） |
| **TC-10** | **半自動**（判定は自動だが**実機 2 環境での実走は Human / 別セッション**。evidence に verdict 添付） |

## sandbox コスト方針（R-010）

- 複製対象は **`scripts/` + `tests/` + `bin/` + `.claude/`**（`docs/` = **18M** を除外）
- **1 回複製して使い回す**（TC ごとに再複製しない）
- `.github/workflows/test.yml` の job は `timeout-minutes: 10`。
  超過が判明したら **MUT-6 を別 job / 手動実行へ退避**し、退避したことを handoff に明記する
