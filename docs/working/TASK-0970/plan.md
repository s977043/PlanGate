# EXECUTION PLAN — TASK-0970

> 入力: [`pbi-input.md`](./pbi-input.md) / Issue [#970](https://github.com/s977043/plangate/issues/970)
> 実行方式: ai-loop（C-3' 裁定ループ）
> 基点: `origin/main` = `4448420`（本 plan の行番号・件数の実測値はすべてこの commit で取得。
> 対象 2 ファイルは前基点 `a952872` と内容同一であることを `git diff --stat` = 空で確認済み）

## 前提の実測（B-1 / 裏取り済み）

| 対象 | 実測値 | 取得方法 |
|------|-------|---------|
| コピーループの symlink 除外 | L179 | `grep -n` |
| src 側 base 集計の symlink 除外 | L200 | 同上 |
| **dst 側 stale 集計の symlink 除外（本 PBI の対象）** | **L206** | 同上 |
| guard 呼び出し | L215 | 同上 |
| 削除ループ（`-L` 除外なし） | L216-224 | 同上 |
| ta-26 の既存 TC 数 | **30**（最大番号 TC-34） | `grep -c 't26_pass "TC-'` |
| `sh tests/run-tests.sh` baseline | **`baseline`（記号）** — 実数は A-1 で現 main を再実測して確定 | A-1 で clean env 実走。ログは `evidence/test-runs/` を正とする（R-002） |
| ta-26 standalone 実走 | **rc=0** | clean env で実走 |
| リポジトリ内の該当 symlink | **0 件** | `find ... -name '*.md' -type l` |

再現・修正後挙動も sandbox で実走確認済み（pbi-input の実測再現表）。

## Goal

経路1（汎用 references）の mass-delete guard において、
**stale 集計集合と削除ループの削除集合を厳密一致させる**。
これにより「N 件と数えて M 件消す」guard 無効化（#861 同型）の残存窓を閉じ、
その対称性を回帰テストで固定する。

## Constraints / Non-goals

### Constraints

- 変更は **`scripts/sync-plugin-plangate.sh` の集計ループ 1 行の削除 + 直上コメント（L195-196）の追従
  （同一ファイル・同一 hunk）** と **`tests/extras/ta-26-plugin-sync.sh` への TC 1 本追加** に限定する
  （コメント追従は R-003。ファイル数は 2 のままで RT-1 に影響しない）
- **既存の削除挙動を変えない**（削除ループには手を入れない）
- 既存 30 TC を非退行で維持する
- 変更対象は Hardening Override 表に非該当（実測済み。§ai-loop run との関係を参照）

### Non-goals

- 経路2 / `sync_dir` 経路の再設計（#877 / #914 で対称性確認済み）
- exit code 伝播（#921）
- src 側 base 集計の symlink 除外の変更（コピーループ整合として維持。
  変更するとコピー挙動まで波及し、本 PBI の「削除挙動を変えない」制約に反する）
- guard 閾値そのものの見直し（`stale > base` は #877 の確定仕様）

## Approach Overview

### 論点 A: 修正方向の選択（最小一手 vs 代替案）

非対称の解消には方向が 2 つある。**A-1 を採用**する。

| 案 | 内容 | 集計 | 削除 | 既存削除挙動 | 判定 |
|----|------|------|------|------------|------|
| **A-1（採用）** | dst 側 stale 集計ループから `-L` 除外を外す（1 行削除） | symlink を**含む** | 現状のまま symlink を含む | **不変** | 採用 |
| A-2（不採用） | 削除ループへ同一の `-L` 除外を追加 | 現状のまま除外 | symlink を**除外** | **変わる** | 不採用 |

**A-1 を採る理由**:

1. 削除ループ（＝実際に起きること）を正とし、集計を実態へ合わせる方向であり、
   guard が守るべき対象（実際に消える件数）と閾値の意味が一致する
2. 既存の削除挙動を 1 ビットも変えない（回帰面が最小）
3. 差分が 1 行削除であり、`git revert` 一発で完全復元できる

**A-2 を不採用とする理由**（記録）:

1. 集計を正として削除を狭めるため、**dst に残った symlink stale が永久に掃除されない**
   という新たな挙動変化を生む（同期の目的である「src と dst の一致」から乖離する）
2. 既存 TC が期待する削除件数に影響しうる（回帰面が広い）
3. 「guard は削除の安全弁であって削除ポリシーではない」という #877 の設計意図に反する

なお **src 側 base 集計の `-L`（L200）は維持**する。src 側はコピーループ（L179）と
対を成しており、こちらの対称性は既に成立しているため（base = 実際にコピーされる集合）。

### 論点 B: 過剰発火リスクの扱い

集計に symlink を含めると、symlink を常用する構成では guard が発火しやすくなる。
これは **安全側（fail-closed）への移動**であり、AC-8 安全側原則と整合する。
既存の `PLANGATE_ALLOW_MASS_DELETE=1` override が意図的な一括削除の逃げ道として機能する
（#877 で導入済み・TC-28 で担保）。現リポジトリの該当 symlink は 0 件のため実害は生じない。

### 論点 C: fixture の作り方

`_t26_mk_refs_guard_sandbox` の**シグネチャは変更しない**（既存 30 TC への影響を避ける）。
新 TC は同ヘルパーを通常どおり呼び出した後、sandbox 内に target 実体と
それを指す symlink を追加して symlink stale を注入する（既存パターンの範囲内の追加）。

## Files / Components to Touch

| # | パス | 変更 |
|---|------|------|
| 1 | `scripts/sync-plugin-plangate.sh` | dst 側 stale 集計ループの symlink 除外 1 行を削除（L206）+ 直上コメント L195-196 を実装へ追従（同一 hunk / R-003） |
| 2 | `tests/extras/ta-26-plugin-sync.sh` | TC-35 追加（symlink stale 混入で「集計 = 削除」を検証） |

本節から機械抽出される allowed\_paths は上記 **2 件**であり、計画時の `changed_files`（＝本節）も
同じ 2 件である。申告 `size_ok=true` は arbiter が `changed_files` 実数で機械検証する
（`SIZE_OK_MAX_FILES`=2）。

作業コンテキスト（docs/working/TASK-0970/ 配下の status / current-state / handoff 等）は
**本節に載せない**。ai-loop の allowed\_paths はファイル書込みの制御機構ではなく
（実行系境界検査器 scripts/ai-loop/check\_exec\_boundary.py は実行系トークンの AST 検査であり
書込みパスを制御しない）、作業コンテキストの生成に本節への記載は不要であることを実測で確認した。
「集計対象から plan 自作の carve-out で除く」構成は、#780 slice C が申告制 `size_ok` の
虚偽宣言を検出するために導入した機械ガードへ**申告者自身がフィルタした集合を渡す**ことになるため採らない（R-001）。

## 変更しない領域（禁止領域 / backtick を付けない）

以下は本 PBI で touch しない。Hardening Override 表に該当するか、または Non-goals に属する。

- scripts/hooks 配下（HO-hook）
- bin/plangate（HO-core）
- schemas 配下（HO-schema）
- .claude 配下すべて（HO-rules / HO-settings）
- .github/workflows 配下（HO-ci）
- CLAUDE.md / AGENTS.md（HO-contract）
- plugin/plangate 配下（sync が生成する派生成果物。正本側のみを変更する）
- tests/run-tests.sh / tests/extras/README.md（本 PBI の scope 外）

## Testing Strategy

- Unit: 該当なし（POSIX sh。判定は sandbox 実走で担保）
- Integration: `tests/extras/ta-26-plugin-sync.sh` — 新規 TC-35（symlink stale 混入・乖離帯）
  および既存 TC-26〜TC-34（経路1 guard 群）の非退行
- E2E: `tests/run-tests.sh` 全系で baseline 維持（`baseline` → `baseline+1` passed / 0 failed を期待。
  `baseline` は A-1 で現 main を再実測した実数であり、絶対値を plan に固定しない / R-002）
- Edge cases:
  - 解決可能 symlink stale（`[ -f ]` 真）→ 集計・削除の両方に入る（本 PBI の是正対象）
  - ダングリング symlink（`[ -f ]` 偽）→ 両ループから対称に除外される（現状も是正後も不変）。
    集計側は TC-35 の副次検査で固定し、削除側は条件式の同一性を AC-1 の差分レビューで確認する
    （guard 発火帯の fixture では削除ループの条件式が結果に現れないため。test-cases.md の「検出できない変異」に明示）
  - symlink の target 実体が sandbox 外に残ること（`rm` は link のみ削除）
- 変異注入（必須 / AC-2）: 削除した 1 行を復元した実装（= 修正前実装）に対して
  TC-35 が **FAIL** することを実測し、空振り fixture でないことを証明する
- Verification Automation: `sh tests/extras/ta-26-plugin-sync.sh && sh tests/run-tests.sh`

いずれも clean env（`PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_FILE` / `PG_HARNESS_SOURCED` /
`FIXTURES_DIR` / `PLANGATE_ALLOW_MASS_DELETE` を unset）+ stdin リダイレクト（`</dev/null`）で実行する。

## Risks & Mitigations

| Risk | 影響 | Mitigation |
|------|------|-----------|
| 集計に symlink が入り guard が過剰発火する | 同期が exit 3 で止まる | 安全側への移動であり許容。override が既存の逃げ道（TC-28）。該当 symlink は現在 0 件 |
| TC-35 が空振り（修正前でも PASS） | AC-2 未達 | 変異注入で FAIL を実測。FAIL しなければ fixture を再設計（RT-2） |
| ヘルパー変更による既存 TC の巻き添え | AC-3 未達 | ヘルパーのシグネチャを変更しない（論点 C） |
| baseline 件数のドリフト | AC-4 の判定不能 | exec 開始時に現 main で baseline を再実測してから着手する |

## Questions / Unknowns（C-3' 論点）

1. **論点 A の方向**: 「削除ループを正として集計を合わせる」（A-1）でよいか。
   A-2（削除を狭める）は symlink stale が掃除されなくなる挙動変化を伴う
2. **src 側 `-L`（L200）の維持**: コピーループ整合として現状維持でよいか
3. **過剰発火の許容**（論点 B）: 安全側移動として許容し、override を逃げ道とする位置づけでよいか

## Loop Scope

単一 PBI（TASK-0970）の exec 内における「検証コマンド失敗 → 自己修正」の反復のみを対象とする。

## Stop Condition

変更が Files to Touch 内 / Verification Automation が exit 0 / AC-1〜4 全 PASS / 残課題は handoff に明示。

## Resume Condition

stop 後の再開は、原因・修正方針・検証手順を本 plan に追記し Replan 判定を通す。

## Replan Triggers（機械値）

| # | トリガー | 再計画の内容 |
|---|---------|------------|
| RT-1 | 実装差分のファイル数 > 2 | lite の `size_ok` が実測で崩れる → Mode 再判定 + C-3' 再裁定 |
| RT-2 | 変異注入で TC-35 の期待 FAIL が出ない | fixture を再設計（空振りの疑い） |
| RT-3 | `sh tests/run-tests.sh` の failed > 0 が同一原因で 3 回連続 | 該当 Step の設計を見直し todo を再生成 |
| RT-4 | 新規 TC 追加後の総テスト数が baseline+1 と一致しない | TC の重複・未登録を調査 |
| RT-5 | HO 表に該当するファイルへの変更が必要になった | 即停止し Human C-3 へ escalate |

## 受入基準

| ID | 内容 | 検証 |
|----|------|------|
| AC-1 | 経路1 の stale 集計集合と削除ループの削除集合が厳密一致する（symlink の扱いが両者で同一） | TC-35（自動）+ 差分レビュー（集計ループと削除ループの条件式が同一であること）。**削除ループ側の条件式は guard 発火帯の fixture では結果に現れないため、この部分のみ手動レビュー依存であることを明示する**（非発火帯の対称性 TC は V2 候補） |
| AC-2 | symlink stale 混入 fixture の TC が追加され、**修正前実装に対して FAIL する** | TC-35 + 変異注入 M-1 の実測ログ |
| AC-3 | 既存 ta-26 全 TC（30 本）が PASS を維持する | `sh tests/extras/ta-26-plugin-sync.sh` = 31 PASS / 0 FAIL |
| AC-4 | `sh tests/run-tests.sh` が baseline を維持する | `baseline` → `baseline+1` passed / 0 failed（`baseline` = A-1 で現 main を再実測した実数。実数の正本は `evidence/test-runs/` の A-1 ログ / R-002） |

## Mode 判定

**モード**: `standard`

**判定根拠**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md) の判定ロジック
「定量の各軸で最大値 → 定性の各軸で最大値 → 高い方を最終」に厳密に従う）:

| 区分 | 軸 | 値 | モード |
|------|----|----|-------|
| 定量 | 変更ファイル数 | 2（実装差分。sync 1 + ta-26 1） | light |
| 定量 | 受入基準数 | 4 | **standard**（3-5） |
| 定量 | タスク数（見込み） | 10（todo A-1〜A-10） | **standard**（5-10） |
| 定性 | 変更種別 | バグ修正（1 行削除）+ 回帰 TC 追加 | light |
| 定性 | リスク | 安全側（fail-closed）方向への移動のみ。既存削除挙動は不変 | 低 |
| 定性 | 影響範囲 | 当該 guard に閉じる | light |
| 定性 | ロールバック | `git revert` 一発 | 容易 |

- 定量の最大値: **standard** / 定性の最大値: **light**
- **最終判定**: `standard`（高い方を採用。narrative による下方修正は行わない
  ＝ mode-classification の調整ガイドはユーザー override のみを許容するため）
- 例外ルールの確認: セキュリティ / DB スキーマ / 公開 API 破壊的変更 /
  承認境界周辺（Hardening Override 対象パス）のいずれにも**非該当**（実測済み）
- なお `lite` は Mode と直交する派生属性であり、下記 4 軸で別途判定する
  （`lite=true` は `standard` と両立する。mode-classification が `lite_eligible=false` を
  強制するのは Hardening Override 対象と `critical` であり、本 PBI はいずれにも該当しない）

### lite 4 軸（[`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md) §2）

| 軸 | 判定 | 根拠（実測） |
|----|------|------------|
| 変更規模（`size_ok`） | **true** | Files to Touch から機械抽出される `changed_files` は 2 件 = `SIZE_OK_MAX_FILES`（2）以内。plan 側で集合を絞る carve-out は行わない（R-001） |
| 新規設計の有無（`no_new_design`） | **true**（＝新規設計なし） | #914 で導入済みの guard 構造・#877 の閾値仕様をそのまま使う。関数・変数・制御フローの新設ゼロ。差分は既存 1 行の削除 + 直上コメント文言の追従のみ |
| 既存パターン踏襲（`follows_pattern`） | **true** | TC-35 は既存 TC-26〜TC-34 と同型（`_t26_mk_refs_guard_sandbox` + `mktemp -d` + `register_cleanup` + 早期 `rm -rf`）。ヘルパーのシグネチャを変更しない |
| 可逆性（`reversible`） | **true** | 1 行削除 + TC 1 本追加。`git revert` 一発で完全復元。不可逆操作（外部公開・データ削除・課金・破壊的マイグレーション）を一切含まない |

**`lite`**: **true**（4 軸 AND）

AC-8 安全側の適用: 4 軸のいずれかが判定不能・根拠不足・曖昧であれば `lite=false` に倒す。
本 PBI では 4 軸すべてを上表の実測で裏取りしており、判定不能な軸は無い。

**Hardening Override**: **非該当**（下記 §ai-loop run との関係で実測記録）

## ai-loop run との関係

### boundary 判定（HO 表との突合・実測）

`docs/ai/ai-loop/ho-paths.md` の HO 表全 21 行を実測突合した結果、
本 PBI の実装差分 2 ファイルは**いずれのパターンにも一致しない**:

- 変更対象は scripts 直下のシェルスクリプト 1 本であり、HO-hook（scripts/hooks 配下）ではない
- tests 配下は HO 表に一切登場しない
- plugin 配布物（HO-plugin-dist）は変更しない（sync が生成する派生成果物であり正本側のみ触る）

→ **`boundary = clean`**

### rollout-policy §2 carve-out 判定（実測）

`docs/workflows/ai-loop/rollout-policy.md` §2「判定基盤 carve-out（自己改変防止・glob）」の
3 系統いずれにも**該当しない**:

| carve-out glob | 本 PBI の対象 | 該当 |
|----------------|--------------|------|
| scripts/ai-loop 配下すべて | 変更対象は scripts 直下の sync スクリプト（ai-loop サブディレクトリではない） | 非該当 |
| docs/workflows/ai-loop 配下・docs/ai/ai-loop 配下すべて | ドキュメントは変更しない（作業コンテキストのみ） | 非該当 |
| ai-loop-cycle スキル配下（.agents / .claude 側とも） | 変更しない | 非該当 |

→ Phase 1 の **適用対象（eligible run）**。

**W チェック 2 体への申し送り（R-004）**: 変更対象 `scripts/sync-plugin-plangate.sh` は、
rollout-policy §2 が「配布派生は正本を carve-out することで実質的に保護される」と述べている当の同期エンジンであり、
同一ファイル L358-402 に carve-out 対象の配布コピーを守る経路2 guard を持つ。
本 PBI の変更は**経路1 のみ・fail-closed 方向のみ**であり経路2 に触れないため escalate 要件には当たらないが、
判定基盤の配布経路を持つファイルであることを明示しておく。

### 予測される裁定

`boundary=clean` かつ `lite=true`（4 軸 AND・`size_ok` は実数 2 で機械検証を通過）であり、
W チェック 2 体が approve で一致すれば **`AUTO_APPROVED`** となる見込み。
不一致・重大 severity・判定不能が生じた場合は `rollout-policy.md` §6 に従い Human へ escalate する。

**不変条件（緩和しない）**: NO MERGE BY AI / C-4・merge は Human-owned 固定 /
HO 接触が判明した時点で無条件 escalate / lite 4 軸の AC-8 安全側。
