# TASK-1408 Status

## モード判定

critical（Human 決定）

## C-3 Gate

C-3 は Human の `approvals/c3.json` 発行による（plan_hash `sha256:2f6dee70…4b07d`）。AI は c3.json を作らない。

## フェーズ履歴

| 日時 | フェーズ | 内容 |
| --- | --- | --- |
| 2026-11-08 00:00 | exec | 下書き clone で T-01〜T-07、T-14 を実施（worktree への転記待ち） |
| 2026-11-12 07:56 | exec | canon を worktree に転記（`e5573cc8` の commit 時刻） |
| 2026-11-12 07:58 | verify（L-0 / V-1〜V-4） | 測定 evidence・exec レビュー・handoff 下書きを追加（`16fa6db7`） |
| 2026-11-12 08:04 | verify（L-0 / V-1〜V-4） | canon `e5573cc8` に対して evidence を再生成（`cf751a1f`） |
| 2026-11-12 08:12 | verify（L-0 / V-1〜V-4） | C-3 APPROVED の `approvals/c3.json` を commit（`6d1f7a6b`。Human の発行時刻は不明、commit 時刻を記載） |
| 2026-11-12 08:53 | verify（L-0 / V-1〜V-4） | T-10 独立再実行の結果を記録（`86db3567` 08:38 / `155ba058` 08:38 / `d5461bd3` 08:53 / `5dae38c0` 08:53） |
| 2026-11-13 01:49 | PR 作成済 | PR #1650 を作成（`createdAt` 2026-11-12T16:49:09Z）。本文に記録欄を転記済み |
| 不明 | C-4 待ち | Human C-4 待ち（本 commit で working context を PR 作成後の状態に同期） |

## exec 開始時の記録

- `<base>` = `9445df175e93fab31493274915bb35ab01cad4f1`（origin/main。2026-11-08 再測定で一致）
- 失効後の canon commit: 4 件（`a6d1ea5f` / `6d626360` / `0122d6f9` / `a3c9146d`）。plan 時点から追加なし → 差分表の更新不要
- M-1: 3 時点とも `(none)`（Replan 不要）
- 別 issue: **#1643**「canon 7: I1 例外の失効後に merge された 4 commit の I4 扱いを裁定する」（OPEN。`gh issue view 1643` で番号とタイトルを照合）
- `ci.yml` L102: `.github/PULL_REQUEST_TEMPLATE.md` は markdownlint の対象 glob に含まれるだけ。テンプレート 1 行追加で CI の挙動は変わらない（T-02）

## 残タスク

- [x] T-01 / T-02 / T-03 / T-04 / T-05 / T-06 / T-07 / T-13 / T-14
- [x] T-08 R1 レビュー（I1 docs 整合 / I2 敵対、`reviewed_at_sha` つき）。`review-external.md` R-101〜R-112 に集約
- [x] T-09 R2 レビュー。同上
- [x] T-10 独立再実行（ME-6 は assertion）。実施者は Codex から作成者ではない Claude サブエージェントへ変更（計画からの変更点を参照）。2026-11-12 rc=0
- [x] T-11 `sh tests/run-tests.sh`、TC-07 / TC-08（結果は V-1 判定の節。head の SHA の問題は handoff §2 で未解決）
- [ ] T-12 handoff ほか: **Human C-4 待ち**（handoff は PR 作成後の状態に更新済み。I4 の充足判定は Human C-4）

## V-1 判定

**WARN**（handoff.md §1 と同じ。1408-AC-6 は I4 の機械証跡が未充足で WARN、1408-AC-7 は未判定）

- T-08 / T-09: exec レビュー X-R1〜X-R5 を `review-external.md` の末尾（R-101〜R-112）に集約した
- T-11: `sh tests/run-tests.sh` は TA-100 で rc=2。未変更の `9445df17` でも同じ箇所で失敗したので、本変更には帰属しない。原因は macOS の `mktemp -d` が TMPDIR を見ず、`/var` の symlink に一時ディレクトリを作ること（TA-100 L44。handoff.md §2）。実パスの TMPDIR と scratch の mktemp shim を使い、単独・直列で再実行した。対照 `9445df17` は rc=0（1556 passed / 0 failed）、head `c571a65c`（PR の履歴にない SHA で測った参考値。指摘 6）は rc=1（1548 passed / 4 failed）。4 件はすべて ta-61 TC-12 のタイムアウト（ta-62 / ta-65 / ta-70 / ta-71、load1 36〜113）で、個別に standalone で再実行すると、head は 4 本とも rc=0 だった。対照は ta-62 のみが負荷によるタイムアウトで rc=1 となり、**負荷に帰属すると確定した**（各実行の前後に uptime を記録。`evidence/test-runs/standalone-4.txt`）。並行実行時の TA-49 FAIL は干渉と確定した（並行実行した回の対照ログは単独実行の出力で上書きしてしまい、残っていない）
- T-11（PR head で再測定、2026-11-13 02:42〜03:22）: 同じ方法（実パス TMPDIR + mktemp shim、単独・直列）で PR head `276f36a4` を測った。rc=1、1552 passed / 3 failed（load1 8.8 → 35.5）。FAIL は TA-10 TC-7、ta-61 TC-12(b) の ta-62 タイムアウト、TA-62 TC-D のタイムアウト。ta-10 と ta-62 を standalone で再実行すると head・対照 `9445df17` とも rc=0 だった。`9445df17..276f36a4` に `bin/` `scripts/` `tests/` の差分はないので、本変更には帰属しない。タイムアウト 2 件は負荷に帰属する。TA-10 TC-7 は再現せず、原因は未特定（`evidence/test-runs/run-tests-pr-head-276f36a4.txt`、`standalone-pr-head-276f36a4.txt`）。判定は WARN のまま
- 既知課題: TA-49 は固定パス `/tmp/ta49_err*` を使うので、並行実行に弱い。head と対照を並行で走らせた shim 版の結果は参考値とする
- clean-tree の範囲は現状のまま（tracked の差分と evidence/ 配下の untracked）とする。repo 全体の untracked（テスト生成物）は、commit 範囲の絞り込み（`git add -A docs/working/TASK-1408`）と head-paths-scoped で混入を防ぐ（オーガナイザー判断）
- T-10: 2026-11-12 08:36 独立 worker が `6d1f7a6b` で実施。check.sh rc=0、陽性対照 rc=3（記録欄を参照）。出力は `evidence/independent-rerun.txt`（`155ba058` で repo に配置）

## 計画からの変更点

- ME-1（`gh pr view`）はネットワークを要するため `measure.sh` に含めず、出力を `evidence/manifest.txt` に記録した（`make-manifest.sh` で生成）
- R2-a（minor）: 失効節の失効後差分の項に「`9445df17` までの 4 commit の扱いは #1643 の Human 裁定に従う」を追加した（plan 文案からの軽微逸脱）
- R2-b（major）: 手書きの manifest をやめ、`evidence/make-manifest.sh`（`<canon-sha>..HEAD` の固定検査を含む）と `evidence/regen.sh`（転記後の再生成を 1 本で行う）を追加。TC の検査は `evidence/check.sh` として repo 内に置いた
- R3-a / R3-b（設計変更）: evidence スクリプトの層で毎ラウンド新しいクラスが出たため、継ぎ当てをやめて作り直した。`manifest.txt` が固定対象を宣言する（base / canon の完全 SHA、`canon^ == base`、`base..canon` の変更パス集合 = テンプレートと `phase0-migration.md` の完全一致、`canon..head` は `docs/working/TASK-1408/` 配下のみ、各スクリプトと `measurements.txt` の sha256）。`check.sh` は HEAD に commit された内容だけを読み、宣言・固定の期待値・実測を全項目で照合する（VERIFY）。`make-manifest.sh` は宣言の生成のみを行い、時刻を含めないので冪等。head の SHA は manifest 自身が head に含まれるため宣言できず、check.sh が実行時に HEAD として検査する
- R4（設計モデルの変更）: 同じ commit の中で check.sh / measure.sh と manifest を同時に書き換えると照合が通る（自己参照。R4 で再現）。evidence 層で 3 ラウンド続けて新しいクラスが出たため、継ぎ当てをやめた。check.sh / measure.sh は「再現手順」と位置づけ直す。**repo 内の照合が検出できるのは書き換え忘れだけで、改ざんは検出できない。** 信頼の起点は commit 外の記録（`reviewed_at_sha` とスクリプトの digest。PR 本文と handoff に書く）と Human C-4 である。manifest の sha256 は作成者の自己申告である
- R4 による計画からの逸脱: TC-08 の主張を縮小した。digest の一致は改ざんの検出力を持たないので、機械証跡ではなく書き換え忘れの検出として扱う。検査力のなかった「1 byte 変えると digest が変わる」テストは削除した（R4 info）
- R4-b: declared-me1 で `mergedAt` も照合する。R4-c: clean-tree が FAIL のときは、以降の検査を実行せず非 0 で終了する
- R5（evidence 層のラウンドを打ち切り。§7-quater の打ち切り方に従う）: R5-a として、独立再実行に停止条件を加えた。check.sh は期待する evidence head と measure.sh の digest を引数で受け取り、不一致なら何も実行せず exit 3 で止まる。R5-b として、照合を「VERIFY」から「REPRO-CHECK」に改名し、manifest / make-manifest.sh / regen.sh の文言を「再現手順」の位置づけに合わせた。R5-c として、記録欄はレビュアーが埋めるものとした
- T-10 の実施者を todo の「Codex」から Claude サブエージェント（作成者ではない別インスタンス）へ変更した。この端末での実施手段として Claude サブエージェントを用いたため。水準は I1（記録欄）
- 転記手順（作成者）: canon を commit → `sh docs/working/TASK-1408/evidence/regen.sh <base> <canon-sha>` → evidence を commit。照合と記録はレビュアーが行う（下記）

## 独立再実行の手順

**作成者以外（レビュアー）が実行し、記録する。** repo 内のスクリプトと本ファイルは信頼せず、commit 外の記録と照合してから使う。

1. 記録（PR 本文と handoff。レビュアーが記入する）から、evidence head、`reviewed_at_sha`、check.sh と measure.sh の sha256 を読む
2. **停止条件**。次のどれか 1 つでも不一致なら実行しない。
   - `git rev-parse HEAD` が記録の evidence head と一致する
   - `reviewed_at_sha` が evidence head と一致する
   - `git show HEAD:docs/working/TASK-1408/evidence/measure.sh | shasum -a 256` が記録値と一致し、check.sh も同様に一致する
3. 一致した check.sh を repo の外に取り出し、clean な checkout で `sh <取り出した check.sh> <base> <canon> <記録の evidence head> <記録の measure.sh sha256>` を実行する。check.sh 自身も、先頭で HEAD と measure.sh の digest を照合する（不一致なら exit 3）
4. 出力と rc を `evidence/independent-rerun.txt` に残す（実行者と context を明記する）

### 記録欄（レビュアーが PR 本文と handoff に記入する。作成者は埋めない）

| 項目 | 値 | 記録者 |
| --- | --- | --- |
| base | `9445df175e93fab31493274915bb35ab01cad4f1` | 宣言値（照合はレビュアー） |
| canon | `e5573cc89b76d5c493aa10d548d22ac7ed7abc2c` | 独立 worker（T-10） |
| evidence head | `6d1f7a6b5ff52cda320e7ed99fdb9ad0ccf3a311` | 独立 worker（T-10） |
| reviewed_at_sha | `6d1f7a6b5ff52cda320e7ed99fdb9ad0ccf3a311` | 独立 worker（T-10） |
| sha256 check.sh | `743b380b4a05412e132d0aaa0ad714a759328cbdaebe4e9babca2f2e5d83a5b1`（`git show 6d1f7a6b:` から取り出して実測。作成者申告値と一致） | 独立 worker（T-10） |
| sha256 measure.sh | `a6906024479b6aa2e08580150c978fdc6ee5c6d0a401131244a3767eb3a98353`（同上。一致） | 独立 worker（T-10） |
| check.sh の rc | **0**（REPRO-CHECK 11 項目 / TC-01〜09・11・E01・E01b・E02・E03 すべて exit=0）。陽性対照（evidence head に `2a6939fa`）は rc=3（STOP） | 独立 worker（T-10） |
| 出力の保存先 | session scratchpad `t10/check-output.txt` / `t10/check-negctl.txt`（repo 外）。check.sh の出力は `evidence/independent-rerun.txt` として repo に配置（`155ba058`） | 独立 worker（T-10） |
| 実施者 / 日時 | 独立 worker（作成者ではない Claude サブエージェント）/ 2026-11-12 08:36 | 独立 worker（T-10） |
| 記録した場所（PR 本文 / handoff） | status.md 本欄と handoff.md `evidence_head`。PR #1650 本文（2026-11-13 作成）の「独立再実行の記録」欄に転記済み | 独立 worker（T-10） |
| 独立性の水準 | **I1**（`evaluation-trust-boundary.md` §4 の定義「same model / separate context + role + run」に当たる。実施者は作成者と同一モデル系列の別インスタンスで、作成者の主張を使わず commit 内容から再実行した。I2 は separate model を要するので該当しない。canon §7「以後の I4 の最低要件」(1) の水準記録として書く） | 作成者（canon 定義との照合のみ） |

**TODO が 1 つでも残る間は C-4 に渡さない。** handoff でも同じ方針を取り、記録欄が埋まっていなければ I4 の機械証跡は「未充足」と書く。

## 残存脅威モデル

- **守るもの**: 書き換え忘れ（canon を変えたのに evidence を再生成しない、canon commit に別ファイルが混ざる、`canon^ ≠ base`、`canon..head` に canon 外の変更が入る、測定出力が古い）。これらは repo-check で検出する
- **守らないもの**: 改ざん。作成者は同じ commit の中で check.sh・measure.sh・manifest を一緒に書き換えられ、repo 内の照合はすべて通る。manifest の sha256 は自己申告である
- **改ざんへの防御**は次の 2 つだけである。(1) Human C-4。(2) 独立再実行者が上の手順（停止条件を含む）を守ること。どちらも人の手順遵守に依存し、機械で強制していない
- **作成者が記録欄を埋めた場合、防御にならない**（自己申告に戻る）
- 実行していない経路: CI では過去 SHA を検査しない。gh の値は GitHub の記録をそのまま信頼する
- **完全性は主張しない。** evidence 層の敵対レビューは R5 で打ち切った。新しいクラスが出なくなったからではなく、層の責務を「再現手順」に格下げし、信頼の起点を repo の外へ移したためである

### 回避クラス台帳（追記専用）

| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
| --- | --- | --- | --- | --- |
| 測定入力の非正規化 | 短縮 SHA と完全 SHA で出力が変わり、manifest を手書きしている | R2 | `rev-parse` で正規化。make-manifest.sh / regen.sh を追加 | R1 は文案と TC の内容を見ており、証跡の生成過程を検査対象にしていなかった |
| 固定対象の未宣言 | canon commit に別ファイルが混ざる、`C^ ≠ B`、別系統の C、stale evidence | R3 | manifest で宣言し、check.sh で全数照合 | R2 の是正は個々の値の一致だけを見ており、commit グラフとパス集合を対象にしていなかった |
| 自己参照 | 同じ commit で check.sh / measure.sh と manifest を同時に書き換えると通る | R4 | 再現手順へ格下げし、信頼の起点を commit 外の記録と C-4 へ移した | R3 は照合器自身を信頼の前提に置いており、照合器の改ざんを脅威に入れていなかった |
| 記録への照合なしの実行 | 記録された head より後の commit で改ざんした measure.sh を、記録済み check.sh で走らせると通る（r5.sh T1） | R5 | 停止条件（HEAD / reviewed_at_sha / digest）を手順と check.sh の引数に入れた | R4 は check.sh の digest だけを照合しており、実行時の HEAD と、check.sh が呼ぶ measure.sh を照合の対象にしていなかった |
