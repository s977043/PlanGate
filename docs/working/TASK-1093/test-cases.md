# TEST CASES — TASK-1093 (#1093)

> 実装先: `tests/extras/ta-67-release-prep-pending.sh`（新規・**`ta-65` は #1101 占有につき不可侵**）
> 判定対象: `scripts/release-prep.sh` の **`check_pending_applies()`**（関数名で参照。行番号は使わない）
>
> **v2（C-2 REJECT 反映 / `Refs: R-001 R-002 R-003 R-004 R-005 R-006 R-007 R-008 R-009 R-010 R-011 R-012`）**
> — 判定は **script の `--dry-run` exit code**（0=applied / 10=pending / その他=undecidable）で行う。
> **stdout は判定に使わない**（v1 の marker probe / status 行 cross-check は廃止）。
>
> **v3（C-3 裁定 2026-08-18 / 案 B: 2 分割）** — **判定方式・AC・穴 (a)(b)(c)(d) は不変**。
> 変更は **どの TC を本 PBI が持ち、どれを [#1114](https://github.com/s977043/PlanGate/issues/1114)
> へ移すか**の分割のみ。**削除した TC は無く、移した TC は下記「#1114 へ移した TC」に明記**する。

## #1114 へ移した TC（削除ではない）

| TC / MUT | v2 での内容 | 移設理由 | 本 PBI に残す代替 |
|----------|-----------|---------|-----------------|
| **TC-16 / MUT-6** | **実 script 全数**（`scope=release` かつ `targets` 単一 tracked）の実装本体を壊し rc=10 反転を要求 | 対象 script が **契約適合済（`adopted`）でないと実行できない**。適合は #1114 の作業 | **TC-16' / MUT-6'**（sandbox の**契約準拠 fixture** に対する同一変異）。「契約 + 検出器の組が判定品質を測れる」ことは本 PBI で実証する |
| **TC-06** | 実 `apply-task-0146-ehs23-wiring.sh` が契約適合後に pending に現れない | 契約適合（verdict を 0/10 に写す）が **#1114 の作業** | **TC-06'**（fixture で「無条件ヘッダを印字するが rc=0」を再現し、**印字によらず `applied`** を実証）。実 script での AC-3 実証は #1114 |
| **TC-17** | `scope=release` の**全行**が `applied`/`pending`/`undecidable` に確定 | 未移行の間は `unmigrated` が入るため全行確定は成立しない | **TC-17'**（`contract=adopted` の**全行**が 3 値に確定 + `contract=legacy` の全行が `unmigrated`。**集合で定義・件数は契約にしない**） |

**引き継ぎ先での受理状況（2026-08-18 実測 / `gh issue view 1114`）**:

| 本 PBI から移した内容 | #1114 側で引き受けている AC |
|---------------------|---------------------------|
| 台帳 `contract` を `legacy` から `adopted` へ移し切る | **#1114 AC-1** |
| `TC-17`（`scope=release` 全行が 3 値に確定）の実 script 版 | **#1114 AC-2** |
| `AC-3` の実 script 実証（`apply-task-0146-*` 等） | **#1114 AC-3** |
| `MUT-6`（判定品質 kill）の実 script 全数版 | **#1114 AC-4** |
| `apply-ai-loop-workflow-command.sh` を適用せず `pending`+`defer` にする | **#1114 AC-6** |

> **AC-3 は削っていない**。本 PBI では **fixture で機構を実証**し、
> **実 script での実証は #1114 の AC-1〜AC-7 が引き受けている**（上表）。
>
> **v3 の「起票時に確認すること（T-21）」という根拠は撤回する** — **#1114 は既に起票済**であり、
> 「起票時に確認する」導線は**永久に実行されない**（run-033 指摘）。
> 代わりに **T-21b で「既存 issue の AC と本 PBI の引き継ぎ内容を突合する」**タスクを立て、
> **齟齬があれば #1114 側を是正する**（本 PBI 側で抱え直さない）。

## 受入基準 → テストケース マッピング

| AC | 内容 | TC | 穴 |
|----|------|----|----|
| **AC-1** | 未適用の apply script が pending として報告される | TC-01, TC-02, TC-03 | **(d)** |
| **AC-2** | 適用済みの script が pending に現れない（負の対照） | TC-04, TC-05, **TC-17'** | — |
| **AC-3** | 無条件ヘッダを印字する script が pending に現れない | **TC-06'**（fixture）/ 実 script は **#1114** | **(b)** |
| **AC-4** | ERROR 終了時に「適用待ちなし」ではなく「判定不能」で READY を阻む | TC-07, TC-08, **TC-18**, **TC-19** | **(a)** |
| **AC-5** | 通常 checkout と worktree で同じ結果 + **環境差は verdict を安全側にしか動かさない**（v4 で単調安全性へ精密化） | TC-09, TC-10, **TC-34** | **(c)** |
| **AC-6** | `sync-plugin-installed.sh` が READY 条件から外れリリース後手順に移る | TC-11, TC-12 | NG-2 |
| **AC-7** | `sh tests/run-tests.sh` rc=0（baseline 維持） | TC-13, **TC-24** | — |
| （構造） | 台帳カバレッジ漏れを構造的に不可能にする | TC-14, TC-15 | (d) の再発防止 |
| （構造） | **判定品質**（コメントだけで applied にならない） | **TC-16' / MUT-6'**（fixture）/ 実 script は **#1114** | **R-002** |
| （構造） | `defer` の挙動と保護 | **TC-20, TC-21, TC-22** | **R-004** |
| （構造） | `vX.Y.Z` 経路の fail-open 解消 | **TC-23** | **R-006** |
| （構造・**v3**） | **移行状態 `contract=legacy` が第 2 の fail-open にならない** | **TC-25, TC-26, TC-27, TC-28** | **U-6** |
| （構造・**v4**） | **拘束の検査が実行できないとき免除を与えない**（fail-closed） | **TC-29, TC-30, TC-31, TC-32, TC-33** | **R-10** |
| （構造・**v4**） | **凍結集合が同語反復でない**（許可集合が台帳の外） | **TC-27 + MUT-13** | **R-11** |

## 穴 (a)(b)(c)(d) → TC 1:1 対応

| 穴 | 症状 | v2 で塞ぐ機構 | 実証 TC |
|----|------|-------------|--------|
| **(a) fail-open** | `2>/dev/null \|\| true` で ERROR が「適用待ちなし」に化ける | rc を一次情報にし、**0/10 以外は `undecidable`→NG**。timeout も NG。`vX.Y.Z` 経路の `\|\| true` も撤廃 | **TC-07 / TC-08 / TC-18 / TC-19 / TC-23** |
| **(b) 誤検出** | 無条件ヘッダの `[dry-run]` で適用済みが pending 扱い | **stdout を判定に使わない**。印字内容は verdict に影響しない | **TC-06' / TC-17'**（実 script 版は #1114） |
| **(c) 環境依存** | `.claude/settings.json` 不在で結果が変わる | `scope=local` は**実行せず** `n/a` 固定。**v4 追加**: ネットワーク / git 履歴の有無は **verdict を NG 側にしか動かせない**（単調安全性） | **TC-09 / TC-10 / TC-34** |
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
| **TC-04** | HEAD そのまま（`apply-eh3-ho-always.sh` は #1089 で**適用済み**。判定は `scripts/hooks/check-plan-hash.sh` において **`_override=0` の代入が `if [ -z "$task_id" ]` の分岐より前に現れる**こと＝ `grep -n` の出現順で確認する。**行番号は記さない**。2026-08-18 時点で成立） | `check_pending_applies()` | **`applied`**（rc=0）で pending に現れない | Integration |
| **TC-05** | TC-01 の sandbox（未適用）と TC-04（適用済み）を比較 | 両 verdict | **`pending` ⇄ `applied` に反転**（片方向だけでないことの実証） | Integration |
| **TC-17'（v3 で改訂 / R-002）** | HEAD そのまま | `check_pending_applies()` の全 verdict | **`contract=adopted` の全行**が `applied` / `pending` / `undecidable` のいずれかに確定し、**`contract=legacy` の全行**が `unmigrated(#1114)` になる。verdict 不明の行が **0**（**集合で定義し件数を契約にしない**）。v2 の「`scope=release` 全行が 3 値に確定」は **#1114 完了時の条件**として引き継ぐ | Integration |

### AC-3: 誤検出の解消（v3: 本 PBI は fixture で実証 / 実 script は #1114）

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-06'（v3 で改訂）** | sandbox の fixture apply script が **`[dry-run]` を無条件ヘッダとして印字しつつ rc=0 を返す** | `check_pending_applies()` | **印字内容によらず `applied`** で pending に現れない（旧実装なら文字列一致で pending になる＝**MUT-1 で kill される**） | Integration |
| — | 実 `apply-task-0146-ehs23-wiring.sh` での実証（判定本体は `scripts/_apply_task_0146_patches.py`・現行 rc=1・`bin/plangate` に EHS-2 実装済） | — | **#1114 の受入条件へ移設**（契約適合が前提のため） | （移設） |

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
| **TC-16'（v3 で改訂 / R-002・MUT-6' の受け皿）** | sandbox の**契約準拠 fixture apply script**（単一 tracked target・冪等判定は実装本体を見る）の**実装本体を壊し、コメント / marker は残す** | 当該 fixture の `--dry-run` rc と検出器の verdict | **rc=10（pending）に反転**し、検出器も **`pending`** を出す。反転しない＝**契約か検出器の設計が誤り**として FAIL（緑にしない / SC-6）。**実 script 全数版は #1114**（MUT-6） | Mutation |
| **TC-25（新規 / U-6）** | 台帳に `contract=legacy` の行がある（#1114 が **OPEN**） | `check_pending_applies()` | **`unmigrated(#1114)` として WARN 行が毎回出力され、READY を阻まない**。**script 名と #1114 が出力に必ず出る**（不可視化しない） | Integration |
| **TC-26（新規 / U-6）** | sandbox で **#1114 が CLOSED** の状態を合成 | `check_pending_applies()` | `contract=legacy` の行が **`undecidable`→NG**（移行の永久先送りを許さない） | Integration |
| **TC-27（v4 で非空振り化 / F-1）** | **台帳だけを編集**し、**凍結リスト `scripts/apply-contract-freeze.list` に無い** script に `contract=legacy` を付ける | 台帳 + 凍結リスト検査 | **FAIL**（`legacy` の値域は**台帳の外**の凍結リストに閉じる / SC-7）。**v3 は許可集合の出所が未定義で、台帳の `legacy` 行から導く実装なら本 TC は構造的に空振りだった**（run-033 指摘）。**MUT-13 が空振り実装を kill する** | Unit |
| **TC-28（v4 で前状態を固定 / F-2）** | 既に `adopted` の行を `legacy` へ差し戻す（＝**凍結リストへ再追加**が必要になる） | 凍結リスト vs **ヘッダに記録された凍結コミットの blob**（`git show <freeze_sha>:scripts/apply-contract-freeze.list`） | **FAIL**（shrink-only 違反）。**比較対象は固定した 1 点**であり「直前のコミット」ではない（drift しない） | Unit |

### 検査不能（v4 新規 / §3-quater・fail-closed）

> **v3 の最大の穴**: 拘束を「凍結集合 + 一方向 + OPEN 検査 + 毎回表示」に置きながら、
> **検査自身が実行できないときの挙動が未定義**だった。実装が「判定不能 → OPEN とみなす」に
> 倒れれば `legacy` / `defer` は **offline で恒久免除**になる（run-033 Model B の最重要指摘）。

| ID | 前提条件 | 入力 | 期待出力 | 種別 |
|----|---------|------|---------|------|
| **TC-29（新規）** | 台帳に `defer=#NNNN` 行あり。sandbox で **ネットワーク不通**（`gh` が非 0 で失敗 / timeout） | `check_pending_applies()` | 当該行が **`undecidable`→NG**。**`pending(defer)` として免除されない**。メッセージに「issue state 取得不能」と理由が出る | Integration |
| **TC-30（新規）** | `contract=legacy` 行あり。sandbox で **`gh` を PATH から除去**（未認証 / rate limit も同型） | `check_pending_applies()` | 当該行が **`undecidable`→NG**。**`unmigrated` として免除されない** | Integration |
| **TC-31（新規）** | `contract=legacy` 行あり。**凍結リストを削除 / 破損 / ヘッダ SHA 欠落** | `check_pending_applies()` | **全 `legacy` 行が `undecidable`→NG**（F-1 が検査できない＝免除しない） | Integration |
| **TC-32（新規）** | `contract=legacy` 行あり。**shallow clone / tarball 展開 / 凍結コミットが履歴に無い / git repo でない** | `check_pending_applies()` | **全 `legacy` 行が `undecidable`→NG**（F-2 が検査できない＝免除しない）。**「履歴が無いから検査省略」にしない** | Integration |
| **TC-33（新規）** | 上記 TC-29〜32 の各状況 | `check_pending_applies()` の**実装** | **「取得失敗 → OPEN とみなす」「取得失敗 → 制約なし」に相当する分岐が grep で 0 件**（SC-8 の静的確認） | Unit |
| **TC-34（新規 / 単調安全性・AC-5 拡張）** | **ネットワーク有無 × git 履歴（full / shallow）有無 の 4 組合せ** | 各組合せで全 verdict を採取 | **NG→OK 方向の変化が 0 件**（OK→NG は許容）。**逆向きが 1 件でもあれば FAIL**。v3 の TC-09 は `.claude/settings.json` の有無しか diff しておらず、**ネットワーク / git 履歴の軸を測っていなかった**（run-033 指摘） | Integration |
| **TC-20（新規 / R-004）** | 台帳に `pending` + `defer=#NNNN`（OPEN issue）を 1 行 | `check_pending_applies()` | **rc=0（READY を阻まない）かつ出力に script 名と issue 番号が必ず出る**（不可視化しない） | Integration |
| **TC-21（新規 / R-004）** | 台帳に `undecidable` になる行 + `defer=#NNNN` | `check_pending_applies()` | **NG のまま**（`defer` は `undecidable` に効かない / R-001 の「握りつぶす経路を作らない」） | Integration |
| **TC-22（新規 / R-004）** | `defer` 行を 1 行追加 | `git diff` / `decision-log.jsonl` | **`git diff` に 1 行として現れる**（監査可能性）かつ **`decision-log.jsonl` に対応エントリが無ければ NG**。参照 issue が **CLOSED なら NG** | Unit + Integration |
| **TC-23（新規 / R-006）** | NOT READY な状態 | `sh scripts/release-prep.sh vX.Y.Z` | **rc≠0**（`run_checks \|\| true` 撤廃。`--check` と同じ rc 伝播） | Integration |

## 変異注入（検出力の実証）

| ID | 変異（**call site / 実態を壊す**） | kill されるべき TC |
|----|--------------------------------|------------------|
| **MUT-1** | `check_pending_applies()` を**旧実装**（`[dry-run]` 文字列一致 + `2>/dev/null \|\| true`）に戻す | TC-02, TC-03, **TC-06'**, TC-07, TC-18 |
| **MUT-2** | `undecidable` の扱いを **NG → OK** に倒す | TC-07, TC-08, TC-15, TC-19, TC-21, **TC-26** |
| **MUT-3** | 台帳カバレッジ照合（`comm -3`）の呼び出しを**削除** | TC-14, TC-15 |
| **MUT-4** | `scope` を見ず**全 script に `n/a` を無条件付与** | TC-01, TC-02, TC-03, **TC-06'**, **TC-17'** |
| **MUT-5** | `defer` の検査（OPEN / decision-log / `undecidable` 除外）を**削除** | TC-20, TC-21, TC-22 |
| **MUT-6'（v3 で改訂 / R-002）** | **判定品質を kill する変異**: **fixture** の実装本体だけを壊し marker / コメントは残す | **TC-16'**（反転しなければ契約 or 検出器の設計が誤り＝FAIL）。**実 script 全数版（MUT-6）は #1114** |
| **MUT-7（新規 / R-006）** | `vX.Y.Z` 経路に `\|\| true` を戻す | TC-23 |
| **MUT-8（新規 / U-6）** | `contract=legacy` の**F-1 検査 / F-2 検査 / #1114 OPEN 検査**を削除 | **TC-26, TC-27, TC-28** |
| **MUT-9（新規 / U-6）** | `unmigrated` を **WARN → 非表示**に倒す（不可視化） | **TC-25** |
| **MUT-10（v4 / 実行不能に落とす変異）** | issue state の**取得失敗を「OPEN とみなす」**に倒す | **TC-29, TC-30, TC-33** |
| **MUT-11（v4 / 同上）** | 凍結リストの**読み込み失敗を「制約なし（全 `legacy` 許可）」**に倒す | **TC-31, TC-33** |
| **MUT-12（v4 / 同上）** | 凍結ベースライン blob の**取得失敗を「shrink-only 検証 PASS」**に倒す | **TC-32, TC-33** |
| **MUT-13（v4 / 同語反復への逆戻り）** | 凍結リスト参照をやめ、**台帳の `legacy` 行自身から凍結集合を導く** | **TC-27**（許可集合が自己言及になれば TC-27 が通ってしまう＝ kill されること） |
| **MUT-14（v4 / 単調安全性）** | 単調検査を削除し、**環境差で verdict が OK 側へ動く**のを許す | **TC-34** |

各変異は **sandbox 内で適用**し、対象 TC が **FAIL する**ことを実測して
`evidence/mutation-kill.txt` に記録する。**1 つでも kill されない TC は空振り**として作り直す。

> **MUT-6' は v1 に欠けていた「probe / 判定の品質そのものを殺す変異」**である。
> MUT-1〜5 / 8 / 9 が検出器の call site を壊すのに対し、MUT-6' は**判定対象の実態**を壊す。
> v3 では対象が **fixture** になり、**実 script 全数に対する MUT-6 は #1114 へ移設**した
> （対象が `adopted` になって初めて成立するため）。

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
| **E-11（新規 / U-6）** | `contract` の値が `adopted` / `legacy` 以外（誤記・空） | **`undecidable`**（未知値を安全側に倒す。緑にしない） |
| **E-12（新規 / U-6）** | `contract=legacy` かつ `defer` も付いている | **`unmigrated` が優先**（二重の免除を重ねない。`defer` は `adopted` 行にのみ意味を持つ） |
| **E-13（新規 / v4）** | issue state の応答が **OPEN・CLOSED のいずれとも解釈できない**（API 変更 / 予期しない JSON / 空応答） | **`undecidable`**（不明を OPEN に丸めない / §3-quater） |
| **E-14（新規 / v4）** | 凍結リストに **台帳に存在しない script 名**がある / **重複行**がある | **`undecidable`** + 明示エラー（凍結リスト自体の破損を緑にしない） |
| **E-08** | script 名に**空白**を含む | TSV 列破損 → **`undecidable`** + 明示エラー |
| **E-09（新規）** | script が **rc=10 だが stdout に何も出さない** | **`pending`**（stdout に依存しない / R-003） |
| **E-10（新規）** | script が **rc=0 だが diff を大量に印字** | **`applied`**（印字は判定に影響しない / R-003） |

## 自動化可否

| TC | 自動化 |
|----|-------|
| TC-01〜TC-09, TC-11〜TC-34, E-01〜E-14, MUT-1〜MUT-14 | **自動**（`ta-67-release-prep-pending.sh`） |
| **TC-10** | **半自動**（判定は自動だが**実機 2 環境での実走は Human / 別セッション**。evidence に verdict 添付） |

## sandbox コスト方針（R-010）

- 複製対象は **`scripts/` + `tests/` + `bin/` + `.claude/`**（`docs/` = **18M** を除外）
- **1 回複製して使い回す**（TC ごとに再複製しない）
- `.github/workflows/test.yml` の job は `timeout-minutes: 10`。
  超過が判明したら **MUT-6' を別 job / 手動実行へ退避**し、退避したことを handoff に明記する
- **v3 でコストは下がる**: 変異対象が実 script 全数（`scope=release` 分）から **fixture** に減ったため
  （実 script 全数の変異コストは #1114 が負う）

## 検出器が CI で走らないことの明示（U-5 / 持ち越し）

- `grep -rn "release-prep" .github/` → **0 件**。**`scripts/release-prep.sh` はどの workflow からも呼ばれない**
- したがって本 test-cases のうち **CI で自動的に回るのは `ta-67-*` 経由の分のみ**であり、
  **`release-prep.sh --check` 全体は Human が手で走らせたときにだけ効く**
- `.github/workflows/*` は **HO のため AI は配線できない**（実測 rc=2）。配線は Human（H-5）
- **この状態は意図的**（C-3 2026-08-18 で「未決のまま持ち越し」と裁定）。
  `ta-67` の TC が「CI 上で検出器が走る」ことを前提にした assert を持たないこと
