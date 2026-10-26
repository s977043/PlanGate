---
task_id: TASK-1608
artifact_type: plan
schema_version: 1
status: draft
mode: high-risk
related_issue: https://github.com/s977043/plangate/issues/1608
created_by: orchestrator
---

# TASK-1608 Implementation Plan

## Goal

`scripts/improvement_seed_delta.py` の Markdown 構造判定を、正規表現による構造推定から
**CommonMark のブロック構造規則に従う行単位の状態機械（標準ライブラリのみ）**へ置き換え、
#1574 で残った回避クラスを「個別の継ぎ当て」ではなく「構造の判定モデル」で閉じる。

## Context

- 背景: #1574 の敵対レビュー R1〜R4 で毎ラウンド新しい回避クラスが出た（`pbi-input.md` Context）
- 関連 Issue: #1608（Refs #1545 / #1574）
- 関連 artifact: `pbi-input.md` / `test-cases.md` / `todo.md`
- Requirement refs: `pbi-input.md` AC-1〜AC-11
- 改訂履歴: 初版は C-3 APPROVED（plan_hash `sha256:a1ddda40…`）後に exec。敵対レビュー R4 で Stop Condition に該当し BLOCKED。
  Human 裁定 (c)（2026-10-24）を D-1b として反映した改訂は再承認済み（plan_hash `439f1620…`）。
  その後 R5・R6 で Stop Condition に該当し、Human 裁定（2026-10-25）を D-1c として反映した本改訂は再々承認が必要
  （既存の `approvals/c3.json` は本改訂の plan_hash と一致しない）。改訂 2 は再承認（plan_hash `24a35af0…`）後に exec し、
  R7 で列 4〜5 の入れ子の素通り（新クラス）が出た。Human 決定（2026-10-26「検証設計を変える」）と HD-1 / HD-2（D-016）を
  **改訂 3**（D-1d・検証モデル V-A〜V-C・停止条件の再定義）として反映した。
  L2 レビュー（R-013〜R-018）と Human 裁定 D-017（HO は hashFiles ガードで #1611 より先に main へ）を **改訂 4** として反映した。
  L3 レビュー（R-019〜R-024）と Human 裁定 D-018（局所是正 + M-1 / M-2 限定の短い確認後に C-3）を **改訂 5** として反映した。
  **再承認が必要**（plan_hash 変更）

## 設計を変える根拠（#1574 の 4 ラウンドの事実から）

[`review-principles.md`](../../../.claude/rules/review-principles.md) §7-quater は「毎ラウンド新しいクラスが出続けるなら、
打ち切りどきではなく設計モデルそのものを疑うとき」と定める。#1574 の台帳を**原因の層**で並べ直すと、
4 ラウンドすべてが同じ層（「正規表現で Markdown のブロック構造を推定している」）に集まっている:

| R | クラス | 原因の層 |
|---|--------|---------|
| R1 | 改行をまたぐ `\s*` によるマーカー誤取得 / 表記ゆれ | 正規表現が行境界・ブロック境界を知らない |
| R2 | 見出しに似た 5 形式 / fence 内の誤判定 / `confirmed_by: no` | 「何が見出しか」を正規表現の近似で判定 / ブロック種別（code）を知らない |
| R3 | 閉じていない fence による seed の隠蔽 | fence の開閉という状態を後付けのマスクで近似 |
| R4 | BOM / HTML コメント内 seed / 先頭語 no・na の人名誤拒否 | ブロック種別（HTML）を知らない / 入力正規化の層が無い / 否定値の判定を先頭トークンの近似で行う |

各ラウンドの是正は「その形を 1 つ足す」継ぎ当て（lookalike 正規表現の拡張・マスク・utf-8-sig）であり、
次のラウンドは継ぎ当ての外側を突いた。これは同じ層での新クラス 2 連続以上に当たるため、継ぎ当てを続けず
**その層の所有者（ブロック構造の判定）を明示的な状態機械へ置き換える**。
状態機械なら「どのブロックの中にいるか」が各行で一意に決まるため、R1〜R4 の大半（改行越え・fence 内・
未閉 fence・HTML コメント内）が個別の正規表現ではなく**状態遷移の規則**で扱われる。

## Scope

### In Scope

- 新規の内部関数群（同一ファイル内）: 入力正規化 → ブロック分割（状態機械）→ seed / digest の意味解析
- 不可視文字の扱い（下記 D-2）
- 否定値判定の見直し（下記 D-3）
- 単体テストの追加（回避クラス台帳の全クラス）、docstring の残存脅威モデル更新
- 改訂 3: CommonMark 参照パーサーとの差分テスト（テスト側のみ）と、CI 配線の HO patch の用意（適用は Human）

### Out of Scope

`pbi-input.md` Out of scope と同じ。加えて ta-116 の判定内容は変えない（AC-1 で PASS を確認するだけ）。

## Approach Overview

### D-1: パーサーの方式（推奨: 標準ライブラリの行単位ブロック状態機械）

対象とするブロック種別を本検査が判定に使うものに**限定**し、それ以外は段落扱いとする:

| 状態 | 開始 | 終了 | 中身の扱い |
|------|------|------|-----------|
| `fenced_code` | 0〜3 空白 + `` ``` ``/`~~~`（3 個以上） | 同種・開き以上の長さ・info string なし | 無視。EOF まで閉じなければ fail-closed（R3 の不変を維持） |
| `html_block` | CommonMark type 2（`<!--`）〜type 7 のうち、type 2（コメント）と type 1/6（`<script>` `<pre>` `<div>` 等）を対象 | type 2 は `-->`、type 1 は終了タグ、type 6/7 は空行 | 無視（AC-2）。type 2 が EOF まで閉じなければ fail-closed |
| `indented_code` | 段落外で 4 空白以上 | 非空・4 空白未満の行 | 無視 |
| `atx_heading` | 0〜3 空白 + `#{1,6}` + 空白 or 行末 | 1 行 | seed 候補として意味解析へ |
| `list_item` / `paragraph` | 上記以外 | — | `- confirmed_by:` の検出対象（トップレベルの `- ` 項目のみ） |

- 「日付を含む見出しで正規形でないもの」は従来どおり fail-closed（R1/R2 の不変を維持）。
  判定対象は**状態機械が `atx_heading` と判定した行**であり、正規表現で全文を走査しない（AC-7）
- setext 見出し（`===` / `---` 下線）で日付を含む段落が見出しになるケースは fail-closed で拒否する
  （正規形は ATX のみ。受理すると同一性がずれる）
- 判定できない構造（例: blockquote 内の見出し `> ## 2026-...`、リスト内にネストした見出し）は
  **seed として数えず、日付を含むなら fail-closed で拒否**する。自作パーサーの守備範囲外を黙って通さない

#### D-1b: コンテナ境界の fail-closed（改訂 2026-10-24 / Human 裁定 (c) / decision-log D-011）

初版 exec の敵対レビューで、コンテナ（リスト項目・blockquote）の軸に R3・R4 と 2 ラウンド続けて新クラスが出た
（`review-external.md`）。本状態機械はコンテナのスタックを持たないため、**コンテナが空行なしで終わる構成は解釈せず拒否する**。

- 定義: 直前の非空行がコンテナの内側（リスト項目の行・その継続行・blockquote の行）にあり、空行を挟まずに
  次の非空行が**列 0〜1 で始まり、かつ同じ種類のコンテナの続き（リストならリストマーカー行、blockquote なら `>` 行）でも
  段落の継続（ブロックを開かない地の文）でもない**とき、`ValueError` で拒否する
- 対象となる行の例（網羅でなく種別）: blockquote の開始 / fence の開始・閉じ / HTML ブロックの開始 / thematic break（`***` `---` `___`）/
  ATX 見出し / setext 下線 / リストから blockquote・blockquote からリストへの切り替え
- R3 で入れた「マーカー行・blockquote 行で開く fence / HTML の拒否」は維持する（コンテナ内でブロックを開く側の fail-closed）
- これで「コンテナがいつ閉じたか」を状態機械が推定する場面は、空行で閉じる場合とコンテナ内のインデント継続だけになる
- 現行データ（`docs/working/improvement-seeds.md` / `improvement-digest.md`）には該当する境界が無いことを実測済み
  （空行なしで続くのは blockquote → blockquote の継続だけ。2026-10-24、`604ffccd` 時点）。誤拒否が出ないことを受入条件とする（AC-11）

#### D-1c: 入れ子コンテナの fail-closed（改訂 2026-10-25 / Human 裁定 / decision-log D-014）

改訂後の敵対レビューで、コンテナ軸に R5（状態判定の入力の不一致）・R6（container 種別の上書き = 入れ子の喪失）と
2 ラウンド続けて新クラスが出た（`review-external.md`）。R6 は、リスト内の `>` で container が `list` から `quote` に置き換わり、
その後のリスト内 fence がトップレベルとして扱われて seed が黙って落ちる、というもの。**入れ子のコンテナは解釈せず拒否する**。

- 定義（一般化）: あるコンテナ（リスト項目 / blockquote）の内側に、別のコンテナの開始が現れたら `ValueError` で拒否する。
  「内側」とは次のいずれか:
  1. 同じ行で、コンテナのマーカーの直後に別のマーカーが続く（`> - a` / `- > a` / `> > a` / `- - a` / `1. - a`）
  2. 空行の有無にかかわらず、リスト項目の継続位置（リストの container 中で列 2 以上）にコンテナのマーカーがある（`  > b` / `  - b` / `   1. b`）
  3. blockquote の container 中で、`>` を外した残りにコンテナのマーカーがある（1 と同じ。`>` の継続行も対象）
- 種別を問わない: リスト内の blockquote、blockquote 内のリスト、リスト内のリスト、blockquote 内の blockquote をすべて拒否する
- 入れ子でないもの（受理を維持）: トップレベルのリストの複数項目（列 0〜1 のマーカー）、同じ深さの blockquote の継続（`> a` / `> b`）、
  リスト内の fence・段落・インデント継続（コンテナではないブロック）
- **container を単一の値（None / list / quote）のままで正しい根拠**: 入れ子を拒否すると、どの行でも開いているコンテナは高々 1 段になる。
  1 段のコンテナ列（スタック）は、最上段の種別だけで完全に表せるので、単一の値はスタックと同値になる。
  R6 の「種別の上書き」は、内側のコンテナの開始で外側の種別を書き換える場合にしか起きないが、その行は上書きの前に拒否されるため到達しない。
  コンテナの終了（空行・境界）は D-1b で扱い、終了後は None に戻るので、深さ 0 / 1 以外の状態は生じない
- 現行データの実測（2026-10-25、`1c26e9de` 時点。fence 内を除外して、上記 1〜3 に当たる行を数えた）:
  `improvement-seeds.md` 0 行 / `improvement-digest.md` 0 行。
  検査器の陽性対照として、入れ子 5 種（`  > b` / `> - c` / `  - d` / `> > e` / `   - g`）を含む fixture で 5 行すべて検出した。
  内容オフセットが 2 でないリスト（インデント付きマーカー・番号付きリスト・マーカー後の空白 2 個以上）も 0 行
- 入れ子拒否は D-1b と同じく、既存の判定より前に行う（container の更新前に拒否）

#### D-1d: 列の上限なしの入れ子拒否（改訂 3 2026-10-26 / R-001）

- list コンテナ内では、列 2 以上の行を strip した先頭が `>` / リストマーカーなら、**列の上限なしで** nested container として拒否する
  （R7: 列 4〜5 が indented code 扱いになり素通りした）。blockquote 内も `>` を外した残りを上限なしで判定する
- 不可視文字（Cf・非 ASCII 空白）がマーカー直前にある行は D-2 で先に拒否する（R5 と同型の入力不一致を作らない）
- TC-NEST-C4〜C7（列 4 / 5 / 6 / 7 × quote / list）。誤拒否は V-B の FALSE_REJECT と V-C で測る

### 検証モデル（改訂 3 / R-002〜R-004・R-005〜R-012 / D-016）

改訂 3 の主題は実装の継ぎ当てではなく**検証の作り直し**である。R1〜R7 は「敵対レビュアーが思いついた入力」でしか
食い違いを検出できず、毎ラウンド新クラスが出た。以後は CommonMark 参照パーサーとの機械的な差分で検出する。

#### 一致の定義（3 値ではなく 4 値）

- `reference_view(text)`（テスト側）: 参照 AST から射影する — トップレベル level 2 の日付 ATX 見出し /
  その節内トップレベル bullet の `confirmed_by` 段落 / digest の索引行。併せて `out_of_scope(text)` を参照 AST から求める
  （入れ子コンテナ・コンテナ内の日付見出し・setext の日付見出し・未閉の fence / HTML コメント・不可視文字など、plan が拒否すると定めた構造の有無）
- 判定（R-005 = Claude major-1 を反映。REJECT を無条件合格にしない）:

| impl | 参照 | 判定 | 合否 |
|------|------|------|------|
| 受理・射影一致 | — | AGREE | 合格 |
| `ValueError` | `out_of_scope=True` | REJECT | 合格（記録） |
| `ValueError` | `out_of_scope=False` | **FALSE_REJECT** | **不合格** |
| 受理・射影不一致 | — | MISMATCH | 不合格（最小化して fixture 固定） |

- 生成器の偏りは**軸別の `out_of_scope=False` 最低件数**で測る（改訂 4 / R-017）: V-B の各軸の各値（コンテナ種別・深さ・列・空行数・
  ブロック種別・不可視文字の有無）について、`out_of_scope=False` かつ AGREE の件数が下限以上であることを要求する
  （全体比率では特定の軸値が拒否側に偏っても検出できないため）。下限値は T-25 で生成器の分布を実測して決め、status に記録する。
  REJECT 率・`out_of_scope=False` の全体割合は**補助指標として記録のみ**（合否に使わない）
- 件数は 4 値（AGREE / REJECT / FALSE_REJECT / MISMATCH）の**合計**で数え、20,000 と一致することを assert する（R-016）
- 「常に `ValueError`」「常に空集合で受理」の 2 変異は E-5 で KILLED 必須
- `out_of_scope` の過大変異（「常に True」「列 2 以上で True」）も E-5 で KILLED 必須（改訂 4 / R-015。過大な `out_of_scope` は
  FALSE_REJECT を REJECT に化けさせて隠すため）

#### `reference_view` の自己参照対策（R-010 = Codex 高-1）

- `reference_view` / `out_of_scope` は impl モジュールを import しない（テストで import グラフを検査）
- 射影規則ごとに手書き期待値の単体テストを持ち、射影側の変異（level 判定・トップレベル判定・節境界）も E-5 で KILLED 必須
- `out_of_scope` にも手書き期待値を持つ。`out_of_scope=False` が期待される入力（列 2 以上の段落継続・リスト内 fence・同じ深さの blockquote 継続など）を必ず含める（R-015）
- golden fixture は**作らない**（下記 R-011 の採否）。期待値は毎回参照パーサーから生成するため、陳腐化・impl 出力からの再生成の経路が無い

#### V-A 参照パーサー（R-002 / HD-2）

- `markdown-it-py` 4.2.0（依存 `mdurl` 0.1.2）をテスト用依存として**ハッシュ固定**で使う
  （`tests/requirements-seed-delta-reference.txt`、`pip install --require-hashes --no-deps`）。repo の実行時依存・`improvement_seed_delta.py` の import は変えない（AC-9 / TC-STRUCT-02 不変）
- 比較した代替: commonmark.py（spec 0.29・deprecated）/ mistletoe（CommonMark との差分既知）/ commonmark.js・cmark（CI に npm・バイナリなし）。準拠する spec 版は exec で実測し evidence に記録する
- live 比較は `SEED_DELTA_REFERENCE=1` のときに走る。**この変数が立っていて参照パーサーが import できなければ skip ではなく FAIL**。
  変数が未設定のときは `SKIP: SEED_DELTA_REFERENCE unset` を明示出力する（黙った skip にしない。R-016）
- wheel のハッシュは pip `--require-hashes` が検査するため、テスト側ではハッシュを assert しない（空振りになる。R-016）。
  実行時 assert は参照パーサーの版（4.2.0）と準拠 spec 版に限定する
- 陽性対照: 旧実装のスナップショット（`ca9a8b33` = R7、`1c26e9de` = R6 の `improvement_seed_delta.py`）を fixture として同梱し、差分テストで MISMATCH または FALSE_REJECT を 1 件以上検出することを CI でも assert する

#### CI での直接比較（HD-1 / R-007 = Codex 高-2）

- CI（`test.yml`）で参照パーサーを入れて `SEED_DELTA_REFERENCE=1` で live 比較を走らせる。`.github/workflows/*.yml` は HO 対象のため、
  **AI は patch・適用スクリプト・dry-run 手順まで、適用は Human**（`docs/working/TASK-1608/ho/`）
- CI の保証範囲: seed 0〜19,999 の生成入力 / V-C コーパス全件 / 陽性対照。ローカルと CI で同じ範囲（分離しない）
- 生成件数（4 値の合計 = 20,000）と参照パーサーの版・spec 版を実行時に assert する（0 件で通る素通りを防ぐ。R-006 / R-016）
- HO 未適用の間は CI で live が走らないため、**E-1 は未達扱い**（ローカル実行だけで合格にしない）。PR は ready にしない

#### HO の適用順序（改訂 4 / D-017 / R-013・R-014）

- patch の 2 step（参照パーサーの導入・差分テスト）に `if: hashFiles('tests/requirements-seed-delta-reference.txt') != ''` を付ける。
  requirements が無い ref（main・他 PR）では skip されるため、HO patch は #1611 に依存せず**先に** main へ入れられる
- 順序: T-26（patch を実測値で確定・dry-run）→ H-6（Human が origin/main から feature ブランチを切り `apply-test-yml.sh` で適用 → PR → merge）
  → #1611 を main に追従 → T-28（#1611 の CI で live が走ることを確認）。循環依存は無い
- skip 中（requirements が無い / HO 未適用）は E-1 未達扱いを維持する。step が skip されたジョブを E-1 の証跡にしない
- 差分テストは `run-tests.sh` とは別の専用 step にし、`SEED_DELTA_MINIMIZE=0`（CI では最小化 off・失敗 seed の出力のみ）と
  step の `timeout-minutes` を持つ（R-018）。`Run CLI tests` の env は変えない
- **差分テストは test.yml の別 job `seed-delta-reference` に置く（改訂 5 / R-019 / D-018）**。既存 job `plangate-cli`
  （`timeout-minutes: 10`・step 不変）とは `needs` で繋がず並列に走り、時間予算を共有しない。
  理由: main の Test 直近 9 回（success、2026-10-22〜26）の `plangate-cli` job 所要は 297〜441 秒（中央値 331 秒）で、
  同じ job に載せると差分テストの余地は 10 分 − 441 秒 ≒ 2.65 分しかなく、venv 作成と pip install も同じ予算から引かれる
  （L3 M-1。job timeout の引き上げは既存テストの暴走検出を弱めるため採らない）
- 新 job の時間予算（暫定値。T-26 で確定）: job `timeout-minutes: 15`、install step `3`、差分 step `10`。
  不変条件: **step timeout の合計 < job timeout**（checkout の余地 ≥ 2 分）。T-26 で差分テストのローカル実測時間 t（`SEED_DELTA_MINIMIZE=0`）を測り、
  差分 step の timeout を `max(5, ceil(2t))` 分（CI ランナーとローカルの速度差の余裕 2 倍）、job timeout を「step 合計 + 2」以上に確定する。
  `ceil(2t)` が 20 分を超える場合は H-6 の前に停止し、生成件数か job 構成の見直しを Human に提示する。E-1 の時間上限は差分 step の timeout とする
- 存在対照（改訂 5 / R-020）: hashFiles ガードは requirements の削除・改名で step を恒常的に skip させ、CI は緑のまま残る。
  これを防ぐため、**#1611 の tests 側**（`scripts/test_improvement_seed_delta.py`。`run-tests.sh` → ta-116 経由で既存 job から呼ばれる）に
  「参照ハーネス `scripts/test_improvement_seed_delta_reference.py` が存在するなら `tests/requirements-seed-delta-reference.txt` も存在し、
  markdown-it-py / mdurl の pin を含む」を assert する TC（TC-DIFF-11）を置く。HO verify も「ハーネスあり・requirements なし」を FAIL にする
- 適用スクリプトは main / master / release/* / detached HEAD では停止し、apply・rollback とも同じ前提検査と dirty 検査を行う。
  適用先は cwd の toplevel に固定し（環境変数による差し替えなし）、スクリプト自身の repo と一致しなければ停止する。
  **base 検証（改訂 5 / R-022）**: apply・rollback は `origin/main` が HEAD の祖先であること、`git diff --name-only origin/main` が
  `test.yml` と `docs/working/TASK-1608/ho/` 以外を含まないこと、`.github` 配下に untracked が無いことを検査する（Human は事前に `git fetch origin`）
- verify は PyYAML 必須で `safe_load` により次を検査する（改訂 5 / R-019・R-021）: jobs が `plangate-cli` / `seed-delta-reference` の 2 つだけ、
  `plangate-cli` の timeout 10・step 名列・`Run CLI tests` の run / env が不変、新 job に `needs` / `continue-on-error` / `if` / `strategy` が無い、
  新 job の step 名列が固定、各 step の `if` が hashFiles ガード・`continue-on-error` 不在・**`run` の非空行集合が固定値と完全一致**（`|| true` や追加の `pip install` を拒否）、
  install step の env 不在、差分 step の env が `SEED_DELTA_REFERENCE=1` / `SEED_DELTA_MINIMIZE=0` と完全一致、step timeout の合計 < job timeout。
  requirements があれば版と全依存の sha256 を検査し、ハーネスがあって requirements が無ければ FAIL
- **`--dry-run` / `--verify` の保証範囲（改訂 5 / R-023）**: `--dry-run` は `git apply --check` のみ、`--verify` は YAML / requirements の構造のみで、
  ブランチ・base・dirty 検査は行わない。**どちらの成功も「現在のブランチで apply してよい」ことの証拠にしない**（スクリプト冒頭と TC-HO-04 に明記）。
  適用安全性の検査は apply / rollback の前提検査が担う

#### V-B 生成テスト

- `random.Random(seed)`。軸: コンテナ種別・深さ 0〜3、列 0〜7 + タブ、空行 0〜2、fence / HTML type 1・2・6・7 と閉じの有無、indented code、
  thematic break、setext、seed / 非正規見出し / `confirmed_by` / **コンテナマーカー直前の不可視文字（独立軸。R-008）**
- `out_of_scope=False` 側として、列 2 以上の段落継続・リスト内 fence など**受理されるべき入れ子でない構造**を必ず生成する（R-009。D-1d の誤拒否を空でなく測る）
- 失敗は行削除による簡易最小化（1 行ずつ外して判定が変わらない限り削る）で縮め、fixture に固定する

#### V-C コーパス（R-003）

- `improvement-seeds.md` 全リビジョン（7）+ `improvement-digest.md` 全リビジョン（1）。全件で FALSE_REJECT 0・AGREE、HEAD は REVIEW_CANDIDATE / 7 / 2 / 5
- コーパスは列 2 以上の `-` / `>` / 番号行を含まない（実測）。D-1d の誤拒否 0 は**コーパスでは空で満たされる**ため、誤拒否の測定は V-B の
  `out_of_scope=False` 側と正常系 fixture（TC-NEST-N4〜N6）で行う（R-009）
- CI の checkout は浅いため、全リビジョンは fixture として同梱する（取得コマンドと各 blob SHA を記録）

#### 停止条件（改訂 3 / R-004）

- E-1 live（CI とローカル）: MISMATCH 0・FALSE_REJECT 0・件数 assert 成立・**実行時間が上限内**（上限は別 job `seed-delta-reference` の
  差分 step の `timeout-minutes`。T-26 のローカル実測 t から `max(5, ceil(2t))` で確定。既存 job の予算とは独立。R-018 / R-019）。
  CI 側は hashFiles ガードで step が実行されたジョブに限る
- E-2 コーパス: FALSE_REJECT 0・全件 AGREE
- E-3 陽性対照: 旧実装 2 本でそれぞれ MISMATCH または FALSE_REJECT ≥ 1
- E-4 軸別の `out_of_scope=False` かつ AGREE の件数が各軸値で下限以上（R-017。全体比率は補助指標）
- E-5 変異（impl の状態遷移 + 常に拒否 / 常に空 + `reference_view` の射影規則 + `out_of_scope` の過大変異 2 種）がすべて KILLED
- 証跡（R-012）: E-1 のログ・seed 範囲・参照パーサーの版と spec 版・実行時間を `evidence/test-runs/` に残す。CI はジョブログの URL を記録
- R8 は検証モデルの穴（射影の誤り・文法外構造・`out_of_scope` の判定誤り）に焦点を置く
- 再停止: 是正後も別クラスの MISMATCH が 3 回連続 / 陽性対照が成立しない / コーパスで FALSE_REJECT

#### スコープ膨張の指摘（R-011 = Codex 中）の採否

**一部採用**。golden fixture・golden 再生成手順・delta debugging の自動化は削り、CI でも live の直接比較 1 経路に絞る
（HD-1=y で golden が不要になり、major-2 の陳腐化・自己参照の経路も同時に消える）。最小化は行削除だけの簡易版にする。
**生成テスト・全履歴コーパス・変異注入は残す**: R1〜R7 は手書きの再現だけで毎回新クラスを取りこぼしており、
「再現済み回避クラス + 既存コーパス」に絞ると、改訂 3 の目的（Human 決定「検証設計を変える」）そのものが成り立たない。
全履歴コーパスは 8 ファイルで費用が小さく、変異注入は既存の運用（T-9 / T-15 / T-21）の継続である。

不採用の代替案（Q-1 で Human 決定済み）: `markdown-it-py` をハッシュ固定で追加して AST を使う。
CI の依存導入（`.github/workflows/*.yml` = HO パス）と standalone 実行の前提を変えるため採らない。
敵対レビューで同層の新クラスが 2 ラウンド続いた場合に限り、再提示する。
（改訂 3 注記: 実装の判定には引き続き使わない。HD-2 で**テスト側の参照パーサーとしてのみ**採用した）

### D-2: 不可視文字（AC-5）— 推奨: 拒否（fail-closed）

- 入力全体を `utf-8-sig` で読み、先頭 BOM を除去（R4 是正を維持）
- 見出し行・`confirmed_by` 行に Unicode カテゴリ `Cf`（ZWSP 以外の書式文字を含む）・文中 BOM・
  NBSP 等の非 ASCII 空白が含まれたら `ValueError`（正規化して受理はしない）
- 理由: 正規化すると「表示上は同じだが digest の識別子とバイト列が違う」状態を受理することになり、
  digest 側との同一性判定がずれる。現行データに該当文字は無い（exec の T-1 で実測して確認する）

### D-3: 否定値の判定（AC-6）

- **推奨: 現行の「値全体または先頭トークンが否定値なら拒否」を維持する**（`Na Yeon` / `No Kim` の誤拒否は
  安全側の誤りとして残存脅威に残す）
- 理由: 先頭トークン判定をやめて「値全体（括弧注記を除く）」だけにすると、`no, later` / `no 後で` のような
  否定値が受理される fail-open が生まれる。人名と否定値の区別は字句では決まらず、誤拒否（Human が表記を直せば済む）より
  誤受理（未確認 seed が確認済みとして数えられる）の方が害が大きい
- 変更するのは字句化の境界だけ: 区切りに全角空白・タブを含め、不可視文字は D-2 で先に拒否する
- `naoki` / `nobu`（先頭トークンが否定値でない）は現行どおり受理されることをテストで固定する

### 出力・インターフェース

`inventory()` / CLI の引数・JSON のキーと値域・エラー時 rc=2 は不変。

## Work Breakdown

| Step | 内容 | Output | Risk | 🚩 |
|------|------|--------|------|----|
| S1 | 現行データの不可視文字・HTML コメント・setext の実測と、R1〜R4 の最小再現を test-cases の ID 付きでテスト化（先に RED / 既存挙動の固定） | テスト追加コミット | 低 | 新テストのうち AC-2 / AC-5 / AC-6 系が現行実装で FAIL することを確認 |
| S2 | ブロック状態機械の実装（D-1） | `improvement_seed_delta.py` | 中 | 既存 22 件 + S1 の構造系テストが PASS |
| S3 | 不可視文字・否定値判定（D-2 / D-3） | 同上 | 中 | AC-5 / AC-6 テスト PASS |
| S4 | 旧正規表現（`SEED_HEADING_LIKE` / `mask_code_blocks` / `DIGEST_SECTION`）の撤去と docstring の残存脅威モデル更新 | 同上 | 低 | 未使用コードゼロ |
| S5 | 変異注入（状態遷移ごとに 1 変異）で新テストの検出力を実証 | evidence/test-runs/ | 中 | 各変異で 1 件以上 FAIL |
| S6 | 敵対レビュー R1 / R2（下記） | review-external.md | 高 | 収束判定 |
| S7（改訂） | D-1b のコンテナ境界拒否を実装し、R4 再現を拒否側 TC として追加。現行データで誤拒否ゼロを再測定 | `improvement_seed_delta.py` / テスト | 中 | TC-CB-* PASS・7 / 5 不変・変異注入 |
| S8（改訂） | 敵対レビュー R5 / R6（コンテナ境界の拒否規則の回避と、規則による正常系の破壊） | review-external.md 追記 | 高 | 収束判定 |
| S9（改訂 2） | D-1c の入れ子拒否を実装し、R6 の再現 A / B を拒否側 TC に追加。内容オフセット固定（R6 m-1）を是正。現行データで誤拒否ゼロを再測定 | `improvement_seed_delta.py` / テスト | 中 | TC-NEST-* PASS・7 / 5 不変・変異注入 |
| S10（改訂 2） | 敵対レビュー R7 / R8（入れ子拒否の回避と正常系の破壊） | review-external.md 追記 | 高 | 収束判定 |
| S11（改訂 3） | 参照パーサー依存（ハッシュ固定）・`reference_view` / `out_of_scope` と単体テスト・4 値判定の差分ハーネス・陽性対照 fixture | `scripts/test_improvement_seed_delta_reference.py` / fixture / requirements | 中 | 陽性対照 2 本で検出 ≥ 1・impl 未 import |
| S12（改訂 3） | V-B 生成器（R-008 / R-009 の軸）と V-C コーパス fixture。D-1d を実装し TC-NEST-C4〜C7 / N4〜N6 を追加 | 同上 / `improvement_seed_delta.py` | 中 | E-1〜E-4 をローカルで成立 |
| S13（改訂 3・4・5） | HO patch（`test.yml`、別 job `seed-delta-reference`・hashFiles ガード・step / job timeout）と適用スクリプトを用意し、T-26 の実測で確定して dry-run の結果を記録。**適用は Human が feature ブランチ → PR で #1611 より先に main へ** | `docs/working/TASK-1608/ho/` | 中 | Human 適用後に #1611 の CI で E-1 成立 |
| S14（改訂 3） | 変異注入（E-5）と敵対レビュー R8（検証モデルの穴） | evidence / review-external.md | 高 | 停止条件 E-1〜E-5 |

## Files / Components to Touch

- `scripts/improvement_seed_delta.py`（PG-SH-GUARD ブロックはバイト不変）
- `scripts/test_improvement_seed_delta.py`（同上）
- `docs/working/TASK-1608/` 配下
- 改訂 3 で追加: `scripts/test_improvement_seed_delta_reference.py`（差分ハーネス）/ `tests/requirements-seed-delta-reference.txt` /
  差分テスト用 fixture（陽性対照の旧実装 2 本・V-C コーパス 8 本・最小化した失敗例）
- HO パスへの変更: AI は**行わない**。`.github/workflows/test.yml` の patch と適用スクリプトを `docs/working/TASK-1608/ho/` に置き、適用は Human（HD-1）。
  `tests/extras/ta-116-*.sh` は変更しない（差分ハーネスは CI の専用 job `seed-delta-reference` とローカルの直接実行で呼び、`run-tests.sh` には載せない。改訂 4・5 / R-018・R-019。
  存在対照 TC-DIFF-11 は `scripts/test_improvement_seed_delta.py` に置き、既存 job から ta-116 経由で走る / R-020）

## Testing Strategy

- Unit: `python3 scripts/test_improvement_seed_delta.py`（既存 22 件 + 追加分）
- Integration: `sh tests/extras/ta-116-improvement-seed-delta.sh` / `sh tests/extras/ta-70-py-sh-misinvocation-guard.sh`
- 現行データ: CLI 実行で REVIEW_CANDIDATE / 7 / 5（AC-3）
- 変異注入: 状態機械の各遷移（fence 閉じ条件 / HTML コメント終了 / indented code 判定 / setext 拒否 / 不可視文字拒否 / 否定値の先頭トークン判定）を 1 つずつ壊し、FAIL を確認
- Verification Automation: 上記 3 コマンドを `evidence/test-runs/` にログ保存
- 差分テスト（改訂 3）: `SEED_DELTA_REFERENCE=1 python3 scripts/test_improvement_seed_delta_reference.py`（ローカル・CI 同範囲）。停止条件 E-1〜E-5 は「検証モデル」節

## 敵対レビューのラウンド設計（§7-quater）

- **ラウンド下限: 2**（Mode = high-risk）。上限は定めず、収束判定で打ち切る
- R1: 新パーサーへの回避（台帳の既存クラスの再現 + 新しい構造: blockquote / ネストリスト / setext / HTML type 1・6・7 / CRLF / タブ展開 / 4 空白 fence）
- R2 以降の焦点: (1) 是正が実は効いていない経路（別のブロック種別で同じ隠蔽ができないか）(2) 状態機械の追加が生んだ穴（未閉 HTML コメントなど新しい fail-open）(3) fail-closed 化が現行データ・正当な人名を壊していないか
- 収束判定: 新しい**原因の層**のクラスが出なくなったか。同じブロック状態機械の層で新クラスが 2 ラウンド続いたら、
  継ぎ当てをやめて Q-1 の代替案（markdown-it-py）への切り替えを Human に提示する
- 改訂後（D-1b）は R5 から数え直し、**下限 2 ラウンド（R5 / R6）**。R5 の焦点は「空行なし境界の拒否規則を、別の境界の作り方
  （タブ・lazy continuation・入れ子・順序付きリスト）で回避できないか」と「規則が正当な文書を誤拒否しないか」。
  R5・R6 でコンテナ軸に新クラスが続いた場合は再度停止して Human に戻す（R5・R6 で該当し停止、D-014）
- 改訂 2（D-1c）後は R7 から数え直し、**下限 2 ラウンド（R7 / R8）**。焦点は「入れ子判定の回避（不可視文字・タブ・
  オフセットの異なるマーカー・lazy 継続行のマーカー）」と「入れ子拒否による正常系の破壊」。コンテナ軸で新クラスが
  2 ラウンド続いた場合は再停止する
- 台帳は `review-external.md` に追記専用（「前ラウンドが見つけられなかった理由」必須）
- 打ち切り時は完全性を主張せず、残存脅威モデルを docstring と handoff の両方に書く

## Mode 判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 2（+ working docs）→ light
- 受入基準数: 11 → high-risk
- タスク数（見込み）: 約 12 → high-risk
- 変更種別: 既存検査器の判定モデルの作り直し（リファクタ＋挙動変更）→ high-risk
- リスク: fail-closed 検査の判定境界を変える。誤ると seed の黙った欠落（fail-open）になる → 高
- 承認境界: HO パスには触れない。ただし `confirmed_by`（Human 確認マーカー）の受理判定を変える → 安全側で該当扱い
- **最終判定**: high-risk（定量・定性の最大値。`lite_eligible=false`、autonomous C-3 不可、Human C-3 必須）

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| 自作パーサーが CommonMark と食い違い新しい回避クラスを生む | 守備範囲外の構造は日付を含めば fail-closed。R2 で状態機械の層を集中的に突く。2 ラウンド連続で同層の新クラスなら Q-1 へ |
| fail-closed 拡大で現行データが落ちる | AC-3 を S2 / S3 / S4 の各 🚩 で再測定 |
| PG-SH-GUARD の drift | ガード領域は編集しない。ta-70 を S4 後に実行 |

## Stop Condition / Replan Triggers

- 標準ライブラリだけで AC-2 / AC-7 を満たせないと判明した → 停止し Q-1 を Human に提示
- 現行データの結果（7 / 5）が変わった → 停止し原因を報告
- 敵対レビューで同層の新クラスが 2 ラウンド連続 → 停止し設計切り替えを提示
- 改訂 3 以降は「検証モデル」節の停止条件 E-1〜E-5 と再停止条件で判定する（ラウンドの新クラス有無ではなく差分テストの結果）

## Human 判断事項（改訂 3、決定済み / D-016）

- **HD-1 = y**: CI でも参照パーサーと直接比較する。workflow は HO のため AI は patch・適用スクリプト・dry-run 手順まで、適用は Human
- **HD-2 = y**: `markdown-it-py` をテスト用ローカル依存にし、ハッシュ固定（実行時依存にはしない）
- **D-017（改訂 4）**: F-1 は (b) hashFiles ガード方式。HO patch は Human が feature ブランチ → PR で main に先行 merge し、#1611 は後続。skip 中は E-1 未達扱いを維持
- **D-018（改訂 5）**: L3 の M-1 / M-2 と minor を改訂 5 で局所是正し、**M-1 / M-2 の是正部分に限った短い確認を 1 本**入れてから C-3 へ進む

## Questions / Unknowns（決定済み）

根拠: Human 回答（2026-10-24、coordinator 経由で受領。いずれも推奨案を採用）。decision-log D-004〜D-007。

- **Q-1（決定）**: 標準ライブラリの限定ブロック状態機械（D-1）。`markdown-it-py` を実装の依存には追加しない（改訂 3 の HD-2 でテスト側の参照パーサーとしてのみ使用）
- **Q-2（決定）**: 不可視文字は拒否（D-2）
- **Q-3（決定）**: issue の AC 案「CommonMark 準拠の Markdown パーサー（AST）」を「判定に使うブロック種別は CommonMark の規則に従い、守備範囲外の構造は fail-closed」と読み替える（pbi-input AC-10）
- **Q-4（決定）**: 先頭語が否定値と同綴りの人名の誤拒否は残存脅威として残す（D-3）
