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

## release プロセス (Human オペレーション)

```text
PR merge 完了 (develop → main)
  ↓
tag push
  ↓
🚪 TAG-MAIN PARITY 検証 (Iron Law)  ← scripts/check-tag-main-parity.sh
  ↓ 一致
GitHub Release 作成
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
```

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
| 8 | `docs/changelog.md` | 更新**不要**（release published 後に `release-docs-sync` が自動 PR） |

検証: `tests/extras/ta-28-plugin-version.sh`（2〜4 を機械検査。1・5・6・7 は未カバー —
リリース準備 PR のレビュー観点として本表で担保する。ta-28 の 1/6 カバー拡張は V2 候補）。

## リリース後の workflow run 結果確認（#950）

release published を起点とする自動 workflow は**失敗しても通知されず、成果物の欠落で
初めて発覚する**。v8.17.0 / v8.17.1 / v8.18.0 では `release-docs-sync`（version 同期
マップ #8 の自動 PR）が権限エラーで 3 リリース連続失敗し、`docs/changelog.md` が
2 世代欠落するまで誰も気づかなかった（issue #950）。GitHub Release 作成後、以下を
リリース手順の一部として必ず確認する:

```sh
# release-docs-sync の直近 run が success であること
gh run list --workflow=release-docs-sync.yml --limit 1
# → conclusion が failure なら下記リカバリへ
```

### 失敗時のリカバリ

同期ブランチ（`chore/release-docs-sync-*`）は PR 作成前の push まで成功していることが
多い。その場合は push 済みブランチから手動で PR を作成する（v8.18.0 時の実績: PR #949 方式）:

```sh
gh pr create --base main --head chore/release-docs-sync-<run_id> \
  --title "chore(docs): リリース時 changelog 同期 (<tag>)"
```

> 注: `sync-plugin-plangate.yml` も drift 検知時に自動 PR（`chore/plugin-sync-*`）を
> 作成する同型 workflow のため、同じ確認（`--workflow=sync-plugin-plangate.yml`）で兼ねられる。
