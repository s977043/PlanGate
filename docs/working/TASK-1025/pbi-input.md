# PBI INPUT PACKAGE — TASK-1025

> Issue: [#1025](https://github.com/s977043/plangate/issues/1025)（**priority:P0** / ai-loop / architecture / governance）
> EPIC: [#870](https://github.com/s977043/plangate/issues/870)（Parent）。[#869](https://github.com/s977043/plangate/issues/869) の **before**（外側 Evolution Loop の前提）
> 起点インシデント: [#1023](https://github.com/s977043/plangate/issues/1023) / [PR #1024](https://github.com/s977043/plangate/pull/1024)（**MERGED**）の Human C-3 待機中に発生した TTY 入力ハンドル消失
> 作成: 2026-08-10 / **base `408cebb`（当時の `origin/main`）で全数実測**。行番号は目安、記号アンカー（関数名・定数名・パス）を正とする
> **先行成果物あり**: ブランチ `feature/TASK-1025-durable-run`（plan-only commit `5414b89`）に plan package が存在し、独立 C-2 が **reject**（critical 1 / major 6 / minor 1）。本 PBI INPUT はその C-2 指摘（特に finding 7 = legacy `c3.json` の binding 不足）を**要件層に引き上げて**再構造化したものである

---

## Context / Why

### 何が起きたか（観測事実）

`#1023` / PR `#1024` の Human C-3 待機で、**Plan hash・PR head・作業ツリーはいずれも不変**だったにもかかわらず、承認が成立していない状態で **同じ Human 要求（承認 nonce）が繰り返し発行**された。原因は「承認機能の欠陥」ではなく、**Human 待機という中断点がプロセス内状態にしか存在せず、Run の正本状態として永続化されていない**ことにある。

この構造は実装上も確認できる（base `408cebb` 実測）:

| 観測点 | 実測結果 |
|--------|---------|
| 承認 nonce の生存範囲 | `bin/plangate` の `_plangate_presence_gate()` が `secrets.token_hex(4)` を**その場で生成し同一プロセスの stdin から読む**。プロセス外に残らない設計であり、stdin ハンドルを失うと**必ず新しい nonce になる** |
| 承認要求の記録 | 試行の監査は `docs/working/_audit/hook-events.log` に出るが、**同ファイルは `.gitignore` 対象**（`.gitignore:21`）。リポジトリ内から「同じ要求を既に出したか」を機械判定できない |
| Run の機械正本 | `docs/working/ai-loop-runs/*.json` は arbiter の**単発裁定 record**。実測（`20260805T055117Z-cc70a91-run030-r2.json`）のキーは `decision` / `gates` / `run.run_id` / `run.round_index` / `target_sha` 等で、**`status` / `phase` / `current_node` / `pending_action` / `plan_hash` を持たない** |
| 待機・再開の語彙 | `docs/workflows/ai-loop/*.md` 全 16 ファイルを `WAITING_HUMAN` / `resume` / 「再開」/「中断」の 4 パターンで grep したヒットは **`delivery-state-machine.md` の 1 行のみ**。Run レベルの待機・再開契約は文書としても存在しない |
| 人間向けビュー | `current-state.md` を機械参照しているのは `bin/plangate` と `scripts/precompact-memory-guard.sh` のみで、`scripts/ai-loop/` からの参照は 0 件。**現状すでに機械正本ではない**（issue の「機械正本にしない」は現状追認） |

### 既に存在するもの（重複実装を避けるための確認）

**intent / receipt 契約そのものは未実装ではない。** `scripts/ai-loop/delivery.py` に既に以下がある（`delivery-state-machine.md` §6 が正本）:

- `action_id = sha256(canonical action payload)` による stable action ID
- `entry_id = sha256(canonical entry〔timestamp 除外〕)` による冪等 append
- 「intent あり・receipt なし → 再要求 / receipt あり → 抑止」の 2 段書き込み
- `--now` 注入による決定論、fail-closed 判定

**ただしその適用範囲は delivery 層（PR 作成後の CI / レビュー収束）に閉じている。** 記録先は `docs/working/TASK-XXXX/delivery/record.jsonl` で、対象 action は `repair_ci` / `repair_review` / `resolve_conflict` の 3 種。**PR 以前の Run 全体、および Human 承認待機はこの契約の外**にある。

同様に `scripts/ai-loop/run_evidence.py`（RunEvidence）も**終端 run のみを対象**とし、`run-evidence-contract.md` §0 U-4 が「非終端 run は `EV` を発行しない」と明記している。したがって **RunEvidence は再開用の state として使えない**。

### したがって本 PBI が埋める穴

**「delivery 層で実証済みの intent / receipt・決定論・fail-closed パターンを、Run 全体（特に Human / External 待機）へ引き上げ、会話履歴・生存プロセス・特定 Agent に依存せずに再開できる機械正本を置く」**こと。これが無い限り、`#869` の外側 Evolution Loop も `#1035`（HOITL → HOTL 自律度ラダー）も「1 Run を安全に中断・再開できる」前提を欠いたまま積み上がる。

---

## What（Scope）

### In scope

1. **Durable Run State v1**（機械正本の新設）
   - 永続フィールド: `run_id` / `task_id` / `revision` / `phase` / `current_node` / `status` / `plan_hash` / `source_sha` / `harness_version` / `pending_action`（0 または 1 件）/ `last_error`（**観測事実と原因仮説を分離**）/ `updated_at`
   - `status` enum: `RUNNING` / `WAITING_HUMAN` / `WAITING_EXTERNAL` / `BLOCKED` / `COMPLETED`
   - 原子的書き込み（同一 directory の一時ファイル + `os.replace`）と `revision` による compare-and-swap
2. **Durable Action Intent / Receipt（Run レベル）**
   - canonical payload からの stable `action_id`、intent 先行永続化、receipt 済みの再要求抑止、intent 済み・receipt 未了は**同一 `action_id` の再提示**
   - unknown / corrupt / binding mismatch は **fail-closed**
3. **Human Interrupt / Resume 契約**
   - `HumanActionRequest`（`kind` / `action_id` / `task_id` / `plan_hash` / `source_sha` / `requested_at` / `instructions_ref`）の永続化と `WAITING_HUMAN` 停止
   - resume 時に **artifact の存在だけでなく binding（task_id / plan_hash / source_sha / action_id）を再照合**し、stale / duplicate / 別 Run の receipt を拒否
   - 別セッション・別 Agent からの再開
4. **`WAITING_EXTERNAL`** を同一 intent / receipt 契約で扱う（CI・外部検証待ち。手続き層は `#938` 側）
5. **Incident Evidence event**: `approval_session_lost` / `human_request_reissued_prevented` / `resume_binding_mismatch` / `state_corrupt` / `external_wait_resumed`
6. **成果物**: 非 HO の独立モジュール（`scripts/ai-loop/durable_run.py` 相当）+ 単体テスト + 契約文書（`docs/workflows/ai-loop/` 配下）+ **CI 実行経路（`tests/extras/ta-NN-*.sh`）**
   - 既存 `tests/run-tests.sh` は `tests/extras/ta-*.sh` を glob で source する構造（`tests/run-tests.sh` 冒頭コメント）。`ta-56-delivery.sh` が `python3 scripts/ai-loop/test_delivery.py` を実行する先例と同型で配線する

### Out of scope

| 除外対象 | 理由 |
|---------|------|
| `bin/plangate` への統合・`approve` / nonce 機構の変更 | **HO-core**（`ho-paths.md`）。issue が「v1 は非 HO の独立モジュール」と明記 |
| `schemas/**` への JSON Schema 追加 | **HO-schema**（`ho-paths.md` は `schemas/**` 全体を HO 指定）。内部 validator + contract emit で固定し、schema 昇格は別 Human 判断 |
| `scripts/hooks/**` / `.github/workflows/*.yml` / `.claude/rules/*.md` / `CLAUDE.md` / `AGENTS.md` の変更 | HO 対象 |
| `**/approvals/*.json` の**書き込み**（c3.json / c3-prime / maintenance 等） | **HO-approval**。本実装は読み取り専用でのみ参照する |
| `c3-approval.schema.json` への `run_id` / `action_id` / `source_sha` 追加 | HO かつ **Human 判断待ち**（後述 Unknowns U-1 の案 B） |
| `.plangate.yml` の `c3_approval.mode` 変更 | 承認モードは Human-owned 設定 |
| C-3 / C-4 / merge の AI-owned 化、nonce / 承認 artifact の AI 代理発行 | **AI の承認権限を増やさない**（issue 明記 / `responsibility-classes.md`） |
| 常駐 daemon・外部 DB・外部 SaaS の導入 | issue Non-goals |
| `#869` の candidate generation / canary / promotion 全体 | 本 PBI はその**前提**のみ |
| `#1031`（Plan-first 正式入口）との配線 | 入口が未開通（`bin/plangate` に `ai-loop` dispatch 0 件 = `#982`）。本 PBI は入口非依存のモジュールとして完結させる |
| `current-state.md` の一括移行・既存 `docs/working/ai-loop-runs/*.json` の形式変更 | RunEvidence 契約が「arbiter record を置き換えない」と明記。追加はしても置換しない |
| `#938`（conductor の待機・再開手順書）の記述 | 本 PBI は機械状態、`#938` は手続き・エージェント指針 |

---

## 受入基準

> **設計方針**: 「塞ぐ」ではなく「塞いだことを機械的に再実行して検証できる」形で書く。
> **1 原因が複数の消費箇所を壊すケースでは、消費箇所ごとに AC を分割**し、片側だけ直して全体が PASS しない構造にする（binding 検証・破損検出は特にこれを適用）。
> 括弧内は issue #1025 の原 AC（AC-1〜AC-10）との対応。

### A. 永続化と復元

- [ ] **AC-01**（原 AC-1）: state を書いたプロセスが**終了した後**、別プロセスが同じ `run_id` / `revision` / `pending_action` を復元できる。同一プロセス内キャッシュに依存していないことを、書込プロセスと読込プロセスを分離した fixture で示す
- [ ] **AC-02**: 書き込みが途中で中断しても、読込側が「有効な旧版」か「明示エラー」のいずれかに収束する（部分書き込みの state を成功として読まない）。一時ファイル残存・`os.replace` 前後の中断を注入した fixture で示す
- [ ] **AC-03**: 同一 state への並行更新で `revision` compare-and-swap が働き、**lost update が起きない**。stale `revision` での更新要求は拒否され、拒否理由が識別可能な形で返る
- [ ] **AC-04**: `status` は `RUNNING` / `WAITING_HUMAN` / `WAITING_EXTERNAL` / `BLOCKED` / `COMPLETED` の 5 値に閉じ、**契約は単一定義**（コード内定数）から機械 emit され、契約文書のブロックと**byte 一致**が検査される（`delivery.py contract` / `ta-56` と同型の doc drift 検出）

### B. Human 待機と要求の非増殖（**#1023 の再発防止本体**）

- [ ] **AC-05**（原 AC-2）: `WAITING_HUMAN` へ遷移すると、stable `action_id` を持つ `HumanActionRequest` が**ちょうど 1 件**記録される。必須フィールド `kind` / `action_id` / `task_id` / `plan_hash` / `source_sha` / `requested_at` / `instructions_ref` の欠落は fail-closed
- [ ] **AC-06**（原 AC-3）: 同一入力で step / resume を **N 回**（N≧3）実行しても、Human request 件数と `action_id` 集合が**初回実行後と同一**であること。件数を絶対値で固定せず「1 回目実行後の集合との同値照合」で検証する
- [ ] **AC-07**（原 AC-9 / **#1023 回帰**）: 「intent 永続化後に呼び出しプロセス（TTY）が消失し、別プロセスが resume する」fixture で、**新規 `action_id` を発行せず同一 request を再提示**する。旧実装（= state 非永続）を模した比較経路では同 fixture が FAIL することを示し、テストの検出力を実証する（変異注入は request 発行の call site を壊す）
- [ ] **AC-08**: `human_request_reissued_prevented` イベントが AC-07 の経路で実際に記録される（抑止したことが証跡に残る）

### C. binding 再検証（**消費箇所ごとに分割**）

> 同一の「binding 照合が甘い」原因が 4 箇所を壊しうるため、4 本に分ける。

- [ ] **AC-09**（原 AC-5-a）: **state ロード時**に `task_id` が保存先ディレクトリと不一致なら fail-closed で停止する
- [ ] **AC-10**（原 AC-5-b）: **`WAITING_HUMAN` からの resume 時**に `task_id` / `plan_hash` / `source_sha` / `action_id` のいずれか 1 つでも不一致なら fail-closed で停止する（4 フィールド**それぞれ**を単独で不一致にした 4 ケースを個別に検証する）
- [ ] **AC-11**（原 AC-5-c / AC-8）: **`WAITING_EXTERNAL` からの resume 時**にも AC-10 と同一の binding 検証が適用される（Human 経路だけ直して External が素通りしない）
- [ ] **AC-12**（原 AC-4）: **receipt 消費時**に、receipt が (a) 既消費 / (b) 別 Run の `run_id` 由来 / (c) 別 `action_id` 宛 のいずれかなら拒否する。3 ケースを個別に検証する
- [ ] **AC-13**: binding 不一致時に `resume_binding_mismatch` イベントが記録され、**不一致フィールド名**が識別できる（どの照合で落ちたかがトレースできる）

### D. 破損・退行の不受理

- [ ] **AC-14**（原 AC-6-a）: state / record の JSON 破損・切り詰めを成功扱いにしない。`state_corrupt` イベントを記録して停止する
- [ ] **AC-15**（原 AC-6-b）: **未知 enum**（未知 `status` / 未知 event kind / 未知 action kind）を成功扱いにしない。将来値の握り潰しをしない
- [ ] **AC-16**（原 AC-6-c）: **`revision` の後退**（保存済みより小さい `revision` での上書き）を拒否する
- [ ] **AC-17**: append-only record の改竄（既存 entry の書き換え・順序入れ替え）を読込時に検出する。検出根拠は entry の再計算 ID に基づき、**「壊した record が PASS しない」ことを注入 fixture で示す**

### E. 承認境界の不変（**AC-07 と並ぶ最重要**）

- [ ] **AC-18**（原 AC-7-a）: 本実装は `**/approvals/*.json` を**書き込まない**。ソース走査で「approvals 配下への書き込み経路が存在しない」ことを機械検査する（`ta-56` が `"MERGED"` の非出現を走査で固定する先例と同型）
- [ ] **AC-19**（原 AC-7-b）: 本実装は merge 系操作（`gh pr merge` / `git push` を含む外部作用）を実行しない。**ネットワーク・外部プロセス呼び出しを行わない純判定器**であることを走査で固定する
- [ ] **AC-20**（原 AC-7-c）: Human 承認 artifact は既存正規経路（`bin/plangate approve` の L1〜L4 presence gate）でのみ発行され、本実装はそれを**読み取り専用**で検証する。承認 artifact が無い状態で `WAITING_HUMAN` から先へ進む経路が存在しないことを負側テストで示す
- [ ] **AC-21**: 本実装の記録に**生ログ本文・秘匿値を格納しない**（`.jsonl` は EH-8 の走査対象外という既知ギャップがあるため、契約側で禁止し検査する）

### F. 回帰と CI 配線

- [ ] **AC-22**（原 AC-10-a）: 新規 Python 単体テストが **CI 実行経路に乗る**。`tests/extras/ta-NN-*.sh` を追加し、`sh tests/run-tests.sh` の出力に当該ブロックが現れることを実測ログで示す（**追加しただけで走っていない状態を PASS にしない**）
- [ ] **AC-23**（原 AC-10-b）: 既存 ai-loop 回帰テスト（`scripts/ai-loop/test_*.py` および関連 `ta-*.sh`）が本変更後も PASS する。**総数を契約値にせず**、変更前 baseline との差分（新規 PASS の増加のみ・FAIL 増ゼロ）で判定する
- [ ] **AC-24**（原 AC-10-c）: `git diff --check` が PASS する
- [ ] **AC-25**: contract / implementation / tests / 契約文書が**同一 PR に揃う**（issue DoD）。PR は MERGE_READY まで整備し、**C-4 / merge の前で停止**する

---

## Notes from Refinement

> 判断の正本は [`decision-log.jsonl`](./decision-log.jsonl)（スキーマ: [`decision-log-schema.md`](../templates/decision-log-schema.md)）。不採用案とその理由は `alternatives_rejected` に構造化記録する。

1. **既存 intent / receipt を再実装しない。** `delivery.py` の canonical hash / stable `action_id` / `entry_id` 冪等 append / `--now` 注入の決定論は**実装済みパターン**であり、Run レベルへの一般化にあたっては可能な限り再利用または同型踏襲とする（`#873` / `#917` の再利用は issue にも明記）。二重実装は契約の分岐を生む。
2. **`current-state.md` は人間向けビューのまま。** 現状すでに `scripts/ai-loop/` からの機械参照は 0 件であり、issue の指示は現状追認である。移行作業は発生しない。
3. **arbiter record（`docs/working/ai-loop-runs/*.json`）は置換しない。** RunEvidence 契約が「arbiter record の後継ではなく上位 artifact」「置き換えも移行も行わない」と定めており、Durable Run State も同じ立場を取る（3 系統が並立するため、契約文書で役割分界を明示することが必須）。
4. **RunEvidence は resume 用 state にならない。** `run-evidence-contract.md` §0 U-4 が非終端 run の `EV` 非発行を既定としているため、中断地点の復元には使えない。役割は排他ではなく直交（EV = 終端証跡、Run State = 進行中正本）。
5. **判定基盤 carve-out に該当する。** `rollout-policy.md` §2 の carve-out は `scripts/ai-loop/**` と `docs/workflows/ai-loop/**` を glob で対象としており、本 PBI の主成果物は**両方に該当**する。したがって ai-loop の auto-approve 帯には入らず、**Human C-3 へ escalate 固定**。ただし同節が明記するとおりこれは**規範層**であり、`arbiter.py` の `boundary_check` は ho-paths 由来でしか判定しないため **`boundary=clean` と機械判定される**（機械層は fail-open）。実行者が escalate する責務を負う点を plan / todo に明示すること。
6. **HO 該当パスの切り分け（実測）**: `ho-paths.md` の HO 表に `scripts/ai-loop/**` は**無い**（HO は `scripts/hooks/**`）。一方 `schemas/**` と `**/approvals/*.json` は HO。したがって「独立モジュール + 内部 validator」構成なら HO 直接編集は回避できるが、**承認境界周辺の変更であることは変わらない**（`mode-classification.md`）。
7. **先行ブランチの C-2 は reject 状態。** `feature/TASK-1025-durable-run` の独立 C-2 は critical 1 / major 6 / minor 1 で reject。うち finding 5（`tests/run-tests.sh` への CI 経路）は本 INPUT で **AC-22** として要件化、finding 1〜4（プロセス間ロック / crash-consistent な commit protocol / 内部での canonical binding 解決 / record の tail・件数 cross-binding と rollback テスト）は **AC-02 / AC-03 / AC-09〜AC-13 / AC-17** に反映済み。**finding 7 のみ Human 判断が未了**（Unknowns U-1）。
8. **本 PBI で AI の承認権限を増やさない。** `responsibility-classes.md` の Human-owned（承認 artifact 発行 / merge）は不変。これを AC-18〜AC-20 で**機械検査可能な形**に落とす。

---

## Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和 |
|----|-------|------|------|
| R-1 | **承認境界の実質的緩和**。resume 側の binding 検証が甘いと「AI が自分で進める経路」が生まれ、承認迂回になる | 致命的（統制崩壊） | AC-10〜AC-13 で消費箇所ごとに fail-closed を固定 + AC-18〜AC-20 でソース走査による経路非存在を検査 |
| R-2 | **3 系統の状態表現の並立**（arbiter record / RunEvidence / Run State）による正本の分裂 | 高（どれが真かで運用が割れる） | 契約文書で役割分界を明示（Notes 3・4）。既存 2 系統を変更しない |
| R-3 | **プロセス間の同時実行**。`os.replace` は原子的でも read-modify-write 全体は原子的でなく、CAS だけでは ABA / 競合窓が残る | 高（state 巻き戻し） | AC-03。C-2 finding 1 が要求するプロセス間ロックの要否は plan で決める（AC は「lost update が起きない」を要求し、実現手段を縛らない） |
| R-4 | **state と append-only record の crash 整合**。2 ファイルの片方だけが更新された中断状態 | 高 | AC-02 + AC-17。commit protocol（順序と復旧規則）を契約文書で固定 |
| R-5 | **fail-open な機械層への依存**。carve-out は規範層のみで `arbiter.py` は clean と判定する | 中（誤って auto-approve 帯に入る） | Notes 5 を plan / todo に明示し、Human C-3 同期を固定 |
| R-6 | **Human 承認が「artifact の存在」だけで通ってしまう**。legacy `c3.json` は `run_id` / `action_id` / `source_sha` を持たない（schema 実測: required 6 + optional `source` / `conditions` / `rejection_reason` / `gate_checks`、`additionalProperties: false`） | 高 | U-1 の Human 判断待ち。案 A なら「非暗号的な信頼限界」を契約文書に明記することが必須条件 |
| R-7 | **テストが空振りする**（新規テストが実は何も検出していない） | 中 | AC-07 で変異注入による検出力実証を要求。AC-22 で CI 実走を要求 |
| R-8 | **`.jsonl` は EH-8 privacy 走査の対象外**（`delivery-state-machine.md` の既知ギャップ） | 中 | AC-21 で契約側禁止 + 検査 |
| R-9 | AC 25 件・新規契約の導入で **scope が肥大**し 1 PR に収まらない | 中 | plan で縦切りの分割可否を判断。ただし issue DoD が「contract / implementation / tests が同一 PR」を要求している点と両立させる |

### Unknowns

| ID | 不明点 | 誰が決めるか | 決まらない場合の既定 |
|----|-------|------------|-------------------|
| **U-1** | **legacy `c3.json` に `run_id` / `action_id` / `source_sha` が無い**ため、artifact レベルでの厳密な cross-run binding が証明できない。**案 A**（HO 不変。C-3 を plan 権威として扱い、その digest を run / action / source へ台帳側で束縛し、**非暗号的な信頼限界を明記**）/ **案 B**（Human-owned な CLI / schema 拡張を別 PBI として切り出し、action 束縛 receipt を発行） | **Human**（issue #1025 コメントで既に決定依頼済み） | **決まるまで着手しない**（案により AC-10 / AC-12 / AC-20 の検証可能範囲が変わるため、後から差し替えると承認済み plan の hash が無効化する） |
| U-2 | state / record の**配置先**。issue は指定していない。`docs/working/TASK-XXXX/run-state/`（delivery 層と同型のタスク配下）か、`docs/working/ai-loop-runs/` 配下か | plan フェーズ | タスク配下（`delivery/record.jsonl` の先例に合わせる）。`approvals/` 配下には**置かない**（HO） |
| U-3 | `harness_version` の供給元。RunEvidence は `{plugin_version, cli_version, corpus_hash}` を**注入**で受けており、自動取得の実装は無い | plan フェーズ | 注入必須（決定論を壊さない）。取得不能は fail-closed |
| U-4 | `phase` / `current_node` の値域。既存の語彙が複数ある（PlanGate フェーズ A〜C-4 / delivery 7 状態 / arbiter 3 値 decision） | plan フェーズ | 既存語彙を**再定義せず参照**する。新語彙を作る場合は契約文書で対応表を持つ |
| U-5 | プロセス間ロックの実現手段（`fcntl.flock` / lock ファイル / CAS リトライのみ）と、その CI / macOS / Linux での可搬性 | plan フェーズ | AC-03 を満たす最小手段。判定不能なら安全側（ロックあり） |
| U-6 | **`#1023` の一次証跡が repo に無い**（`hook-events.log` が `.gitignore` 対象）。AC-07 の fixture は実ログの replay ではなく**構造再現の合成 fixture**になる | plan フェーズ | 合成 fixture とし、「実インシデントの replay ではない」ことを test docstring と契約文書に明記する（証跡の格上げをしない） |
| U-7 | `#1031`（Plan-first 正式入口）で `bin/plangate ai-loop` が開通した場合の配線タイミング | Human / 後続 PBI | 本 PBI は入口非依存。配線は follow-up |

### Assumptions

| ID | 前提 | 検証状況 |
|----|------|---------|
| A-1 | Python 3 標準ライブラリのみで完結できる（外部依存を追加しない） | 既存 `scripts/ai-loop/*.py` が全て標準ライブラリ構成であることを確認 |
| A-2 | `tests/extras/ta-*.sh` を追加すれば `sh tests/run-tests.sh` が glob で拾う | `tests/run-tests.sh` 冒頭の構成コメントで確認。実走は AC-22 で実測する |
| A-3 | `scripts/ai-loop/**` は HO 対象**外**（HO は `scripts/hooks/**`）であり、AI が直接編集できる | `docs/ai/ai-loop/ho-paths.md` の HO 表を全数確認 |
| A-4 | `docs/working/**`（`approvals/` を除く）は AI 書き込み可能 | `ho-paths.md` の HO-approval は `**/approvals/*.json` のみ |
| A-5 | `delivery.py` の intent / receipt 契約は本 PBI 期間中に破壊的変更を受けない | `#873` / `#917` は実装済み・`delivery-state-machine.md` が正本として固定 |
| A-6 | Human C-3 は `bin/plangate approve`（`source: "cli"`）が生成する `c3.json` を正規経路とする。ただし `approved_by` は git-config 由来で**暗号的検証がされていない**（`c3.json` 自身が `_approver_identity_unverified: true` を持つ） | `bin/plangate` の `cmd_approve()` 実装を確認。U-1 / R-6 の前提でもある |

---

## Mode（想定）

| 判定軸 | 値 | 根拠 |
|--------|---|------|
| 受入基準数 | 25 → **critical**（11+） | 上記 AC |
| 変更ファイル数（見込み） | 4〜6 → high-risk 寄り | module / test / 契約 doc / `ta-NN` / 作業ドキュメント |
| 例外ルール | **承認境界周辺 → 最低「高」** | `mode-classification.md`（Human 承認待機の状態管理そのもの） |
| carve-out | `scripts/ai-loop/**` + `docs/workflows/ai-loop/**` に該当 | `rollout-policy.md` §2（**規範層 escalate 固定**） |

**想定モード: `critical`（安全側既定）。最低でも `high-risk`。** `lite_eligible=false`・**Standard 同期 C-3 固定**（`working-context.md` AC-10 Hardening Override / AC-8 安全側）。ai-loop の auto-approve 帯には**入らない**。plan フェーズで `high-risk` へ下げる場合は根拠を明示すること。

---

## 参照した一次ソース

- issue: `#1025`（本文 + コメント 1 件）/ `#1023` / `#1031` / `#938` / PR `#1024`（MERGED）
- 実装: `scripts/ai-loop/delivery.py` / `scripts/ai-loop/run_evidence.py` / `bin/plangate`（`cmd_approve` / `_plangate_presence_gate`）/ `tests/run-tests.sh` / `tests/extras/ta-56-delivery.sh`
- 契約: `docs/workflows/ai-loop/delivery-state-machine.md` / `run-evidence-contract.md` / `rollout-policy.md` / `00_concept.md` / `execution-runbook.md`
- 境界: `docs/ai/ai-loop/ho-paths.md` / `.claude/rules/mode-classification.md` / `.claude/rules/responsibility-classes.md` / `.claude/rules/working-context.md`
- schema: `schemas/c3-approval.schema.json` / `schemas/c3-prime.schema.json` / `schemas/run-event.schema.json`（run state 用 schema は**存在しない**ことを確認）
- 実データ: `docs/working/ai-loop-runs/20260805T055117Z-cc70a91-run030-r2.json` ほか / `.gitignore`
