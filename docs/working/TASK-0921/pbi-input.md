# PBI INPUT PACKAGE — TASK-0921

> Issue: [#921](https://github.com/s977043/plangate/issues/921)（bug / **priority:P1**）
> 由来: [#914](https://github.com/s977043/plangate/issues/914) の受入基準 AC-8（案 C のスコープ切り出し）。TASK-0914 の plan / review-external に検出経緯と実測を記録済み
> 作成: 2026-07-31（**main `b45ab17` で実測**。行番号は目安であり記号アンカーを正とする）
> 前段: #877（mass-delete guard fail-closed 化）→ #914（R-204 = harness 判別統一・**C-3 待ち**）→ 本 PBI

## Context / Why

`tests/extras/` のテストスクリプトは、**standalone 実行（`sh tests/extras/ta-XX-....sh`）時に内部の `[FAIL]` を exit code へ反映しない**。`pass` / `fail` カウンタは更新されるが、それを終了ステータスへ変換する仕組みを持つのは **53 本中 ta-26 の 1 本だけ**（実測）。結果、**全ケース失敗していても exit 0 で通る**。

### 実測による裏取り（main `b45ab17`・2026-07-31）

| # | 主張 | 実測 | 結果 |
|---|------|------|------|
| 1 | fallback を持つスクリプトでも fail が伝播しない | `env -u PLANGATE_HOOK_TASK sh tests/extras/ta-39-eh3-doc-light.sh` ※`PLANGATE_HOOK_TASK` 汚染下では **7 件 FAIL** | いずれの場合も **exit 0**。内部 FAIL と exit code が無関係 |
| 2 | **harness 専用スクリプトは standalone で誤動作した上で exit 0** | `sh tests/extras/ta-04-check-pr-issue-link.sh </dev/null` | ヘッダに「**Sourced by tests/run-tests.sh** — relies on `$pass` / `$fail` / `$PLANGATE_BIN` / `$FIXTURES_DIR`」と明記されているのに、standalone で叩くと `$FIXTURES_DIR` 未定義のまま進み **FAIL=4・exit 0**（誤動作 + 静かに成功を装う） |
| 3 | 唯一の対応済み前例 = ta-26 | `tests/extras/ta-26-plugin-sync.sh` 末尾 | `PG_T26_STANDALONE=1` のとき cleanup drain + サマリ出力 + **`if [ "$fail" != "0" ]; then exit 1; fi`**。**source 経路（harness）では exit しない**（run-tests.sh を殺さないため） |
| 4 | 対象の全数は**文字列 grep では確定できない** | 複数ヒューリスティックを試行 | 「`exit 1` を含む = 伝播あり」とすると 16 本が該当するが、抜き取り検証で **ta-09 の `exit 1` はコメント内の期待値記述**（`# expect --validate to exit 1`）であり伝播ではないと判明。誤検出が混ざるため、**確実な判定は「fail を 1 件注入して standalone 実行し rc を見る」実行ベース検査のみ** |
| 5 | 「Sourced by tests/run-tests.sh」ヘッダは**全 53 本に存在**し、**層判別には使えない** | `grep -lF ... \| wc -l` = **53**（全数） | 当初「37 本」と誤実測していた（R-101 で是正）。**カウンタ初期化（`pass=0`/`fail=0` 自前定義）を持つのは ta-26 の 1 本のみ**。ta-39 等が standalone でも FAIL を「正しく数える」のは、**sh の未定義変数算術展開（`pass=$((pass + 1))` が未初期化でも 0 起点で動く）による副次効果**であり、意図した fallback ではない |

### なぜ問題か（故障確率）

- **検証条件が構造的に空振りする**: TASK-0914 の当初 AC-6「standalone 実行が exit 0」はこの欠落により**無条件に成立**していた（同 plan で 3 条件の代理判定へ強化して回避済み）。同型の AC を書くたびに検証が形骸化する
- **誤動作が成功を装う**: 層 B（harness 専用）は standalone で叩くと fixtures 未解決のまま走って FAIL を量産するのに exit 0 を返す。手元デバッグ・CI 外実行で誤った成功シグナルになる
- 外部 env 汚染（#914 R-204 の領域）と組み合わさると、壊れていることに気づく手段がない

## 問題の 2 層構造（本 PBI の中心整理）

| 層 | 対象 | 症状 | 対処の方向 |
|----|------|------|-----------|
| **層 A** | **ROOT パス解決フォールバック**（`if [ -n "${FIXTURES_DIR:-}" ]` 型）を持ち、standalone でもテスト本体が走る群 = **#914 T-07 対象の 11 本と同一**（ta-39/43/44/45/46/47/49/50/51/52/53。カウンタ初期化は持たず、sh の未定義変数算術展開で偶然カウントが動く — R-102） | 正しく実行され FAIL を数えるが exit 0 | **ta-26 パターンの複製**（standalone フラグ + カウンタ初期化 + 末尾 `fail != 0 → exit 1`。source 経路では exit しない） |
| **層 B** | ROOT パス解決フォールバックを持たない残り **41 本**（= 53 − ta-26 − 層 A 11。「Sourced by」ヘッダは全数共通のため判別に使えない — R-101） | standalone だと**誤動作**（`$FIXTURES_DIR` 等未定義のまま進行）した上で exit 0 | **fail-fast ガード**が第一候補（standalone 実行を検知したら「harness 経由で実行せよ」と明示して **exit 2**）。完全 standalone 対応（fallback 追加）は 41 本への大改修になるため原則やらない — plan で確定（U-1） |

> 層 B に「fail 伝播（exit 1）」だけを足すのは**誤り**: 誤動作した FAIL を非ゼロで返しても「テストが壊れている」と「対象が壊れている」を区別できない。standalone 実行自体を拒否する fail-fast が正しい対処。

## What（Scope）

### In scope

1. **層 A**: ta-26 パターン（standalone フラグ + 末尾 exit）を層 A 全数へ適用
2. **層 B**: standalone 実行の fail-fast ガード（検知 → 明示メッセージ → exit 2）を適用。※対処方針自体は plan 冒頭で確定（U-1）
3. **対象の実行ベース全数分類**: 「fail を 1 件注入して standalone 実行 → rc を検査」する機械判定で分類・検証し、**件数をハードコードしない**検査として固定する
   - **各起動は `sh "$f" </dev/null` を必須とする**（#914 plan RV-M1: 未リダイレクトだと `ta-50` が `precompact-memory-guard.sh` の `cat` で**無限ハング**する — RV-F2）
   - **pre-fix の層判別は rc では不能**（修正前は層 A も層 B も rc=0 で同値）。判別は **fallback 構造（`FIXTURES_DIR:-` 分岐）の有無**で行い、rc 検査は**適用後の検証**に使う（RV-F4a）
   - **分類・注入が適用できないファイルは検査 FAIL（fail-closed）**とし、silently skip を禁止する（RV-F4b）
4. **回帰テスト**: 意図的に fail させた fixture で「層 A = exit 1」「層 B = exit 2」「harness 経由 = run-tests.sh が集計（exit しない）」を負側テストで固定
5. **`tests/extras/README.md` の規約追記**: 「standalone 実行では fail を exit code へ伝播する（層 A）/ harness 専用は fail-fast する（層 B）」

### Out of scope

- `tests/run-tests.sh`（harness 側集計）の変更
- harness/standalone の**判別方式**の統一（= **#914 R-204 のスコープ**。本 PBI はその後続）
- 層 B の完全 standalone 対応（fallback 追加による 41 本の大改修）— fail-fast で足りる前提。必要なら別 issue
- `tests/extras/README.md` の「現行テスト一覧」表のドリフト是正（53 本中 12 本しか掲載されていない別の文書負債）

### ⚠️ #914 exec との順序依存（重要）

層 A の対象は **#914 の T-07 が触る 11 本（ta-39/43/44/45/46/47/49/50/51/52/53）と同一**で、README.md は #914 の **T-08**（別ステップ）が触る（R-105）。#914 は現在 **C-3 承認待ち**（plan は main 実在）。

- **本 PBI の exec は #914 の exec 完了（マージ）後に着手する**（同一ファイル群の conflict 回避）
- #914 の plan は「AC-6 の代理判定（`[FAIL]` 文字列 + `[PASS]` 件数 baseline）を、本 PBI 完了後に **exit code ベースへ戻す**」を V2 候補として記録している → 本 PBI の AC-6 で接続する
- pbi-input / plan の作成は並行可能（本ファイルはその前段）

## 受入基準

> issue #921 の AC-1〜6 を継承し、2 層構造の実測を反映して精緻化。plan で最終確定する。

- **AC-1**: `tests/extras/ta-*.sh` のうち「standalone 実行時に `fail > 0`（層 A）または未定義前提での誤動作（層 B）でも exit 0 を返す」ものが **0 件**。判定は**文字列 grep でなく実行ベース**（fail 注入 → rc 検査）で行い、件数をハードコードしない
- **AC-2**: 層 A の各ファイルについて、意図的に 1 件 fail させた standalone 実行が **exit 1** になる（負側テスト）。かつ **同じ fail 注入状態のまま** source 経路（`sh tests/run-tests.sh`）で実行しても **run-tests.sh が完走して当該 fail を集計する**（= exit しない。harness を殺さない = ta-26 前例の踏襲。通常グリーン実行での代用は不可 — RV-F5）
- **AC-3**: 層 B の各ファイルについて、standalone 実行が**明示メッセージ付き exit 2** で即終了する（誤動作したまま走らない）。※既存 extras の `exit 2` 参照 3 箇所（ta-39/42/50）はいずれも**サブプロセス戻り値の比較**でありトップレベル終了コードではないため機能衝突しない（実測）。ただし「ta-*.sh 自身の exit 2 = standalone 誤用検知」という新しい意味を導入するため、test-cases で意味レイヤーを明記する（R-106）
- **AC-4**: `sh tests/run-tests.sh` が回帰しない（**baseline: 430 passed / 0 failed**。#914 マージ後は当該 plan の 444 を正とする）
- **AC-5**: AC-1 の実行ベース検査が回帰テストとして `tests/extras/` に追加され、**新規スクリプト追加時の伝播漏れを将来も検出できる**
- **AC-6**: `tests/extras/README.md` に層 A / 層 B の規約が明記され、**TASK-0914 の AC-6 代理判定を exit code ベースへ戻せる状態にする**（#914 の V2 候補のクローズ）。U-3 の分岐別充足条件（RV-F3）: **含める場合** = #914 検証スクリプトの exit code 化まで本 PBI で完了 / **含めない場合** = 戻せることの実証（層 A 全数の rc 検査 PASS）+ follow-up 起票 + handoff 記録をもって充足

## Notes from Refinement

### T-01（分類実行）の隔離方針（RV-F6）

pre-fix の standalone 全数実行は、層 B が `$FIXTURES_DIR` 等の誤解決で **artifact を誤配置**する副作用を持つ（例: ta-09 は standalone だと `tests/docs/working/TASK-9991` 相当へ書き込み + cleanup の `rm -rf` が走る）。分類・検証の実行は**使い捨て worktree / 隔離 cwd** で行う。

### ta-26 前例の実装（層 A の複製元・実測）

```sh
# 末尾（source 時は run-tests.sh が担うため exit しない）
if [ "$PG_T26_STANDALONE" = "1" ]; then
  # cleanup drain ...
  printf '\nTA-26 standalone: %s passed, %s failed\n' "$pass" "$fail"
  if [ "$fail" != "0" ]; then
    exit 1
  fi
fi
```

- 層 A の各ファイルは既に standalone 判別（#914 完了後は `PG_HARNESS_SOURCED` AND 方式）を持つため、**判別結果のフラグ化 + カウンタ初期化（`pass=0`/`fail=0` — 現状は未初期化で sh 仕様に依存している）+ 末尾ブロック追加**の機械的変更。**対象特定に `pass=0` 等の grep を使わないこと**（存在しないため 0 件になる — R-102）
- 層 B は冒頭 3 行程度のガード（`Sourced by` 前提の変数が未定義なら exit 2）で足りる見込み

### Mode 見込み: high-risk〜critical（plan で確定）

- 定量: 対象ファイルは**最大 50 本超**（対応済み ta-26 を除き 層 A 11 + 層 B 41 + テスト + README）→ 16+ で **critical 帯**
- ただし変更は**各ファイル数行の機械的同一パターン追加**であり、mode-classification の定性軸（新規設計なし・既存パターン踏襲 = ta-26 ミラー）では light 相当
- **plan でスライス分割を判断**。ただし単純 2 分割では不足: Slice 1（層 A 11 + 検査基盤 ≈ 12-14）は high 帯に収まるが、**Slice 2（層 B 41 本）は単独でも 16+ = critical 帯のまま**（mode-classification の「定量と定性の高い方を採用」により定性 light でも critical 固定 — R-104）。層 B を **≤15 本のサブスライス 3 本**に割るか、critical 受容（V-2/V-3/V-4 フル + 同期 C-3）で一括するかを plan で確定
- 安全側の初期値: **high-risk**（層 A 先行スライスの場合）。一括なら critical。いずれも `lite_eligible=false`・Human C-3

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| source 経路（harness）で誤って exit してしまう | **run-tests.sh が途中で死に、以降の全テストがスキップされる**（最重大） | ta-26 と同じく standalone フラグの内側でのみ exit。AC-2 の「harness では exit しない」負側テストで固定 |
| 層 B に fail 伝播だけ足して「誤動作 + exit 1」になる | 「テストが壊れた」と「対象が壊れた」を区別できず調査コストが増える | 層 B は fail-fast（exit 2）方針。exit 1（テスト失敗）と exit 2（実行方法エラー）を区別 |
| #914 T-07 と同一ファイルを並行編集して conflict | どちらかの PR が rebase 地獄 | **#914 exec 完了後に本 PBI の exec を開始**（順序依存を明記済み） |
| 文字列 grep で対象を確定して漏れる | 伝播漏れが残存し AC-1 が空振り | 実行ベース検査（fail 注入 → rc）のみを判定に使う（実測 #4 で grep の誤検出を確認済み） |
| 53 本への一括変更で回帰 | run-tests.sh の 430 が崩れる | スライス分割 + 各スライスで 430/0（or 444/0）維持を 🚩 に |

### Unknowns

- **U-1**: 層 B の対処方針の最終確定 — fail-fast（exit 2・推奨）か、選択的に standalone 対応を足すか。fail-fast の場合の検知条件（`Sourced by` 前提変数の未定義検査 vs `PG_HARNESS_SOURCED` 非設定検査 — 後者は #914 完了が前提）
- **U-2**: 層 A の正確な全数（実行ベース検査で T-01 に確定させる。fallback の書式が ta-26 型・ta-39 型で揺れている可能性）
- **U-3**: AC-6 の「#914 検証スクリプト更新」を本 PBI に含めるか #914 側の follow-up とするか
- **U-5**: **fail 注入の汎用手段**（AC-1/AC-5 の検査基盤）。53 本の実装形状は **ヘルパー関数形式（`tXX_pass()`/`tXX_fail()`）35 本 / 直書き `fail=$((fail+1))` 18 本** に分かれ、README が案内する `assert_pass`/`assert_fail` は **ta-*.sh 内では 0 本で未使用**（run-tests.sh 本体埋め込み専用・実測）。両形状 + 将来の新規ファイルに機械適用できる単一の注入手段は現存しない — plan で設計する（R-103）
- **U-4**: 共通 preamble 化（`_standalone-guard.sh` の共有）の是非 — #914 は「extras 自己完結の慣習」を理由に E-2（インライン）を採用した。50 本規模なら共通化の損益分岐が変わる可能性。plan で再比較

### Assumptions

- #914（PR #919 の plan）が承認され exec が完了すること（層 A の判別式が `PG_HARNESS_SOURCED` AND 方式に統一済みであること）
- `sh tests/run-tests.sh` baseline = 430 passed / 0 failed（main `b45ab17` 時点。#914 マージ後は 444）
- ta-26 の standalone exit パターンが引き続き正（変更されないこと）
