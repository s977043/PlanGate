---
task_id: TASK-0914
artifact_type: handoff
schema_version: 1
status: draft
issued_at: 2026-08-02
author: qa-reviewer
v1_release: ""
---

# Handoff Package — TASK-0914

> **status: draft** = `bin/plangate doctor --check-settings` PASS（Human 実施）待ちのみ。V-1 独立検査は実施済み・**条件付き PASS**（§1）。doctor PASS 確定後に `status: final` へ更新する。
> mass-delete guard の 3 経路拡張（#877 follow-up）+ R-204: extras harness 判別の AND 統一 + standalone env 無害化。

## メタ情報

```yaml
task: TASK-0914
related_issue: https://github.com/s977043/plangate/issues/914
author: qa-reviewer
issued_at: 2026-08-02
v1_release: ""  # C-4 マージ後に commit SHA を記入
```

- Mode: **high-risk**（C-3 Human APPROVED 2026-08-02 12:40 / autonomous APPROVE 不可）
- ブランチ: `fix/914-mass-delete-guard`（exec 基点 = origin/main `f25ae8b`。plan 基点 `90c313d` からの前進差分は本 PBI 対象 3 領域に影響なし — status.md「計画からの変更点」）
- 実装完了 head: `ef65021`（T-01〜T-09）+ 記録コミット（T-10/T-11/handoff）

## 1. 要件適合確認結果

exec 内機械検証（T-06 / T-09 / T-11）と **V-1 独立検査（acceptance-tester・2026-08-02 実施）**の結果。V-1 は status.md「T-09」節の V-1-A / V-1-B / V-1-B' / AC-9 スニペットの独立再実行 + test-cases.md 全件突合で判定した（独立再実行の実測: ta-26 standalone **30/0**・V-1-A/B/B' 各 **64 PASS / NG 0**・AC-9 **残存 0 / 包含 MISSING=0**・フルスイート **467/0**・rc すべて 0）。

| 受入基準 | exec 内判定 | V-1 独立検査 | 根拠 / evidence |
|---------|------------|--------------|----------------|
| AC-1: 経路2（ai-loop refs）guard 発火 + `guard_fired` 経由 exit 3 | PASS | PASS（ta-26 standalone 30/0 再実行） | TC-20/21/22/25 PASS（`evidence/test-runs/t05a-tc20-25-standalone.log`）+ sandbox 手動再現（`evidence/verification/t03-path2-guard-repro.log`）+ M-1/M-3/M-4 変異で FAIL 実証 |
| AC-2: 経路1（汎用 refs）guard 発火 + exit 3 | PASS | PASS（ta-26 standalone 30/0 再実行） | TC-26/27/32 PASS（`t05b-tc26-34-standalone.log`）+ sandbox 再現（`t04-path1-guard-repro.log`）+ M-2/M-3/M-4/M-5 変異で FAIL 実証 |
| AC-3: 各経路の負側 + 正常系 TC が ta-26 に存在（検出力実証込み） | PASS | PASS（TC 存在は 30/0 内・変異 M 系は evidence-based — WARN ②） | 負側 TC-20/21/22/26/27・正常系 TC-24/29・境界 TC-34・dry-run 一致 TC-25/32 追加。変異 8 件（M-1〜M-7 + M-6b）全てで期待 FAIL 実測・空振り fixture 0（status.md「T-06 変異注入マトリクス」+ `t06-m{1..7,6b}-*.log` 8 本） |
| AC-4: `PLANGATE_ALLOW_MASS_DELETE=1` override が全経路一貫 | PASS | PASS（ta-26 standalone 30/0 再実行） | TC-23/28 PASS + 既存 TC-11/TC-15 PASS 維持。M-7（override 判定削除）で TC-23/28 + 既存 TC-11 が FAIL = 共通関数 1 箇所で全経路担保の裏付け（`t06-m7-override-removed.log`） |
| AC-5: `tests/extras/README.md` に判別規約明記 | PASS | PASS（ta-26 30/0 内 TC-30） | 規約 8（AND 判別 / 非 export / standalone 側 = 安全側 / 7 env unset / TC-33 言及）追記 + 規約 7 末尾是正（RV-m3）。TC-30 PASS（`t08-ta26-all30-pass.log`） |
| AC-6: 11 extras 移行後、フルスイート 0 failed + standalone 3 条件（①`[FAIL]` 不在 ②exit 0 ③`[PASS]` 件数 baseline 一致） | PASS | PASS（V-1-A 64 PASS / NG 0 + フルスイート 467/0・rc 0） | V-1-A: 64 PASS・NG 0・per-file baseline（T-01 表）全一致（`t09-v1a-clean.log`）。フルスイート **467 passed / 0 failed**（T-08 `t08-full-suite-467.log` / T-11 `t11-full-suite-clean.log`。todo 記載 444 は基点前進で 467 へ読み替え = status.md「計画からの変更点」） |
| AC-7: 汚染 env 下でも AC-6 と同結果 | PASS | PASS（V-1-B / V-1-B' 各 64 PASS / NG 0・rc 0） | V-1-B（6 env + `FIXTURES_DIR` 注入）+ V-1-B'（`PG_HARNESS_SOURCED` 単独）とも 64 PASS・NG 0・baseline 一致（`t09-v1b-contaminated.log` / `t09-v1bprime-single.log`）。移行前 NG_TOTAL=8 → 移行後 0 の対比で検出力証明（`t01-ac7-contaminated-pre.log`） |
| AC-8: exit code 伝播欠落の別 issue 起票 + 妥協点記録 | PASS | PASS（V-1-C 成果物確認。等価記述で実質充足 — WARN ①） | [#921](https://github.com/s977043/plangate/issues/921) 起票済（P1）+ W1/T-01 実測根拠を[コメント追記](https://github.com/s977043/PlanGate/issues/921#issuecomment-5155633541)（2026-08-02）。妥協点は本書 §4（R-309 の 2 点） |
| AC-9: `FIXTURES_DIR` 単独判別の残存 0 + unset 集合の包含（件数ハードコードなし・ta-26 も対象） | PASS | PASS（独立再実行: 残存 0 / 包含 MISSING=0・rc 0） | TC-33 PASS + TC-33 と独立の grep -L / awk 実装で残存 0・harness 7 env 集合の包含成立（対象 12 ファイル。`t09-ac9-static.log`） |
| （不変条件）`sync_dir` 経路の挙動が共通関数化で不変 | PASS | PASS（ta-26 standalone 30/0 再実行） | 既存 TC-08〜TC-17 全 PASS 維持（T-02 チェックポイント 16/16 → 最終 30/30。`t11-ta26-standalone.log`） |

**総合（exec 内）**: 9/9 AC PASS + 不変条件 PASS
**総合（V-1 独立検査）**: **条件付き PASS**（条件 = `bin/plangate doctor --check-settings` PASS 待ちのみ。テストケース側 FAIL 0）
**V-1 WARN 2 件**（いずれも判定を覆さない）: ① V-1-C の確認語「`exit $fail` 欠落」の字句は #921 本文に不存在だが、等価記述（伝播欠落の実測記述）で実質充足 ② 変異 M 系（M-1〜M-7 + M-6b）は evidence-based 検証（検査側のファイル編集禁止制約により、T-06 evidence ログ 8 本の突合で判定）
**FAIL / WARN の扱い**: テストケース側 FAIL 0（上記 WARN 2 件のみ）。**handoff 完了の前提 `bin/plangate doctor --check-settings` PASS は Human 待ち**（worktree 内は gitignored `.claude/settings.json` 非複製で構造的 FAIL。main checkout に settings.json 実在 2026-07-23 を確認済みのため Shadow Config ではないが、PASS 実測は main checkout 側での実行が必要 — §2）。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| extras standalone の exit code 伝播欠落（`fail > 0` でも exit 0。11 本に限らず extras 全般） | major | open（**#921** で追跡・本 PBI スコープ外 = 案 C） | Yes（#921 完了時に AC-6 判定を exit code ベースへ戻す） |
| 全変異で TC-13 が副次 FAIL する連鎖構造（TC-13 は子プロセスで ta-26 を再帰実行するため、他 TC の FAIL が必ず伝播する — W3/T-06 観察） | minor | accepted（構造どおりの挙動。単独原因の特定は「期待 FAIL TC」列で行う運用） | No |
| test-cases.md V-1-B' スニペットの env 引数順が BSD/GNU env 仕様（オプションは NAME=VALUE より前）に反し rc=127 で実行不可 | minor | workaround（status.md「計画からの変更点」の読み替え `env -u FIXTURES_DIR PG_HARNESS_SOURCED=1 sh "$f" </dev/null` で運用。C-3 承認後の plan 変更禁止のため原本未修正） | Yes |
| フルスイート総数の期待値が環境依存（ベースが 452/453/454 と振れる既知事象 #947・#942。worktree で ta-13 TC-17 が素通り / トピックブランチで ta-57 TC-14 が実行される） | minor | open（#947 / #942 で追跡。本 exec は worktree + トピックブランチで一貫して 453 ベース + 14 = 467/0 を実測） | No |
| `bin/plangate doctor --check-settings` が worktree 内で構造的 FAIL（gitignored `.claude/settings.json` が worktree に複製されない） | minor | open（**Human 待ち**: main checkout で PASS 実測 → handoff final 化の前提。V-1 独立検査は実施済み・条件付き PASS の残条件はこの PASS のみ） | No |
| 経路1 の stale 集計が dst 側 symlink を `[ -L ]` で除外する一方、削除ループは除外せず非対称（River Review F-1・test-cases E-7 の残穴が実測再現で確定） | minor | open（**#970** で起票済み・follow-up。C-3 plan_hash 束縛下の設計残穴のため本 PBI では変更しない。現リポジトリの該当 references/ に symlink 0 件で顕在化しない） | Yes（#970 で追跡） |
| `tests/extras/ta-54-ai-loop-link-selfcontained.sh` L43/L63 の `\|\| true` がスクリプト失敗を握りつぶす構造 | minor | accepted（**指示による仕様判断の記録**: ta-54 は #914 の対象 11 本〔ta-39/43/44/45/46/47/49/50/51/52/53〕に含まれず、#947 が追跡する既知の別件。本 PBI では変更しない） | No |
| guard の発火境界: `stale > base` のみ発火し、`stale == base`（== src）は非発火（正当な全量入れ替え同期を許容） | info | accepted（**仕様として意図した境界**。境界は TC-34 で固定し、`>=` への変異 M-6b が TC-34 で検出されることを実証済み） | No |
| 経路2 base 算出の未 quote `set --` が pathname 展開に晒される（River Review F-5） | info | accepted（対処不要判定: 対象が repo 管理下 docs ファイル名のため実害窓は無視できる） | No |

**Critical 課題の対応**: critical なし。

**鮮度（River Review F-4 更新・2026-08-04 再確認）**: main 前進（`f25ae8b` → `7bf5f5c`・変更 65 ファイル）とブランチ接触 48 ファイルの交差 **0** を再実測済み（直近の前進 = #972 dependabot workflows bump + #971 TASK-0874 plan。クリーンマージ見込み維持。マージ後のフルスイート総数は main 側変動により 467 から変わりうる）。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| **#921 完了時に AC-6 の判定を exit code ベースへ戻す**（代理判定〔`[FAIL]` 文字列不在 + `[PASS]` 件数 baseline 一致〕の解消） | 代理判定は exit code 伝播欠落が直る（#921 AC-6）までの暫定。恒久化させない | High | [#921](https://github.com/s977043/plangate/issues/921) |
| standalone preamble の共通化（7 env unset のインライン 12 ファイル重複の解消） | 論点 E-2（インライン）採用の代償。drift は AC-9 静的検査で機械検出できるため緊急性は低い（R-306 / U-3） | Low | — |
| test-cases.md V-1-B' スニペットの原本是正（env 引数順） | C-3 plan_hash 束縛下で原本を触れなかった。次に plan 系文書を正規手順で更新する機会に反映 | Low | — |
| `tests/extras/README.md`「現行テスト一覧」表のドリフト是正（53 本中 12 本のみ掲載） | #921 本文でも Out of scope とされた別の文書負債 | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| **案 C: 判別式統一 + env 無害化まで。exit code 伝播は #921 へ分離**（R-309 ①） | 同一 PBI で伝播まで実施（案 A/B） | 2026-07-25 Human 決定によるスコープ境界。**代償: 同一 11 ファイル（+README）を本 PBI と #921 で 2 回触る**（コンフリクト・二重レビューのコスト）。#921 に W1 実測根拠をコメント固定して引き継ぎコストを最小化 |
| **AC-6 を代理判定（`[FAIL]` 不在 + `[PASS]` 件数 baseline 一致）で検証**（R-309 ②） | exit code ベースの判定（「standalone が非ゼロ終了しない」） | 伝播欠落（#921）が残る間、exit code 判定は無条件成立で空振りする（R-301）。**代償: 代理判定が #921 完了まで恒久化** → §3 の V2 候補（High）で exit code ベースへ戻すことを明記 |
| 7 env unset を各 extras へインライン記述（論点 E-2） | 共有 preamble ファイル `_standalone-preamble.sh`（E-1） | ta-26 既存実装と同型（既存パターン準拠）。共有ファイルは `ta-*.sh` glob 外の新規ファイルで extras 自己完結の慣習を崩す。重複 drift は AC-9（`run-tests.sh` 集合 ⊆ 各 extras 集合）で機械検出 |
| 変異注入の復元元を W2 完了 head `1e1c074` に固定（todo 記載 `90c313d` から読み替え） | `git show 90c313d:` からの復元（plan 時点の表記） | 90c313d へ戻すと W1/W2 実装（guard 3 経路 + TC）ごと消えて変異と無関係の FAIL が出る。オーガナイザー指示 + decision-log 記録済み。全 8 サイクルで復元後 diff 空 + 30/0 復帰を実測 |

## 5. 引き継ぎ文書

### 概要

前段の #877（v8.18.0）で `sync_dir` 経路に入った mass-delete guard（fail-closed / exit 3 / `PLANGATE_ALLOW_MASS_DELETE` override）を、`scripts/sync-plugin-plangate.sh` に残っていた 2 つの削除経路 — 経路1（汎用 skill references）/ 経路2（ai-loop references）— へ共通関数 `_mass_delete_blocked()` として拡張した。あわせて R-204（外部 env 漏れによる誤判定）対策として、`tests/extras/` 11 本の harness 判別を `FIXTURES_DIR` 単独から **`PG_HARNESS_SOURCED` AND `FIXTURES_DIR`** へ統一し、standalone 分岐で 7 env を unset（片方欠けは standalone 側 = 安全側へ倒す）。

検証は新規 14 TC（ta-26 は 16 → 30 TC）+ **変異注入 8 件全てで期待 FAIL を実測**（空振り fixture なし）+ AC-6/7/9 の 3 独立ループ機械検証（64 PASS × 3・baseline 全一致）+ フルスイート **467 passed / 0 failed**。現状: **exec 完了・V-1 条件付き PASS（残条件 = doctor PASS の Human 実測のみ）・PR 未作成**。

### c3.json の顛末（承認トークンの保全記録）

`approvals/c3.json` は Human 発行（2026-08-02T03:37:59Z・CLI = `plangate approve`）→ 並行セッションの `git stash push -u` により untracked のまま作業ツリーから退避 → `stash@{0}^3`（untracked を保持する第 3 親）から非破壊抽出し、コミット `fb443e8` で tracked 化した（River Review F-2 解消）。教訓: **承認トークンは発行直後に tracked 化する**（untracked のまま置くと並行セッションの stash / clean に巻き込まれ、承認証跡が消失しうる）。

### 触れないでほしいファイル

- `scripts/sync-plugin-plangate.sh` の guard 3 箇所と閾値 `stale > base`: M-3（+100）/ M-6b（`>=`）で境界の両側を変異検証済み。閾値・呼び出し位置を動かすと 14 TC + 変異マトリクスの均衡が崩れる
- `tests/extras/ta-*.sh` の判別式（AND 化済み 12 ファイル）: TC-33 + AC-9 独立検査が静的に守っている。`FIXTURES_DIR` 単独判別へ戻すと即 FAIL する（意図された防御）
- `docs/working/TASK-0914/plan.md`: C-3 APPROVED の plan_hash 束縛下。編集すると EH-3 が mismatch 検知する
- `docs/working/TASK-0914/decision-log.jsonl`: append-only（既存行の編集・削除禁止）

### 次に手を入れるなら

- **V-1（実施済み・2026-08-02）**: acceptance-tester が test-cases.md 全件突合 + status.md「T-09」節の V-1-A / V-1-B / V-1-B' / AC-9 スニペット再実行で**条件付き PASS**（§1）。再実行時の注意はそのまま有効: **全ループ `sh "$f" </dev/null` 必須**（ta-50 が非 tty stdin 未リダイレクトで無限ハング — RV-M1）
- **残る完了条件（順に）**: ① `sh scripts/apply-claude-settings.sh` を **Human が実行**（AI は self-mod ガードで不可） → ② `bin/plangate doctor --check-settings` PASS を実測（§2） → ③ handoff frontmatter を `status: final` 化 → ④ PR 作成。high-risk のため V-2 / V-3 も必須（mode-classification フェーズ適用）
- アンチパターン: `scripts/sync-plugin-plangate.sh` の素実行禁止（検証は必ず sandbox 経由 = `_t26_mk_*_sandbox` ヘルパー）/ 変異検証の復元元に `HEAD:` を使わない（exec 中に移動する）/ 汚染注入で `PG_HARNESS_SOURCED` と `FIXTURES_DIR` を同時に立てない（harness 分岐へ入り検証が消える — RV-M2）

### 参照リンク

- 親 issue: [#914](https://github.com/s977043/plangate/issues/914) / follow-up: [#921](https://github.com/s977043/plangate/issues/921) / 前段: [#877](https://github.com/s977043/plangate/issues/877)（PR #915）
- status.md: [`docs/working/TASK-0914/status.md`](./status.md)（T-01 baseline 表 / T-06 変異マトリクス / T-09 検証コマンド全文 / 計画からの変更点）
- plan: [`plan.md`](./plan.md) / [`todo.md`](./todo.md) / [`test-cases.md`](./test-cases.md) / C-2: [`review-external.md`](./review-external.md)

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| ta-26 standalone（guard TC: 既存 16 + 新規 14） | 30 | 30 | 0 | — |
| 移行 11 本 standalone（V-1-A / V-1-B / V-1-B' の 3 独立ループ） | 64 × 3 | 192 | 0 | — |
| フルスイート `sh tests/run-tests.sh`（T-11 / clean env） | 467 | 467 | 0 | — |
| 変異注入（M-1〜M-7 + M-6b） | 8 変異 | 8/8 で期待 FAIL 実証 | 空振り 0 | — |
| 静的検査（TC-30 / TC-33 + AC-9 独立実装） | 3 検査 | 3 | 0 | — |

**FAIL / SKIP の詳細**: テスト FAIL なし。`doctor --check-settings` の worktree 内 FAIL は環境制約（§2）でありテスト失敗ではない。T-05c 時点の TC-30/33 FAIL は TDD RED（実行順による想定内・T-07/T-08 で PASS 転化を対比実測済み — status.md「計画からの変更点」）。

## 7. Metrics summary（任意）

該当なし（本 run では `bin/plangate metrics` を未 collect）。
