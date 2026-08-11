# TASK-0921 作業ステータス

> 最終更新: 2026-08-10 09:00
> 現在フェーズ: **C-2 完了 → 確定反映（1 回）待ち**。**Human C-3 未承認・実装未着手**
> モード: `high-risk`（Slice 1 = 層 A 12 本 + helper + contract TA + README = 15 ファイル）
> 関連 Issue: [#921](https://github.com/s977043/PlanGate/issues/921) / 親: [#1005](https://github.com/s977043/PlanGate/issues/1005) Reliability Recovery

## このファイルについて

本 PBI の作業は **2 系統のセッションが並行**して進んだ。本 status はその両方を 1 本の
時系列へ統合したものである（片方の系統だけを見ると現在地を誤読するため）。

| 系統 | 内容 | 到達点 |
|---|---|---|
| **系統 A** | 2 レーン C-2（設計妥当性 / コードベース整合）= `R-001`〜`R-020` | **PR [#1020](https://github.com/s977043/PlanGate/pull/1020) で main へマージ済み**。plan / todo / test-cases へ 1 回確定反映済み |
| **系統 B** | 4 レーン C-2（POSIX shell / test architecture / workflow boundary / maintainability）= **元 ID 48 個**（系統 B 文書は「32 件」と自称するが実際の採番 ID は 48 個。会計の分母は 48） | 成果が未コミットだったため退避 → **本ブランチで `R-021`〜`R-037` として review-external へ集約**（計画本体は未反映） |

## フェーズ履歴

> **日時は `YYYY-MM-DD HH:mm`（分まで）必須**（#463、テンプレート `docs/working/templates/status.md` 準拠）。
> 出典が日付までしか持たない項目は、対応する commit の author date を採用した（推定時刻は書かない）。

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ |
|------------------------|---------|------------|
| 2026-08-05 09:43 | Plan Package merged | PR [#1008](https://github.com/s977043/PlanGate/pull/1008) が main へマージ（merge commit `4448420`）。**Plan Package のマージは実装承認ではない** |
| 2026-08-05 09:45 | 系統 B Phase 3（baseline） | `sh -n` 58 ファイル **エラー 0**。full-suite **539 passed / 0 failed / rc=0 / 231 秒**。main の baseline は緑のため「赤なら実装へ進まない」停止条件に非該当 |
| 2026-08-05 10:05 | 系統 B Phase 2（trap 監査） | **案 C 採用不可**を実測で確定。`ta-45` が standalone-capable かつ trap 保有（L76 設定 / L224 解除）。`trap -p` が dash/zsh で使用不可。`tests/extras/README.md:81`「trap は使わない」が既に明文規約 → 案 D への replan を提案 |
| 2026-08-05 10:20 | 系統 B Phase 1（inventory） | 全 **57 件**を分類: standalone-capable 16 / harness-only 41。`[FAIL]` を出しながら rc=0 が **35 件**（`[FAIL]` 合計 256 / 伝播 0 件）= #921 の症状を実証。**偽 PASS 3 件（`ta-11` / `ta-32` / `ta-38`）** という issue AC に無い症状クラスを新規検出 |
| 2026-08-05 10:25 | 系統 B C-2 Lane 3 | PlanGate workflow boundary。blocker 1 / major 1 / minor 1 / info 2 |
| 2026-08-05 10:35 | 系統 B C-2 Lane 1/2/4 委託 | POSIX shell / mutation 検出力 / 移行リスクの 3 レーンを独立レビュアーへ委託（**案 D を対象**） |
| 2026-08-05（時刻不詳） | 系統 A C-2（2 レーン） | 設計妥当性 + コードベース整合。critical 0 / major 11 / minor 6 / info 3 = **R-001〜R-020**。基点 `origin/main` = `516e2f7` |
| 2026-08-06 18:27 | **系統 A の確定反映（1 回）** | PR [#1020](https://github.com/s977043/PlanGate/pull/1020) `76a91c3` が main へマージ。`R-001`〜`R-020` を plan / todo / test-cases へ 1 回確定反映し、**Slice 1 を C-3 提出可能な状態**にした。C-1 は 5 ラウンド実施済み |
| 2026-08-10 09:00 | **系統 B の集約（本ブランチ）** | 系統 B の**元 ID 48 個**を main 版と突合し、**未反映の固有指摘 17 件を `R-021`〜`R-037` として `review-external.md` へ追記専用で集約**。純粋除外 20 個・部分/統合 8 個は「重複除外表」＋「会計」に根拠付きで記録。`decision-log.jsonl` に `D-0921-09` / `D-0921-10` を append（`status=proposed`）。**計画本体（plan / todo / test-cases / review-self）は変更していない** |
| 2026-08-10 12:00 | **独立 river-review の反映（本ブランチ）** | critical 0 / major 4 / minor 5。**F-1** R-023 の前提誤り（層 C / D-2 (c) は既出）→ severity を minor へ引き下げ残余 1 点へ縮小 / **F-2** 「偽 PASS」判定式が evidence と矛盾（`[PASS]` は 0 ではない）→ 判定式を是正 / **F-3** 元 ID の会計不整合（32 → **48**）→ 全数照合表を新設 / **F-4** R-032 は `516e2f7`（PR #1017）で解消済み → `resolved-by-design` へ。あわせて採録側 17 件を `origin/main` = `9f9af94` で**現存スイープ**（stale は R-032 のみ）。trap 件数差は「未確定」→「**定義（数え方）の差**」として決着 |

## 現在の判定

| ゲート | 状態 |
|---|---|
| C-1 | 系統 A 側で 5 ラウンド実施済み（PR #1020 に反映）。**`R-021`〜`R-037` の確定反映後に簡易 C-1 を再実行する必要がある** |
| C-2 | **完了**（系統 A = R-001〜R-020 反映済み / 系統 B = R-021〜R-037 集約済み・未反映） |
| **C-3** | **未承認**。`docs/working/TASK-0921/approvals/c3.json` は**存在しない**。AI は C-3 を発行しない（Human-owned） |
| 実装 | **未着手**（C-3 承認前のため） |
| C-4 | 未到達 |

### C-2 の総合判定（系統 A + 系統 B 合算）

| severity | 系統 A（R-001〜R-020） | 系統 B 追補（R-021〜R-037） | 合算 |
|---|---:|---:|---:|
| critical | 0 | **1** | **1** |
| major | 11 | 8 | 19 |
| minor | 6 | 6 | 12 |
| info | 3 | 2 | 5 |

> [`review-principles.md`](../../../.claude/rules/review-principles.md) §4 より、**critical ≥ 1 = Human review required**。
> 系統 A 単独では `critical = 0` だったが、**R-021 の追補により判定が引き上がる**。

## 確定済みの設計判断（main 反映済み）

| ID | 決定 | 状態 |
|---|---|---|
| Human 決定 1 | **案 D（末尾 explicit finalize）を採用**（案 C = trap 方式は不採用） | main の `plan.md` へ反映済み |
| Human 決定 3 | 層 0（`ta-26` / `ta-58` / `ta-59` / `ta-60`）を **Slice 2 へ繰り延べ**（Slice 1 を 15 ファイル = high-risk 帯に収める） | 同上 |
| Human 決定 4 | 移行期間 allowlist を contract TA 本体の `_pending_migration`（heredoc を返す shell 関数）へ**内蔵** | 同上 |
| Human 決定 5 | TC-17 / M-10 を Slice 2 へ繰り延べず、**repo 実コピー sandbox を Slice 1 の必須ゲート**とする | 同上 |
| C-2 委譲裁定 ①②③ | probe env は **internal-only** / TARGET 未設定は **fail-closed** / probe を README へ**公開**（test section 限定） | 同上 |

> **注（系統 B 側の記述との差異）**: 系統 B の作業記録は「案 C → 案 D' へ Replan **提案中**」の時点で止まっている。
> main では既に **案 D が Human 決定 1 として採用済み**であり、Approach Comparison / Finalize precedence /
> Task 5 が案 D 前提へ全面改訂されている。系統 B の `D-0921-06`（案 D への replan 提案）は**実質的に決着済み**。
> 本ブランチで append した `D-0921-09` は「案 D の**素朴な実装**が `|| true` 型 4 件で成立しない」という
> **案 D 採用後の残課題**であり、案 D 自体の否定ではない。

## 残タスク

- [x] C-2 系統 A（2 レーン）→ `R-001`〜`R-020`
- [x] 系統 A の確定反映（1 回）→ PR #1020
- [x] C-2 系統 B（4 レーン）→ 元 ID 48 個
- [x] 系統 B の `review-external.md` への集約（`R-021`〜`R-037`）
- [ ] **`R-021`〜`R-037` の計画本体への確定反映（1 回）**（反映コミットに `Refs: R-0NN`）
      — **`R-022` の `.github/workflows/**` 部分は AI が適用せず patch 提示に留める**
- [ ] 簡易 C-1 再実行
- [ ] **Human C-3 承認**（`approvals/c3.json` の発行。確定反映の**後**）
- [ ] exec（Slice 1）

### Human 判断が必要な項目（AI は `approved` へ変更しない）

`decision-log.jsonl` に `status=proposed` で記録済み。

| ID | 判断事項 | 状態 |
|---|---|---|
| `D-0921-09` | 案 D の skip 経路を `pg_extra_contract_skip` 経由へ書き換え、Task 5 の対象を 3 本 → **7 本**へ拡大するか（R-021） | **未判断** |
| `D-0921-10` | contract TA と CI で `sh` 実体を固定するか（dash 明示 / dash + bash matrix）（R-022） | **未判断・HO 対象** |
| 未採番 | **層 C の空振り PASS に対する ROOT sentinel を Slice 1 へ前倒しするか、D-2 (c) の Slice 2 に委ねるか**（R-023）。※層 C の扱い自体は `plan.md:48` で **D-2 (c) 採用**として裁定済み。3 件自体の修理は Out of Scope | **未判断** |
| 未採番 | `original rc` の扱い: 2 値化するか「finalize 直前にコマンドを挟まない」規約にするか（R-030） | **未判断** |
| `D-0921-01`〜`05` | 2 層能力モデル / 共通 helper / runtime inventory 正本化 / probe seam（Plan Package 由来） | `proposed` のまま |

### BLOCKED

| タスク | blocker | owner | unblock_condition |
|---|---|---|---|
| `R-022` の CI 変更適用 | `.github/workflows/**` は Hardening Override 対象パス。AI は適用できない | human | Human が patch を確認し適用する（採否も Human 判断） |
| exec（Slice 1） | C-3 未承認（`approvals/c3.json` 不在） | human | `R-021`〜`R-037` の確定反映 → 簡易 C-1 → APPROVED な `c3.json` の発行 |

## 実測サマリ（系統 B / 基点 `origin/main` = `4448420`）

| 項目 | 実測値 | 証跡 |
|---|---|---|
| main HEAD（系統 B 採取時） | `4448420cb48261aefa9fd274e498f140ab5e4cf7` | — |
| `ta-*.sh` 総数 | **57**（`ta-48` 欠番 / `ta-14` 同番 2 ファイル） | [`evidence/inventory/extras-files.txt`](./evidence/inventory/extras-files.txt) |
| standalone-capable / harness-only | **16 / 41** | [`evidence/inventory/extras-inventory.md`](./evidence/inventory/extras-inventory.md) |
| full-suite baseline | **539 passed / 0 failed / rc=0**（231 秒） | [`evidence/baseline/full-suite.log`](./evidence/baseline/full-suite.log) |
| 構文チェック | 58 ファイル **エラー 0** | [`evidence/baseline/syntax.log`](./evidence/baseline/syntax.log) |
| `[FAIL]` を出して rc=0 | **35 件 / `[FAIL]` 合計 256 / 伝播 0 件** | [`evidence/baseline/standalone-current.log`](./evidence/baseline/standalone-current.log) |
| **空振り PASS（`vacuous`）**＝ rc=0 かつ `[FAIL]`=0 かつ **ROOT 誤解決で assertion が空振り**（**`[PASS]` は 0 とは限らない**） | **3 件**: `ta-11`(**P4** F0) / `ta-32`(**P1**+WARN1 F0) / `ta-38`(**P1** F0)。**別クラス**として `ta-06` / `ta-08` = P0 F0 **S1**（正当な SKIP・誤検出禁止） | 同上 `:21,43,49` / `:106,108`（R-023） |
| `trap` 文字列を含むファイル | **5 件**（`ta-07` / `ta-09` / `ta-24` / `ta-28` / `ta-45`）。うち**行頭**（関数・分岐の外）は **2 件**（`ta-09:23` / `ta-45:76`）。系統 A の「5 件」と系統 B の「4 件」の差は**数え方の差**として決着済み | [`evidence/inventory/trap-cleanup-audit.md`](./evidence/inventory/trap-cleanup-audit.md) |
| 早期脱出イディオム | `\|\| exit 0` 型 **3 件**（`ta-39` / `ta-43` / `ta-44`）+ `\|\| true` 型 **4 件**（`ta-45` / `ta-46` / `ta-47` / `ta-49`）※`ta-31` は分岐内のみ | [`review-external.md`](./review-external.md) R-021 |

### 本ブランチで再現した一次実測（R-021 の根拠）

`/bin/sh`（bash 3.2.57）/ `/bin/dash` / `/bin/zsh` の 3 実装で 2 型を実行:

| 型 | `/bin/dash`（= CI の `sh`） | `/bin/sh`（macOS = bash） | `/bin/zsh` |
|---|---|---|---|
| `return 0 2>/dev/null \|\| true` | 終了 | **継続（本体が走る）** | 終了 |
| `return 0 2>/dev/null \|\| exit 0` | 終了 | 終了 | 終了 |

案 D の末尾 explicit finalize を付けた最小再現（`fail=1` を立てた最悪ケース）:
**dash = rc 0 かつ FINALIZE 未到達** / **bash = 本体実行のうえ rc 1**。

## 計画からの変更点

本ブランチでは **計画本体（`plan.md` / `todo.md` / `test-cases.md` / `review-self.md`）を一切変更していない**。
[`working-context.md`](../../../.claude/rules/working-context.md)「C-2 指摘の差分管理」の順序
（(1) review-external へ集約 → (2) 1 回確定反映 → (3) 簡易 C-1 → (4) 人間が `c3.json` 発行 → (5) exec）
の **(1) まで**が本ブランチの担当であるため。

## 未処理・要 Human 対処

| 項目 | 内容 |
|---|---|
| ツリー汚染 | 系統 B のセッションで `tests/docs/working/_audit/hook-events.log`（未追跡）の残留が観測された。standalone 実行時に ROOT が `tests/` へ解決される `ta-09` 由来で、`.gitignore` 対象外。**R-023 の ROOT sentinel 検査を Slice 1 へ前倒しすれば構造的に塞がる**（前倒ししない場合は D-2 (c) の Slice 2 まで残る）。既存の残留は Human が判断して削除する |
| 破壊的テスト | `ta-54:129` が `$REPO_ROOT/plugin/plangate`（git tracked）を `rm -rf` し **trap なしで** `cp -r` 復元。中断時はツリー汚染。#921 のスコープ外だが follow-up 候補 |
| 固定名 tmp | `ta-49` が `/tmp/ta49_err{,2}` を固定名で作成し削除しない |
| コメント drift | `ta-26` の実行時間コメント「約 13 秒」に対し実測 **54〜58 秒**。contract TA の timeout 設計に影響（R-026） |
| ~~trap 件数の不一致~~ **（決着済み）** | 系統 A = 5 件 / 系統 B = 4 件の差は **定義（数え方）の差**。実測: `trap` 文字列を含むファイル = **5**、行頭（関数・分岐の外）の `trap` = **2**（`ta-09:23` / `ta-45:76`）、`ta-28:87,114` はサブシェル内。どの数え方でも「standalone-capable かつ trap 保有は `ta-45` のみ」は不変 |
| evidence の基点 SHA 表記差 | 同梱ログのヘッダ（`syntax.log:1` = `1242420` / `full-suite.log:5` = `ded2b4c`）が宣言（`4448420`）と不一致。**コード側（`tests` / `bin` / `scripts` / `.github`）の差分は空**で測定値に影響しないことを実測済み。注記を `evidence/baseline/baseline-summary.md:4` に追加した |

## 次の作業（Claude Code プロンプト）

`docs/working/TASK-0921/review-external.md` の **`R-021`〜`R-037`**（追補節）を読み、
計画本体（`plan.md` / `todo.md` / `test-cases.md`）へ **1 回だけ確定反映**する。
反映コミットのメッセージに `Refs: R-021` 〜 `Refs: R-037` を付ける。

制約:

- **`.github/workflows/**` 変更は AI が適用しない**（Hardening Override 対象。patch 提示のみ）。
  対象は **`R-022`（`sh` 実体の固定 / dash + bash matrix）** と
  **`R-026`（`timeout-minutes: 10` の再見積り）** の 2 件
- **`R-032` は `resolved-by-design`（`516e2f7` / PR #1017 で解消済み）のため反映不要**
- 反映後に**簡易 C-1 を再実行**し、その**後で** Human が `approvals/c3.json`（`c3_status=APPROVED` +
  確定後 plan の `plan_hash`）を発行する。**順序を逆にしない**（先に発行すると EH-3 が後続反映を mismatch 検知する）
- `decision-log.jsonl` の `status` を AI が `approved` へ変更しない
- **C-3 承認前に `tests/` / `scripts/` / `bin/` / `.github/` を変更しない**

最優先の反映項目: **R-021**（`|| true` 型 4 件を Task 5 の置換対象へ追加し、
`## 前提の実測検証` の「早期 `exit 0` = 3 件」を「早期脱出 2 型 7 件」へ是正）。

## 参照ファイル一覧

- [`pbi-input.md`](./pbi-input.md) — PBI INPUT PACKAGE（4 層構造 / 層 0・A・B・C の定義）
- [`plan.md`](./plan.md) — EXECUTION PLAN（`R-001`〜`R-020` 反映済み / 案 D 前提）
- [`todo.md`](./todo.md) — EXECUTION TODO
- [`test-cases.md`](./test-cases.md) — テストケース定義（TC-01〜TC-25 / M-01〜M-14）
- [`review-self.md`](./review-self.md) — C-1
- [`review-external.md`](./review-external.md) — C-2（`R-001`〜`R-020` + 追補 `R-021`〜`R-037`）
- [`decision-log.jsonl`](./decision-log.jsonl) — `D-0921-01`〜`D-0921-10`
- [`evidence/`](./evidence/) — 系統 B の baseline / inventory 証跡
- [`../TASK-0914/handoff.md`](../TASK-0914/handoff.md) — writeback 対象（§3 V2 候補表）
