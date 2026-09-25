# TASK-1392 INDEX

> 最終更新: 2026-09-25 17:20
> 更新契約: `.claude/rules/working-context.md`「INDEX.md（L0 索引）の鮮度契約」に従い、
> plan 完了時に生成し、**以降はフェーズ遷移のたびに更新する**
> （C-3 承認 / plan 確定反映・再編集 / exec 完了 / V-1 判定確定 / WF-05 発行 / BLOCKED 化・解除）。

## チケット概要（1-2文）

V2 RunState の revision CAS と accepted RunEvent の durable commit を、1 ファイルの atomic snapshot で crash-consistent に実装する計画。**モデル B**: snapshot には #1392 の transaction envelope に包んだ accepted RunEvent だけを保存し、RunState・generation・replay 索引は load のたびに導出する。event の意味論は #1391、Decision / Verification は #1393 が持つ。

## 現在のフェーズ

C-2

> - PR 独立レビュー（R-001〜R-004）とその敵対レビュー（R-005〜R-009）、Codex 相談（R-010〜R-013）、#1407 からの依頼（R-014〜R-016）を反映済み
> - **C-2 R1**（R-017〜R-028）: 設計レーン 2 モデルとも B を推奨 → **Human 決定: R-017 = モデル B / R-023 = #1402 から run_state を外す**。canon §4 と pbi-input を改訂済み
> - **C-2 R2**（R-029〜R-036）: **要是正・未収束**（新しいクラス 4 件）→ **Human 決定: R-029 = conflict を冪等の対象外 / R-034 = REPLANNING 中の再束縛を許可**。反映済み
> - C-1 はモデル B への書き直し後に再実行済みで、判定は **PASS with WARN**（`review-self.md`）
> - C-2 は §7-quater に従い、新しい失敗クラスが出なくなるまで続ける（回数は固定しない）

## 次のアクション

1. C-2 R3: R2 の是正（冪等性の縮小・再束縛・conflict の整合）そのものを疑う
2. Human C-3（[P1] WAL なしの単一 snapshot と容量上限・durability 定義 / [P2] CAS 保証を同一 `runtime_root` 内に限る扱い / 暫定値 `MAX_*` の確定方法）
3. exec は #1391 が consumable になり（todo Preflight の条件）、#1329 preflight を通ってから

## ファイルマップ（読み込み優先度）

| ファイル | フェーズ依存 | 説明 |
|---------|------------|------|
| pbi-input.md | plan, review | 要件・責務境界（R-017 の改訂注記あり） |
| plan.md | exec, review | 実行計画（未承認） |
| todo.md | exec | タスク一覧・進捗（Preflight に #1391 consumable の条件） |
| test-cases.md | exec, review | テストケース定義（ST-01〜ST-43a） |
| review-self.md | C-3, review | C-1 結果 |
| review-external.md | C-3, review | R-001〜R-036 と Human 決定（追記専用） |
| current-state.md | status, 復旧 | 現在状態スナップショット |
| decision-log.jsonl | 監査, 振返り | 判断履歴（append-only） |

## 変更ファイル一覧（概要）

plan 段階のため実装ファイルは未確定。永続化 module（lock / strict loader / envelope と fold / commit / conflict）とテスト一式。CLI は追加しない。本 PR は canon `docs/ai/ai-loop-v2/artifact-responsibilities.md` §4 も改訂する。
