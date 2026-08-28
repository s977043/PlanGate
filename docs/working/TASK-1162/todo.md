# EXECUTION TODO — TASK-1162 (#1162 / PBI-A)

> Mode: **high-risk** → 実装タスクは `rollback:` **必須**。
> 順序制約: **H-00 → T-00（plan → C-1 → C-2）→ H-01（C-3）→ S-1-a → S-1-b → S-1-c → S-3 → 完了**。
> L-0 / V-1〜V-3 / **PR 作成（commit / push を含む）** は `workflow-conductor` が自動制御する
> ため本 ToDo には含めない。
>
> **実装タスク数**: T-01〜T-12 の **12**（`H-*` と `T-00*` はワークフロー工程であり
> 実装タスクとして数えない。pbi-input の Mode 判定の「タスク数（見込み）」と一致）。
>
> **ゲート順序の設計**: `bin/plangate exec` は APPROVED な `approvals/c3.json`（**確定後 plan の
> `plan_hash`**）を要求し、**承認後に plan を編集すると EH-3 が mismatch を検知する**。
> したがって **plan.md の生成と C-1 / C-2 は実装タスクより前**に置き、C-3 承認後は plan を編集しない。

## 👤 Human タスク（起点）

- [ ] **H-00**（**すべての起点** / env 設定）`PLANGATE_HOOK_TASK=TASK-1162` を設定した状態で
  セッションを起動する
  - ⚠️ `PLANGATE_HOOK_TASK` は**セッション起動時に固定**され、**実行中の `export` では効かない**
    （実測）。未設定だと EH-3（`scripts/hooks/check-plan-hash.sh`）が `plan.md` の新規作成を
    **rc=2 で BLOCK** する
  - ⚠️ **AI は自セッションの起動時 env を設定できない**ため本タスクは Owner=human 固定
  - 完了条件: 起動後のセッションで `printenv PLANGATE_HOOK_TASK` が `TASK-1162` を返す
  - depends_on: なし / Owner: **human**

## 🤖 Agent タスク

### T-00: Plan Package の確定（**すべての実装タスクの前**）

- [ ] **T-00a** `plan.md` を生成する
  - 記載必須: Goal / Constraints / Non-goals / Approach / Work Breakdown /
    Files to Touch / Testing Strategy / Risks & Mitigations / Questions / Mode 判定
  - 記載必須（本 PBI 固有）:
    - **AC-06 の運用解釈**（時間予算 1,800 秒 / **変更後・baseline のどちらが TIMEOUT でも
      WARN＝未検証**として扱う / pass 件数は下限比較）
    - **AC-07 の 3 要素**（実施可否の明示・実測値・`tests/hooks/run-tests.sh` への参照）
    - **U-01: sandbox harness の確定仕様**（`pass` / `fail` / `FIXTURES_DIR` /
      `register_cleanup` / 配置位置 `$SBX/tests/`）
    - **U-02: 置換後の FAIL / PASS メッセージ書式**（`[FAIL] TA-33 TC-01` /
      `[PASS] TA-33 TC-01` の prefix は維持 ＋ **PASS 側へ実測件数を埋め込む**）
    - **D-2 / D-3 の選択肢**を「本 PBI では実施しない」前提の選択肢として提示
  - depends_on: **H-00** / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1162/plan.md`（未 commit なら削除）
- [ ] **T-00b** C-1 セルフレビュー（17 項目）を実施し `review-self.md` を出力
  - 🚩 判定が FAIL なら plan を修正して再実行。**PASS / WARN になるまで C-3 へ上げない**
  - depends_on: T-00a / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1162/review-self.md`
- [ ] **T-00c** C-2 外部 AI レビュー（high-risk mode で必須）→ `review-external.md`
  - 指摘は `R-NNN` で採番。**指摘ゼロでも「指摘なし」を明示記録**する
  - 実行不可（CLI 未導入 / quota 超過等）の場合は `unavailable` として理由・代替観点・
    未充足リスクを記録する（空欄にしない）
  - 反映は **1 回だけ確定**（反映コミットに `Refs: R-NNN`）→ 簡易 C-1 再実行 →
    その**後**で人間が `c3.json` を発行（順序を逆にすると EH-3 が mismatch を検知する）
  - depends_on: T-00b / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1162/review-external.md`

> **⛔ ここで H-01（C-3）を通すまで、以降のタスクに着手しない。**

### 準備

- [ ] **T-01** 変更前 baseline の実測 ＋ **extras 起動 harness の作成** ＋ 現状条件の一次照合
  - **harness の要件**（sandbox 内に作る。`tests/` 原本には追加しない）:
    1. `pass=0` / `fail=0` を初期化する
    2. **`FIXTURES_DIR="$SBX/tests/fixtures"` を定義**する
       （`ta-57:36` が `$FIXTURES_DIR/../..` で repo root を導出するため。**`$0` 由来ではない**）
    3. **`register_cleanup()` を定義**する（**実呼び出しは `ta-57:45` のみ**。`:32` と `:667` は
       コメント行。未定義だと `:45` で `command not found` となり以降が壊れる）
    4. **harness を `$SBX/tests/` 直下に置き**、`sh $SBX/tests/<harness>.sh` で起動する
       （`ta-33:7` が `dirname -- "$0"/..` で root を導出するため。この位置でのみ
       `_t33_root` が `$SBX` に解決する）
    5. 対象スイートを **`.`（source）**で読み込む
    6. 末尾で `[ "$fail" -eq 0 ] || exit 1`（ただし**判定は rc ではなく出力行**で行う）
  - **一次照合（読取のみ）**:
    - `ta-33` の期待集合（`_t33_sonnet_set` / `_t33_expect_low` / `_t33_expect_medium`）と
      現ファイル集合の突合。`_t33_expect_low`(6) + `_t33_expect_medium`(11) = 17 を確認
    - `ta-57:622` が**既に 3 条件**（`rc=0` && `^OK` && `-eq 57`）であることを確認し、
      S-1-c の**条件式の**変更が **`-eq`→`-ge` の 1 箇所のみ**であることを確定する
    - **PASS 行がリテラルであることの確認**: `ta-33:26`（`（17 体）`）/ `ta-57:623`
      （`Ran 57 tests`）に実測値が入っていないこと。S-1-a / S-1-c で埋め込む対象を確定する
  - **baseline 内容**: `ta-33` / `ta-57` の TC ごとの PASS / FAIL 一覧（test-cases P-1 の
    判定規則で取得。**`> log 2>&1` 必須**）、`python3 scripts/ai-loop/test_delivery.py` の
    `Ran N tests`、`sh tests/run-tests.sh` の pass 件数（**timeout 1,800 秒**）
  - ⚠️ **baseline 側が TIMEOUT（rc=124）した場合**: `TIMEOUT`＝未検証として記録し、
    AC-06 は最終的に **WARN** とする。「変更後だけ完走したから PASS」とは書かない（R-07）
  - 🚩 baseline は**測定日時・ホスト・HEAD SHA とセット**で `evidence/baseline/` に記録する
  - depends_on: H-01 / Owner: agent / rollback: 不要（読取のみ。harness は sandbox 内）
- [ ] **T-02** `decision-log.jsonl` を初期化し、C-3 で確定した D-1〜D-3 の判断を追記
  - ⚠️ 本 PBI 開始時点で `docs/working/TASK-1162/decision-log.jsonl` は**存在しない**（実測）。
    **初期化と追記を本タスク内で連続実行**する（初期化タスクを別に切らない）
  - 以降の判断（変異の空振り / U-02 の書式決定 / S-3 判断）も本ファイルへ append する
  - depends_on: **H-01**（C-3 の判断結果が入力）/ Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1162/decision-log.jsonl`（未 commit なら削除）

### 実装（S-1: 件数契約の置換）

- [ ] **T-03**（RED）`ta-33` / `ta-57` の**変異注入 sandbox** を用意し、現状の assert が
  「増加で FAIL する（＝時限爆弾である）」ことを実証
  - 🚩 agent を **md + toml の両側で** 1 体増やした sandbox で現状 `ta-33` TC-01 が
    **FAIL** すること（片側だけ増やすと TC-04 が drift FAIL して判定が混ざる）
  - 🚩 `test_delivery.py` にテストを 1 本足した sandbox で現状 `ta-57` TC-15 が **FAIL** すること
  - ⚠️ sandbox は `mktemp -d` 複製。原本（`.claude/agents/` / `.codex/agents/` /
    `scripts/ai-loop/`）には**書き込まない**（A-03）。終了時に明示削除
  - ⚠️ 判定は **test-cases.md 前提 P-1 のスイート別パターン**で行う（rc を根拠にしない）
  - depends_on: T-01 / Owner: agent
  - rollback: 不要（tmp のみ。原本不変）
- [ ] **T-04**（GREEN / S-1-a）`ta-33` TC-01 を**期待集合との双方向照合**へ置換
  - 置換内容: (a) 全 `.md`（README 除く）が期待 tier と一致 ＋ (b) `_t33_sonnet_set` の
    各名が**ファイルとして存在**（削除検知）。`-eq 17` は削除する
  - 🚩 **PASS 側 printf（`:26`）を `（%s 体）` へ変更し `$_t33_count` を埋め込む**。
    現行はリテラル `（17 体）` で、実測件数が出るのは FAIL 側（`:29`）のみ。
    このままでは対象 0 件で PASS してもリテラルの `17` を読んで「件数 > 0」と誤判定し、
    **恒真 PASS を再導入する**（test-cases P-4 / PBIA-01 受理条件 3 が本変更に依存）
  - 🚩 `sh -n tests/extras/ta-33-agent-model-tier.sh` 通過 / TC-02・TC-04 の判定が不変
  - 🚩 **`[FAIL] TA-33 TC-01` / `[PASS] TA-33 TC-01` の prefix を維持**する
    （P-1 の判定規則が依存するため）
  - depends_on: T-03 / Owner: agent
  - rollback: `git checkout -- tests/extras/ta-33-agent-model-tier.sh`
- [ ] **T-05**（GREEN / S-1-b）`ta-33` TC-03 を**期待集合との双方向照合**へ置換
  - 置換内容: (a) 期待 low/medium 集合の各 toml が存在し effort 一致 ＋
    (b) **集合外の toml が存在しない**（過剰検知）。`-eq 17` は削除する
  - 🚩 集合外 toml の混入で FAIL すること（現状 `-eq 17` が担っていた検出力の維持）
  - 🚩 FAIL / **PASS の両方**のメッセージに**照合した toml 件数**を含める
    （対象 0 件の恒真 PASS を判定側で排除できるようにする）
  - depends_on: T-04 / Owner: agent
  - rollback: `git checkout -- tests/extras/ta-33-agent-model-tier.sh`
- [ ] **T-06**（GREEN / S-1-c）`ta-57` TC-15 の `-eq 57` を **`-ge 57`** へ変更し、
  **同一 hunk で PASS 行へ実測値を埋め込む**
  - ⚠️ **条件式の変更は 1 箇所のみ**。`:622` は既に `rc=0` && `grep -q '^OK'` && `-eq 57` の
    3 条件であり、rc と `^OK` は**変更前から効いている**。「3 条件にすることで除外する」という
    新規の便益は存在せず、本変更は**純粋な緩和**である
  - 🚩 **`:623` の `t57_pass` を
    `"TC-15 / AC-7: test_delivery.py（Ran ${_t57_n} tests / OK）"` へ変更する**。
    現行はリテラル `Ran 57 tests` で、実測 `_t57_n` は FAIL 側（`:625`）にしか出ない。
    加えて `:668` の `rm -rf "$_t57_tmp"` で python ログも削除されるため、
    **PASS 経路では `Ran N` の N を外から測る手段が無い**（test-cases P-4 /
    PBIA-07 受理条件 3 が本変更に依存）。検出力を上げる方向であり Non-goal に抵触しない
  - ⚠️ 下限方針は**人間承認済み**（A-02）。等値へ戻したり `OK` / rc 条件を落としたりしない
  - ⚠️ **既知の穴（残存）**: 全 skip 時（`Ran 57 tests` / `OK (skipped=57)` / rc=0）は
    `-eq` でも `-ge` でも **PASS** する。`grep -qE '^OK$'` で塞げるが本 PBI は
    Out of scope（D-2）。**塞がったと書かない**
  - 🚩 FAIL メッセージの実測 `ran=` は現行どおり維持する
  - depends_on: T-05 / Owner: agent
  - rollback: `git checkout -- tests/extras/ta-57-pr-convergence.sh`
- [ ] **T-07**（変異）変異注入を**呼び出し箇所（call site）**に適用し kill を実証
  - 正側: agent +1（md+toml 両側 ＋ 期待集合更新）/ テスト +1 → **PASS**
    （**`[PASS]` 行の存在と、PASS 行に埋め込まれた対象件数 ≠ 0 も受理条件**）
  - 負側: 期待外 tier の agent 混入 / 期待外 effort の toml 混入 / 集合外 toml の混入 /
    テスト 57 本未満 → **FAIL**
  - 🚩 判定は **2 層**（変異 → 被検査スイートの対象 TC が FAIL → 本 PBI の対応 TC が PASS →
    復元して被検査スイートが PASS に戻る）。test-cases.md「変異一覧」の前文に従う
  - 🚩 空振り（被検査スイートが FAIL しない）なら TC の欠陥として**正直に記録**し
    `decision-log.jsonl` へ追記（R-02）
  - depends_on: T-04, T-05, T-06 / Owner: agent
  - rollback: 不要（sandbox コピーのみ。原本不変）

### 検証

- [ ] **T-08** 個別スイート → フルスイートの順で実行し AC-06 を確認
  - 個別: T-01 の harness 経由で `ta-33` / `ta-57` を実行し、
    **該当 TC の `[FAIL]` 行が 0 件かつ `[PASS]` 行が存在**（rc を判定根拠にしない）
  - フル: `sh tests/run-tests.sh` を **timeout 1,800 秒**で 1 回実行し、
    **T-01 baseline の pass 件数以上**で exit 0
  - ⚠️ **timeout（rc=124）時の扱い**: `TIMEOUT`＝**未検証**として記録し「PASS」と書かない。
    個別スイート結果で代替判定した旨と、未検証範囲を `handoff.md` に明示する（R-07）
  - ⚠️ **baseline 側が TIMEOUT だった場合も AC-06 は WARN（未検証）**とし、個別スイートで
    代替判定する（変更後だけの完走を根拠に PASS と書かない）
  - ⚠️ フルスイートは**並走がない時点で 1 回**。件数は**下限比較**（絶対値契約にしない）
  - depends_on: T-07 / Owner: agent
  - rollback: 不要（検証のみ）

### S-3（判断のみ）

- [ ] **T-09** `tests/hooks/run-tests.sh`（754 行 / EH ブロック 13 個）の分割**要否判断**
  - 調査: 共有変数・fixture・順序依存の有無を実測（U-03）
  - 🚩 「実施する / しない」いずれでも可。**根拠を必ず残す**（AC-07）。根拠は
    「EH ブロックが共有する変数名の列挙」「順序依存の有無の実測結果」のように
    **再検証可能な形**で書く
  - ⚠️ 本 PBI では分割を**着手しない**。実施判断でも別 PBI へ送る
  - depends_on: T-08 / Owner: agent / rollback: 不要（調査のみ）

### 完了

- [ ] **T-10** `handoff.md` を作成（必須 6 要素 + 本 PBI 固有の記録）
  - 必須 6 要素: 要件適合確認（AC-01 / 02 / 03 / 06 / 07 ごとに PASS / FAIL / WARN）/
    既知課題 / V2 候補 / 妥協点 / 引き継ぎ文書 / テスト結果サマリ
  - 本 PBI 固有の記録必須項目:
    1. **S-3 判断根拠**（AC-07 の 3 要素を満たす形）
    2. **`-ge 57` 下限の運用注記**と baseline の測定条件（日時・ホスト・HEAD SHA / R-06）
    3. **`ta-33` の便益が `ta-57` 側に限定される**こと（S-1 後も agent 追加 PR は
       TC-03 / TC-04 で RED / R-09）
    4. **残存する既知の穴**: `grep -q '^OK'` は全 skip を弾かない（D-2 / Out of scope）
    5. **AC-06 が TIMEOUT だった場合の未検証範囲**（R-07）
    6. **変異の空振り**があればその一覧（R-02）
    7. **#1165 との順序制約**（技術的な必須依存は #1165 側の B-3 スコープ限定で解消。
       `ta-57-pr-convergence.sh` の並行改変を避けるため #1165 は本 PBI のマージ後に着手する）
    8. **PASS 行へ実測値を埋め込んだ**こと（`ta-33:26` / `ta-57:623`）と、それが
       「対象件数 ≠ 0」検査の前提であること
  - V2 候補: `grep -qE '^OK$'` 化 / `ta-33` `ta-57` への standalone フォールバック移植 /
    `sync-plugin-plangate.sh` 二重 allowlist の単一定義化 / `bin/plangate` の分割
  - depends_on: T-09 / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1162/handoff.md`（未 commit なら削除）
- [ ] **T-11** **AC-07 の 3 要素検査を実行**して結果を `evidence/ac07-check/` に残す
  - 検査対象: `handoff.md` の S-3 節に (a) 「実施する / しない」の明示、
    (b) **実測値**（変数名の列挙または件数）、(c) `tests/hooks/run-tests.sh` への参照
    の 3 つが揃うこと
  - ⚠️ **3 要素のいずれかが欠けたら AC-07 は未達**。T-10 へ差し戻して追記する
  - 🚩 検査は再実行可能な形（grep ベースのワンライナー）で記録する
  - depends_on: T-10 / Owner: agent
  - rollback: 不要（検査のみ。差し戻し時の rollback は T-10 に従う）
- [ ] **T-12** `status.md` を更新（フェーズ履歴を `YYYY-MM-DD HH:mm` 形式で追記）
  - 記載: C-3 判断結果（D-1〜D-3）/ 各 S の完了状況 / 計画からの変更点 / V 系進捗 /
    **#1165 との順序制約の現況**
  - ⚠️ **`plan.md` は編集しない**（C-3 承認後の編集は `plan_hash` を無効化する）
  - depends_on: T-11 / Owner: agent
  - rollback: `git checkout -- docs/working/TASK-1162/status.md`

## 👤 Human タスク（ゲート）

- [ ] **H-01**（C-3 ゲート / exec 前）plan / todo / test-cases / review-self / review-external を
  レビューし三値判断
  - ⚠️ Mode = **high-risk** のため **autonomous APPROVE 不可**。人間の C-3 が必須
  - **本ゲートで確定すべき論点**（pbi-input「C-3 での要判断事項」）:
    - **D-1**: Mode を `high-risk` とするか `critical` へ引き上げるか
    - **D-2**: `grep -qE '^OK$'` 化を本 PBI で実施するか（AI 推奨: しない）
    - **D-3**: `ta-33` / `ta-57` への standalone フォールバック移植を行うか（AI 推奨: しない）
  - 承認時は `approvals/c3.json`（`c3_status=APPROVED` ＋ **確定後 plan の `plan_hash`**）を発行
  - ⚠️ **発行は確定反映の後**（先に発行すると後続の plan 編集を EH-3 が mismatch 検知する）
  - depends_on: T-00c / Owner: human
- [ ] **H-02**（C-4 ゲート / PR レビュー）GitHub 上で APPROVE / REQUEST CHANGES / REJECT
  - ⚠️ **merge は Human-owned 固定**（AI は merge しない）
  - depends_on: T-12（PR 作成は workflow-conductor が実施）/ Owner: human

## ⚠️ 依存関係

| 依存 | 内容 |
|------|------|
| **H-00 → T-00a** | `PLANGATE_HOOK_TASK` はセッション起動時固定。AI は自セッションの env を設定できないため plan 生成の起点は Human タスク |
| **T-00 → H-01** | plan / C-1 / C-2 の確定なしに C-3 は判断できない。**H-01 は T-00c に依存**（完了タスクではない） |
| **H-01 → T-01 / T-02** | C-3 APPROVED 前に baseline 取得・decision-log 追記へ進まない |
| **T-01 → T-03 / T-08** | harness がないと extras の判定ができず、baseline がないと AC-06 が判定不能 |
| **T-03 → T-04 → T-05 → T-06 → T-07** | RED（時限爆弾の実証）を先に取り、S-1-a → S-1-b → S-1-c の順で置換し、最後に kill を実証する |
| **T-04 / T-06 → T-07** | 「対象件数 ≠ 0」の受理条件は **PASS 行への実測値埋め込み**が入って初めて検証可能になる |
| **T-10 → T-11** | AC-07 の 3 要素検査は `handoff.md` が存在してから。欠落時は T-10 へ差し戻し |
| **本 PBI → #1165** | **技術的な必須依存は解消**（#1165 の B-3 が凍結対象外 7 箇所へ限定され `test_delivery.py` を触らなくなったため）。ただし**両者とも `ta-57-pr-convergence.sh` を改変する**ので、衝突回避のため #1165 は本 PBI のマージ後に着手する |
| **Agent → Human（C-4）** | PR 作成後、H-02 の APPROVE なしに merge しない |

## 即停止条件

- HO 対象パス（`.claude/**` / `scripts/hooks/**` / `bin/plangate` / `schemas/**` /
  `.github/workflows/**` / `CLAUDE.md` / `AGENTS.md`）の編集が必要になった → **即停止**
- 外部振る舞い（CLI IF / exit code 契約 / hook 挙動）を変える必要が生じた → **即停止**（A-05）
- 変異注入が空振りし、検出力を実証できない → **即停止して人間判断**（R-02）
- 判定規則（P-1）が対象スイートで成立しない（`[PASS]` 行も `[FAIL]` 行も出ない等）→
  **即停止**。判定できない状態で PASS と記録しない
- C-3 承認後に plan の変更が必要になった → **即停止**。plan を書き換えず再承認を仰ぐ
- hook（EH-3 等）に block された → **迂回せず報告して停止**
