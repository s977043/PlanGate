# Repo Guard（pre-push guard + gh account 検証 / #684）

> issue [#684](https://github.com/s977043/plangate/issues/684) 実装。
> 関連: [`direct-push-prevention.md`](./direct-push-prevention.md)（TASK-0114
> / #360、protected branch 直 push block の**正本**）/
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
   ラッパ）は plangate リポジトリ固有の対策として存在するが、**push の
   最終地点（pre-push hook）で account を検証する仕組みは無かった**。
2. **protected branch への直接 push**: AI エージェント（conductor）が
   main へ直接 push した逸脱（INC-2026-05-26-001）。
   **TASK-0114（#360）で既に実装済み**（下記）。
3. **宣言と実装の乖離**: notionnext-blog 側の Memories には「pre-push hook
   で検知する」と対策が宣言されていたが、実際には `.git/hooks/` が空の
   ままだった。pre-push guard は #360 で提供済みだが、**install が opt-in
   のため導入されていない**と、宣言だけで実装が伴わない状態になる。

## protected branch guard は #360 が正本（本 PR で新規実装しない）

protected branch（`main master release/*`）への直接 push block は
**TASK-0114 / #360 が正本**であり、本 PR では新規実装しない（DRY）。既存資産:

| ファイル | 役割 |
|---------|------|
| [`../../scripts/templates/pre-push.sample`](../../scripts/templates/pre-push.sample) | pre-push hook テンプレート本体（battle-tested。Gemini bot R-001/R-002 反映で noglob / SHA-1・SHA-256 zero hash 対応済み） |
| [`../../scripts/install-pre-push.sh`](../../scripts/install-pre-push.sh) | `.git/hooks/pre-push` への opt-in install（既存 hook は `.bak` 退避・冪等） |

詳細な設計・bypass・Defense in Depth は
[`direct-push-prevention.md`](./direct-push-prevention.md) を参照。

## 本 PR の新規貢献

### 1. gh account ドリフト検証の opt-in 追加

`scripts/templates/pre-push.sample` の末尾（protected branch チェックの
**後**）に、環境変数 `REPO_GUARD_EXPECTED_GH_LOGIN` が設定されている場合
**のみ**動く gh account 検証ブロックを追記した。既存の battle-tested
ロジック（`set -eu` / `set -f` / stdin parse ループ）は一切変更していない。

| 条件 | 挙動 |
|------|------|
| `REPO_GUARD_EXPECTED_GH_LOGIN` 未設定 | **完全に no-op**（既存挙動と不変） |
| `gh` CLI 未導入 | skip（誤ブロックしない） |
| `gh api user --jq .login` が判定不能 | skip（失敗は握りつぶす） |
| 期待値と一致 | 通過 |
| 期待値と不一致 | **push を block（exit 1、理由メッセージ）** |

判定は stdin parse ループの**後に 1 回だけ**行う（push 対象 ref に依存
しないため）。誤爆でブロックしすぎない安全側設計。

### 2. doctor による hook 導入検証（follow-up・HO・別 PBI）

後述の「Follow-up」参照。本 PR の scope 外。

## セットアップ手順（宣言↔実装乖離の是正）

「pre-push で検知する」という宣言を**実装が伴う状態**にするには、opt-in
install の実行と（任意で）gh 検証の有効化を行う:

```sh
# 1. pre-push guard を実際に配線する（#360 の opt-in install を実行）
sh scripts/install-pre-push.sh --dry-run   # 差分確認
sh scripts/install-pre-push.sh             # 実 install（Human が実行）

# 2. （任意）gh account ドリフト検証を有効化する
#    push 時に active account が期待値と一致するか検証したい場合、
#    環境変数 REPO_GUARD_EXPECTED_GH_LOGIN を設定する。
#    永続化するには shell profile か、リポジトリローカルの仕組みで宣言する:
export REPO_GUARD_EXPECTED_GH_LOGIN="<your-gh-login>"   # 例: s977043
```

`REPO_GUARD_EXPECTED_GH_LOGIN` は個人環境依存（gh login）のため、環境変数
として宣言する（コミットしない）。未設定なら gh 検証は無効＝既存挙動のまま。

### protected branch のカスタマイズ

protected list の override は既存どおり `PLANGATE_PROTECTED_BRANCHES` で
行う（[`direct-push-prevention.md`](./direct-push-prevention.md) 参照）。

## 緊急 bypass

```sh
git push --no-verify
```

`--no-verify` は git client 標準の hook skip 機構。本 hook（protected
branch guard + gh 検証）を含む全 git hook を一律 skip する。緊急時のみ使用
し、最終防衛線は GitHub branch protection（Human-owned admin 操作）に委ねる。

## staged-adoption-guide との接続

[`../staged-adoption-guide.md`](../staged-adoption-guide.md) の「1. フック
有効化の推奨順序」において、pre-push guard は git hook レイヤーの対策で
あり、`.claude/settings.json` の EH-1〜EH-9（Claude Code hook）とは別軸で
独立に導入できる。誤操作防止という性質上モード判定に依存しないため、
Phase 0（Day 1）からの早期 install を推奨する。

## Follow-up: `plangate doctor` への統合（本 PR 範囲外）

issue #684 は「`plangate doctor` に『必須 git hooks が導入済みか』の
チェック項目を追加」も要望しているが、`bin/plangate` は Hardening
Override 対象パス
（[`mode-classification.md`](../../.claude/rules/mode-classification.md)
の 9 カテゴリ正本）に該当し、**AI が直接編集できない**（常時 block）。

したがって、doctor への「pre-push guard 導入済みか」チェック追加は **別
PBI として起票し、Standard モード・同期 C-3（人間承認）を経て実施する**。
本 PR（#684）は pre-push.sample への gh 検証 opt-in 追加 + 本仕様書までを
scope とし、doctor 連携は明示的に scope 外とする。

検証観点の候補（follow-up PBI 起票時の参考。本 PR では実装しない）:

- `.git/hooks/pre-push`（または `core.hooksPath` 配下）が存在し実行可能か
- `install-pre-push.sh` 由来の内容と一致するか（宣言↔実装乖離の機械検出）
- `REPO_GUARD_EXPECTED_GH_LOGIN` が設定されているか（未設定は WARN・
  gh 検証が opt-out であることの周知に留め、FAIL にはしない）
