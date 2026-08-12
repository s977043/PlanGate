# TEST CASES — TASK-1044

> plan: `plan.md` / AC 対応は `pbi-input.md` 受入基準表を正とする。
> 新規 TC は `ta-61-extra-contract.sh` へ追加（TC-30 以降）。シェルマトリクスと変異は
> evidence 実測（TA 本体は dash 固定 — CI の sh 実体と一致させる）。

## 受入基準 → テストケースマッピング

| AC | TC |
|---|---|
| AC-1（helper 欠落 + env 漏出 + 直接実行 → 4 シェル rc=1） | TC-30 + EV-1 |
| AC-2a（rc 契約 0/1/3） | TC-31 (1) + EV-2 |
| AC-2b（summary 書式） | TC-31 (2) + EV-2 |
| AC-2c（7 env unset の実測） | TC-31 (3) + EV-2 |
| AC-2d（カウンタ初期化） | TC-31 (4) + EV-2 |
| AC-3（正規経路無回帰） | TC-33 / TC-34 |
| AC-4（bootstrap marker の**各出現**でバイト一致 + helper 分離照合） | TC-35 |
| AC-5（変異注入で検出力実証） | EV-3（pre-fix red）/ EV-4（M-1〜M-4 + M-4b の kill） |
| AC-6（F-3 fail-closed） | TC-32 |
| AC-7（ta-61 既存 TC 無回帰） | TC-36 |
| AC-8（fixture の `_pg_extra_direct` 明示 / 未設定 0 件） | **TC-37** + EV-4（M-4 / M-4b） |
| AC-9（TASK-0921 handoff への解消・evidence 継承の追記 + 本 PBI handoff の「未塞ぎ 5 本」行） | **TC-38**（確認対象 2 点） |
| （R-008 の pin: 無条件代入の維持） | **TC-30b** |

## テストケース一覧

### TC-30: env 漏出 + helper 欠落 + 直接実行は rc 非 0（自動 / ta-61 追加）

- 前提: sandbox に層 A 1 本（例: ta-46）のみ複製（helper を置かない）
- 入力: `PG_HARNESS_SOURCED=1 FIXTURES_DIR=/tmp EXTRAS_DIR=$SBX dash $SBX/ta-46-*.sh`
- 期待出力: **rc=1** + stderr に `helper unresolved`
- 種別: 自動（contract TA）。現 HEAD では rc=0（実測済み）= pre-fix red の根拠

### TC-30b: `_pg_extra_direct=0` を export しても層 A は standalone（自動 / ta-61 追加 / R-008）

- 前提: sandbox に層 A 1 本 + `_extra-contract.sh` を複製
- 入力: **`_pg_extra_direct=0` を export した状態**（+ 3 env 漏出）で `dash $SBX/ta-XX-*.sh`
- 期待出力: **それでも standalone**（bootstrap の `case … esac` が**無条件代入**で
  環境値を上書きするため）。summary 出力 + standalone rc 契約
- 目的: `_pg_extra_direct` を新たな env 漏出面にしないこと＝**無条件代入を pin** する。
  将来 bootstrap が `: ${_pg_extra_direct:=…}` へ「最適化」されると本 TC が FAIL する
- 種別: 自動

### TC-31: env 漏出 + helper 存在 + 直接実行は standalone 契約有効（自動 / ta-61 追加）

- 前提: sandbox に層 A 1 本 + `_extra-contract.sh` を複製
- 入力: 3 env 漏出状態で `dash $SBX/ta-XX-*.sh`
- 期待出力: standalone として動作。**AC-2a〜2d の 4 点をすべて検証する**（R-004。
  従来案は (1)(2) のみで、**7 env unset とカウンタ初期化を誰も検証していなかった**）:
  1. **(AC-2a)** rc が standalone 契約（0 / 1 / 3）に従う
  2. **(AC-2b)** summary 行 `TA-<NN> standalone: N passed, M failed` が出力される
  3. **(AC-2c)** 契約下で起動した子プロセスで、**`tests/run-tests.sh:20` の unset 行に
     列挙された 7 個の名前がいずれも未設定**であること
     （`PLANGATE_SKIP_REASON` / `PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_FILE` /
     `PLANGATE_BYPASS_HOOK` / `PLANGATE_HOOK_STRICT` / `PG_HARNESS_SOURCED` /
     `PLANGATE_ALLOW_MASS_DELETE`）。
     **`env | grep -c '^PLANGATE_'` の全数 0 は判定に使わない（R-029）** —
     repo 内の `PLANGATE_*` は実測 **52 種**で、`PLANGATE_BIN` / `PLANGATE_PYTHON` /
     `PLANGATE_REPO_ROOT` 等は 7 env 契約の外。全数 0 にすると**開発者環境や CI が
     無関係な `PLANGATE_*` を export しているだけで TC-31 (3) が落ちる**
     （「無関係な PR の CI 落ち」と同型）。
     漏出 env が子へ伝播しないことの実測。**この検証が無いと、漏出 env が
     子プロセスへ伝播したままでも TC-31 は緑になる**
  4. **(AC-2d)** init 直後に `pass=0` / `fail=0`（カウンタ初期化）
- 現 HEAD では summary 無し・rc=0 = red
- 種別: 自動

### TC-32: init 前 finalize は fail-closed（自動 / ta-61 追加 / F-3）

- 前提: helper のみ source し `pg_extra_contract_init` を呼ばない fixture
- 入力: fixture から直接 `pg_extra_contract_finalize` を呼ぶ（直接実行）
- 期待出力: **rc=4** + stderr に `finalize called before init`
- 種別: 自動（Q-1 裁定が代替案になった場合は期待値を裁定に合わせて確定）

### TC-33: フルスイート無回帰（自動）

- 入力: `sh tests/run-tests.sh`
- 期待出力: rc=0 / `0 failed`（source 経路で direct=0 → harness 判定が従来どおり）
- 種別: 自動（既存 runner）

### TC-34: 清浄 env での standalone 直接実行が従来 rc を維持（自動）

- 前提: 清浄 env（3 env unset）
- 入力: **bootstrap marker を含む `tests/extras/ta-*.sh` 全件**（**動的導出・件数は
  assert しない** / R-030。本 PR 時点の実測は層 A 12 + ta-61 = 13 ファイル）を
  `sh tests/extras/ta-XX-*.sh` で直接実行
- 期待出力: 各本の従来 rc（0 または 3 — 前提未充足の本は rc=3）と summary 書式不変
- **固定件数にしない理由（R-030）**: AC-4 / AC-8 が「絶対件数を契約値にしない」と
  定めているのに AC-3 / TC-34 だけ「層 A 12 本」を固定すると、Slice 2 が追加した
  層 A ファイルが**静かに対象から漏れる**（偽陰性）
- 種別: 自動

### TC-35: 新述語のバイト一致照合（自動 / ta-61 へ**新設** — base の ta-61 に述語バイト一致 TC は存在しない）

- 入力: Mode resolution v2 の判定 2 行（case 行 + if 行）を canonical 文字列として、
  **bootstrap marker（`# ---- extras execution contract bootstrap`）の各出現
  （`file:line`）を対象として動的に導出**し照合する（R-005・R-024）。
  比較は**行頭空白を除去して**行う（fixture 複製のインデント差を正規化）。
  helper `_pg_extra_resolve_mode` は**分離定義**として、変数消費形 literal
  （`${_pg_extra_direct:-1}` 消費・関数内 `$0` 非評価）との一致を別途照合
- **照合単位は「出現」であり「ファイル」ではない（R-024 / 必須）**:
  `ta-61-extra-contract.sh` は**本体 bootstrap と heredoc fixture 複製で marker を
  2 回持つ**。**ファイル単位ループで実装すると 2 つ目の出現が照合網から外れ、
  fixture 複製が旧述語のまま残っても TC-35 は緑**になる（＝本 PBI が潰そうとしている
  「静かに通る」形をそのまま作る）。**1 ファイル内の全出現を照合すること**
- **base では ta-61 に marker が無い（R-024）**: base 実測 = **12 出現 / 12 ファイル
  （層 A のみ）**。ta-61 本体 `:15` と fixture 複製 `:745` は述語のみで marker 行を
  持たないため、**S4 で marker 行ごと置換して初めて本 TC の対象になる**。
  適用後 = **14 出現 / 13 ファイル**
- 期待出力: 導出された全出現で一致（bad=0）。
  **絶対件数を assert しない**（実測母数 = base 12 出現 / 適用後 14 出現・13 ファイルは
  ログ出力のみ）。
  固定リストにすると Slice 2 が旧述語で新ファイルを足しても緑（偽陰性）、
  件数を固定すると無関係 PR が層 A に 1 本足しただけで CI が落ちる（偽陽性）
- 先例: `ta-26` TC-33（件数ハードコードなしの grep ベース検査）
- 種別: 自動

### TC-36: ta-61 既存 TC（TC-01〜29）全 PASS（自動）

- 入力: `sh tests/extras/ta-61-extra-contract.sh`（清浄 env）+ harness 経由
- 期待出力: 全 PASS。ただし**「空振りでも PASS」は無回帰と見なさない**（R-001）。
  bootstrap を持たず helper を直接 source する fixture は、変数消費形では
  `_pg_extra_direct` 未設定 = direct 既定 → standalone に落ち、**多くが赤くならず
  静かに PASS する**ため、**helper を直接 source する全 fixture（`. "$T61_HELPER"` 由来で
  動的導出・本 PR 時点の実測 12 本）**に `_pg_extra_direct=0` を明示設定した上で
  無回帰を判定する。うち **`PG_HARNESS_SOURCED` を明示設定するため挙動が変わるのは
  以下の 4 本（部分集合）**である（導出根拠:
  `grep -n 'PG_HARNESS_SOURCED=1' tests/extras/ta-61-extra-contract.sh` の fixture heredoc。
  **この 4 本は TC-37 の走査母数ではない** / R-014）:

  | fixture | 行 | 未対応時の落ち方 |
  |---|---|---|
  | `tc01.sh` | `:383` | 空振り PASS（finalize が exit → 後続 counters 検証行に未到達） |
  | `tc01b.sh`（TC-01b / TC-01c 兼用） | `:410` | 空振り PASS（期待値 `pass=0` が standalone と同値） |
  | `tc21.sh` | `:582` | 空振り PASS |
  | `tc26-file1.sh`（`tc26-runner.sh` `:631` から source される） | `:621`（runner `:631`） | loud FAIL（rc=1・`mini-marker: file2` 消失） |

  **`tc26` の置き場所（R-014）**: TC-37 の literal フィルタ（`. "$T61_HELPER"`）に
  マッチするのは **`tc26-file1.sh`** であり `tc26-runner.sh` ではない。
  `_pg_extra_direct=0` は同一シェル継承によりどちらに置いても機能するが、
  **TC-37 が検査する `tc26-file1.sh` 側に置く**（runner 側だけだと TC-37 が未設定と判定する）。
  なお `tc26-file2.sh` は helper を source しないため走査対象外（自動除外）。

  **standalone 期待の fixture（`tc01b.sh`）にも `_pg_extra_direct=0` を入れる**こと。
  そうして初めて env 述語が唯一の判別子として残り、TC-01b / TC-01c が
  元の意味（3 env AND の検証）を回復する。sandbox 系 TC-14〜17/29 も無回帰
- 検出力の担保: 本 TC 単体では空振りを検出できないため、**TC-37（静的）と
  EV-4 の M-4（変異）と対で判定する**
- 種別: 自動

### TC-37: helper 直接 source fixture の `_pg_extra_direct` 明示（自動 / ta-61 新設 / AC-8）

- 入力: `ta-61-extra-contract.sh` 内の fixture heredoc を走査し、
  **bootstrap marker を持たず `. "$T61_HELPER"` を含む fixture** を列挙。
  各 fixture がトップレベルで `_pg_extra_direct=` を設定しているかを静的検査
- **走査母数は動的導出（件数を assert しない / R-014）**: 本 PR 時点の実測は
  `grep -c '\. "\$T61_HELPER"'` = **12**（`tc01` / `tc01b` / `tc02` / `tc03` / `tc04` /
  `tc06` / `tc07` / `tc08` / `tcskip` / `tc21` / `tc23` / `tc26-file1`。行 `:391` `:416`
  `:440` `:454` `:468` `:494` `:512` `:530` `:553` `:590` `:606` `:623`）。
  **plan「帰結」節の 4 本は挙動が変わる部分集合であって本 TC の母数ではない** —
  4 本の固定リストへ狭めると AC-8 が手書きリストへ退化し R-001 / R-002 が実質復活する
- 期待出力: **未設定の fixture が 0 件**（母数の絶対件数は assert せずログ出力のみ）
- 目的: **AC-4 の照合網（bootstrap + helper）は fixture を含まない**ため、
  本 TC が将来の fixture 追加漏れに対する唯一の機械検出点になる（R-001 / R-012）
- 種別: 自動（静的検査）

### TC-38: handoff 追記の静的確認（**確認対象 2 点** / AC-9）

- 入力 (1): `docs/working/TASK-0921/handoff.md` 既知課題 2 / 2-bis、および
  **同ファイル内で「18/18 KILL」を主張する全行**
  （**行番号でなく意味ラベルで特定する**: **AC-7 PASS の根拠行 / 引き継ぎ文書の状態行 /
  テスト結果サマリ行**。本 PBI 反映時の実測は L43 / L104 / L119 だが、**T-11 の追記で
  行番号はずれる**ため行番号をアンカーにしない）
- 期待出力 (1): 本 PR による解消、および **変異 evidence の HEAD 整合失効とその扱い**が
  1 行で追記されており、**上記の全行から当該注記への参照が張られている**
  （既知課題への追記だけでは根拠行が古い主張のまま残るため / R-017）。
  **分母は実測 19 本**（`grep -cE '^M-' docs/working/TASK-0921/evidence/mutations/mutation-summary.log`。
  handoff の「18」は `M-14ab` を `M-14a` / `M-14b` へ分割再走した後に更新されなかった
  stale 値 / R-025）で、**15 本 = superseded（後継は本 PBI の M-1〜M-4b）/
  4 本 = M-01・M-02・M-03・M-16 は新 HEAD で再走し kill 再確認**（15 + 4 = 19 の全件分類）
- **検証手順（R-025）**: TC-38 は「18 本…」という文字列の存在だけを見てはならない。
  **`grep -cE '^M-' mutation-summary.log` を実行して分母を数え直し、
  handoff の記載と一致することを確認する**（申告値の素通しを禁止）
- 入力 (2): `docs/working/TASK-1044/handoff.md`（本 PBI handoff）
- 期待出力 (2): **「未塞ぎ = 5 本（`ta-25` / `ta-26` / `ta-58` / `ta-59` / `ta-60`・
  2 env AND・Slice 2 へ）」の行が存在する**（R-016。pbi-input 残存エクスポージャ節の
  「AC-9 で義務化」を実際に検証する）
- 実施: V-1 受け入れ検査での静的確認（grep + 目視）。TA 化はしない
  （`tests/` から `docs/working/` の内容を assert すると別クラスの結合を生むため）
- 種別: 手動（V-1 チェックリスト項目）

## Evidence 実測（TA 外・ログ必須）

> **シェル実体の記録は必須（R-009）**: EV-1 / EV-2 のログ冒頭に
> **各シェルの実体と測定ホスト**を必ず記録する —
> `ls -l /bin/sh` / `sh -c 'echo ${BASH_VERSION:-not-bash}'` / `dash --version` /
> `bash --version` / `zsh --version` / `uname -a`。
> pre-fix 表で `sh` が bash と同じ rc=1・dash のみ rc=0 という分布は、測定ホストの
> `/bin/sh` が bash 3.2（macOS）であること＝**「4 シェル」が実質 3 実装**である
> ことを示唆する。この記録が無いと **CI 実体（dash）と `sh` の対応が evidence から
> 復元できない**。

### EV-1: 4 シェルマトリクス（helper 欠落）

- dash / zsh / bash / sh × TC-30 シナリオ → 修正後すべて rc=1（AC-1）。
  pre-fix 値（dash=0 / zsh=0 / bash=1 / sh=1）と対で記録
- **各シェルの実体・ホストを併記**（上記）

### EV-2: 4 シェルマトリクス（helper 存在）

- dash / zsh / bash / sh × TC-31 シナリオ → 修正後すべて standalone 契約
  （AC-2a〜2d の 4 点すべて）。pre-fix 値（4 シェル rc=0）と対で記録
- **各シェルの実体・ホストを併記**（上記）

### EV-3: pre-fix red（AC-5 (a)）

- 修正前 HEAD に TC-30/31 のみ適用して実行 → FAIL することをログ化
  （新 TC が現不具合を実際に検出できる証明）

### EV-4: 変異注入 kill（AC-5 (b)）

- 変異 M-1: bootstrap の case 行（direct-exec ガードの call site）を除去 →
  TC-30/31 が dash で FAIL（kill）
- 変異 M-2: helper resolve_mode 側を「変数消費」から独自判定（3 env のみ / または
  関数内 `$0` 再評価）へ退行させる → TC-31 が **zsh を含めて** FAIL（mode 分裂検出）。
  F-1 是正後の M-2 は **zsh FUNCTION_ARGZERO 問題の再発形を恒久検出**する役割を持つ
- 変異 M-3: F-3 明示検査を除去 → TC-32 が FAIL
- **変異 M-4（新規 / R-001・AC-8。期待値は R-018 で訂正）**: helper の 3 env 述語を
  **`PG_HARNESS_SOURCED` 単独へ退行**させる（`FIXTURES_DIR` / `EXTRAS_DIR` の
  条件を落とす）→ **TC-01c が FAIL（kill・rc=65）**。
  **TC-01b は rc=0 で生存する（＝ M-4 の設計上ヒットしない）** — TC-01b の判別子は
  `PG_HARNESS_SOURCED=0` であり M-4 は同条件を保持するため**原理的に検出できない**
  （レビュアー実測）。旧記述「TC-01b / TC-01c が FAIL」は**半分外れ**であり訂正する
- **変異 M-4b（新規 / R-018）**: helper の述語から **`PG_HARNESS_SOURCED` 条件を落とし
  `FIXTURES_DIR && EXTRAS_DIR` のみ**へ退行させる → **TC-01b が FAIL（kill）**。
  M-4 と対称に置くことで **`PG_HARNESS_SOURCED` と `EXTRAS_DIR` の 2 条件に検出力が
  あること**を示す。
  **`FIXTURES_DIR` 単独条件は本 PBI の scope 外（R-022）**: 整合レーンが `M-4c`
  （`FIXTURES_DIR` 条件のみを落とす退行）を作って実測したところ **TC-01b / TC-01c
  とも rc=0 で生存**した（`tc01b.sh` が `FIXTURES_DIR` を常に非空で固定しているため）。
  **これは base の `ta-61` に元からある穴**であり本 PBI が持ち込んだものではない。
  **「3 条件すべてに検出力」とは書かない**（実測は 2/3）。
  塞ぐか V2 へ送るかは **Q-4 で C-3 が裁定**する
- **fixture 更新との対**: **本 PR で fixture へ `_pg_extra_direct=0` を入れていない
  状態では M-4 / M-4b が生存する**（レビュアー実測: TC-01c は rc=0 で PASS）＝
  HR-4 回帰テストの検出力が失われていることの証明であり、
  M-4 / M-4b は fixture 更新の有効性を担保する対の証跡である
- 変異は sandbox 複製上でのみ実施（本体 checkout を汚さない）

## エッジケース

- `$0` にディレクトリを含まない直接実行（`cd tests/extras && dash ta-46-*.sh`）:
  `${0##*/}` は無変換で basename のまま → ガード発火（TC-30 バリアントとして 1 回実測）
- runner を `sh tests/run-tests.sh` / `cd tests && sh run-tests.sh` の双方で起動:
  `$0` はいずれも `run-tests.sh` に終わる → 非発火（TC-33 に包含）
- ta-61 sandbox の ta-97/98/99 fixture: `ta-*.sh` 名だが清浄 env での直接実行のため
  従来から standalone → 挙動不変（TC-36 に包含）
- **2 env のみ漏出（部分汚染）: 「不変」は誤り — 訂正（R-001）**。
  従来記述は「既存 TC-01b/01c が standalone 解決を検証済み → 不変」としていたが、
  **本 plan 適用後は成立しない**。`tc01b.sh` は bootstrap を持たず helper を直接
  source するため、`_pg_extra_direct` 未設定 → direct 既定 → **3 env の値に関わらず
  standalone** となり、TC-01b / TC-01c は「期待値 `pass=0` = standalone 側」と
  一致して **rc=0 で空振り PASS** する（＝ HR-4 の検証力が消える）。
  **`tc01b.sh` に `_pg_extra_direct=0` を明示設定して初めて env 述語が唯一の
  判別子として残り、TC-01b / TC-01c が元の意味を回復する**
  （TC-36 / TC-37 / **M-4（TC-01c）/ M-4b（TC-01b）** で担保 / R-021）
- `_pg_extra_direct=0` の環境漏出: bootstrap は無条件代入のため層 A では上書きされ
  standalone 維持（TC-30b で pin）。ただし bootstrap を持たない fixture では
  漏出値がそのまま効くため、fixture 側のトップレベル明示設定が必須（AC-8 / TC-37）
- 同一シェルでの連続 source（runner 経路）: `_pg_extra_direct` は**非 export の
  グローバル**であり、bootstrap を持たないファイルは**直前ファイルの値を継承**しうる。
  非 export のため子プロセスへは漏れないが、README 規約 8（トップレベル設定必須）と
  TC-37 で担保する（R-012）
