---
task_id: TASK-0078
artifact_type: handoff
schema_version: 1
status: done
---

# HANDOFF — TASK-0078 (F2 §5-bis 統合)

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1 §5-bis 単一正本 | PASS | core-contract §5-bis-1「exec 前プリフライト（単一正本/F1+F2統合）」に capability/委譲commit境界(EH-9)/配線契約/exec後検証/認証三点/delegation_unavailable を網羅 |
| AC-2 execute.md 重複除去 | PASS | F2 プリフライト本文・Error taxonomy 本文を削除し §5-bis-1 参照化（89→43行） |
| AC-3 暫定ノート削除 | PASS | 「#245 マージ後…統合する」削除（grep 0） |
| AC-4 スクリプト不変 | PASS | `git diff main -- scripts/` 空（EH-9/auth-preflight/plan-hash 無変更） |
| AC-5 参照整合 | PASS | execute.md → core-contract §5-bis リンク有効・Stop rules は exec 文脈で §5-bis-1 を指す |
| AC-6 回帰なし | PASS | hook 78 passed/0 failed（挙動不変） |
| AC-7 F2 handoff 更新 | PASS | TASK-0073 handoff 既知課題を「統合完了」に更新 |

## 1-bis. V-3 外部レビュー対応（Codex major1/Gemini APPROVED）

Codex=critical0/major1/minor2、Gemini=APPROVED。挙動不変要件のため Codex major
を反映:
- MJ-1: 統合 Decision-rule を3分離（delegation_unavailable=direct降格 /
  EH-9=block / auth=exit!=0停止）。移設前の挙動を厳密維持
- mn-1: 「warn 廃止＝high-risk 恒久対処」を §5-bis-1 に復元（情報無損失）
- mn-2: execute.md リンク §5-bis-1 明示
再 V-1 PASS、hook 78/0、scripts 不変。Gemini も無損失/挙動不変を確認。

## 2. 既知課題一覧

- なし（本 PBI は技術的負債（暫定二重定義）の解消そのもの）。
- core-contract.md / execute.md は CI markdownlint スコープ外（docs/ai 非対象）。
  ローカル構造は維持。

## 3. V2 候補

- `delegation_unavailable` の #203 Tool Error Taxonomy への正式統合（§5-bis-1
  は最小定義を維持・#203 着手時に一元化）

## 4. 妥協点

- なし。F2 handoff で確定済の統合方針を情報無損失で実施。挙動・スクリプト不変

## 5. 引き継ぎ文書（5分サマリ）

F2(#246)が#245未マージ時の暫定でexecute.mdに併存させていた「exec前プリフライト
（F2）」節を、#245/#246マージ済を受けて core-contract §5-bis-1 単一正本へ移設
統合。execute.md は §5-bis-1 参照に簡潔化（89→43行）。スクリプト・挙動・hook
テスト（78/0）すべて不変。TASK-0073 handoff の §5-bis 統合 follow-up を解消。

## 6. テスト結果サマリ

- hook 回帰: 78 passed / 0 failed（挙動不変）
- scripts/ git diff: 空（スクリプト不変）
- 変更: core-contract.md(+§5-bis-1) / execute.md(参照化・-46行) / TASK-0073 handoff(既知課題更新)
- AC-1〜7 全 PASS
