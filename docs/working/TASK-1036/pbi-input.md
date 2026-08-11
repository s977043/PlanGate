# TASK-1036 PBI INPUT PACKAGE

> Issue: [#1036](https://github.com/s977043/plangate/issues/1036)
> `fix(tests): PG_T26_NO_RECURSE が呼び出し元 env の漏れから保護されておらず、親実行でも TC が黙って消える`
> Base: `origin/main` = **`408cebb`**（2026-08-10 時点。#1039 = TASK-1012 の exec は**マージ済み**）
> Labels: `bug` / `priority:P2` / Milestone: `v8.19.0`
>
> **本ファイル中の行番号（`L###`）はすべて base `408cebb` 時点の実測値**であり、後続コミットで陳腐化する。判断に使うときは併記した**記号アンカー（grep 文字列）で再取得**すること。

---

## Context / Why

`tests/extras/ta-26-plugin-sync.sh` は `PG_T26_NO_RECURSE=1` を「TC-13 が起動した子プロセスである」ことのシグナルとして使い、重い TC 群をスキップする。#1039（TASK-1012）でゲートが 2 組追加され、**このシグナル 1 つで消える TC の量が大きく増えた**。

ところが **この env は「呼び出し元から漏れてきた場合」に無害化されていない**。

- `tests/run-tests.sh:20` の unset 集合は 7 env で、`PG_T26_NO_RECURSE` を含まない（本 PBI 起票時に実物で確認）
- `ta-26` 自身の standalone preamble にも含まれない（**含めてはならない**。子プロセスでもその preamble が走るためガードが壊れる）
- `tests/extras/README.md` 規約 7 は「呼び出し元 env の漏れはスイートが無害化する」と定めており、本 env はその対象からの**抜け**にあたる

### 実害の形

`PG_T26_NO_RECURSE=1` が export された環境（CI 再実行スクリプト・開発者シェル・別テストの残留など）で `sh tests/run-tests.sh` または `ta-26` を実行すると、**TC 群が黙って消えたまま rc=0 のグリーンになる**。消えるのは #877 / #914 / #970 の mass-delete guard 回帰テスト群＝**本番データ削除の安全弁を検証する TC** を含む。件数を見ない限り気づけない＝#921 が主題としている「**静かに通る失敗**」と同じクラス。

**現時点で進行中の損失はない**（この env を export する運用は存在しない）＝**潜在バグ**。優先度 P2 の根拠。

### 実測スナップショット（測定日 2026-08-10 / base `408cebb` / macOS `sh`）

| 実行 | PASS 行数 | `[SKIP]` 行 | rc |
|---|---|---|---|
| `sh tests/extras/ta-26-plugin-sync.sh </dev/null` | **32** | 0 | 0 |
| `PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh </dev/null` | **15** | 4 | 0 |

差分 **17 件**（TC-03 / TC-04 / TC-13 / TC-20〜25 / TC-26〜29・32・34〜36）。issue 本文の「#1012 以降 17 件」と一致した。

> ⚠️ **この 32 / 15 / 17 は測定時点のスナップショットであり、契約値ではない**。`ta-26` の TC は今後も増減する。**AC には絶対件数を書かない**（成長する対象の絶対件数を契約値にすると無関係な PR が AC を壊す既往事故がある）。

---

## What (Scope)

### In scope

- `PG_T26_NO_RECURSE` が**呼び出し元から漏れても harness 経路（`sh tests/run-tests.sh`）では無害化される**ようにする
- その漏れを**機械的に検出できる**ようにする（回帰テストを追加し、修正前実装で FAIL することを実証する）
- 上記に伴う `tests/extras/README.md` の規約更新（本 env の扱いを明文化）

### Out of scope

- `ta-26` のゲート構造そのものの変更（#1012 / #1039 で確定済み）
- `ta-26` の TC 内容・期待値の見直し
- 他 extras の env 汚染耐性の一斉点検（別途）
- **直接 standalone 起動時（`sh tests/extras/ta-26-plugin-sync.sh` を env 漏れ下で直接叩く経路）の保護** — 案 (b)（argv 化）を採らない限り残る。**残す場合は既知の残存リスクとして handoff に明記する**

---

## 受入基準

> すべて「**通常実行との同値照合**」で書く。絶対件数（32 / 15 / 17 等）を契約値にしない。

- [ ] **AC-1（harness 経路の無害化）**: `PG_T26_NO_RECURSE=1` を export した状態で `sh tests/run-tests.sh` を実行しても、`ta-26` セクションの**実行 TC 件数が env 無し実行と一致**する（同一 tree・同一コマンドの 2 回実行を比較する形で判定。`ta-26` セクションに再帰防止起因の `[SKIP]` 行が出ないことでも確認できる）
- [ ] **AC-2（回帰テストと変異注入による検出力の実証）**: AC-1 を検証する TC が追加され、**修正前の実装に対して変異注入を行い、その TC が実際に FAIL する**ことをログ付きで実証している。TC は件数のハードコードではなく**通常実行との同値照合**で書く。変異は「修正の call site を壊す」形にする（関数の中身だけ壊して空振りさせない）
- [ ] **AC-3（正規経路の非退行）**: TC-13 が起動する子プロセス（`PG_T26_NO_RECURSE=1` を**コマンド単位の env 前置で明示的に渡す** 2 系統 = `ta-26-plugin-sync.sh` L298 / L301。記号アンカー: `_t26_out13a=` / `_t26_out13b=` の代入行）が**従来どおりゲートを発火**させ、#1012 の AC-1（子でゲート対象 TC がスキップされ `[SKIP]` 行が出る）が**引き続き PASS** する
- [ ] **AC-4（既存静的検査の非退行）**: 修正後に `ta-26` が 3 系統すべてで `0 failed` になる — (i) harness 実行、(ii) 直接 standalone 実行、(iii) `PG_T26_NO_RECURSE=1` 前置の子相当実行。とくに **`ta-26` TC-33（`run-tests.sh` の unset 集合 ⊆ 各 extras の standalone unset 集合）が PASS のまま**であること（後述 Notes N-1 の衝突を回避できていることの機械的な証拠）
- [ ] **AC-5（規約の明文化）**: `tests/extras/README.md` の規約 7（および必要なら規約 8）に、**本 env が harness 側で無害化される対象であること**と、**`ta-26` の standalone 分岐では意図的に unset しない**（そこで unset するとガード自体が壊れる）ことが読み取れる形で記載されている

---

## Notes from Refinement

本 PBI 起票にあたり、issue の記述を鵜呑みにせず実物を確認した。以下は**実測で得た追加事実**であり、plan フェーズでの方式決定に直接効く。

### N-1（最重要）: issue が「最小一手・推奨」とする案 (a) は、そのままでは `ta-26` TC-33 を壊す

`ta-26` の **TC-33** は次を静的検査している（`tests/extras/ta-26-plugin-sync.sh` L761 = `grep -n 'TC-33: FIXTURES_DIR 単独判別' tests/extras/ta-26-plugin-sync.sh`）:

> `run-tests.sh` 冒頭の unset 集合 ⊆ `FIXTURES_DIR:-` 判別を持つ各 extras の standalone unset 集合（**`ta-26` 自身も対象**）

したがって `run-tests.sh:20` に `PG_T26_NO_RECURSE` を 1 語足すと、**`ta-26` 自身を含む 15 ファイル**が「unset 欠落」として検出され TC-33 が FAIL する。しかも **`ta-26` 自身がその欠落を埋めることは許されない**（= 案 (c) と同じことになりガードが壊れる）。**案 (a) は単独では成立しない**。

**実証（2026-08-10 / base `408cebb`）**:

1. `git archive HEAD` で作った sandbox（リポジトリ外・scratchpad 配下）に案 (a) を適用（`run-tests.sh` の unset 行末尾に `PG_T26_NO_RECURSE` を追加）
2. sandbox で `sh tests/extras/ta-26-plugin-sync.sh` を実行 → **`30 passed, 2 failed`**
   - `[FAIL] TC-33 ... unset欠落: ta-26-plugin-sync.sh:PG_T26_NO_RECURSE ta-39-... （計 15 ファイル）`
   - `[FAIL] TC-13 ...` — TC-13 が起動する子でも同じ TC-33 が落ちるため rc が伝播した二次的失敗
3. 同 sandbox で unset 行を元に戻すと FAIL は解消（対照）
4. TC-33 の包含検査部分だけを切り出した再現スクリプトでも、`408cebb` の tree では `TC-33: PASS` / 案 (a) 適用後は `incl_missing_count: 15` で `TC-33: FAIL`

→ **plan では「(a) を採るなら TC-33 側の carve-out（本 env を包含検査の対象外にする）が必ずセットで要る」**ことを前提に Work Breakdown を組むこと。carve-out を入れるなら、その carve-out 自体も AC-4 の対象。

### N-2: 案 (d)（issue に無い選択肢）— `ta-26` の **harness 分岐**（`else` 節）で unset する

`ta-26` の判別は `PG_HARNESS_SOURCED=1` **かつ** `FIXTURES_DIR` 非空 の AND で、成立時は `PG_T26_STANDALONE=0` の `else` 節に入る。`run-tests.sh` は `PG_HARNESS_SOURCED=1` を **export しない**（L159-163 のコメントで「export すると extras が起動した子プロセスまで harness 実行と誤判定する」と明記）。したがって:

- TC-13 が起動する子は `PG_HARNESS_SOURCED` を見ないので **standalone 分岐**へ入る → 前置された `PG_T26_NO_RECURSE=1` は保持されゲートは正常に効く
- 親（harness で source された ta-26）だけが `else` 節に入るので、そこで unset すれば **harness 経路の漏れだけを潰せる**
- TC-33 は「各 extras の unset 集合が harness 集合を**包含**するか」を見るので、`ta-26` に unset 行が増える分には**違反にならない**（`run-tests.sh` 側の集合を増やさないため他 14 ファイルにも波及しない）

案 (d) は「案 (a) + TC-33 carve-out」と比べ、**触るファイルが `ta-26` 1 本で済む**可能性がある一方、「呼び出し元 env の無害化は harness 冒頭で一括」という既存構造から外れる（規約 7 の書きぶりと合わせる必要がある）。**どちらを採るかは plan フェーズの判断**。本 PBI は両案を候補として提示するに留める。

### N-3: 案 (c) は採ってはならない

`ta-26` の **preamble（standalone 分岐を含む無条件経路）で `PG_T26_NO_RECURSE` を unset する**案。TC-13 が起動する子プロセスでもその行が走り、**再帰防止ガードそのものが無効化される**（子が TC-13 本体を実行して孫を spawn する = 再入ループ）。issue でも ❌ と明示されている。**採用禁止**。

### N-4: 呼び出し経路の実測

- `ta-26` の呼び出し口は **(1) `run-tests.sh` の `ta-*.sh` glob source**、**(2) 直接 standalone 起動** の 2 経路のみ。`.github/` / `scripts/` / `bin/` を grep しても `ta-26` への直接参照は無い（CHANGELOG / 他 extras のコメント内言及のみ）
- `PG_T26_NO_RECURSE` を渡すのは **TC-13 の 2 箇所のみ**（L298 / L301。いずれも**コマンド単位の env 前置**。記号アンカー: `_t26_out13a=` / `_t26_out13b=` の代入行）
- `run-tests.sh` の呼び出し口には `.github/workflows/test.yml:28`（`run: sh tests/run-tests.sh`）と `scripts/run-tests-safe.sh` がある。**CI 本線は harness 経路**なので、harness を塞げば CI 上の実害面は閉じる
- `ta-26` 内の `PG_T26_NO_RECURSE` ゲートは現在 **4 箇所**（L67 = TC-03/04、L293 = TC-13、L427 / L572 = #1039 で追加された 2 組。記号アンカー: `grep -n 'PG_T26_NO_RECURSE:-0' tests/extras/ta-26-plugin-sync.sh` が 4 件）

### N-5: 依存関係と時期

- **#1039（TASK-1012 の exec）は `408cebb` で main にマージ済み**。本 PBI は #1039 の後に実施する前提で、**現 main の tree に対して plan / exec する**（起票時点の「#1039 マージ前後で影響範囲が変わる」という懸念はすでに解消）
- #1039 の PR タイトルには `**AC-5 は未達・Human 受入裁定済**` とある。本 PBI は #1012 の AC 群を再オープンするものではなく、**#1012 が前提としていた「この env は TC-13 の子にしか付かない」という仮定の穴**（＝呼び出し元からの漏れ）だけを塞ぐ
- 本 PBI の変更対象は `tests/` 配下（+ `tests/extras/README.md`）に閉じる想定で、**Hardening Override 対象パス（`.claude/rules/*` / `bin/plangate` / `scripts/hooks/*` / `.github/workflows/*` 等）を含まない**。ただし `.github/workflows/test.yml` に触る必要が生じた場合は **Hardening Override に該当し Standard・同期 C-3 固定**になる点に注意

### N-7: 案 (d) の実走検証（2026-08-10 追加 / U-1・U-3・R-6 の決着）

pbi-input 初版では未検証だった 3 点（案 (d) の実走 / harness レベルの AC-1 実測 / 判定方法）を、`git archive` で作ったリポジトリ外 sandbox で実走して埋めた。**リポジトリ本体は無変更**。

適用した案 (d) の差分（sandbox のみ）:

```sh
else
  PG_T26_STANDALONE=0
  # harness 分岐でのみ呼び出し元 env の漏れを無害化する
  unset PG_T26_NO_RECURSE 2>/dev/null || true
fi
```

| # | 条件 | 結果 | 意味 |
|---|---|---|---|
| D-A | 案 (d) + `PG_T26_NO_RECURSE=1` を前置して `ta-26` を直接起動（TC-13 の子相当） | `15 passed, 0 failed` / rc=0 | **ガードは従来どおり効く**（AC-3 の前提が壊れない） |
| D-B | 案 (d) + env なしで `ta-26` を直接起動 | `32 passed, 0 failed` / rc=0 | standalone の全 TC 実行が保たれる |
| D-C | 案 (d) + `PG_T26_NO_RECURSE=1` を export して `sh tests/run-tests.sh` | `Results: 538 passed, 1 failed` | **harness で無害化される**（AC-1） |
| D-D | 案 (d) + env なしで `sh tests/run-tests.sh`（対照） | `Results: 538 passed, 1 failed` | D-C と一致 |
| **BASE** | **未修正** + `PG_T26_NO_RECURSE=1` を export して `sh tests/run-tests.sh` | **`Results: 521 passed, 1 failed`** | **17 件が黙って消える**（`538 - 521 = 17`）。しかも **failed は 1 のまま**＝件数を見ない限り気づけない |

- D-C と D-D の **`ta-26` セクションは `diff` で完全一致（byte-identical・`[SKIP]` 0 行）**。→ AC-1 の判定方法として「セクション切り出し + `diff`」が使える（U-3 解決）
- BASE の `ta-26` セクションは `15 [PASS]` + `[SKIP]` 4 行（TC-03/04・TC-13・TC-20〜25・TC-26〜29/32/34〜36）
- 3 実行に共通の `1 failed` は `test_run_evidence.py`（sandbox が git リポジトリでないことに起因、`ta-26` と無関係）。**全条件で同一のため比較のノイズは相殺される**
- 案 (d) 適用下で TC-33 の包含検査を再現実行 → `TC-33: PASS`（`run-tests.sh` の unset 集合を増やさないため波及しない）

> ⚠️ ここでも `538` / `521` / `17` は**測定時点のスナップショットで契約値ではない**。AC は D-C と D-D の**同値照合**で書く。

### N-6: 想定 Mode

**方式によって変わるため、条件付きで確定する**（最終確定は C-3）。

| 採用方式 | 変更ファイル | 波及 | Mode |
|---|---|---|---|
| **案 (d)**（推奨 / N-7 で実証） | `tests/extras/ta-26-plugin-sync.sh` + `tests/extras/README.md` + 追加 TC の置き場 | `run-tests.sh` の unset 集合を増やさないため **TC-33 に波及しない**（実測 PASS） | **standard** |
| 案 (a)+TC-33 carve-out | 上記 + `tests/run-tests.sh` + TC-33 本体 | TC-33 の包含検査を緩める＝**全 extras の env 無害化契約に触る** | **high-risk**（承認境界に準じ安全側） |

共通の根拠: 受入基準 5、変更種別 = code（テストハーネス）、リスク = mass-delete guard 回帰テストの検出力。いずれも Hardening Override 対象パス（`.claude/rules/*` / `bin/plangate` / `scripts/hooks/*` / `.github/workflows/*` 等）を含まないため、Mode による強制引き上げは発生しない。

---

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和 |
|---|---|---|---|
| R-1 | 案 (a) 単独採用で **TC-33 が FAIL**（N-1 で実証済み） | CI レッド・他 14 extras への波及是正が発生 | plan で carve-out をセットにする / または案 (d) を採る。AC-4 で機械的に検出 |
| R-2 | 案 (c) 的な実装に流れて **再帰防止ガードが壊れる** | `ta-26` が孫プロセスを spawn し暴走 | Out of scope / N-3 に明記。AC-3 で子の挙動を固定 |
| R-3 | 追加した TC が**空振り**する（漏れを検出しない） | 「静かに通る失敗」を塞いだつもりで塞げていない | AC-2 の変異注入で検出力を実証。変異は call site を壊す形にする |
| R-4 | AC を絶対件数で書くと、`ta-26` の TC 増減で**無関係 PR が AC を壊す** | 時限爆弾化 | AC はすべて同値照合。実測値は本ファイルのスナップショット節に測定日 + base SHA 付きで隔離 |
| R-5 | **直接 standalone 起動の経路は塞がらない**（案 (b) 以外） | 開発者ローカルでの誤検知は残る | Out of scope として明示。handoff に既知の残存リスクとして記載（AC 外） |
| R-6 | 案 (d) が `ta-26` の harness / standalone 判別ロジックに依存する（`PG_HARNESS_SOURCED` 非 export 前提） | 将来 export に変えられると静かに壊れる | plan で「`PG_HARNESS_SOURCED` を export しない」ことへの依存を明記。既存 TC-30 / TC-13 が判別規約を静的に固定している。**2026-08-10 に案 (d) を実走検証し、子のガード保持・harness の無害化・TC-33 非波及をすべて確認済み（N-7）** |

### Unknowns

| ID | 不明点 | 解消方法 |
|---|---|---|
| ~~U-1~~ **RESOLVED** | 案 (a)+carve-out と案 (d) のどちらを採るか | **案 (d) を推奨として決着**（2026-08-10 の追加実走。N-7 参照）。最終確定は C-3 |
| U-2 | 追加 TC を `ta-26` 内に置くか、別 extras（新規 `ta-NN`）に置くか。`ta-26` 内に置くと**再帰防止ゲートで自分自身が消える**位置に置いてしまう危険がある | plan で配置を決める。どこに置いても AC-1 の同値照合が env 漏れ下で成立することを実測で確認する |
| ~~U-3~~ **RESOLVED** | AC-1 の「件数一致」をどう機械判定するか | **`ta-26` セクション（`=== TA-26` 〜 次の `=== TA-` 直前）を env あり / なしの 2 回実行から切り出し `diff` で完全一致を見る**方式が有効と実測（N-7 D-C/D-D で byte-identical）。件数ハードコード不要 |
| U-4 | 変異注入の具体形（修正行の削除 / 条件反転 / env 名の改名） | plan で「call site を壊す」形を選定。#1012 todo.md L53 の警告（ゲート一括反転で孫プロセス無限 spawn）を踏襲し、変異範囲を限定する |

### Assumptions

| ID | 前提 | 根拠 |
|---|---|---|
| A-1 | `PG_T26_NO_RECURSE` を読むのは `ta-26` のみ | repo 全体 grep（`docs/working/` の記録を除くと `tests/extras/ta-26-plugin-sync.sh` のみ） |
| A-2 | `PG_T26_NO_RECURSE` を設定するのは TC-13 の 2 箇所のみ、いずれもコマンド単位 env 前置 | L298 / L301 を実物確認 |
| A-3 | `run-tests.sh` は `PG_HARNESS_SOURCED=1` を **export しない** | `tests/run-tests.sh` L159-163 のコメント + 代入行（記号アンカー: `grep -n '^PG_HARNESS_SOURCED=1' tests/run-tests.sh`） |
| A-4 | CI（`.github/workflows/test.yml`）は harness 経路でのみ `ta-26` を実行する | `.github/` grep で `ta-26` 直接参照なし・`run: sh tests/run-tests.sh` のみ |
| A-5 | この env を export する運用は現存しない（＝進行中の損失なし・潜在バグ） | issue 記載。反証は見つからなかった |
| A-6 | 本 PBI の変更は `tests/` に閉じ、Hardening Override 対象パスを含まない | N-5 参照。含む場合は Mode / ゲートを引き上げる |

### 検証コマンド（本 PBI 起票時に実行したもの / base `408cebb`）

```sh
sh tests/extras/ta-26-plugin-sync.sh </dev/null                      # → 32 passed, 0 failed / rc=0 / [SKIP] 0
PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh </dev/null  # → 15 passed, 0 failed / rc=0 / [SKIP] 4
```

案 (a) の TC-33 衝突は、`git archive HEAD` で作った**リポジトリ外の sandbox**に案 (a) を適用して `ta-26` を実走させて確認した（`30 passed, 2 failed` / `TC-33` に 15 ファイルの unset 欠落）。本 PBI では `tests/` を一切変更していない。
