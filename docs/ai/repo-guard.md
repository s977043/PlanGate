# Repo Guard（pre-push テンプレート標準提供 / #684）

> issue [#684](https://github.com/s977043/plangate/issues/684) 実装。
> 関連: [`direct-push-prevention.md`](./direct-push-prevention.md)（TASK-0114
> / #360、既存の main 直 push block 実装）/
> [`../staged-adoption-guide.md`](../staged-adoption-guide.md)（フック有効化
> 推奨順）/ [`../../.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
> （Bash 連結コマンド時の error guard / merge boundary の正本）

## 背景

notionnext-blog の Memories / 実行履歴監査（2026-07-02）で、**リポジトリ操作
系の事故が反復**していることを確認した。

1. **gh CLI の active account ドリフト**: セッション中に gh の active
   account が別アカウントへ想定外に切り替わり、誤アカウントで push / PR
   操作をしかける事故。`docs/working/retrospective-*.md` に複数回記録
   （2026-04-30 〜 2026-05-31）。`scripts/gh-pin-account.sh`
   （SessionStart 時の pin）/ `scripts/gh-s977043.sh`（gh 操作直前の
   ラッパ）は plangate リポジトリ固有の対策として存在するが、**pre-push
   hook 側で検知する仕組みは存在しなかった**。
2. **main への直接 push**: AI エージェント（conductor）が main へ直接
   push した逸脱の実績（INC-2026-05-26-001）。TASK-0114（#360）で
   `scripts/templates/pre-push.sample` + `scripts/install-pre-push.sh`
   （`.git/hooks/pre-push` へ直接コピーする opt-in 方式）として対策済み。
3. **宣言と実装の乖離**: notionnext-blog 側の Memories には「pre-push hook
   で検知する」と対策が宣言されていたが、実際には `.git/hooks/` が空の
   ままだった。宣言だけで実装が伴わない状態を **doctor が検出できる
   仕組みが無かった**。

本 PBI は (1) の gh account 検証を pre-push hook に追加し、**PlanGate 資産
として repo guard を標準提供**することで、消費側リポジトリが個別実装せず
導入できるようにする。(3) の「宣言と実装の乖離」検出（doctor 連携）は
別途 follow-up とする（後述）。

## 既存実装（TASK-0114 / #360）との関係

| | `scripts/install-pre-push.sh`（TASK-0114） | `scripts/repo-guard/`（本 PBI） |
|---|---|---|
| 配線方式 | `.git/hooks/pre-push` へ直接コピー | `core.hooksPath` で `scripts/repo-guard` を指す |
| main 直 push block | ○ | ○（同等ロジックを踏襲） |
| gh account 検証 | なし | ○（`REPO_GUARD_EXPECTED_GH_LOGIN` 設定時） |
| 既存 hook との共存 | 既存 `.git/hooks/pre-push` を `.bak` 退避して上書き | `core.hooksPath` 変更により他ディレクトリの直接配置 hook は参照されなくなる（相互排他点として明示・下記「注意」参照） |
| 対象読者 | plangate リポジトリ自身 | plangate を導入する **消費側リポジトリ**（例: notionnext-blog）への標準配布を主眼 |

両者は機能的に重複するが、排他的な選択肢として提供する。**新規導入する
消費側リポジトリは `scripts/repo-guard/` を優先**し、`scripts/install-pre-push.sh`
は plangate 自身（および `core.hooksPath` 方式を採らない既存導入先）向けの
既存資産として維持する。

### 注意: `core.hooksPath` 併用時の相互排他

`core.hooksPath` を `scripts/repo-guard` に変更すると、Git は
`.git/hooks/` 配下の hook を **一切参照しなくなる**（`core.hooksPath` は
hook 探索先を完全に置き換える。追加ではなく上書き）。したがって
`scripts/install-pre-push.sh` で `.git/hooks/pre-push` を導入済みのリポジトリ
で `install-repo-guard.sh --apply` を実行すると、`.git/hooks/pre-push` は
以後実行されなくなる（`scripts/repo-guard/pre-push` に一本化される）。
`install-repo-guard.sh` は `--apply` 実行時にこの上書きを警告表示する。

## 提供物

| ファイル | 役割 |
|---------|------|
| [`../../scripts/repo-guard/pre-push`](../../scripts/repo-guard/pre-push) | pre-push hook テンプレート本体（実行可能シェル） |
| [`../../scripts/repo-guard/install-repo-guard.sh`](../../scripts/repo-guard/install-repo-guard.sh) | `core.hooksPath` 方式での配線 apply スクリプト（既定 dry-run） |

## pre-push テンプレートが防ぐこと

1. **protected branch への直接 push**（既定: `main master release/*`）。
   `local_sha` が全 0（SHA-1/SHA-256）の delete push はエッジケースとして
   許可（ブランチ削除は別意味の操作、GitHub 側の branch protection で
   別途保護する前提）。
2. **期待 gh account との不一致**（`REPO_GUARD_EXPECTED_GH_LOGIN` 設定時
   のみ有効化。未設定なら検証しない＝既定 opt-out）。`gh` 未導入環境では
   自動的に skip（誤ブロックしない）。不一致時の挙動は
   `REPO_GUARD_GH_MISMATCH_MODE`（既定 `block` / `warn` も選択可）。

## セットアップ手順

```sh
# 1. 差分プレビュー（既定・破壊的操作なし）
sh scripts/repo-guard/install-repo-guard.sh
# または明示的に
sh scripts/repo-guard/install-repo-guard.sh --dry-run

# 2. 内容を確認した上で実適用（Human が実行）
sh scripts/repo-guard/install-repo-guard.sh --apply
```

`--apply` は `git config --local core.hooksPath scripts/repo-guard` を
設定するのみで、`.git/hooks/` 配下のファイルは書き換えない（非破壊）。

### 期待 gh account の宣言（任意）

リポジトリルートに `.repo-guard.conf` を作成する（本スクリプトは自動生成
しない。値の宣言は人間が行う）:

```sh
# .repo-guard.conf
REPO_GUARD_PROTECTED_BRANCHES="main master release/*"
REPO_GUARD_EXPECTED_GH_LOGIN="<your-gh-login>"
REPO_GUARD_GH_MISMATCH_MODE="block"  # block | warn
```

`.repo-guard.conf` は個人環境依存の値（gh login 等）を含み得るため
`.gitignore` への追加を推奨する（チーム共通の protected branch 設定のみ
共有したい場合はコミットしても構わない）。

## 緊急 bypass

```sh
git push --no-verify
```

`--no-verify` は git client 標準の hook skip 機構。本 hook を含む全 git
hook を一律 skip するため監査ログに残らない。緊急時のみ使用し、最終防衛線
は GitHub branch protection（Human-owned admin 操作、
[`direct-push-prevention.md`](./direct-push-prevention.md) の Defense in
Depth 表を参照）に委ねる。

## staged-adoption-guide との接続

[`../staged-adoption-guide.md`](../staged-adoption-guide.md) の「1. フック
有効化の推奨順序」において、repo guard（本 PBI）は git hook レイヤーの
対策であり、`.claude/settings.json` の EH-1〜EH-9（Claude Code hook）とは
別軸で独立に導入できる。Phase 0（Day 1）からの早期導入を推奨する
（コード変更を伴わず、誤操作防止という性質上モード判定に依存しないため）。

## Follow-up: `plangate doctor` への統合（本 PBI 範囲外）

issue #684 は「`plangate doctor` に『必須 git hooks が導入済みか』の
チェック項目を追加」も要望しているが、`bin/plangate` は Hardening
Override 対象パス
（[`mode-classification.md`](../../.claude/rules/mode-classification.md)
の 9 カテゴリ正本）に該当し、**AI が直接編集できない**（常時 block、
[`project_ho_always_block.md`] 系の運用実績と整合）。

したがって、doctor への「repo guard 導入済みか」チェック追加は **別 PBI
として起票し、Standard モード・同期 C-3（人間承認）を経て実施する**。
本 PBI（#684）はテンプレート + apply スクリプト + 本仕様書までを scope と
し、doctor 連携は明示的に scope 外とする。

検証観点の候補（follow-up PBI 起票時の参考。本 PBI では実装しない）:

- `git config --local --get core.hooksPath` が `scripts/repo-guard` を
  指しているか
- `scripts/repo-guard/pre-push` が存在し実行可能か
- `.repo-guard.conf` の有無（未設定は WARN、gh account 検証が opt-out で
  あることの周知に留める・FAIL にはしない）
