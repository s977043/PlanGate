---
task_id: TASK-0078
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0078

> F2 §5-bis 統合（技術的負債解消）: execute.md F2 暫定節を core-contract
> §5-bis 配下の単一プリフライト正本へ移設し重複を排除
> 起源: TASK-0073（F2）handoff 既知課題「#245 マージ後 §5-bis 統合」

## Context / Why

F2（#246）は #245 未マージ時点で実装したため、core-contract §5-bis への
ダングリング参照を避け execute.md に「exec 前プリフライト（F2）」節を**暫定
併存**させた（execute.md 57-59 に「#245 マージ後 §5-bis 配下へ統合」と明記）。
#245/#246 が main にマージ済の今、**capability preflight（§5-bis）と F2
プリフライト（execute.md 暫定節）が二重定義**状態。放置すると正本性が崩れ
解釈ブレの温床になる（F2 handoff の明示 follow-up）。

## What — Scope

### In scope

- **core-contract §5-bis を単一プリフライト正本に集約**: 既存の capability
  （Task 可否）+ direct-implementer-mode + 統制不変 に加え、F2 の
  認証三点プリフライト・委譲 commit 境界（EH-9）・配線契約・exec 後検証・
  `delegation_unavailable` error taxonomy を §5-bis 配下へ移設統合
- **execute.md を参照化**: §9「実行者の決定」/ §28「exec 前プリフライト（F2）」
  / Error taxonomy 節の重複本文を削除し、§5-bis を参照する簡潔記述に置換。
  Stop rules は exec phase 文脈として残すが詳細は §5-bis 参照
- 暫定統合ノート（execute.md 57-59）を削除（統合完了のため）
- EH-9 / `check-auth-preflight.sh` / `check-delegation-commit-boundary.sh`
  の**実装は一切変更しない**（参照先の一本化のみ・挙動不変）

### Out of scope

- スクリプト/Hook の挙動変更（参照集約のみ）
- #203 Tool Error Taxonomy 本体（delegation_unavailable は §5-bis に最小維持）
- F5-AD 実装（#251）/ TASK-0071 / その他 follow-up

## Acceptance Criteria

- [ ] AC-1: core-contract §5-bis が capability+認証三点+commit境界+direct-mode+統制不変+delegation_unavailable を網羅する単一正本になる
- [ ] AC-2: execute.md から F2 プリフライト本文・Error taxonomy 本文の重複が除去され §5-bis 参照に置換される
- [ ] AC-3: execute.md の暫定統合ノート（「#245 マージ後…統合する」）が削除される
- [ ] AC-4: EH-9 / check-auth-preflight.sh / check-delegation-commit-boundary.sh の実装が不変（差分なし）
- [ ] AC-5: §5-bis 参照リンクが整合し、execute.md Stop rules は exec 文脈で残るが詳細は §5-bis を指す
- [ ] AC-6: 既存 hook テスト（78 件）/ doc 整合性に回帰がない（挙動不変）
- [ ] AC-7: F2（TASK-0073）handoff の既知課題「§5-bis 統合 follow-up」が解消済と更新される

## Notes from Refinement

- F2 handoff 明記の統合方針: 正本=§5-bis、execute.md F2 節は移設し削除、
  スクリプト実装は不変（参照先のみ一本化）
- 挙動変更ゼロのドキュメント refactor（強制力・テストは不変）

## Estimation Evidence

**Risks**: core-contract（governance 正本）編集。参照切れ/情報欠落で正本性
低下 → 移設は情報無損失（execute.md の内容を §5-bis へ完全移動）を厳守
**Unknowns**: なし（F2 handoff で統合方針確定済）
**Assumptions**: 挙動不変・スクリプト無変更。Mode 想定: standard（governance
正本編集のため最低中。コード変更なし）
