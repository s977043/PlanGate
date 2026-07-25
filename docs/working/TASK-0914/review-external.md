# C-2 外部レビュー結果 — TASK-0914

> **追記専用**（`.claude/rules/working-context.md` §review-external.md）。既存エントリは編集・削除しない。
> 実施: 2026-07-25 / 対象: plan.md `feat/task-0914-plan`（未コミット時点）/ Mode: high-risk（C-2 複数観点）
> 2 レーン構成は `.claude/rules/review-principles.md` §7-bis に準拠。

## 実施レーン

| レーン | 担当 | 読んだ範囲 | 判定 |
|--------|------|-----------|------|
| 設計妥当性レーン | `qa-reviewer`（サブエージェント） | pbi-input / plan / todo / test-cases（実装コード非精読） | **WARN**（critical 0 / major 5 / minor 3 / info 1） |
| コードベース整合レーン | `explorer-agent`（サブエージェント） | 上記 + `scripts/sync-plugin-plangate.sh` / `ta-26` / `run-tests.sh` / extras 11 本 / `_ai_loop_link_rewrite.py` | **WARN**（critical 0 / major 2 / minor 2 / info 1） |

**合計: critical 0 / major 7**。C-3 三値では **CONDITIONAL** 相当（`bin/plangate exec` は APPROVED のみ受理するため、確定反映 → 簡易 C-1 → Human が APPROVED `c3.json` 発行の順序を守る）。

### オーガナイザーによる指摘の裏取り（実測）

指摘を受理する前に、主張の事実性を一次ソースで確認した（`.claude/rules/review-principles.md` の「故障確率で判断」/ 実物照合）。

| 指摘 | 裏取り方法 | 結果 |
|------|-----------|------|
| R-350（ta-39 のみ判定 2 箇所） | `for f in 39 43 ... 53; do grep -c 'FIXTURES_DIR:-' ...` | **確認**（ta-39=2、他 10 本=1） |
| R-351（symlink 除外の非対称） | `sed -n '157,166p' scripts/sync-plugin-plangate.sh` | **確認**（コピーループに `[ -L "$_rf" ] && continue` が実在） |
| R-352（行番号 L103-111 が 2 行不足） | `sed -n '112,114p'` | **確認**（`fi` / `fi` が L112-113） |
| R-353（`references/README.md` の実在） | `find plugin/plangate/skills -path '*/references/README.md'` | **確認**（`ai-loop-cycle/references/README.md` のみ実在。経路1 の対象 2 skill（skill-creator / review-gate）の src 側には不在） |
| R-302（V-1-B の `env -u` 自己無効化） | `test-cases.md` V-1-A の実コード確認 | **確認**（V-1-A のループが `env -u PLANGATE_HOOK_TASK` を含み、V-1-B が「上記ループを再実行」と指示しているため汚染が剥がれる） |

## 監査表（指摘 → 反映）

| ID | lane | severity | 概要 | status | reflected_in | notes |
|----|------|----------|------|--------|--------------|-------|
| R-301 | 設計 | major | AC-6 に実行件数の下限がなく「1 件も実行されず exit 0」で空振りしうる。失敗表記が全 11 本 `[FAIL]` 統一である実測記録もない | reflected | 本 PBI 確定反映コミット | AC-6 に第 3 条件（`[PASS]` 件数が baseline 一致）を追加。T-01 で 11 本の baseline 件数と失敗表記の統一を実測 |
| R-302 | 設計 | major | V-1-B が V-1-A のループ（`env -u` 付き）を流用しており汚染が剥がれ、AC-7 が原理的に検出力ゼロ | reflected | 同上 | V-1-A / V-1-B を別ループに分離。V-1-B は `env VAR=... sh "$f"` で汚染を明示注入。移行前に ta-39 で NG が出ることを検出力証明として evidence 化 |
| R-303 | 設計 | major | AC↔TC の誤割当（TC-25 は経路2 なのに AC-2 へ）+ 経路1 の dry-run 一致 TC 欠落（plan Testing Strategy との不一致）+ AC-3 が範囲指定の bucket | reflected | 同上 | AC-2 → TC-26/27 に修正、TC-25 を AC-1 へ移動、**TC-32（経路1 dry-run 一致）追加**、AC-3 を個別列挙化 |
| R-304 | 設計 | major | 「判別方式の統一」の完了を機械保証する AC/TC がない（残存ゼロ検査が不在・11 本の件数ハードコード依存） | reflected | 同上 | **AC-9 追加**（`tests/extras/**.sh` で `PG_HARNESS_SOURCED` を伴わない単独判別が 0 件）+ **TC-33** 追加 |
| R-305 | 設計 | major | 変異注入が guard 弱体化方向のみで、正常系（形骸化防止）と override の検出力が未実証 | reflected | 同上 | **M-6（常に blocked / 過剰発火）** と **M-7（override 判定行を削除）** を追加 |
| R-350 | 整合 | major | ta-39 のみ `FIXTURES_DIR` 判定が 2 箇所（2 箇所目は return/exit 分岐）で、plan/todo の単数形記述から漏れている | reflected | 同上 | todo T-07 に ta-39 の例外構造と扱い（AND 化のみ・unset は 1 箇所目の else 節のみ）を明記 |
| R-351 | 整合 | major | 経路1 の base/stale 集計に symlink 除外（`[ -L ]`）が未記載で、コピーループと非対称になり「集計と削除条件の不一致 = guard 無効化（#861 再発型）」ハザードを再現しうる | reflected | 同上 | plan Step 3 / todo T-04 に `[ -L ]` 除外の明記。test-cases に E-7（symlink）を追加 |
| R-352 | 整合 | minor | guard ブロックの行番号が L103-111 で閉じ `fi` 2 行を含まない | reflected | 同上 | plan / todo を **L103-113** に訂正 |
| R-353 | 整合 | info | U-1 の前提記述が不正確（`ai-loop-cycle/references/README.md` は実在する） | reflected | 同上 | 論点 D の記述を実測結果で置換。U-1 を Questions から解消済みへ移動 |
| R-354 | 整合 | minor | TC-24 / TC-25 の前提条件に `scripts/_ai_loop_link_rewrite.py` 同梱の必須性が未記載（guard と無関係な理由で TC が落ちる） | reflected | 同上 | 該当 TC の前提条件へ追記 |
| R-306 | 設計 | minor | 論点 F の unset 集合が外部行番号参照のみで plan 内に列挙されておらず、機械検証も drift 検知も不能 | reflected | 同上 | plan に env 名を明示列挙。AC-9 / TC-33 の静的検査枠へ「run-tests.sh の集合 ⊆ 各 extras の standalone 集合」を同居させる |
| R-307 | 設計 | minor | TC-31 が既存 TC-15 の再掲で二重管理になる | reflected | 同上 | TC-31 を削除し、AC-4 のマッピングで既存 TC-15 を参照する形へ変更 |
| R-308 | 設計 | minor | Step 2 / Step 3 の 🚩「手動再現」に evidence 保存先の指定がない（high-risk の silent failure 経路） | reflected | 同上 | plan Step 2/3 と todo T-03/T-04 に `evidence/verification/` 保存を明記 |
| R-309 | 設計 | info | 案 C のスコープ切り出しコスト（同一 11 ファイルを 2 回触る / 代理判定の恒久化）を handoff の妥協点として固定すべき | reflected | 同上 | Step 6 の Output と完了条件に handoff 記録を追加。follow-up 完了時に AC-6 判定を exit code ベースへ戻す旨を V2 候補として明記 |

**指摘なしと明示された観点**（監査連続性 / 設計妥当性レーン）: 論点 A / B / C / D / E / F の各判断、Mode 判定（high-risk が妥当・critical 引き上げ理由なし）、Work Breakdown の Output / rollback（R-306・R-308 を除く）、Out of scope の妥当性（scripts allowlist 経路の対象外判断・`.github/workflows` 非変更）。

**指摘なしと明示された観点**（コードベース整合レーン）: `guard_fired` のサブシェル非経由（新規 2 経路の呼び出し位置でも global 伝播が成立）、`set -- $_ai_loop_expected_refs` の安全性（U-2: 位置パラメータの後段使用は 0 件）、TC 番号の非衝突（TC-20〜TC-33 は既存と重複なし）、行番号アンカー L173-183 / L316-329 / L350-363 / L483-486 の一致。

## Unknowns の解消（本レビューで確定）

| ID | 内容 | 実測結果 |
|----|------|---------|
| U-1 | `references/README.md` の存在 | 経路1 の対象 skill（`skill-creator` / `review-gate`）の **src 側には不在** → 論点 **D-2（除外しない）を維持**。`plugin/plangate/skills/ai-loop-cycle/references/README.md` は実在するが、これは経路2 が `_ai_loop_spec_files`（L212）経由で正規に同期する対象であり D の判断対象外 |
| U-2 | 位置パラメータの後段使用 | **0 件**（`$@` / `shift` / `set --` なし。`$1` は L10 の `--dry-run` 判定のみで Step 2 の実装位置より前）→ `set -- $_ai_loop_expected_refs; _n=$#` は **安全**。`for` カウントループへの切替は不要 |

---

## 第 2 ラウンド: River Review（PR 作成前のローカル実施 / 2026-07-25）

> 対象: branch `feat/task-0914-plan` HEAD `59c13a1` の差分（計画文書 7 ファイル・990 行）
> ルーティング: `river-review-docs` + `river-review-testing` + `adversarial-review`
> 判定: **WARN**（critical 0 / major 4 / minor 5 / info 1）。第 1 ラウンドの 14 指摘とは非重複

### オーガナイザーによる裏取り（実測・全 major を確認）

| 指摘 | 裏取りコマンド | 結果 |
|------|--------------|------|
| RV-M1（V-1 ループが stdin 未リダイレクトでハング） | `sh tests/extras/ta-50-precompact-guard.sh` を 10 秒監視 / `</dev/null` 付きと比較 | **確認**（10 秒経過も生存 = HANG。`</dev/null` 付きは rc=0 / PASS=9） |
| RV-M2（V-1-B が AND を両方注入し harness 分岐へ入る） | `env ... PG_HARNESS_SOURCED=1 FIXTURES_DIR=/nonexistent/fixtures sh tests/extras/ta-39-*.sh` | **確認**（PASS=0 / baseline 8 → ROOT 解決が壊れる） |
| RV-M3（ta-26 の unset が 1 env のみで AC-9 の包含検査に落ちる） | `grep -n 'unset' tests/extras/ta-26-plugin-sync.sh` | **確認**（L22 の `PLANGATE_ALLOW_MASS_DELETE` 1 件のみ） |
| RV-m2（件数の食い違い） | `grep -o 'TC-[0-9][0-9]' ta-26 \| sort -u \| wc -l` / `ls tests/extras/ta-*.sh \| wc -l` / ta-39 の FAIL 数 | **確認**（既存 TC = **16**（TC-14 欠番）/ extras = **53** 本 / ta-39 の FAIL = **7 件**（PASS 1）。当方の「15 / 56 / 6」は誤り） |

### 監査表（River Review / 追記）

| ID | severity | 概要 | status | reflected_in | notes |
|----|----------|------|--------|--------------|-------|
| RV-M1 | major | V-1-A / V-1-B のループが `sh "$f"` を stdin 未リダイレクトで呼ぶため、`ta-50` が起動する `scripts/precompact-memory-guard.sh` の `cat`（非 tty 時に EOF まで読む）で**無限ハング**する。Stop Condition にハングの項目がなく自律実行が無言停止する | reflected | 第 2 ラウンド反映コミット | 全ループの `sh "$f"` を `sh "$f" </dev/null` に変更（T-01 の baseline 実測にも適用）。Stop Condition に「検証ループの無応答」を追加 |
| RV-M2 | major | V-1-B が `PG_HARNESS_SOURCED=1` と `FIXTURES_DIR` を**同時注入**するため AND 判別が真になり harness 分岐へ入る。ROOT が壊れ移行前後で同じく PASS=0 → AC-7 の「V-1-A と同一結果」は原理的に達成不能で、RT-4 が確実に誤発火する。R-302 の**逆方向**（過剰注入）の欠陥 | reflected | 同上 | V-1-B から `PG_HARNESS_SOURCED` を外し「`FIXTURES_DIR` だけが漏れている」シナリオへ。`PG_HARNESS_SOURCED` 単独注入は **V-1-B' として第 3 ループに分離** |
| RV-M3 | major | AC-9 の「unset 集合の包含」検査は `ta-26`（既に AND 判別済み・unset は 1 env のみ）で必ず失敗するが、ta-26 の unset 拡張がどの Step にも無い（AC と Step の scope 未接続） | reflected | 同上 | Step 5 / T-07 の Output に「ta-26 の standalone unset を 7 env へ拡張」を追加（ファイル数 14 は不変）。AC-9 と TC-33 の glob を `tests/extras/ta-*.sh` に統一 |
| RV-M4 | major | 変異注入表の誤り 3 点: ①M-6 の対象に TC-25 / TC-32（= guard 発火帯）が入っており「常に blocked」でも期待どおり PASS する ②`stale >= base` 変種は `base == stale` を突く fixture が存在せず（E-3 が「TC 不要」と明言）どの TC も FAIL しない ③M-5 が `continue` 実装を前提にしているが経路1 の削除ループは `for` 本体の最終ブロックで `continue` を要さない。結果 T-06 が必ず「期待 FAIL 不出」を生み **RT-3 / Stop Condition 3 を誤発火**させる | reflected | 同上 | M-6 の対象を TC-24 / TC-29 に限定。`base == stale` 境界の **TC-34 を新設**し M-6b で突く（E-3 の「TC 不要」判断を撤回）。M-5 を実装非依存の振る舞い記述へ書き換え |
| RV-m1 | minor | V-1-B が 7 env のうち 5 env しか注入せず、`PLANGATE_SKIP_REASON` / `PLANGATE_BYPASS_HOOK` / `PLANGATE_HOOK_STRICT` の無害化が挙動レベルで未検証（AC-9 の静的検査は「存在」しか見ない） | reflected | 同上 | V-1-B の注入を **7 env 全件**にし論点 F の集合と 1:1 対応させる |
| RV-m2 | minor | 件数の食い違い 6 件（既存 TC 15→**16** / 新規 TC 12→**14** / extras 56→**53** / ta-39 の FAIL 6→**7** / review-self サマリー PASS 22・N/A 3 → **23・2** / RT-6 の「想定 TC 数」が未定義で機械判定不能） | reflected | 同上 | 全件是正。RT-6 は総テスト数 **444**（430 + 14）に固定 |
| RV-m3 | minor | `tests/extras/README.md` 既存規約 7 の「extras 側の個別対処は不要」が新規項目 8（各 extras が自前で unset）と矛盾したまま残り、新規 extras の著者が unset を省略して AC-9 が将来落ちる（U-3 の drift を規約側から誘発） | reflected | 同上 | T-08 に「規約 7 の該当文を standalone は防御が効かない旨へ改める」を追加 |
| RV-m4 | minor | `_mass_delete_blocked` 擬似コードが WARN 文字列を `src=`→`base=` に変え `#861 safety guard` 部分を `...` で省略しており、そのまま実装すると既存 TC-08 / TC-12 の grep が外れて T-02 の 🚩 が guard 挙動と無関係な理由で落ちる | reflected | 同上 | Step 1 に「WARN 文の維持必須語（`#861 safety guard` / `解除しました` / `mass-delete safety guard が発火`）は不変」制約を追加 |
| RV-m5 | minor | AC↔TC マッピングの非対称（AC-1 に TC-25 を入れたのに AC-2 に TC-32 がない）+ AC-4 の既存 TC ラベル誤付（`.github/` 検査は TC-15 のみで TC-11 は override 動作） | reflected | 同上 | AC-2 に TC-32 を追加。AC-4 のラベルを分離 |
| RV-i1 | info | 検証手順の暗黙前提 3 点（M-1 の `git show HEAD:` が exec 中の HEAD 移動で非決定論 / V-1 ループの相対 glob が cwd 依存・`grep -c` が 0 件で rc=1 / **Stop Condition 6 と RT-2 が同一機械値で異なる指示**） | reflected | 同上 | `git show 90c313d:` に固定 / ループ冒頭に `cd "$(git rev-parse --show-toplevel)"` / Stop-6 を「RT-2 の再計画でも解消しない場合」へ条件分岐 |

### River Review が実測で「一致」を確認した主張（再検証不要の記録）

baseline 430/0、guard ブロック L103-113、経路1 L173-183 とコピーループの `[ -L ]` L163（削除ループ側に `[ -L ]` が無いことも確認 → 論点 D' の前提は正しい）、経路2 L316-329、終端 exit 3 L483-486、allowlist L350-363、extras 11 本と ta-39 の 2 箇所、論点 F の 7 env と `run-tests.sh` L20 の完全一致、`_t26_mk_guard_sandbox` L197-215、README 規約が現在 7 項目（→ 項目 8 が正しい採番）、TC-20〜33 の非衝突、相対リンク 8 本すべて実在（MISS 0）、Files 表 14 行と Mode 判定根拠の整合、V-1-A の shell 構文（`case *"[FAIL]"*` の誤解釈なし）。

### T-01 の baseline 参考値（River Review が clean env で実測 / `</dev/null` 付き）

```text
ta-39=8  ta-43=6  ta-44=5  ta-45=6  ta-46=4  ta-47=6
ta-49=6  ta-50=9  ta-51=5  ta-52=5  ta-53=4      計 64
```

**T-01 では自ら再実測して確定する**（本値は参考。全ファイル `[FAIL]` 0 / rc 0 で採取されたもの）。

## 次アクション（PlanGate 規約順序）

1. ✅ 本ファイルへ R-NNN 集約（完了）
2. ✅ plan / todo / test-cases への **1 回確定反映**（コミットに `Refs: R-301..R-309, R-350..R-354`）
3. ✅ 簡易 C-1 再実行 → `review-self.md`
4. ⏳ **Human が C-3 三値判断 → APPROVED `c3.json` を発行**（`bin/plangate approve` は対話 TTY 必須。AI 実行不可）
5. ⏳ exec（T-01 から）
