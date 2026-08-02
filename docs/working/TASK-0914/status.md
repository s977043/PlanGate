# TASK-0914 作業ステータス

> 最終更新: 2026-08-02 12:50
> 現在フェーズ: exec
> モード: high-risk

## フェーズ履歴

> **日時は `YYYY-MM-DD HH:mm`（分まで）必須**（#463）。日付のみ・時刻欠落は不可。

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ |
|------------------------|---------|------------|
| 2026-07-25 08:30 | A: PBI INPUT | 作成完了（PR #918 で main 実在） |
| 2026-07-25 11:20 | B: plan 生成 | plan/todo/test-cases 生成（C-2 major 7 + River major 4 反映済・C-1 PASS） |
| 2026-08-02 12:40 | C-3 Gate | APPROVED（`approvals/c3.json`・plan_hash 検証済み — オーガナイザー確認） |
| 2026-08-02 12:44 | D: exec 開始 | ブランチ `fix/914-mass-delete-guard` を origin/main `f25ae8b` から作成 |
| 2026-08-02 12:46 | T-01 完了 | baseline 実測（下表）+ 失敗表記統一確認 + AC-7 検出力証明（NG_TOTAL=8） |
| 2026-08-02 12:55 | T-02 完了 🚩 | `_mass_delete_blocked()` 導入 + sync_dir guard 置換。チェックポイント PASS: `sh -n` rc=0 + ta-26 standalone **16 passed / 0 failed**（TC-10 exit 3 = guard_fired 非サブシェル実証） |
| 2026-08-02 13:00 | T-03 完了 🚩 | 経路2（ai-loop references）guard 適用。sandbox 再現 3 系: S1 正本2dir消失=発火+exit3+全残存 / S1b 空化=発火（`[ -d ]` すり抜けなし）/ S2 base=4,stale=1=非発火・削除実行・exit 0。evidence 保存 + ta-26 16/16 維持 + U-2 再確認（`set --` 以降の位置パラメータ使用 0 件） |
| 2026-08-02 13:05 | T-04 完了 🚩 | 経路1（汎用 references）guard 適用（集計に `[ -L ]` 除外 = R-351）。sandbox 再現: S1 複数 skill 中 skill-A のみ空化 → 当該のみ保留・skill-B は正常同期（break 誤用なし）・exit 3 / S2 正常系 非発火・exit 0。ta-26 16/16 維持 + フルスイート **453 passed / 0 failed**（現 main 基点） |
| 2026-08-02 13:17 | T-05a 完了 🚩 | 経路2 TC-20〜25 + `_t26_mk_ai_loop_guard_sandbox`（`_ai_loop_link_rewrite.py` 同梱 = R-354）追加。チェックポイント PASS: clean env + `</dev/null` standalone で **22 passed / 0 failed**（既存 16 + 新規 6 全 PASS）・exit 0。evidence: `evidence/test-runs/t05a-tc20-25-standalone.log` |
| 2026-08-02 13:22 | T-05b 完了 🚩 | 経路1 TC-26〜29/32/34 + `_t26_mk_refs_guard_sandbox`（複数 skill 構成可・skill-B は empty 開始で COPY 実行を継続処理の証拠化 = M-5 検出用）追加。チェックポイント PASS: clean env + `</dev/null` standalone で **28 passed / 0 failed**・exit 0。evidence: `evidence/test-runs/t05b-tc26-34-standalone.log` |
| 2026-08-02 13:30 | T-05c 完了 🚩（RED 実測） | 静的検査 TC-30/TC-33 追加（件数ハードコードなし）。**検出力証明: T-07 前の実装に対し TC-33 が FAIL**（単独判別残存 = 対象 11 本ちょうど + ta-26 の unset 欠落 6 env = RV-M3 レグも発火）。TC-30 も FAIL（README 規約は T-08 で追記 = 実行順変更による想定内 RED）。TC-13 は子プロセスが TC-30/33 FAIL を含むため連鎖 FAIL（原因は静的 TC の RED のみ）。**27 passed / 3 failed**・rc=1。T-07 後に TC-33 → PASS、T-08 後に TC-30/13 → PASS を対比実測する。evidence: `evidence/test-runs/t05c-tc30-33-pre-t07-fail.log` |
| 2026-08-02 13:45 | T-07 完了 🚩 | 11 本の判別式を AND 化（`[ "${PG_HARNESS_SOURCED:-0}" = "1" ] && [ -n "${FIXTURES_DIR:-}" ]`）+ standalone else 節に 7 env unset。ta-39 のみ 2 箇所 AND 化・unset は L14 側のみ（R-350）。ta-26 の standalone unset も 7 env へ拡張（RV-M3）。チェックポイント: ①clean env ループ = **64 PASS / NG 0・per-file 全件 T-01 baseline 一致** ②汚染 env（6 env + `FIXTURES_DIR` 注入・`PG_HARNESS_SOURCED` 非注入）= **64 PASS / NG 0**（T-01 の NG_TOTAL=8 → 0 = AC-7 移行後側成立）③**TC-33 FAIL→PASS 転化を実測**（ta-26 standalone 28 passed / 2 failed。残 FAIL は TC-30 = T-08 待ち + その連鎖 TC-13 のみ）。evidence: `t07-standalone-clean-post.log` / `t07-contaminated-post.log` / `t07-tc33-post-pass.log` |
| 2026-08-02 13:50 | T-08 完了 | `tests/extras/README.md` 規約 8（AND 判別 + 非 export + standalone 側（安全側）+ 7 env unset + TC-33 静的検査の言及）追記 + 規約 7 末尾の 1 文是正（RV-m3: 「extras 側の個別対処は不要」→ harness では unset 済み / standalone は規約 8 で自前 unset）。**TC-30 FAIL→PASS 転化・TC-13 復帰を実測: ta-26 standalone 30 passed / 0 failed・exit 0**（既存 16 + 新規 14 = 30 TC 全 PASS）。フルスイート **467 passed / 0 failed**（= 453 + 14。読み替え後の RT-6 期待値と一致）。evidence: `t08-ta26-all30-pass.log` / `t08-full-suite-467.log` |
| 2026-08-02 14:08 | T-06 完了 🚩 | 変異注入 8 件（M-1〜M-5 弱体化 / M-6・M-6b 過剰発火 / M-7 override 無効化）**すべてで期待 FAIL TC を実測**（下表マトリクス・空振り fixture なし = RT-3 / Stop Condition 3 発火なし）。M-6 下で TC-25/32 の PASS 維持も実測（RV-M4 の対象限定どおり）。各変異とも `git checkout 1e1c074 --` 復元 → diff 空 → ta-26 standalone 30/0 復帰を確認。evidence: `t06-m{1,2,3,4,5,6,6b,7}-*.log` 8 本（変異 diff 断片つき） |

## 全体構成（PR 一覧）

| PR | ブランチ | 状態 |
|----|---------|------|
| （未作成） | fix/914-mass-delete-guard | ローカル（exec 中） |

## T-01: AC-6 baseline 実測（R-301 / U-4）

実測条件: clean env（`env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PG_HARNESS_SOURCED -u FIXTURES_DIR -u PLANGATE_ALLOW_MASS_DELETE`）+ `sh "$f" </dev/null`、cwd = repo root。
実測日時: 2026-08-02 12:45 / head `f25ae8b` / evidence: `evidence/test-runs/t01-baseline-clean.log`

| ファイル | `[PASS]` 件数 (baseline) | rc | `[FAIL]` 行 |
|---------|------------------------|----|------------|
| ta-39-eh3-doc-light.sh | **8** | 0 | 0 |
| ta-43-eh2-strict-json.sh | **6** | 0 | 0 |
| ta-44-eh457-cli-wiring.sh | **5** | 0 | 0 |
| ta-45-c3-mode-config.sh | **6** | 0 | 0 |
| ta-46-ehs-wiring.sh | **4** | 0 | 0 |
| ta-47-ehs23-wiring.sh | **6** | 0 | 0 |
| ta-49-bias-export.sh | **6** | 0 | 0 |
| ta-50-precompact-guard.sh | **9** | 0 | 0 |
| ta-51-doctor-w6.sh | **5** | 0 | 0 |
| ta-52-doctor-skill-collision.sh | **5** | 0 | 0 |
| ta-53-doctor-prepush.sh | **4** | 0 | 0 |
| **計** | **64** | — | — |

- 参考値（River Review 実測 `ta-39=8 ta-43=6 ta-44=5 ta-45=6 ta-46=4 ta-47=6 ta-49=6 ta-50=9 ta-51=5 ta-52=5 ta-53=4` 計 64）と**全件一致**
- **失敗表記の統一（U-4）**: 11 本すべて source 内の失敗マーカーは `[FAIL]`（grep 実測: 各 1〜6 箇所）。`[NG]` / `not ok` / `[ERROR]` 等の別表記は **0 件**（grep rc=1）→ AC-6 条件①の判定語彙拡張は**不要**
- **AC-7 検出力証明（R-302 / RV-M2）**: 移行前に V-1-B 型汚染 env（`PLANGATE_SKIP_REASON/HOOK_TASK/HOOK_FILE/BYPASS_HOOK/HOOK_STRICT/ALLOW_MASS_DELETE` + `FIXTURES_DIR=/nonexistent/fixtures`。`PG_HARNESS_SOURCED` は注入しない）で 11 本実行 → **NG_TOTAL=8**（ta-45/46/47/49/50/51/52/53 が `[FAIL]` を出力）。さらに ta-39/43/44 は `[PASS]`=0（baseline 8/6/5 から消失 = 1 件も実行せず素通り）となり、条件③（件数一致）の検出対象。evidence: `evidence/test-runs/t01-ac7-contaminated-pre.log`
- 全ファイル rc=0 のまま `[FAIL]` が出る = exit code 伝播欠落（AC-8 別 issue の根拠）も同時に再確認

## T-06: 変異注入マトリクス（8 変異 × 期待 FAIL TC × 実測）

実測条件: clean env（`env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PG_HARNESS_SOURCED -u FIXTURES_DIR -u PLANGATE_ALLOW_MASS_DELETE`）+ `sh tests/extras/ta-26-plugin-sync.sh </dev/null`、cwd = repo root。
サイクル: worktree 内で `scripts/sync-plugin-plangate.sh` を直接編集（`sh -n` 確認）→ ta-26 実測 → **`git checkout 1e1c074 -- scripts/sync-plugin-plangate.sh` で復元** → `git diff 1e1c074 -- <file>` 空を確認 → ta-26 standalone 30/0 復帰確認。
（復元元の読み替え: todo.md 記載の `git show 90c313d:` は plan 時点の表記。W1/W2 実装が乗った現在は **W2 完了 head `1e1c074` に固定**する — 90c313d へ戻すと W1/W2 実装が消えるため使わない。オーガナイザー指示）
実測日時: 2026-08-02 13:58〜14:08 / evidence: `evidence/test-runs/t06-m{1,2,3,4,5,6,6b,7}-*.log`（各ファイルに変異 diff 断片・FAIL 行・復元確認を収録）

| 変異 | 内容 | 期待 FAIL TC | 実測（期待分） | 副次 FAIL（実測） | 復元後 |
|------|------|-------------|---------------|------------------|--------|
| M-1 | 経路2 guard 呼び出し削除 | TC-20/21/22 | **全 FAIL** ✓ | TC-23/25（解除ログ・fired 判定の喪失）+ TC-13（子プロセス連鎖） | 30/0 |
| M-2 | 経路1 guard 呼び出し削除 | TC-26/27 | **全 FAIL** ✓ | TC-28/32 + TC-13 | 30/0 |
| M-3 | 閾値 `stale > base+100`（非発火方向） | TC-20/26 | **全 FAIL** ✓ | 3 経路の guard 系 14 TC（TC-08/10/11/12/16/17/21/22/23/25/27/28/32/13）= 共通関数集約の構造どおり全経路へ波及 | 30/0 |
| M-4 | `guard_fired=1` をサブシェル `$( )` 内へ | TC-22/27 | **全 FAIL** ✓ | rc=3 検査系 TC-10/12/16/17/25/32 + TC-13。**TC-20/21/26 は PASS 維持**（WARN・保留は残り exit code のみ失われる = silent failure の症状分離を実証） | 30/0 |
| M-5 | 経路1 blocked 時に skill ループ全体を break | TC-26 | **FAIL** ✓ | TC-13 のみ（TC-27 は PASS 維持 = skill-B 継続同期の検査だけが本変異を検出） | 30/0 |
| M-6 | `_mass_delete_blocked` 常に blocked（過剰発火） | TC-24/29 のみ | **全 FAIL** ✓ | TC-05（実 repo 相当 sandbox の誤発火見張り）/TC-09/TC-34 + TC-13。**TC-25/32 は PASS 維持を実測**（発火帯 fixture のため判定一致のまま = RV-M4 の対象限定判断の妥当性を裏付け・期待 FAIL 不出の誤発火なし） | 30/0 |
| M-6b | 閾値 `stale >= base`（境界 1 段の過剰発火） | TC-34 | **FAIL** ✓ | TC-13 のみ（乖離帯 fixture TC-12/25/32 は PASS 維持 = TC-34 新設理由〔E-3 撤回〕の実証） | 30/0 |
| M-7 | override（`PLANGATE_ALLOW_MASS_DELETE`）判定ブロック削除 | TC-23/28 | **全 FAIL** ✓ | TC-11（sync_dir 経路の既存 override TC）+ TC-13 = override の全経路一貫（AC-4）が共通関数 1 箇所で担保される構造の裏付け | 30/0 |

- 8 変異すべてで期待 FAIL を実測 = **新規 TC は空振り fixture でない**（RT-3 / Stop Condition 3 の発火なし・TC 側の修正不要）
- 全サイクルで復元後 `git diff 1e1c074 -- scripts/sync-plugin-plangate.sh` = 空 + ta-26 standalone **30 passed / 0 failed** 復帰を実測（復元漏れなし）

## 残タスク

- [x] T-01: baseline 実測（2026-08-02 12:46 完了）
- [x] T-02: `_mass_delete_blocked()` 導入 + `sync_dir` guard 置換 🚩（2026-08-02 12:55 完了）
- [x] T-03: 経路2（ai-loop references）guard 適用 🚩（2026-08-02 13:00 完了）
- [x] T-04: 経路1（汎用 references）guard 適用 🚩（2026-08-02 13:05 完了）
- [ ] T-05a/b/c: TC 追加（別ワーカー担当）
- [x] T-06: 変異注入 8 件で検出力実証 🚩（2026-08-02 14:08 完了）
- [ ] T-07: extras 11 本判別式統一 + unset（別ワーカー担当）
- [ ] T-08: README 規約追記（別ワーカー担当）
- [ ] T-09: AC-6/7/9 機械検証（別ワーカー担当）
- [ ] T-10: 別 issue 起票 + handoff 妥協点（別ワーカー担当）
- [ ] T-11: 回帰フルテスト（別ワーカー担当）

## 計画からの変更点

- **T-05c/T-08 の実行順による一時 RED（想定内・解消済み）**: オーガナイザー指示の実行順（T-05a→b→c→T-07→T-08）では、T-05c コミット時点で TC-33（T-07 待ち）と TC-30（T-08 待ち）+ 連鎖 TC-13 が FAIL する（TDD RED。evidence: `t05c-tc30-33-pre-t07-fail.log`）。T-07 後 TC-33 → PASS、T-08 後 TC-30/TC-13 → PASS を対比実測済み。**branch head（T-08 以降）は 467/0 で green**
- **TC-33 のトークン抽出は sed 末尾除去方式**: 実装当初の `case [A-Z]*` によるトークン選別は locale collation 下で `true` 等の小文字にも誤マッチする（実測で混入確認）。`_t26_unset_envs33()`（grep + sed で `unset` / `2>/dev/null` / `|| true` を除去）へ是正
- **test-cases.md V-1-B' スニペットの env 引数順は実行不可（T-09 担当への申し送り）**: `env PG_HARNESS_SOURCED=1 -u FIXTURES_DIR sh "$f"` は BSD/GNU env とも「オプション（-u）は NAME=VALUE 代入より前」の仕様に反し、`-u` 以降が COMMAND 扱いになって **rc=127 で全滅**する（2026-08-02 実測）。正しくは `env -u FIXTURES_DIR PG_HARNESS_SOURCED=1 sh "$f" </dev/null`。同順で 11 本スモーク済み = **64 PASS / NG 0**（evidence: `t07-bprime-smoke-post.log`）
- **ta-26 冒頭の #877 由来方針コメント 1 文を #914 完了形へ是正**（T-07 内）: 「移行と規約追記は follow-up issue で扱う（本 PBI では touch しない）」が本 PBI 完了後に誤読を招くため

- **exec 基点が main `f25ae8b`**（plan 基点 `90c313d` から前進）。`scripts/sync-plugin-plangate.sh` の 90c313d→f25ae8b 差分は **L342 以降（scripts allowlist 節 = 本 PBI Non-goal 領域）のコメント3+2行と集合拡張のみ**で、本 PBI の対象 3 領域（sync_dir guard L103-113 / 経路1 L173-183 / 経路2 L316-329）は**行番号・内容とも 90c313d と同一**（`git diff 90c313d f25ae8b -- scripts/sync-plugin-plangate.sh` で実測）。plan の行番号参照はそのまま有効
- **`tests/extras/ta-57-pr-convergence.sh` が新設**（#941）・ta-56 に 1 行変更 → `sh tests/run-tests.sh` の総数 baseline が 430（90c313d）から **453（f25ae8b + T-02〜T-04 適用後、2026-08-02 13:05 実測・0 failed）** へ増加。**RT-6 / AC-6 / T-11 の期待値は 444 ではなく 467（= 453 + 新規 14 TC）に読み替える**こと（T-02〜T-04 は TC を追加しないため 453 が「移行前」相当の現基点値） |
- 変異注入の復元元 `git show 90c313d:scripts/sync-plugin-plangate.sh`（RV-i1）は、対象 3 領域が同一なため引き続き有効（allowlist 節の差分は変異対象外）

## V 系ステップ進捗

| ステップ | 結果 |
|---------|------|
| L-0 | — |
| V-1 | — |
| V-2 | — |
| V-3 | — |
| V-4 | — |

## 次の作業（Claude Code プロンプト）

TASK-0914 exec 続行。T-02（`_mass_delete_blocked()` 共通関数導入 + sync_dir guard L103-113 置換）→ T-03（経路2 L316-329）→ T-04（経路1 L173-183）を todo.md の指示どおり直列実施。チェックポイントは `sh -n` + ta-26 既存 16 TC 全 PASS（T-02）、sandbox 手動再現ログの evidence 保存（T-03/T-04）。
