# TASK-1392 INDEX

> 最終更新: 2026-09-25 16:40
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 RunState の revision CAS と accepted RunEvent の durable commit を、1 ファイルの atomic snapshot（state + events + 冪等性台帳）で crash-consistent に実装する計画。event の意味論は #1391、Decision / Verification は #1393 が持つ。

## 現在のフェーズ

C-2

> PR #1406 の独立レビュー（2026-09-24）の major 2 / minor 2（R-001〜R-004）と、その是正への敵対レビューの
> major 1 / minor 4（R-005〜R-009）を反映済み。敵対レビューは**未収束**（是正が新しいクラスを生んだ）。
> C-1 は反映後に再実行済みで、判定は **PASS with WARN**（未決事項あり。`review-self.md`）。**C-2 は未実施**。永続化と crash 整合を扱うので high-risk 相当とし、
> `review-principles.md` §7-quater に従って **C-2 は最低 2 ラウンド、新しい失敗クラスが出なくなるまで**続ける（回数を固定しない）。
> Codex への相談（2026-09-25）を受けて、durability の定義・容量の上限・CAS 保証の範囲・初期状態の扱いを plan に追記済み。
> #1407（#1393）からの依頼 R-014〜R-016（Decision からの遷移導出 / `decided_in_state` 照合 / `input_last_event_seq + 1`）を反映済み。
> `decision_made` の payload キーは #1391 の凍結待ち（RED fixture の前提）。
> **C-2 R1 実施済み・未収束**（R-017〜R-028）。設計レーンは 2 モデル（gpt-5.6-sol / gpt-6-sol）とも「モデル B（event + envelope のみ保存）へ変更」を推奨し、canon §4 と pbi-input の改訂を要する。
> コードベースレーンは #1402 の `run_state.py` が別モデルで本 slice を実装済みであることを検出。**R-017（A→B）と R-023（#1402 との関係）が Human 判断待ちで、C-2 R2 はその後**。
> **Human 決定（2026-09-25）: R-017 = モデル B、R-023 = #1402 から run_state を外す。** plan・test-cases・pbi-input・canon §4 を B に書き直し済み。次は **C-2 R2**（B への書き直しそのものを疑う）。

## 次のアクション

1. C-2 ラウンド 1: 文言確認でなく、ledger + fold + replay の設計モデルを代替モデル（event 列だけを真実とし state を保存しない 等）と比べる設計レビュー
2. C-2 ラウンド 2 以降: 新クラスが出なくなるまで
3. Human C-3（[P1] WAL なしの単一 snapshot 方式と容量上限・durability 定義の採否 / [P2] CAS 保証を同一 `runtime_root` 内に限る扱い / 暫定値 `MAX_*` の確定方法 を含む）
3. exec は #1391 が consumable になり、#1329 preflight を通ってから

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・責務境界 |
| plan.md | exec, review | 実行計画（未承認） |
| todo.md | exec | タスク一覧・進捗 |
| test-cases.md | exec, review | テストケース定義（ST-01〜ST-29） |
| review-self.md | C-3, review | C-1 結果 |
| review-external.md | C-3, review | PR 独立レビュー（R-001〜R-004）と C-2 結果 |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

plan 段階のため実装ファイルは未確定。永続化 module（lock / strict loader / snapshot / commit / conflict / 冪等性台帳）とテスト一式。CLI は追加しない。
