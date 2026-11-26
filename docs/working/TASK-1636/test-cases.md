# TASK-1636 TEST CASES

全ケースは一時ディレクトリの fixture で実行する。`setUp` の root は `os.path.realpath` で正規化するので、TMPDIR の配置に結果が左右されない。symlink の祖先は各ケースが明示的に作る。

**共通の検証コマンド**: `sh tests/run-tests.sh`（CI 経路）。個別確認は `python3 tests/test_installer_ownership.py -v`（CI との差は単体実行であること）。

**RED 列**: `e683fd4d` の installer に対する期待。**FAIL** はこの是正で結果が変わるケース。**PASS** は是正で壊さないことの固定（変更前でも満たすので、対応する変異で FAIL することを検出力の根拠にする）。

## 受入基準 → テストケース マッピング

| 受入基準 | テストケース | 備考 |
| --- | --- | --- |
| AC-01: symlink 祖先 / target 自身 | TC-01, TC-02, TC-E01 | 両 OS で明示的に作る |
| AC-02: root より下の symlink | TC-03, TC-04, TC-05 | symlink の root と組み合わせる |
| AC-03: 表記と向け替え | TC-06, TC-07 | |
| AC-04: 解決できない symlink | TC-08, TC-09 | |
| AC-05: v1 のみの導入 | TC-10, TC-11, TC-12, TC-E02 | |
| AC-06: v1 を根拠にしない / 移行 | TC-13, TC-14, TC-22 | |
| AC-07: 結果表示と案内 | TC-15, TC-23, TC-24 | |
| AC-08: テストの弱さ | TC-16, TC-17, TC-18 | |
| AC-09: 残存脅威の明記 | TC-19 | |
| AC-10: 検出力 | TC-20, TC-21 | |

## Verification Trace

| Trace Type | Trace ID / 内容 | Source / Evidence | テストケース |
| --- | --- | --- | --- |
| AC | AC-01〜AC-10 | `pbi-input.md` | 上表 |
| Invariant | INV-01: 解決後の root より下の symlink を経由して書かず消さない | `install.sh:134-142,160,221,262`（既存実装） | TC-03, TC-04, TC-05 |
| Invariant | INV-02: v1 manifest を所有の根拠にしない。内容も読まない | issue #1636 AC / `install.sh:100-101` | TC-13, TC-E02 |
| Invariant | INV-03: 止めるときは 1 ファイルも書かない | `install.sh:208`（dry-run の既存方針）、AC-05 | TC-09, TC-12 |
| Regression | REG-01: major-1 | PR #1639 コメント / `plan.md` P-01〜03 | TC-01, TC-02 |
| Regression | REG-02: major-2 | PR #1639 コメント / P-05, P-06 | TC-10, TC-11 |
| Conditional | CR-01: Security（dangling の追従） | `plan.md` P-08 | TC-08 |
| Regression | R-001: 印字コマンドが auto モードで効かない | `review-external.md` | TC-15 |
| Regression | R-002: 更新 0 件でも完了と出る | `review-external.md` | TC-24 |
| Regression | R-003: 移行手順をたどれない | `review-external.md` | TC-14, TC-22 |
| Conditional | H-10: 案内の出力エラーが書き込み後に rc=1 にする | `plan.md` P-18 | TC-23 |

## テストケース一覧

### TC-01: symlink の祖先を持つ target に導入し撤去する

- 対応 AC: AC-01 / Trace ID: REG-01 / 種別: integration / RED: **FAIL**
- 前提条件: `<root>/real/` と `<root>/link -> real`
- 入力: `--claude --target <root>/link/proj`、続いて `--uninstall --target <root>/link/proj`
- 期待出力: 導入 rc=0。`<root>/real/proj/agents/new.md` が存在。撤去 rc=0 で削除。出力に `symlink in target path` を含まない
- 期待値の出所: 既存実装（`plan.md` P-02, P-12）

### TC-02: target 自身が symlink（dotfiles 型）

- 対応 AC: AC-01 / Trace ID: REG-01 / 種別: integration / RED: **FAIL**
- 前提条件: `<root>/dotfiles/claude/` と `<root>/dot -> dotfiles/claude`
- 入力: `--claude --target <root>/dot`
- 期待出力: rc=0。`<root>/dot` は symlink のまま。`<root>/dotfiles/claude/plangate-owned-v2.json` が存在
- 期待値の出所: 既存実装（P-03）

### TC-03: symlink の root + 配下の親 symlink への書き込み

- 対応 AC: AC-02 / Trace ID: INV-01 / 種別: integration / RED: FAIL（導入自体が拒否され `protected symlink` が出ない）
- 前提条件: `<root>/l -> C`、`C/agents -> <root>/out`
- 入力: `--claude --target <root>/l`
- 期待出力: rc=0。出力に `protected symlink: agents/new.md`。`<root>/out` は空
- 期待値の出所: 既存実装（試作の実測）

### TC-04: symlink の root + 配下の親 / ファイル symlink への削除

- 対応 AC: AC-02 / Trace ID: INV-01 / 種別: integration / RED: FAIL（導入が拒否される）
- 前提条件: symlink の root に導入後、(a) `agents` を外部へ rename し、`agents` をその移動先への symlink にする（inode と ctime が保たれ、`no_symlinks` だけが守る形。R-004）、(b) `agents/new.md` を外部ファイルへの symlink に置換
- 入力: `--uninstall --target <symlink root>`
- 期待出力: rc=0。`retained (modified or unsafe): agents/new.md`。(a) の移動先の `new.md` と (b) の外部ファイルの内容が不変
- 期待値の出所: 既存実装（`tests/test_installer_ownership.py:213-232` の期待を symlink の root へ拡張）

### TC-05: manifest が symlink

- 対応 AC: AC-02 / Trace ID: INV-01 / 種別: integration / RED: PASS（是正で壊さないことの固定。MU-5 で FAIL）
- 前提条件: `plangate-owned-v2.json -> <root>/outm.json`、内容は `{}`
- 入力: `--claude --target <dest>`
- 期待出力: rc=1。`symlink in manifest path`。`outm.json` が `{}` のまま
- 期待値の出所: 既存実装（試作の実測）

### TC-06: root の表記が違っても同じ記録を使う

- 対応 AC: AC-03 / Trace ID: AC-03 / 種別: integration / RED: FAIL
- 前提条件: `<root>/l -> real`。`l` 経由で導入
- 入力: 撤去 dry-run を実パス、相対（cwd=`<root>`, `l`）、`l/../real/`、末尾スラッシュの各表記で実行し、最後に実パスで撤去
- 期待出力: すべて rc=0 で同じ `WOULD DELETE` の集合。manifest のキーは全件 `agents/` などの相対で、`/` 始まりが 0 件
- 期待値の出所: 既存実装（P-12）

### TC-07: root を別ディレクトリのコピーへ向け替える

- 対応 AC: AC-03 / Trace ID: AC-03 / 種別: integration / RED: FAIL（導入が拒否される）
- 前提条件: `l -> A` で導入。`A` を manifest ごと `B` へ属性保持コピーし、`l -> B` に変更
- 入力: `--uninstall --target l`
- 期待出力: rc=0。`retained`。`B/agents/new.md` が存在
- 期待値の出所: 既存実装（P-13）

### TC-08: 解決できない symlink を拒否する

- 対応 AC: AC-04 / Trace ID: CR-01 / 種別: integration / RED: **FAIL**（文言が異なる。(c) は `abspath` が `..` を畳むので `<root>/y` を作る）
- 分類: 異常系
- 入力: target が (a) dangling、(b) `d/x`（途中が dangling）、(c) `d/../y`、(d) 循環
- 期待出力: すべて rc=1、`unresolved symlink in target path`。リンク先の `nowhere` と `<root>/y` が作られない
- 期待値の出所: 既存実装（P-14）

### TC-09: 拒否は dry-run と撤去でも同じ

- 対応 AC: AC-04 / Trace ID: INV-03 / 種別: integration / RED: PASS（MU-2 で FAIL）
- 入力: dangling の target へ `--claude --dry-run`、`--uninstall`
- 期待出力: どちらも rc=1。リンク先が作られない
- 期待値の出所: 既存実装（`fail()` の既存方針）

### TC-10: v1 のみ + `--force` で止まる

- 対応 AC: AC-05 / Trace ID: REG-02 / 種別: integration / RED: **FAIL**（現状 rc=0）
- 前提条件: `plangate-manifest.json` と `agents/new.md`（配布物と異なる内容）
- 入力: `--claude --force --target <dest>`
- 期待出力: rc=1。`legacy manifest found` と `docs/plangate-plugin-migration.md` を含む。ファイル内容が不変で v2 なし
- 期待値の出所: 既存実装（P-15）

### TC-11: v1 のみ + `--force` なし + 新しい配布ファイル

- 対応 AC: AC-05 / Trace ID: REG-02 / 種別: integration / RED: **FAIL**（現状 v2 を作る）
- 前提条件: TC-10 に加え、導入先にない配布ファイルがある
- 入力: `--claude --target <dest>`
- 期待出力: rc=1。v2 なし。新しい配布ファイルがコピーされない
- 期待値の出所: 既存実装（P-06, P-15）

### TC-12: v1 のみ + `--dry-run`、書き込みゼロ

- 対応 AC: AC-05 / Trace ID: INV-03 / 種別: integration / RED: **FAIL**（現状 rc=0）
- 入力: `--claude --force --dry-run` の前後で `snapshot()` を取る
- 期待出力: rc=1。`snapshot()` が前後で一致
- 期待値の出所: 既存実装（P-15）

### TC-13: v1 を根拠に削除しない（legacy テストの確定）

- 対応 AC: AC-06, AC-08 / Trace ID: INV-02 / 種別: integration / RED: **FAIL**（文言の案内）
- 前提条件: `test_legacy_manifest_followed_by_install_and_uninstall` と同じ fixture
- 入力: `--claude`、続いて `--uninstall`
- 期待出力: 導入 rc=1。撤去 rc=0 で `all files retained` と移行手順の参照を含む。ファイルと v1 manifest はバイト一致。if/else を持たない
- 期待値の出所: 既存実装、AC-06

### TC-14: 移行手順をたどる

- 対応 AC: AC-06 / Trace ID: AC-06 / 種別: integration / RED: **FAIL**
- 前提条件: v1 manifest に PlanGate のファイル `agents/new.md` と利用者のファイル `agents/existing.md` が載っている
- 前提条件（追加）: 配布元は tag `v<version>` を持つ使い捨ての git repo。`files` に利用者のファイルを含むディレクトリも載せる
- 入力: 文書の `git show ... | cmp -` で比較 → 一致した `new.md` だけを削除 → v1 を `.bak` へ改名 → `--claude --target <dest>` → `--uninstall --target <dest>`
- 期待出力: 比較で `existing.md` と、ディレクトリ内の利用者のファイルは一致しない。tag がないときは一致扱いにしない。導入 rc=0、`protected existing: agents/existing.md`。撤去後 `new.md` なし、`existing.md`、ディレクトリ内の利用者のファイル、`.bak` が残る
- 期待値の出所: 規約（`plan.md` の移行手順）。Convention Evidence を参照
- 備考: 手順の節が文書にあることは `grep -c "Migrating from a v1 manifest" docs/plangate-plugin-migration.md` が 1 以上で確認する

### TC-15: 導入後の案内

- 対応 AC: AC-07 / Trace ID: AC-07 / 種別: integration / RED: **FAIL**（呼び出し元がない）
- 前提条件: repo と target のパスに空白と `'` を含む。target は symlink 経由の相対パス
- 入力: (1) `PLANGATE_SETUP_HINT` 未設定で `--claude`、(2) `=0` で `--claude`、(3) 未設定で `--claude --dry-run`。(1) の出力の更新コマンドと撤去コマンドを、`.claude` のない別の cwd で `sh -c` により実行する
- 期待出力: (1) のみ `インストール完了` を表示。更新コマンドは `--claude --force --target` を含み、実行すると rc=0 で導入先が新しい内容になり、cwd に `.claude` を作らない。撤去コマンドは rc=0 で削除する。(2)、(3) は案内なしで summary あり
- 期待値の出所: `origin/main:install.sh`（案内の存在）、`plan.md` P-19（実行可能性）

### TC-22: 全件保持の移行

- 対応 AC: AC-06 / Trace ID: R-003 / 種別: integration / RED: FAIL（summary がない）
- 前提条件: v1 を `.bak` へ改名済み。`agents/` の全ファイルを利用者が残している（配布物と異なる内容）
- 入力: `--claude --force --target <dest>`、続いて `--uninstall --target <dest>`
- 期待出力: 導入 rc=0、`copied=0 updated=0`、案内なし、v2 なし。撤去 rc=0 で全ファイルが残る
- 期待値の出所: 既存実装（`plan.md` P-21）

### TC-23: ASCII の stdout

- 対応 AC: AC-07 / Trace ID: H-10 / 種別: integration / 分類: 異常系 / RED: PASS（案内がないため。MU-14 で FAIL）
- 入力: `PYTHONIOENCODING=ascii`、`PLANGATE_SETUP_HINT` 未設定で `--claude --target <dest>`
- 期待出力: rc=0。traceback なし。v2 に導入済みのファイルが記録されている
- 期待値の出所: 既存実装（`plan.md` P-18）

### TC-24: 変更がなければ完了案内を出さない

- 対応 AC: AC-07 / Trace ID: R-002 / 種別: integration / RED: FAIL（summary がない）
- 入力: (a) 導入済みに再度 `--claude`、(b) 全件編集後に `--claude --force`、(c) 壊れた v2 manifest で `--claude`
- 期待出力: (a) rc=0、`copied=0 updated=0 protected=N`、案内なし。(b) 同左で `updated=0`。(c) rc=1、案内なし
- 期待値の出所: R-002、`plan.md` P-17

### TC-16: ctime のみの変化

- 対応 AC: AC-08 / Trace ID: AC-08 / 種別: integration / RED: PASS（MU-9 で FAIL）
- 前提条件: 導入後にハードリンクの作成と削除を行う。`st_ctime_ns` が変わるまで最大 2 秒再試行する
- 入力: `--uninstall`
- 期待出力: **前提の assert**: 内容、inode、mode が同じで ctime のみ違う。rc=0、`retained`、ファイルが残る
- 期待値の出所: 既存実装（P-07）

### TC-17: `ok=False` の置き換え

- 対応 AC: AC-08 / Trace ID: AC-08 / 種別: manual（静的確認）+ unit / RED: 該当なし
- 入力: `grep -c "ok=False" tests/test_installer_ownership.py`
- 期待出力: 0。各呼び出しの期待: 行 156 rc=0 + `protected existing: agents/existing.md`、行 159 rc=0 + `retained (modified or unsafe): agents/new.md`、行 202 rc=1 + `invalid ownership manifest`、行 210 rc=0 + `protected symlink:`、行 220, 230 rc=0 + `retained (modified or unsafe): agents/new.md`
- 期待値の出所: 既存実装（`install.sh:179,222,227,269`）

### TC-18: docstring の参照

- 対応 AC: AC-08 / Trace ID: AC-08 / 種別: manual（静的確認）/ RED: 該当なし
- 入力: `grep -c installer_tests.py tests/test_installer_ownership.py`
- 期待出力: 0
- 期待値の出所: PR #1639 コメント

### TC-19: 残存脅威の明記

- 対応 AC: AC-09 / Trace ID: AC-09 / 種別: manual（静的確認）/ RED: **FAIL**
- 入力: `grep -n TOCTOU install.sh docs/working/TASK-1636/installer-ownership-review.md`、`grep -c "祖先を含むシンボリックリンクを拒否" docs/working/TASK-1636/installer-ownership-review.md`
- 期待出力: 前者は両ファイルで 1 件以上。後者は 0。目視で「守るもの / 守らないもの」が両方にある
- 期待値の出所: 規約（`review-principles.md` §7-quater）

### TC-20: 旧実装での RED

- 対応 AC: AC-10 / Trace ID: AC-10 / 種別: integration
- 入力: `plan.md` Task 1 Step 4
- 期待出力: 本表の RED 列と一致。FAIL の理由が各ケースの想定どおり
- 期待値の出所: 本表

### TC-21: 変異注入

- 対応 AC: AC-10 / Trace ID: AC-10 / 種別: integration
- 入力: `plan.md` Task 6 の MU-1〜MU-16
- 期待出力: 全変異で指定の TC が FAIL。未変異のコピーは GREEN
- 期待値の出所: `plan.md`

## Edge Cases

### TC-E01: macOS の実 `/tmp`

- 対応 AC: AC-01 / Trace ID: REG-01 / 種別: integration / 分類: 境界値 / RED: **FAIL**（macOS のみ）
- 前提条件: `os.path.islink('/tmp')` が真のときだけ実行（Linux は skip し、理由を表示）
- 入力: `tempfile.mkdtemp(dir='/tmp')` を正規化せずに target にする
- 期待出力: rc=0
- 期待値の出所: 既存実装（P-01）。Linux での同等の確認は TC-01

### TC-E02: v1 manifest が壊れている / dangling symlink

- 対応 AC: AC-05 / Trace ID: INV-02 / 種別: integration / 分類: 異常系 / RED: **FAIL**
- 入力: (a) `plangate-manifest.json` が `{bad`、(b) dangling symlink。`--claude`
- 期待出力: どちらも rc=1 で `legacy manifest found`。`json` の例外が出ない（内容を読まない）。リンク先が作られない
- 期待値の出所: 既存実装（`install.sh:197` は `is_symlink` も存在扱い）

### TC-E03: target の解決先が配布元

- 対応 AC: AC-02 / Trace ID: INV-01 / 種別: integration / 分類: 境界値 / RED: FAIL（導入が拒否される）
- 入力: `l -> <repo>/plugin/plangate`。`--claude --target l`、`--uninstall --target l`
- 期待出力: rc=0。`protected existing`。配布元の内容が不変、v2 なし
- 期待値の出所: 既存実装（試作の実測）

### TC-E04: v1 と v2 の共存

- 対応 AC: AC-05, AC-06 / Trace ID: INV-02 / 種別: integration / 分類: 境界値 / RED: PASS（是正で壊さないことの固定。対応する変異はない）
- 前提条件: v2 で導入後に v1 manifest を置く
- 入力: `--claude --force`、`--uninstall`
- 期待出力: どちらも rc=0、`legacy manifest retained`。v2 に載らないファイルは残り、v1 は不変
- 期待値の出所: 既存実装（`install.sh:197-198`）

## Convention Evidence

| 規約の記述（出典パス付き） | 実値 | 一致 | 判定 |
| --- | --- | --- | --- |
| §7-quater「残存脅威は実装側と運用 doc の両方」（`.claude/rules/review-principles.md`） | 現状 `installer-ownership-review.md:7` のみ（取得: `grep -n TOCTOU install.sh` が 0 件） | ❌（現状が未達。AC-09 で是正する対象） | 採用（是正対象として） |
| 移行手順（`plan.md`） | 新設の手順なので実値がない。v1 の形式は `origin/main:install.sh` の `_write_manifest` と照合済み（絶対パス、ディレクトリを含む、導入前のファイルを含みうる） | ✅ | 採用（TC-14 で実走する） |

## 自動化可否

| テストケース | 自動化 | 理由 / 代替手段 |
| --- | --- | --- |
| TC-01〜TC-16, TC-22〜TC-24, TC-E01〜E04 | 可 | `tests/test_installer_ownership.py` |
| TC-17〜TC-19 | grep で可 | 目視部分は V-1 で確認 |
| TC-20, TC-21 | スクラッチパッドのスクリプトで可 | リポジトリには残さない。ログを evidence に保存 |
| Linux 実機 | CI のみ | ローカル不可。PR の CI で確認 |
| macOS 実機 | ローカルのみ | CI なし。TC-E01 のログを evidence に保存 |

## 検証結果（V-1 で記入）

| テストケース | 結果 | Evidence |
| --- | --- | --- |
| 未実施 | — | — |
