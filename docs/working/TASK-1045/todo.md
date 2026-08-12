# EXECUTION TODO — TASK-1045

> 計画: [`plan.md`](./plan.md) / テスト: [`test-cases.md`](./test-cases.md)
> Mode: **`critical`** / `lite_eligible=false` / **人間 C-3 必須・同期**
> L-0 / V-1〜V-4 / PR 作成は `workflow-conductor` が自動制御するため本 ToDo には含めない。

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
- **判断を要する論点**（plan §Questions / Unknowns）:
  - **Q-1**: Mode を `critical` のままとするか `high-risk` へ引き下げるか
    （引き下げても `lite_eligible=false` と同期 C-3 は維持）
  - **Q-2**: U-2（`&>` / `&>>` を block 維持）でよいか
    （`&>/dev/null` 付き読み取りは**残存誤検知**になる）
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
- 出力: `evidence/verification/baseline.md`
- 🚩 **チェックポイント**: baseline が **0 failed**。そうでなければ **exec を止めて人間へ**
- `rollback:` 不要（読み取り・記録のみ）

---

### フェーズ 2: 実装（**H-1 承認後にのみ開始**）

#### A-2: RED — 誤検知解消 TC を focused 群へ追加（plan Step 2）

- Owner: agent / depends_on: A-1, **H-1**
- 内容: `T1045-TC-01` / `TC-02` / `TC-03` / `TC-20` を
  **`ta-25` の `222` 行より前（focused 群）**へ追加
- 🚩 **チェックポイント**: この時点で **`T1045-TC-01`〜`03` が FAIL する**（RED 成立）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-3: RED — 退行防止 TC を focused 群へ追加（plan Step 2）

- Owner: agent / depends_on: A-2
- 内容: `T1045-TC-04` / `TC-05` / `TC-06` を **focused 群**へ追加
- 🚩 **チェックポイント**: この時点で **PASS**（修正前でも通るべき TC＝退行防止の基準線）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-4: focused 群配置の実測確認（plan GC-4(b) / R-7）

- Owner: agent / depends_on: A-3
- 内容: `PG_T25_MUTATION_CHILD=1` で `ta-25` を子プロセス実行し、
  **`T1045-TC-01`〜`06` / `TC-20` のラベルが出力に現れる**ことを目視確認
- 🚩 **チェックポイント**: 1 件でも現れなければ **focused 群外に置かれている**
  → 配置を修正するまで先へ進まない（#874 同型の空振り防止）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-5: GREEN — `_strip_nonwrite_redirects()` 実装（plan Step 3）

- Owner: agent / depends_on: A-4
- 内容: `scripts/check-approval-token-write.sh` に正規化ヘルパを追加
  - (1) fd 複製 / クローズ除去（`>&` の直後が **数字列 or `-`** のときのみ）
  - (2) `/dev/null` 破棄除去（**語境界**必須 / **直前が `&` なら除去しない**）
  - **POSIX BRE のみ**（GNU 拡張禁止 / plan GC-6）
- 🚩 **チェックポイント**: `sh -n` PASS
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh`

#### A-6: GREEN — `_has_write_intent()` のリダイレクト検査を置換（plan Step 3）

- Owner: agent / depends_on: A-5
- 内容: `48` 行の `grep -q '>'` を「正規化 → 残存 `>` 判定」の 2 段へ置換し、
  一意アンカー **`# t1045-redirect-normalize`** / **`# t1045-file-redirect`** を付す
- 🚩 **チェックポイント**:
  - **アンカー 2 種が各 `grep -c` == 1**（実測 / R-6）
  - `T1045-TC-01`〜`06` / `TC-20` が **全 PASS へ転じる**
  - **`T1023-TC-08` / `TC-09` が PASS を維持**（plan GC-3）
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh`

#### A-7: 除外条件の境界 TC を追加（plan Step 2 / R-3・R-4・U-1・U-2・GC-2）

- Owner: agent / depends_on: A-6
- 内容: `T1045-TC-11`〜`15` / `TC-19` を通常群へ追加
- 🚩 **チェックポイント**: 全 **rc=2**（除外が広がりすぎていないことの機械確認）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-8: block メッセージへ `rule=<id>` を付与（plan Step 4）

- Owner: agent / depends_on: A-6
- 内容: `_has_write_intent()` が一致ルール ID を返し `_block()` detail に載せる（6 ID）。
  併せて `T1045-TC-08` を追加
- 🚩 **チェックポイント**: `BLOCK` / `target=` / `file_path=` / `parse-unknown` / `bypass` を
  assert する**既存 TC がすべて PASS を維持**
- `rollback:` `git checkout -- scripts/check-approval-token-write.sh tests/extras/ta-25-approval-token-guard.sh`

#### A-9: 変異 (a)「修正前へ戻す」を追加（plan Step 5 / AC-08）

- Owner: agent / depends_on: A-8
- 内容: `_t25_mutate` 呼び出しを追加（`t1045-redirect-normalize` を no-op 化 / kill 対象 `T1045-TC-01`）
- 🚩 **チェックポイント**: **`[FAIL] T1045-TC-01` が実出力に現れ、子プロセス rc が非 0**
  （申告ではなく実出力を evidence に残す）
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

#### A-10: 変異 (b)「弱める側」を追加（plan Step 5 / AC-09）

- Owner: agent / depends_on: A-9
- 内容: `_t25_mutate` 呼び出しを追加（`t1045-file-redirect` を常に false 化 / kill 対象 `T1045-TC-04`）
- 🚩 **チェックポイント**: **`[FAIL] T1045-TC-04` が実出力に現れ、子プロセス rc が非 0**。
  **これが plan GC-1（弱体化禁止）の機械的担保**であり、空振りしたまま先へ進まない
- `rollback:` `git checkout -- tests/extras/ta-25-approval-token-guard.sh`

---

### フェーズ 3: 検証

#### A-11: 併記回避の多重防御を再実測（plan Step 6 / AC-07）

- Owner: agent / depends_on: A-10
- 内容: `T1045-TC-07` の 4 形が**各 exit 2** であることを本 PBI 内で再実測
  （起票時実測を根拠にしない）
- 出力: `evidence/verification/multi-defense.md`
- 🚩 **チェックポイント**: 4 形すべて exit 2
- `rollback:` 不要（読み取り・記録のみ）

#### A-12: AC-12 — 起点そのものの解消を実測（plan Step 7）

- Owner: agent / depends_on: A-10
- 内容: `<TOKEN>` 対象の read-only 監査コマンド群（`2>/dev/null` を伴う）が通過することを実測
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
  - U-6 横断調査で follow-up issue を起票した場合はその番号
- 🚩 **チェックポイント**: AC-01〜13 ごとに PASS / FAIL / WARN を記載。
  `bin/plangate doctor --check-settings` が PASS していること（settings タスクロック）
- `rollback:` `git checkout -- docs/working/TASK-1045/handoff.md`

---

## 完了条件

- [ ] AC-01〜13 がすべて PASS（`test-cases.md` の Traceability で orphan 0）
- [ ] 変異 2 方向がともに **実 TC の `[FAIL]` 出力**で kill されている
- [ ] 新規 TC が **focused 子プロセスで実行されている**ことを実測確認済み
- [ ] `T1023-TC-08` / `TC-09` を含む既存 TC が **0 failed**、pass 数 ≥ baseline
- [ ] ローカル（BSD）と CI（GNU）双方の実行結果が evidence にある
- [ ] `handoff.md` の必須 6 要素が揃い、残存誤検知が既知課題に明記されている
- [ ] 変更が `scripts/check-approval-token-write.sh` /
      `tests/extras/ta-25-approval-token-guard.sh` / `docs/working/TASK-1045/` に閉じている
