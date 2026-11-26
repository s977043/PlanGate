---
task_id: TASK-1636
artifact_type: plan
schema_version: 1
status: draft
mode: high-risk
related_issue: https://github.com/s977043/plangate/issues/1636
created_by: orchestrator
---

# TASK-1636 Implementation Plan（PR #1639 レビュー指摘の是正）

## Goal

PR #1639（head `e683fd4d`）の所有権保護を保ったまま、symlink を含む導入先への導入と v1 利用者の更新を、成功に見せかけず動く形にする。

## Context

- 背景: 敵対レビューが major 2 件と minor 5 件で NOT_OK（PR #1639 コメント）
- 関連 Issue: #1636
- 関連 artifact: `pbi-input.md`（Human 確認待ちの下書き） / `test-cases.md` / `todo.md` / `review-self.md`
- Requirement refs: AC-01〜AC-10

## exec の前提（Human 操作）

`plan.md` の配置と、実行段階の `.md` 以外（`install.sh`、`tests/test_installer_ownership.py`）の編集のため、次の順で揃える（R-007）。

1. Human が `PLANGATE_HOOK_TASK=TASK-1636` を付けて Claude Code を再起動する。実行中の export やインライン付与は hook に届かない。
2. Agent が `plan.md` を配置し、下書きとの一致を確認する。
3. Human が C-3 を判断し、`bin/plangate approve TASK-1636` で `docs/working/TASK-1636/approvals/c3.json` を発行する（TTY が要るので `!` 実行は不可）。**AI は c3.json を作らない。**
4. exec 開始時に `plan_hash` の一致を確認する。C-3 後に `plan.md` を編集すると承認が無効になるので、修正が要れば再承認に戻す。

## Mode判定

**モード**: high-risk

**判定根拠**:

- 変更ファイル数: 実装・文書 4 → standard
- 受入基準数: 10 → high-risk
- 変更種別: バグ修正だが、ユーザーファイル削除の安全境界を緩める → high-risk
- リスク: 誤ると導入先の外への書き込みやユーザーファイル削除になる → high-risk
- 影響範囲: installer の導入、更新、撤去のすべてと移行手順 → high-risk
- ロールバック: commit 単位で戻せるが、配布後の利用者環境は戻せないので計画的に必要 → high-risk
- **最終判定**: high-risk。`lite_eligible=false`。HO 対象パスには触れない（`install.sh` と `tests/` は 12 カテゴリ外）が、autonomous APPROVE は high-risk のため不可で、人間の C-3 が必須。

## Scope

### In Scope

- major-1: target の正規化と、解決できない symlink の拒否
- major-2: v1 のみの状態での導入拒否、撤去時の案内、移行手順の文書化
- 導入結果の表示と案内の復旧: 件数の表示、変更があったときだけの完了案内、実行できる更新・撤去コマンド。未使用の `_print_caveats` と `_skip` の削除（Q-5）
- minor 5 件（テストの検証強化、legacy テスト、ctime テスト、docstring、TOCTOU の明記）

### Out of Scope

- **auto モードの終了コード**: `.claude` だけのプロジェクトで `sh install.sh` が導入成功でも rc=1 になる（P-09。`[ "$HAS_CODEX" = "1" ] && install_codex` が case の最後の文）。`origin/main` にも同じ構造がある既存欠陥なので、別 Issue に分離する。
- **`plugin/plangate/README.md:57-59` の `plangate-manifest.json` への言及**: 文言は古くなるが、`plugin/` を変更すると version bump ゲートの対象になる。別 PBI にする。
- macOS の CI ランナー追加（`.github/workflows/` は HO 対象で、現在 macOS ランナーはない）
- Codex 直接展開の撤去、TOCTOU への技術的防御

> 実装中にスコープ外の改善や不具合を見つけたら、その場で直さず handoff の V2 候補か別 Issue へ分離する。

## Global Constraints

- v1 manifest を所有の根拠にしない。内容も読まない（存在だけを見る）。
- manifest に記録する path は root からの相対のみ。絶対パスを記録しない。
- 新規依存を追加しない（標準ライブラリのみ。Python 3.8 互換を維持する）。
- 新しい CLI オプションを追加しない。
- 判断は `decision-log.jsonl` に記録する（exec の T-01 で初期化）。

## 前提の実測検証

実測環境は darwin、head `e683fd4d`、一時ディレクトリの fixture のみ。「試作」は scratchpad に置いた `install.sh` のコピーへの変更で、リポジトリのコードは変更していない。

| ID | 前提 | 検証方法 | 実測結果 | 判定 |
|---|---|---|---|---|
| P-01 | macOS 既定 TMPDIR で導入できない | `--target $TMPDIR/...` | `ERROR: symlink in target path` rc=1 | ✅ |
| P-02 | 明示的な symlink 祖先でも同じ | 実パス base に `link/t2` | 同上 rc=1 | ✅ |
| P-03 | target 自身が symlink でも同じ | dotfiles 型の `dot-link` | 同上 rc=1 | ✅ |
| P-04 | テストの失敗は環境依存 | `python3 tests/test_installer_ownership.py` を既定 TMPDIR / 実パスの TMPDIR で実行 | 17 件中 15 失敗 / 17 件 OK | ✅ |
| P-05 | v1 のみで `--force` は何もしない | v1 manifest + 既存ファイル | `protected existing` rc=0、内容不変、v2 なし | ✅ |
| P-06 | v1 のみで新規配布ファイルがあると v2 が生まれる | 同上 + 新しい `b.md` | `b.md` をコピーし v2 作成、rc=0。`a.md` は保護のまま | ✅ |
| P-07 | ctime のみの変化で保持される | ハードリンクの作成と削除 | `retained (modified or unsafe)` | ✅ |
| P-08 | `realpath` のみでは dangling を追従して先に作る | 試作で `--target` に dangling symlink | リンク先に `agents/` と manifest を作り rc=0 | ✅（穴 H-4 の根拠） |
| P-09 | auto モードは成功でも rc=1 | `.claude` のみの cwd で `sh install.sh` | rc=1 | ✅（Out of Scope） |
| P-10 | `_print_caveats` に呼び出し元がない | `grep -n _print_caveats install.sh` | `293:` の定義のみ。`origin/main` では `install_claude` から呼んでいた | ✅ |
| P-11 | `realpath` 案で既存テストが環境によらず通る | 試作で既定 TMPDIR の全件実行 | 17 件 OK | ✅ |
| P-12 | 表記違いでも同じ記録を使う | 試作で symlink 経由に導入し、実パスと `l3/../real/` で撤去 | 同じ `agents/a.md` を削除。manifest のキーは相対 | ✅ |
| P-13 | コピー先へ向け替えても削除しない | 試作で `cp -Rp` 後に root を向け替えて撤去 | `retained` | ✅ |
| P-14 | 事前検査で dangling と循環を止められる | 試作で leaf / 途中 / `d/../y` / 循環 | すべて rc=1、リンク先は作られない。正常な symlink と新規ディレクトリは rc=0 | ✅ |
| P-15 | v1 ガードで書き込みなしに止められる | 試作で `--force` / なし / `--dry-run` | すべて rc=1、導入先の一覧は不変 | ✅ |
| P-16 | macOS の CI ランナーがない | `git grep -nE "runs-on:.*macos\|os:.*macos" -- .github/workflows` | 0 件 | ✅ |
| P-17 | 変更がなければ完了案内を出さない案が成立する | 試作（`rr1636/verify.py`）で再導入、全件編集済みの `--force`、dry-run、失敗 | いずれも案内なし。初回と更新のみ案内あり | ✅ |
| P-18 | 非 ASCII の案内は ASCII の stdout で失敗しうる | 試作で `PYTHONIOENCODING=ascii` | `reconfigure` なしは**書き込み後に rc=1**。`errors='backslashreplace'` ありは rc=0 | ✅（穴 H-10） |
| P-19 | 印字したコマンドが別の cwd で動く | 試作で空白と `'` を含む repo と target、symlink 経由の相対 target | 更新と撤去が成功、cwd に `.claude` を作らない | ✅（H-11） |
| P-20 | 移行手順がたどれる | 試作で tag 付き git repo に対して比較、削除、改名、導入、撤去 | 未編集の配布ファイルだけを選び、利用者のファイルは残る。存在しない tag は「同じ」と判定しない | ✅ |
| P-21 | 全件保持の移行は v2 を作らず rc=0 | 試作 | rc=0、案内なし、`protected=1`、v2 なし、撤去で全件保持 | ✅ |
| P-22 | MU-4 は親の移動と移動先への symlink で検出できる | 試作で `agents` を rename して symlink | 変異なしは保持、変異ありは削除 | ✅（R-004 の実測と一致） |
| P-23 | manifest なしの撤去の rc が main と異なる | RiverReview の実測（main rc=1）、試作でブランチ rc=0 を再確認 | main 側はコード（`exit 1`）とレビュー記録で確認 | ✅ |

## Questions / Unknowns

- **Q-1（Human, C-3）**: v1 のみで `--force` なしの導入も rc≠0 にしてよいか。推奨は「はい」（案 M2-C）。だめなら `plan.md` を差分改訂する。
- **Q-2（Human, C-3）**: 撤去は v1 のみで rc=0 を維持する案でよいか。manifest が何もない撤去も、main は rc=1、本ブランチは rc=0 で、既に挙動が変わっている（R-005）。推奨は両方 rc=0（「何も消さなかった」ことを文言で明示する）。自動化が「撤去できた」と誤認しうる点は残る。
- **Q-3（Human, C-3）**: RiverReview の計画レビューを C-2 として十分とみなすか（`review-external.md`。verdict は WARN）。担当エージェントは unavailable で、独立の汎用エージェントが代替した。推奨は十分とみなすこと。設計妥当性とコードベース整合のレーンを分けていない点は残る。
- **Q-4（Human, C-3）**: `pbi-input.md` は AI の下書きなので、AC の確定を C-3 で確認する。
- **Q-5（Human, C-3, R-006）**: レビュー指摘にない案内の復旧（現 head では呼び出し元がない `_print_caveats` を、件数つきの Python 側の案内に置き換える）を範囲に含めてよいか。推奨は「はい」。v1 利用者の更新経路と major-2 の案内に直結するため。不要なら Task 4 を件数表示だけに減らす。

**検証の限界（Human の判断事項ではない）**: Linux の実機実行はローカルでできない。PR の CI（`sh tests/run-tests.sh`）で確認する。macOS は CI がないのでローカル実行の証跡で確認する。

## Approach Comparison

### major-1: symlink を含む target

| 案 | Evidence | Complexity Cost | New Abstractions | Current-Need Trace | Verification | Trade-offs | 判定 |
|---|---|---|---|---|---|---|---|
| M1-A: `realpath` で正規化し、既存の全成分検査を維持。事前検査を追加 | P-08, P-11〜P-14 | 低（10 行未満） | なし | AC-01〜04 | TC-01〜09 | 実行中の祖先差し替えも全成分検査で検出できる。root 表記が 1 つに定まる。既存検査を変えない | **採用** |
| M1-B: 検査を root より下の成分に限定 | レビュー案 | 低〜中（`no_symlinks` の起点を全呼び出しで変更） | なし | AC-01 | 同左 | 祖先を見なくなり、実行中の祖先差し替えを検出できない。root の表記が複数のまま残り、同一性の議論が増える | 不採用 |
| M1-C: 現状維持で文書に書く | 現行文書 | なし | なし | なし | — | 既定の `~/.claude` 運用と macOS の TMPDIR で使えず、major-1 が残る | 不採用 |
| M1-D: `/tmp`・`/var` だけ許可 | P-01 | 低 | 許可リスト | なし | — | dotfiles 型を救えない。OS 名で分岐する | 不採用 |

既存文書の「安全側の制限」との関係: 祖先拒否の目的は導入先の外に書かないことだが、利用者が指定した target の解決先は利用者の意図の範囲である。守るべき境界は **解決後の root より下** なので、そこの検査は緩めない。

### 緩めて再び開く穴と固定方法

| ID | 穴 | 塞ぎ方 | 固定するテスト |
|---|---|---|---|
| H-1 | root より下の symlink 経由の書き込み | `no_symlinks(dest)` を維持。正規化後の全成分を検査 | TC-03 |
| H-2 | root より下の symlink 経由の削除（親、ファイル） | `matches()` の `no_symlinks` を維持 | TC-04 |
| H-3 | manifest や一時ファイルが symlink 経由で外へ出る | `read_records` の拒否を維持 | TC-05 |
| H-4 | dangling symlink を追従して意図しない場所に作る（P-08） | 正規化前に未正規化の各 prefix を検査して拒否 | TC-08 |
| H-5 | 循環 symlink の挙動が Python 版で異なる | H-4 と同じ検査で版によらず拒否 | TC-08 |
| H-6 | manifest に記録する path の同一性 | キーは root 相対のまま。絶対パスを記録しないことを assert | TC-06 |
| H-7 | 再導入や撤去時の root 表記の違い | `realpath` で 1 つに定める。macOS の大文字小文字違いも相対キーなら影響しない | TC-06 |
| H-8 | root の向け替えで別ディレクトリのファイルを所有扱いする | receipt の dev / ino / ctime 照合を維持 | TC-07 |
| H-9 | target の解決先が配布元そのもの | 全件 `protected existing`、manifest を作らない（試作で確認済み） | TC-E03 |
| H-10 | 案内の非 ASCII 出力が書き込み後に例外で rc=1 になる（P-18。R-002 の修正案が生む穴） | 冒頭で `sys.stdout.reconfigure(errors='backslashreplace')` | TC-23 |
| H-11 | 印字するコマンドが空白や `'` を含むパスで壊れる（R-001 の修正案が生む穴） | `shlex.quote` で全パスを引用 | TC-15 |

**残す脅威**: symlink の target が指す先は、利用者が指定した場所として受け入れる。意図せず作られた symlink を target にすると、その先へ導入される。判定から unlink までの差し替えは防がない。

### major-2: v1 manifest のみの状態

| 案 | Evidence | Complexity Cost | New Abstractions | Current-Need Trace | Verification | Trade-offs | 判定 |
|---|---|---|---|---|---|---|---|
| M2-A: 警告して rc=0 | P-05 | 低 | なし | — | — | スクリプトや CI では成功に見えたまま。major-2 の中心が残る | 不採用 |
| M2-B: `--force` のときだけ rc≠0 | P-05, P-06 | 低 | なし | AC-05 の一部 | — | `--force` なしの導入が v2 を作ると以後は検出できない（P-06） | 不採用 |
| M2-C: v1 あり・v2 なしの導入は常に rc≠0、書き込み前に停止 | P-15 | 低（2 行 + 文言） | なし | AC-05, AC-06 | TC-10〜13 | P-06 の素通りが起きない。`--force` なしの既存利用者も止まる（Q-1） | **採用** |
| M2-D: v1 記載のファイルを自動で所有扱い | #1636 | 中 | なし | なし | — | v1 は導入前のファイルも記録するので #1636 が再発する。既存方針に反する | 不採用 |
| M2-E: `--adopt-legacy` を追加 | — | 中 | 新オプション | なし | — | 所有を証明できない点は同じ。削除の根拠を CLI で作れてしまう | 不採用 |

**終了コード**: 既存の `fail()` と同じ rc=1。文言で区別できるので専用コードは足さない。

**エラー文（`fail()` 経由）**:

```text
legacy manifest found (plangate-manifest.json) and no ownership manifest; nothing was changed. See "Migrating from a v1 manifest" in docs/plangate-plugin-migration.md
```

**撤去時の文言**（v2 なしで v1 あり。rc=0 を維持）:

```text
[plangate] no verified ownership manifest; all files retained. See "Migrating from a v1 manifest" in docs/plangate-plugin-migration.md
```

**移行手順（`docs/plangate-plugin-migration.md` の `install.sh を使う` に節を追加）**:

1. `.claude/` をバックアップする。
2. `plangate-manifest.json` の `files` を確認する。絶対パスで、ディレクトリも含まれる。**導入前からあったファイルも含まれうるので、記載されていても PlanGate のものとは限らない。**
3. 各ファイルを、manifest の `version` の tag の配布物と 1 件ずつ比較する（R-003）: `git -C <clone> show "v<version>:plugin/plangate/<相対パス>" | cmp - <導入先のファイル>`。`files` のディレクトリは中のファイルごとに比較する。**cmp が一致したファイルだけ**を手で削除してよい。不一致、tag やファイルが見つからない、判断できないものは残す。空になったディレクトリは `rmdir` で消す。`rm -r` は使わない。
4. `plangate-manifest.json` を `plangate-manifest.json.bak` に改名する（削除しない）。
5. `sh <clone>/install.sh --claude --target <導入先の .claude>` を実行する。新しく置いたファイルは v2 で管理される。
6. 残したファイルは `protected existing` と表示され、**以後 `--force` でも更新されず、撤去もされない**。新しい版が欲しいファイルは、内容を確認して手で削除してから再度導入する。すべて残した場合は `copied=0` で v2 は作られないが、rc=0 で正常である。

**v1 と v2 が共存する状態**: 通常は発生しない（M2-C 後は v2 を作る前に止まる）。利用者が v1 を戻した場合は従来どおり進み、v1 を根拠にしない。

### 導入結果の表示と案内（R-001 / R-002）

| 案 | Evidence | Trade-offs | 判定 |
|---|---|---|---|
| D-A: Python が件数を数え、変更があるときだけ Python が案内を出す。シェルの `_print_caveats` は削除 | P-17〜P-19 | 件数、解決後の root、引用を 1 か所で扱える。シェルとの値の受け渡しが要らない。H-10 への対処が要る | **採用** |
| D-B: `DRY_RUN=0` だけでシェルから案内 | R-002 | 全件保護でも「完了」と出る | 不採用 |
| D-C: Python の出力をシェルで捕捉して判定 | — | 途中失敗の出力の扱いと逐次表示が複雑になる | 不採用 |
| D-D: fd 3 で Python からシェルへ件数を渡す | — | 動くが仕組みが読みにくく、引用をシェルでも実装する必要がある | 不採用 |

- 毎回の表示: `[plangate] summary: copied=N updated=N protected=N`（dry-run は末尾に ` (dry-run)`）。
- 案内の条件: dry-run でなく、`copied + updated > 0` で、`PLANGATE_SETUP_HINT` が `0` でないこと。rc は変えない。途中失敗では出さない。
- 更新コマンド: `git -C <repo> pull && sh <repo>/install.sh --claude --force --target <解決後の root>`。auto モードを使わないので P-09 の影響を受けない（R-001）。
- 撤去コマンド: `sh <repo>/install.sh --uninstall --target <解決後の root>`。
- `--force` で全件保護のときは rc=0 のまま、`updated=0 protected=N` で結果が分かる。

### Recommended Approach

M1-A、M2-C、D-A を採用する（M2-C と D-A の範囲は Q-1、Q-5 の Human 判断が前提）。既存の検査と方針を変えずに入口と出口だけ足す形で、P-11〜P-22 の試作で成立を確認した。

#### Why this is the minimum sufficient design

- Required AC / constraints: AC-01〜AC-07。v1 を所有扱いしない方針
- New abstractions / interfaces / dependencies: なし
- Why each is needed now: `realpath` は major-1、事前検査は P-08 の穴、ガードは P-05 と P-06 に対応する
- Simpler alternative considered: M1-B、M2-B（上表で棄却）
- Observable behavior / contract / invariant: root より下の symlink を経由しない。v1 を根拠に削除も上書きもしない。止めるときは書き込まない
- Verification strategy: fixture の黒箱テスト、旧実装での RED、変異注入
- Conditional guidance fired: Failure / Compatibility / Security
- Deferred extensions: macOS CI、自動移行コマンド

## Change Type / Verification Strategy

- Change type: bug fix + テスト強化 + docs
- Pre-change evidence: `e683fd4d` の installer に対する新テストの RED（実パスの TMPDIR で実行し、環境由来の失敗を混ぜない）
- Post-change evidence: GREEN、変異注入の全件 FAIL 検出、`sh tests/run-tests.sh`
- Test trace: `test-cases.md`

## Files / Interfaces

| ファイル | 操作 | 目的 | 公開インターフェース |
|---|---|---|---|
| `install.sh` | modify | 正規化、事前検査、v1 ガード、件数と案内、`_print_caveats` と `_skip` の削除、残存脅威コメント | CLI オプションは不変。rc が変わるのは v1 のみの導入だけ。summary 行が増える |
| `tests/test_installer_ownership.py` | modify | 新規 TC、`ok=False` の置き換え、docstring、root の realpath 化 | `PLANGATE_TEST_INSTALLER` は維持 |
| `docs/plangate-plugin-migration.md` | modify | 節「Migrating from a v1 manifest」を追加 | エラー文から参照する |
| `docs/working/TASK-1636/installer-ownership-review.md` | modify | 旧制限の記述を置き換え、残存脅威を明記 | — |
| `docs/working/TASK-1636/{status,current-state,INDEX,handoff,todo}.md`, `decision-log.jsonl` | create / modify | 作業記録 | — |

**触らないファイル**: `tests/extras/ta-1636-installer-ownership.sh`（入口は変更不要）、`plugin/` 配下全部、`.claude/` 配下全部、`.github/workflows/`、`bin/plangate`、`schemas/`、`scripts/hooks/`、`README.md`。

## Work Breakdown

### Task 1: テストの検証を強め、新テストを先に書く（RED）

**Purpose**: 修正前の実装で想定の理由で落ちるテストを揃える。

**Change Type / Verification Pattern**: bug fix — regression RED → fix → GREEN

**Files**: Modify `tests/test_installer_ownership.py`

**Interfaces**: Produces: `run_installer(*args, rc=0, expect=None)`（`ok=False` を廃止し、rc と出力の部分一致を検証する）

**Steps**:

- [ ] Step 1: `setUp` の root を `Path(os.path.realpath(self.temp.name))` にし、docstring を `tests/test_installer_ownership.py` に直す
- [ ] Step 2: `ok=False` の呼び出し（行 117, 156, 159, 202, 210, 220, 230）を、期待する rc と理由の検証へ置き換える
- [ ] Step 3: `test-cases.md` の TC を追加する
- [ ] Step 4: `e683fd4d` の installer で RED を確認し、ログを保存する
  - command: `git show e683fd4d:install.sh` をスクラッチパッドへ書き出し、`TMPDIR=<実パス> PLANGATE_TEST_INSTALLER=<そのコピー> python3 tests/test_installer_ownership.py -v`
  - expected: `test-cases.md` の RED 列が FAIL の TC だけが FAIL

**Completion Criteria**: RED の理由が各 TC の想定と一致する。既存の意図を持つテストは GREEN のまま。

**Rollback**: `git checkout -- tests/test_installer_ownership.py`

### Task 2: major-1 を実装する

**Purpose**: target を正規化し、解決できない symlink を拒否する。

**Change Type / Verification Pattern**: bug fix — RED → fix → GREEN

**Files**: Modify `install.sh`（行 117 周辺）

**Interfaces**: Consumes: Task 1 のテスト

**Steps**:

- [ ] Step 1: `root` の計算の前に、`os.path.join(os.getcwd(), target)` を**正規化せず**先頭からたどり、`islink` かつ `not exists` の prefix があれば `fail('unresolved symlink in target path: ...')` とする
- [ ] Step 2: `root = Path(os.path.realpath(target))` に変更する。`fail()` より後に置く順序に注意する。行 194 の `no_symlinks(root)` は残す
- [ ] Step 3: `python3 tests/test_installer_ownership.py` で AC-01〜04 の TC が GREEN

**Completion Criteria**: TC-01〜09、TC-E01、TC-E03 が GREEN。

**Rollback**: `git revert` で当該 commit を戻す。

### Task 3: major-2 を実装し、移行手順を書く

**Purpose**: v1 のみの導入を書き込み前に止め、進む道を示す。

**Change Type / Verification Pattern**: bug fix — RED → fix → GREEN

**Files**: Modify `install.sh`（行 200 周辺、行 258）、`docs/plangate-plugin-migration.md`

**Steps**:

- [ ] Step 1: `if operation == 'install':` の直後で `os.path.lexists(legacy) and not os.path.lexists(manifest)` なら上記の文言で `fail()`
- [ ] Step 2: 行 258 の撤去文言を、v1 があるときだけ案内を足す形にする
- [ ] Step 3: 移行手順の節を追加する
- [ ] Step 4: TC-10〜14、TC-22 を GREEN にする

**Completion Criteria**: TC-10〜14、TC-22 が GREEN。手順の TC-14 が文書の順序どおりに動く。

**Rollback**: `git revert` で当該 commit を戻す。

### Task 4: 導入結果の表示と案内を実装する（Q-5 の判断が前提）

**Purpose**: 何も更新しなかった導入を完了に見せず、実行できるコマンドを案内する。

**Change Type / Verification Pattern**: bug fix — RED → fix → GREEN

**Files**: Modify `install.sh`（Python ブロックの install 分岐、行 293-307、行 38）

**Steps**:

- [ ] Step 1: install 分岐で `copied` / `updated` / `protected` を数え、ループ後に summary 行を出す
- [ ] Step 2: 「導入結果の表示と案内」の条件で案内を Python から出す。パスはすべて `shlex.quote`、root は解決後の値を使う
- [ ] Step 3: Python ブロック冒頭に `sys.stdout.reconfigure(errors='backslashreplace')` を入れる
- [ ] Step 4: 未使用の `_print_caveats` と `_skip` を削除する
- [ ] Step 5: TC-15、TC-23、TC-24 を GREEN にする

**Completion Criteria**: TC-15、TC-23、TC-24 が GREEN。`PLANGATE_SETUP_HINT=0` で案内が出ず、summary は出る。

**Rollback**: `git revert` で当該 commit を戻す。

### Task 5: 残存脅威を書く

**Purpose**: 打ち切りの範囲を、コードを読む人と運用者の両方に示す。

**Change Type / Verification Pattern**: docs — deterministic validation

**Files**: Modify `install.sh`（行 100 のコメント）、`docs/working/TASK-1636/installer-ownership-review.md`（行 7）

**Steps**:

- [ ] Step 1: 守るもの（root より下の symlink 経由の書き込みと削除、未所有ファイル、v1 を根拠にした削除）と、守らないもの（target の symlink の指す先、判定から unlink までの差し替え、旧 installer の使用）を書く
- [ ] Step 2: 旧記述「祖先を含むシンボリックリンクを拒否する」を置き換え、検証結果の節を更新する
- [ ] Step 3: TC-19 を実行する

**Completion Criteria**: TC-19 が PASS。

**Rollback**: `git revert` で当該 commit を戻す。

### Task 6: 検出力を確認し、敵対レビューを 2 ラウンド回す

**Purpose**: テストの素通りをなくし、是正そのものを疑う。

**Change Type / Verification Pattern**: verification

**Files**: 読取のみ。証跡は `docs/working/TASK-1636/evidence/`。変異はスクラッチパッドのコピーに注入し、リポジトリの `install.sh` は変えない。

**変異一覧（各変異で少なくとも 1 TC が FAIL すること）**:

| ID | 変異 | 検出する TC |
|---|---|---|
| MU-1 | `realpath` → `abspath` | TC-01, TC-02 |
| MU-2 | 事前検査を削除 | TC-08 |
| MU-3 | 導入の `no_symlinks(dest)` を常に真 | TC-03 |
| MU-4 | `matches()` の `no_symlinks` を削除 | TC-04(a)（親を rename して移動先へ symlink。同じ inode を保つ形でないと生存する。R-004） |
| MU-5 | `read_records` の symlink 拒否を削除 | TC-05 |
| MU-6 | v1 ガードを削除 | TC-10, TC-11 |
| MU-7 | v1 ガードを `force` のときだけに限定 | TC-11 |
| MU-8 | v1 ガードを導入ループの後へ移動 | TC-11 |
| MU-9 | 比較から `ctime_ns` を除外 | TC-16 |
| MU-10 | 比較から `dev`、`ino`、`ctime_ns` をまとめて除外（`ino` 単独の除外はコピーで ctime も変わるため検出できない） | TC-07 |
| MU-11 | manifest のキーを絶対パスにする | TC-06 |
| MU-12 | 案内の出力を削除 | TC-15 |
| MU-13 | 案内の条件から `copied + updated > 0` を除く | TC-24 |
| MU-14 | `reconfigure` を削除 | TC-23 |
| MU-15 | 印字の `shlex.quote` を除く | TC-15 |
| MU-16 | 更新コマンドから `--target` を除く | TC-15 |

変異はすべて call site を壊す。各変異の前に、未変異のコピーが GREEN であることを確認して検査器の生存を示す。

**敵対レビュー（`review-principles.md` §7-quater、下限 2 ラウンド）**:

- **R1**（独立レビュー、実装差分と穴リスト H-1〜H-9 を渡さず差分だけ）: 導入先の外への書き込み、ユーザーファイルの削除、成功に見せかける経路、案内の誤り。
- **R2 以降**: 新しい穴探しではなく R1 の是正を疑う。(1) 別表記や別ノード種別で是正を回避できないか（`..`、相対、FIFO、ディレクトリ置換）、(2) 事前検査や v1 ガードが生んだ穴、(3) fail-closed 化が正常系を壊していないか（新規導入、`~/.claude` 実運用、v2 のみの再導入）。
- **収束判定**: 新しい回避クラスが出なくなること。指摘ゼロを条件にしない。回避クラス台帳を `installer-ownership-review.md` に追記専用で持ち、「前ラウンドが見つけられなかった理由」を必須とする。新クラスが毎ラウンド出るなら停止して設計を疑う。
- **打ち切り時**: 完全性を主張せず、Task 5 の残存脅威モデルに揃える。保証の主体は C-4 Human レビューと利用者のバックアップであることも書く。

**fixture と実環境の分担**: fixture は分岐と回帰を、macOS 実機の 1 周（実 `/tmp` 配下と実 symlink の dotfiles 構成の fixture）は OS の配置由来の失敗を担当する。実 `~/.claude` には触れない。

**Completion Criteria**: 変異が全件検出される。ラウンド結果が台帳に残る。

**Rollback**: 不要（検証のみ）

## Verification Plan

| 種別 | コマンド / 確認方法 | 期待結果 | Evidence 保存先 |
|---|---|---|---|
| Unit（CI 経路） | `sh tests/run-tests.sh` | 0 failed | `evidence/test-runs/` |
| Wrapper | `sh tests/extras/ta-1636-installer-ownership.sh` | rc=0（現状 macOS 既定 TMPDIR で rc=1） | `evidence/test-runs/` |
| 環境依存の確認 | 既定 TMPDIR と実パス TMPDIR の両方で `python3 tests/test_installer_ownership.py` | ともに OK | `evidence/test-runs/` |
| Linux | PR の CI（exact HEAD） | 緑 | PR の checks |
| 構文 | `sh -n install.sh` / `python3 -m py_compile tests/test_installer_ownership.py` | rc=0 | `evidence/verification/` |
| RED | Task 1 Step 4 | RED 列どおり | `evidence/test-runs/` |
| 変異 | Task 6 | 全件検出 | `evidence/verification/` |
| 差分範囲 | `git diff --stat e683fd4d...HEAD` | Files 表の範囲内 | `evidence/verification/` |

**実行不能な検証**: Linux のローカル実行と macOS の CI はない。代替は Q-5 のとおり。

### レビューレーン計画

| 成果物 | レーン | unavailable 時の代替 |
|---|---|---|
| 計画一式（C-2 を求める場合。Q-3） | 設計妥当性 / コードベース整合 | 独立サブエージェント |
| 実装差分（V-3） | 敵対レビュー R1, R2 / Codex 独立レビュー | 独立サブエージェント。`unavailable` の理由を記録する |

## Plan Review Readiness

### Success Criteria

- AC: AC-01〜10 と `test-cases.md` の対応表
- Contract / Invariant: INV-01〜03（`test-cases.md`）
- Completion boundary: V 系完了と PR 更新まで。merge と draft 解除は Human。

### Review Criteria

- Design alignment: 既存の receipt 照合と `no_symlinks` を変えない
- Minimum sufficient design: 新しい抽象、オプション、依存がない
- Test expectations: RED と変異の証跡
- Security: 穴リスト H-1〜H-9 と残存脅威
- Maintainability: 変更は Python ブロックの入口に集まる
- Backward compatibility: v1 のみの導入の rc が 0 から 1 に変わる（Q-1）。v2 環境は不変
- Operational risk: v1 利用者は移行が要る。手順はファイルを自動で消さない

### Required Context

- Referenced issues: #1636、PR #1639
- ADR / docs: `installer-ownership-review.md`、`docs/plangate-plugin-migration.md`
- Existing implementation: `install.sh:100-280`
- Related tests: `tests/test_installer_ownership.py`、`tests/extras/ta-1636-installer-ownership.sh`
- Constraints: HO パス非接触。`plugin/` 非接触（version bump 回避）

### Non-goals and Scope Boundary

- Out of scope: 上記 Out of Scope
- Change-prohibited zones: 上記「触らないファイル」
- Forbidden new dependencies: すべて

## Replan Triggers

- `install.sh` の Python ブロックの差分が 60 行を超える
- Files 表にないファイルの変更が 1 件でも必要になった
- `e683fd4d` との比較で既存 17 テストの意図を 1 件でも変える必要が出た
- 変異が 1 件でも検出できず、テスト追加で解消しない
- 敵対レビューで 2 ラウンド連続して新しい回避クラスが出た
- `sh tests/run-tests.sh` のベースラインが `e683fd4d` で失敗している

## Stop Condition

- C-3 承認前に exec が必要になった
- `PLANGATE_HOOK_TASK` が未設定、または `plan_hash` が不一致
- v1 を所有の根拠にしないと AC を満たせないと判明した
- 実 `~/.claude` など fixture 外に触れる必要が出た
- 新規依存、新しい CLI オプション、HO パスの変更が必要になった

## Human Approval Boundary

- Security-sensitive changes: symlink 追従の解禁は C-3 で確認する（本計画の M1-A）
- Auth / billing / permissions: 該当なし
- Production operations: merge、draft 解除、tag、Release は Human
- Data deletion / migration: 移行手順の実行は利用者。AI は実環境で実行しない
- Irreversible changes: force push はしない

## C-1 Self Review Checklist

結果は `review-self.md` を参照。
