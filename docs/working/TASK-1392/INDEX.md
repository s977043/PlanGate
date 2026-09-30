# TASK-1392 INDEX

> 最終更新: 2026-09-28
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 RunState の revision CAS と accepted RunEvent の durable commit を、1 ファイルの atomic snapshot で crash-consistent に実装する計画。**モデル B**: snapshot には #1392 の transaction envelope に包んだ accepted RunEvent だけを保存し、RunState・generation・position は load のたびに導出する。冪等性は first slice に含めず、再送の二重確定は revision + position の CAS で防ぐ。event の意味論は #1391、Decision / Verification は #1393 が持つ。

## 現在のフェーズ

C-3 待ち

> **2026-09-29 追記（範囲レビュー）: main の事実との食い違い（Human 判断待ち）**
> - PR #1406（この plan）は 2026-09-29 00:04:39Z に main へ merge された。C-3 の承認記録（`approvals/c3.json`）は無い
> - issue #1392 は、その 3 分前（00:01:19Z）に PR #1402 の merge（本文の `Closes #1392`）で CLOSED（COMPLETED）になった。この plan（モデル B）は未実装
> - R-023（`run_state.py` を #1402 から外す）に反して、#1402 の複数ファイル方式の `scripts/ai-loop-v2/run_state.py` が main に入り、`delivery_runtime.py:17` が import している
> - 決めること: #1392 を reopen するか新しい issue にするか / #1402 の run_state を暫定実装として残すか、モデル B への移行順 / この plan の C-3 をどう扱うか

> **C-2 は R12 で収束（両レーンとも新しい失敗クラスなし、2026-09-28）。** 残存脅威モデルは `review-external.md` の「C-2 convergence」節。以下は経緯。

> - PR 独立レビュー（R-001〜R-004）とその敵対レビュー（R-005〜R-009）、Codex 相談（R-010〜R-013）、#1407 からの依頼（R-014〜R-016）を反映済み
> - **C-2 R1**（R-017〜R-028）: 設計レーン 2 モデルとも B を推奨 → **Human 決定: R-017 = モデル B / R-023 = #1402 から run_state を外す**。canon §4 と pbi-input を改訂済み
> - **C-2 R2**（R-029〜R-036）: **要是正・未収束**（新しいクラス 4 件）→ **Human 決定: R-029 = conflict を冪等の対象外 / R-034 = REPLANNING 中の再束縛を許可**。反映済み
> - **C-2 R3**（R-037〜R-045）: **要是正・未収束**（冪等性の層でまた新しいクラス）→ **Human 決定: 冪等性は残して記述で閉じる / 再束縛は #1391 に対応を依頼（R-043、それまで Preflight で exec 停止）**。反映済み
> - **C-2 R4**（R-046〜R-053）: **要是正・未収束**（冪等性の層で 4 ラウンド連続の新クラス、binding を渡す手段が無い critical）→ **Human 決定: 冪等性を first slice から外す（R-046）/ CAS は revision + position（R-049。冪等性を外すと遷移なし commit の再送が二重確定するため）**。binding は API 引数で渡す（R-047）。反映済み
> - **C-2 R5**（R-054〜R-059）: **要是正・未収束**（新クラス 4 件、すべて記述で閉じる。同じ token での二重確定は全経路で起きないことを確認）→ **Human 決定: 応答を失ったときの回復は単一 writer を前提（R-054）**。反映済み
> - **C-2 R6**（R-060〜R-064）: **要是正・未収束**（R5 の回復規則から新クラス 3 件、load の耐久性）→ **Human 決定: 回復規則を捨て、#1395 が stream から次の action を導き直す（R-060）**。`load_run` は lock + dir fsync の後に返す（R-061）。反映済み
> - **C-2 R7**（R-065〜R-070）: **要是正・未収束**（新クラスはすべて #1395 の回復契約の記述と非機能面。記述で閉じた。残る 2 つの保証は全入力列で破れず）。反映済み
> - **C-2 R8**（R-071〜R-076）: **要是正・未収束**（判定分裂: 設計レーン=収束 / 敵対レーン=新クラス 1。実ファイルで新クラスを確認）→ **Human 決定: #1392 に halt marker を追加（R-071）**。結果の閉じた一覧と既定の停止行も追加。反映済み
> - **C-2 R9**（R-077〜R-083）: **要是正・未収束**（判定分裂: 設計レーン=新クラス / 敵対レーン=収束。両レーン共通で step 14 失敗〜marker 永続化の crash の窓）→ **Human 決定: replace 前に pending marker を書く（R-077）**。marker の判定・lock 後検査・halt_run の結果・Human の解除手順も追加。反映済み
> - **C-2 R10**（R-084〜R-089）: **要是正**（判定分裂: 設計レーン=新クラス 1（記述で閉じる）/ 敵対レーン=収束。両レーンとも設計変更不要。pending の全段階でコア保証は破れず）。記述で閉じ、`load_run` の flush を削除（オーガナイザー判断、R-089）。反映済み
> - **C-2 R11**（R-090〜R-094）: **要是正**（判定分裂: 設計レーン=収束 / 敵対レーン=新クラス 1（Run 間で共有するディレクトリの flush エラー消費）。両レーンとも設計変更不要）→ **Human 決定: 1 回の呼び出しの dir flush は事前に開いた 1 つの dirfd で行う（R-090）**。反映済み
> - **C-2 R12**（R-095〜R-098）: **収束**（両レーンとも新しいクラスなし）。是正漏れ（root の差し替え検出・dirfd への束縛・対象 OS の位置づけ・tmp 残骸の flush 失敗）を記述で閉じた
> - C-1 は R12 の反映後に再実行済みで、判定は **PASS with WARN**（WARN は C-3 の判断事項。`review-self.md`）

## 次のアクション

1. **Human C-3**。判断事項:
   - [P1] WAL なしの単一 snapshot（モデル B）と、容量上限・durability の定義・flush 回数（commit あたり 5 回）
   - [P2] CAS の保証を同じ `runtime_root` の中に限る扱い
   - 暫定値（`MAX_EVENTS_PER_RUN` / `MAX_SNAPSHOT_BYTES` / `TERMINAL_RESERVE` / `MAX_CONFLICTS_PER_POSITION` / `LOCK_WAIT_TIMEOUT` / `MAX_REDERIVE_PER_POSITION` / `MAX_BUSY_RETRIES` / `MAX_HALT_BUSY_RETRIES`）を fixture で確定する進め方
   - 残存脅威モデルの受け入れ（とくに Linux 4.13 未満・macOS での Run 間の flush エラー消費）
2. C-3 承認後も、exec は #1391 が consumable になり（todo Preflight の条件）、#1329 preflight を通ってから

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・責務境界（R-017 の改訂注記あり） |
| plan.md | exec, review | 実行計画（未承認） |
| todo.md | exec | タスク一覧・進捗（Preflight に #1391 consumable の条件） |
| test-cases.md | exec, review | テストケース定義（ST-01〜ST-46。取り下げた ST は冒頭の注記を参照） |
| review-self.md | C-3, review | C-1 結果（最新の節が有効） |
| review-external.md | C-3, review | R-001〜R-098、Human 決定、残存脅威モデル（追記専用） |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

plan 段階のため実装ファイルは未確定。永続化 module（lock / strict loader / envelope と fold / commit / conflict）とテスト一式。CLI は追加しない。本 PR は canon `docs/ai/ai-loop-v2/artifact-responsibilities.md` §4 も改訂する。
