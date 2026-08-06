# EXECUTION TODO — TASK-1012

> plan: `docs/working/TASK-1012/plan.md`（**改訂 6** = C-1 ラウンド 1〜7 反映 + ゲート戦略変更）/ Mode: **standard**（`lite_eligible=true`）
> ゲート: **Human C-3**（承認）+ **ai-loop C-3' 裁定**（裁定記録・承認トークンは発行しない）

## 👤 Human タスク

| ID | 内容 | 依存 |
|----|------|------|
| **H-0** | **C-3: 承認**（`bin/plangate approve TASK-1012` で legacy 形式の `approvals/c3.json` を発行）。**AI は実行不可**（承認トークン書込ガード + presence gate） | C-1 / C-2 / C-3' 完了後・A-1 開始前 |
| **H-1** | **C-4: PR レビュー**（GitHub 上・三値）。merge は Human-owned 固定 | A-6 完了後 |

> **C-3 は ai-loop の C-3' 裁定に置換**（`lite_eligible=true`）。`arbiter.py` が `HUMAN_ESCALATED`（exit 2）を返した場合のみ Human 判断を仰ぐ。
>
> ⚠️ **ゲート戦略を変更した**（C-1 R7 / Human 判断）: **承認は Human C-3**。C-3' は「裁定記録」として回すが承認トークンの発行元にはしない。理由は plan「ゲート運用」節（①`size_ok` を誠実に申告すると `AUTO_APPROVED` に到達しない ②`check-approval-token-write.sh` が配線済みで **AI は `approvals/*.json` を書けない** ③c3-prime の発行 CLI が存在しない）。順序は **Step 0 → plan 確定 → C-1 → C-2 → C-3'（記録）→ Human C-3（`bin/plangate approve`）→ exec**。これらは workflow-conductor が制御するゲート工程であり、本 ToDo の Agent タスクには含めない。

## 🤖 Agent タスク

| ID | 内容 | depends_on | 🚩 | rollback |
|----|------|-----------|----|----------|
| **A-1**（T-01） | baseline 実測（TC 総数 / PASS 数 / rc + 実行時間 2 回）+ ゲート A / B の範囲確定 + **シンボル越境検査** | — | 🚩 baseline 記録 + **越境 0 件を機械確認** | 不要（読取のみ） |
| **A-2**（T-02） | ゲート A / B を適用（L62-68 と同型）。ヘルパー定義は移動しない。**適用後に `git add` して index に載せる** | A-1 | 🚩 `sh -n` rc=0 + **`git diff -w HEAD -- <file>`** の変化がゲート追加分のみ（**`HEAD` 必須**・M-1）+ `git diff --cached --stat` に当該ファイルが載る | `git checkout HEAD -- tests/extras/ta-26-plugin-sync.sh`（**HEAD 指定**。index ごと戻す） |
| **A-3**（T-03） | **受入検証**: AC-1 / AC-2 / AC-3 / AC-4 | A-2 | 🚩 AC-1〜AC-4 すべて PASS | 不要（読取のみ） |
| **A-4**（T-04） | **変異検証 3 種**（1 つずつ入れて戻す）。①条件反転 → AC-2 が FAIL ②ゲート B 終端を TC-36 手前へ → AC-1 が FAIL ③**ゲート外にゲート A 内変数 `_t26_t20` を参照する 1 行を注入** → 越境検査が ≥1 件 | A-3 | 🚩 3 変異すべてで期待 FAIL + 各復元後に再 PASS | 各変異ごとに `git checkout -- tests/extras/ta-26-plugin-sync.sh`（**HEAD を付けない**。index = 実装適用済みへ戻る） |
| **A-5**（T-05） | **AC-5**: 交互 A/B で実行時間を実測（BASE / OPT を交互に各 2 回以上）。**退避コピー方式**で切替（plan の該当節）。**A-4 の後に直列実行** | **A-4** | 🚩 交互測定 + 測定後に OPT が index と一致 | `cp /tmp/ta26.opt <file>` で OPT へ復帰 |
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
A-1 → A-2 → A-3 → A-4（変異 3 種・1 つずつ入れて戻す）
                          ↓
                        A-5（A/B 計測・退避コピー方式）
                          ↓
                        A-6 → 【PR 作成】 → H-1（C-4）
```

- **A-1 が最重要**。ここを行境界だけで済ませると、初版 plan が踏んだ「ゲート内定義をゲート外が参照して子が壊れる」欠陥を再現する
- **A-4 は 1 変異ずつ**。同時に入れない。復元後に対応する検証（AC-2 / AC-1 / 越境検査）を再実行して PASS を確認するまでが各変異
- **A-5 は A-4 の後に直列**（C-1 R4 指摘 D）。並行させると、変異の index 復元と A/B の `cp` 上書きが同一ファイルを奪い合う。A-5 では **`git checkout HEAD -- <file>` を使わない**（index ごと OPT を壊し復帰不能になる）

## 完了条件

- AC-1〜AC-5 がすべて PASS（AC-1 は静的前提＝シンボル越境 0 件を含む）
- A-4 の 3 変異でそれぞれ期待どおり FAIL し、各復元後に再 PASS
- **`git diff -w HEAD -- tests/extras/ta-26-plugin-sync.sh`** が**ゲート追加分のみ**（+ working context）。**`HEAD` を省くと `git add` 済みのため常に空になり fail-open**（C-1 R6 指摘 M-1）

> L-0（リンター）/ V-1（受け入れ検査）/ V-3（外部レビュー）/ PR 作成は workflow-conductor が制御するため本 ToDo には含めない。
> Mode=standard のため **V-2 / V-4 は適用外**（`.claude/rules/mode-classification.md` フェーズ適用マトリクス）。
