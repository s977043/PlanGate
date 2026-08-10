# EXECUTION TODO — TASK-1012

> plan: `docs/working/TASK-1012/plan.md`（**改訂 11** = C-1 ラウンド 1〜9 + C-2 R-001/002/004/005/006/007/008/009 反映 + **R-003 反映** + **独立 river-review R-010〜R-014 反映**）/ Mode: **high-risk**（**`lite_eligible=false`** / Human C-3 決定 2026-08-10）
> ゲート: **Human C-3**（承認）+ **ai-loop C-3' 裁定**（裁定記録・承認トークンは発行しない）

## 👤 Human タスク

| ID | 内容 | 依存 |
|----|------|------|
| **H-0** | **C-3: 承認**（`bin/plangate approve TASK-1012`）。**AI は実行不可**。実行条件は下記「H-0 の前提」を必ず読むこと | C-1 / C-2 / C-3' 完了後・A-1 開始前 |
| **H-1** | **C-4: PR レビュー**（GitHub 上・三値）。merge は Human-owned 固定。**AC-5 が WARN で確定した場合は「子プロセスのカバレッジ縮小を受け入れるか」の明示判断もここで行う**（C-2 R-004。AI は自動受理しない） | A-6 完了後 |

> ⚠️ **ゲート戦略を変更した**（C-1 R7 / Human 判断）: **承認は Human C-3**。C-3' は「裁定記録」として回すが承認トークンの発行元にはしない。理由は plan「ゲート運用」節（①`size_ok` を誠実に申告すると `AUTO_APPROVED` に到達しない ②`check-approval-token-write.sh` が配線済みで **AI は `approvals/*.json` を書けない** ③c3-prime の発行 CLI が存在しない）。順序は **Step 0 → plan 確定 → C-1 → C-2 → C-3'（記録）→ Human C-3（`bin/plangate approve`）→ exec**。これらは workflow-conductor が制御するゲート工程であり、本 ToDo の Agent タスクには含めない。

### H-0 の前提（`bin/plangate approve` の実装を読んで確認・C-1 R8 指摘 P-3）

`bin/plangate approve` は **5 つ**の条件で止まる。**知らずに実行すると必ず失敗する**ので事前に読むこと。

| # | 条件 | 実装 | 意味 |
|---|------|------|------|
| a | **presence gate L3**: `ps -p $PPID -o comm=` が `claude` / `codex` / `cursor` に一致すると **reject** | `_plangate_presence_gate()` | ⚠️ **Claude Code 内のターミナルで打つと必ず弾かれる**。**別のターミナル**（AI エージェントの子プロセスでない場所）で実行すること |
| b | **presence gate L1/L2**: stdin が TTY であること / `CI`・`CLAUDE_AGENT`・`CURSOR_AGENT`・`PLANGATE_BYPASS_HOOK` がすべて未設定 | 同上 | 非対話実行・スクリプト化は不可 |
| c | **L4 nonce**: 8 桁 hex を対話で打ち返す | 同上 | 自動化できない（意図的） |
| d | **APPROVED 時は内部で `cmd_validate` が走る**。`pbi-input.md` / `plan.md` / `todo.md` / `test-cases.md` / **`review-self.md`** の 5 点が必須 | `cmd_approve` → `cmd_validate` | **`review-self.md` が無いまま approve すると、c3.json は生成済み・コマンドは rc=1** で終わり、以後 `--force` が必要になる |
| e | **既存 `approvals/c3.json` があると `--force` 無しで `return 2`** | `cmd_approve` | 再承認時は `--force` を付ける |

> ✅ **承認後に `review-external.md` / handoff を書くのは安全**。`cmd_exec` の preflight が照合するのは `plan.md` の hash のみで、これらは hash 対象外。ただし **`plan.md` は承認後に一切編集しない**（`plan_hash mismatch` で exec が止まる）。

## 🤖 Agent タスク

| ID | 内容 | depends_on | 🚩 | rollback |
|----|------|-----------|----|----------|
| **A-1**（T-01） | baseline 実測（TC 総数 / PASS 数 / rc + 実行時間 2 回）+ ゲート A / B の範囲確定 + **シンボル越境検査** | — | 🚩 baseline 記録 + **越境 0 件を機械確認** | 不要（読取のみ） |
| **A-2**（T-02） | ゲート A / B を適用（L62-68 と同型）。ヘルパー定義は移動しない。**適用後に `git add` して index に載せる** | A-1 | 🚩 `sh -n` rc=0 + **`git diff -w HEAD -- <file>`** の変化がゲート追加分のみ（**`HEAD` 必須**・M-1）+ `git diff --cached --stat` に当該ファイルが載る | `git checkout HEAD -- tests/extras/ta-26-plugin-sync.sh`（**HEAD 指定**。index ごと戻す） |
| **A-3**（T-03） | **受入検証**: AC-1 / AC-2 / AC-3 / AC-4 / **AC-6（適用後の tree に対して TC-A6a を再実行）** | A-2 | 🚩 AC-1〜AC-4 + AC-6 すべて PASS | 不要（読取のみ） |
| **A-4**（T-04） | **変異検証 4 種**（1 つずつ入れて戻す）。①条件反転 → AC-2 が FAIL ②ゲート B 終端を TC-36 手前へ → AC-1 が FAIL ③**ゲート外に、ゲート B 終端付近で定義される変数 `_t26_tgt36`（L721）を参照する 1 行を注入** → 越境検査が ≥1 件（**`_t26_t20` に戻さない** — C-2 R-002b） ④**範囲入力を広げて TC-30 のヘッダを飲み込ませる**（TC-A6d・**ファイル無改変**）→ 排他アサーションが `IN-RANGE` を報告 | A-3 | 🚩 4 変異すべてで期待 FAIL + 各復元後に再 PASS | 各変異ごとに `git checkout -- tests/extras/ta-26-plugin-sync.sh`（**HEAD を付けない**。index = 実装適用済みへ戻る） |
| **A-5**（T-05） | **AC-5**: 交互 A/B で実行時間を実測（BASE / OPT を交互に各 2 回以上）。**退避コピー方式**で切替（plan の該当節）。**A-4 の後に直列実行**。⚠️ **A-5 完了まで実装を commit しない**（commit すると `git show HEAD:` で取る BASE がゲート適用後になり BASE == OPT で AC-5 が無言で無意味化する — C-1 R9 指摘 N-2。plan の BASE 健全性アサーションで検出する） | **A-4** | 🚩 交互測定 + 測定後に OPT が index と一致 + BASE アサーション通過 | `cp /tmp/ta26.opt <file>` で OPT へ復帰 |
| **A-6**（T-06） | handoff / status / current-state / INDEX を整備。handoff に「**ゲート境界の直後に TC を足すときは越境検査を再実行する**」旨を明記 | A-5 | 🚩 handoff 6 要素 + 再発防止の申し送り | 不要 |

## ⚠️ 変異の復元セマンティクス（C-1 R3 N-3 の是正・**厳守**）

初版は A-2 の rollback と変異復元に**同じコマンド**を割り当てており、両立しなかった。`git checkout -- <file>`（HEAD 無し）は **index の内容**へ戻すため、A-2 で `git add` 済みなら**実装を保持したまま変異だけ**が消える。

| 目的 | コマンド | 戻り先 |
|------|---------|-------|
| **変異のみ復元**（A-4 の各変異後） | `git checkout -- tests/extras/ta-26-plugin-sync.sh` | **index**（= ゲート実装が載った状態） |
| **実装ごと取り消し**（A-2 のやり直し） | `git checkout HEAD -- tests/extras/ta-26-plugin-sync.sh` | HEAD（= ゲート未適用） |

> ⚠️ **A-2 の `git add` を飛ばすと両者が同じ意味になる**。その場合 A-4 の「復元後の再 PASS」は**ゲート実装が消えた状態**での確認になり、AC-2 は baseline と一致して誤 PASS・AC-1 は SKIP 0 本で FAIL する（誤診断）。A-2 の 🚩 に `git diff --cached --stat` を入れているのはこのため。

## ⚠️ 変異①の適用範囲（C-1 R3 N-7）

`PG_T26_NO_RECURSE` のゲートはファイル内に **4 箇所**（既存 2 = TC-03/04 の L67・TC-13 の L293、新規 2 = ゲート A / B）ある。変異①（条件反転）は**新規 2 箇所に限定**すること。一括置換で TC-13 のゲートまで反転させると、子が TC-13 本体を実行して**孫プロセスを無限に spawn する**。

## ⚠️ 依存関係

```text
A-1 → A-2 → A-3 → A-4（変異 4 種・1 つずつ入れて戻す）
                          ↓
                        A-5（A/B 計測・退避コピー方式）
                          ↓
                        A-6 → 【PR 作成】 → H-1（C-4）
```

- **A-1 が最重要**。ここを行境界だけで済ませると、初版 plan が踏んだ「ゲート内定義をゲート外が参照して子が壊れる」欠陥を再現する
- **A-4 は 1 変異ずつ**。同時に入れない。復元後に対応する検証（AC-2 / AC-1 / 越境検査）を再実行して PASS を確認するまでが各変異
- **A-5 は A-4 の後に直列**（C-1 R4 指摘 D）。並行させると、変異の index 復元と A/B の `cp` 上書きが同一ファイルを奪い合う。A-5 では **`git checkout HEAD -- <file>` を使わない**（index ごと OPT を壊し復帰不能になる）

## 完了条件

- **AC-1〜AC-6 がすべて PASS**（**AC-6 = シンボル越境 0 件**。改訂 9 まで「AC-1 の静的前提」として畳んでいたものを改訂 10 で独立 AC へ復帰 — C-2 R-003 / Human C-3 決定）
  - AC-6 は **TC-A6a のフェンスのスクリプトをそのまま実行**して `containment_violations=0` かつ `crossings=0` であること。**範囲導出 awk の出力を目視で信用しない**。桁 0 の `fi` により範囲は**両方向へ**壊れる — 打ち切られる側（C-2 R-002a / (1) 内包アサーション）と、**次の桁 0 `fi` まで延びて TC-30/33 を飲み込む側**（river-review major / **(1b) 排他アサーション**）。**(1b) 無しでは広がる側が rc=0 で PASS する**（実測済み）
- A-4 の **4 変異**でそれぞれ期待どおり FAIL し、各復元後に再 PASS（④ TC-A6d はファイル無改変のため、正しい範囲での再実行が復元確認にあたる）
- **`git diff -w HEAD -- tests/extras/ta-26-plugin-sync.sh`** が**ゲート追加分のみ**（+ working context）。**`HEAD` を省くと `git add` 済みのため常に空になり fail-open**（C-1 R6 指摘 M-1）
- **判定用ログを repo ルートに残さない**（C-2 R-008）。ログはすべて `docs/working/TASK-1012/evidence/test-runs/` 配下に出力する。完了前に `git status --porcelain` で **想定外の untracked が 0 件**であることを確認する（#1021 と同クラスの repo 汚染を作らない）
- **PR 前に clean tree で CI 相当（python テスト側を含む）を 1 回通す**（C-2 R-007）
  - `tests/run-tests.sh` に **pytest 起動は 0 件**（実測）。python 側の unit test は `tests/extras/ta-60-run-evidence.sh` が `python3 scripts/ai-loop/test_run_evidence{,_verify}.py` を直接呼ぶ導線でのみ走る（同ファイル L134 / TC-47）。**AC-4 を「pytest も含む」と読み替えないこと**
  - **dirty tree で誤 FAIL する具体経路（実測で確認）**: `test_run_evidence.py::test_tc45` は `git status --porcelain -- docs/working/ai-loop-runs/` が**空であること**を assert する。**C-3' の裁定記録は同ディレクトリへ出力される**ため、未 commit のまま `sh tests/run-tests.sh` を回すと ta-60 経由で FAIL し、AC-4 が本 PBI と無関係な理由で落ちる
    - 実測: `docs/working/ai-loop-runs/` に untracked を 1 件置くと `test_tc45` が `AssertionError: '?? docs/working/ai-loop-runs/…' != ''` で FAIL。取り除くと PASS
  - したがって **A-5 完了後・PR 作成前に、変異も A/B 退避も判定用ログの残骸も無い状態**（`git status --porcelain` に想定外の untracked が 0 件）で `sh tests/run-tests.sh` を **もう 1 回**実行し、0 failed を確認する。C-3' 裁定記録は**この実行より前に commit しておく**
- **AC-5 が WARN のまま確定した場合は AI 完了扱いにしない**（C-2 R-004）
  - 短縮率が判定基準（OPT ≤ BASE × 0.85）に届かず WARN が継続したときは、`status.md` に `## AC-5: WARN（人間判断待ち）` を記録し、**H-1（C-4）で人間に「子プロセスのカバレッジ縮小を受け入れるか」を明示判断させる**
  - 本 PBI は **恒久コスト（テスト意味論の変更）が確定する一方、便益未達でも完了できる**非対称を持つ。AI が「短縮はしているので有益」と自己判断して押し切らない
  - handoff / PR 本文に **(1) BASE/OPT の全実測値と短縮率 (2) 恒久コストの明示 (3) `git revert` 1 手で取り消せること** を必ず載せる。人間が「受け入れない」と判断した場合は revert する

- **V-2（コード最適化）/ V-3（外部モデルレビュー）を通過していること**（改訂 10 / Mode = high-risk。`.claude/rules/mode-classification.md` フェーズ適用マトリクス）
  - **V-2**: 追加したゲート 2 組を対象に、**動作を変えずに**可読性を確認する。⚠️ **TC-INV（`git diff -w HEAD --` がゲート追加分のみ）を壊す変更は行わない**ため改変余地は極小。**「最適化なし」と判断した場合もその判定と根拠を evidence に残す**（未実施と、実施して変更なしを区別する）。変更した場合は **AC-1〜AC-4 を再実行**して回帰なしを確認する
  - **V-3**: 実装後の外部レビュー。指摘は `review-external.md` へ**追記専用**で `R-NNN` 採番して集約する（既存 R-001〜R-009 は書き換えない）
  - **V-4 は適用外**（`critical` のみ）
- **brainstorm / exec 並列も high-risk では `○` だが、本 PBI では該当なし / 非並列とする**（`.claude/rules/mode-classification.md` L149-163 の中→高 差分は `brainstorm` / `C-2` / `exec` / `V-2` の **4 行**）。brainstorm は R-407 で方式確定済みの派生 PBI のため該当なし、exec は A-1〜A-6 が全て直列依存のため並列化しない。**いずれも H-0（Human C-3）の確認事項**として提示する（AI が単独で「不要」と確定しない）
- **C-2 の充足は AI が判定しない**（改訂 10）。high-risk の C-2 は `○`（必須）だが、実施済みの 1 本は Lite ゲート（AC-12）を根拠としたものであり、`review-principles.md` §7-bis の**コードベース整合レーンが未実施**のまま残る。plan「C-2 の充足判定」の結論は **不足**。追加 1 本を exec 前に実施するか、この不足を許容して APPROVE するかは **H-0（Human C-3）の判断事項**として提示する

> L-0（リンター）/ V-1（受け入れ検査）/ **V-2** / **V-3** / PR 作成は workflow-conductor が制御するため、本 ToDo の Agent タスク（A-1〜A-6）には工程として並べない（完了条件としては上記に含める）。
