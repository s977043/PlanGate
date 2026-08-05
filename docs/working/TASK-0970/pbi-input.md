# PBI INPUT PACKAGE: 経路1 mass-delete guard の stale 集計を削除ループと厳密一致させる

> Issue: [#970](https://github.com/s977043/plangate/issues/970)（`bug` / `priority:P2` / area: sync）
> 検出契機: TASK-0914 PR 前 River Review F-1（実測再現付き）
> 関連: #914（guard 本体）/ #861（同型の guard 無効化前例）/ #877（stale ベース判定・exit 3）/ #921（exit code 伝播）

## Context / Why

issue #914（TASK-0914）で導入した経路1（汎用 references）の mass-delete guard に、
**集計集合 ⊊ 削除集合** の残存窓が 1 件ある。

- stale 集計ループは dst 側 symlink を `[ -L ] && continue` で除外する（scripts/sync-plugin-plangate.sh L206）
- 直後の削除ループは `-L` 除外を持たない（同 L216-224）
- → dst references/ に **解決可能な symlink `.md`** が混入した状態で src が空化する事故時、
  guard 閾値が symlink 数だけ過小になり **fail-open 方向へずれる**

「N 件と数えて M 件消す」構造は #861 のデータ損失インシデントと同型の guard 無効化パターンであり、
issue #877 で stale ベース判定へ是正した際の設計意図（集計定義と実削除条件の一致）にも反する。

### 実測再現（本 PBI 作成時に再取得。main `a952872`）

sandbox: src 通常 3 / dst に通常 stale 3 + 解決可能 symlink stale 2

| 実装 | base | stale 集計 | guard | 結果 |
|------|------|-----------|-------|------|
| 現行（L206 の `-L` あり） | 3 | **3** | `3 > 3` 偽 → 非発火 | **5 件削除・rc=0**（fail-open） |
| L206 の `-L` を外した版 | 3 | **5** | `5 > 3` 真 → 発火 | 削除保留・8 件全残存・rc=3 |

symlink の target ファイルは両ケースとも非破壊（`rm` は link のみ削除）。

### 影響の限定（過大評価しないための実測）

- 損失は symlink ファイル自体に限定（target 非破壊）
- ダングリング symlink は `[ -f ]` が偽で両ループから対称に除外され、問題は生じない
- **現リポジトリに該当 symlink は 0 件**（実測: `find plugin/plangate/skills -name '*.md' -type l` = 0 / `.agents/skills` `.claude/skills` も 0）
  — 現時点では顕在化しない潜在窓である

### なぜ #914 で直さなかったか

TASK-0914 は C-3 APPROVED の plan（plan_hash 束縛）で
「集計ループへ `[ -L ] && continue` を入れる」（論点 D'-2 / R-351）と凍結されており、
exec は承認 plan に忠実に実装した。本件は **plan 側の設計残穴** であり、
承認範囲外の変更を exec で加えず follow-up 化した（TASK-0914 handoff §2 既知課題に記録済み）。

## What（Scope）

### In scope

- 集計集合と削除集合の**厳密一致化**。最小一手は dst 側 stale 集計ループから
  `[ -L "$_rf" ] && continue`（L206 相当）を外す 1 行
  （src 側 base 集計の `-L` はコピーループ整合として**維持**）
- 代替案（削除ループへ同一の `-L` 除外を追加 = 既存削除挙動が変わる）との比較判断を plan で行う
- 対称性を突く TC の追加（symlink stale 混入 fixture で「集計 = 削除」を検証）
- 追加 TC の**変異注入による検出力実証**（修正前実装に対して FAIL すること）

### Out of scope

- 経路2 / `sync_dir` 経路（集計・削除の対称性は #914 の実測で厳密一致を確認済み）
- exit code 伝播（#921）
- src 側 `-L` 除外の是非（コピーループとの整合として現状維持。変更すればコピー挙動まで波及する）
- `tests/extras/README.md` の現行テスト一覧ドリフト（既存文書負債・別 issue 候補）

## 受入基準

- [ ] AC-1: 経路1 の stale 集計集合と削除ループの削除集合が厳密一致する（symlink の扱いが両者で同一）
- [ ] AC-2: symlink stale 混入 fixture の TC が追加され、**修正前実装に対して FAIL する**（検出力証明）
- [ ] AC-3: 既存 ta-26 全 TC（30 本）が PASS を維持する
- [ ] AC-4: `sh tests/run-tests.sh` が baseline を維持する（baseline は exec 開始時に現 main で再実測した値。本 PBI 作成時点の実測値は **537 passed / 0 failed**）

## Notes from Refinement

- 最小一手（集計側から `-L` を外す）を第一候補とする。理由は「削除ループ（＝実際に起きること）を正とし、
  集計を実態へ合わせる」方向であり、**既存の削除挙動を一切変えない**ため。
- 代替案（削除ループへ `-L` を追加）は集計を正として削除を狭める方向で、
  「dst に残った symlink stale が永久に掃除されない」新たな挙動変化を生む。plan で比較記録する。
- 判断の正本は本 PBI ディレクトリの `decision-log.jsonl`（exec 開始時に初期化）。

## Estimation Evidence

### Risks

- 集計に symlink を含めることで、symlink を常用する構成では guard が**過剰発火**しうる
  （ただし現リポジトリの該当 symlink は 0 件。override `PLANGATE_ALLOW_MASS_DELETE=1` が既存の逃げ道）
- 追加 TC の fixture が空振り（修正前でも PASS）になると AC-2 を満たせない → 変異注入で実証する

### Unknowns

- なし（対象 1 行・既存 TC 群のパターンが確立しており、設計自由度は小さい）

### Assumptions

- `_t26_mk_refs_guard_sandbox` ヘルパーのシグネチャは変更せず、呼び出し後に symlink を追加して fixture を作る
- 変更対象は Hardening Override 9 カテゴリに非該当（`scripts/` 直下 / `tests/` は HO 表外・実測済み）
