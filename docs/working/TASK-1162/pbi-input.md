# PBI INPUT PACKAGE: 件数契約 3 箇所の時限爆弾除去（PBI-A）

> 対応 issue: [#1162](https://github.com/s977043/plangate/issues/1162)
> 分割先: [#1165](https://github.com/s977043/plangate/issues/1165)（PBI-B）
>
> **本 PBI は 2 巡目の敵対レビュー（スコープ膨張の指摘）を受けて分割された後の PBI-A**。
> issue #1162 の最新コメント「分割しました」を仕様の正本とする。
>
> | | 本 PBI（#1162 / PBI-A） | #1165（PBI-B） |
> |---|---|---|
> | 内容 | 件数契約 3 箇所の置換（`ta-33:25` / `ta-33:54` / `ta-57:622`）+ S-3 | TC-14 凍結の射程限定 + `[WARN]` 可視化 + JSON 読込の単一定義化 |
> | Mode | **high-risk** | critical |
> | ガバナンス判断への依存 | **なし（即着手可）** | D-1（凍結改訂）の承認が前提 |
> | 受入基準 | **AC-01 / AC-02 / AC-03 / AC-06 / AC-07** | #1165 の AC-01〜AC-07 |
>
> 受入基準は issue #1162 から **改変せず転記**している（AC-04 / AC-05 / AC-08 / AC-09 は
> #1165 へ移管済みのため本 PBI には存在しない。**番号は詰めない**）。

## Context / Why

### 単一原因の 2 方向（分類の正本）

本 PBI が扱う件数契約は「型 A（絶対件数）」という独立の型ではなく、次の**単一原因**の
一方向として説明できる（issue #1162 のコメントで別セッションと相互検証・合意済み）:

> **一時点・一 PBI の状態を、射程を宣言しないまま共有スイートに恒久契約として置いた**

射程のずれには**逆向きの 2 方向**がある:

| 方向 | 症状 | 本 PBI の該当 | 隣接 |
|------|------|--------------|------|
| **射程が狭すぎる** | **壊れても鳴らない**（恒真 PASS / skip 素通り） | `ta-57:622` の `grep -q '^OK'` が全 skip を素通り（本 PBI 後も**残存**する既知の穴） | #1163 |
| **射程が広すぎる** | **無関係な変更で鳴る** | `ta-33:25` / `ta-33:54` / `ta-57:622` の `-eq` | `ta-57:568` の無期限凍結 → **#1165** |

### 実測 1: 成長する対象への絶対件数 assert が 3 箇所（「広すぎる」側）

| file:line | assert | 対象 | 本セッション実測 |
|---|---|---|---|
| `tests/extras/ta-33-agent-model-tier.sh:25` | `[ "$_t33_count" -eq 17 ]` | `.claude/agents/*.md`（README 除く） | 17（`ls .claude/agents/*.md \| wc -l` = **18**、README を含む） |
| `tests/extras/ta-33-agent-model-tier.sh:54` | `[ "$_t33_toml_count" -eq 17 ]` | `.codex/agents/*.toml` | **17** |
| `tests/extras/ta-57-pr-convergence.sh:622` | `[ "$_t57_n" -eq 57 ]` | `test_delivery.py` の `Ran N tests` | **57**（`grep -c 'def test' scripts/ai-loop/test_delivery.py` = 57） |

いずれも**等値**での固定。agent を 1 体足す PR、`delivery.py` にテストを 1 本足す PR が、
**変更と無関係に CI を RED にする**。3 つ目は `scripts/ai-loop/` のリファクタリング
（**#1165 の B-3 を含む**）を直接ブロックする。

#### 「3 箇所で全数」の列挙方法（再検証可能性のため明記）

```sh
grep -rn -- '-eq [0-9][0-9]*' tests/extras/*.sh          # 本セッション実測: 106 ヒット
grep -rn -- '-le [0-9]\|-lt [0-9]' tests/extras/*.sh     # 本セッション実測: 2 ヒット
grep -rn -- '-ge [0-9]\|-gt [0-9]' tests/extras/*.sh     # 本セッション実測: 26 ヒット
```

- **対象拡張子**: `tests/extras/*.sh` のみ（shell テストスイート）
- **採用条件**（3 つすべて）:
  1. 左辺が **リポジトリ内の成長しうる対象**（ディレクトリのファイル数・テスト本数）の計数
  2. 比較対象が **リテラル整数**（変数同士の相対比較ではない）
  3. sandbox 内で自分が作った fixture の数ではなく、**原本リポジトリの状態**を測っている
- **列挙を `-eq` に限定した理由**（採用条件の補足 / 全数性の担保）:
  対象の**増加**で RED になる比較は原理的に (i) 等値 `-eq` と (ii) 上限比較 `-le` / `-lt`
  の 2 種のみ。`-ge` / `-gt`（下限、**26** ヒット）は増加方向では決して RED にならないため
  対象外。上限比較は**実測 2 ヒットのみで、いずれも成長対象を測っていない**
  （`ta-25:313` はループカウンタ、`ta-65:190` は doc 件数の**下限**検査）。
  したがって `-eq` に限定しても全数性を失わない。
- **除外されたもの**（106 ヒットの大半）:
  - `[ "$rc" -eq 0 ]` 等の **exit code 検査**（成長しない）。`-eq 0` を除くと **36** ヒットへ減る
  - `ta-26-plugin-sync.sh` / `ta-59-apply-settings-merge.sh` の `-eq 1` / `-eq 2` 等は
    **sandbox 内で自分が作った fixture の数**（原本の成長に連動しない）
  - `ta-33` TC-04（`md 件数 = toml 件数`）は**相対一致**でリテラル整数を持たない
- **Python 側の隣接候補は対象外**: `scripts/ai-loop/test_check_exec_boundary.py:711` /
  `test_collector.py:817` の定数長 assert は**モジュール内定数（`STATES` 等）の要素数**を
  測っており、リポジトリのファイル追加・テスト追加で変動しない

> ⚠️ 前版の「実測 100 件超のヒット」という記述は**コマンドと数値が再現しない**状態だった。
> 本版は**コマンドと実測値（106 / 36 / 26 / 2）を対にして**記載する。

### 実測 2: 恒真 PASS（「狭すぎる」側の最も発見が遅れる形）

`ta-33` を **単体実行**したときの出力（issue #1162 コメントの実測）:

```text
[FAIL] TA-33 TC-01: tier 不一致 or 体数変動(0 体):
[PASS] TA-33 TC-02: plugin 配布版 agents は全て model: inherit
[FAIL] TA-33 TC-03: toml総数=0(expect 17) ... 17 件すべて missing
[PASS] TA-33 TC-04: .claude/agents md(0) = .codex/agents toml(0)     ← 両辺 0 で恒真
```

`_t33_root` は `$0` 由来（`ta-33:7` の `dirname -- "$0"/..`）のため単体実行では誤った root を
指し、**対象件数が 0 になる**。このとき TC-04（相対一致）は `0 = 0` で **PASS を返す**。

したがって:

- **rc は判定に使えない**（`[FAIL]` 2 件でも rc=0）
- **PASS 件数も判定に使えない**（対象 0 件でも PASS が出る）
- 「検査が存在し・実行され・PASS を返している」のに**測っている対象が空**という状態が成立する

この事実は本 PBI の**全 TC の判定規則**（test-cases.md 前提 P-1）へ反映する。

> ⚠️ **PASS 行から件数を読めない**（3 巡目レビューで実測是正）。`ta-33:26` の PASS 側 printf は
> **リテラル `（17 体）`** であり `$_t33_count` を埋め込んでいない（実測: `git show
> origin/main:tests/extras/ta-33-agent-model-tier.sh | sed -n '26p;29p'`。実測件数が出るのは
> **FAIL 側 `:29` のみ**）。対象 0 件で PASS した場合にリテラルの `17` を読んで
> 「件数 > 0」と判定すると**恒真 PASS を再導入する**。S-1-a では **PASS 側 printf にも
> `$_t33_count` を埋め込む**（todo T-04 / test-cases P-4）。

### 実測 3: 「割るべき」候補は実は少ない（棚卸の結論）

- `arbiter.py:884 arbitrate()` 245 行 / `delivery.py:246 assess()` 189 行は decision-table /
  state-machine を**意図的に 1 箇所へ集約**した設計。分割すると判定順序の単一情報源が失われる
- `tests/extras/` の bootstrap ブロックは「helper を source する前に helper の所在を解決する」
  自己参照構造で**原理的に共通化不能**
- 実害のある重複は **JSON 読込 10 箇所 / 5 ファイル**だが、これは **#1165 の B-3** が扱う
  （#1165 は 3 巡目の是正で**凍結対象外の 7 箇所**へスコープを限定した）

### 棚卸の分母（本セッション再実測 / HEAD `f8d7a0b` / 2026-08-19）

| 対象 | 本数 | 行数 | 計測コマンド |
|------|-----:|-----:|--------------|
| `tests/extras/*.sh`（全体） | **66** | **13,536** | `ls tests/extras/*.sh \| wc -l` / `cat tests/extras/*.sh \| wc -l` |
| `tests/extras/ta-*.sh`（TA スイート本体のみ） | **65** | **13,375** | 同上（`ta-*` 限定） |
| `scripts/ai-loop/*.py`（実装 + テスト） | **30** | — | `ls scripts/ai-loop/*.py \| wc -l` |
| `tests/hooks/run-tests.sh` | 1 | **754** | `wc -l tests/hooks/run-tests.sh` |

> ⚠️ **issue #1162 本文の「63 本 12,166 行」は執筆時点の値で、現 HEAD では stale**。
> `git ls-tree -r --name-only origin/main tests/extras/ | grep -c '\.sh$'` = **66**（`origin/main`
> `645220b` でも同数）であり、本 PBI 進行中も増えうる。
> **本 PBI はこれらの分母を契約値にしない**（成長するディレクトリに絶対件数を書かない）。
> 上表は「測定時点の背景数値」として HEAD SHA とセットで扱う。
> なお issue 本文の値は**本数（`ta-*` 限定）と行数（全体）で分母が混成**してもいた。

## What（Scope）

### In scope

#### S-1: 件数契約 3 箇所を、検出力を下げずに置換する

| ID | 対象 | 置換方針 | 対応 AC |
|----|------|----------|---------|
| **S-1-a** | `ta-33` TC-01（`:25` の `-eq 17`） | 「17 体」ではなく**期待集合との双方向照合**で測る（＋ PASS 側 printf へ実測件数を埋め込む） | AC-01 |
| **S-1-b** | `ta-33` TC-03（`:54` の `-eq 17`） | 同上（期待 low/medium 集合 ＋ **集合外 toml の検出**） | AC-02 |
| **S-1-c** | `ta-57` TC-15（`:622` の `-eq 57`） | **`-eq 57` → `-ge 57`**（＋ 同一 hunk で PASS 側 `t57_pass` へ実測 `Ran ${_t57_n} tests` を埋め込む） | AC-03 |

##### S-1-c の正確な記述（既存条件の誤記訂正）

`ta-57:622` は **既に 3 条件**である（本セッションで一次照合）:

```sh
if [ "$_t57_rc" -eq 0 ] && grep -q '^OK' "$_t57_log" && [ "$_t57_n" -eq 57 ]; then
```

したがって S-1-c で条件式について変わるのは **`-eq` → `-ge` の 1 箇所のみ**であり、
**「3 条件にする」という新規の便益は存在しない**（rc=0 と `^OK` は変更前から効いている）。
本変更は**純粋な緩和**であり、下記「既知の穴」の全 skip 経路は**変更前後を通じて残存**する。

> ⚠️ ただし **PASS 行の出力も同一 hunk で変更する**（3 巡目レビューで実測是正）。
> `:623` の `t57_pass "TC-15 / AC-7: test_delivery.py（Ran 57 tests / OK）"` は**リテラル**で、
> 実測 `_t57_n` が出るのは **FAIL 側 `:625` のみ**。さらに `:668` の `rm -rf "$_t57_tmp"` で
> python ログも削除されるため、**PASS 経路では `Ran N` の N を外から測る手段が無い**。
> `t57_pass "TC-15 / AC-7: test_delivery.py（Ran ${_t57_n} tests / OK）"` へ変更する
> （検出力を上げる方向であり Non-goal に抵触しない）。

#### S-3: `tests/hooks/run-tests.sh` の分割**要否判断**

- 754 行 / EH ブロック 13 個。**要否判断と根拠の記録のみ**（実施する / しない いずれも可）
- 本 PBI では分割そのものに**着手しない**
- 記録は AC-07 の 3 要素（後述「受入基準の運用解釈」）を満たす形で `handoff.md` に書く

### Out of scope

- **`ta-57` TC-14（`:568`）の無期限凍結の改訂** → **#1165 の B-1**（#917 由来のガバナンス
  判断に従属するため分離した）
- **JSON 読込の単一定義化（`read_json()`）** → **#1165 の B-3**
- **`[WARN]` スキップの可視化** → **#1165 の B-2**
- **`ta-33` TC-04 の変更**（md 件数 = toml 件数の相対一致。絶対件数を持たず時限爆弾ではない）
- **`ta-57` TC-15 の `grep -q '^OK'` → `grep -qE '^OK$'` への変更**（下記「既知の穴」。
  検出力が上がる方向で Non-goal には抵触しないが AC-03 の要求外。D-2 の論点として提示）
- **`ta-33` / `ta-57` への `PG_HARNESS_SOURCED` standalone フォールバックの移植**
  （既存 25/65 本のパターン。AC の要求外。D-3 の論点として提示）
- `bin/plangate` の分割（HO 対象・適用が Human-owned）
- `scripts/hooks/*.sh`（HO 対象・AI 編集不可）
- `arbitrate()` / `assess()` 等の長関数の分割
- `sync-plugin-plangate.sh:428/440` の二重 allowlist の単一定義化（V2 候補）
- 外部振る舞いの変更（CLI IF・exit code 契約・hook 挙動はすべて不変）
- テストの検出力を下げる方向の「共通化」（assert の緩和・失敗経路のスキップ）
- 件数 assert を**単に削除**すること（テスト消失を検知できなくなる）

## 受入基準

> issue #1162 の AC-01 / AC-02 / AC-03 / AC-06 / AC-07 を**改変せず転記**（増減なし）。
> AC-04 / AC-05 / AC-08 / AC-09 は #1165 へ移管済みのため本 PBI には存在しない。**番号は詰めない**。
> 運用解釈は AC 本文に書かず、下記の別節と plan.md に書く。

- [ ] AC-01: `ta-33` TC-01 が `.claude/agents/*.md` を 1 体増やしても PASS し、**期待集合から
  外れた tier を持つ agent が 1 体でもあれば FAIL** する（変異注入で両方向を実証する）
- [ ] AC-02: `ta-33` TC-03 が `.codex/agents/*.toml` を 1 本増やしても PASS し、**期待 effort と
  異なる toml があれば FAIL** する
- [ ] AC-03: `ta-57` TC-15 が `test_delivery.py` のテストを 1 本追加しても PASS し、**57 本未満に
  減った場合は FAIL** する
- [ ] AC-06: `sh tests/run-tests.sh` が変更前と同じ pass 件数以上で PASS（exit 0）
- [ ] AC-07: S-3 の分割要否判断が根拠付きで `handoff.md` に記録されている（実施する / しない の
  いずれでも可）

### 受入基準の運用解釈（AC 本文は不改変 / 詳細は plan.md）

- **AC-06 の TIMEOUT 時の判定式**: `sh tests/run-tests.sh` は sandbox 実測で
  **900 秒でも未完了（rc=124）**。時間予算は **1,800 秒**とし、超過時は
  **AC-06 を WARN（未検証）**として記録する。「PASS」とも「FAIL」とも書かず、
  **個別スイート（`ta-33` / `ta-57`）の結果で代替判定**し、未検証範囲を `handoff.md` に明示する。
  **baseline 側（変更前）が TIMEOUT した場合も同じく WARN（未検証）**とする
  （比較対象が存在しない状態で「pass 件数以上」を判定してはならない）
- **AC-06 の pass 件数**: 比較は**下限比較**（baseline 以上）で行い、**絶対件数を新たな契約に
  しない**（本 PBI が除去している時限爆弾の再導入を避ける）。baseline は
  **測定日時・ホスト・HEAD SHA とセット**で記録する
- **AC-01 / AC-02 の「1 体増やしても PASS」**: 正しい設計は「**期待集合を更新すれば +1 が通る**」
  であり、期待集合を更新せずに増やした場合は FAIL が正（AC-02 後半の「集合外検出」と両立させる）
- **AC-01 / AC-03 の「PASS する」の判定**: PASS 行に**実測件数が出ていること**を受理条件に含める。
  現行の PASS 行はいずれもリテラル（`ta-33:26` の `（17 体）` / `ta-57:623` の `Ran 57 tests`）で、
  対象 0 件でも同じ文字列を出す。S-1-a / S-1-c の変更 hunk に**実測値の埋め込み**を含める
- **AC-07 の「根拠付き」の判定**: 次の 3 要素がすべて `handoff.md` の S-3 節に存在すること。
  1. 「実施する / しない」の明示
  2. **実測値**（EH ブロックが共有する変数名の列挙、または順序依存の件数）
  3. `tests/hooks/run-tests.sh` への参照

## Mode 判定

**モード**: `high-risk`

**判定根拠**（[`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md) 準拠）:

| 判定軸 | 実測 | モード |
|--------|------|--------|
| 変更ファイル数 | `tests/extras/ta-33-agent-model-tier.sh` / `tests/extras/ta-57-pr-convergence.sh` の **2 本**（＋ `docs/working/TASK-1162/` の成果物） | 低（1-2） |
| 受入基準数 | **5**（AC-01 / 02 / 03 / 06 / 07） | 中（3-5） |
| タスク数（見込み） | **12**（todo.md の準備・実装・検証・S-3・完了タスク実数。**plan / C-1 / C-2 等のワークフロー工程は実装タスクとして数えない**） | 高（11-20） |
| 変更種別 | **全 PR が通る共有テストスイートの判定契約の改訂**（個別機能のリファクタではない） | 高 |
| リスク | 検出力を下げると**テスト消失・agent 削除・tier 逸脱が無検出**になる | 高 |
| 影響範囲 | `tests/extras/` 2 本 → **すべての PR の CI 判定**に波及 | 高（複数レイヤに波及） |
| ロールバック | ファイル単位の `git checkout --` で戻せる（2 ファイル・段階的巻き戻し不要） | 中 |
| **最終判定** | 定量（タスク数 = 高）と定性（変更種別 / リスク / 影響範囲 = 高）の高い方 | **high-risk** |

**`critical` を採らない根拠**（分割による mode 再判定）:

1. 分割前に `critical` としていた主因は **S-1-d（TC-14 凍結＝ガバナンス契約の改訂）** と
   **S-2（判定エンジン 3 ファイルへの実装変更）**。**両方とも #1165 へ移管**された
2. 残る変更は**テストスイート 2 本の assert 置換**であり、
   `mode-classification.md` の `critical` 例示（アーキテクチャ変更 / 横断的リファクタリング /
   ワークフロー定義変更）に該当しない
3. 受入基準 5・変更ファイル 2 はいずれも `critical` 帯（11+ / 16+）に届かない
4. 前版で `critical` の根拠に挙げた「AC 9・タスク 23」は**分割前の数**であり、分割後の
   実数（AC 5・実装タスク 12）で再判定した

**変更種別軸**: `code`（`.sh` を変更するため doc-light は不適用）。

**Hardening Override 該当性**: **非該当**。接触予定パスは `tests/extras/*.sh` と
`docs/working/TASK-1162/` のみで、HO 9 カテゴリ
（`.claude/rules/*.md` / `.claude/settings*.json` / `.claude/commands/*.md` /
`.claude/agents/*.md` / `scripts/hooks/*.sh` / `bin/plangate` / `schemas/*.schema.json` /
`.github/workflows/*.yml|yaml` / `AGENTS.md` `CLAUDE.md`）のいずれにも該当しない。

> ⚠️ ただし `ta-33` は `.claude/agents/*.md`（HO 対象）を**読み取り対象**にする。
> **原本は編集しない**。変異注入は sandbox コピー上でのみ行う（Assumptions A-03）。

**mode に伴う運用帰結**:

- high-risk のため **autonomous C-3 APPROVE は不可**（`working-context.md` の判定マトリクス）。
  人間の C-3 が必須
- `lite_eligible` = **false**
- フェーズ適用: C-2 外部レビュー ○ / V-2 ○ / V-3 ○ / **V-4 は不要**（critical のみ）

## #1165（PBI-B）との相互依存

| 方向 | 依存の有無 | 根拠 |
|------|-----------|------|
| **本 PBI → #1165** | **依存しない** | S-1-a/b/c はいずれも `ta-33` / `ta-57` の assert 置換のみで、TC-14 の凍結対象 3 ファイル（`delivery.py` / `c3_contract.py` / `c3prime_verify.py`）に**一切触れない**。#1165 のガバナンス判断の結論に関わらず単独で完遂できる |
| **#1165 → 本 PBI** | **技術的な必須依存は解消。運用上の順序制約のみ残る** | 3 巡目の是正で #1165 の B-3 は**凍結対象外の 7 箇所**へ限定され、`delivery.py:538,540` は**据え置き**になった。したがって #1165 が `test_delivery.py` にテストを追加する必要はなく、`-eq 57` のままでも TC-15 は FAIL しない。ただし**両 PBI とも `ta-57-pr-convergence.sh` を改変する**（本 PBI: `:622-623` / #1165: `:568` と `:600-605`）ため、**衝突回避のため #1165 は本 PBI のマージ後に着手する**（安全側の順序制約） |

> 3 巡目レビューまでは「#1165 の AC-04 が `delivery.py:538,540` の parity テストを要求する」
> ことを必須依存の根拠にしていたが、**C-01 の是正でその前提が消えた**。順序制約は
> **同一ファイルの並行改変を避けるため**に残す（技術的な達成不能性ではない）。

## C-3 での要判断事項（人間へ上げる論点）

| ID | 論点 | AI の推奨 | 判断が必要な理由 |
|----|------|-----------|------------------|
| **D-1** | Mode を `high-risk` とするか `critical` へ引き上げるか | **`high-risk`**（分割後の再判定） | 分割で `critical` の主因（S-1-d / S-2）が #1165 へ移った。引き上げると V-4 が加わる。規模判断は人間の裁量 |
| **D-2** | `grep -q '^OK'` → `grep -qE '^OK$'` を本 PBI で実施するか | **実施しない**（Out of scope。plan に選択肢として記載） | AC-03 の要求外。検出力は上がるがスコープ拡大 |
| **D-3** | `ta-33` / `ta-57` へ `PG_HARNESS_SOURCED` standalone フォールバック（既存 25/65 本のパターン。実物は `ta-58:38-53`）を移植するか | **移植しない**（sandbox harness で足りる） | AC の要求外。移植は本 PBI の対象 2 ファイルへの追加変更になる |

> **D-1 が「引き上げ」でも本 PBI は打ち切りにならない**（V-4 が追加されるだけ）。
> 分割前にあった「ガバナンス判断が REJECT なら PBI の半分が落ちる」という構造的従属は解消済み。

## Notes from Refinement

> 判断の記録先は `docs/working/TASK-1162/decision-log.jsonl`（append-only）。
> **本ファイル作成時点では未作成**であり、T-02 で初期化する（それまでは本節が判断の記録）。

1. **`ta-57` TC-15 は `-ge 57`（下限）で確定**。等値 → 下限へ緩めることでテスト追加は通し、
   テスト**消失**（＝検出力の喪失）は引き続き FAIL にする。**この方針は人間承認済み**（A-02）。
   - ⚠️ **訂正**: 「`OK` と rc=0 を併せた 3 条件にすることで『件数だけ満たすが失敗している』
     状態を除外する」は誤り。**`:622` は変更前から既に 3 条件**であり、S-1-c は**純粋な緩和**。
2. **`ta-33` は下限ではなく期待集合との照合**にする。下限にすると「未知の tier を持つ agent が
   増えた」ケースを取り逃すため。
   - TC-01 は「全ファイルが期待 tier と一致」＋「`_t33_sonnet_set` の各名がファイルとして存在
     （＝削除検知）」の双方向
   - TC-03 は「期待 low/medium 集合の各 toml が存在し effort 一致」＋「**集合外の toml が
     存在しない**」の双方向
   - 実測補足: `_t33_expect_low`(6) + `_t33_expect_medium`(11) = **17** で期待集合はすでに
     コード内に存在する。現状 `-eq 17` は「集合外 toml の混入」を間接的に検出しているだけで、
     集合照合へ置き換えれば**検出力はむしろ上がる**
3. **削除検知はスイート水準で維持される**（実測・撤回済みの誤りを是正）。
   `.claude/agents/*.md`（README 除く 17 名）をハイフン→アンダースコア変換した集合と
   `_t33_expect_low` ∪ `_t33_expect_medium` は **IDENTICAL SETS**。したがって:
   - **md 側のみ削除** → TC-04（相対一致）が `drift md=16 toml=17` で FAIL
   - **md + toml の両側削除** → TC-03 の `:missing` ループが FAIL
   - TC-03 / TC-04 は本 PBI で**変更しない**ため、この 2 経路は S-1 後も残る
   - よって「TC-01 単体では弱まる」が「**スイート全体の検出力は下がらない**」。TC-01 に
     inherit 側 11 体を明示列挙する対処は**不要**
4. **`ta-33` TC-04 は変更しない**。相対一致であり絶対件数を持たないため時限爆弾ではない。
   - ⚠️ **帰結**: `ta-33` は **S-1 後も agent 追加 PR を RED にする**
     （md のみ +1 → TC-04 が drift FAIL / md+toml 両側 +1 → TC-03 が集合外検出で FAIL）。
     **「無関係 PR を RED にしない」という便益は実質 `ta-57` 側に限定される**。
     `ta-33` 側の便益は「件数変動と tier 不一致が FAIL メッセージ上で区別できる」ことと
     「期待集合を更新すれば通る、という正しい運用が成立する」こと。`handoff.md` に明記する
5. **判定規則はスイートごとに実物から導出する**（2 巡目レビュー N-01 の是正）。
   「`[FAIL] <TC 名>` 行の有無で判定する」を全スイートへ一般化したのは **`ta-33` 1 本からの
   誤った全称化**だった。実測:

   ```text
   ta-33-agent-model-tier.sh:29  printf '[FAIL] TA-33 TC-01: ...'    ← 行頭・TA-33 あり・stdout
   ta-57-pr-convergence.sh:39    printf '  [FAIL] %s\n' "$1" >&2     ← 先頭 2 空白・TA-57 なし・stderr
   ```

   詳細な判定規則は test-cases.md の前提 P-1（正本）に置く。
6. **`tests/extras/ta-*.sh` が単体実行できない**は**過大な全称**だった。実測（HEAD `f8d7a0b`）で
   `grep -l 'PG_HARNESS_SOURCED' tests/extras/ta-*.sh | wc -l` = **25 / 65**。
   正しくは「**65 本中 40 本に standalone フォールバックが無く、`ta-33` / `ta-57` はその側**」
   （`grep -c 'PG_HARNESS_SOURCED' tests/extras/ta-{33,57}-*.sh` = 0 / 0）。
   結論（この 2 本には harness が要る）は不変。
7. **S-3 は判断のみ**。実施する場合でも本 PBI では着手せず、`handoff.md` に根拠を記録する。
   記録が AC-07 の 3 要素を満たすことを**機械検査するタスクを todo に置く**（T-11）。
8. **`plan.md` は本セッションで作成していない**。EH-3（`scripts/hooks/check-plan-hash.sh`）が
   `PLANGATE_HOOK_TASK` 未設定時に rc=2 で BLOCK するため（実測）。
   `PLANGATE_HOOK_TASK` は**セッション起動時に固定**され実行中の `export` では効かないため、
   plan 生成は **Human タスク H-00（env を設定してセッションを起動する）**を前提にする。
9. **PASS 経路に実測値を残す**（3 巡目レビューの是正 / S-1-a・S-1-c 共通）。
   `ta-33:26` と `ta-57:623` はいずれも PASS 側がリテラルで、実測値は FAIL 側にしか出ない。
   このままでは「対象件数 ≠ 0」を PASS 行から検証できず、**恒真 PASS を排除できない**。
   置換 hunk に PASS 側 printf への実測値埋め込みを含める（**検出力を上げる方向**であり
   Non-goal に抵触しない）。

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和 |
|----|--------|------|------|
| R-01 | 件数 assert の置換で**検出力が下がる**（テスト消失・agent 削除を取り逃す） | 高（Non-goal に明示された最悪ケース） | 各 AC に**正側（増やして PASS）と負側（壊して FAIL）の両方**の TC を置き、**変異注入**で kill を実証する |
| R-02 | 変異注入が**空振り**（変異を入れても PASS のまま）で「検出できたつもり」になる | 高 | 変異は**関数ではなく呼び出し箇所（call site）を壊す**形で設計。空振りなら TC の欠陥として正直に記録する |
| R-03 | **判定規則がスイート横断で成立せず、TC が恒真 PASS になる** | 高（TC 自体が無効） | 判定パターンを**スイートごとに実物から導出**し、`2>&1` でログを取り、**正側は `[PASS]` 行の存在も受理条件**にする（P-1） |
| R-04 | **対象件数 0 の恒真 PASS**（harness 未整備で root 誤導出） | 高 | 受理条件に「対象件数が 0 でない」を含める。**ただし現行の PASS 行はリテラルで実測件数を持たない**（`ta-33:26` / `ta-57:623`。実測件数は FAIL 側のみ）。したがって S-1-a / S-1-c の置換 hunk で **PASS 側 printf に実測値を埋め込み**、その値を parse する |
| R-05 | **`ta-33` / `ta-57` に standalone フォールバックが無い**ため検証手段そのものが機能しない | 高 | sandbox 内に harness を用意する（U-01）。harness は `pass` / `fail` / `FIXTURES_DIR` / `register_cleanup` を定義し、`ta-33` の `$0` 由来 root 解決が成立する位置（`$SBX/tests/`）に置く |
| R-06 | `-ge 57` の下限値自体が将来 stale になる（テストが増えた後に大量削除されても 57 以上なら通る） | 中 | 下限は「現時点の実測値」であり、増加時に引き上げる運用を `handoff.md` に明記。**測定環境とセットで baseline を記録**する |
| R-07 | **フルスイートが完走しない**（sandbox 実測で 900 秒で rc=124） | 中（AC-06 が判定不能） | 時間予算 **1,800 秒**。超過時は `TIMEOUT`＝**未検証（WARN）**として記録し「PASS」と書かない。**baseline 側が TIMEOUT の場合も同様**に WARN 扱いとし個別スイートで代替判定する |
| R-08 | **plan 生成が着手できない**（`PLANGATE_HOOK_TASK` は起動時固定で AI が設定できない） | 中（起点が到達不能） | **H-00（Human）**を todo の起点に置き、`T-00a` を `H-00` に依存させる |
| R-09 | **`ta-33` の便益が期待より小さい**（S-1 後も agent 追加 PR は TC-03/TC-04 で RED） | 低（誤解による過大評価） | Notes 4 に明記済み。`handoff.md` にも記録する |
| R-10 | high-risk のため人間 C-3 が必須で、承認待ちがボトルネックになる | 低 | plan / todo / test-cases を先に確定し、C-1 / C-2 を通してから 1 回で承認を取る |
| R-11 | **背景数値（extras 本数・行数）が進行中に変動**し、記述が stale になる | 低 | 分母を**契約値にしない**。HEAD SHA とセットで「測定時点の値」として書く |

### Unknowns

| ID | 不明点 | 解消方法 |
|----|--------|----------|
| U-01 | **sandbox harness に何を定義すれば足りるか** | T-01 で実測して確定。少なくとも `pass=0` / `fail=0` / `FIXTURES_DIR`（`ta-57:36` が `$FIXTURES_DIR/../..` で root を導出）/ `register_cleanup`（**実呼び出しは `ta-57:45` のみ**。`:32` / `:667` はコメント）の 4 点。加えて `ta-33:7` は `$0` 由来で root を導出するため、**harness を `$SBX/tests/` 直下に置く**必要がある |
| U-02 | `ta-33` TC-01 / TC-03 の置換後の FAIL / PASS メッセージ書式（デバッグ可能性と機械判定の両立） | T-04 / T-05 で確定。**`[FAIL] TA-33 TC-01` / `[PASS] TA-33 TC-01` の prefix は維持**し、**PASS 側にも実測件数を埋め込む**（P-1 の判定規則と P-4 の件数検査が依存するため） |
| U-03 | `tests/hooks/run-tests.sh` の EH ブロック 13 個が**独立実行可能**か（共有 fixture / 順序依存の有無） | S-3 の調査で `grep` により共有変数・順序依存を実測。依存があれば「分割しない」判断の根拠にする |
| U-04 | フルスイート（`sh tests/run-tests.sh`）の**変更前 pass 件数 baseline** | 並走がない時点で時間予算 1,800 秒で 1 回実行して記録（測定日時・ホスト・HEAD SHA とセット）。完走しなければ `TIMEOUT` として記録し個別スイートで代替する（R-07） |

### Assumptions

| ID | 前提 |
|----|------|
| A-01 | issue #1162 の AC-01 / AC-02 / AC-03 / AC-06 / AC-07 は**確定**であり、本 PBI で増減・改変しない（AC-04 / AC-05 / AC-08 / AC-09 は #1165 へ移管済み。番号は詰めない） |
| A-02 | `ta-57` TC-15 の `-ge 57`（下限）方針は**人間承認済み**であり再検討しない |
| A-03 | 変異注入は **sandbox（`mktemp -d` 上の複製）**で行い、`.claude/agents/` / `.codex/agents/` / `scripts/ai-loop/` の**原本には一切書き込まない**。テスト終了時に明示削除する |
| A-04 | HO 対象パス（`.claude/**` / `scripts/hooks/**` / `bin/plangate` / `schemas/**` / `.github/workflows/**` / `CLAUDE.md` / `AGENTS.md`）は**読むだけで編集しない** |
| A-05 | 外部振る舞い（CLI IF・exit code 契約・hook 挙動）は**すべて不変**。振る舞いを変える必要が生じたら即停止して人間判断を仰ぐ |
| A-06 | `.claude/agents/*.md` は現在 **18** ファイル（README.md を含む）、README を除くと **17**。`.codex/agents/*.toml` は **17**（本セッション再実測） |
| A-07 | **S-1-a → S-1-b → S-1-c → S-3** の順序は固定であり入れ替えない |
| A-08 | `plan.md` は `PLANGATE_HOOK_TASK=TASK-1162` を設定して**起動した**セッションで生成する（H-00）。実行中の `export` では効かない |
| A-09 | **#1165 は本 PBI のマージ後に着手する**（技術的な必須依存は C-01 の是正で解消。`ta-57-pr-convergence.sh` の並行改変を避けるための順序制約として維持する。上記「相互依存」節） |

## 実測の再確認（本セッション / HEAD `f8d7a0b` / 2026-08-19）

| # | 項目 | 確認コマンド | 結果 |
|---|------|--------------|------|
| 1 | **判定規則のスイート差** | `printf '  [FAIL] TC-14 / AC-7: x\n' \| grep -q '^\[FAIL\] TA-57 TC-14'` / 同 `grep -qE '^ *\[FAIL\] TC-14'` | 前者 **rc=1**（永久に不一致）/ 後者 **rc=0**。`ta-57:39` は先頭 2 空白・`TA-57` なし・**stderr** |
| 2 | `-eq` ヒットの実数 | `grep -rn -- '-eq [0-9][0-9]*' tests/extras/*.sh \| wc -l` | **106**（`-eq 0` を除くと **36**）。`origin/main`（`645220b`）でも **106** |
| 3 | 上限比較の実数 | `grep -rn -- '-le [0-9]\|-lt [0-9]' tests/extras/*.sh` | **2**（`ta-25:313` ループカウンタ / `ta-65:190` doc 件数の下限）。いずれも成長対象ではない |
| 4 | 下限比較の実数 | `grep -rn -- '-ge [0-9]\|-gt [0-9]' tests/extras/*.sh \| wc -l` | **26**（増加方向では RED にならないため対象外） |
| 5 | `ta-57:622` の既存条件 | `sed -n '620,625p' tests/extras/ta-57-pr-convergence.sh` | `[ rc -eq 0 ] && grep -q '^OK' && [ n -eq 57 ]` = **既に 3 条件**。条件式の変更は `-eq`→`-ge` の 1 箇所のみ |
| 6 | `ta-33` の root 導出 | `sed -n '7p' tests/extras/ta-33-agent-model-tier.sh` | `_t33_root="$(... dirname -- "$0")/..)"` = **`$0` 由来** |
| 7 | `ta-57` の root 導出と harness 依存 | `git grep -n 'FIXTURES_DIR\|register_cleanup' origin/main -- tests/extras/ta-57-pr-convergence.sh` | `:36` が **`$FIXTURES_DIR/../..`** 由来（`$0` 由来ではない）/ **`register_cleanup` の実呼び出しは `:45` のみ**（`:32` と `:667` は**コメント行**） |
| 8 | standalone フォールバックの分布 | `grep -l 'PG_HARNESS_SOURCED' tests/extras/ta-*.sh \| wc -l` | **25 / 65**（`ta-33` / `ta-57` は**含まれない**） |
| 9 | agent / toml / test 件数 | `ls .claude/agents/*.md \| wc -l` / `ls .codex/agents/*.toml \| wc -l` / `grep -c 'def test' scripts/ai-loop/test_delivery.py` | **18**（README 含む）/ **17** / **57** |
| 10 | `tests/extras` の分母（**契約値にしない**） | `ls tests/extras/*.sh \| wc -l` / `cat \| wc -l` | **66 本 / 13,536 行**（issue 本文の「63 本 / 12,166 行」は stale） |
| 11 | `tests/hooks/run-tests.sh` 行数 | `wc -l tests/hooks/run-tests.sh` | **754**（issue 記載と一致） |
| 12 | **PASS 行の実測値欠落**（3 巡目） | `git show origin/main:tests/extras/ta-33-agent-model-tier.sh \| sed -n '26p;29p'` / 同 `ta-57 \| sed -n '623p;625p;668p'` | `ta-33:26` は **リテラル `（17 体）`** / `ta-57:623` は **リテラル `Ran 57 tests`**。実測値（`$_t33_count` / `${_t57_n}`）は **FAIL 側のみ**。`ta-57:668` の `rm -rf "$_t57_tmp"` で python ログも削除される |
