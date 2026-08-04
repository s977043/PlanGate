# TASK-0914 作業ステータス

> 最終更新: 2026-08-04 09:55
> 現在フェーズ: **完了（PR #986 マージ済み・merge commit `0ebb8fe` / 2026-08-04T22:18:46Z）**。残るのは follow-up PR（guard コメント是正・鮮度根拠是正・#991 / #994 の記録）を main へ届けること
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
| 2026-08-02 14:15 | T-09 完了 🚩 | AC-6（V-1-A）/ AC-7（V-1-B + V-1-B'）/ AC-9 の機械検証**全 PASS**。V-1-A/B/B' とも **64 PASS・NG 0・per-file baseline（T-01 表）全一致**。AC-9 は TC-33 と独立の grep -L / awk 実装で**単独判別残存 0 + 7 env 包含成立**（対象 12 ファイル = 移行 11 本 + ta-26）。V-1-B' の env 引数順は W2 申し送りの読み替えを採用。検証コマンド全文は下記セクション（V-1 で再実行）。evidence: `t09-v1a-clean.log` / `t09-v1b-contaminated.log` / `t09-v1bprime-single.log` / `t09-ac9-static.log` |
| 2026-08-02 14:25 | T-10 前半（#921 コメント） | issue #921 本文と todo T-10 起票要件を突合（issue-governance 必須セクション = Why/What/AC/Non-goals/Labels/Milestone 全て充足・4 軸ラベルは必須 2 軸 kind=`bug` + `priority:P1` 充足、area/status は任意軸で tests/extras 該当 area ラベルはタクソノミに不存在）→ 欠けていた W1/T-01 実測根拠を**コメント追記**（本文編集なし）: ①汚染 env 下 8 ファイルが `[FAIL]` 4〜9 行を出しつつ全 11 本 rc=0（NG_TOTAL=8）②ta-39/43/44 は `[PASS]`=0（baseline 8/6/5）= 1 件も実行せず exit 0 素通り ③#914 完了で AND 化済み・残るは exit code 伝播のみのスコープ境界 + `Refs #914`。URL: <https://github.com/s977043/PlanGate/issues/921#issuecomment-5155633541> |
| 2026-08-02 14:30 | T-11 完了 🚩 | 回帰フルテスト（clean env + `</dev/null`）**467 passed / 0 failed・rc=0**（= 453 + 新規 14。worktree + トピックブランチの期待値どおり: ta-13 TC-17 の worktree 素通り #947 と ta-57 TC-14 のトピックブランチ実行 +1 が相殺）+ `sh -n scripts/sync-plugin-plangate.sh` rc=0 + ta-26 standalone **30 passed / 0 failed・rc=0**。`bin/plangate doctor --check-settings` は worktree 内 **FAIL**（gitignored `.claude/settings.json` が worktree に複製されない構造要因。main checkout には 2026-07-23 適用の settings.json 実在を確認 = Shadow Config ではなく worktree 制約）→ **Human 待ち事項: V-1 前に main checkout で PASS 実測**。evidence: `t11-full-suite-clean.log` / `t11-ta26-standalone.log` |
| 2026-08-02 14:45 | T-10 完了 + handoff 起草 | `handoff.md` 起草（必須 6 要素 + **R-309 妥協点 2 点**〔①同一 11 ファイルを本 PBI と #921 で 2 回触る代償 ②AC-6 代理判定が #921 完了まで恒久化 → V2 候補 High「exit code ベースへ戻す」を明記〕+ **V-1 結果欄はプレースホルダ**・frontmatter `status: draft` = V-1 PASS 後に final 化）→ AC-8 成果物確定・T-10 完了。INDEX.md / current-state.md を「exec 完了・V-1 待ち」へ更新 |
| 2026-08-02 14:50 | L-0 相当 完了 | 本ブランチ変更 `.md` 6 本（status / todo / INDEX / current-state / handoff / tests/extras/README）へ `npx markdownlint-cli2` → 検出 8 件（handoff MD018 ×1 = 起草分の行頭 `#877` 見出し誤認 / README MD031 ×6 + MD012 ×1 = うち 2 件は W2 追記ブロック・5 件は main 既存）を**全て修正**（抑制なし・whitespace のみ・内容不変）→ 再実行 **0 issues**。README は TC-30/TC-13 の検査対象のため ta-26 standalone を再実測 **30/0** + 最終 tree でフルスイート再実測 **467 passed / 0 failed**（テストした tree = 出荷 tree を保証。PASS のため evidence 省略・ta-26 の evidence ログは再実行で更新） |
| 2026-08-02 15:26 | #970 起票（PR 前 River Review F-1） | branch diff への PR 前 River Review 指摘 F-1（経路1 stale 集計が dst 側 symlink を除外し削除ループと非対称・実測再現付き）を **#970** として起票（bug / priority:P2）。C-3 plan_hash 束縛下の設計残穴（test-cases E-7 の残穴確定）のため follow-up 化。現リポジトリの該当 references/ に symlink 0 件で顕在化しない |
| 2026-08-04 09:34 | 再開: F-2 解消 | Human 発行済み c3.json（2026-08-02T03:37:59Z・CLI）を並行セッションの `git stash push -u` 退避から `stash@{0}^3` 非破壊抽出し、コミット `fb443e8` で tracked 化（River Review F-2 解消。教訓: 承認トークンは発行直後に tracked 化） |
| 2026-08-04 09:48 | freshness 再確認（F-4） | main 前進 `f25ae8b` → `7bf5f5c` の変更 65 ファイルとブランチ接触 48 ファイルの交差 **0** を再実測（直近前進 = #972 dependabot workflows bump + #971 TASK-0874 plan。クリーンマージ見込み維持。マージ後のフルスイート総数は main 側変動で 467 から変わりうる）。**⚠️ 2026-08-05 是正: この「交差 0」を鮮度根拠とする論法は誤り**（AC-9 は全体不変条件のため交差 0 でも破れる。実際 ta-58/#967 と ta-59/#976 の追加で破れ CI 2 failed 化した — 2026-08-05 行） |
| 2026-08-05 07:05 | **鮮度根拠の是正 + CI 2 failed の解消（PR #986）** | **F-4 の「接触ファイル交差 0」を鮮度根拠とする論法を撤回**。AC-9 はリポジトリ全体の不変条件であり、main が無関係な extras を 1 本追加するだけで破れる ＝ **全体量化子を含む AC の鮮度は接触ファイル交差では担保できない。base 更新のたびに機械ゲートを再実行して判定する必要がある**。実害: main へ ta-58（`c25c022`/#967）と ta-59（`a667c0d`/#976）が入り、交差 0 のまま AC-9 が破れて PR #986 が CI 2 failed（ta-26 TC-33 / TC-13）となった。是正 3 点: ①ta-26 TC-33 のパーサを awk で行継続結合してから走査（旧実装は `grep '^\s*unset '` 直接のため ta-60 の複数行 `unset` の 2 行目以降が不可視 + 末尾 `\` を env 名として収集 = false positive。ta-60 は 7 env すべて unset 済みで修正不要）②ta-58 を AND 判別 + 7 env unset + standalone fallback（`pass`/`fail`/`register_cleanup` + 末尾 drain・サマリ・exit code）へ移行（真の未移行。fallback 前は FAIL があっても exit 0 で素通り）③`scripts/sync-plugin-plangate.sh` 経路2 コメントを保証範囲どおりに是正（挙動不変）。実測: フルスイート **538〜539 passed / 0 failed・rc=0**（TC-13 / TC-33 含む。3 者独立実測で 0 failed 一致・総数のみ worktree 538 / primary checkout 539 に振れる = #947 の環境依存変動の再現）/ ta-26 standalone **30/0・rc=0** / ta-58 standalone **40/0・rc=0**（変異注入時 39/1・**rc=1**。修正前 HEAD 版は同変異で 1 FAIL でも rc=0 = 検出力の対比実証） |
| 2026-08-05 07:18 | **C-4 APPROVE + マージ（PR #986）** | Human（s977043）が head `7dad6dd`（CI 全 11 チェック pass / `sync` のみ skipping）でマージ。merge commit **`0ebb8fe`**（2026-08-04T22:18:46Z UTC）。handoff frontmatter `v1_release` に記入済み。**V-2 / V-3 は high-risk のため本来必須だったが実施前にマージされた**（事実として記録・handoff §5） |
| 2026-08-05 07:20 | ⚠️ 反映コミットが main に届かず | 上記マージの 2 分後に作成したレビュー反映コミット `77c1319`（guard コメント是正 / handoff §2 / 鮮度根拠 / #991）を **closed 済みの PR ブランチへ push** したため main に入らなかった。**closed PR は head 更新も CI 実行も行わない**（remote ref は `77c1319` へ進むが PR API の `head.sha` は `7dad6dd` のまま・check-runs 0 件 — 実測）。→ `docs/914-guard-scope-followup` へ cherry-pick（`ee3ac9a`）し follow-up PR で main へ届ける |
| 2026-08-05 07:40 | follow-up 整備 | #994 起票（**TC-33 検査 (1) が移行済みファイルに対し空振り** — 判別行のみの差し戻し変異を検出できないことを sandbox 実測で確定）→ handoff §2 に major として追記。あわせて `v1_release` 記入・「PR 未作成」stale の是正・本履歴行の時刻欠落（#463 規約）是正 |
| 2026-08-05 07:37 | **C-3' 裁定（ai-loop run-026）→ HUMAN_ESCALATED** | follow-up 変更（`ee3ac9a` / 4 ファイル）へ `/ai-loop-cycle` を適用。**W チェック 2 体とも approve**（Model A = 設計妥当性 / Model B = adversarial。両者が独立 sandbox で guard の双方向挙動〔少数側欠損 base16/stale7 → WARN なし削除 / 多数側欠損 base7/stale16 → `DELETE skipped`〕を再現し、コメント記述との一致を確認。非コメント行 md5 一致で挙動不変も裏取り）。`boundary_check=clean`（HO 21 パターン + 判定基盤 carve-out に非接触）/ `scope_check=in_scope`。**`arbiter.py` exit 2 = HUMAN_ESCALATED / priority 1.7**（`gates.c1=NOT_EXECUTED`。本変更は #986 の後続是正で PBI 化しておらず C-1 未実施）。`lite_check=false`（実 4 ファイル > `SIZE_OK_MAX_FILES`=2 のため `size_ok` は虚偽申告せず false）。record = `docs/working/ai-loop-runs/20260804T223729Z-ee3ac9a-run026.json`（audit record） |
| 2026-08-05 07:45 | **Human C-3 APPROVED（条件付き）** | escalate 内容を提示し Human が「瑕疵 3 件を是正のうえ承認 → PR」を選択。Model B 検出の瑕疵を是正: ①基点 `be53897` は `ee3ac9a` の祖先でない（squash 前ブランチ状態）→ main 起点の再現基点 `0ebb8fe` へ差し替え ②総数 `538` を `538〜539`（worktree / primary checkout の #947 環境依存変動）へ是正し 3 者独立実測の「0 failed 一致」を明記 ③「PR 未作成」stale・`status: final` 自己矛盾（並行セッションが同一作業ツリーで是正済みのため取り込み） |
| 2026-08-04 09:55 | handoff 内容確定 | §1 に V-1 独立検査（acceptance-tester・2026-08-02 実施）の結果を転記し確定: **総合 条件付き PASS**（条件 = doctor --check-settings PASS 待ちのみ・テストケース側 FAIL 0・AC-1〜9 全 PASS・WARN 2 件〔V-1-C 字句は等価記述で充足 / 変異 M 系は evidence-based〕）。§2 に River Review disposition（#970 / ta-54 `\|\| true` 対象外判断 / `stale == base` 境界仕様 / F-5 対処不要 / F-4 鮮度）、§5 に c3.json 顛末 + 残る完了条件を追記。`status: draft` は doctor 待ちのため維持 |

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

## T-09: AC-6 / AC-7 / AC-9 機械検証（検証コマンド全文 / V-1 再実行用）

実測日時: 2026-08-02 14:09〜14:15 / 実装は head `1e1c074` から不変 / いずれも repo root から `sh <スクリプト>` で実行（コピペで動く自己判定つき・最終行が `PASS`/`FAIL`）。
結果: **V-1-A / V-1-B / V-1-B' = 64 PASS・NG_TOTAL 0・per-file baseline（T-01 表）全一致 / AC-9 = 単独判別残存 0 + unset 包含成立** → AC-6 / AC-7 / AC-9 すべて PASS。
evidence: `evidence/test-runs/t09-v1a-clean.log` / `t09-v1b-contaminated.log` / `t09-v1bprime-single.log` / `t09-ac9-static.log`

> **V-1-B' の env 引数順**は「計画からの変更点」の W2 申し送りどおり **`env -u FIXTURES_DIR PG_HARNESS_SOURCED=1 sh "$f" </dev/null`** を採用（test-cases.md 記載の `env PG_HARNESS_SOURCED=1 -u FIXTURES_DIR` は BSD/GNU env の仕様〔オプションは NAME=VALUE 代入より前〕に反し rc=127 で実行不可 — W2/T-09 とも実測）。

### V-1-A: AC-6 — clean env ループ（3 条件 + per-file baseline 照合）

```sh
#!/bin/sh
# T-09 V-1-A: AC-6 — clean env での standalone 実行（3 条件 + baseline 照合を自己判定）
cd "$(git rev-parse --show-toplevel)"
ng=0
total=0
expected="tests/extras/ta-39-eh3-doc-light.sh=8 tests/extras/ta-43-eh2-strict-json.sh=6 tests/extras/ta-44-eh457-cli-wiring.sh=5 tests/extras/ta-45-c3-mode-config.sh=6 tests/extras/ta-46-ehs-wiring.sh=4 tests/extras/ta-47-ehs23-wiring.sh=6 tests/extras/ta-49-bias-export.sh=6 tests/extras/ta-50-precompact-guard.sh=9 tests/extras/ta-51-doctor-w6.sh=5 tests/extras/ta-52-doctor-skill-collision.sh=5 tests/extras/ta-53-doctor-prepush.sh=4"
for f in tests/extras/ta-39-*.sh tests/extras/ta-43-*.sh tests/extras/ta-44-*.sh \
         tests/extras/ta-45-*.sh tests/extras/ta-46-*.sh tests/extras/ta-47-*.sh \
         tests/extras/ta-49-*.sh tests/extras/ta-50-*.sh tests/extras/ta-51-*.sh \
         tests/extras/ta-52-*.sh tests/extras/ta-53-*.sh; do
  out=$(env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PG_HARNESS_SOURCED \
            -u FIXTURES_DIR -u PLANGATE_ALLOW_MASS_DELETE sh "$f" </dev/null 2>&1); rc=$?
  n_pass=$(printf '%s\n' "$out" | grep -c '\[PASS\]' || true)
  case "$out" in *"[FAIL]"*) echo "NG(FAIL detected): $f"; ng=$((ng+1));; esac   # 条件①
  [ "$rc" = "0" ] || { echo "NG(rc=$rc): $f"; ng=$((ng+1)); }                     # 条件②
  case " $expected " in                                                            # 条件③ per-file baseline
    *" $f=$n_pass "*) : ;;
    *) echo "NG(baseline mismatch): $f=$n_pass"; ng=$((ng+1)) ;;
  esac
  total=$((total+n_pass))
  echo "COUNT $f=$n_pass"
done
echo "TOTAL_PASS=$total NG_TOTAL=$ng"
if [ "$ng" = "0" ] && [ "$total" = "64" ]; then echo "V-1-A: PASS"; else echo "V-1-A: FAIL"; exit 1; fi
```

実測結果: `TOTAL_PASS=64 NG_TOTAL=0` / `V-1-A: PASS` / rc=0（COUNT 全 11 行が T-01 baseline と一致）

### V-1-B: AC-7 — 汚染 env ループ（6 env + `FIXTURES_DIR` 注入・`PG_HARNESS_SOURCED` 非注入）

```sh
#!/bin/sh
# T-09 V-1-B: AC-7 — 汚染 env（6 env + FIXTURES_DIR 注入・PG_HARNESS_SOURCED 非注入）での standalone 実行
# V-1-A の env -u を流用しない独立ループ（R-302）/ AND 両側を同時注入しない（RV-M2）
cd "$(git rev-parse --show-toplevel)"
ng=0
total=0
expected="tests/extras/ta-39-eh3-doc-light.sh=8 tests/extras/ta-43-eh2-strict-json.sh=6 tests/extras/ta-44-eh457-cli-wiring.sh=5 tests/extras/ta-45-c3-mode-config.sh=6 tests/extras/ta-46-ehs-wiring.sh=4 tests/extras/ta-47-ehs23-wiring.sh=6 tests/extras/ta-49-bias-export.sh=6 tests/extras/ta-50-precompact-guard.sh=9 tests/extras/ta-51-doctor-w6.sh=5 tests/extras/ta-52-doctor-skill-collision.sh=5 tests/extras/ta-53-doctor-prepush.sh=4"
for f in tests/extras/ta-39-*.sh tests/extras/ta-43-*.sh tests/extras/ta-44-*.sh \
         tests/extras/ta-45-*.sh tests/extras/ta-46-*.sh tests/extras/ta-47-*.sh \
         tests/extras/ta-49-*.sh tests/extras/ta-50-*.sh tests/extras/ta-51-*.sh \
         tests/extras/ta-52-*.sh tests/extras/ta-53-*.sh; do
  out=$(env PLANGATE_SKIP_REASON=x PLANGATE_HOOK_TASK=TASK-9999 \
            PLANGATE_HOOK_FILE=/nonexistent/x.md PLANGATE_BYPASS_HOOK=1 \
            PLANGATE_HOOK_STRICT=1 PLANGATE_ALLOW_MASS_DELETE=1 \
            FIXTURES_DIR=/nonexistent/fixtures sh "$f" </dev/null 2>&1); rc=$?
  n_pass=$(printf '%s\n' "$out" | grep -c '\[PASS\]' || true)
  case "$out" in *"[FAIL]"*) echo "NG(FAIL detected): $f"; ng=$((ng+1));; esac   # 条件①
  [ "$rc" = "0" ] || { echo "NG(rc=$rc): $f"; ng=$((ng+1)); }                     # 条件②
  case " $expected " in                                                            # 条件③ per-file baseline
    *" $f=$n_pass "*) : ;;
    *) echo "NG(baseline mismatch): $f=$n_pass"; ng=$((ng+1)) ;;
  esac
  total=$((total+n_pass))
  echo "COUNT $f=$n_pass"
done
echo "TOTAL_PASS=$total NG_TOTAL=$ng"
if [ "$ng" = "0" ] && [ "$total" = "64" ]; then echo "V-1-B: PASS"; else echo "V-1-B: FAIL"; exit 1; fi
```

実測結果: `TOTAL_PASS=64 NG_TOTAL=0` / `V-1-B: PASS` / rc=0（T-01 の移行前 NG_TOTAL=8 → 0 = AC-7 成立の再確認）

### V-1-B': AC-7 — `PG_HARNESS_SOURCED` 単独漏れループ（第 3 ループ / RV-M2）

```sh
#!/bin/sh
# T-09 V-1-B': AC-7 — PG_HARNESS_SOURCED 単独漏れ（第 3 ループ / RV-M2）
# env 引数順は W2 申し送りの正しい形（オプション -u は NAME=VALUE 代入より前）:
#   env -u FIXTURES_DIR PG_HARNESS_SOURCED=1 sh "$f" </dev/null
cd "$(git rev-parse --show-toplevel)"
ng=0
total=0
expected="tests/extras/ta-39-eh3-doc-light.sh=8 tests/extras/ta-43-eh2-strict-json.sh=6 tests/extras/ta-44-eh457-cli-wiring.sh=5 tests/extras/ta-45-c3-mode-config.sh=6 tests/extras/ta-46-ehs-wiring.sh=4 tests/extras/ta-47-ehs23-wiring.sh=6 tests/extras/ta-49-bias-export.sh=6 tests/extras/ta-50-precompact-guard.sh=9 tests/extras/ta-51-doctor-w6.sh=5 tests/extras/ta-52-doctor-skill-collision.sh=5 tests/extras/ta-53-doctor-prepush.sh=4"
for f in tests/extras/ta-39-*.sh tests/extras/ta-43-*.sh tests/extras/ta-44-*.sh \
         tests/extras/ta-45-*.sh tests/extras/ta-46-*.sh tests/extras/ta-47-*.sh \
         tests/extras/ta-49-*.sh tests/extras/ta-50-*.sh tests/extras/ta-51-*.sh \
         tests/extras/ta-52-*.sh tests/extras/ta-53-*.sh; do
  out=$(env -u FIXTURES_DIR PG_HARNESS_SOURCED=1 sh "$f" </dev/null 2>&1); rc=$?
  n_pass=$(printf '%s\n' "$out" | grep -c '\[PASS\]' || true)
  case "$out" in *"[FAIL]"*) echo "NG(FAIL detected): $f"; ng=$((ng+1));; esac   # 条件①
  [ "$rc" = "0" ] || { echo "NG(rc=$rc): $f"; ng=$((ng+1)); }                     # 条件②
  case " $expected " in                                                            # 条件③ per-file baseline
    *" $f=$n_pass "*) : ;;
    *) echo "NG(baseline mismatch): $f=$n_pass"; ng=$((ng+1)) ;;
  esac
  total=$((total+n_pass))
  echo "COUNT $f=$n_pass"
done
echo "TOTAL_PASS=$total NG_TOTAL=$ng"
if [ "$ng" = "0" ] && [ "$total" = "64" ]; then echo "V-1-B': PASS"; else echo "V-1-B': FAIL"; exit 1; fi
```

実測結果: `TOTAL_PASS=64 NG_TOTAL=0` / `V-1-B': PASS` / rc=0（AND 片側欠けで standalone 側〔安全側〕へ倒れることの回帰確認）

### AC-9: 静的検査の独立再実測（TC-33 と別実装・件数ハードコードなし）

```sh
#!/bin/sh
# T-09 AC-9: 静的検査の独立再実測（TC-33 とは別実装 = grep -L / awk 方式・件数ハードコードなし）
cd "$(git rev-parse --show-toplevel)"
fail=0

echo "== (1) PG_HARNESS_SOURCED を伴わない FIXTURES_DIR 単独判別の残存 =="
viol=$(grep -l 'FIXTURES_DIR:-' tests/extras/ta-*.sh | xargs grep -L 'PG_HARNESS_SOURCED')
if [ -z "$viol" ]; then
  echo "残存 0 件: OK"
else
  echo "残存あり: $viol"
  fail=1
fi
echo "検査対象（FIXTURES_DIR:- を含む extras）:"
grep -l 'FIXTURES_DIR:-' tests/extras/ta-*.sh

echo "== (2) run-tests.sh の unset 集合 <= 各 extras の standalone unset 集合 =="
# unset 行の抽出は「行頭第 1 フィールドが unset」の awk（コメント行の 'unset' 言及を拾わない・
# TC-33 の grep+sed 実装とは独立）。リダイレクト/演算子以降のトークンは打ち切る。
extract_unset() {
  awk '$1 == "unset" { for (i = 2; i <= NF; i++) { if ($i ~ /^2>/ || $i == "||") break; print $i } }' "$1"
}
hset=$(extract_unset tests/run-tests.sh | sort -u | tr '\n' ' ')
echo "harness unset 集合: $hset"
[ -n "$hset" ] || { echo "NG: harness 集合が空"; fail=1; }
missing=0
for f in $(grep -l 'FIXTURES_DIR:-' tests/extras/ta-*.sh); do
  fset=" $(extract_unset "$f" | sort -u | tr '\n' ' ') "
  for e in $hset; do
    case "$fset" in
      *" $e "*) : ;;
      *) echo "MISSING $f:$e"; missing=$((missing+1)) ;;
    esac
  done
done
if [ "$missing" = "0" ]; then echo "包含成立（欠落 0）: OK"; else echo "欠落 $missing 件"; fail=1; fi

if [ "$fail" = "0" ]; then echo "AC-9: PASS"; else echo "AC-9: FAIL"; exit 1; fi
```

実測結果（2026-08-02・基点 `f25ae8b`）: 残存 **0 件** / 検査対象 **12 ファイル**（ta-26 + 移行 11 本 = `FIXTURES_DIR:-` を含む全 extras、件数はハードコードせず列挙で確認。**2026-08-05・ta-58 移行後の再実測（main 起点 `0ebb8fe`）= 検査対象 15 ファイル・残存 0**（3 者独立実測で一致）。対象数は main 前進で増えるため契約値にしない）/ harness unset 集合 = **7 env**（`PG_HARNESS_SOURCED PLANGATE_ALLOW_MASS_DELETE PLANGATE_BYPASS_HOOK PLANGATE_HOOK_FILE PLANGATE_HOOK_STRICT PLANGATE_HOOK_TASK PLANGATE_SKIP_REASON` = plan 論点 F と一致）/ 包含欠落 **0** / `AC-9: PASS` / rc=0

## 残タスク

- [x] T-01: baseline 実測（2026-08-02 12:46 完了）
- [x] T-02: `_mass_delete_blocked()` 導入 + `sync_dir` guard 置換 🚩（2026-08-02 12:55 完了）
- [x] T-03: 経路2（ai-loop references）guard 適用 🚩（2026-08-02 13:00 完了）
- [x] T-04: 経路1（汎用 references）guard 適用 🚩（2026-08-02 13:05 完了）
- [x] T-05a/b/c: TC 追加 🚩（2026-08-02 13:17 / 13:22 / 13:30 完了 — フェーズ履歴参照）
- [x] T-06: 変異注入 8 件で検出力実証 🚩（2026-08-02 14:08 完了）
- [x] T-07: extras 11 本判別式統一 + unset 🚩（2026-08-02 13:45 完了）
- [x] T-08: README 規約追記（2026-08-02 13:50 完了）
- [x] T-09: AC-6/7/9 機械検証 🚩（2026-08-02 14:15 完了）
- [x] T-10: 別 issue 起票（→ #921 コメント追記へ読み替え・2026-08-02 14:25）+ handoff 妥協点記録（2026-08-02 14:45 完了）
- [x] T-11: 回帰フルテスト 🚩（2026-08-02 14:30 完了）

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
| L-0 | ✅ markdownlint-cli2 **0 issues**（変更 .md 6 本・違反 8 件を修正で解消・2026-08-02 14:50） |
| V-1 | ✅ 条件付き PASS（acceptance-tester 独立検査 2026-08-02。テストケース側 FAIL 0・WARN 2。残条件 = doctor --check-settings PASS の Human 実測のみ → 充足後に handoff `status: final` 化。結果は handoff §1 に転記済み 2026-08-04） |
| V-2 | ⬜（high-risk のため必須） |
| V-3 | ⬜（high-risk のため必須） |
| V-4 | —（critical のみ・対象外） |

## 次の作業（Claude Code プロンプト）

TASK-0914 は exec 完了 + **V-1 条件付き PASS**（acceptance-tester 独立検査 2026-08-02・テストケース側 FAIL 0・WARN 2）+ **handoff 確定・final 化済み**（2026-08-04）+ **2026-08-05 に鮮度根拠是正 + CI 2 failed 解消**（フルスイート 0 failed を 3 者独立実測。総数は 538〜539 で環境依存に振れる）。**[PR #986](https://github.com/s977043/PlanGate/pull/986) は 2026-08-04T22:18:46Z に C-4 APPROVE + マージ済み**（merge commit `0ebb8fe` / by s977043 / head `7dad6dd`・CI 全 pass）。①〜④（apply 実行 → doctor PASS → final 化 → PR 作成 → C-4）はすべて消化済み。**V-2 / V-3 は high-risk のため本来必須だったが実施前にマージされた**（handoff §5 に事実として記録）。残タスクは follow-up PR（本ファイルを含む鮮度根拠是正・guard コメント是正・#991 / #994 の記録）を main へ届けること — マージ直後に作った反映コミットが **closed 済み PR ブランチへ push されたため main に入らなかった**（closed PR は head 更新も CI も走らない）。**鮮度判定は接触ファイル交差ではなく、base 更新のたびに `sh tests/run-tests.sh` と AC-9 静的検査を再実行した実測 rc / 件数で行うこと**（交差 0 は「テキスト衝突が起きない」ことしか意味せず、全体不変条件の保存を意味しない — 2026-08-05 行）。
