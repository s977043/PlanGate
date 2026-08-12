# PBI INPUT PACKAGE — TASK-1044

> Issue: [#1044](https://github.com/s977043/plangate/issues/1044)（P2 / bug）
> 親系譜: TASK-0921 Slice 1（#921）handoff 既知課題 2（HR-4 残存）/ 2-bis（F-3）
> 同クラス: #1026（シェル間セマンティクス逆転で静かに通る）

## Context / Why

TASK-0921 Slice 1 で導入した tests/extras の bootstrap（層 A 12 本 + ta-61 に複製）は、
harness 判定を 3 env（`PG_HARNESS_SOURCED=1` / `FIXTURES_DIR` 非空 / `EXTRAS_DIR` 非空）の
AND のみで行う。このため **3 env がすべて漏出した環境で直接実行**すると harness mode と
誤判定し、失敗が rc に伝播しない。

**現 main（`48f6971`）での再実測（2026-08-12 / 本 plan 作成時）**:

実測 1 — helper `_extra-contract.sh` 欠落 + 3 env 漏出 + 直接実行（issue #1044 記載の症状）:

| shell | rc |
|---|---|
| dash | **0（silent pass。`[FAIL] helper unresolved` は stderr に出るが rc=0）** |
| zsh | **0** |
| bash | 1 |
| sh | 1 |

実測 2 — **helper が存在しても** 3 env 漏出 + 直接実行では harness 誤判定により
standalone rc 契約が丸ごと無効化される（本 plan 作成時に新規確認・issue 未記載）:

| shell | rc |
|---|---|
| dash / zsh / bash / sh | **すべて 0**（SKIP 経路が rc=3 でなく rc=0。カウンタ未初期化・summary 未出力・guarded env unset 不発） |

つまり根本原因は「helper 欠落分岐の脱出」ではなく **harness 判定述語が『実際に source
されているか』を見ていない**ことにあり、修正は mode 判定そのものに直接実行検知を
加える必要がある。

## What (Scope)

### In scope

1. **bootstrap の harness 判定に直接実行ガードを追加**する（`$0` basename ベース）。
   対象 = 層 A 12 本 + `ta-61-extra-contract.sh` 本体 bootstrap + ta-61 内 heredoc fixture
   （**これは本 PR で touch するファイルの列挙であって AC-3 / AC-4 / AC-8 の判定母数では
   ない** — 各 AC の母数は marker / `. "$T61_HELPER"` から動的導出する / R-030・R-032）
   （ta-99-probe-c 複製）— **照合単位は marker の出現**で、**base = 12 出現 / 12 ファイル
   （層 A のみ。ta-61 は本体・fixture 複製とも marker を持たないため S4 で marker 行ごと
   置換して載せる）→ 適用後 = 14 出現 / 13 ファイル**（R-024。AC-4 の照合対象は件数でなく
   bootstrap marker の出現から導出する）。**helper `_pg_extra_resolve_mode` は関数内で `$0` を
   再評価せず、bootstrap がトップレベルで確定した `_pg_extra_direct` を消費する**
   （zsh FUNCTION_ARGZERO により関数内 `$0` = 関数名となりガードが不発になるため —
   river-review F-1 実測反映。未設定は安全側 = direct 扱い。mode 分裂禁止
   — TASK-0921 plan L676-678 — は「同一の確定値を両者が使う」形で継承）
2. **変更後スニペットの正本を本 PBI の plan.md「### Mode resolution v2」へ移す**
   （TASK-0921 plan は承認済み歴史文書として不変。DoD の機械照合先を新正本へ切替）
3. **F-3（`_extra-contract.sh` L34/L117 の standalone 既定値非対称）の是正**:
   handoff 2-bis が「#1044 と同族の follow-up 対象」と明示し、0921 で見送った理由
   （変異 evidence の HEAD 整合失効）は新 PBI では該当しないため **In scope**。
   finalize が init 前に呼ばれた契約違反を fail-closed（exit 4 + stderr 診断）で顕在化させる
4. **回帰テスト追加**（ta-61 に TC 追加）: env 漏出 + 直接実行の 2 シナリオ
   （helper 欠落 → rc=1 / helper 存在 → standalone 契約維持）を dash で検証
5. **変異注入による検出力実証**: 修正前 HEAD で新 TC が FAIL すること、および
   ガードの call site を壊した変異で新 TC が FAIL（kill）することを evidence 化

### Out of scope

- 層 B / 層 C の contract 移行（TASK-0921 Slice 2 の範囲）
- ta-31 の分岐内 `return 0 2>/dev/null || true` 4 箇所（層 B / Slice 2）
- 層 C 空振り PASS の機械検出（HJ-2 裁定で Slice 2 D-2 (c) に委譲済み）
- `tests/run-tests.sh` 本体の変更（bootstrap / helper 側のみで完結させる）
- zsh を harness runner として公式サポートすること（runner は sh 前提を維持）

#### 残存エクスポージャ（本 PBI マージ後も塞がらない範囲 / R-006）

> issue #1044 のタイトル・AC はいずれも「塞ぐ」と読めるため、マージ後に
> 「extras 全体で塞がった」と誤読されうる。**塞ぐ範囲は bootstrap 系に限られる**
> ことを明示記録する（Out of scope の「移行作業」という言い方では、
> 残存する脆弱性そのものが読み取れないため）。

以下 **5 本は本 PBI 適用後も同一クラスの脆弱述語を保持する**。しかも
**2 env AND（`PG_HARNESS_SOURCED` + `FIXTURES_DIR`）で、層 A の 3 env AND より
条件が 1 つ少ないぶん更に破りやすい**（本 PBI 反映時に実測確認済み）:

| ファイル | 述語 | 直接実行ガード |
|---|---|---|
| `tests/extras/ta-25-approval-token-guard.sh` | 2 env AND | なし |
| `tests/extras/ta-26-plugin-sync.sh` | 2 env AND | なし |
| `tests/extras/ta-58-git-destructive-guard.sh` | 2 env AND（肯定形） | なし |
| `tests/extras/ta-59-apply-settings-merge.sh` | 2 env AND | なし |
| `tests/extras/ta-60-run-evidence.sh` | 2 env AND | なし |

- 塞ぐ範囲 = **bootstrap 系 13 本**（層 A 12 + ta-61 本体。fixture 複製を含めた
  照合母数は AC-4 参照）+ helper
- 未塞ぎ = **上記 5 本**（Slice 2 で bootstrap へ移行する際に同時解消）
- 本 PBI では**是正しない**（scope 外）が、**handoff に記録することを AC-9 で義務化**する
  （記録を AC 化しないと落ちる）

## 受入基準

| AC | 内容 |
|---|---|
| AC-1 | 3 env 漏出 + helper 欠落 + 直接実行が **dash / zsh / bash / sh の 4 シェルすべてで rc=1**（実測 1 の是正） |
| AC-2a | 3 env 漏出 + helper 存在 + 直接実行で **rc が standalone 契約（0 / 1 / 3）に従う**（実測 2 の是正） |
| AC-2b | 同シナリオで **summary 書式 `TA-<NN> standalone: N passed, M failed` が出力される**（R-015a 不変） |
| AC-2c | 同シナリオで **guarded env の unset が実測される** — 契約下で起動した子プロセスで、**`tests/run-tests.sh` の `^unset` で始まる行から実行時導出した env 集合の全名**がいずれも未設定であること（現時点の実測は 7 名 = `PLANGATE_SKIP_REASON` / `PLANGATE_HOOK_TASK` / `PLANGATE_HOOK_FILE` / `PLANGATE_BYPASS_HOOK` / `PLANGATE_HOOK_STRICT` / `PG_HARNESS_SOURCED` / `PLANGATE_ALLOW_MASS_DELETE`。**件数も名前も契約値にせず、行番号でもアンカーしない** — `ta-61:286` の `_T61_GUARDED_ENVS`（`sed -n 's/^unset \(.*\) 2>\/dev\/null.*$/\1/p'`）をそのまま消費する。**7 名で固定すると 8 個目の guarded env が追加されたとき静かに検査対象から落ちる** = R-030 が潰した偽陰性と同クラス / R-033）。**`^PLANGATE_` の全数 0 は要求しない**（repo 内の `PLANGATE_*` は実測 52 種で、`PLANGATE_BIN` / `PLANGATE_PYTHON` / `PLANGATE_REPO_ROOT` 等は guarded 集合外。開発者環境や CI が無関係な `PLANGATE_*` を export しているだけで落ちる = 「無関係な PR の CI 落ち」と同型 / R-029）。漏出 env が子へ伝播しないことを実測する（「漏出環境で直接実行」という本 PBI のシナリオと同じ土俵にあるため必須） |
| AC-2d | 同シナリオで **カウンタが初期化される**（init 直後に `pass=0` / `fail=0`） |
| AC-3 | 正規経路の無回帰: `sh tests/run-tests.sh` フルスイートが rc=0 / fail=0、かつ **bootstrap marker を含む `tests/extras/ta-*.sh` 全件から contract TA 自身（`$_T61_SELF_ID` = `ta-61-extra-contract`）を除いた集合**の standalone 直接実行（清浄 env）が従来どおりの rc を返す。**自己除外は必須（R-032）** — S4 適用後は ta-61 も marker を持つため、除外しないと **ta-61 が ta-61 を起動 → 孫がフルスイートを再走する再帰**になり、回避できても **per-file `timeout 180` を確実に超過**して FAIL 扱いになる（`ta-61:304` の既存 standalone ループが `[ "$_t61_id" = "$_T61_SELF_ID" ] && continue` で自己除外しているのが repo の確立パターン）。**件数は assert しない**（AC-4 / AC-8 と同じ動的導出規約に揃える。本 PR 時点の実測は 13 ファイル − 自己 1 = **12 ファイル**だが、`tests/extras/` は成長ディレクトリであり固定件数にすると Slice 2 が追加した層 A ファイルが**静かに対象から漏れる**偽陰性を生む / R-030） |
| AC-4 | 述語の同一性: **bootstrap marker（`# ---- extras execution contract bootstrap`）の各出現**（`file:line` 単位。**1 ファイル内の複数出現をすべて照合する** — `ta-61` は本体 + fixture 複製で 2 出現を持つため、**ファイル単位ループにすると 2 つ目が照合網から外れる** / R-024）で、判定 2 行（case 行 + if 行）が本 PBI plan「### Mode resolution v2」と**行頭空白を除去した比較で**文字単位同一（機械照合）。**対象は marker 出現から動的に導出し、絶対件数を契約値にしない**（`tests/extras/` は成長ディレクトリ。実測は **base = 12 出現 / 12 ファイル → 適用後 = 14 出現 / 13 ファイル** だが、これは契約値ではなく実測値である。**base に ta-61 の marker は存在せず、S4 で marker 行ごと置換して初めて照合網に載る**）。helper は照合対象から**分離定義**とし、変数消費形 literal（`${_pg_extra_direct:-1}` 消費・関数内 `$0` 非評価）との一致を別途照合 |
| AC-5 | **変異注入**: (a) 修正前 HEAD で新 TC を走らせ FAIL を実証（pre-fix evidence）。(b) 修正後、**M-1 / M-2 / M-3 / M-4 / M-4b の全変異**で対応 TC が FAIL（kill）することを dash（M-2 は zsh も）で実証する — M-1: bootstrap の case 行（ガードの call site）除去 / M-2: helper を変数消費から独自判定へ退行 / M-3: F-3 明示検査の除去 / **M-4: helper の 3 env 述語を `PG_HARNESS_SOURCED` 単独へ退行させ TC-01c が FAIL（kill）すること**（**TC-01b は判別子が `PG_HARNESS_SOURCED=0` であり M-4 が同条件を保持するため原理的にヒットしない** / R-018）/ **M-4b: `PG_HARNESS_SOURCED` 条件を落とし `FIXTURES_DIR && EXTRAS_DIR` のみへ退行させ TC-01b が FAIL（kill）すること**。変異は関数でなく call site を壊す（#874 教訓） |
| AC-6 | F-3 是正: `pg_extra_contract_finalize` が `_PG_EXTRA_STANDALONE` 未設定（init 前呼出）のとき silent に harness 扱いへ落ちず、fail-closed（stderr 診断 + exit 4）となる。既存 TC-10（静的検出）は不変で PASS。**本 AC は Constraints「harness source 経路で非 0 return / exit しない（R-024）」に対する明示 carve-out である**（対象は init 前 finalize = 契約違反の mis-wire に限定。carve-out を設けること自体の可否は Q-1 で C-3 裁定） |
| AC-7 | ta-61 既存 TC（TC-01〜TC-29）が全 PASS（ガード追加による fixture 回帰なし）。**ただし「空振りでも PASS」は AC-7 充足と見なさない** — 検出力の維持は AC-8 と AC-5 の **M-4 / M-4b** で担保する（R-021） |
| AC-8 | **fixture の `_pg_extra_direct` 明示化**: ta-61 内で bootstrap を持たず helper を直接 source する **全 fixture**（harness 模擬・standalone 期待の双方）が `_pg_extra_direct` を**トップレベルで明示設定**しており、**未設定の fixture が 0 件**であることを**静的検査 TC** で機械検出する。将来の fixture 追加漏れもこの TC で検出する。**走査母数は `. "$T61_HELPER"` 由来で動的導出し、件数（本 PR 時点の実測 12）を契約値にしない**（AC-4 と同じ規約。plan「帰結」節の 4 本は「`PG_HARNESS_SOURCED` を明示設定するため挙動が変わる部分集合」であって走査母数ではない / R-014） |
| AC-9 | **evidence 継承の明示**: `docs/working/TASK-0921/handoff.md` 既知課題 2 / 2-bis に、本 PR による解消および **変異 evidence の HEAD 整合の扱い**が 1 行で追記されている。**分母は申告値を継承せず `grep -cE '^M-' mutation-summary.log` で数え直す（本 PBI 実測 = 19 本。handoff の「18」は `M-14ab` 分割後に未更新の stale 値 / R-025）**。内訳 = **15 本 superseded（後継 = 本 PBI の M-1〜M-4b）/ 4 本（M-01 / M-02 / M-03 / M-16）は新 HEAD で再走し kill を再確認**（15 + 4 = 19 で全件分類）。**同 handoff で「18/18 KILL」を主張する全行（AC-7 PASS の根拠行 / 引き継ぎ文書の状態行 / テスト結果サマリ行）から当該注記への参照が張られている**（**行番号ではなく意味ラベルで検証する** — T-11 の追記で行番号はずれるため）。**および本 PBI handoff に「未塞ぎ = 5 本（`ta-25` / `ta-26` / `ta-58` / `ta-59` / `ta-60`・2 env AND・Slice 2 へ）」の行が存在すること**（R-016。残存エクスポージャ節の「AC-9 で義務化する」を実際に AC 本文へ落とす） |

## Notes from Refinement

- 修正案の `$0` アンカーは issue 記載のファイル名 literal 埋め込み（`*ta-46-ehs-wiring.sh)`）
  ではなく **`${0##*/}` の `ta-*.sh` glob 照合**とする。literal 埋め込みは bootstrap
  照合対象全件のバイト一致 DoD（TASK-0921 が確立した機械照合可能性）を壊すため
- **`$0` の評価位置は bootstrap トップレベル 1 回のみ**（F-1）: zsh は
  FUNCTION_ARGZERO（既定 ON）で関数内 `$0` = 関数名になるため、helper 関数内での
  再評価は zsh 直接実行でガード不発（実測: 関数内評価形は zsh のみ rc=0・summary 無し）。
  helper は確定済み変数 `${_pg_extra_direct:-1}` を消費する
- TASK-0921 plan「#### bootstrap の helper 解決規約」の「`$0` をアンカーにしてはならない」は
  **helper のディレクトリ解決**に対する禁止（harness では `$0`=run-tests.sh のため）。
  本 PBI の `$0` 利用は**直接実行の検知**であり、`$0`=run-tests.sh が `ta-*.sh` に一致しない
  ことをそのまま利用する = 矛盾しない（plan の Approach で明記）
- runner が zsh で起動された場合 zsh の FUNCTION_ARGZERO により source 先で `$0` が
  変わりうるが、runner は `sh tests/run-tests.sh` 前提（CI 実体 dash / README 規約）であり
  制約として明記する
- **`_pg_extra_direct` は新たな env 漏出面である（R-008）**: bootstrap は
  **無条件代入**（`case … esac`）なので層 A は安全だが、helper を直接 source する
  consumer が `_pg_extra_direct=0` を明示設定する方針である以上、
  「`_pg_extra_direct=0` が環境から漏れていれば harness と誤判定」という
  **#1044 と同型の窓**が新設される。将来 bootstrap の代入が
  `: ${_pg_extra_direct:=…}` へ「最適化」されると即座に回帰するため、
  **無条件代入を TC-30b で pin する**
- **`_pg_extra_direct` は非 export のグローバル（R-012）**: `run-tests.sh` は同一
  シェルで extras を順次 source するため、bootstrap を持たないファイルは
  **直前ファイルの値を継承**しうる。非 export のため子プロセスへは漏れない
  （設計として正しい）が、**「トップレベル設定必須」を規約化**する
  （`tests/extras/README.md` 規約 8 への 1 行 + AC-8 の静的 TC で担保）

## Estimation Evidence

- **Risks**: ta-61 の sandbox 系 TC（TC-14〜17 / TC-29）が bootstrap 複製をコピーして
  実行するため、述語変更が fixture 期待値を壊す可能性 → exec 冒頭で ta-61 全走を baseline 化
- **Unknowns**: macOS `/bin/sh`（bash 3.2）と CI `sh`（dash）の挙動差は実測 1 で確認済み。
  他に露出するシェル依存は変異注入と 4 シェルマトリクスで検出する
- **Assumptions**: tests/extras の実行ファイルは `ta-*.sh` 命名規約に従う（README 規約。
  `_extra-contract.sh` は glob 非一致 — TASK-0921 plan R-014 反証材料で実測済み）
