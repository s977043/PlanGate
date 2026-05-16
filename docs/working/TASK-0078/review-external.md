---
task_id: TASK-0078
artifact_type: review-external
schema_version: 1
status: done
phase: V-3
---

# V-3 外部レビュー — TASK-0078（F2 §5-bis 統合）

standard。Codex + Gemini 実行。

## 判定: Codex=critical0/major1/minor2、Gemini=APPROVED → fix-loop で全反映

挙動不変が要件のため Codex major（意味の意図せぬ広がり）をブロッカー採用。

| # | Sev | 指摘 | 対応 |
|---|-----|------|------|
| MJ-1 | major | 統合行が「委譲不可/no-commit違反/認証不整合 → 停止 or 降格」と一括化し、移設前は delegation_unavailable のみ降格・EH-9/auth は block/停止だった挙動が広がって読める | Decision rules を3行に分離（delegation_unavailable=direct降格 / EH-9=block / auth=exit!=0停止）+ §5-bis-1 本文に「降格は delegation_unavailable 限定」明示 |
| mn-1 | minor | 「warn は廃止＝high-risk 恒久対処」情報が移設で欠落（情報無損失違反） | §5-bis-1 EH-9 項に warn 廃止を復元 |
| mn-2 | minor | execute.md リンクが §5-bis-1 直リンクでなく参照精度低 | リンク表記を §5-bis-1 明示に修正 |

## Gemini
- **Approved（critical/major なし）**。情報無損失・参照整合・挙動不変を確認

## 確認
- 再 V-1: AC-1〜7 + MJ-1/mn-1/mn-2 全 PASS、hook 78/0、scripts/hooks diff ゼロ

## 出典
- Codex: /tmp/t0078-codex-v3.md（critical0/major1/minor2）
- Gemini: /tmp/t0078-gemini-v3.md（APPROVED）
