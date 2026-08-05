# TEST CASES — TASK-0970

> 入力: [`plan.md`](./plan.md)
> 実装先: `tests/extras/ta-26-plugin-sync.sh`（既存 TC-01〜TC-34 の 30 本は非退行。新規は **TC-35** の 1 本）
> 基点: `origin/main` = `a952872`（baseline: `sh tests/run-tests.sh` = 537 passed / 0 failed）

## 共通の実装規約

- 既存 TC-26〜TC-34 と同型: `mktemp -d` + `register_cleanup` + 末尾早期 `rm -rf`（冪等）。trap は使わない
- 変数は `_t26_` / `PG_T26_` プレフィクス
- 非ゼロ rc の捕捉書式は `tests/extras/README.md` 規約 4 の正書式: `rc=0; out="$(cmd)" || rc=$?`
- **`_t26_mk_refs_guard_sandbox` のシグネチャは変更しない**（既存 30 TC への巻き添えを避ける）。
  symlink は同ヘルパー呼び出しの**後**に sandbox へ追加注入する
- symlink の target は sandbox 内の同期対象外ディレクトリに置く（sync の走査に混入させない）
- 実行は clean env（`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_FILE` / `PG_HARNESS_SOURCED` /
  `FIXTURES_DIR` / `PLANGATE_ALLOW_MASS_DELETE` を unset）+ `sh <file> </dev/null`

## 受入基準 → テストケース マッピング

| AC | 内容 | テストケース |
|----|------|------------|
| AC-1 | 経路1 の stale 集計集合と削除集合が厳密一致（symlink の扱いが両者で同一） | TC-35 |
| AC-2 | TC が修正前実装に対して FAIL する（検出力証明） | TC-35 + 変異注入 **M-1** |
| AC-3 | 既存 ta-26 全 TC（30 本）が PASS を維持 | TC-R（回帰実行） |
| AC-4 | `sh tests/run-tests.sh` が baseline を維持 | TC-B（baseline 実行） |

## テストケース一覧

### TC-35（新規・AC-1 / AC-2）— 経路1: 解決可能 symlink stale を集計に含める

| 項目 | 内容 |
|------|------|
| 前提 | sandbox（`_t26_mk_refs_guard_sandbox "$SB" 3 3 skill-A` = src 通常 3 / dst に通常 stale 3・dst mirror 3）に対し、sandbox 内 targets ディレクトリへ実体 2 件を作り、それを指す symlink `link-1.md` / `link-2.md` を dst references/ へ追加注入する（= 解決可能 symlink stale 2 件） |
| 入力 | `rc=0; out="$(sh "$SB"/scripts/sync-plugin-plangate.sh 2>&1)" \|\| rc=$?` |
| 期待 | ① `rc = 3`（guard 発火の終端 exit） / ② 出力に `base=3 / stale=5` を含む（**集計が symlink 2 件を含む**ことの直接検査） / ③ 出力に `DELETE skipped for skills/skill-A/references` を含む / ④ dst references/ の残存 **8 件**（通常 stale 3 + symlink 2 + mirror 3。1 件も削除されない） / ⑤ symlink の target 実体 2 件が非破壊で残存 |
| 種別 | Integration（自動） |
| 検出する欠陥 | 集計が symlink を除外し `stale=3` と数えるため `3 > 3` が偽 → 非発火のまま 5 件削除・rc=0 になる（#970 の残存窓） |

**「集計 = 削除」の厳密一致をどう突いているか**: 期待 ② が集計値（stale=5）を、
期待 ④ が削除集合（本来消えるはずだった 5 件）を、それぞれ独立に固定する。
両者が乖離する実装（現行）では ② が `stale=3` となり ①③④ も同時に崩れる。

### TC-35 の副次検査（同一 TC 内・ダングリング symlink が集計に入らない）

| 項目 | 内容 |
|------|------|
| 前提 | 上記 sandbox に、target が存在しない symlink `dangling-1.md` を dst references/ へ追加（dst 計 9 件） |
| 入力 | 同上 |
| 期待 | `base=3 / stale=5` が**変わらない**（`[ -f ]` が偽のため集計に入らない）。`rc = 3`・dst 残存 **9 件** |
| 種別 | Integration（自動） |
| 意図 | 「symlink を一律に集計へ入れる」誤実装（`[ -f ]` を `[ -e ]` に緩める等 = M-3）との差を、集計値の文字列一致で固定する |
| **担保しない範囲（明示）** | 本 fixture は guard 発火側のため、**削除ループ側のダングリング除外までは実証しない**（削除自体が保留されるため）。削除ループの `[ -f ]` は集計ループと同一条件式であることを差分レビュー（AC-1）で確認する |

### TC-R（回帰・AC-3）— 既存 ta-26 の非退行

| 項目 | 内容 |
|------|------|
| 前提 | 修正後の作業ツリー |
| 入力 | `sh tests/extras/ta-26-plugin-sync.sh` |
| 期待 | **31 PASS / 0 FAIL**（既存 30 + TC-35）・exit 0 |
| 種別 | Integration（自動） |
| 特記 | 特に TC-29（base=3/stale=1 の非発火）/ TC-32（乖離帯 dry-run 一致）/ TC-34（base=stale 同数の境界）は symlink を含まない fixture のため、本修正で判定が変わってはならない |

### TC-B（回帰・AC-4）— 全系 baseline

| 項目 | 内容 |
|------|------|
| 前提 | 修正後の作業ツリー |
| 入力 | `sh tests/run-tests.sh` |
| 期待 | **538 passed / 0 failed**（baseline 537 + 新規 1）・exit 0 |
| 種別 | E2E（自動） |
| 特記 | baseline は exec 開始時に現 main で再実測した値を正とする（ドリフト時は再測値 +1 が期待値） |

## 変異注入（AC-2 の検出力証明）

| ID | 変異内容 | 対象 TC | 期待 |
|----|---------|--------|------|
| **M-1（必須）** | 削除した `[ -L "$_rf" ] && continue` を dst 側 stale 集計ループへ復元する（= 修正前実装） | TC-35 | **FAIL**（`rc=0` / `stale=3` / 5 件削除となり期待 ①②③④ が崩れる） |
| M-2（任意） | stale 集計ループから存在判定 `[ -f "$_rf" ] \|\| continue` を**削除**する（実体の有無を問わず数える集計にする） | TC-35 副次検査 | **FAIL**（ダングリング symlink が集計に入り `base=3 / stale=6` となり、期待の文字列一致が崩れる） |

> **`-e` への緩和は変異にならない（実測記録）**: POSIX の `-e` / `-f` はいずれも
> symlink を解決してから判定するため、ダングリング symlink では両方とも偽になる
> （実測: `-e = FALSE` / `-f = FALSE` / `-L = TRUE`）。したがって
> 「`[ -f ]` を `[ -e ]` に緩める」変異は挙動を変えず空振りする。M-2 は存在判定自体の
> 削除としてある。

### 検出できない変異（既知の限界・明示記録）

| ID | 変異内容 | TC-35 での結果 | 理由と代替担保 |
|----|---------|--------------|--------------|
| M-X | 削除ループ側へ `[ -L "$_rf" ] && continue` を追加する（論点 A-2 相当の誤修正） | **PASS してしまう（非検出）** | TC-35 は guard 発火帯（`stale > base`）の fixture であり、削除自体が保留されるため削除ループの条件式が結果に現れない。**代替担保**: 本 PBI は「削除ループに手を入れない」を Constraints で固定し、AC-1 の差分レビューで削除ループが無改変であることを確認する。非発火帯の対称性 TC 追加は V2 候補 |

### 変異注入の実行手順

1. 作業ツリーを汚さないため、`scripts/sync-plugin-plangate.sh` を一時ディレクトリへ複製し、
   複製側に変異を適用する（正本は触らない）
2. TC-35 の fixture 構築手順を同一のまま、複製したスクリプトを sandbox へ配置して実走する
   （sandbox 内のファイル名は `sync-plugin-plangate.sh` のままにする。
   名前が変わると sandbox 側の実行パスが解決できず rc=127 の空振りになる）
3. 期待どおり FAIL したことを実測ログとして `evidence/test-runs/` に残す
4. M-1 で FAIL が出ない場合は Replan Trigger RT-2（空振り fixture）を発火させ fixture を再設計する

## エッジケース一覧

| # | ケース | 期待挙動 | 担保 |
|---|-------|---------|------|
| E-1 | 解決可能 symlink stale | 集計・削除の両方に入る | TC-35 |
| E-2 | ダングリング symlink | 両ループから対称に除外される（集計に入らず削除もされない） | 集計側 = TC-35 副次検査 / 削除側 = AC-1 の差分レビュー（条件式同一性） |
| E-3 | dst symlink の basename が src に存在する | stale ではないので集計にも削除にも入らない（両者とも `[ ! -f "$_src_refs/$_rb" ]` 判定） | 既存 TC-29 の枠組みで担保（挙動不変） |
| E-4 | src 側 symlink | base 集計・コピーループの双方から除外（**本 PBI で変更しない**） | 既存挙動・非退行を TC-R で担保 |
| E-5 | symlink 0 件の通常構成 | 修正前後で判定・削除件数ともに完全一致 | TC-29 / TC-32 / TC-34（TC-R に含む） |
