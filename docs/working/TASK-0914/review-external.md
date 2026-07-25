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

## 次アクション（PlanGate 規約順序）

1. ✅ 本ファイルへ R-NNN 集約（完了）
2. ✅ plan / todo / test-cases への **1 回確定反映**（コミットに `Refs: R-301..R-309, R-350..R-354`）
3. ✅ 簡易 C-1 再実行 → `review-self.md`
4. ⏳ **Human が C-3 三値判断 → APPROVED `c3.json` を発行**（`bin/plangate approve` は対話 TTY 必須。AI 実行不可）
5. ⏳ exec（T-01 から）
