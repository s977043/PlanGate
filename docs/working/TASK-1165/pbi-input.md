# PBI INPUT PACKAGE: TC-14 凍結の射程限定 + `[WARN]` 可視化 + JSON 読込の単一定義化（PBI-B）

> 対応 issue: [#1165](https://github.com/s977043/plangate/issues/1165)
> 分割元: [#1162](https://github.com/s977043/plangate/issues/1162)（PBI-A）
>
> 受入基準は issue #1165 の **AC-01〜AC-07 を改変せず転記**している。
>
> | | #1162（PBI-A） | 本 PBI（#1165 / PBI-B） |
> |---|---|---|
> | 内容 | 件数契約 3 箇所の置換 + S-3 | **TC-14 凍結の射程限定 + `[WARN]` 可視化 + JSON 読込の単一定義化** |
> | Mode | high-risk | **critical** |
> | ガバナンス判断への依存 | なし | **あり**（#917 由来の凍結改訂の承認 = D-1） |
> | 先行依存 | — | **#1162 のマージ**（技術的な必須依存は解消済み。`ta-57-pr-convergence.sh` の並行改変を避けるための**順序制約**として維持） |

## Context / Why

### 一時的スコープ制約が共有スイートで恒久凍結に変質している

`tests/extras/ta-57-pr-convergence.sh:568`（本セッションで一次照合）:

```sh
_t57_ac7_files="scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py"
```

同 `:608-612` が `git diff --stat "$_t57_base" -- $_t57_ac7_files` を取り、**非空なら FAIL**。

一次ソースを追跡した結果、この AC-7 は **TASK-0917 という個別 PBI の Out of scope 自己拘束**
だった:

- `docs/working/TASK-0917/todo.md:5` — 「**`delivery.py` / `c3_contract.py` /
  `c3prime_verify.py` は一行も触らない**（AC-7）」
- `docs/working/TASK-0917/review-external.md:39`（R-006 / major）— 定数単位
  （`STATES` / `TRANSITIONS` / `PRIORITY_ORDER`）の差分ゼロでは「**本体に後方互換な分岐を
  足しても鳴らない ＝ Out of scope を破っても AC が通る**」と指摘され、**ファイル単位の
  差分ゼロ**へ強化された

つまり「**この PBI では触らない**」という一時的制約が、共有スイートに `origin/main` との
恒久比較として置かれ、**全リポジトリ・全 PR に対する無期限凍結**へ変質している。

TC-14 導入コミット `ff46761`（2026-07-31）以降、この 3 ファイルを触った PR は **0 本**。
**一度も正当な変更と衝突しないまま沈黙して効いてきた**。

これは #1162 が扱う件数契約と**同一原因の別方向**である:

> **一時点・一 PBI の状態を、射程を宣言しないまま共有スイートに恒久契約として置いた**

| 方向 | 症状 | 本 PBI の該当 |
|------|------|--------------|
| **射程が広すぎる** | 無関係な変更で鳴る | `ta-57:568` の無期限凍結（B-1） |
| **射程が狭すぎる** | 壊れても鳴らない | `ta-57:600-605` の `[WARN]` が集計されない（B-2） |

### 併発している false green

base ref 不在（PR 時 CI の `actions/checkout` は `fetch-depth` 未指定＝既定 1）や
base ref == HEAD（push-to-main）では、TC-14 は `[WARN]` 経路へ落ちる（`:600-605`）。
この経路は **`pass` にも `fail` にも計上されない**ため、**ローカル feature branch だけ RED /
CI は緑**という分裂が起きる。

### これが JSON 読込の単一定義化をブロックしている

`scripts/ai-loop/` の実害ある重複は **JSON 読込 10 箇所 / 5 ファイル**。集約先として自然な
`c3_contract.py`（既存の単一定義点）は、**凍結対象 3 ファイルに含まれる**。したがって凍結を
改訂しない限り、`c3_contract.py` に `read_json()` を追加した時点で `ta-57` TC-14 が必ず
FAIL し `sh tests/run-tests.sh` が exit 0 にならない。

**ただし 10 箇所すべてを集約対象にはしない**。10 箇所のうち 3 箇所（`delivery.py:538,540` /
`c3prime_verify.py:56`）は**凍結を維持すると決めた 2 ファイルの中**にあり、集約すると
B-1 の「判定エンジンを不用意に変えない」保護と正面から衝突する。本 PBI は
**凍結対象外の 7 箇所**を集約する（下記 B-3）。

## What（Scope）

### In scope

#### B-1: `ta-57` TC-14 の無期限凍結を、射程を限定した不変条件へ置換する

**設計案（実現可能性を検証済み・#1165 本文で確定）**: 凍結リストから **`c3_contract.py`
のみを外し**、`c3_contract.py` は「**削除行 0（追加のみ）**」の検査へ移す。
`delivery.py` / `c3prime_verify.py` は**ファイル単位 0 行差分のまま維持**する。

| ファイル | 置換後の不変条件 | 判定手段（案） |
|---------|----------------|--------------|
| `delivery.py` | ファイル単位 **0 行差分**（現行維持） | `git diff --stat "$base" -- <file>` が空 |
| `c3prime_verify.py` | ファイル単位 **0 行差分**（現行維持） | 同上 |
| `c3_contract.py` | **削除行 0（追加のみ許可）** | `git diff --numstat "$base" -- <file>` の**削除カラムが 0** |

- **単純に定数単位（`STATES` / `TRANSITIONS` / `PRIORITY_ORDER`）の差分ゼロへ戻すことは禁止**
  （R-006 の指摘を無効化する退行になる）
- 上記案は「後方互換な関数追加」と「`assess()` への分岐追加」を**意味論的に区別する必要が
  ない**（**ファイル境界で分ける**）
- 維持すべき継続的価値: 「**判定エンジンの判定規則を不用意に変えない**」
- **R-006 の「ファイル単位」強化は 3 ファイル中 2 ファイル（`delivery.py` /
  `c3prime_verify.py`）で温存される**

##### 意図した緩和と、その残存リスク（正直に記録する）

`c3_contract.py` に限り「0 行差分」→「削除行 0」へ**緩和**される。その結果:

- ✅ 後方互換な関数追加（`read_json()` の追加＝B-3）は通る（**これが緩和の目的**）
- ✅ 既存行の**削除・改変**は FAIL する（改変は `git diff --numstat` 上で削除 1 行を伴う）
- ⚠️ **既存関数の内部に行を追加するだけの変更は通る**（削除を伴わないため）

最後の 1 点は**意図した緩和の副作用として残存する**。`c3_contract.py` は契約定数と
I/O なし純関数の層であり、振る舞い変更は `test_c3_contract.py` の既存テスト群と
層契約検査（AC-05）が捕捉する。**「凍結が維持されている」とは書かず、「c3_contract.py は
追加のみ許可へ緩和した」と `handoff.md` に明記する**。

#### B-2: `[WARN]` スキップを判定結果に現す

`ta-57:600-605` は現在 **stderr に `[WARN]` 4 行**を出すのみで `pass` / `fail` のどちらにも
計上されない。**stdout に `[UNVERIFIED] TC-14 ...` を 1 行出す**ことで「検証されていない」を
緑と区別できるようにする。

**採用案は (a) で確定**（#1165 本文の記述と一致）。plan 段階で再検討しない:

| 案 | 内容 | 採否 | 理由 |
|----|------|------|------|
| **(a)** | `ta-57:600-605` の `[WARN]` ブロックで **stdout に `[UNVERIFIED] TC-14 ...` を 1 行出す** | **採用** | 共有 harness を触らずに済み、stdout に出るため CI ログで埋没しない |
| (b) | `t57_pass` / `t57_fail` に加えて**第 3 の集計**（`t57_unverified`）を持ち、サマリへ出す | 不採用 | `tests/run-tests.sh` の 2 値サマリ改変を伴い **Files to Touch 外**（共有 harness） |
| (c) | `PG_STRICT=1` 指定時のみ FAIL にする | **不採用** | **既定 run の出力が何も変わらない**ため AC-03（「検証されていないことが stdout に現れる」）を満たさない |

- `tests/run-tests.sh` の 2 値サマリ（`pass` / `fail`）は**改変しない**（共有 harness を触らない）

#### B-3: JSON 読込の単一定義化（**凍結対象外の 7 箇所**）

`scripts/ai-loop/c3_contract.py` に `read_json(path)` を追加し、**凍結対象外の 7 箇所**を集約する。

##### 集約する 7 箇所

| # | 箇所 | 形式 |
|---|------|------|
| 1-3 | `run_evidence.py:243` / `:357` / `:411` | 1 行形式 |
| 4-6 | `run_evidence_verify.py:93` / `:285` / `:418` | 1 行形式 |
| 7 | `discovery.py:182+186` | 2 行形式（`read_text` → `json.loads`）。**`sys.path` bootstrap の新設を伴うため据え置き判断あり**（U-05 / D-3） |

##### 集約しない 3 箇所（**明示除外 / スコープ限定の中核**）

| 箇所 | 扱い | 理由 |
|------|------|------|
| `delivery.py:538` / `:540` | **据え置き** | **B-1 でファイル単位 0 行差分の凍結を維持すると決めたファイル**。置換は既存行の削除を伴うため、集約した時点で TC-14 が必ず FAIL する |
| `c3prime_verify.py:56` | **据え置き** | 同上 |

- **B-1 と B-3 の衝突（C-01 / critical）を解消するための仕様確定**。3 巡目の敵対レビューで
  「B-1 が凍結維持と決めた 2 ファイルの中に B-3 の集約対象 3 箇所がある」＝**同一ファイルに
  正反対を要求している**ことが実測で検出された（`git grep -n 'json\.loads' origin/main --
  scripts/ai-loop/delivery.py scripts/ai-loop/c3prime_verify.py` = 3 ヒット）
- **「3 ファイルとも削除行 0 にする」案は成立しない**。`json.loads(X.read_text(...))` →
  `read_json(X)` の置換は**既存行の削除を伴う**。`c3_contract.py` で削除行 0 が成立するのは
  そこが**純粋な関数追加**だからである
- これは**価値の縮小**だが、**凍結の目的そのものと整合する**縮小である（7/10 の集約は達成）。
  据え置いた 3 箇所は `handoff.md` に「**凍結解除時の後続候補**」として記録する（T-14）

##### 共通の制約

- **新規ファイルを作らない**（`scripts/sync-plugin-plangate.sh:428`（for 列挙）と
  `:440`（case allowlist）にファイル名がベタ書きで二重に存在し、新規ファイルは自動では
  配布されないため。本セッションで一次照合済み）
- **層契約を守る**: `c3_contract.py:7-14` の docstring は「I/O あり関数（`sha256_of_file`）は
  producer / 受理器のみが使用し、**arbiter は import / call しない**」「共通層から新たな
  ファイル読取依存を持ち込まない」と定めている（#896 AC-6）。`read_json` は 2 本目の
  I/O 関数になるため、**`test_c3_contract.py:201 test_arbiter_does_not_touch_io_layer` の
  assert 対象に `read_json` を追加**する（現在は AST 上で文字列 `sha256_of_file` のみを
  assert しており、新関数には効かない。本セッションで一次照合）
- 各呼び出し側の例外処理（`ValueError` / `OSError` / `json.JSONDecodeError` の扱いと
  メッセージ）が箇所ごとに異なるため、**呼び出しごとに挙動不変を 1 箇所ずつ確認**する

##### 採用基準と、基準そのものによる除外

- **採用基準**: `pathlib.Path.read_text(...)` の戻り値を `json.loads()` に渡す
  **ファイル由来の JSON 読込**（＝ファイルパスを受け取り dict / list を返す共通関数に
  寄せられる形）
- **基準外（「見落とし」ではないことを記録する）**:

| 箇所 | 除外理由 |
|------|----------|
| `arbiter.py:1160-1169` | (1) `open()` + `f.read()` の 2 行形式で、`--input-path` 未指定時は `sys.stdin.read()` に切り替わる **CLI / stdin 兼用**。パスを受け取る関数に寄せると stdin 経路が失われる。(2) **層契約（#896 AC-6）により arbiter は I/O 層を import / call しない**。`read_json` を arbiter から呼ぶことは AC-05 の回帰検査自体に違反する。**据え置く** |
| `delivery.py:461` | `json.loads(line)` — **NDJSON の 1 行**であってファイル読込ではない |
| `run_evidence.py:639` / `:658` / `:676` | `opts.get("harness-version")` 等の **CLI 引数文字列**のパース |
| `executor.py:448` / `gh_exec.py:670` | `proc.stdout` / `view.stdout` の **subprocess 出力**のパース |

> 実測（本セッション）: `grep -rn 'json\.loads' scripts/ai-loop/*.py | wc -l` = **61**
> （うち `test_*` を除く実装側が **17**）。前版の「全 17 ヒット」は**コマンドと数値が
> 一致していなかった**（コマンドはテストを含む 61 を返す）。本版では両方を併記する。

### Out of scope

- **件数契約 3 箇所の置換**（`ta-33:25` / `ta-33:54` / `ta-57:622`）→ **#1162**
- **`delivery.py:538` / `:540` / `c3prime_verify.py:56` の JSON 読込の集約**
  → 凍結維持のため**据え置き**（上記 B-3「集約しない 3 箇所」）。凍結解除時の後続候補として
  `handoff.md` に記録する
- `arbiter.py:1160-1169` の 2 行形式 JSON 読込（上表の理由で据え置き）
- **`discovery.py` を集約対象に含めるかの見直し**は行うが、**新たな import 経路の新設は
  しない**（下記 U-05 / 据え置き判断の材料）
- `scripts/sync-plugin-plangate.sh` の allowlist 二重ハードコードの単一定義化（V2 候補・別 issue）
- `tests/run-tests.sh` の集計方式の変更
- `bin/plangate` の分割 / `scripts/hooks/*.sh`（HO 対象）
- テストの検出力を下げる方向の変更（assert の緩和・失敗経路のスキップ）
- 凍結を**単に削除**すること（判定エンジンの保護が失われる）

## 受入基準

> issue #1165 の AC-01〜AC-07 を**改変せず転記**（増減・改変なし）。
> 運用解釈は AC 本文に書かず、下記の別節と plan.md に書く。

- [ ] AC-01: `ta-57` TC-14 が、`c3_contract.py` への**後方互換な関数追加**（B-3 相当）では
  **PASS** する
- [ ] AC-02: `ta-57` TC-14 が、以下の**いずれか**で **FAIL** する（変異注入で各 1 件実証）
  - `delivery.py` の `STATES` / `TRANSITIONS` / `PRIORITY_ORDER` の変更
  - `delivery.py` の `assess()` への分岐追加
  - `c3_contract.py` の**既存行の削除・改変**
  - `c3prime_verify.py` の変更（exit code 契約の緩和を含む）
- [ ] AC-03: base ref 不在・base ref == HEAD の環境で、TC-14 が**検証されていないことが
  stdout に現れ**、緑と区別できる
- [ ] AC-04: `scripts/ai-loop/` の JSON 読込が `c3_contract.read_json()` へ集約され、各呼び出し
  箇所で**リファクタ前後の挙動が同一**（例外の型・メッセージ・rc）であることをテストで確認済み
- [ ] AC-05: `test_c3_contract.py` の層契約検査（`test_arbiter_does_not_touch_io_layer`）が
  **`read_json` についても発火**する（arbiter が `read_json` を import / call したら FAIL する）
- [ ] AC-06: plugin 側コピー（`plugin/plangate/skills/ai-loop-cycle/`）で、**B-3 の前後で
  FAIL するモジュール集合が増えない**（baseline は T-01 の実測値を正とし、名指しリストを
  契約にしない）
- [ ] AC-07: `sh tests/run-tests.sh` が変更前の pass 件数以上で exit 0（**baseline 自体が
  TIMEOUT した場合は WARN=未検証**とし、個別スイートで代替判定する）

### 受入基準の運用解釈（AC 本文は不改変 / 詳細は plan.md）

- **AC-04 の「集約」の対象範囲**: **凍結対象外の 7 箇所**とする（B-3「集約する 7 箇所」）。
  判定エンジン 3 ファイル内の 3 箇所（`delivery.py:538,540` / `c3prime_verify.py:56`）は、
  **凍結が意図する「判定規則を不用意に変えない」という保護と両立しないため据え置く**。
  AC-04 の「各呼び出し箇所で挙動が同一」は**集約した箇所**について判定する。
  据え置いた 3 箇所は `handoff.md` に「凍結解除時の後続候補」として記録し、
  **「10/10 集約」とは書かない**
- **AC-06 の baseline の取り方**: `plugin/plangate/skills/ai-loop-cycle/` を
  **skill ディレクトリ全体でコピー**する（`scripts/` のみのコピーは不可）。
  実物の依存: `scripts/ai-loop/test_arbiter.py:159,898,903` が
  `plugin/plangate/skills/ai-loop-cycle/references/ho-paths.md` および
  スクリプト位置基準の `../references/ho-paths.md` を解決対象にしており、
  `scripts/` だけのコピーでは**この 1 本が追加で FAIL する**（本セッションで参照箇所を一次照合）。
  skill ディレクトリの構成は `agents/` `references/` `schemas/` `scripts/` `SKILL.md`。
  **baseline は T-01 の実測結果を正とし、FAIL モジュールの名指しリストを AC の契約にしない**
  （名指しリストは測定時点の値であり、無関係な変更で stale になるため）。
  加えて **baseline の「実行されたモジュール総数」を記録**し、変更後も**同数以上**であることを
  受理条件に含める（総数 0 のまま「FAIL 集合が増えていない」で PASS する恒真経路の排除）
- **AC-07 の TIMEOUT 時の判定式**: 時間予算 **1,800 秒**。**変更後・baseline のどちらが
  TIMEOUT（rc=124）でも AC-07 を WARN（未検証）**として記録し、「PASS」とも「FAIL」とも
  書かない。個別スイートで代替判定し、未検証範囲を `handoff.md` に明示する
- **AC-01 の「PASS する」の判定**: 「FAIL 行が無い」だけでは足りない。TC-14 は `[WARN]`
  経路（`:600-605`）に落ちると `pass` / `fail` のどちらにも計上されないため、
  **`[PASS] TC-14 / AC-7:` 行が出ること**と **`[WARN] TC-14` 行が出ないこと**を受理条件に
  加える（実行された証拠。test-cases 前提 P-1）
- **AC-02 の「各 1 件実証」**: 4 種すべてについて変異を注入し、**被検査スイート
  （`ta-57`）の TC-14 が FAIL すること**を確認する（1 種でも kill できなければ採用しない）

## Mode 判定

**モード**: `critical`

**判定根拠**（[`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md) 準拠）:

| 判定軸 | 実測 | モード |
|--------|------|--------|
| 変更ファイル数 | `ta-57-pr-convergence.sh` / `c3_contract.py` / `test_c3_contract.py` / `run_evidence.py` / `run_evidence_verify.py`（+ `discovery.py` は据え置き判断次第）= **5〜6** ＋ plugin 同期生成物（`delivery.py` / `c3prime_verify.py` は **B-3 のスコープ限定により不変**） | 中〜高（3-15） |
| 受入基準数 | **7**（AC-01〜AC-07） | 高（6-10） |
| タスク数（見込み） | **15**（todo.md の実装・検証・完了タスク実数。**plan / C-1 / C-2 等のワークフロー工程は数えない**） | 高（11-20） |
| 変更種別 | **#917 由来のガバナンス決定（全 PR に効く共有ゲート契約）の改訂** ＋ **#896 の層契約への I/O 関数追加** | **超高**（統制ルールの変更に相当） |
| リスク | 凍結の射程を誤ると**判定エンジンの無断改変が無検出**になり、R-006 の指摘を無効化する退行になる | 極高 |
| 影響範囲 | 全 PR が通る共有スイート ＋ ai-loop 判定エンジン ＋ plugin 配布物 | **超高**（システム全体） |
| ロールバック | B-1 → B-3 の順で積むため、**段階的ロールバック**が必要（B-1 を戻すと B-3 が構造的に RED になる） | **超高** |
| **最終判定** | 定量（高）と定性（**超高**）の高い方 | **critical** |

**変更種別軸**: `code`（`.sh` / `.py` を含むため doc-light は不適用）。

**Hardening Override 該当性**: **非該当**。接触予定パスは `tests/extras/*.sh` /
`scripts/ai-loop/*.py` / `plugin/plangate/skills/ai-loop-cycle/scripts/*.py`（同期生成物）/
`docs/working/TASK-1165/` のみで、HO 9 カテゴリ
（`.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md` /
`.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` /
`.github/workflows/*.yml|yaml` / `AGENTS.md` `CLAUDE.md`）のいずれにも該当しない。

> ⚠️ `schemas/*.schema.json` は HO 対象だが、`run_evidence_verify.py:93` が読む schema は
> **読取対象**であり編集しない。schema 変更が必要になったら即停止（A-06）。

## #1162（PBI-A）との相互依存

| 方向 | 依存の有無 | 根拠 |
|------|-----------|------|
| **本 PBI → #1162** | **技術的な必須依存は解消。順序制約のみ維持** | 3 巡目の是正（C-01）で B-3 が**凍結対象外 7 箇所**へ限定され、`delivery.py` は集約対象外になった。したがって `test_delivery.py` へ parity テストを追加する必要がなくなり、`ta-57` TC-15 の `-eq 57` は本 PBI の障害にならない。**ただし両 PBI とも `tests/extras/ta-57-pr-convergence.sh` を改変する**（#1162: `:622-623` / 本 PBI: `:568` と `:600-605`）ため、**衝突回避のため #1162 のマージ後に着手する** |
| **#1162 → 本 PBI** | **依存しない** | #1162 は `ta-33` / `ta-57` の assert 置換のみで、凍結対象 3 ファイルに触れない |

**運用**: 本 PBI の exec 開始前に、`git log origin/main` で **#1162 がマージ済みであること**を
実測確認する（todo T-01 の前提検査）。未マージなら着手しない（即停止条件）。

> 3 巡目レビューまでは「AC-04 が `delivery.py:538,540` の parity テストを要求するため
> `-ge 57` 化が必須」を依存の根拠にしていた。**C-01 の是正でその前提が消えたため、
> 依存の性質を「構造的達成不能性」から「同一ファイルの並行改変回避」へ書き換えた**。

## C-3 での要判断事項（人間へ上げる論点）

| ID | 論点 | AI の推奨 | 判断が必要な理由 |
|----|------|-----------|------------------|
| **D-1** | `ta-57` TC-14 の凍結契約を改訂してよいか（B-1 の可否） | **改訂する**（射程限定へ） | #917 由来の**ガバナンス決定**。AI が単独で解除すると「Out of scope 自己拘束」を AI が外したことになる。**REJECT の場合、B-3 は実行不能となり本 PBI 全体を取り下げる**（即停止条件） |
| **D-2** | `c3_contract.py` を「削除行 0（追加のみ）」へ緩和することを許容するか | **許容する**（B-3 を通すための最小の緩和） | 「既存関数の内部への行追加は通る」という残存リスクを受け入れる判断（上記「意図した緩和」節） |
| **D-3** | `discovery.py:182+186` を集約対象に含めるか（U-05） | **T-02 の実測後に判断。含められなければ据え置く** | `discovery.py` は **plugin 非配布**（`sync-plugin-plangate.sh:428` の for 集合に不在）かつ **`sys.path` bootstrap を持たない**ため、`c3_contract` を import させると**新しい import 経路の新設**を伴う |
| **D-4** | B-3 のスコープを**凍結対象外 7 箇所**に限定する（`delivery.py` 2 箇所 / `c3prime_verify.py` 1 箇所を据え置く）ことを許容するか | **限定する**（issue #1165 の起票者コメントで確定済み） | AC-04 の「集約」の射程を縮小する判断。価値は 10/10 → 7/10 に縮むが、B-1 の凍結維持と両立させる唯一の形（C-01 の是正） |

## Notes from Refinement

> 判断の記録先は `docs/working/TASK-1165/decision-log.jsonl`（append-only）。
> **本ファイル作成時点では未作成**であり、T-03 で初期化する。

1. **B-1 は「凍結の撤廃」ではなく「射程の限定」**。TASK-0917 R-006 の指摘（定数単位では
   後方互換な分岐追加を検知できない）を**無効化しない**形にする。ファイル境界で分ける案
   （`c3_contract.py` のみ「削除行 0」へ）は、**R-006 の「ファイル単位」強化を 3 ファイル中
   2 ファイルで温存する**。
2. **B-2 の採用案は (a) で確定**（`[UNVERIFIED]` を stdout に 1 行）。候補 (b)（第 3 集計）は
   `tests/run-tests.sh` の改変を要し Files to Touch 外、候補 (c)（`PG_STRICT=1` 時のみ FAIL）は
   **既定 run の出力が変わらないため AC-03 を満たさない**。plan で再検討しない。
3. **層契約（#896 AC-6）への追従は AC-05 として独立している**。`read_json` は 2 本目の
   I/O 関数であり、既存の回帰検査は文字列 `sha256_of_file` を AST で assert しているだけで
   新関数には効かない。**assert 対象へ `read_json` を追加するタスクを明示的に置く**（T-09）。
4. **`arbiter.py:1169` の除外理由は 2 つある**。CLI/stdin 兼用（技術的理由）に加えて、
   **層契約により arbiter は I/O 層を触れない**（規範的理由）。前版は前者しか書いておらず、
   「stdin 兼用でなければ集約してよい」と読める状態だった。
5. **判定規則はスイートごとに実物から導出する**。`ta-57` の FAIL は
   **先頭 2 空白 + `TA-57` を含まない + stderr**（`ta-57:39`）。`ta-33` 由来のパターンでは
   **永久に一致しない**（実測: rc=1）。詳細は test-cases.md 前提 P-1。
6. **正側 TC には「実行された証拠」を要求する**。TC-14 は `[WARN]` 経路で `pass` / `fail` の
   どちらにも計上されないため、「FAIL 行が無い」だけでは**恒真 PASS**になる。
7. **AC-06 の baseline は skill ディレクトリ全体のコピーで測る**。`scripts/` のみのコピーでは
   `test_arbiter.py` が `../references/ho-paths.md` を解決できず**追加で FAIL する**。
   コピー対象を TC に明記し、baseline は T-01 の実測結果とする。
8. **`plan.md` は本セッションで作成していない**。EH-3 が `PLANGATE_HOOK_TASK` 未設定時に
   rc=2 で BLOCK するため。`PLANGATE_HOOK_TASK` は**セッション起動時に固定**され実行中の
   `export` では効かないため、plan 生成は **Human タスク H-00** を前提にする。
9. **B-3 のスコープは 7 箇所へ限定した**（3 巡目 C-01 の是正 / D-4）。B-1 が凍結維持と決めた
   `delivery.py` / `c3prime_verify.py` の中に B-3 の集約対象 3 箇所があり、**同一ファイルに
   正反対を要求していた**。集約は既存行の削除を伴うため「削除行 0」案でも回避できない。
   据え置いた 3 箇所は `handoff.md` に「凍結解除時の後続候補」として記録する（T-14）。
   この縮小に伴い **#1162 への技術的な必須依存も解消**した（順序制約のみ残す）。

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和 |
|----|--------|------|------|
| R-01 | **B-1 の改訂が TASK-0917 R-006 の退行になる**（後方互換な分岐追加を検知できなくなる） | 極高（過去のレビュー指摘の無効化） | AC-02 の 4 種の負側変異をすべて注入し、**`ta-57` TC-14 が FAIL することを実証**してから採用する。実証できない案は採らない（即停止条件） |
| R-02 | **`c3_contract.py` の緩和が想定より広い**（既存関数内への行追加が通る） | 中（意図した緩和の副作用） | `handoff.md` に「c3_contract.py は追加のみ許可へ緩和した」と明記。`test_c3_contract.py` の既存テスト群と AC-05 の層契約検査で振る舞い変更を捕捉する |
| R-03 | `read_json()` 集約で**例外の型・メッセージが変わる**（`ValueError` を握っていた箇所が `OSError` を素通しする等） | 高（fail-closed の破壊） | **集約する 7 箇所**を 1 箇所ずつ、集約前後の例外型・メッセージ・rc を対比表で確認。`discovery.py:180-191` は `OSError` と `JSONDecodeError` を**別メッセージ**で `ValueError` に包み直しており最も差異が大きい |
| R-04 | **層契約（#896 AC-6）の回帰検査が新関数に効かない**まま完了する | 高（AC-05 未達に気付かない） | AC-05 を独立した TC とし、**arbiter が `read_json` を参照する変異で FAIL する**ことを実証する |
| R-05 | plugin 側コピーが同期されず **plugin 導入先だけ import エラー** | 高 | AC-06 の TC で **skill ディレクトリ全体を単独コピーしてのテスト実行**を必須にする。`sync-plugin-plangate.sh --dry-run` で差分 0 を確認 |
| R-06 | **AC-06 の baseline がコピー範囲で変わる**（`scripts/` のみ vs skill 全体で FAIL 本数が異なる） | 中（判定が測り方に依存） | **コピー対象を TC に明記**し、baseline / 変更後の**両方を同一手順**で測る。名指しリストを契約にしない |
| R-07 | **判定規則がスイート横断で成立せず、TC が恒真 PASS になる** | 高（TC 自体が無効） | 判定パターンを `ta-57` の実物から導出（`^ *\[FAIL\] TC-14`）し、`2>&1` でログを取り、**正側は `[PASS]` 行の存在と `[WARN]` 行の不在**も受理条件にする |
| R-08 | **`[WARN]` 経路で TC-14 が実行されず、正側 TC が恒真 PASS** | 高 | sandbox に **HEAD と異なる `main`** を用意する（fixture）。受理条件に `[WARN] TC-14` の不在を含める |
| R-09 | **フルスイートが完走しない**（sandbox 実測で 900 秒で rc=124） | 中（AC-07 が判定不能） | 時間予算 **1,800 秒**。**変更後・baseline のどちらが TIMEOUT でも WARN（未検証）**とし「PASS」と書かない |
| R-10 | **#1162 未マージのまま着手**し、`ta-57-pr-convergence.sh` の並行改変で衝突する | 中（マージ作業の増加。**AC の達成不能ではない**） | T-01 で #1162 のマージ済みを**実測確認**してから着手する（即停止条件） |
| R-11 | **D-1 が REJECT** され B-3 が実行不能になる | 高（PBI 全体が落ちる） | D-1 を C-3 の**明示論点**として上げる。REJECT なら本 PBI を取り下げ、`handoff.md` に理由を記録して停止 |
| R-12 | **plan 生成が着手できない**（`PLANGATE_HOOK_TASK` は起動時固定で AI が設定できない） | 中（起点が到達不能） | **H-00（Human）**を todo の起点に置き、`T-00a` を `H-00` に依存させる |
| R-13 | 変異注入が**空振り**（変異を入れても FAIL しない） | 高 | 変異は**呼び出し箇所（call site）を壊す**形で設計。空振りなら TC の欠陥として正直に記録する |
| R-14 | **据え置いた 3 箇所が「集約済み」と誤記録される**（AC-04 を 10/10 で PASS と書く） | 中（実態と記録の乖離） | AC-04 の運用解釈に射程を明記。`handoff.md` の必須項目に「据え置き 3 箇所と理由」を置き（T-14）、**「10/10 集約」の文字列を書かない**ことを検査する |

### Unknowns

| ID | 不明点 | 解消方法 |
|----|--------|----------|
| U-01 | `read_json()` の**シグネチャ**（例外を投げるか / デフォルト値を返すか / `ValueError` に包むか） | 集約する **7 箇所**の要求の**最大公約数**を T-02 で実測してから決める。fail-closed を壊さない形を優先 |
| U-02 | 7 箇所のうち **`read_json()` に寄せられない箇所**が何件あるか（`errors=` 指定や後続の型検査の差） | T-02 で 7 箇所の呼び出し文脈（例外処理 / encoding / 後続の型検査）を一覧化して判定。寄せられない箇所は理由を記録して**据え置く**（無理に統一しない） |
| U-03 | `git diff --numstat` の**削除カラムが 0** で「追加のみ」を判定する形が、rename / mode 変更 / binary で誤動作しないか | T-04 の RED で `--numstat` の出力形（`added deleted path`）を実測し、非数値（`-`）が出る条件を確認してから採用する |
| U-04 | AC-06 の **baseline FAIL モジュール集合と実行モジュール総数**（skill 全体コピー時） | T-01 で実測する。issue 起票時の参考値は「`scripts/` のみコピー → 4 本 / skill 全体 → 3 本」だが、**本 PBI では自分で測り直した値を正**とする |
| U-05 | `discovery.py` を集約対象に含められるか | T-02 で判定。`discovery.py` は **plugin 非配布**（`sync-plugin-plangate.sh:428` の for 集合に不在）かつ **`sys.path` bootstrap を持たない**（`grep -n 'sys.path' scripts/ai-loop/discovery.py` は 0 ヒット / 本セッション実測）。`c3_contract` を import させると**新しい import 経路の新設**を伴うため、**据え置きが既定**。含める場合は D-3 として人間判断へ上げる |
| U-06 | フルスイート（`sh tests/run-tests.sh`）の**変更前 pass 件数 baseline** | 並走がない時点で時間予算 1,800 秒で 1 回実行して記録（測定日時・ホスト・HEAD SHA とセット） |

### Assumptions

| ID | 前提 |
|----|------|
| A-01 | issue #1165 の AC-01〜AC-07 は**確定**であり、本 PBI で増減・改変しない（運用解釈は本ファイルの別節と plan.md に書く） |
| A-02 | **B-1 の設計案（`c3_contract.py` のみ「削除行 0」へ / 他 2 本はファイル単位 0 行差分維持）は issue #1165 本文で確定済み**であり、plan で別案へ差し替えない |
| A-03 | **B-2 の採用案は (a)（stdout に `[UNVERIFIED]` を 1 行）で確定**。(b) / (c) は採らない |
| A-04 | 変異注入は **sandbox（`mktemp -d` 上の複製）**で行い、原本には一切書き込まない。テスト終了時に明示削除する |
| A-05 | HO 対象パス（`.claude/**` / `scripts/hooks/**` / `bin/plangate` / `schemas/**` / `.github/workflows/**` / `CLAUDE.md` / `AGENTS.md`）は**読むだけで編集しない** |
| A-06 | 外部振る舞い（CLI IF・exit code 契約・hook 挙動・schema）は**すべて不変**。変える必要が生じたら即停止して人間判断を仰ぐ |
| A-07 | `plugin/plangate/skills/ai-loop-cycle/scripts/` は `scripts/ai-loop/` からの**同期生成物**であり、直接編集せず `sync-plugin-plangate.sh` 経由で更新する |
| A-08 | **B-1 → B-2 → B-3** の順序は固定であり入れ替えない（B-1 未完了で B-3 に着手すると TC-14 が FAIL する） |
| A-09 | **#1162 がマージ済み**であること（`ta-57-pr-convergence.sh` の並行改変を避ける順序制約。技術的な必須依存は C-01 の是正で解消済み）。未マージなら着手しない |
| A-10 | `plan.md` は `PLANGATE_HOOK_TASK=TASK-1165` を設定して**起動した**セッションで生成する（H-00） |
| A-11 | B-1 の可否は **C-3 で人間が判断する**（D-1）。AI が単独で #917 由来の凍結を解除しない |
| A-12 | **B-3 の集約対象は凍結対象外の 7 箇所**であり、`delivery.py:538,540` / `c3prime_verify.py:56` は据え置く（D-4。issue #1165 の起票者コメントで確定） |

## 実測の再確認（本セッション / HEAD `f8d7a0b` / 2026-08-19・2026-08-20）

> 測定はすべて **`origin/main` を明示**して行う（`git show origin/main:<path>` /
> `git grep <pat> origin/main -- <path>`）。作業ツリーの状態を根拠にしない。

| # | 項目 | 確認コマンド | 結果 |
|---|------|--------------|------|
| 1 | 凍結対象の定義 | `git show origin/main:tests/extras/ta-57-pr-convergence.sh \| sed -n '568p'` | `_t57_ac7_files="scripts/ai-loop/delivery.py scripts/ai-loop/c3_contract.py scripts/ai-loop/c3prime_verify.py"` |
| 2 | **B-1 と B-3 の衝突（C-01 の根拠）** | `git grep -n 'json\.loads' origin/main -- scripts/ai-loop/delivery.py scripts/ai-loop/c3prime_verify.py` | `c3prime_verify.py:56` / `delivery.py:461`（NDJSON・基準外）/ `delivery.py:538` / `delivery.py:540`。**凍結維持 2 ファイル内に集約対象が 3 箇所**存在する |
| 3 | 集約先に既存 JSON 読込が無いこと | `git grep -n 'json\.loads' origin/main -- scripts/ai-loop/c3_contract.py` | **0 ヒット**（`read_json` は純粋な**追加**になる＝削除行 0 が成立する） |
| 4 | `[WARN]` 経路と base ref 探索 | `git show origin/main:tests/extras/ta-57-pr-convergence.sh \| sed -n '587,605p'` | base ref 探索ループ = **`:589-599`** / `if [ -z "$_t57_base" ]` = `:600` / `[WARN]` printf **4 行** = `:601-604` / `else` = `:605`。`t57_pass` / `t57_fail` のどちらも呼ばれない |
| 5 | 判定規則のスイート差 | `printf '  [FAIL] TC-14 / AC-7: x\n' \| grep -q '^\[FAIL\] TA-57 TC-14'` / 同 `grep -qE '^ *\[FAIL\] TC-14'` | 前者 **rc=1**（永久に不一致）/ 後者 **rc=0** |
| 6 | 層契約 docstring | `sed -n '1,14p' scripts/ai-loop/c3_contract.py` | 「I/O あり関数: `sha256_of_file`。producer / 受理器のみが使用し、arbiter は import / call しない」を確認 |
| 7 | 層契約の回帰検査 | `sed -n '201,211p' scripts/ai-loop/test_c3_contract.py` | `test_arbiter_does_not_touch_io_layer` は AST の `node.attr` / `node.id` を **`"sha256_of_file"` とだけ**比較。**`read_json` には効かない** |
| 8 | `arbiter.py` の JSON 読込 | `sed -n '1158,1172p' scripts/ai-loop/arbiter.py` | `open()` + `f.read()` / `--input-path` 未指定時は `sys.stdin.read()` の **CLI/stdin 兼用**を確認 |
| 9 | 集約対象 7 箇所 | `git grep -n 'json\.loads' origin/main -- scripts/ai-loop/run_evidence.py scripts/ai-loop/run_evidence_verify.py scripts/ai-loop/discovery.py` | `run_evidence.py:243,357,411`（+ `:639,658,676` は CLI 引数・基準外）/ `run_evidence_verify.py:93,285,418` / `discovery.py:186`（`:182` の `read_text` と対） |
| 10 | JSON 読込のヒット数 | `grep -rn 'json\.loads' scripts/ai-loop/*.py \| wc -l` / 同 `\| grep -v '/test_' \| wc -l` | **61** / **17**（前版の「全 17 ヒット」はコマンドと不一致） |
| 11 | `register_cleanup` の実呼び出し | `git show origin/main:tests/extras/ta-57-pr-convergence.sh \| grep -n 'register_cleanup'` | **`:45` のみが呼び出し**。`:32` と `:667` は**コメント行** |
| 12 | TC-E8 ブロックの範囲 | `git show origin/main:tests/extras/ta-57-pr-convergence.sh \| sed -n '641,665p'` | **`:641-665`**（`:666` は空行、`:667` はコメント、`:668` が `rm -rf "$_t57_tmp"`） |
| 13 | plugin skill の構成 | `ls plugin/plangate/skills/ai-loop-cycle/` | `agents` `references` `schemas` `scripts` `SKILL.md`（**`scripts/` だけでは閉じない**） |
| 14 | `references/ho-paths.md` への依存 | `grep -rn 'references/ho-paths' scripts/ai-loop/test_arbiter.py` | `:159` / `:898` / `:903` の 3 箇所。**`../references/ho-paths.md`** を解決対象にしている |
| 15 | plugin 配布 `.py` 本数（**契約値にしない**） | `ls plugin/plangate/skills/ai-loop-cycle/scripts/*.py \| wc -l` | **28**（`scripts/ai-loop/*.py` は **30**。`discovery.py` / `test_discovery.py` が非配布） |
| 16 | `discovery.py` の `sys.path` bootstrap | `grep -n 'sys.path' scripts/ai-loop/discovery.py` | **0 ヒット**（bootstrap を持たない） |
| 17 | 二重 allowlist | `sed -n '425,445p' scripts/sync-plugin-plangate.sh` | `for` = **428** / `case` = **440**。`discovery.py` は**どちらにも不在** |
| 18 | `decision-log.jsonl` の存在 | `ls docs/working/TASK-1165/` | **存在しない**（T-03 で初期化する） |
