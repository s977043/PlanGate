---
task_id: TASK-1101
artifact_type: review-self
schema_version: 1
status: draft
verdict: FAIL
created_by: c1-self-review
---

# TASK-1101 セルフレビュー結果（C-1）

> レビュー日: 2026-08-15
> レビュー対象: `pbi-input.md` / `plan.md`（**`todo.md` / `test-cases.md` は未生成**）
> 実測基準: `main` = `dfaeebb`（`docs(hooks): EH-3 の HO 注記を退役し…（#1100）`）
> 判定: **FAIL** — FAIL=11, WARN=3, PASS=3

## サマリー

| result | 件数 |
|--------|------|
| PASS | 3 |
| WARN | 3 |
| FAIL | 11 |
| 合計 | 17 |

### 前提（重要 / 隠さず明示する）

`docs/working/TASK-1101/` には **`plan.md` のみが存在**し、**`todo.md` と `test-cases.md` は未生成**である。
本 PBI は Phase B の 3 成果物（plan / todo / test-cases）を**同時生成**する契約（`.claude/rules/working-context.md` §todo.md / §test-cases.md）であり、
C-1 17 項目のうち **ToDo チェック 5 項目（C1-TODO-08〜12）と TestCases チェック 3 項目（C1-TEST-13〜15）は
「対象成果物が存在しない」ため N/A ではなく FAIL** とする（判定対象が欠落している ＝ ゲートを通せない状態）。

```
$ ls docs/working/TASK-1101/todo.md docs/working/TASK-1101/test-cases.md
ls: docs/working/TASK-1101/test-cases.md: No such file or directory
ls: docs/working/TASK-1101/todo.md: No such file or directory
rc=1
```

### evidence の扱い（レビュー実施上の制約）

`.claude/rules/working-context.md` の evidence 保管ルールでは **FAIL 判定に evidence 必須**である。
本レビューは委譲時の行動規範により **`review-self.md` の新規作成のみ**が許可されているため、
`evidence/c1-review/` にファイルを作らず、**実行コマンド・出力・exit code を本ファイル内にインラインで記録**する（§実行した検証コマンド）。
`docs/working/TASK-1101/evidence/` は現在**空**である。evidence をファイルとして分離する必要がある場合は、
本ファイルの §実行した検証コマンド をそのまま `evidence/c1-review/` へ写せば足りる。

---

## Plan チェック（7項目）

### C1-PLAN-01: 受入基準網羅性

- **result**: WARN
- **category**: plan
- **finding**: AC-1〜AC-5 / AC-7 は Work Breakdown の Step に対応するが、**AC-6（`sh tests/run-tests.sh` が rc=0 / baseline を着手時に現 main で再測定）に対応する Step・Output が無い**。`## Testing Strategy > Verification Automation` に文章として現れるだけで、**誰がいつ baseline を測るか**が Work Breakdown 上に存在しない。「絶対件数を契約値にしない」という但し書きがあるぶん、測定タイミングが未定義だと AC-6 は事後に「通ったことにする」判定になりやすい。
- **AC ↔ Step 対応表（本レビューで作成・plan には無い）**:

  | AC | 内容 | 対応 Step | 判定 |
  |----|------|----------|------|
  | AC-1 | 4 ケースで HO block | Step 1 / Step 2 | ✅ |
  | AC-2 | TC-07 を fixed 期待へ反転・戻すと RED | Step 3 | ✅ |
  | AC-3 | 偽陽性なし（TC-06 10 件） | Step 1 🚩 / Testing Integration | ⚠️（下記 C1-PLAN-04 参照） |
  | AC-4 | 4 シェル同一挙動 | Step 5 | ❌（C1-PLAN-07 参照。検証手段が成立しない） |
  | AC-5 | 変異注入 3 種で対応 TC が FAIL | Step 4 | ✅ |
  | AC-6 | `sh tests/run-tests.sh` rc=0 / baseline 再測定 | **なし** | ❌ |
  | AC-7 | `hook-enforcement.md` の残存記述更新 | Step 7 | ✅ |

- **suggested_action**: AC-6 を担う Step（着手時 baseline 測定 + 完了時 full run）を Work Breakdown に追加し、AC ↔ Step 対応表を plan 本体に載せる。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド（plan.md L59-118 / L140-145 の実読）
- **impacted_files**: `docs/working/TASK-1101/plan.md`

### C1-PLAN-02: Unknowns処理

- **result**: PASS
- **category**: plan
- **finding**: `## Questions / Unknowns` の 3 件すべてに解決手段が紐づいている — (1) `../foo` が repo root を超える場合の扱いは **C-3 で確認**（C-1 時点で未決なのは正しい。承認境界の意味論変更は Human 判断）、(2) マルチバイト環境の `tr` は Step 5 で実測し問題時は `case` 側吸収へ切替、(3) 性能不足時は「`..` を含むパスは無条件 block」へ単純化する代替案を Step 6 の結果次第で C-3 に再提案。**未決のまま exec に流れる項目がない**。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-03: スコープ制御

- **result**: **FAIL**
- **category**: plan
- **finding**: **`_norm_target` は HO 判定専用の変数ではない。** `scripts/hooks/check-plan-hash.sh` 内で計 17 箇所参照され、HO 判定（L95-105）以外に**少なくとも 4 つの下流経路**がこの値を消費している:

  | 下流経路 | 位置 | plan の正規化強化で起きる変化 |
  |---|---|---|
  | maintenance token の scope 照合 | L207 `NORM_TARGET=` → L225 `fnmatch.fnmatchcase(norm_target, pat)` | **`fnmatchcase` は大小文字を区別する。** (g) 小文字化を `_norm_target` に施すと、`allowed_paths` に大文字を含むパターン（例 `CLAUDE.md` / `AGENTS.md` / `docs/AGENTS.md`）を持つ **既存の Human 発行 maintenance token が `OUT_OF_SCOPE` に転じて効かなくなる**。(f) `..` 畳み込みも同様に照合結果を変える |
  | doc-light 自動 SKIP | L193 `_dl_ext=$(… \| sed 's/.*\.//' …)` | 末尾空白除去・`..` 畳み込みで拡張子抽出結果が変わり、**`"foo.md "` が SKIP 側に倒れる**（現状は拡張子 `md ` として不一致）。挙動変化が Non-goals に無い |
  | 監査ログ / skip-decision-log の `target` | L177-179, L198-200, L273 | 記録される target が **AI/ツールが実際に指定したパスではなく正規化後の値**になる。監査証跡と実操作の突合が崩れる（`..` を使った試行の痕跡が消える） |
  | TASK 文脈側の `case` 分岐 | L152 | plan では触れていないが同じ値を見ている |

  plan の `## Files / Components to Touch` は「正規化関数の追加 + `case` の小文字化」としか書かれておらず、**`## Constraints / Non-goals` にもこの波及が現れていない**。「HO 判定の入力だけを強くする」つもりの変更が、**maintenance 承認経路（Human-owned トークン）と監査証跡を同時に変える**構図になっている。承認境界そのものを扱う PBI で、承認トークンの scope 判定を巻き添えにするのは許容できない。
- **suggested_action**: **HO 判定専用の正規化変数を新設**し（例 `_ho_target`）、`_norm_target` は現状のまま下流へ渡す。どうしても `_norm_target` 自体を強化するなら、(a) maintenance `allowed_paths` 照合を大小文字非依存にする是正、(b) 監査ログには**正規化前の生パスも併記**、(c) doc-light 判定の期待挙動、の 3 点を plan の In scope と AC に明示する。いずれの案でも **Non-goals / Files 表 / AC を更新**する。
- **owner**: agent（設計変更を伴うため C-3 論点として提示）
- **evidence_ref**: 本ファイル §実行した検証コマンド [E2] [E3]
- **impacted_files**: `scripts/hooks/check-plan-hash.sh`, `docs/working/TASK-1101/plan.md`

### C1-PLAN-04: テスト戦略

- **result**: WARN
- **category**: plan
- **finding**: 2 点の穴がある。
  1. **「正規化関数を単体で呼ぶ」経路が定義されていない。** plan は `_pg_norm_path()` を `check-plan-hash.sh` 内に置くとしており（Step 1 Output）、Testing Strategy の Unit は「関数を単体で呼び、入力→期待出力の対応表で検証」としているが、hook は `sh scripts/hooks/check-plan-hash.sh` として**プロセス実行**される設計で、関数だけを取り出す seam（`.` で source できる構造 / `PG_NORM_SELFTEST=1` のような入口）が無い。Step 1 の 🚩「本体に組み込む前に関数単体で確認」も同じ理由で手段が未定義。
  2. **AC-3 の偽陽性表明が (g) 小文字化に対して無力。** TC-06 の 10 件は `.claude/rules/x.txt` / `scripts/hooks/x.py` / `bin/other` / `docs/AGENTS.md` / `docs/working/TASK-T65/CLAUDE.md.bak` 等で、**大文字を含むのは `docs/AGENTS.md` と `…/CLAUDE.md.bak` の 2 件のみ**、しかもどちらも前置パスがあるため小文字化しても HO パターンに当たらない。つまり **小文字化が過剰に効いた場合の偽陽性（例 `bin/PLANGATE` / `Schemas/x.schema.json`）を検出するケースが存在しない**。pbi-input の「AC-3 で必ず実測確認する」は、現行 TC-06 の集合では実測にならない。
- **suggested_action**: (1) 正規化関数を単体呼び出しできる seam を Step 1 の Output に明記（source 可能な構造 or 自己テスト入口）。(2) TC-06 に大小文字の偽陽性ケースを追加することを Step 3 の Output に含める。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E4]（ta-65 の hook 起動形態）/ `tests/extras/ta-65-eh3-ho-task-context.sh` L305-315（TC-06 の 10 件）
- **impacted_files**: `docs/working/TASK-1101/plan.md`, `tests/extras/ta-65-eh3-ho-task-context.sh`

### C1-PLAN-05: Work Breakdown Output

- **result**: PASS
- **category**: plan
- **finding**: Step 1〜7 のすべてに **Output / Owner / Risk / 🚩チェックポイント / `rollback:`** が揃っている。Output は成果物名まで具体（`scripts/apply-1101-ho-normalization.sh` / `evidence/test-runs/` の変異記録 等）で、「〜を検討する」で終わる Step が無い。検証のみの Step には `rollback: 不要` が明記されており、`.claude/rules/working-context.md` の rollback 記載規約と整合する。
- **evidence_ref**: —
- **impacted_files**: []

### C1-PLAN-06: 依存関係

- **result**: **FAIL**
- **category**: plan
- **finding**: **Step 4 / 5 / 6 は「patch が適用された `check-plan-hash.sh`」がないと実行できないが、適用は Human-owned であり、その適用手段（Step 7 の apply スクリプト）は Step 4〜6 より後に作られる。** 依存が逆行している。
  加えて `ta-65` は検証対象を **repo 本体から sandbox へ cp する**構造（`_T65_HOOK_SRC="$_T65_ROOT/scripts/hooks/check-plan-hash.sh"` → `cp "$_T65_HOOK_SRC" "$_T65_TMP/…"`）であり、**repo 本体が未適用の間は Step 3 🚩（TC-07 が FAIL することの確認）以外の実測が成立しない**。plan には「AI が未適用の状態でどう Step 4〜6 を回すか」の記述が無く、このままでは exec が Step 3 で Human 待ちに入り、Step 4〜6 の 🚩（「1 つでも割れたら実装をやり直す」）が**適用後にしか発火しない** ＝ 実装やり直しコストが Human 適用の後ろに来る。
- **suggested_action**: (a) Step 7 の apply スクリプト作成を Step 4 より**前**に移す、または (b) ta-65 に「検証対象 hook のパスを差し替える seam」（例 `PG_T65_HOOK_SRC`）を追加し、AI が patch 適用済みコピーに対して Step 4〜6 を回せるようにする。いずれかを Work Breakdown の順序として明記し、**Human 適用ゲートを Step として可視化**する。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E4] / `tests/extras/ta-65-eh3-ho-task-context.sh` L55-80
- **impacted_files**: `docs/working/TASK-1101/plan.md`, `tests/extras/ta-65-eh3-ho-task-context.sh`

### C1-PLAN-07: 動作検証自動化

- **result**: **FAIL**
- **category**: plan
- **finding**: **AC-4（`sh` / `dash` / `bash` / `zsh` の 4 シェルで同一挙動）を Step 5 の方法では検証できない。** Step 5 の Output は「4 シェルで `ta-65` を実行した記録」だが、`ta-65` の hook 起動ヘルパは**シェルを `sh` に固定**している:

  ```
  tests/extras/ta-65-eh3-ho-task-context.sh:66:    sh "$_T65_HOOK" </dev/null 2>&1
  tests/extras/ta-65-eh3-ho-task-context.sh:215:    | PLANGATE_HOOK_TASK="$_T65_TASK" sh "$_T65_HOOK" 2>&1) || _t65_rc=$?
  ```

  harness 自体を `dash tests/…` や `zsh tests/…` で起動しても、**被検査対象である hook は常に `sh` で実行される**。したがって Step 5 は「4 シェルで同じ結果が出た」という記録を作れてしまうが、それは **hook の可搬性ではなく harness の可搬性**しか測っていない。`..` 畳み込み（パラメータ展開ループ）と `tr` はまさにシェル差が出る箇所であり、**AC-4 が false green になる**。同じ穴は Risks 表の「マルチバイト環境で `tr` が想定外の動作 → Step 5 に `LANG=ja_JP.UTF-8` ケースを含める」にも波及する（`sh` 固定のままでは locale 差は測れても shell 差は測れない）。
  なお Step 4（変異注入）の 🚩 は「call site ではなく関数内の各正規化ステップを 1 つずつ壊す」と #874 の教訓を正しく織り込んでおり、この点は妥当。
- **suggested_action**: `ta-65` に hook 起動シェルを差し替える seam（例 `PG_T65_SHELL=${PG_T65_SHELL:-sh}`）を追加し、Step 5 の Output を「**hook を 4 シェルで起動**した記録」に書き換える。seam 追加は `tests/extras/` = HO 対象外なので AI が実施可能。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E4]
- **impacted_files**: `docs/working/TASK-1101/plan.md`, `tests/extras/ta-65-eh3-ho-task-context.sh`

---

## ToDo チェック（5項目）

> **対象ファイル `docs/working/TASK-1101/todo.md` が存在しない。** 以下 5 項目はすべて
> 「判定対象の欠落」による **FAIL**（N/A ではない）。`.claude/rules/working-context.md` は
> todo.md を Phase B の必須成果物と定めており、plan.md のみでは C-1 を通過できない。
> 共通 evidence: 本ファイル §実行した検証コマンド [E1]（`ls` rc=1）。

### C1-TODO-08: タスク粒度

- **result**: **FAIL**
- **category**: todo
- **finding**: `todo.md` 未生成のため判定不能。plan の Step 1〜7 は「粒度 2〜5 分」の単位より大きく（例: Step 1 = 正規化関数の実装全体）、**そのまま ToDo に転記しても粒度基準を満たさない**見込み。
- **suggested_action**: Step 1〜7 を 🤖 Agent タスク（準備 → 実装 → 検証 → 完了）へ分解して `todo.md` を生成する。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E1]
- **impacted_files**: `docs/working/TASK-1101/todo.md`

### C1-TODO-09: depends_on設定

- **result**: **FAIL**
- **category**: todo
- **finding**: `todo.md` 未生成のため判定不能。加えて **C1-PLAN-06 で検出した依存の逆行（Step 4〜6 が Human 適用に先行している）を未解決のまま転記すると、todo.md の `depends_on` も同じ矛盾を引き継ぐ**。
- **suggested_action**: C1-PLAN-06 の是正を plan に反映してから todo.md を生成する。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E1]
- **impacted_files**: `docs/working/TASK-1101/todo.md`

### C1-TODO-10: チェックポイント設定

- **result**: **FAIL**
- **category**: todo
- **finding**: `todo.md` 未生成のため判定不能。plan 側には Step ごとに 🚩 が置かれており、転記元としては十分。
- **suggested_action**: plan の 🚩 を todo.md の該当タスクへ写す。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E1]
- **impacted_files**: `docs/working/TASK-1101/todo.md`

### C1-TODO-11: Iron Law遵守

- **result**: **FAIL**
- **category**: todo
- **finding**: `todo.md` 未生成のため判定不能。**ただし plan 側の設計は Iron Law と整合している** — Step 7 の 🚩 が「AI は `--dry-run` のみ実行する（`--apply` を AI が走らせない）」と明記し、HO 対象パスの適用を Human-owned に固定している。todo.md 生成時にこの制約を 👤 Human タスクとして分離することが必須。
- **suggested_action**: 「Human が `sh scripts/apply-1101-ho-normalization.sh --apply` を実行」を 👤 Human タスクとして todo.md に明記する。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E1]
- **impacted_files**: `docs/working/TASK-1101/todo.md`

### C1-TODO-12: 完了条件

- **result**: **FAIL**
- **category**: todo
- **finding**: `todo.md` 未生成のため判定不能。plan の Output は具体的だが、**AC-6 に対応する完了条件（full test run）が plan に無い**ため（C1-PLAN-01）、todo.md にも欠落が伝播する。
- **suggested_action**: 各タスクに完了条件を記述し、AC-6 を担うタスクを追加する。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E1]
- **impacted_files**: `docs/working/TASK-1101/todo.md`

---

## テストケースチェック（3項目）

> **対象ファイル `docs/working/TASK-1101/test-cases.md` が存在しない。** 以下 3 項目はすべて
> 「判定対象の欠落」による **FAIL**。共通 evidence: §実行した検証コマンド [E1]。

### C1-TEST-13: 受入基準→テストケース網羅性

- **result**: **FAIL**
- **category**: test
- **finding**: `test-cases.md` 未生成のため、AC-1〜AC-7 → TC のマッピングが存在しない。plan の Testing Strategy は方針レベルの記述にとどまり、**AC-6 に対応する TC が想定されていない**（C1-PLAN-01）ほか、AC-4 は現行 ta-65 の構造では TC を書いても成立しない（C1-PLAN-07）。
- **suggested_action**: AC-1〜AC-7 の 7 件すべてに TC を割り当てた `test-cases.md` を生成する。既存 `ta-65` TC-06 / TC-07 との対応関係も明記する。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E1]
- **impacted_files**: `docs/working/TASK-1101/test-cases.md`

### C1-TEST-14: テストケースの具体性

- **result**: **FAIL**
- **category**: test
- **finding**: `test-cases.md` 未生成のため判定不能。**入力の候補は plan / pbi-input に揃っている**（`docs/../CLAUDE.md` / `CLAUDE.MD` / `"CLAUDE.md "` / `bin/../bin/plangate` と期待 rc=2、TC-06 の 10 件と期待「HARDENING_OVERRIDE を出さない」）ため、値レベルの記述は十分に可能。
- **suggested_action**: 入力パス・期待 rc・期待出力文字列（`HARDENING_OVERRIDE` の有無）を値で記述する。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E1]
- **impacted_files**: `docs/working/TASK-1101/test-cases.md`

### C1-TEST-15: エッジケースの考慮

- **result**: **FAIL**
- **category**: test
- **finding**: `test-cases.md` 未生成のため判定不能。**plan の Testing Strategy > Unit には境界の列挙がある**（空文字列 / `/` のみ / `../foo`（repo root 超え）/ `..` のみ）ため、転記すれば網羅性は確保しやすい。ただし **(g) 小文字化の偽陽性ケース（大文字を含む非 HO パス）** と **maintenance token scope への影響ケース**（C1-PLAN-03）が現状の列挙に無く、追加が必要。
- **suggested_action**: 上記 2 クラスのエッジケースを追加した上で `test-cases.md` を生成する。
- **owner**: agent
- **evidence_ref**: 本ファイル §実行した検証コマンド [E1]
- **impacted_files**: `docs/working/TASK-1101/test-cases.md`

---

## B-1/B-2 チェック（2項目）

### C1-B1B2-16: B-1確認質問

- **result**: WARN
- **category**: plan
- **finding**: **B-1（PBI INPUT の曖昧箇所を確認質問で解消したフェーズ）の記録が package 内に無い。** `pbi-input.md` の `## Notes from Refinement` は refinement 時点の事前整理であり、plan 生成時の確認質問と応答ではない。結果として、承認境界の意味論に関わる論点（`../foo` が repo root を超える場合の扱い＝ **repo 外は EH-3 の管轄外でよいか**）が **B-1 で解消されず C-3 へ持ち越されている**。持ち越し自体は Human 判断事項として妥当だが、「B-1 で確認を試みた／曖昧さが無いことを確認した」という記録が無いため WARN。
- **suggested_action**: plan に「B-1 確認質問と回答」節、または「PBI INPUT に曖昧さなし・未決 1 件を C-3 論点へ送る」旨を明記する。
- **owner**: agent
- **evidence_ref**: —
- **impacted_files**: `docs/working/TASK-1101/plan.md`

### C1-B1B2-17: B-2アプローチ比較

- **result**: PASS
- **category**: plan
- **finding**: 3 方式が比較され、選定理由が明記されている（`pbi-input.md` §実装方針の候補と評価 / `plan.md` §Constraints・§Approach Overview）— `realpath` / `readlink -f` は **GNU/BSD 差と macOS 標準に `-f` が無い**こと、および**シンボリックリンクを解決して意味論が変わる**ことを理由に不採用、**純 sh の字句的 `..` 畳み込み**を採用（外部コマンド非依存 / 意味論保存 / 「畳み込んで HO に当たれば block」＝安全側）、`case` パターン小文字化は採用方式に伴う必須変更として位置づけ。**なぜシンボリックリンクを解決しないかを Non-goals に明示**している点も含め、比較と選定理由は十分。
- **evidence_ref**: —
- **impacted_files**: []

---

## 参考: テンプレート追加項目（17 項目の外 / `docs/working/templates/review-self.md` 由来）

> 総合判定の 17 件には算入しない。plan 改訂時の参考として記録する。

| check_id | result | 要点 |
|---|---|---|
| C1-PLAN-08-AEE: Stop Condition | WARN | plan に `Stop Condition` 節が無い。EH-3 は全 Edit/Write の前段であり「hook が壊れたら即停止」は明示に値する |
| C1-PLAN-09-AEE: Replan Triggers（機械値） | WARN | 機械値の Replan Trigger が無い。Step 6 の「遅ければ方式変更」は閾値が未定義（例: 典型パスで +Nms 超なら replan） |
| C1-SUP-PLAN-01: No Placeholders | WARN | 関数名が `_pg_norm_path()`（仮）のまま。Step 6 の「体感で変わらないこと」は測定基準として非具体 |
| C1-SUP-PLAN-02: Task Sizing | PASS | Step 単位で Output / 検証手段 / rollback が揃い、Step 単位の approve/reject が可能 |
| C1-TODO-RB: rollback | FAIL | `todo.md` 未生成。ただし **plan 側は Step 1〜7 すべてに `rollback:` を記載済み**（high-risk 要件を満たす転記元はある） |
| C1-SEC-01: 秘密情報 非接触 | N/A | `.env` / トークン / 個人パスに触れない。maintenance token は既存機構であり本 PBI で新規に扱わない（ただし C1-PLAN-03 の波及は要確認） |
| C1-SCOPE-DISC-01: 発見事項の予防的分離 | WARN | 実装中の scope 外発見の扱い（別 Issue へ分離）が plan に明記されていない。#1089 → #1101 の分離実績があるので方針化は容易 |
| C1-UI-01: UI デザインシステム準拠 | N/A | non-UI |

---

## Mode 判定の妥当性（補足確認）

plan の `high-risk` / `lite_eligible=false` 判定は正本と整合する。

- `scripts/hooks/check-plan-hash.sh` は `.claude/rules/mode-classification.md` の Hardening Override 対象 9 カテゴリの 1 つ（`scripts/hooks/*.sh`）→ **「承認境界周辺の変更 → 最低『高』」** が適用される
- 同ルールにより **`lite_eligible=false` 強制 + Standard・同期 C-3 固定**、`.claude/rules/working-context.md` の **autonomous APPROVE 不可**（HO 対象パスを含む変更）
- 受入基準 7 件は定量基準で high-risk 帯
- **結論: `high-risk` 妥当。C-3 は Human 同期必須**

## plan の事実記述の裏取り（実測）

plan / pbi-input が引用する現状記述は、`main` = `dfaeebb` の実体と一致することを確認した。

| plan / pbi-input の記述 | 実測 | 判定 |
|---|---|---|
| `_norm_target` の正規化は 2 つだけ（先頭 `./` / repo root） | `scripts/hooks/check-plan-hash.sh` L85-91 が該当。一致 | ✅ |
| HO の `case` で大文字を含むのは `AGENTS.md\|CLAUDE.md` のみ（他 8 カテゴリは小文字） | L95-105 を実測。大文字を含む行は L104 の 1 行のみ | ✅ |
| `ta-65` TC-07 が 4 ケースを KNOWN-GAP として固定 | `tests/extras/ta-65-eh3-ho-task-context.sh` L338-356。対象 4 パスも一致 | ✅ |
| TC-06 は非 HO 近傍 10 件の偽陽性否定表明 | 同 L299-336。10 件を実測 | ✅ |
| `docs/ai/hook-enforcement.md` に「既知の残存」記述あり | L147-151 に該当記述を確認 | ✅ |

## 実行した検証コマンド（インライン evidence）

すべて `/Users/user/Documents/GitHub/plangate`（`main` = `dfaeebb`）で実行。**読み取りのみ**。

```
[E1] $ ls docs/working/TASK-1101/todo.md docs/working/TASK-1101/test-cases.md
     ls: docs/working/TASK-1101/test-cases.md: No such file or directory
     ls: docs/working/TASK-1101/todo.md: No such file or directory
     rc=1

[E2] $ grep -n '_norm_target\|NORM_TARGET' scripts/hooks/check-plan-hash.sh | wc -l
     17
     rc=0

[E3] $ grep -n 'fnmatchcase' scripts/hooks/check-plan-hash.sh
     225:        matched = any(fnmatch.fnmatchcase(norm_target, pat) for pat in allowed)
     rc=0

[E4] $ grep -n 'sh "\$_T65_HOOK"' tests/extras/ta-65-eh3-ho-task-context.sh
     66:    sh "$_T65_HOOK" </dev/null 2>&1
     215:    | PLANGATE_HOOK_TASK="$_T65_TASK" sh "$_T65_HOOK" 2>&1) || _t65_rc=$?
     rc=0

[E5] $ sed -n '95,105p' scripts/hooks/check-plan-hash.sh | grep -n '[A-Z]'
     10:  AGENTS.md|CLAUDE.md) _override=1 ;;
     rc=0

[E6] $ git rev-parse --abbrev-ref HEAD && git log --oneline -1
     main
     dfaeebb docs(hooks): EH-3 の HO 注記を退役し、no-task 経路の正規手順を明文化（#1095 / #1089） (#1100)
     rc=0
```

未実行（本レビューの範囲外）: `sh tests/run-tests.sh`（AC-6 の baseline 測定は exec 着手時に行う。C-1 は plan の書面レビュー）。

## 総合判定

**FAIL**（FAIL=11 / WARN=3 / PASS=3）

### FAIL の内訳と性質

| 分類 | 件数 | 内容 |
|---|---|---|
| 成果物欠落 | 8 | `todo.md` 未生成（C1-TODO-08〜12）/ `test-cases.md` 未生成（C1-TEST-13〜15） |
| plan 内容の欠陥 | 3 | C1-PLAN-03（`_norm_target` 下流への波及が未申告）/ C1-PLAN-06（Human 適用ゲートと Step 4〜6 の依存が逆行）/ C1-PLAN-07（AC-4 の検証手段が hook のシェルを固定しており false green になる） |

### C-3 へ進む前に必要な対応

1. **`todo.md` / `test-cases.md` を生成する**（Phase B の必須成果物。plan のみでは C-1 を通過できない）
2. **C1-PLAN-03 の是正**（HO 判定専用の正規化変数を分離する / または maintenance scope 照合・監査ログ・doc-light への影響を In scope と AC に明示する）— **本 PBI で最も重い指摘**。承認境界を強化する変更が、別の承認経路（Human 発行 maintenance token）を巻き添えにしうる
3. **C1-PLAN-07 の是正**（`ta-65` に hook 起動シェルの seam を追加し、AC-4 を実測可能にする）— 放置すると **AC-4 が緑のまま穴が残る**
4. **C1-PLAN-06 の是正**（apply スクリプトを Step 4 より前に出す、または検証対象 hook を差し替える seam を追加し、Human 適用ゲートを Step として可視化）
5. **C1-PLAN-01 の是正**（AC-6 を担う Step の追加 + AC ↔ Step 対応表の plan 本体への掲載）

### C-3 に上げる論点（Human 判断）

| # | 論点 | 由来 |
|---|------|------|
| U-1 | `..` が repo root を超える場合（`../foo`）を「EH-3 の管轄外」として skip し続けてよいか | plan Questions 1 |
| U-2 | `_norm_target` の小文字化を **HO 判定限定にするか、hook 全体に適用するか**。後者なら maintenance token の `allowed_paths` 照合を大小文字非依存に変える是正が同時に必要 | **C1-PLAN-03（本レビュー新規）** |
| U-3 | 監査ログに記録する target を正規化前／後のどちらにするか（`..` を使った試行の痕跡を残すか） | **C1-PLAN-03（本レビュー新規）** |
| U-4 | 性能が許容外だった場合の代替案（`..` を含むパスは無条件 block）を採るか | plan Questions 3 |

> **Mode = `high-risk`、HO 対象パスを含むため autonomous APPROVE 不可。C-3 は Human 同期必須。**

## 自動修正ログ

| check_id | 修正内容 | 修正先ファイル |
|----------|---------|--------------|
| — | **自動修正なし**（`plan.md` は C-3 承認前の改変を EH-3 が block するため、本レビューは指摘のみ。本レビューでの変更は本ファイルの新規作成のみ） | — |
