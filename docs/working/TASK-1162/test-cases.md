# テストケース定義 — TASK-1162 (#1162 / PBI-A)

> **原本には書き込まない**。すべての変異は `mktemp -d` 上に複製した sandbox（以下 `$SBX`）で行い、
> 実行後に明示削除する（pbi-input A-03）。`.claude/agents/` / `.codex/agents/` /
> `scripts/ai-loop/` の原本は不変。
>
> **変異は関数ではなく呼び出し箇所（call site）を壊す**。関数本体を壊す変異は「その関数が
> 呼ばれているか」しか測れず、契約が実際に評価されているかを実証できないため。
>
> **TC ID は `PBIA-NN`**（被検査スイート `ta-33` / `ta-57` の `TC-NN` と**番号衝突しない**体系。
> 前版の `T1162-TC-13/14/15` は `ta-57` の TC-13/14/15 と衝突していた）。

## 前提 P-1: 判定規則（**全 Integration TC に適用 / 正本**）

**判定パターンはスイートごとに実物から導出する**。`ta-33` の書式を全スイートへ一般化した
前版の規則は**誤り**だった。実測（本セッション）:

```text
tests/extras/ta-33-agent-model-tier.sh:29   printf '[FAIL] TA-33 TC-01: ...'      ← 行頭・TA-33 あり・stdout
tests/extras/ta-57-pr-convergence.sh:39     printf '  [FAIL] %s\n' "$1" >&2       ← 先頭 2 空白・TA-57 なし・stderr
```

```sh
printf '  [FAIL] TC-15 / AC-7: x\n' | grep -q  '^\[FAIL\] TA-57 TC-15'   # → rc=1（永久に不一致）
printf '  [FAIL] TC-15 / AC-7: x\n' | grep -qE '^ *\[FAIL\] TC-15'       # → rc=0
```

### スイート別パターン（実物由来）

| スイート | FAIL パターン | PASS パターン | 出力先 |
|---------|--------------|--------------|--------|
| `ta-33` | `^\[FAIL\] TA-33 TC-NN` | `^\[PASS\] TA-33 TC-NN` | いずれも **stdout** |
| `ta-57` | `^ *\[FAIL\] TC-NN` | `^ *\[PASS\] TC-NN` | FAIL は **stderr** / PASS は stdout |

### 受理条件（4 つすべてを満たしたときのみ「その TC は PASS した」と記録する）

1. **ログ取得は `> "$log" 2>&1` 必須**（`ta-57` の FAIL は stderr に出るため、stdout だけ
   見ると FAIL を取りこぼす）
2. 対象 TC の **FAIL パターンが 0 件**
3. **対象 TC の PASS パターンが 1 件以上存在する** — 「FAIL 行が無い」は
   「FAIL 行が出るところまで到達したか不明」と区別できない（恒真 PASS の除外）
4. **対象件数が 0 でない**（P-4 参照）

> **rc は判定に使わない**。`ta-33` / `ta-57` はいずれも `pass` / `fail` を harness 側の変数で
> 加算するだけで、自前の exit code を持たない（`grep -c 'PG_HARNESS_SOURCED'
> tests/extras/ta-{33,57}-*.sh` = 0 / 0。standalone フォールバックは 65 本中 25 本にあるが
> この 2 本は含まれない）。

### 起動 harness（sandbox 内に作る。`tests/` 原本には追加しない）

1. `pass=0` / `fail=0` を初期化する
2. **`FIXTURES_DIR="$SBX/tests/fixtures"` を定義**する
   （`ta-57:36` は `PG_T57_ROOT="$(cd -- "$FIXTURES_DIR/../.." && pwd)"`。**`$0` 由来ではない**）
3. **`register_cleanup()` を定義**する（**実呼び出しは `ta-57:45` のみ**。`:32` と `:667` は
   コメント行であり呼び出しではない）
4. **harness を `$SBX/tests/` 直下に置く**（`ta-33:7` は `dirname -- "$0"/..` で root を
   導出するため、この位置でのみ `_t33_root` が `$SBX` に解決する）
5. 対象スイートを **`.`（source）**で読み込む
6. 末尾で `[ "$fail" -eq 0 ] || exit 1`（**判定には使わない**。harness 自体の健全性確認用）

## 前提 P-2: `ta-33` TC-04 の巻き添え（**PBIA-01 / 02 / 03 / 04 / 05 / 06 に適用**）

`ta-33` TC-04 は `.claude/agents/*.md` 件数と `.codex/agents/*.toml` 件数の**相対一致**を
測る。片側だけ増減させると必ず巻き添えで FAIL する（`[FAIL] TA-33 TC-04: drift md=18 toml=17`）。

- **手順側の対処**: agent を増減させる変異では **`.claude/agents/` と `.codex/agents/` の
  両側を同時に**増減させる
- **判定側の対処**: **TC-04 は変異対象外**であり、判定は該当 TC の行のみで行う
- TC-04 は本 PBI で**変更しない**
- **例外（PBIA-03 の 2 行目のみ）**: 「md 側のみ削除」の変異は、**TC-04 の FAIL を期待
  シグナルとして意図的に使う**（削除検知がスイート水準で残ることの実証。pbi-input Notes 3）。
  この 1 ケースに限り TC-04 の `[FAIL]` 行を受理条件に含める。それ以外のすべての TC では
  TC-04 は「巻き添えとして無視する対象」であり判定に使わない

## 前提 P-3: 時間予算と TIMEOUT の判定式

| 対象 | 予算 | 超過時 |
|------|-----:|--------|
| 個別スイート（`ta-33` / `ta-57`） | 300 秒 | `TIMEOUT` として記録し原因を調査 |
| フルスイート（`sh tests/run-tests.sh`） | **1,800 秒** | `TIMEOUT`＝**未検証**として記録。**「PASS」と書かない** |

- sandbox 実測でフルスイートは **900 秒でも未完了（rc=124）**
- **baseline 側（変更前）が TIMEOUT した場合も AC-06 は WARN（未検証）**とする。
  比較対象が存在しない状態で「pass 件数以上」は判定できない。代替として個別スイート
  （`ta-33` / `ta-57`）の結果で判定し、未検証範囲を `handoff.md` に明示する

## 前提 P-4: 対象件数 0 の排除（恒真 PASS の防止）

`_t33_root` の誤導出などで対象が 0 件になると、TC-04 は `0 = 0` で **PASS を返す**
（issue #1162 コメントの実測）。したがって全 Integration TC で次を確認する:

| スイート | 件数の取り出し方 | 前提となる実装変更 |
|---------|----------------|------------------|
| `ta-33` TC-01 | PASS / FAIL メッセージに埋め込まれた**照合体数**が **> 0** | **必要**（`:26` の PASS 側はリテラル `（17 体）`。todo T-04 で `（%s 体）` + `$_t33_count` へ変更） |
| `ta-33` TC-03 | 同上（照合した toml 件数が **> 0**） | **必要**（置換時に FAIL / PASS 双方へ件数を含める / todo T-05） |
| `ta-57` TC-15 | `Ran N tests` の **N > 0**（`_t57_n=0` は import エラー等） | **必要**（`:623` の PASS 側はリテラル `Ran 57 tests`。todo T-06 で `Ran ${_t57_n} tests` へ変更） |

> ⚠️ **この検査は実装変更なしには成立しない**（3 巡目レビューの是正）。実測（`origin/main`）:
>
> ```text
> ta-33-agent-model-tier.sh:26   printf '[PASS] TA-33 TC-01: ...（17 体）\n'                  ← リテラル
> ta-33-agent-model-tier.sh:29   printf '[FAIL] TA-33 TC-01: ...(%s 体):%s\n' "$_t33_count" … ← 実測は FAIL 側のみ
> ta-57-pr-convergence.sh:623    t57_pass "TC-15 / AC-7: …（Ran 57 tests / OK）"              ← リテラル
> ta-57-pr-convergence.sh:625    t57_fail "… （rc=${_t57_rc} / ran=${_t57_n}）"               ← 実測は FAIL 側のみ
> ta-57-pr-convergence.sh:668    rm -rf "$_t57_tmp"                                           ← python ログも削除
> ```
>
> PASS 行のリテラル `17` / `57` を「件数 > 0」の根拠に使うと、**対象 0 件でも P-4 が成立して
> しまう**（恒真 PASS の再導入）。したがって S-1-a / S-1-c の変更 hunk に
> **PASS 側 printf への実測値埋め込み**を含める（**検出力を上げる方向**であり Non-goal に
> 抵触しない）。

---

## 受入基準 → テストケース マッピング

| AC | 内容 | 正側 TC（増えても PASS） | 負側 TC（壊すと FAIL） |
|----|------|--------------------------|------------------------|
| AC-01 | `ta-33` TC-01 が agent +1 で PASS / 期待外 tier で FAIL | **PBIA-01** | **PBIA-02**, PBIA-03 |
| AC-02 | `ta-33` TC-03 が toml +1 で PASS / 期待外 effort で FAIL | **PBIA-04** | **PBIA-05**, PBIA-06 |
| AC-03 | `ta-57` TC-15 がテスト +1 で PASS / 57 本未満で FAIL | **PBIA-07** | **PBIA-08**, PBIA-09 |
| AC-06 | `sh tests/run-tests.sh` が baseline 以上で exit 0 | PBIA-10 | **PBIA-11** |
| AC-07 | S-3 分割要否判断が**根拠付きで** `handoff.md` に記録 | PBIA-12 | **PBIA-13** |
| 全般 | 変異が被検査スイートの FAIL で kill される | — | **M-1〜M-6**（下表） |

---

## S-1-a / S-1-b: `ta-33` の件数契約の置換

### PBIA-01: agent を 1 体増やしても PASS（正側 / AC-01）

| # | 手順 |
|---|------|
| 1 | `$SBX` へ repo を複製し、P-1 の harness を `$SBX/tests/` に置く |
| 2 | `$SBX/.claude/agents/dummy-agent.md` を `model: inherit` で追加 |
| 3 | **同時に** `$SBX/.codex/agents/dummy_agent.toml` を `model_reasoning_effort = "medium"` で追加（P-2） |
| 4 | `_t33_expect_medium` に `dummy_agent` を追記（期待集合の更新 / E-09） |
| 5 | harness 経由（P-1）で `ta-33` を実行し `> log 2>&1` |

**受理条件（すべて）**:

1. `^\[FAIL\] TA-33 TC-01` が **0 件**
2. `^\[PASS\] TA-33 TC-01` が **1 件以上**
3. **PASS 行に埋め込まれた実測体数**が **18**（> 0 / P-4）
   — 置換後の PASS 行は `$_t33_count` を出力する（todo T-04）。**リテラルの `17` を
   読んで判定してはならない**

- ⚠️ **P-2 適用**: md 側だけ +1 すると `[FAIL] TA-33 TC-04: drift md=18 toml=17` が必ず出る。
  両側を同時に増やし、**判定は TC-01 の行のみ**で行う。TC-04 は変異対象外
- 意図: 現状の `-eq 17` は**この変異で FAIL する**（＝時限爆弾の実証。todo T-03 の RED）。
  置換後は PASS になること
- 対照: 置換**前**の同一 sandbox で `[FAIL] TA-33 TC-01` が出ることを先に記録する
- 種別: Integration / 自動化: 可

### PBIA-02: 期待外 tier の agent 混入で FAIL（負側 / AC-01）

| 変異 | 期待 |
|------|------|
| `$SBX/.claude/agents/dummy-agent.md` を `model: sonnet` で追加（`_t33_sonnet_set` に**無い**名前） | `^\[FAIL\] TA-33 TC-01` が **1 件以上** |
| 既存 `explorer-agent.md`（sonnet 集合内）の `model:` を `inherit` へ書き換え | 同上 |
| 既存 `orchestrator.md`（sonnet 集合外）の `model:` を `sonnet` へ書き換え | 同上 |
| `model:` 行そのものを削除（空文字になる） | 同上 |

- ⚠️ **P-2 適用**: 1 行目のみファイル数が変わる。`.codex/agents/` 側も同時に追加し、
  判定は TC-01 の行のみで行う。2〜4 行目は件数不変のため TC-04 は鳴らない
- 意図: 「期待集合から外れた tier を持つ agent が 1 体でもあれば FAIL」（AC-01 後半）。
  4 方向（集合外に sonnet / 集合内を inherit / 集合外を sonnet / 欠落）を網羅する
- 種別: Integration / 自動化: 可

### PBIA-03: agent 削除の検知（負側 / AC-01 / 検出力の維持）

| 変異 | 期待 |
|------|------|
| `$SBX/.claude/agents/explorer-agent.md`（sonnet 集合内）を削除 | `^\[FAIL\] TA-33 TC-01`（期待集合の名が存在しない） |
| `$SBX/.claude/agents/orchestrator.md`（inherit 期待）を **md 側のみ**削除 | `^\[FAIL\] TA-33 TC-04`（`drift md=16 toml=17`）— **P-2 の例外**（TC-04 の FAIL を期待シグナルとして使う唯一のケース） |
| `orchestrator.md` と `orchestrator.toml` を **両側**削除 | `^\[FAIL\] TA-33 TC-03`（`orchestrator:missing`） |

- 実測: `.claude/agents/*.md`（README 除く 17 名）の集合と
  `_t33_expect_low`(6) ∪ `_t33_expect_medium`(11) は **IDENTICAL SETS**。したがって
  **片側削除は TC-04**、**両側削除は TC-03 の `:missing` ループ**が捕捉する
- TC-03 / TC-04 は本 PBI で変更しないため、**スイート水準の検出力は下がらない**。
  TC-01 に inherit 側 11 体を明示列挙する対処は**不要**
- ⚠️ `handoff.md` には「TC-01 単体では弱まるがスイート水準では下がらない」という形で書く
  （「限界がある」とも「完全に検知できる」とも書かない）
- 種別: Integration / 自動化: 可

### PBIA-04: toml を 1 本増やしても PASS（正側 / AC-02）

| # | 手順 |
|---|------|
| 1 | `$SBX/.codex/agents/dummy_agent.toml` を `model_reasoning_effort = "medium"` で追加 |
| 2 | **同時に** `$SBX/.claude/agents/dummy-agent.md` を `model: inherit` で追加（P-2） |
| 3 | `_t33_expect_medium` に `dummy_agent` を追記（期待集合の更新 / E-09） |
| 4 | harness 経由で `ta-33` を実行し `> log 2>&1` |

**受理条件（すべて）**:

1. `^\[FAIL\] TA-33 TC-03` が **0 件**
2. `^\[PASS\] TA-33 TC-03` が **1 件以上**
3. **PASS 行に埋め込まれた照合 toml 件数**が **> 0**（P-4 / todo T-05 の実装変更が前提）

- 種別: Integration / 自動化: 可

### PBIA-05: 期待 effort と異なる toml で FAIL（負側 / AC-02）

| 変異 | 期待 |
|------|------|
| `explorer_agent.toml`（low 期待）の `model_reasoning_effort` を `"medium"` へ | `^\[FAIL\] TA-33 TC-03` |
| `orchestrator.toml`（medium 期待）を `"low"` へ | 同上 |
| `orchestrator.toml` から `model_reasoning_effort` 行を削除 | 同上 |
| `qa_reviewer.toml` を削除（medium 集合内 / md 側も同時削除） | 同上（`:missing`） |

- 種別: Integration / 自動化: 可

### PBIA-06: 集合外 toml の混入で FAIL（負側 / AC-02 / 過剰検知）

| 変異 | 期待 |
|------|------|
| `$SBX/.codex/agents/rogue_agent.toml` を `"high"` で追加（期待集合は**更新しない**） | `^\[FAIL\] TA-33 TC-03` |
| 同上を `"low"` で追加（値は妥当だが集合外） | 同上 |

- ⚠️ **P-2 適用**: toml のみ +1 なので TC-04 が巻き添えで鳴る。判定は TC-03 の行のみ
- 意図: 現行 `-eq 17` が間接的に担っていた「未知 agent の混入検知」を、置換後は
  **集合外 toml の明示検出**で置き換える。これがないと PBIA-04 の緩和で検出力が純減する
- ⚠️ PBIA-04（+1 で PASS）と本 TC（集合外で FAIL）は**一見矛盾する**。正しい設計は
  「期待集合を更新すれば +1 が通る」であり、集合を更新せずに増やした場合は FAIL が正。
  PBIA-04 の手順には**期待集合への追記**を含める
- 種別: Integration / 自動化: 可

---

## S-1-c: `ta-57` TC-15 の下限化

### PBIA-07: テストを 1 本増やしても PASS（正側 / AC-03）

| # | 手順 |
|---|------|
| 1 | `$SBX/scripts/ai-loop/test_delivery.py` に空の `test_pbia_dummy` を 1 本追加（`Ran 58 tests`） |
| 2 | harness 経由で `ta-57` を実行し `> log 2>&1`（FAIL は stderr） |
| 3 | 同様に 5 本追加（`Ran 62 tests`）して再実行 |

**受理条件（すべて）**:

1. `^ *\[FAIL\] TC-15` が **0 件**
2. `^ *\[PASS\] TC-15` が **1 件以上**
3. **PASS 行に埋め込まれた `Ran N`** の N が **58**（3 の手順では 62）で **> 0**（P-4）
   — 置換後の PASS 行は `${_t57_n}` を出力する（todo T-06）。python ログは `:668` で
   削除されるため、**PASS 行以外に N の観測経路は無い**

- ⚠️ **`ta-57` の他 TC が巻き添えで FAIL しうる**（TC-14 の凍結検査など）。判定は
  **TC-15 の行のみ**で行う
- 意図: `scripts/ai-loop/` へテストを足しても CI が RED にならないこと（＝本 PBI の主目的）
- 対照: 置換**前**は `Ran 58` で `^ *\[FAIL\] TC-15` が出ることを先に記録する
- 種別: Integration / 自動化: 可

### PBIA-08: 57 本未満へ減らすと FAIL（負側 / AC-03）

| 変異 | 期待 | 観点 |
|------|------|------|
| `test_delivery.py` からテストを 1 本削除（`Ran 56 tests`） | `^ *\[FAIL\] TC-15` | 境界の直下 |
| 10 本削除（`Ran 47 tests`） | 同上 | 明白な消失 |
| ちょうど 57 本（変異なし） | `^ *\[PASS\] TC-15` が出る（FAIL は 0 件） | 境界そのもの（`-ge` の等号側） |

- 意図: 「テスト消失を検知できなくなる」ことを防ぐ（Non-goal に明記された最悪ケース）。
  境界値 **56 / 57 / 58** の 3 点を必ず測る
- 種別: Integration / 自動化: 可

### PBIA-09: 件数以外の条件が独立に効く（負側 / AC-03）

| 変異 | 期待 | 落ちる条件 |
|------|------|-----------|
| テストを 60 本にした上で 1 本を意図的に失敗させる（`Ran 60 tests` / `FAILED` / rc≠0） | `^ *\[FAIL\] TC-15` | `rc -eq 0` |
| `test_delivery.py` を import エラーにする（`Ran` 行が出ない → `_t57_n=0`） | 同上 | 3 条件すべて |

- ⚠️ 前版の「`OK` が出ず rc=0 のみ（skip 全件等）→ FAIL」は**到達不能（空振り TC）**のため削除済み
- 意図: `-ge 57` へ緩めた分、**rc=0 が実際に評価されている**ことを実証する
- 種別: Integration / 自動化: 可

#### 既知の穴（本 PBI では塞がない / D-2 で Out of scope 確定）

`test_delivery.py` を**全 skip 化**すると出力は次のようになる:

```text
Ran 57 tests in 0.001s

OK (skipped=57)
```

- `rc=0` ✅ / `grep -q '^OK'` は `OK (skipped=57)` に**マッチする** ✅ / `-ge 57` ✅
  → **TC-15 は PASS**
- したがって `grep -q '^OK'` は **全 skip を弾いていない**
- この穴は `-eq 57` の時点から存在し、**`-ge 57` 化で新たに生じるものではない**（純粋な残存）
- **塞ぐ手段**: `grep -qE '^OK$'` へ変更すれば `OK (skipped=57)` は不一致となり FAIL する。
  検出力が上がる方向のため Non-goal には抵触しないが、AC-03 の要求外のため
  **plan.md の選択肢として提示するに留める**（D-2）
- ⚠️ `handoff.md` には「全 skip の穴は**残存**」と書く。「3 条件で除外している」と書かない

---

## 全体回帰・記録

### PBIA-10: フルスイート回帰（正側 / AC-06）

| 検査 | 期待 |
|------|------|
| `timeout 1800 sh tests/run-tests.sh` | exit **0** |
| pass 件数 | T-01 baseline の pass 件数 **以上** |

- ⚠️ 件数は**下限比較**。絶対件数を新たな契約にしない（本 PBI が除去している時限爆弾を
  自分で再導入しないため）
- ⚠️ 並走がない時点で 1 回だけ実行。baseline は**測定日時・ホスト・HEAD SHA とセット**で記録する
- 種別: Integration / 自動化: 可（ただし手動タイミング制御）

### PBIA-11: TIMEOUT の扱い（負側 / AC-06）

| 検査 | 期待 |
|------|------|
| **変更後**の run の rc が **124** | AC-06 を PASS と記録しない。`TIMEOUT`＝**未検証（WARN）** |
| **baseline 側**の run の rc が **124** | AC-06 を **WARN（未検証）**とする。「変更後だけ完走したから PASS」と書かない |
| `handoff.md` の AC-06 欄 | `WARN`（未検証）＋ 代替判定に使った個別スイート名 ＋ **未検証範囲**が明記されている |
| 「AC-06 PASS」の文字列 | rc=124 の run に対して**存在しない** |

- 意図: sandbox 実測で **900 秒でも未完了（rc=124）**。「時間切れ」を「緑」と読み替える
  経路を塞ぐ。**未完了は未検証であって成功ではない**
- ⚠️ **本 TC は「両方の run が完走した場合は N/A」**（発火しない）。完走した run に対して
  本 TC を「PASS」と記録してはならない（空虚に真になるため）。`handoff.md` には
  `N/A（両 run とも完走）` と書く
- 種別: 手動レビュー + doc 検査 / 自動化: 文字列検査のみ機械化可

### PBIA-12: S-3 判断の記録（正側 / AC-07 / doc 検査）

| 検査（3 要素） | 期待 |
|------|------|
| (a) `handoff.md` の S-3 節に「実施する / しない」が明示されている | あり |
| (b) **実測値**（EH ブロックが共有する変数名の列挙、または順序依存の件数）が併記されている | あり |
| (c) `tests/hooks/run-tests.sh` への参照がある | あり |

- 🚩 この 3 要素検査は **todo T-11 が実行するタスクとして存在する**（検査を実装しないまま
  AC-07 を PASS と書かない）
- 種別: doc 検査 / 自動化: 可（grep ベース）

### PBIA-13: 根拠なしの記録は AC-07 未達（負側 / AC-07）

| 変異（`handoff.md` の記述） | 期待 |
|------|------|
| 「S-3: 分割しない」のみで根拠なし | **AC-07 未達**（3 要素検査が (b) で落ちる） |
| 「複雑なので分割しない」（実測を伴わない主観） | **AC-07 未達**（同上） |
| 「EH ブロック 13 個中 N 個が変数 `X` を共有し、順序依存が M 件あるため分割しない」＋ `tests/hooks/run-tests.sh` への参照 | AC-07 達成 |

- 意図: AC-07 は「記録がある」ではなく「**根拠付きで**記録されている」を要求している。
  根拠の有無を判定できない TC では AC-07 を検証したことにならない
- 種別: doc 検査 / 自動化: 可

---

## 変異一覧（kill 実証）

> **判定は 2 層である**（前版は 1 層で書いており、表の「kill する TC」と前文の記述が
> 意味論的に逆転していた）:
>
> 1. `$SBX` に変異を適用 → **被検査スイート（`ta-33` / `ta-57`）の対象 TC が FAIL する**
>    （P-1 のスイート別 FAIL パターンで確認）
> 2. **その結果として、本 PBI の対応 TC（`PBIA-NN`）が PASS になる**
>    ＝「壊したら鳴る」ことを実証できた
> 3. 変異を復元 → 被検査スイートの対象 TC が **PASS に戻る**ことも確認する
>    （変異と無関係に常時 FAIL していた、という誤検出を排除するため）

| ID | 変異（call site） | 被検査スイートで FAIL する TC | 実証される本 PBI の TC | 対応 AC |
|----|-------------------|------------------------------|----------------------|---------|
| M-1 | `.claude/agents/` に sonnet 集合外の `model: sonnet` agent を 1 体追加（toml も同時追加 / P-2） | `ta-33` TC-01 | PBIA-02 | AC-01 |
| M-2 | sonnet 集合内 agent の `model:` を `inherit` へ書換 | `ta-33` TC-01 | PBIA-02 | AC-01 |
| M-3 | sonnet 集合内 agent のファイルを削除 | `ta-33` TC-01 | PBIA-03 | AC-01 |
| M-4 | `.codex/agents/` の low 期待 toml の effort を `"medium"` へ書換 | `ta-33` TC-03 | PBIA-05 | AC-02 |
| M-5 | `.codex/agents/` に集合外 toml を 1 本追加（期待集合は更新しない） | `ta-33` TC-03 | PBIA-06 | AC-02 |
| M-6 | `test_delivery.py` からテストを 1 本削除（`Ran 56`） | `ta-57` TC-15 | PBIA-08 | AC-03 |

> **fixture（変異ではない）**: 「期待集合（`_t33_expect_medium` 等）への追記」は
> **正側 TC の前提条件**であり変異ではない。変異表には載せない
> （PBIA-01 / PBIA-04 の手順に前提として記載）。

### 空振り時の扱い

変異を入れても**被検査スイートの対象 TC が FAIL しなかった**場合、「検出できた」と書かない。
「変異 M-x は kill されなかった」を `handoff.md` の既知課題および `decision-log.jsonl` へ
記録し、TC を足すか「その挙動は未検証」と明記するかを人間判断に上げる（R-02 / todo の即停止条件）。

## エッジケース

| ID | ケース | 扱い |
|----|--------|------|
| E-01 | `.claude/agents/README.md` | `ta-33` TC-01 は `case ... README) continue` で除外済み。置換後も除外を維持する |
| E-02 | `.codex/agents/` に toml が 0 本（glob 不展開） | `ls` が空 → 期待集合の全件 `:missing` で **FAIL**（fail-closed）。P-4 の「件数 > 0」検査でも捕捉する |
| E-03 | `ta-57` の `Ran` 行が複数出る（サブプロセス実行） | `head -1` で先頭のみ採用（現行踏襲）。複数出る条件が生じたら停止して設計見直し |
| E-04 | `Ran 1 test in ...`（単数形） | 現行 `sed` は `tests*` で単数形も拾う。置換後も維持する |
| E-05 | `test_delivery.py` が import エラーで `Ran` 行を出さない | `_t57_n=0` → `-ge 57` で **FAIL**（fail-closed 維持） |
| E-06 | harness を `$SBX` 直下に置いてしまった | `ta-33` の `_t33_root` が `$SBX` の親を指し**全 glob が空**＝恒真 PASS。P-1 の配置要件（`$SBX/tests/`）と P-4 の件数検査の両方で捕捉する |
| E-07 | harness が `register_cleanup` を定義していない | `ta-57:45`（**唯一の実呼び出し**）で `command not found` となり以降の TC が壊れる。harness 要件 3 で担保 |
| E-08 | ログを `2>&1` なしで取得した | `ta-57` の FAIL（stderr）を取りこぼし**恒真 PASS**になる。P-1 受理条件 1 で担保 |
| E-09 | 期待集合を更新して agent を正式に増やす運用 | PBIA-01 / PBIA-04 の手順に「期待集合への追記」を含める（集合更新すれば +1 が通る、が正しい設計） |
| E-10 | `test_delivery.py` の**全 skip** | `Ran 57 / OK (skipped=57) / rc=0` で TC-15 は **PASS**（既知の穴・残存）。PBIA-09 の「既知の穴」節に記録済み |
| E-11 | 被検査スイートの**他 TC が巻き添えで FAIL** | 判定は対象 TC の行のみ（P-2）。ただし巻き添えの内容は evidence に残す |
| E-12 | PASS 行への実測値埋め込みを**忘れたまま**受理条件 4 を判定した | リテラルの `17` / `57` を読んで恒真 PASS が成立する。todo T-04 / T-06 の実装変更が入っていることを、判定前に `git diff` で確認する（P-4） |

## 自動化可否サマリ

| 種別 | TC | 自動化 |
|------|----|--------|
| Integration | PBIA-01〜09, 10 | 可（sandbox 複製 + **P-1 の harness 経由**でスクリプト実起動） |
| Mutation | M-1〜M-6 | 可（sandbox 上で適用 / 復元。**2 層判定**で確認） |
| doc 検査 | PBIA-11, 12, 13 | 可（存在検査 + 3 要素の充足検査 + 禁止文字列検査） |
