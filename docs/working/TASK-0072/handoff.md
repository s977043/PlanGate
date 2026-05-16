---
task_id: TASK-0072
artifact_type: handoff
schema_version: 1
status: draft
---

# HANDOFF — TASK-0072 (F1 exec 委譲デッドロック恒久対処)

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 capability preflight 明示 | PASS | execute.md「Task 利用可否をツール存在検査で判定」 |
| AC-2 直接実行フォールバック既定 | PASS | execute.md「直接 Implementer を実行（既定の正規フロー）」 |
| AC-3 conductor 委譲前提撤廃 | PASS | conductor.md「最適化でありハード前提ではない」+ 旧挙動撤廃明記 |
| AC-4 core-contract 不変条件 | PASS | core-contract §5-bis「exec はどの実行環境でも完遂可能」「ハード前提とするフェーズ定義を禁止」 |
| AC-5 error taxonomy + recovery | PASS | execute.md Error taxonomy: delegation_unavailable + 直接実行へ自動降格 |
| AC-6 conductor Iron Law 整合 | PASS | conductor.md「Iron Law（実装しない）は破られない・降格は委譲不能環境限定」 |
| AC-7 回帰なし | PASS | hook tests 48/0、CI スコープ lint（docs/workflows/04）0 error |

## 1-bis. V-3 外部レビュー対応（fix-loop 完了）

Codex=REJECT(Critical2)/Gemini=APPROVE の割れ判定。critical をブロッカー採用し
fix-loop で全件反映:
- CR-1: preflight 主体を conductor → exec router（conductor 起動前）へ移動
- CR-2: サブエージェント起動ツール命名（`Agent`/`Task`）統一・注記
- MJ-1: direct-implementer-mode の runner 責務明文化
- MJ-2: direct mode でも C-3/plan_hash/allowed_files/V-gates/C-4 不変を明記
- MJ-3: conductor.md 内の「委譲必須 vs 直接実行」衝突解消（router 責務へ）
- Minor: taxonomy 判定不能/不可 同一扱い理由 / AGENT_LEARNINGS.md:59 更新
再 V-1: AC-1〜7 + CR/MJ/Minor 全 PASS、hook 48/0、CI lint 0 error

## 2. 既知課題一覧

- core-contract.md / execute.md は CI markdownlint スコープ外（globs は
  docs/workflows/** 等のみ）。既存 Stop rules テーブルに MD060 が残るが
  本 PBI 起因ではなく CI 非対象。整形は別途任意。
- error taxonomy は本 PBI の最小定義。正本一元化は #203 で実施予定。

## 3. V2 候補

- #203 Tool Error Taxonomy で delegation_unavailable を正本統合
- F2（#239-2 commit 禁止のツールレベル強制 / 認証プリフライト）別 PBI
- F5（#234 A-D ゲート運用改善）別トラック

## 4. 妥協点

- 定義レイヤ変更主体（コード強制は最小）。実行時挙動の完全自動テストは
  困難なため grep 機械検証 + 文書トレース + 既存回帰で担保（C-1 D-3）。
- D-1 はツール存在検査を C-3 採用（env 宣言は TASK-0071 の自己付与リスク
  教訓で不採用、プリフライト探索はコスト増で見送り）。

## 5. 引き継ぎ文書（5分サマリ）

field の恒常 bug（conductor 2段委譲がサブエージェント・ネスト不可環境で
デッドロック）を、core-contract 不変条件 + capability preflight +
直接実行フォールバック既定化 + delegation_unavailable taxonomy で恒久対処。
#237/#238/#239/#234-E を1スコープ統合。AC-1〜7 PASS。残: V-3/V-4/C-4。

## 6. テスト結果サマリ

- AC grep 機械検証: AC-1〜7 + V-3 fix(CR-1/CR-2/MJ-1〜3/Minor) 全 PASS
- hook 回帰: `tests/hooks/run-tests.sh` 48 passed / 0 failed
- CI スコープ lint: docs/workflows/04_build_and_refine.md 0 error
