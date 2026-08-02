# EXECUTION TODO — TASK-0914

> Plan: [`plan.md`](./plan.md) / Test Cases: [`test-cases.md`](./test-cases.md) / C-2: [`review-external.md`](./review-external.md)
> Mode: **high-risk**（C-2 複数観点 + **C-3 Human 必須**・autonomous APPROVE 不可）
> 基点: main `90c313d` / C-2 指摘 `R-301..R-309` / `R-350..R-354` + River Review `RV-M1..M4` / `RV-m1..m5` / `RV-i1` 反映済み

## 依存関係

```text
T-01（baseline 実測: PASS件数 / 失敗表記統一）
  └→ T-02（共通関数導入 + sync_dir 置換）🚩
        ├→ T-03（経路2 guard）🚩 ──┐
        └→ T-04（経路1 guard）🚩 ──┤
                                    ├→ T-05a（経路2 TC）🚩 ──┐
                                    ├→ T-05b（経路1 TC）🚩 ──┼→ T-06（変異注入 M-1〜M-7）🚩
                                    └→ T-05c（静的 TC）🚩 ───┘
T-07（extras 11本 判別式+unset）──┐
T-08（README 規約追記）───────────┴→ T-09（AC-6/AC-7/AC-9 機械検証）🚩
T-06 + T-09 ─→ T-10（別 issue 起票 + handoff 妥協点記録）─→ T-11（回帰フルテスト）🚩 ─→ [L-0 / V-1 〜]
```

- **H-01（👤 human・T-01 の前）**: C-3 ゲート判断（high-risk のため必須。plan.md / test-cases.md / review-self.md / review-external.md を確認 → `bin/plangate approve` で APPROVED な `c3.json` 発行）
- **H-02（👤 human・PR 作成後）**: C-4 ゲート（GitHub 上でレビュー → マージ）
- ⚠️ T-03 / T-04 は T-02 の共通関数に依存するため**並行不可**（同一ファイルの隣接箇所を触る）。T-07 / T-08 は T-02〜T-06 と**独立**（別ファイル）なので並行可

---

## 🤖 Agent タスク

### 準備フェーズ

- [x] **T-01**: AC-6 の baseline 実測（R-301 / U-4）
  - 移行前の 11 本（ta-39/43/44/45/46/47/49/50/51/52/53）について、clean env（`env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PG_HARNESS_SOURCED -u FIXTURES_DIR -u PLANGATE_ALLOW_MASS_DELETE`）+ **`sh "$f" </dev/null`** での standalone 実行時の **`[PASS]` 件数**を実測し `status.md` へ表形式で記録（= AC-6 条件③の baseline）
  - ⚠️ **`</dev/null` を必ず付ける（RV-M1）**: 未リダイレクトだと `ta-50-precompact-guard.sh` が `scripts/precompact-memory-guard.sh` の `cat`（非 tty 時に EOF まで読む）でブロックし**無限ハングする**（実測確認済み）
  - 参考値（River Review が clean env で実測。**自ら再実測して確定する**）: `ta-39=8 ta-43=6 ta-44=5 ta-45=6 ta-46=4 ta-47=6 ta-49=6 ta-50=9 ta-51=5 ta-52=5 ta-53=4`（計 64）
  - 11 本の**失敗表記が `[FAIL]` に統一されている**ことを grep 実測（`NG` / `ERROR` / `not ok` 等の別表記がないか）。非統一なら AC-6 条件①の判定語彙を拡張して test-cases.md を更新
  - **AC-7 の検出力証明（R-302 / RV-M2）**: 移行**前**に V-1-B の汚染 env（`PG_HARNESS_SOURCED` は**注入しない**。AND 両方が揃うと harness 分岐に入り移行後も NG が残る）で 11 本を実行し **NG が出ること**を `evidence/test-runs/` へ保存（移行後に NG が消えることで検出力を示す）
  - Owner: agent / `rollback:` 不要（読み取りのみ）
  - 注: U-1 / U-2 は C-2 で解消済み（[`review-external.md`](./review-external.md) §Unknowns）。再実測は不要

### 実装フェーズ

- [x] **T-02**: `_mass_delete_blocked()` を追加し、既存 `sync_dir` 内 guard（**L103-113**。内側 `if`〜対応する `fi` 2 個まで — R-352）を同関数呼び出しへ置換
  - 🚩 **チェックポイント**: `sh -n` PASS + `tests/extras/ta-26-plugin-sync.sh` の既存 **16 TC**（TC-14 は欠番）全 PASS（`sync_dir` 経路の挙動不変を証明）
  - `guard_fired=1` の代入がサブシェル内に入っていないことを目視 + TC-10（exit 3）で実証
  - Owner: agent / `rollback:` `git checkout -- scripts/sync-plugin-plangate.sh`

- [x] **T-03**: 経路2（ai-loop references・L316-329）へ guard 適用
  - `_ai_loop_expected_refs` の要素数（base。`set -- $_ai_loop_expected_refs; _n=$#` — U-2 で安全確認済み）と `PLUGIN_AI_LOOP_REFS` 内の非期待 `*.md` 数（stale）を削除実行前に集計
  - blocked なら削除ループ全体を skip（コピー処理は継続）
  - 🚩 **チェックポイント**: 「正本 2 ディレクトリ両方が空/消失 → 発火 + exit 3」「1 件だけ正当削除 → 非発火で削除実行」を手動再現し、**実行ログを `evidence/verification/` へ保存**（R-308。本経路は「最も危険な silent failure」に該当）してから T-04 へ
  - Owner: agent / `rollback:` `git checkout -- scripts/sync-plugin-plangate.sh`

- [x] **T-04**: 経路1（汎用 references・L173-183）へ guard 適用
  - **集計条件（R-351 / 論点 D'）**: base / stale の集計ループに**コピーループ L163 と同一の** `[ -L "$_rf" ] && continue` を入れる。集計と削除条件が非対称だと「N 件と数えて M 件消す」= #861 再発型の guard 無効化になる
  - blocked なら**当該 skill の references 削除のみ** skip（`break` ではなく他 skill の処理を継続する制御にする）
  - 🚩 **チェックポイント**: 複数 skill のうち 1 つだけ空化した sandbox で、当該 skill のみ保留・他 skill は正常同期。**ログを `evidence/verification/` へ保存**（R-308）
  - Owner: agent / `rollback:` `git checkout -- scripts/sync-plugin-plangate.sh`

- [ ] **T-07**: extras 11 本の判別式統一 + standalone env 無害化
  - 対象: ta-39 / 43 / 44 / 45 / 46 / 47 / 49 / 50 / 51 / 52 / 53
  - `if [ -n "${FIXTURES_DIR:-}" ]; then` → `if [ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]; then`
  - **ta-39 のみ例外（R-350）**: 同ファイルは当該文字列を **2 箇所**持つ（L14 = ROOT 解決 / L55 = apply 未適用時の `return`/`exit` 分岐）。**2 箇所とも AND 条件化**するが、`unset` は **L14 側の else 節にのみ**追加する（L55 側は ROOT 解決ではないため無害化対象外）。他 10 本は 1 箇所のみ（実測確認済み）
  - standalone 分岐（**else 節の内側のみ**）に plan「論点 F の対象 env」の **7 件**を `unset`
  - **`ta-26-plugin-sync.sh` の standalone unset も 7 env へ拡張（RV-M3）**: 現状 `PLANGATE_ALLOW_MASS_DELETE` 1 件のみ（L22 実測）。AC-9 の包含検査は ta-26 も対象なので、拡張しないと TC-33 が自ファイルで落ちる
  - Owner: agent / `rollback:` `git checkout -- tests/extras/`

- [ ] **T-08**: `tests/extras/README.md` の「隔離・後始末の規約（#530）」節へ項目 8 として判別規約を追記
  - 「新規 extras は `PG_HARNESS_SOURCED`（非 export）と `FIXTURES_DIR` の AND で判別する。片方でも欠ければ standalone 側（安全側）へ倒す。standalone 分岐では `PLANGATE_*` / `PG_HARNESS_SOURCED`（7 env）を unset して外部 env 汚染を無害化する」旨
  - **既存規約 7 の是正（RV-m3）**: 規約 7 末尾の「run-tests.sh 冒頭で unset 済みのため extras 側の個別対処は不要」が項目 8 と矛盾する。「harness 実行では unset 済み。standalone 実行はその防御が効かないため項目 8 に従い各 extras が自前で unset する」へ改める（README 1 ファイル内の 1 文修正・ファイル数不変）
  - Owner: agent / `rollback:` `git checkout -- tests/extras/README.md`

### 検証フェーズ

> **T-05 は粒度確保のため 3 分割**（C-1 自己検出: 14 TC を 1 タスクにすると独立検証できない）。共通の実装規約は 3 タスクすべてに適用する:
>
> - ヘルパーは既存 `_t26_mk_guard_sandbox`（L197-215）と同型（引数順・命名・`register_cleanup` パターンを踏襲）
> - sandbox は**最小構成**（`CHANGELOG.md` / `.claude-plugin/marketplace.json` を置かない）
> - rc 捕捉は `_rc=0; _out=$(sh ...) || _rc=$?` の型（`|| true` 直後の `$?` 空振りを書かない）

- [ ] **T-05a**: 経路2 の TC 追加（**TC-20 / 21 / 22 / 23 / 24 / 25**）
  - ヘルパー `_t26_mk_ai_loop_guard_sandbox` を実装。**`scripts/_ai_loop_link_rewrite.py` を必ず同梱**（python3 で可用性ガードなしに呼ばれ、不在だと guard と無関係な理由で異常終了 — R-354）
  - 🚩 **チェックポイント**: TC-20〜TC-25 が全 PASS
  - Owner: agent / `rollback:` `git checkout -- tests/extras/ta-26-plugin-sync.sh`

- [ ] **T-05b**: 経路1 の TC 追加（**TC-26 / 27 / 28 / 29 / 32 / 34**）
  - ヘルパー `_t26_mk_refs_guard_sandbox` を実装（複数 skill を作れる構造にする。TC-26 が skill-A / skill-B を要求）
  - 🚩 **チェックポイント**: TC-26〜TC-29 / TC-32 / TC-34 が全 PASS
  - Owner: agent / `rollback:` `git checkout -- tests/extras/ta-26-plugin-sync.sh`

- [ ] **T-05c**: 静的検査 TC 追加（**TC-30 / TC-33**）
  - TC-33 は **11 という件数をハードコードしない** grep ベース（AC-9）
  - 🚩 **チェックポイント**: TC-30 / TC-33 が PASS。かつ TC-33 が移行前の実装に対して **FAIL する**ことを確認（静的検査の検出力証明）
  - Owner: agent / `rollback:` `git checkout -- tests/extras/ta-26-plugin-sync.sh`

- [ ] **T-06**: **変異注入で新規 TC の検出力を実証**（M-1〜M-7 + M-6b = 計 8 変異）
  - guard 弱体化方向（M-1〜M-5）**および過剰発火 / override 無効化方向（M-6 / M-6b / M-7）**について、対応 TC が **FAIL する**ことを確認（R-305 / RV-M4）
  - ⚠️ **M-6 の対象は TC-24 / TC-29 のみ**（TC-25 / TC-32 は guard 発火帯の fixture なので「常に blocked」でも期待どおり PASS になり、期待 FAIL 不出として RT-3 / Stop Condition 3 を誤発火させる）。閾値の 1 段ずれ（`stale >= base`）は専用 fixture **TC-34** を持つ **M-6b** で突く
  - 変異の復元元は **`git show 90c313d:...`** に固定（`HEAD:` は exec 中に移動する — RV-i1）
  - 🚩 **チェックポイント**: 空振り fixture でないことの証明ログを `evidence/test-runs/` へ保存。FAIL が確認できない TC は設計をやり直す
  - Owner: agent / `rollback:` 不要（検証のみ。stash は必ず復元する）

- [ ] **T-09**: AC-6 / AC-7 / AC-9 の機械検証
  - **AC-6**: V-1-A（clean env ループ）で 3 条件（`[FAIL]` 不在 / exit 0 / `[PASS]` 件数が T-01 baseline と一致）
  - **AC-7**: V-1-B（`FIXTURES_DIR` 漏れ・6 env 注入）+ **V-1-B'**（`PG_HARNESS_SOURCED` 単独漏れ）の 2 ループで AC-6 と同結果。V-1-A の `env -u` を流用しない（R-302）/ AND を両方注入しない（RV-M2）
  - ⚠️ 全ループで **`sh "$f" </dev/null`** と冒頭 `cd "$(git rev-parse --show-toplevel)"` を必須にする（RV-M1 / RV-i1）
  - **AC-9**: `tests/extras/**.sh` に `PG_HARNESS_SOURCED` を伴わない `FIXTURES_DIR` 単独判別が **0 件**（件数ハードコードなし）+ `run-tests.sh` の unset 集合 ⊆ 各 extras の standalone unset 集合
  - 🚩 **チェックポイント**: 検証コマンドを status.md に記録（V-1 で再実行するため）
  - Owner: agent / `rollback:` 不要（検証のみ）

### 完了フェーズ

- [ ] **T-10**: 別 issue 起票 + handoff への妥協点記録（AC-8）
  - 起票内容: extras 11 本の standalone 実行が内部 FAIL を exit code に反映しない（`exit $fail` 相当の欠落）
  - 根拠として「`PLANGATE_HOOK_TASK` 汚染下の ta-39 が **7 件 FAIL**（PASS 1）しつつ exit 0 で通った」実測を添付（follow-up issue 本文に載る数値なので誤値を持ち込まない — RV-m2）
  - issue-governance.md の必須セクション・4 軸ラベルに準拠
  - **handoff.md「妥協点」へ記録（R-309）**: ①同一 11 ファイルを本 PBI と follow-up で 2 回触る代償 ②AC-6 の代理判定が follow-up 完了まで恒久化 → follow-up 完了時に AC-6 を exit code ベースへ戻す旨を V2 候補に明記
  - Owner: agent / `rollback:` 誤起票時は close

- [ ] **T-11**: 回帰フルテスト
  - `sh tests/run-tests.sh` が **444 passed / 0 failed**（430 + 新規 14 TC）
  - `sh -n scripts/sync-plugin-plangate.sh`
  - `bin/plangate doctor --check-settings` PASS（handoff / V-1 の前提条件）
  - 🚩 **チェックポイント**: 全 exit 0。1 件でも FAIL なら該当 Step へ戻る
  - Owner: agent / `rollback:` 不要（検証のみ）

---

## 👤 Human タスク

- [ ] **H-01（C-3 ゲート・T-01 の前）**: plan.md / test-cases.md / review-self.md / review-external.md を確認し三値判断（APPROVE / CONDITIONAL / REJECT）。**high-risk のため autonomous APPROVE 不可**。`bin/plangate approve` は対話 TTY 必須（AI 実行不可）
- [ ] **H-02（C-4 ゲート・PR 作成後）**: GitHub 上でレビュー → APPROVE / REQUEST CHANGES / REJECT。**マージは Human-owned**

---

## 完了条件

- AC-1〜**AC-9** すべて PASS（test-cases.md と突合）
- `sh tests/run-tests.sh` が 0 failed
- 変異注入 **M-1〜M-7 + M-6b（計 8）** で新規 TC（負側・正常系・境界・override）の検出力が実証済み（evidence あり）
- handoff.md 必須 6 要素 + AC-8 のスコープ境界と R-309 の妥協点記録
- `bin/plangate doctor --check-settings` PASS
