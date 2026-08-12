# Release Process — NO RELEASE WITHOUT TAG-MAIN PARITY

> Iron Law for PlanGate release (TASK-0116 / #354)。
> annotated tag が指す commit と `origin/main` の不一致を構造的に防ぐ。

## Iron Law

```text
NO RELEASE WITHOUT TAG-MAIN PARITY
```

意味:

- **リモート tag 実体**（`git ls-remote origin refs/tags/<tag>` の peel 先 commit）と `git rev-parse origin/main` が **完全一致** するまで GitHub Release を作成しない
- 判定基準はローカル tag の `rev-parse` ではなく **リモート実体（ls-remote）照合**（#783 R-005。ローカル tag は貼り替え済み・リモートは旧 commit のままでも、公開されるのはリモート tag のため）
- 一致しない場合は `git push --force-with-lease=<ref>:<期待値>` で貼り替え (Human オペレーション)
- 検証コマンドの実行ログを `status.md` / release note に記録

> **注**: 本検証はリリース時ゲート。リリース後に main が進んだ状態での再実行は MISMATCH になる（仕様）。

## 背景

annotated tag を打った後、tag が指す commit と `origin/main` の最新が一致しない事態が過去に発生:

- `git tag -a v0.X.Y <SHA>` の SHA を誤って打つ (develop の HEAD を指す等)
- annotated tag のオブジェクト SHA と commit SHA を混同して検証スキップ
- 同日複数リリースで tag → main のズレに気づかず GitHub Release 作成

これらは「リリース完了」報告後に発覚すると rollback / tag 削除 / 再 push の手戻りが発生し、本番障害の温床になる。

## リリース判定とオーケストレータの役割（定期リリースを回すため）

> 「どう出すか」（以降の節）の前段。**「いつ出すか」を毎回その場の勘で決めない**ための判定基準と担当。
> 実例: [`docs/working/_merge/v8.19.0-release-runbook.md`](working/_merge/v8.19.0-release-runbook.md)。

### 判定サイクルと判定基準

**前回タグから 7 日経過するごとに、オーケストレータが「リリース要否」を 1 回判定する**（判定であってリリース確定ではない）。7 日は実測の中央値: v8.6.0〜v8.18.0 の minor 間隔（同日リリースを除く 10 区間）は 13 / 10 / 5 / 2 / 4 / 4 / 9 / 13 / 4 / 18 日で、median 7 日・mean 8.2 日・max 18 日。

判定は以下で行う。**時間だけでトリガーしない**（空リリースが出る）:

| 判定 | 条件 | 備考 |
|------|------|------|
| **出す** | 前回タグから **14 日以上**経過 かつ `plugin/` 配下に未リリース変更あり | 実測 max（18 日）と median（7 日）の間。滞留の上限 |
| **出す** | 導入側の挙動が変わる変更がマージされた（hook の fail-closed 化・既定 ON の新規 hook・schema / CLI の互換性に触れる変更） | 経過日数によらず即。semver 判定も同時に要る |
| **出す** | 機能単位の区切り（EPIC / 親 PBI の完了、まとまった機能群の main 収束） | 日数より区切りを優先 |
| **見送る** | `plugin/` 配下の未リリース変更が 0、かつ差分が doc-only | [`mode-classification.md`](../.claude/rules/mode-classification.md) doc-light「doc-only で単独 tag / Release を切らない」と整合 |

> **`plugin/` 変更の有無を単独のトリガーにはしない**（実測: plugin 同梱後の v8.11.0 以降 **9 区間すべて**で `plugin/` に変更あり = ほぼ常に真）。**空リリース防止のガード**としてだけ機能させ、発火軸は経過日数と機能の区切りに置く。

### オーケストレータの責務（AI-owned）

| # | 責務 | 具体 |
|---|------|------|
| 1 | **要否判定** | 上表を `git log <前回タグ>..origin/main` / `git diff --stat <前回タグ>..origin/main -- plugin/` の実測に当てて判定し、見送る場合も理由を残す |
| 2 | **収録内容の決定** | 未リリース差分から CHANGELOG エントリを起こし、導入側に影響する変更を「⚠️ 更新前に必ずお読みください」相当の警告節に切り出す |
| 3 | **semver の材料提示** | [`docs/ai/versioning-stability-policy.md`](ai/versioning-stability-policy.md) §2 に照らし major / minor / patch の**材料**を提示する（決定はしない → 下記） |
| 4 | **準備一式** | 「version 同期マップ」の全箇所 bump（HO パスは apply スクリプト提示まで）、リリース手順書の作成、Human が実行するコマンドの提示 |
| 5 | **調整** | 未マージで収録したい PR の洗い出し、リリース前に入れる / 入れないの切り分け、CHANGELOG の分岐記述 |

### Human-owned の境界（再定義しない）

`git push origin <tag>` / `gh release create` / HO パスの適用 / **semver の最終決定** は
[`.claude/rules/responsibility-classes.md`](../.claude/rules/responsibility-classes.md)
§対外公開アーティファクト publish 責務分界 に従い **Human-owned**。本節はその分界を変えず、
**「誰がいつ判定して準備するか」だけ**を足す。

### semver で規約と裁定が食い違った場合

規約（`versioning-stability-policy.md` §2）が major を示す変更に対し Human が minor と裁定することがある。このとき:

1. **規約を書き換えて辻褄を合わせない**（規約改定は当該リリースの越権）
2. リリース手順書に **裁定の経緯**（規約の該当行 / 提示した材料 / 判定者 / 判定日 / 裁定内容）を記録する
3. **残る不整合を明示**し、解消方法（例外条項を設ける / 一度きりの裁定として以後は規約どおり）を follow-up として残す
4. 緩和措置（CHANGELOG の警告節・`[MIGRATION REQUIRED]` タグ付与）を実施する

実例: v8.19.0（EH-13 の `exit 1` → `exit 2` fail-closed 化は §2.2 で major、Human 裁定は minor。runbook §1 に記録）。

### 判定を怠るとどうなるか

`plugin/` 配下は **リリース版（`marketplace.json` の version）で配布される**。version bump のない更新は導入側で no-op となるため、**未リリースの plugin 改善は自分たちでも次リリースまで使えない**。

実測（2026-08-13 時点 / `origin/main` = `9289ba7`）: v8.18.0（2026-07-31）から **13 日 / 72 マージ / 430 ファイル**、うち **`plugin/` 配下 25 ファイル**が未リリースで滞留した。これは実測 median（7 日）の約 2 倍で、滞留中に作った plugin skill の改善を作業側が使えない状態が続いた。リリース判定を定期化するのは、この滞留を検出可能にするため。

## release プロセス (Human オペレーション)

```text
PR merge 完了 (develop → main)
  ↓
tag push
  ↓
🚪 TAG-MAIN PARITY 検証 (Iron Law)  ← scripts/check-tag-main-parity.sh
  ↓ 一致
GitHub Release 作成
  ↓
🚪 release-docs-sync run 確認  ← 失敗しても通知されない (#950)
```

### 必須検証手順

```sh
# 1. tag push
git push origin <tag>

# 2. Iron Law: tag = main 検証 (R-001: 内部で git fetch origin main 実施、
#    R-005: git ls-remote でリモート tag 実体を照合)
sh scripts/check-tag-main-parity.sh <tag>
# → OK: tag '<tag>' (origin 実体) = origin/main (<sha>)  なら次へ
# → MISMATCH / FAIL なら下記フローで貼り替え

# 3. GitHub Release 発行 (Human-owned。2 が OK になるまで実行しない)
#    note は AI が用意した確定 release note（例: docs/working/_reports/<version>-release-note-draft.md）
gh release create <tag> --title "<tag> — <リリース見出し>" --notes-file <確定 release note>
# → 発行と同時に release published 起点の workflow（release-docs-sync）が発火する

# 4. リリース後: release 起点の自動 workflow の run 結果確認
#    （失敗しても通知されない。詳細・リカバリは「リリース後の workflow run 結果確認（#950）」節）
gh run list --workflow=release-docs-sync.yml --event=release --limit 1
# → conclusion が success なら完了。failure なら同節のリカバリ手順へ
```

`gh release create` の実行は
[`.claude/rules/responsibility-classes.md`](../.claude/rules/responsibility-classes.md)
「対外公開アーティファクト publish 責務分界」により **Human-owned**（AI は release note
整備とコマンド提示まで）。

## 失敗時のフロー (MISMATCH 検出時)

`scripts/check-tag-main-parity.sh` が MISMATCH を返した場合:

```sh
# 1. origin/main の正しい SHA を確認
git fetch origin main
git rev-parse origin/main

# 2. annotated tag を作り直し (R-004: annotated を ^{commit} で peel 可能に)
git tag -fa <tag> origin/main -m "release <tag>"

# 3. リモート tag オブジェクト SHA (ls-remote の un-peeled 行) を確認
git ls-remote origin refs/tags/<tag>

# 4. remote tag を --force-with-lease (期待値=リモート tag オブジェクト SHA) + ref 明示で上書き (R-002)
#    注: annotated tag では期待値に peeled commit SHA を使うと必ず stale info で拒否される。
#    期待値なしの --force-with-lease も tag では remote-tracking 参照がなく機能しない。
#    check-tag-main-parity.sh が MISMATCH 時にこの形式のコマンドをそのまま出力する。
git push --force-with-lease=refs/tags/<tag>:<リモートtagオブジェクトSHA> origin refs/tags/<tag>:refs/tags/<tag>

# 5. 再検証 → 一致するまで GitHub Release 作成禁止
sh scripts/check-tag-main-parity.sh <tag>
```

### --force-with-lease の理由 (R-002)

通常の `git push -f` ではなく `--force-with-lease=<ref>:<期待値>` + ref 明示 (`refs/tags/<tag>:refs/tags/<tag>`) を使う:

- `--force-with-lease=<ref>:<期待値>`: remote 側が想定外に進んでいた場合に上書きを拒否 (他者の変更保護)。期待値は **リモート tag オブジェクト SHA**（ref の格納値。annotated tag では commit でなく tag オブジェクト）
- ref 明示: 誤って別 ref を push するリスク排除
- Human オペレーション + 監査ログ + 対象 tag 再確認 の段階フロー

## 承認境界 (R-003)

| 操作 | 担当 |
|------|------|
| `scripts/check-tag-main-parity.sh` 実装 | AI (新規 file、Hardening Override 対象外) |
| `.claude/rules/responsibility-classes.md` §publish 責務分界 への link 追記 | AI (Hardening Override、c3.json APPROVED + plan_hash 一致で適用) |
| tag push / `--force-with-lease` 貼り替え / GitHub Release 作成 | **Human-owned** (`responsibility-classes.md` §対外公開アーティファクト publish 責務分界) |

## tag 種別 (R-004)

| tag 種別 | 動作 (リモート照合 / #783 R-005) |
|---------|------|
| annotated tag (`git tag -a`) | `git ls-remote origin "refs/tags/<tag>" "refs/tags/<tag>^{}"` の **peel 行** (`refs/tags/<tag>^{}`) の SHA を commit として採用 |
| lightweight tag (`git tag`) | peel 行が現れないため **un-peeled 行** (`refs/tags/<tag>`) の SHA を採用 (直接 commit を指す) |

両者ともリモート実体の peel 先 commit を `origin/main` と比較する。

## CI 化 (V2 候補)

現状は Human オペレーション + script による機械検証。将来 `bin/plangate doctor --scope release` 等への統合は V2 候補 (本 PBI では stretch AC-7 として削除済)。

## 関連

- Issue: [#354](https://github.com/s977043/plangate/issues/354)
- 検証 script: [`scripts/check-tag-main-parity.sh`](../scripts/check-tag-main-parity.sh)
- 責務分界: [`.claude/rules/responsibility-classes.md`](../.claude/rules/responsibility-classes.md) §対外公開アーティファクト publish 責務分界
- 参考: PocketEitan `.claude/commands/release.md` Phase 5 / memory `feedback_release_tag_collision_verify.md`

## version 同期マップ（リリース準備 PR で更新する箇所の正本）

リリース準備 PR（AI-owned）で以下を**全箇所同時に**対象 version へ更新する。
1 箇所でも漏れると「Latest 表記の drift」となる（v8.13.0 の README 漏れ・
v8.16.0 の README_en 漏れ（レビューで水際検出）が実害・ヒヤリの実例）:

| # | ファイル | 箇所 |
|---|---|---|
| 1 | `CHANGELOG.md` | `## vX.Y.Z (date)` 節の確定（Unreleased を残す） |
| 2 | `plugin/plangate/.claude-plugin/plugin.json` | `version` |
| 3 | `.claude-plugin/marketplace.json` | `plugins[].version` と `metadata.version` の両方 |
| 4 | `README.md` | 「最新リリース」表の行 + 冒頭散文 + 「リリース済」行 |
| 5 | `README_en.md` | 同上（英語） |
| 6 | `plugin/plangate/README.md` | `**Version**:` 行 |
| 7 | **`CLAUDE.md`「最新リリース」節** | **HO パスのため AI は apply スクリプト提示まで・適用は Human**（`sh scripts/apply-claude-md-*.sh --apply`。v8.14〜8.16 で 3 世代 stale になった構造原因への対策として本表に常設） |
| 8 | `docs/changelog.md` | 更新**不要**（release published 後に `release-docs-sync` が自動 PR。**リリース後に run 結果確認 — 本書末尾「リリース後の workflow run 結果確認」参照**） |

検証: `tests/extras/ta-28-plugin-version.sh`（2〜4 を機械検査。1・5・6・7 は未カバー —
リリース準備 PR のレビュー観点として本表で担保する。ta-28 の 1/6 カバー拡張は V2 候補）。

## リリース後の workflow run 結果確認（#950）

release published を起点とする自動 workflow は**失敗しても通知されず、成果物の欠落で
初めて発覚する**。v8.17.0 / v8.17.1 / v8.18.0 では `release-docs-sync`（version 同期
マップ #8 の自動 PR）が権限エラーで 3 リリース連続失敗し、`docs/changelog.md` が
2 世代欠落するまで誰も気づかなかった（issue #950）。GitHub Release 作成後、以下を
リリース手順の一部として必ず確認する:

```sh
# release 起点の直近 run が success であること
# （--event=release 必須: 本 workflow は workflow_dispatch トリガーも持つため、
#   素の --limit 1 では手動 dispatch の run を拾い release 起点の失敗を見逃す）
gh run list --workflow=release-docs-sync.yml --event=release --limit 1
# → conclusion が failure なら下記リカバリへ
```

### 失敗時のリカバリ

同期ブランチ（`chore/release-docs-sync-*`）は PR 作成前の push まで成功していることが
多い。その場合は push 済みブランチから手動で PR を作成する（v8.18.0 時の実績: PR #949 方式）。
`--title` / `--body` は**両方指定する**（どちらか欠けると `gh pr create` はタイトル / 本文の
入力プロンプトを開き、非対話環境では止まる）。本文は workflow 側
（`release-docs-sync.yml` L41-43）が渡す内容に揃え、手動作成である旨のみ追記している:

```sh
gh pr create --base main --head chore/release-docs-sync-<run_id> \
  --title "chore(docs): リリース時 changelog 同期 (<tag>)" \
  --body "release-docs-sync run <run_id> が PR 作成権限エラーで失敗したため、生成済み同期ブランチから手動作成（#950 runbook）。内容は \`scripts/sync-release-docs.sh\` による \`docs/changelog.md\` の冪等生成物。merge は Human-owned（C-4）。"
```

> 注: `sync-plugin-plangate.yml` も drift 検知時に自動 PR（`chore/plugin-sync-*`）を
> 作成する同型 workflow。ただしトリガーは release published ではなく
> `push`（main）/ `pull_request` / `workflow_dispatch` の 3 種で、PR を作らない
> drift-check のみの `pull_request` run が混在する（`sync` job は
> `github.event_name != 'pull_request'` 条件）— 確認は
> `gh run list --workflow=sync-plugin-plangate.yml --event=push --limit 1` で
> event=push の run を見ること。
