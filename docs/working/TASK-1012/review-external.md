# TASK-1012 外部レビュー結果（C-2）

> 本ファイルは **追記専用**（`.claude/rules/working-context.md`「C-2 指摘の差分管理」）。
> 指摘は `R-NNN` で採番し、計画本体（plan / todo / test-cases）への反映は **1 回だけ確定**する。
> 反映コミットには `Refs: R-NNN` を付す。

## メタ

| 項目 | 値 |
|---|---|
| 対象 | `docs/working/TASK-1012/` の plan.md / todo.md / test-cases.md / pbi-input.md |
| 基点 | `feat/1012-tc13-skip` @ `951e394`（`origin/main` = `862dd05`） |
| レーン | 設計妥当性レーン（`.claude/rules/review-principles.md` §7-bis） |
| 実施 | 2026-08-06 / 独立レビュアー 1 名（lite ゲート = 1 本・`critical/major=0` 要求） |
| 総合判定 | **CONDITIONAL**（critical 0 / major 4 / minor 3 / info 2） |
| コードベース整合レーン | **未実施**（設計妥当性レーンが実コードの行番号・関数定義位置・HO 判定を全件実測照合したため、当該レーンの主眼「既存パターンとの不整合」は本レビューに内包された。§7-ter の `unavailable` 記録には該当しない） |

## 判定サマリ

行番号・TC 番号・外部実装（`plan_package.py` / `arbiter.py` / `bin/plangate` / `check-plan-hash.sh`）への参照は **全件が実ファイルと一致**し、1 件のズレも無かった。指摘は「検査そのものの実行可能性・検出力」と「Mode 判定の計数規約」に集中している。

## 指摘一覧（監査表）

| ID | severity | 対象 | 指摘（要約） | status | reflected_in(commit) |
|---|---|---|---|---|---|
| R-001 | **major** | `test-cases.md` TC-A6a / `plan.md` 越境検査 | AC-1 の静的前提を担保する**唯一の検査に実行可能な判定式が無い**（範囲導出までが fence、識別子収集と全数照合は fence 外の散文）。記法規約 §8 の自己違反 | 反映 | `16cd2a4` |
| R-002 | **major** | `plan.md` 適用後 awk / `test-cases.md` 変異③ | 範囲導出 awk が **fail-open**。桁 0 の `fi` に一致するため、ゲート内の `fi` が 1 行でも未インデントだと範囲が黙って打ち切られる。`sh -n` は通り、TC-INV は `-w` で空白差を無視し、🚩「導出件数 4」も通過する。さらに変異③の注入対象 `_t26_t20` は**ゲート A 先頭付近**なので切り詰め後の範囲にも入り、この経路を一切実証しない | 反映 | `16cd2a4` |
| R-003 | **major** | `plan.md` Mode 判定 / `test-cases.md` | **Mode=standard が 2 つの計数規約に依存**。① AC 6→5 の畳み込み動機として「high-risk 帯に入り Mode 判定が変わる」と**帯回避を明記** ② 変更ファイル数を「1」とする一方、同 plan が arbiter 向けには「実差分は 2 を超える」と**逆の計数**を採る。リポジトリ内の先例も割れている（TASK-0970 は実装のみ / TASK-0981 は working context 7 を母数に含めて high） | 反映 | `8216339` |
| R-004 | **major** | `test-cases.md` TC-A5 / `pbi-input.md` AC-5 | **AC-5 に拘束力が無い**。FAIL 条件が「OPT 中央値 > BASE 中央値」だけで、短縮率 0〜15% は WARN で受理して完了できる。恒久コスト（子のカバレッジ縮小＝テスト意味論の変更）は確定する一方、便益未達でも完了する非対称。取り消し判断ゲートが plan / todo のどこにも無い | 反映 | `16cd2a4` |
| R-005 | minor | `test-cases.md` TC-A1c / TC-A2a | 記法規約の**兄弟取りこぼしが再発**（TC-A1b / TC-INV に fence を入れた際の対象漏れ）。TC-A1c は素直に書くと `\|` エスケープ事故を起こす形 | 反映 | `16cd2a4` |
| R-006 | minor | `plan.md` 越境検査の収集パターン | `^\s*(\w+)=` は**行頭でない代入を拾わない**（範囲内に 6 箇所）。`\s` / `\w` は **POSIX ERE 外**で非可搬。※現時点では 6 変数すべてが行頭代入も併存するため false negative は **0 件** | 反映 | `16cd2a4` |
| R-007 | minor | `pbi-input.md` AC-4 | AC-4 は `sh tests/run-tests.sh` のみで **python テスト側を含まない**（`run-tests.sh` に pytest 起動は 0 件）。A-3〜A-5 は working tree が dirty なので `test_tc45`（#997）と CI の挙動差が残る | 反映 | `16cd2a4` |
| R-008 | info | `test-cases.md` ログ採取 | 判定用ログ `t26-child.log` を**リポジトリルート**に生成し削除指示が無い。TC-33 の走査対象外なので実害なしだが untracked が残る。※ **#1021（ta-09 の repo 汚染）と同クラス**なので同時に閉じる | 反映 | `16cd2a4` |
| R-009 | info | `test-cases.md` TC-A2a | AC-2 が「TC 総数・PASS 件数の一致」で **TC ID 集合の同一性**を見ない。本変更では件数が減る方向にしか動かないため実害なし | 反映 | `16cd2a4` |

## オーガナイザーによる一次検証（受理前の実物照合）

ワーカー報告をそのまま受理せず、最も影響の大きい **R-002 を自分で再現**した。

```sh
# ゲート内に桁 0 の `fi` が 1 行混ざった入力（全 10 行・本来の範囲は 1-10）
awk '
  /^if \[ "\$\{PG_T26_NO_RECURSE:-0\}" = "1" \]; then/ { depth++; if (depth==1) gs=NR }
  /^fi$/ { if (depth==1) { print gs"-"NR } ; if (depth>0) depth-- }
' repro.txt
# → 1-5     ← 範囲が黙って打ち切られる（fail-open）

# 全 fi をインデントした正常形
# → 1-7     ← 正しい
```

**結果**: R-002 は再現。エラー・警告は一切出ず、切り詰められた範囲だけを見て越境検査が 0 件 PASS する経路が実在する。**major として受理**。

## 指摘ゼロと確認された領域（監査連続性）

「見ていない」と「見て問題なし」を区別するため明示する。

- **行番号・TC 番号・件数の主張は全件一致**。`L62-68` / `L92` / `L293` / `L321` / `L388` / `L394` / `L421` / `L423` / `L527` / `L558` / `L673` / `L683` / `L707` / `L713` / `L732` / `L743`、extras **57 本**、`plan_package.py:188` / `:341`、`c3prime_verify.py:71-72`、`arbiter.py:421 SIZE_OK_MAX_FILES = 2`、`check-plan-hash.sh:124-134`（HO 9 カテゴリ）、`.claude/settings.json:102,111`。plan の awk が現ファイルに対し `67-92` / `293-321` を返すことも実測一致
- **Hardening Override 該当性: 非該当**。`tests/extras/*.sh` は HO 9 パターンのいずれにも一致せず、ai-loop carve-out にも非接触。plan の boundary 主張は正しい
- **設計の中核前提（ゲート 2 分割でヘルパー定義を外に残す）は妥当**。ゲート A 内 31 識別子・ゲート B 内 46 識別子とも範囲外からの参照 **0 件**、ゲート範囲内で定義される関数は `_t26_mk_refs_guard_sandbox`（L527 = 両ゲートの間）のみ。ゲート A→B の相互参照も 0 件で、越境検査が false positive を出す構造でもない
- **TC-13 のカバレッジ論拠は正しい**。TC-13 の判定は `TA-26 standalone: … 0 failed` の grep と静的自己証明のみで、子の個別 TC 結果に依存しない。`set -e` が無いことも確認済み
- **変異①②の検出力は成立**。①条件反転は親の PASS 数を減らし TC-A2a が確実に FAIL。②ゲート B 終端の縮小では `_t26_mk_refs_guard_sandbox` がゲート外なので子で TC-36 が正常実行され `[PASS] TC-36` が出る＝空振りしない
- **todo H-0 の `bin/plangate approve` 4 条件は全件実装と一致**（`ps -p $PPID` の reject / `[ -t 0 ]` + 4 env / `token_hex(4)` の 8 桁 hex / 既存 c3.json + `--force` 無しで `return 2`、c3.json は validate の前に書かれる）
- **todo の rollback / 依存関係: 指摘なし**。変異復元（`git checkout --`）と実装取り消し（`git checkout HEAD --`）のセマンティクス分離、A-5 の退避コピー方式、A-4 → A-5 の直列化はいずれも git の実挙動と整合
- **test-cases と AC の紐付き網羅: 指摘なし**（R-004 の閾値問題を除く）。AC-1〜AC-5 + 静的前提 + 不変条件がすべて TC を持ち、E-1〜E-6 も AC へ帰着

## 反映方針

`.claude/rules/working-context.md` の順序に従う:

1. 本ファイルへ R-NNN を集約（本コミット）
2. **1 回だけ確定反映**（`Refs: R-001 R-002 R-004 R-005 R-006 R-007 R-008 R-009`）
3. 簡易 C-1 再実行
4. **人間が最終 `c3.json` を発行**（確定後 plan の `plan_hash`）
5. exec

**R-003 は 2 の対象外**。Mode を standard のままとするか high-risk へ引き上げるかは承認境界に関わる判断であり、Human C-3 の判断事項として保留する（差分は実質 V-2 の要否）。

## 追記: R-003 の決着（2026-08-10 / 追記専用）

> 本節は**追記**であり、上記 R-001〜R-009 の記述は書き換えていない（監査表の R-003 行の `status` / `reflected_in` のみ、規約どおり更新した）。

| 項目 | 内容 |
|------|------|
| **決定** | **B. Mode を high-risk へ引き上げる**（Human 決定 2026-08-10） |
| **決定者** | Human（C-3 の承認境界に関わる判断のため AI は決定しない） |
| **反映** | `.claude/rules/working-context.md`「C-2 指摘の差分管理」に従い **1 回だけ確定反映**（コミットに `Refs: R-003`）。plan.md 改訂 10 / pbi-input.md / test-cases.md / todo.md |
| **reflected_in** | `82163397dfe39f6d8d1e635fc4d8d3ce9cd465ec`（監査表の R-003 行は短縮 SHA `8216339`） |

反映内容（詳細な台帳は `plan.md`「C-2 指摘の反映」節）:

1. **Mode = high-risk**。判定表を書き直し、定量軸（変更ファイル数 ≥ 6 / 受入基準数 6）で high-risk に到達することを示した
2. **計数規約を明示・統一**（指摘 2 の解消）: Mode 判定の母数は **PR の実差分に載る全ファイル**。arbiter の `size_ok` は `changed_files` の実数（`SIZE_OK_MAX_FILES`=2）で機械検証される**別レイヤ**であり、**両者の母数は本改訂で一致**した
3. **帯回避の記述を撤回**（指摘 1）: 「AC 数 6 は high-risk 帯に入るので畳む」という動機の記述を plan / test-cases から除去し、**AC-6 を独立の受入基準へ復帰**（TC-A6a / A6c を AC-6 へ、TC-A6b は AC-1 のまま）
4. **`lite_eligible=false`**
5. **V-2 / V-3 を必須化**。V-4 は `critical` のみなので適用外。※ 本項は当初「standard との実質差分は V-2」と書いていたが **R-012 で誤りと判明**（中→高 の差分は `brainstorm` / `C-2` / `exec 並列` / `V-2` の **4 行**）。訂正は `e22053e`
6. **C-2 の充足判定は「不足」と明記**した。high-risk では Lite の 1 本枠（AC-12）ではなく Standard 枠で読むべきであり、`review-principles.md` §7-bis の**コードベース整合レーンが未実施**のまま残る。追加 1 本を実施するか不足を許容するかは **Human C-3 の判断事項**として提示する（AI は「充足」と書き換えない）

**ゲート戦略は不変**（C-3' は非 production の裁定記録 / 承認は Human C-3。`bin/plangate exec` は APPROVED の `c3.json` のみ受理）。

**未反映の指摘は 0 件**（R-001〜R-009 すべて反映済み）。

## 追記: 改訂 10 に対する独立 river-review（2026-08-10 / 追記専用）

> R-003 の反映commit `8216339` に対して**独立レビュアー**が実施。critical 0 / major 2 / minor 2 / info 1。
> 既存の R-001〜R-009 とは**別採番（R-010〜）**とし、上記の C-2 監査表には手を触れていない。
> レビュアーは AC-6 独立化の反映 4 箇所・TC-A6b を AC-1 に残す例外・行番号アンカーの非 stale・C-2「不足」判定の妥当性を**独立に確認して指摘なし**とした。

| ID | severity | 指摘（要約） | status | reflected_in |
|---|---|---|---|---|
| R-010 | **major** | **TC-A6a の内包アサーションが「範囲が広すぎる」方向に fail-open**（C-2 R-002 の**逆方向**）。閉じ `fi` のインデント誤りで範囲が次の桁 0 `fi` まで延び、TC-30/33 領域を「ゲート内」と誤認する。`sh -n` / TC-INV（`-w` で空白差を無視）/ 🚩「導出件数 4」/ ランタイム TC のいずれでも見えず、**変異③でも検出できない** | 反映（**(1b) 排他アサーション** + **TC-A6d**） | `e22053e` |
| R-011 | **major** | `review-self.md` が存在せず `bin/plangate approve TASK-1012` が失敗する（`cmd_validate` の必須 5 点。c3.json は validate より**前**に書かれるため rc=1 で終わる） | **本ワーカーの対象外**（改訂 10 の maker が簡易 C-1 を書くと独立性を失うため、オーガナイザーが別の独立ワーカーへ委託） | — |
| R-012 | minor | 「standard との実質差分は V-2 の 1 点」が誤り。中→高 の差分は **4 行**（`brainstorm` / `C-2` / `exec 並列` / `V-2`）。とくに **C-2 が要約から落ちる**と承認者が「追加作業は V-2 のみ」と誤読する | 反映（4 行に訂正 + brainstorm / exec 並列の扱いを明記） | `e22053e` |
| R-013 | minor | 記法規約「表セルに書かない」と実体のずれ（TC-A3 / A4 / A5 がセルのみ）。`\|` を含まないため実害は無いが、**C-1 R5 → C-2 R-005 と 2 度再発**しており「入れ切った」宣言とのずれが 3 度目を招く | 反映（**規約の適用範囲を確定** + TC-A3 / A4 / A5 にフェンス追加） | `e22053e` |
| R-014 | info | TC-A1b は**期待どおり 0 件のとき `grep -c` の rc が 1**（POSIX）。A-3 を `set -e` / `&&` でまとめると**成功したときに限って**中断する | 反映（`\|\| true` + 注記） | `e22053e` |

### R-010 の一次検証（受理前の実物照合）

レビュアー報告をそのまま受理せず、**`test-cases.md` の TC-A6a フェンスを verbatim で抽出して実行**し、4 通りの範囲入力で再現・是正後の検出を確認した。

| 範囲入力（ゲート B） | (1b) **追加前** | (1b) **追加後** |
|---|---|---|
| `558-730`（正常） | `containment_violations=0` / `identifiers=77 crossings=0` / rc=0 | 同左（**回帰なし**） |
| `558-700`（狭める） | `OUT-OF-RANGE gate B: TC-36 at L707` / rc=1 | 同左（**回帰なし**） |
| `558-741`（広げる・現実的） | **`containment_violations=0` / `identifiers=78 crossings=0` / rc=0 = PASS** | `IN-RANGE gate B: TC-30 at L732` / rc=1 |
| `558-791`（広げる・拡大） | **`containment_violations=0` / `identifiers=83 crossings=0` / rc=0 = PASS** | `IN-RANGE` 2 件 / `containment_violations=2` / rc=1 |

**結果**: R-010 は再現。広げる側は警告も出さずに PASS しており、**major として受理**。
