# EXECUTION TODO — TASK-1045

> 計画: [`plan.md`](./plan.md) / テスト: [`test-cases.md`](./test-cases.md)
> Mode: **`critical`** / `lite_eligible=false` / **人間 C-3 必須・同期**
> L-0 / V-1〜V-4 / PR 作成は `workflow-conductor` が自動制御するため本 ToDo には含めない。

## Stop Conditions / Replan Triggers（**正本は [`plan.md`](./plan.md)**）

> 各タスクの 🚩 チェックポイントは、失敗時に下表の ID へ接続する。
> **「様子を見る」「回避策を探す」は禁止**（AI 運用 4 原則 第 2: 迂回禁止）。

| ID | 種別 | 要約 | 接続先タスク |
|---|---|---|---|
| **SC-1** | 停止 | baseline が 0 failed でない / **RED 中に GC-4-C の期待 FAIL 6 件以外が FAIL** | A-1 / A-4 |
| **SC-2** | 停止 | 変異アンカーの `grep -c` が 1 でない | A-6b |
| **SC-3** | 停止 | 変異が kill されない / 新 TC が focused 子で走らない | A-4 / A-9 / A-10 |
| **SC-4** | 停止 | 既存 mutation 7 種のいずれかが kill されなくなる（**7 ラベル列挙で判定。`TC-15pre` / `TC-17post` は対象外**） | A-4 / A-8b / A-13 |
| **SC-5** | 停止 | `T1023-TC-09` が FAIL（GC-3 違反） | A-6a |
| **SC-6** | 停止 | 境界 TC + **`T1045-TC-07 (1)`** が `rc=0` になる（ガード弱体化 / GC-1 違反） | A-7 / A-11 |
| **SC-7** | 停止 | 変更が許可 3 領域の外へ及ぶ | 全タスク |
| **SC-8** | 停止 | `PLANGATE_SKIP_TOKEN_GUARD=1` が必要になる（Human-owned） | 全タスク |
| **SC-9** | 停止 | **`sed` 不在 / 失敗時に guard が `rc=0`（ALLOW）** = **`T1045-TC-22`（不在）または `T1045-TC-22b`（失敗）のいずれかが FAIL**（GC-8 / R-009） | A-5a / A-6a |
| **RT-1** | 差し戻し | BSD / GNU `sed` で 26 ケースの分類が割れる | **A-1b** |
| **RT-2** | 差し戻し | **(a)** 他の稼働ガードが本ガードを **invoke / source** している / **(b)** 本ガードの**複製が `.claude/settings*.json` に実配線**されている（実測では (a)(b) とも該当なし） | A-1 |
| **RT-3** | 差し戻し | 既存 TC がメッセージ本文を assert していると判明 | A-1 / A-8 |
| **RT-4** | 差し戻し | `_t25_mutate` への引数追加が既存互換を壊す | A-8b |
| **RT-5** | 差し戻し | 列挙的 allowlist のまま AC-01〜03 を満たせない | A-5a / A-5b |

**発火時の必須記録**: 発火 ID・判定に使った**実出力**・停止時点の **HEAD SHA** を
`decision-log.jsonl`（append-only）と `status.md` に記録してから停止する。

## 依存関係（Agent ↔ Human）

```text
H-1 (C-3 人間承認) ──必須先行──> A-2 以降のすべての Agent タスク
A-1 (調査・baseline) は C-3 前でも実行可（読み取りのみ・ファイル変更なし）
A-14 (handoff) ──> H-2 (C-4 PR レビュー) ──> merge (Human-owned)
```

- **A-2 以降は `approvals/c3.json`（`c3_status=APPROVED`）の発行後にのみ開始する**
- 承認 artifact は **Human-owned**。AI は作成しない

---

## 👤 Human タスク

### H-1: C-3 ゲート（exec 前・**同期・必須**）

- Owner: **human**
- 内容: `plan.md` / `todo.md` / `test-cases.md` + C-1 / C-2 結果を確認し三値判定
- **判断を要する論点**（plan §Questions / Unknowns）: **Q-1 / Q-2 / Q-3 は 3 件とも裁定済み**
  - **Q-1**: Mode を `critical` のままとするか `high-risk` へ引き下げるか
    → ✅ **裁定済み: `critical` のまま**（plan の既定を維持）。
    V-4 と C-4 複数レビュアー推奨が適用される。`lite_eligible=false` / 同期 C-3 は元から不変。
    **plan の設計変更なし**
  - **Q-2**: U-2（`&>` / `&>>` を block 維持）でよいか
    → ✅ **裁定済み: block 維持**（安全側）。`&>/dev/null` 付き読み取りは**残存誤検知**のまま。
    **`T1045-TC-14 (3)` で意図的に固定し、handoff の既知課題へ必ず記載する**。
    **plan の設計変更なし**
  - **Q-3（River Review 由来）**:
    `plan.md` の `Files / Components to Touch` に `evidence/` /
    `decision-log.jsonl` / `current-state.md` を追加して `plan_hash` を取り直すか
    → ✅ **裁定済み: 追加して `plan_hash` を取り直す**
    - **反映済み**: `plan.md` の `Files / Components to Touch` へ 3 行追加。
      `extract_allowed_paths(plan.md)` を実走し **7 → 10 パス**を実測確認
    - **効果**: ai-loop 経路で exec しても evidence / decision-log / current-state の
      書き込みが `allowed_paths` **内**に収まる（逸脱扱いにならない）
    - **`plan_hash` は再算出済み**（`744b3c4f…` → `30261b11…`）。
      詳細は `review-external.md` の **`R-019`**
- **裁定後に残る Human タスク**: **新 `plan_hash` に対する承認トークンの再発行**（**Human-owned**。
  AI は作成しない）。順序は **plan 編集 → 簡易 C-1 → 新 hash 算出 → 👤 承認 → exec**
- 🚩 **チェックポイント**: `critical` かつセキュリティ関連のため
  **autonomous APPROVE は不可**（`working-context.md` §C-3 Autonomous APPROVE）
- 出力: `docs/working/TASK-1045/approvals/c3.json`（**Human-owned**）+ `status.md` へゲート記録

### H-2: C-4 ゲート（PR レビュー）

- Owner: **human**
- 内容: GitHub 上で PR をレビュー（`critical` のため**複数レビュアー推奨**）
- 🚩 **チェックポイント**: **ガードを弱める変更が入っていないこと**（plan GC-1）を
  AC-04〜07 / AC-09 の evidence で確認
- merge は **Human-owned 固定**

---

## 🤖 Agent タスク

### フェーズ 1: 準備・調査（C-3 前でも可）

#### A-1: baseline 実測と横断調査（plan Step 1）

- Owner: agent / depends_on: なし
- 内容:
  1. `sh tests/extras/ta-25-approval-token-guard.sh` を実行し pass/fail を記録
  2. `PreToolUse` payload で誤検知（A〜K 表）を**本 PBI 内で再現**
     （トークン literal と `2>/dev/null` を**同一コマンドに書かない** / plan §記法規約）
  3. **U-6 横断調査**: `scripts/` / `bin/` / `.codex/` の粗い `>` 判定を列挙
     → 検出時は **scope 外・follow-up issue 起票**
  4. **U-3 再確認**: `grep -rn "writes token path" tests/` が 0 件
  5. **RT-2 の (a)(b) を実測**（R-003）: (a) 他ガードが本ガードを invoke / source していないか、
     (b) 本ガードの複製が `.claude/settings*.json` に実配線されていないか
  6. **稼働 settings の実測（i-1）**: `.claude/settings.json`（**gitignore 対象で worktree には
     存在しない**）が `scripts/` 直下を直接呼び、`scripts/hooks/` 側の複製が無いことを
     **メイン checkout 側で実測**して 1 行残す（U-5「再適用不要」の根拠を稼働側でも固める）
  7. **R-008 の複製導線を記録**: `scripts/apply-task-0123-patches.sh`（`67-88` 行）が
     `scripts/hooks/` へ `cp` し**既存時はスキップして更新しない**ことを確認
     （**GC-7 維持・本 PBI では触らない**。handoff + follow-up issue へ）
- 出力: `evidence/verification/baseline.md`
- 🚩 **チェックポイント**: baseline が **0 failed**。そうでなければ **SC-1 で即停止**して人間へ
- `rollback:` 不要（読み取り・記録のみ）

#### A-1b: GNU `sed` 等価性の**先行**検証（plan Step 1b / W-2 で Step 8 から前倒し）

- Owner: agent / depends_on: A-1
- 内容: 正規化ロジックの **26 ケースのプロトタイプ**を
  **BSD `sed`（macOS）と GNU `sed`（Linux コンテナまたは CI）の双方**で実行し、
  分類が一致することを確認する（`scripts/` は変更しない）
- 出力: `evidence/verification/sed-dialect-parity.md`
- 🚩 **チェックポイント**: **26/26 が両方言で一致**。
  1 件でも異なれば **RT-1 を発火させ C-3 へ差し戻す**（実装に着手しない）
- **前倒しの理由**: plan の feasibility 検証は **BSD `sed` のみ**（UV-1）。
  実装後に割れると Step 3 以降が全て手戻りになる
- `rollback:` 不要（スクラッチのみ）

---

### フェーズ 2: 実装（**H-1 承認後にのみ開始**）

> **focused 群へ置く TC は plan §GC-4-A の 7 件**
> （`T1045-TC-01`〜`06` + `TC-20`）。それ以外は通常群。

### TC 追加の owner 表（**全 23 件に owner を割り当てる** / R-014）

> **plan `Step 2` は「`TC-07`〜`TC-19` + `TC-21` + `TC-22` + `TC-22b` を通常群へ追加」と
> 書いている。本表は plan のその記述と一致する側へ寄せ、todo 側の分解に落としたもの。**
> **owner の無い TC が 1 件でもあると、その TC は `ta-25` に入らずスクラッチ確認に退化する**
> （#874 型「TC はあるのに検出力が無い」の再発）。

| TC | 追加する owner タスク | 群 |
|---|---|---|
| `TC-01` / `TC-02` / `TC-03` / `TC-20` | **A-2** | focused |
| `TC-04` / `TC-05` / `TC-06` | **A-3** | focused |
| **`TC-22` / `TC-22b`** | **A-5a**（GC-8 実装と同一タスク） | 通常 |
| `TC-11` / `TC-12` / `TC-13` / `TC-14` / `TC-15` / `TC-19` / **`TC-07`** / **`TC-16`** / **`TC-17`** / **`TC-18`** | **A-7** | 通常 |
| `TC-08` | **A-8** | 通常 |
| `TC-21` | **A-8b** | 通常 |
| `TC-09` / `TC-10`（`_t25_mutate` 呼び出し） | **A-9** / **A-10** | 通常 |

**合計 23 件（focused 7 + 通常 16）で owner 未割当は 0 件。**
**`A-11` / `A-12` は evidence 専任**（`TC-07` / `TC-17` の**追加は A-7** が行い、
A-11 / A-12 は**実測ログの採取のみ**。したがって `rollback: 不要` のまま）。

#### A-2: RED — 誤検知解消 TC を focused 群へ追加（plan Step 2）

- Owner: agent / depends_on: A-1b, **H-1**
- 内容: `T1045-TC-01` / `TC-02` / `TC-03` / `TC-20` を
  **`ta-25` の `222` 行より前（focused 群）**へ追加
- 🚩 **チェックポイント**: この時点で **`T1045-TC-01`〜`03` + `TC-20` が FAIL する**（RED 成立）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-3: RED — 退行防止 TC を focused 群へ追加（plan Step 2）

- Owner: agent / depends_on: A-2
- 内容: `T1045-TC-04` / `TC-05` / `TC-06` を **focused 群**へ追加（合計 7 件で GC-4-A と一致）
- 🚩 **チェックポイント**: この時点で **PASS**（修正前でも通るべき TC＝退行防止の基準線）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-4: focused 群配置の実測確認（plan GC-4(b) / R-7）

- Owner: agent / depends_on: A-3
- 内容: `PG_T25_MUTATION_CHILD=1` で `ta-25` を子プロセス実行し、
  **GC-4-A の 7 件（`T1045-TC-01`〜`06` / `TC-20`）のラベルが出力に現れる**ことを目視確認
  （UV-3 の解消）
- **判定方式（R-001）**: **suite 全体の rc / `0 failed` で判定しない**
  （RED 中は必ず exit 1 になる）。**`grep -q "[FAIL] <ラベル>"` のラベル単位判定**で行う
- 🚩 **チェックポイント**:
  - 1 件でも現れなければ **focused 群外に置かれている** → **SC-3 で即停止**し、
    配置を修正するまで先へ進まない（#874 同型の空振り防止）
  - **RED ウィンドウの FAIL が GC-4-C の 6 件と完全一致**すること:
    `T1045-TC-01` / `TC-02` / `TC-03` / `TC-20` / **`T1023-TC-15pre`** / **`T1023-TC-17post`**。
    **この 6 件は SC-1 / SC-4 の対象外**。**6 件以外が FAIL したら SC-1 で即停止**
  - **既存 mutation 7 種が引き続き PASS**（**SC-4 の 7 ラベル列挙**で判定。
    `TC-15pre` / `TC-17post` は除外）。
    変異 1 の子で `T1045-TC-04`〜`06` も FAIL するが `T1023-TC-15` の kill 判定は成立する。
    壊れれば **SC-4 で即停止**
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

> **W-5 対応**: 旧 A-5 / A-6 は 1 タスクあたり 2〜5 分の粒度基準を超過していたため、
> **A-5a / A-5b / A-6a / A-6b の 4 タスクへ分割**した（各 2〜5 分・独立に rollback 可能）。

#### A-5a: GREEN — fd 複製 / クローズの除去のみ実装（plan Step 3-1）

- Owner: agent / depends_on: A-4
- 内容: `_strip_nonwrite_redirects()` を新設し、**(1) fd 複製 / クローズ除去のみ**を実装
  （`>&` の直後が **数字列 or `-`** のときのみ除去。`>&<file>` は除去しない / R-4）。
  **同時に GC-8 の必須実装 3 件を入れる**（**後回しにしない** / R-002）:
  (i) `_wc_n=$(…) || _wc_n="$_wc"` の fail-closed フォールバック、
  (ii) `command -v sed` 検査（`jq` と同契約）を
  **`_parse_unknown()` 定義の後（`:81` 以降）・`# --- 1) target:`（`:83`）の直前**に置く
  （**関数定義より前に置くと `rc=127` = 非 block になり `T1023-TC-05` も巻き添えで落ちる** / R-010）、
  (iii) 正規化パイプラインの `LC_ALL=C` 固定
  - **`T1045-TC-22` / `T1045-TC-22b` を `ta-25` の通常群へ追加する**（**R-014 / 本タスクの owner**）。
    **スクラッチ確認で代替しない**（コミットされたスイートに残さないと
    `R-12`（critical / fail-open）の機械的担保が消える）。
    GC-8 の実装と同一タスク内で **RED（未実装で FAIL）→ GREEN** を確認する
- 🚩 **チェックポイント**: `sh -n` PASS。単体で `2>&1` / `>&2` / `3>&-` が除去され、
  `>& /tmp/o` が**除去されない**ことをスクラッチで確認。
  **要件 (iii) の静的検査**（R-016。**(iii) だけは TC で落とせないため静的に確認する**）:
  `grep -c 'LC_ALL=C' scripts/check-approval-token-write.sh` が **1 以上**、
  **かつ正規化パイプライン行に付いている**こと（別行に付いていても (iii) を満たさない）。
  **`sed` 不在 PATH で `rc=2`**（要件 (ii)）**かつ `sed` シム（`exit 1`）PATH でも `rc=2`**（要件 (i)）を
  確認 → **どちらかが `rc=0` なら SC-9 で即停止**（R-009。**不在だけの確認では (i) の欠落を見逃す**）。
  **reason の期待値は TC ごとに異なる**（R-013）: **不在 → `sed not available`** /
  **シム → `Bash command writes token path` かつ `parse-unknown` を含まない**。
  **シム側に `sed` 起因の reason を期待しない**（フォールバックは設計上サイレント）。
  **`T1023-TC-05` が PASS を維持**することも確認（R-010 の巻き添え検出）
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh tests/extras/ta-25-approval-token-guard.sh`
  （**R-014 により本タスクは `ta-25` も変更する**ため両方を戻す）

#### A-5b: GREEN — `/dev/null` 破棄の除去を追加（plan Step 3-1）

- Owner: agent / depends_on: A-5a
- 内容: 同ヘルパへ **(2) `/dev/null` 破棄除去**を追加
  （**語境界**必須 / **直前が `&` なら除去しない**。**POSIX BRE のみ** / plan GC-6）
- 🚩 **チェックポイント**: `sh -n` PASS。`/dev/nullX` / `/dev/null/../…` / `&>/dev/null` が
  **除去されない**ことをスクラッチで確認（R-3 / U-2）
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh`

#### A-6a: GREEN — `_has_write_intent()` の `>` 検査を 2 段構成へ置換（plan Step 3-2）

- Owner: agent / depends_on: A-5b
- 内容: `48` 行の `grep -q '>'` を「正規化 → 残存 `>` 判定」の 2 段へ置換
- 🚩 **チェックポイント**:
  - `T1045-TC-01`〜`06` / `TC-20` が **全 PASS へ転じる**
  - **`T1023-TC-08` / `TC-09` が PASS を維持**（plan GC-3。FAIL なら **SC-5 で即停止**）
  - **`T1023-TC-15pre` / `T1023-TC-17post` が PASS へ戻る**（GC-4-C。
    **RED ウィンドウが閉じたことの機械的確認**。戻らなければ即停止）
  - **`T1045-TC-22`（`sed` 不在 / 要件 (ii)）と `T1045-TC-22b`（`sed` 失敗 / 要件 (i)）が両方 PASS**
    （GC-8 / R-009。いずれかが FAIL なら **SC-9 で即停止**）
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh`

#### A-6b: 一意アンカー 2 種を付与し `grep -c` == 1 を実測（plan Step 3-3）

- Owner: agent / depends_on: A-6a
- 内容: **`# t1045-redirect-normalize`** / **`# t1045-file-redirect`** を付す
- 🚩 **チェックポイント**: **アンカー 2 種が各 `grep -c` == 1**（実測 / R-6）。
  1 でなければ **SC-2 で即停止**
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh`

#### A-7: 除外条件の境界 TC を追加（plan Step 2 / R-3・R-4・U-1・U-2・GC-2）

- Owner: agent / depends_on: A-6b
- 内容: **通常群の残余をすべて追加する**（R-014 / owner 表）:
  `T1045-TC-11`〜`15` / `TC-19`（除外条件の境界）
  **＋ `TC-07`**（併記回避。**`SC-6` がスイート条件として rc を参照する**ため
  `ta-25` に入っていないと GC-1 の機械担保が 1 本細る）
  **＋ `TC-16` / `TC-17` / `TC-18`**（既存スイート突合 / AC-12 監査 / 静的検査）
  （**`TC-22` / `TC-22b` は A-5a が追加済み**。GC-8 の実装と同時に検出力を確保するため）
- 🚩 **チェックポイント**: 全 **rc=2**（除外が広がりすぎていないことの機械確認）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-8: block メッセージへ `rule=<id>` を付与（plan Step 4）

- Owner: agent / depends_on: A-6b
- 内容: `_has_write_intent()` が一致ルール ID を返し `_block()` detail に載せる（6 ID）。
  併せて `T1045-TC-08` を追加
- 🚩 **チェックポイント**: `BLOCK` / `target=` / `file_path=` / `parse-unknown` / `bypass` を
  assert する**既存 TC がすべて PASS を維持**
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh tests/extras/ta-25-approval-token-guard.sh`

#### A-8b: `_t25_mutate` に label prefix 引数を追加（plan GC-4-B 採用案 (a) / W-4）

- Owner: agent / depends_on: A-8
- 内容: シグネチャを `_t25_mutate <tc-id> <sed> <anchor> <kill-label> [prefix]` へ拡張し、
  内部 5 箇所（`ta-25:640, 644, 648, 656, 658`）の `T1023-` ハードコードを
  **`${5:-T1023}` 由来へ置換**する。**既存 7 呼び出し（`662, 664, 666, 668, 670, 672, 674`）は無変更**
- 🚩 **チェックポイント**: **既存 mutation 7 種が全 PASS**、かつ出力ラベルが **`T1023-` のまま**
  （`T1045-TC-21`）。壊れれば **RT-4 で C-3 へ差し戻す**
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-9: 変異 (a)「修正前へ戻す」を追加（plan Step 5 / AC-08）

- Owner: agent / depends_on: A-8b
- 内容: `_t25_mutate` 呼び出しを追加（`t1045-redirect-normalize` を no-op 化 /
  kill 対象 `T1045-TC-01` / **第 5 引数 `T1045`**）
- 🚩 **チェックポイント**: **`[FAIL] T1045-TC-01` が実出力に現れ、子プロセス rc が非 0**
  （申告ではなく実出力を evidence に残す）。**出力ラベルが `T1045-TC-09`**
  （`T1023-TC-09` と衝突しない）。kill しなければ **SC-3 で即停止**
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-10: 変異 (b)「弱める側」を追加（plan Step 5 / AC-09）

- Owner: agent / depends_on: A-9
- 内容: `_t25_mutate` 呼び出しを追加（`t1045-file-redirect` を常に false 化 /
  kill 対象 `T1045-TC-04` / **第 5 引数 `T1045`**）
- 🚩 **チェックポイント**: **`[FAIL] T1045-TC-04` が実出力に現れ、子プロセス rc が非 0**。
  **出力ラベルが `T1045-TC-10`**。
  **これが plan GC-1（弱体化禁止）の機械的担保**であり、空振りしたまま先へ進まない
  （kill しなければ **SC-3 で即停止**）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

---

### フェーズ 3: 検証

#### A-11: 併記回避の多重防御を再実測（plan Step 6 / AC-07）

- Owner: agent / depends_on: A-10
- 内容: `T1045-TC-07` の 4 形が**各 exit 2** であることを本 PBI 内で再実測
  （起票時実測を根拠にしない）。
  **本タスクは evidence 専任**で、**`TC-07` の `ta-25` への追加は A-7 が行う**（R-014 / owner 表）
- 出力: `evidence/verification/multi-defense.md`
- 🚩 **チェックポイント**: 4 形すべて exit 2
- `rollback:` 不要（読み取り・記録のみ）

#### A-12: AC-12 — 起点そのものの解消を実測（plan Step 7）

- Owner: agent / depends_on: A-10
- 内容: `<TOKEN>` 対象の read-only 監査コマンド群（`2>/dev/null` を伴う）が通過することを実測。
  **本タスクは evidence 専任**で、**`TC-17` の `ta-25` への追加は A-7 が行う**（R-014 / owner 表）
- 出力: `evidence/verification/ac12-readonly-audit.md`
- 🚩 **チェックポイント**: 各 exit 0
- `rollback:` 不要（読み取り・記録のみ）

#### A-13: 全体検証（plan Step 8 / AC-11・AC-13）

- Owner: agent / depends_on: A-11, A-12
- 内容:
  1. `sh -n scripts/check-approval-token-write.sh`
  2. `sh tests/extras/ta-25-approval-token-guard.sh`（standalone）
  3. `sh tests/run-tests.sh`（source 経路）
  4. **CI（Linux / GNU）実行結果を取得**（plan GC-6 / R-5）
- 出力: `evidence/test-runs/`
- 🚩 **チェックポイント**: すべて **0 failed**、**pass 数 ≥ baseline**
  （**絶対件数を契約値にしない**）
- `rollback:` 不要（検証のみ）

#### A-14: handoff 発行（WF-05 / Rule 5）

- Owner: agent / depends_on: A-13
- 内容: `handoff.md` を必須 6 要素で作成。以下を**既知課題として必ず明記**:
  - **`&>/dev/null` 付き読み取りの残存誤検知**（U-2 の意図的判断 / plan R-11）
  - **完全なシェル構文解析を行わないことによる取りこぼし**（リテラル / heredoc / 変数展開 / plan GC-2）
  - **`apply-task-0123-patches.sh` の複製導線**（`67-88` 行が `scripts/hooks/` へ `cp` し
    既存時はスキップ＝**過去に適用した環境へ修正が伝播しない古い fork が残る**。
    `origin/main` に当該ファイルは**不在**で実害ゼロ。**follow-up issue を起票**して番号を記載 / R-008 / R-14）
  - **`GC-8 (ii)` による挙動変更**（R-012）: **`command -v sed` は `sed` 不在環境で
    token パス関連の全 Bash 呼び出しを block する**。方向は「厳格化」なので承認範囲上の危険は無く、
    `jq` と同契約のため新規クラスでもないが、**C-4 / 運用側が挙動差を把握できるよう 1 行残す**
  - U-6 横断調査で follow-up issue を起票した場合はその番号
- 🚩 **チェックポイント**: AC-01〜13 ごとに PASS / FAIL / WARN を記載。
  `bin/plangate doctor --check-settings` が PASS していること（settings タスクロック）
- `rollback:` `git checkout -- docs/working/TASK-1045/handoff.md`

---

## 完了条件

- [ ] AC-01〜13 がすべて PASS（`test-cases.md` の Traceability で orphan 0）
- [ ] 変異 2 方向がともに **実 TC の `[FAIL]` 出力**で kill されている
- [ ] **新変異の出力ラベルが `T1045-TC-09` / `T1045-TC-10`**（`T1023-TC-09` と衝突しない）
- [ ] **`_t25_mutate` の既存 7 呼び出しが無変更**で、既存 mutation 7 種が全 PASS（`T1045-TC-21`）
- [ ] 新規 TC が **focused 子プロセスで実行されている**ことを実測確認済み（GC-4-A の 7 件）
- [ ] **GNU `sed` 等価性が A-1b で先行検証済み**（UV-1 の解消・**`LC_ALL=C` 固定を実験条件に含む**）
- [ ] **正規化ヘルパが fail-closed**（GC-8 の 3 件が実装され
      **`T1045-TC-22`（不在 / 要件 (ii)）と `T1045-TC-22b`（失敗 / 要件 (i)）が両方 PASS**）
- [ ] **`command -v sed` が `_parse_unknown()` 定義の後に置かれている**（R-010。`rc=127` 非 block の回避）
- [ ] **`LC_ALL=C` が正規化パイプライン行に付いている**（R-016。要件 (iii) の静的検査）
- [ ] **owner 表の 23 件がすべて `ta-25` に入っている**（R-014。**スクラッチ確認で代替した TC が 0 件**）
- [ ] **RED ウィンドウが GC-4-C の 6 件と一致**し、GREEN 後に
      `T1023-TC-15pre` / `T1023-TC-17post` が **PASS へ戻っている**
- [ ] **Stop Condition / Replan Trigger が 1 件も未処理で残っていない**
- [ ] **`review-external.md` の監査表に `status = open` が 0 件**
- [ ] `T1023-TC-08` / `TC-09` を含む既存 TC が **0 failed**、pass 数 ≥ baseline
- [ ] ローカル（BSD）と CI（GNU）双方の実行結果が evidence にある
- [ ] `handoff.md` の必須 6 要素が揃い、残存誤検知が既知課題に明記されている
- [ ] 変更が `scripts/check-approval-token-write.sh` /
      `tests/extras/ta-25-approval-token-guard.sh` / `docs/working/TASK-1045/` に閉じている
