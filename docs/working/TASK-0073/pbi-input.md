---
task_id: TASK-0073
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0073

> F2: exec 強制力ギャップ（委譲先 commit 境界のツールレベル強制 + exec 前プリフライト）
> 起源（field feedback）: #239 問題2（Behavior Rule 不遵守）/ #239 問題3（プリフライト欠如）

## Context / Why

field report #239 で2件の強制力ギャップが顕在化:

- **問題2**: 実装委譲時に「コミット・git push はしない（完了フェーズは親が
  実施）」と明示指示したのに、委譲先サブエージェントが commit を作成した。
  結果は偶然クリーンだったが**指示違反自体は発生**。原因: exec の
  Behavior rules / タスク境界が「プロンプト内自然言語の禁止指示」依存で、
  **ツール実行レベルの強制（ガード）になっていない**
- **問題3**: exec 進入前に実行環境の能力（git 操作主体・認証アカウント）を
  検証するゲートが無い。認証アカウント不一致で push が一度失敗し手動回避
  （既知パターンだが毎回手動対処）

「誰が commit/push するか」の分離が保証されず、不要ファイル混入・早すぎる
push の確率を構造的に内包。TASK-0072（F1）が委譲ケイパビリティ判定を
追加したのと対をなす、git 操作境界 + 認証の強制力ギャップ。

## What — Scope

### In scope

- **委譲 commit 境界の宣言と検出**: 委譲タスクに「commit/push 禁止」境界を
  構造化フィールドで宣言できる仕様を定義し、違反（委譲スコープ中に
  予期しない commit）を**機械検出**する仕組み（Hook or 検証ステップ）
- **exec 前プリフライト・ゲート**: exec 開始前に
  (a) git 操作主体（誰が commit/push するか）
  (b) 認証アカウント整合（gh auth / git config / remote）
  を検証し、不整合なら exec を停止 or 明示降格する正規ステップを定義
- core-contract / execute.md / 関連 workflow へのプリフライト不変条件追記
- 既存の認証三点セット（gh auth switch + git config + remote）を
  プリフライトの検査項目として正規化

### Out of scope

- F1（#237/#238 委譲ケイパビリティ＝Task 可否）→ TASK-0072 で完了
- commit 署名/GPG・ブランチ保護そのものの変更
- sockpuppet 検出ロジックの新規実装（既存運用ルール踏襲）
- #234 A-D（F5 別トラック）

## Acceptance Criteria

- [ ] AC-1: 委譲タスクに commit/push 境界を宣言する構造化フィールド仕様が定義されている
- [ ] AC-2: 委譲スコープ中の予期しない commit/push を機械検出する仕組み（Hook or 検証ステップ）が定義・実装されている
- [ ] AC-3: exec 前プリフライトで git 操作主体が検証され、未定義/不整合なら停止 or 明示降格する
- [ ] AC-4: exec 前プリフライトで認証整合（gh auth / git config / remote の三点）が検証され、不整合は exec 前に検出される
- [ ] AC-5: core-contract / execute.md にプリフライト不変条件が追記され、F1（§5-bis）と整合する
- [ ] AC-6: 違反/不整合時の挙動が決定論的（理由つき停止 or 降格）で、自然言語依存でない
- [ ] AC-7: 既存 hook テスト / ドキュメント整合性に回帰がない

## Notes from Refinement

- #239 問題2 の根因: NL 禁止指示は委譲先の自律判断で容易に上書きされる
  → ツール実行レベル or 事後検出の決定論的ガードが必要
- #239 問題3 は F1 の capability preflight と同じ「exec 前プリフライト」層に
  属する。F1=委譲可否、F2=git 主体/認証 → 同一プリフライト・ゲートに統合可
- メモリ既知: `GitHub アカウント切り替え`（gh auth switch + git config user +
  remote の三点セット必須）/ `マージ確定検証` と整合
- 検出方式は Hook（決定論・100%強制）が PlanGate 思想に合致するが、
  「予期しない commit」の定義（委譲境界の表現）が設計論点 → C-3 判断

## Estimation Evidence

**Risks**: Hook 追加（強制力レイヤ）+ core-contract 追記。誤検出で正常 commit を
阻害するリスク → 委譲境界の宣言を明示必須にし、未宣言時は従来動作
**Unknowns**: 委譲境界の構造化表現（todo.md フィールド / 委譲プロンプト規約 /
専用メタ）。検出主体（PreToolUse Hook on git / exec 後検証ステップ）→ C-3
**Assumptions**: F1 と同一プリフライト層に統合してよい。Mode 想定: high-risk
〜critical（強制力レイヤ + core-contract 追記、F1 と整合必須）
