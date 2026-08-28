# Status — TASK-1101

> Issue: [#1101](https://github.com/s977043/PlanGate/issues/1101)
> Mode: **high-risk**（`lite_eligible=false` / C-3 は Standard・同期固定）

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|---|---|---|
| 2026-08-15 16:55 | A | `bin/plangate init TASK-1101` で作業ディレクトリ生成 |
| 2026-08-15 17:05 | A | `pbi-input.md` 作成（#1101 の実測を根拠に PBI 化） |
| 2026-08-15 17:20 | B | `plan.md` v1 作成（**EH-3 が block したため draft → Human が `cp` で設置**） |
| 2026-08-15 17:45 | C-1 | セルフレビュー実施 → **FAIL 11 / WARN 3 / PASS 3** |
| 2026-08-15 17:45 | C-2 | 外部レビュー 3 レーン実施 → **critical 2 / major 6 / minor 4 / info 1** |
| 2026-08-15 18:10 | C-2 | `review-external.md` に **R-001〜R-013 / S-1〜S-4** を集約（追記専用・監査表つき） |
| 2026-08-15 18:30 | B' | **確定反映 1 回**: `pbi-input.md` 更新（AC 7→11）/ `plan.md` v2 / `todo.md` 新規 / `test-cases.md` 新規 |
| 2026-08-15 18:40 | C-1' | **簡易 C-1 再実行** → WARN（未解消 3 / 新規 N-1〜N-4）→ v3 へ確定反映 |
| 2026-08-15 19:10 | C-2'' | **RiverReview 実施** → **critical 1 / major 10 / minor 8 / info 1**。critical は**先行 4 レビューが全て見逃した**設計順序の欠陥 |
| 2026-08-15 19:20 | B'' | **v4 確定反映**（critical + major 10 + minor 8）。`review-self-2.md` を新規発行（M-9） |
| 2026-08-15 19:27 | C-3 | ⚠️ **v3 に対して APPROVED が発行される**（v4 未設置のまま `approve` を実行。`validate` は PASS を返した） |
| 2026-08-15 19:29 | C-3 | plan v4 設置 → **hash MISMATCH を検出**（`validate` FAIL）。承認が古い版に対するものと判明 |
| 2026-08-15 19:30 | C-3 | **`approve --force` で再承認** → 三点照合（v4 draft / c3.json / plan.md）が一致・`validate` PASS |
| 2026-08-15 19:31 | D | **exec 開始**。T-01（baseline）/ T-02（迂回面再測定）完了 |
| 2026-08-15 19:45 | D | **T-03 で中断** — `.sh` への書き込みが no-task セッションの EH-3 で block（`SKIP 拒否: SKIP_REASON 未設定`） |
| 2026-08-15 20:35 | D | **exec 再開**（worktree `plangate-wt-1101` / branch `feat/1101-ho-normalization` / base `73ac1db`）。Step 0〜5 を実施 |
| 2026-08-15 20:50 | D | **Step 0 完了**: T-02 迂回面を `73ac1db` で再実測（C-2 時点から変化なし）。T-01 baseline は **pristine clone で測り直し**（1 回目の worktree 実行は測定中に ta-65 を編集したため無効） |
| 2026-08-15 21:00 | D | **Step 1 完了**: `tests/fixtures/pg-fold-path.sh` に `_pg_fold_path` を実装。**4 シェル + `LANG=ja_JP.UTF-8` で出力 byte 一致**を本体組み込み前に確認 |
| 2026-08-15 21:15 | D | **Step 2 完了**: `scripts/apply-1101-ho-normalization.sh`（`--dry-run` / `--apply` / `--revert` / `--emit` / smoke + 自動 revert）。T-06 は旧 apply 2 本に**退役注記**（no-op を実測） |
| 2026-08-15 21:30 | D | **Step 3-4 完了**: ta-65 に `--emit` 経由の patch 済み sandbox 複製と TC-06 拡充 / TC-07 反転 / TC-08〜TC-12 を追加。**ta-65 = 16 passed / 0 failed** |
| 2026-08-15 21:50 | D | **Step 5 完了**: 変異 9 種（7 + 第 8 + 順序）を注入し **9/9 kill** を実測 |
| 2026-08-15 22:05 | D | **Step 0 T-01 確定**: pristine clone `73ac1db` で `Results: 741 passed, 0 failed / rc=0` |
| 2026-08-15 22:30 | C-2''' | **PR 前レビュー（独立 2 体 + オーガナイザー再現）で AC-1 未達を検出** — `_pg_fold_path` の repo root 除去が大小文字厳密で、root 前置部だけ大文字にした絶対パス（`/USERS/.../CLAUDE.md`）が素通り。macOS の case-insensitive FS で**同一実体に到達し書き込みが成立する**。Human 判断「**本 PBI 内で是正**」 |
| 2026-08-15 22:45 | D | **是正完了**: 先に `ta-65` TC-08 に root 大文字 2 形を追加し**是正前の実装で 30/195 FAIL** を確認 → `_pg_fold_path` の (4)/(5) を入れ替え → 直積 **195 件すべて rc=2**。変異 **M10** を追加し 10/10 kill |
| 2026-08-15 23:10 | D | **Step 6 完了（T-15）**: `tests/extras/ta-67-pg-fold-path-portability.sh` を新設。`ta-67` 5 passed / `ta-61` 契約 92 passed。変異 4 種で検出力を実証 |
| 2026-08-15 23:40 | D | **Step 7 部分（T-16）**: **fork 増加ゼロを実測**（3 経路とも base と patched で同一）。ただし**病的パスで実行時間が非線形に悪化**する問題を検出（下記「Step 7 の重要な検出」）。**判定は保留** |
| 2026-08-15 23:50 | D | **セッション中断**（オーケストレータ指示）。Step 7 の判定 / Step 8 / Step 9 / handoff は未着手 |
| 2026-08-28 12:00 | D | **exec 再開**（13 日ぶり）。base を `dfaeebb` から `origin/main` = `75d832d` へ **merge** で追随（rebase は既存コミットを書き換えるため不採用）。`check-plan-hash.sh` / `ta-65` / `ta-67` は main 側で**未変更**を実測（patch アンカーと parity は無傷）|
| 2026-08-28 12:30 | D | **Step 7 完了（T-16）— 判定 = 是正**。小文字化を `/` セグメント単位に分割 + 長さ由来の fail-closed 2 条件を追加。`len=2749` が 10,803ms から 208ms、`1 セグメント x 20,000 文字` が未完（ハング）から 58ms/rc=1 へ。変異 M11 / M7 再注入で検出力を実証（`evidence/test-runs/step7-performance.md`）|
| 2026-08-28 13:10 | D | **Step 8 完了（T-17）**: `ta-65` 17/0・`ta-67` 5/0・`ta-12` 14/0・`ta-39` 8/0・`ta-45` 7/0（後者 3 本は main が追加した `tests/fixtures/extras-mini-harness.sh` で隔離実行）。**`sh tests/run-tests.sh` の通し実行は禁止指示により未実施＝ degrade** |
| 2026-08-28 13:30 | D | **Step 9 完了（T-18）**: `docs/ai/hook-enforcement.md` の既知残存を 2 系統から 3 系統へ是正（FS エイリアスを追加）、変換クラスを 3 種から 7 種へ訂正、残存脅威モデルを追記 |
| 2026-08-28 13:45 | WF-05 | **handoff.md 発行（T-19）**。総合 **8/11 PASS・3 WARN・0 FAIL** |

## モード判定結果

**`high-risk`**

- 変更ファイル数 6 / 受入基準 11 / **承認境界そのものの判定ロジック**
- `mode-classification.md` の例外ルール「承認境界周辺の変更 → 最低でも高」に該当
- **`lite_eligible=false` 強制** / autonomous APPROVE 不可 / C-3 は同期

> critical への引き上げは不要。R-001 の Fix（`_norm_target` 据え置き）により**既存の承認契約を破壊しない**設計になったため。v1 のままなら critical 相当だった。

## 計画からの変更点（v1 → v2）

| 項目 | v1 | v2 | 理由 |
|---|---|---|---|
| 正規化の適用先 | `_norm_target` を**置き換え** | **`_ho_key` を新設**し `_norm_target` は据え置き | R-001（critical）。下流 3 経路が大小文字に感応して共有 |
| 実装方式 | `IFS=/` の for ループを想定 | **単語分割非依存**のパラメータ展開ループ | R-002（critical）。zsh で no-op になる |
| 正規化の順序 | repo root 除去 → 畳み込み | **畳み込み → repo root 除去 → 先頭 `/` 除去** | R-005。絶対パス入力で `/CLAUDE.md` が残る |
| AC 件数 | 7 | **11** | R-004 / R-007 / S-1 / S-3 の AC 昇格 |
| AC-1 の定義 | 既知 4 ケース | **9 カテゴリ 15 パターン × 変換 7 種 + 複合の直積** | R-004。狙い撃ち実装が PASS してしまう |
| AC-4 の検証方法 | `ta-65` を 4 シェルで実行 | **正規化関数を 4 シェルで直接評価** | R-003。`ta-65` は hook を常に `sh` で起動する false green |
| Step 順序 | apply スクリプトが最後（Step 7） | **Step 2 へ前倒し + sandbox 検証（Step 3）** | R-008。依存の逆行 |
| 性能基準 | `..` ループのコスト | **追加 fork 数（増加ゼロ）** | R-012。fork が支配的 |
| Questions | 3 件（未解決のまま承認要求） | **1 件**（Q1・Q3 を確定） | R-008。承認後の方式分岐は `plan_hash` を無効化する |

### 事実誤認の訂正（v1 の記述が誤っていた）

| v1 の記述 | 実測 |
|---|---|
| 「`realpath` は macOS 標準に無い」 | **誤り**。`/bin/realpath` は存在し `readlink -f` も動く。真の不採用理由は**存在しないパスで rc=1（新規 Write を正規化できず fail-open）** |
| 「末尾空白は case-insensitive FS のため実ファイルに到達」 | **誤り**。`cat "CLAUDE.md "` は `No such file`。到達するのは**大小文字だけ** |

## 残タスク

### 🤖 Agent

- [x] **T-01** baseline 再測定（pristine clone `73ac1db` → 741 passed / 0 failed / rc=0）
- [x] **T-02** 迂回面の再実測（C-2 時点から変化なし）
- [x] **T-03** `_pg_fold_path()` 単体実装 + 4 シェル直接評価
- [x] **T-04** `check-plan-hash.sh` への patch（`_ho_key` 新設 / `_norm_target` 据え置き / log を生パスへ）
- [x] **T-05** `scripts/apply-1101-ho-normalization.sh`
- [x] **T-06** 旧 apply スクリプト 2 本の stale 対処（退役注記 + no-op 実測）
- [x] **T-07** sandbox 検証環境（`--emit` による patch 済み複製）
- [x] **T-08** TC-07 の反転（既定 fixed + PENDING-APPLY flag）
- [x] **T-09** TC-06 拡充（変換適用 5 件）
- [x] **T-10** 直積検証（TC-08 / 165 件）
- [x] **T-11** `_norm_target` 不変の回帰表明（TC-10 / 3 経路）
- [x] **T-12** fail-closed（TC-09）+ 絶対パス非 block（TC-09b）
- [x] **T-13** 監査ログの生パス保持（TC-11）
- [x] **T-14** 変異注入 9 種 → **9/9 kill**
- [x] **T-15** 4 シェル可搬性の TC 化（Step 6）— `tests/extras/ta-67-pg-fold-path-portability.sh`
- [x] **T-16** 性能実測（Step 7）— fork 増加ゼロ + **非線形性を是正**（判定 = 是正。`evidence/test-runs/step7-performance.md`）
- [x] **T-17** 既存 4 本 + 新設 1 本の回帰確認（Step 8）— **`sh tests/run-tests.sh` の通し実行のみ未実施（degrade / AC-6 WARN）**
- [x] **T-18** `docs/ai/hook-enforcement.md` の更新（Step 9）— **AC-7 は WARN**（FS エイリアスの追跡 issue が未起票）
- [x] **T-19** handoff.md — 発行済み（2026-08-28 / `82dbe8e`）

### 👤 Human

- [x] **H-01: C-3 ゲート** — APPROVED（2026-08-15T10:30:43Z）
- [ ] H-02: patch 適用（`sh scripts/apply-1101-ho-normalization.sh --apply`）※ Step 9 完了後
- [ ] H-03: C-4 ゲート（PR レビューとマージ）

## V 系ステップ進捗

| ステップ | 状態 |
|---|---|
| L-0 / V-1 / V-2 / V-3 / V-4 | 未着手（exec 後） |

## 既知の制約

1. **`plan.md` は AI が編集できない**（EH-3）。v1 / v2 とも draft → Human が `cp` で設置した
2. **`scripts/hooks/check-plan-hash.sh` は AI が適用できない**（HO 対象パス）。patch + apply スクリプトまでが AI-owned
3. ただし **sandbox 複製 + patch により、Human 適用を待たずに検証を先行できる**（plan Step 3）

## 計画からの変更点（exec / Step 0〜5）

> 正本は `decision-log.jsonl`。以下は要約。

| # | 逸脱・訂正 | 内容 |
|---|---|---|
| 1 | **事実訂正** | plan / test-cases の「**第 8 変異で `ta-45` が FAIL する**」は**再現しなかった**（M8 注入時も rc=0 / 6 passed）。`ta-45` TC-01 は TASK 文脈で EH-3 を起動し C-3 conversation 分岐（no-task 経路の内側）に到達せず、判定も `grep -qiE 'SKIP\|PASS'` と緩い。**AC-2 の担保は新設 `ta-65` TC-10 に置く**。todo T-17 の🚩「`ta-45` が PASS することが AC-2 の実質的な担保」は成立しない |
| 2 | **機構の逸脱** | TC-07 を「fixed 固定」ではなく「**既定 fixed + PENDING-APPLY flag による明示 opt-in**」にした。単純反転だと Human が `--apply` するまで CI が RED になり PR がマージ不能。#1089 の KNOWN-GAP flag と同一機構（tracked flag / `--apply` が自動削除 / 適用済みで残れば stale FAIL）。**patch の内容自体は TC-08〜TC-12 が patch 済み複製に対して常時検査する** |
| 3 | 実装細部の確定 | **末尾 `/` を保持**（`CLAUDE.md/` の偽陽性回避 / エッジケース表と整合）。**絶対パスの `..` は root で clamp し fail-closed にしない**（TC-11b と両立） |
| 4 | 追加 | apply スクリプトに **`--emit`**（書き込みなし・stdout のみ）を追加。AI が `--apply` を実行せずに Step 3 の sandbox 検証を成立させるため |
| 5 | 測定手順 | baseline は **pristine clone** で測る（worktree で測ると測定中の編集が混入する。1 回目の実行が実際に汚染された） |
| 6 | **AC-1 未達の是正**（PR 前レビュー） | `_pg_fold_path` の適用順を **(4) repo root 除去 → (5) 小文字化** から **(4) 小文字化 → (5) repo root 除去**（root 側にも同じ写像）へ入れ替えた。plan §Approach の順序記述と異なるが、plan の順序のままでは **AC-1（repo root 跨ぎ × 大小文字の 2 種複合）を満たせない**。`$3=0` では従来どおり大小文字厳密で `_norm_target` 側の意味論は不変。詳細: [`evidence/test-runs/prereview-ac1-root-case.md`](./evidence/test-runs/prereview-ac1-root-case.md) |
| 7 | 直積の規模 | TC-08 の変換形を **11 形 → 13 形**（165 件 → **195 件**）。追加は repo root 形への大小文字変換 2 形 |
| 8 | 変異の本数 | **9 種 → 10 種**（M10: root 比較を大小文字厳密に戻す）。M7 のアンカーも新ブロックへ更新（旧アンカーは `anchor count=0` で**当たっていなかった**） |
| 9 | **AC-8 からの逸脱（Step 7）** | fail-closed を **2 条件 → 4 条件**にした。追加は **(c) 全体長が 4096 超（PATH_MAX 上限）**・**(d) セグメント長が 255 超（NAME_MAX）**。理由: `_pg_fold_tolower` の 1 文字ループが O(n^2) で、**セグメント数の上限は総文字数を制限しない**ため `1 セグメント x 20,000 文字` が上限を通過し、**timeout の無い EH-3 が block ではなくハングする**（可用性の穴）。セグメント分割だけでは この入力に効かず（実測）、長さ上限だけでは worst case が数十秒に達するため**両方が要る**。(c)(d) に該当する入力は FS 上のファイルを指しえないため正当な書き込みを止めない。`plan.md` は C-3 承認済みで編集できないため**逸脱として記録**する。詳細と却下した代替案: [`evidence/test-runs/step7-performance.md`](./evidence/test-runs/step7-performance.md) §3 |
| 10 | **回帰実行の手段** | `ta-12` / `ta-39` / `ta-45` は harness-only のため、main が追加した `tests/fixtures/extras-mini-harness.sh` で 1 本ずつ隔離実行した。`sh tests/run-tests.sh` の通し実行は**禁止指示により未実施**（AC-6 WARN / degrade）|

## ⚠️ Step 7 の重要な検出（**未解決 / 次セッションの最優先**）

**fork 増加はゼロだったが、`_pg_fold_tolower` の 1 文字ループが入力長に対して
非線形（実測上ほぼ O(n²)）で、長い大文字パスを渡すと実行時間が跳ね上がる。**

### 実測（単発。`base` = 未適用 hook / `patched` = `--emit` の patch 済み hook）

| 入力 | base | patched |
|---|---|---|
| `CLAUDE.md`（len=9） | 83ms | **88ms** |
| `CLAUDE.MD`（len=9） | 88ms | **80ms** |
| 50 セグメント × 大文字（len=609） | 80ms | **230ms** |
| 100 セグメント × 大文字（len=1209） | 81ms | **1,027ms** |
| **250 セグメント × 大文字（len=3009）** | 81ms | **13,135ms** 🔴 |
| 250 セグメント × **小文字**（len=3009） | — | **179ms**（写像ループを回さない経路） |
| **1 セグメント × 20,000 文字 大文字** | 97ms | **測定打ち切り（10 分の枠内で未完）** 🔴 |

### なぜ危険か

- **セグメント上限 256 は「セグメント数」しか見ておらず、総文字数を制限していない**。
  `1 セグメント × 20,000 文字` は上限判定を通過し、写像ループだけが O(n²) で回る
- **EH-3 に `timeout` は設定されていない**（本 PBI 自身が Risks に明記）。
  したがって**暴走は block ではなくハング**になる。これは fail-closed ではなく
  **可用性の穴**（全 Edit/Write が止まる）
- 大文字を含まない入力は `case *[A-Z]*` のガードで写像ループを回さないため、
  **通常運用では顕在化せず、悪意ある入力でのみ発火する**

### 想定される是正案（**未実装 / 次セッションで方式を決めること**）

1. **文字数の上限を fail-closed 条件に追加する**（例: 4096 文字超は block）。
   plan の fail-closed は 2 条件（先頭 `..` / セグメント上限）なので、
   **3 条件目の追加は plan からの逸脱** → オーケストレータ判断が要る
2. 写像を**セグメント単位**に分割して O(n²) の n を小さくする（実装のみで完結）
3. `${v#?}` / `${v%"$rest"}` の 2 回展開をやめ、別方式で 1 文字を取り出す

> **どれも未検証**。1 は plan 逸脱、2 は plan 内で収まる可能性が高い。

## スコープ外で検出した問題（本 PBI では手を出していない）

- `tests/extras/ta-45-c3-mode-config.sh` TC-01 は名前に反して **C-3 conversation 分岐を一度も通っていない**（TASK 文脈起動 + 緩い grep 判定）。`_norm_target` を破壊しても緑のまま。**別 issue 化候補**
- 前セッション baseline の 2 件 FAIL（TA-60 / TA-42）は **clean checkout では再現しない**（dirty tree 起因 = #997 と整合）

## 次セッション用プロンプト

```
TASK-1101（#1101 / EH-3 の HO 正規化）の続きです。

docs/working/TASK-1101/current-state.md と status.md を読んでください。
Plan Package（pbi-input / plan v2 / todo / test-cases / review-self / review-external）
は揃っており、C-2 の指摘 R-001〜R-013 / S-1〜S-4 は確定反映済みです。

次は C-3（人間）です。承認後、todo.md の T-01 から着手してください。
Mode = high-risk・lite_eligible=false のため autonomous APPROVE はできません。

注意:
- plan.md は EH-3 が block するため AI は編集できない（draft → Human が cp）
- scripts/hooks/check-plan-hash.sh は HO 対象パスのため AI は適用できない
- 検証は ta-65 の sandbox 複製に patch を当てて先行できる（plan Step 3）
```

## 参照ファイル一覧

- `docs/working/TASK-1101/` 配下すべて
- `scripts/hooks/check-plan-hash.sh`（対象・HO）
- `tests/extras/ta-65-eh3-ho-task-context.sh` / `ta-12` / `ta-39` / `ta-45`（回帰対象）
- `docs/ai/hook-enforcement.md`（AC-7 の更新対象）
- `scripts/apply-eh3-ho-always.sh` / `scripts/fix-eh3-doc-light-maint-guard.sh`（S-2 の stale 対処）
