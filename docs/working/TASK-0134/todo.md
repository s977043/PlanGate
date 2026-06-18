# EXECUTION TODO — TASK-0134 (#571)

## 🤖 Agent タスク
### 準備
- [ ] T1 _review_parallel / cmd_review の現状引数解析・出力を精読 (owner:agent, files:bin/plangate, rollback:不要・読取のみ)
### 実装
- [ ] T2 [S1] cmd_review に --progress 引数解析 + _review_parallel への伝播 patch/apply-script を生成（AI編集しない） (owner:agent, files:scripts/apply-task-0134-progress.sh, depends_on:T1, rollback:生成スクリプトを削除, 🚩HO)
- [ ] T3 [S2] wait 前の status_NNN ポーリング + [done X/N] 逐次表示ロジックを上記 patch に含める (owner:agent, files:scripts/apply-task-0134-progress.sh, depends_on:T2, rollback:生成スクリプトを削除, 🚩HO)
- [ ] T4 [S3] 後方互換 + privacy のテスト手順を整備 (owner:agent, depends_on:T1, rollback:test 追記を git checkout で復元)
### 検証
- [ ] T5 --progress 有/無 diff + [done X/N] 出現 + status破損failed + privacy grep + doctor (owner:agent, depends_on:T3,T4, rollback:不要・検証のみ。HO適用後に実施)
### 完了
- [ ] T6 handoff.md 作成(6要素) (owner:agent, files:docs/working/TASK-0134/handoff.md, depends_on:T5, rollback:不要)

## 👤 Human タスク
- [ ] H1 C-3 承認（high-risk / Standard 同期・exec 前ゲート） (owner:human 🚩)
- [ ] H2 bin/plangate の apply-script 実行（HO 適用） (owner:human 🚩)
- [ ] H3 C-4 PR レビュー (owner:human)

## ⚠️ 依存
- T1 → T2 → T3 / T4 → T5 → T6
- exec 開始は H1(C-3) 必須 / 実装反映は H2(HO 適用) 必須
- T5 の動作検証は H2(人間 apply) 後（それ以前は PASS にできない）

## 📌 rollback 記法サンプル（#565 規約適用）
HO patch 生成タスクの rollback は「生成スクリプトを削除」（bin/plangate 自体は人間 apply のため AI 側は patch 破棄で戻る）。
