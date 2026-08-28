# EXECUTION TODO — TASK-1101

> plan: [plan.md](./plan.md)（**v4 / RiverReview 反映版**） / AC: [pbi-input.md](./pbi-input.md)（AC-1〜AC-11）
> Mode: **high-risk**（`lite_eligible=false` / C-3 は Standard・同期固定・autonomous APPROVE 不可）
> **L-0 / V-1〜V-4 / PR 作成は workflow-conductor が自動制御するため本 ToDo に含めない**

## 🤖 Agent タスク

> **T-01〜T-19 はすべて完了**（2026-08-28 / `82dbe8e`）。判定の正本は
> [`handoff.md`](./handoff.md) §1（**8 / 11 PASS・3 WARN・0 FAIL**）。
> 完了時に生じた**計画からの逸脱**は [`status.md`](./status.md)「計画からの変更点」#1〜#10 と
> `decision-log.jsonl` を参照。特に **#9（AC-8 の fail-closed を 2 条件 → 4 条件へ拡張）**は
> C-4 で明示承認を要する。
> **T-17 の🚩「`ta-45` が PASS することが AC-2 の実質的な担保」は成立しない**
> （exec 実測。担保は `ta-65` TC-10 / status.md 変更点 #1）。
> **T-17 の `sh tests/run-tests.sh` 通し実行は未実施**（禁止指示による degrade / AC-6 WARN）。

### 準備

- [x] **T-01** baseline を現 main で再測定する（`sh tests/run-tests.sh` の結果・`ta-65` / `ta-12` / `ta-39` / `ta-45` の PASS 状況）
  - depends_on: なし
  - 🚩 **絶対件数を契約値にしない**。測定環境（OS / シェル / 日時 / main SHA）とセットで記録する
  - `rollback:` 不要（読取のみ）
- [x] **T-02** 迂回面を現 main で再実測し、`evidence/c2-review/ho-bypass-surface.md` を更新する
  - depends_on: T-01
  - 🚩 C-2 の実測は `dfaeebb` 時点。**着手時点で再測定**する
  - `rollback:` 不要（読取のみ）

### 実装

- [x] **T-03** 正規化関数 `_pg_fold_path()` を**単体ファイル**として実装する（Step 1）
  - depends_on: T-02
  - 要件: **単語分割非依存**（`${v%%/*}` / `${v#*/}`）/ **fork ゼロ**（`sed` `tr` を使わない）/ **セグメント上限 256**
  - 🚩 **本体に組み込む前に** `sh` / `dash` / `bash` / `zsh` で直接評価して入出力一致を確認する（**ここを飛ばすと zsh no-op を見逃す** / R-002）
  - `rollback:` 単体ファイルを削除する
- [x] **T-04** `check-plan-hash.sh` への patch を作成する（Step 2）
  - depends_on: T-03
  - 内容: **`_ho_key` を新設**（`_norm_target` は**据え置き**）/ HO `case` を小文字側で受ける / `reason` と監査ログを**生 `target_file`** へ
  - 🚩 **`_norm_target` への代入を増やさない**こと（R-001。下流 3 経路が共有している）
  - 🚩 HO `case` の全数確認は **ラベル 9 行 / パターン 15 個の両方**で数える（R-011）
  - `rollback:` patch ファイルを破棄する（本体は未変更）
- [x] **T-05** `scripts/apply-1101-ho-normalization.sh` を作成する（Step 2）
  - depends_on: T-04
  - 要件: `--dry-run` 既定 / `--apply` / **`--revert`** / **`--apply` 直後の smoke check（HO 1 件 rc=2・非 HO 1 件 rc≠2・実行時間が閾値内）と失敗時の自動 revert**
  - 🚩 **AI は `--dry-run` のみ実行する**（`--apply` を AI が走らせない）
  - `rollback:` スクリプトを削除する
- [x] **T-06** 旧 apply スクリプトの stale 化に対処する（Step 2 / S-2）
  - depends_on: T-04
  - 対象: `scripts/apply-eh3-ho-always.sh`（L123-145 / L163-173 に旧 HO ブロックを verbatim 保持）/ `scripts/fix-eh3-doc-light-maint-guard.sh`（`_norm_target` を含む挿入文字列）
  - 🚩 **無効化 / 注記 / 削除のいずれかを決めて実施**する。放置すると**古い形へ巻き戻す事故**になる
  - `rollback:` `git checkout -- scripts/`

### 検証

- [x] **T-07** sandbox 検証環境を作る（Step 3 / R-008）
  - depends_on: T-05
  - 要件: `ta-65` の複製先（`cp "$_T65_HOOK_SRC" "$_T65_TMP/..."` / L80）に patch を当て、**Human 適用を待たずに実測**できること
  - 🚩 未適用 main の hook と patch 済み hook の**両方**を同一 harness で測れること
  - `rollback:` 不要
- [x] **T-08** `ta-65` TC-07 を fixed 期待へ反転する（Step 4 / AC-5）
  - depends_on: T-07
  - 🚩 **patch 未適用の hook に対して FAIL する**ことを確認する（検出力の実証）
  - `rollback:` `git checkout -- tests/extras/ta-65-eh3-ho-task-context.sh`
- [x] **T-09** TC-06 を拡充する（Step 4 / AC-3）
  - depends_on: T-07
  - 追加: `docs/x/../AGENTS.md` / `scripts/hooks/../hooks/x.py` / `bin/../bin/other` / `docs/working/TASK-T65/../TASK-T65/CLAUDE.md.bak`
  - 🚩 既存 10 件は**正規化しても値が変わらない**ため測定装置として不十分。**変換を施した非 HO ケース**を足す
  - `rollback:` 同上
- [x] **T-10** 直積検証の新 TC を追加する（Step 4 / AC-1）
  - depends_on: T-07
  - 内容: **9 カテゴリ 15 パターン × 変換 7 種 + 2 種複合 → 全件 rc=2**
  - 🚩 **既知 4 ケースの狙い撃ちでは PASS しない**構成にする
  - `rollback:` 同上
- [x] **T-11** `_norm_target` 不変の回帰表明 3 本を追加する（Step 4 / AC-2）
  - depends_on: T-07
  - 内容: maintenance `allowed_paths` の `fnmatchcase` 一致 / `docs/working/TASK-*/approvals/c3.json` の conversation 経路 / doc-light の拡張子判定
  - 🚩 **TC-02/03/04 は「壊れていないこと」の表明**。patch 未適用でも PASS するため、**変異注入（T-14）で検出力を別途実証する**
  - `rollback:` 同上
- [x] **T-12** fail-closed の新 TC を追加する（Step 4 / AC-8）
  - depends_on: T-07
  - 内容: **fail-closed 2 条件**（先頭 `..` 残り / セグメント上限超過）→ rc=2。**加えて TC-11b（絶対パスを block しないこと）**
  - 🚩 **「絶対パスが残る」を条件に加えない**（N-1/N-2 で確定。加えると scratchpad への書き込みが止まる）
  - 🚩 TC-11(d) `a/b/../../../CLAUDE.md` は畳み込み**後**に先頭 `..` へ転じる。**判定を畳み込みの後に置く**
  - `rollback:` 同上
- [x] **T-13** 監査ログが生パスを保持する TC を追加する（Step 4 / AC-9）
  - depends_on: T-07
  - 🚩 **正規化後の値ではなく Edit/Write が要求した原文**が残ること。`reason` と `skip-decision-log.jsonl` の両方で確認する
  - `rollback:` 同上
- [x] **T-14** 変異注入で検出力を実証する（Step 5 / AC-5）
  - depends_on: T-08〜T-13
  - 内容: **変換クラス 7 種に対応する変異**を**関数内の各ステップ**に 1 つずつ注入し、対応 TC が FAIL することを記録
  - 🚩 **call site を壊さない**（全変異が同じ FAIL に潰れる）
  - `rollback:` 不要（検証のみ）
- [x] **T-15** 4 シェル可搬性を実証する（Step 6 / AC-4）
  - depends_on: T-03
  - 内容: **正規化関数を `sh` / `dash` / `bash` / `zsh` で直接評価**した入出力表。`LANG=ja_JP.UTF-8` のケースを含める
  - 🚩 **`ta-65` 経由で確認しない**（hook を常に `sh` で起動するため false green / R-003）
  - `rollback:` 不要（検証のみ）
- [x] **T-16** 性能を実測する（Step 7 / AC-11）
  - depends_on: T-04
  - 内容: **追加 fork 数**（目標: 増加ゼロ）と典型 / 病的パスの実行時間
  - 🚩 測るのは `..` ループのコストではなく **fork 数**
  - `rollback:` 不要（検証のみ）
- [x] **T-17** 既存 4 本の回帰を確認する（Step 8 / AC-6 / S-4）
  - depends_on: T-14, T-15, T-16
  - 対象: `ta-65` / `ta-12`（TC-24 / TC-33）/ `ta-39`（TC-03 / TC-06）/ `ta-45`
  - 🚩 `ta-45` は R-001 を踏むと RED になる経路。**ここが PASS することが AC-2 の実質的な担保**
  - `rollback:` 不要（検証のみ）

### 完了

- [x] **T-18** `docs/ai/hook-enforcement.md` を更新する（Step 9 / AC-7 / S-3）
  - depends_on: T-17
  - 内容: 「既知の残存」を更新し、**残存ゼロまたは追跡 issue 番号を本文に記載**。**旧記述が 4 件と過少だったことを訂正**する
  - 🚩 **残存を書けば AC-7 を満たせてしまう構造にしない**。残存がある場合は**追跡 issue 番号が必須**
  - `rollback:` `git checkout -- docs/ai/hook-enforcement.md`
- [x] **T-19** handoff.md を作成する（必須 6 要素）
  - depends_on: T-18
  - 🚩 **既知課題に「残存する迂回ケース（あれば）と追跡先」を必ず含める**（#1101 自身が「追跡先の無い KNOWN-GAP」を理由に起票されたため、同じ穴を再生産しない）
  - `rollback:` 不要

## 👤 Human タスク

- [x] **H-01** **C-3 ゲート**（**plan v4** の承認 / `c3.json` 発行）
  - 🚩 **Mode の override も同時に承認対象**（M-3）: 定量では `critical` 帯（受入基準 11+）だが、**ユーザー override で `high-risk` 維持**（2026-08-15 選択 B）。この判断ごと C-3 で承認する
  - depends_on: 簡易 C-1 の再実行完了
  - 🚩 **Mode = high-risk・`lite_eligible=false` のため同期・人間必須**。autonomous APPROVE 不可
  - 🚩 **`c3.json` の発行は確定反映の後**（先に出すと EH-3 が後続反映を mismatch 検知する）
- [ ] **H-02** **patch の適用**（`sh scripts/apply-1101-ho-normalization.sh --apply`）
  - depends_on: T-05, T-06, H-01
  - 🚩 `check-plan-hash.sh` は **HO 対象パスのため AI は適用できない**
  - 🚩 適用後に smoke check が自動実行され、失敗時は自動 revert される
- [ ] **H-03** **C-4 ゲート**（PR レビューとマージ）
  - depends_on: T-19

## ⚠️ 依存関係

> **簡易 C-1 の N-3 を受けて修正**。旧版のグラフは `H-01（C-3）` を T 系列から切り離した別チェーンとして描いており、**グラフだけ読むと C-3 前に exec タスクが走る構成に見えた**。承認境界の PBI でこの誤読を招く図は残さない。**H-01 を全 T の前段として描く**。

```
👤 H-01（C-3 承認）  ←★ すべての T タスクの前段。ここが通るまで exec しない
      │
      ↓
    T-01 → T-02 → T-03 ─┬→ T-04 ─┬→ T-05 → T-07 → T-08〜T-13 → T-14 ─┐
                        │        ├→ T-06                              │
                        │        └→ T-16 ─────────────────────────────┤
                        └→ T-15 ────────────────────────────────────── ┤
                                                                        ↓
                                                          T-17 → T-18 → T-19
                                                                          │
                                          👤 H-02（patch 適用）           ↓
                                            ↑ T-05 / T-06 / H-01 後   👤 H-03（C-4）
```

- **H-01（C-3）は T-01〜T-19 のどれよりも先**（PlanGate の Iron Law: C-3 承認前に exec しない）
- **H-02（適用）は T-05 / T-06 / H-01 の後**。ただし **T-07 の sandbox 検証により、H-02 を待たずに T-08〜T-17 を実行できる**（plan Step 3 / R-008）
- **H-03（C-4）は T-19 の後**

## plan Step ↔ ToDo 対応（N-4 の追跡漏れ対策）

| plan Step | ToDo |
|---|---|
| **Step 0 準備** | **T-01**（baseline 再測定）/ **T-02**（迂回面の再実測） |
| Step 1 正規化関数の実装 | T-03 |
| Step 2 patch と apply スクリプト | T-04 / T-05 / T-06 |
| Step 3 sandbox 検証環境 | T-07 |
| Step 4 テストの拡充と反転 | T-08 / T-09 / T-10 / T-11 / T-12 / T-13 |
| Step 5 変異注入 | T-14 |
| Step 6 4 シェル可搬性 | T-15 |
| Step 7 性能実測 | T-16 |
| Step 8 回帰確認 | T-17 |
| Step 9 文書更新 | T-18 |
| （WF-05 handoff） | T-19 |

> **T-01 / T-02 は plan の Step 0（準備）に対応する**。旧版では Step 8 の🚩に埋もれていた（T-01）／plan のどの Step にも対応が無かった（T-02）。
>
> ⚠️ **v3 時点ではこの対応が虚偽だった**（RiverReview M-10）— `todo.md` は「plan v3 で Step 0 として明示した」と書いたが、**plan v3 に Step 0 は存在しなかった**（Step 1〜9 のみ）。監査表にも `REFLECTED` と記録しており、**「指摘→反映の抜けを検出する」ための機構自体を無効化**していた。**plan v4 で実際に Step 0 を追加**して解消。
