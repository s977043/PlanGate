# Test Cases: TASK-0126

## AC → テストケースマッピング

| AC | テストケース |
|----|------------|
| AC-01 | TC-01: SKILL.md が設計妥当性レーンの責務を明示している |
| AC-02 | TC-02: 出力フォーマットに R-NNN / lane / severity / status が含まれる |
| AC-03 | TC-03: external-reviewer-interface.md に plan-quality-reviewer が追記されている |
| AC-04 | TC-04: SKILL.md に案件固有情報（プロジェクト名・TASK-番号・リポジトリ固有パス）が含まれていない |

## テストケース一覧

### TC-01: SKILL.md 責務明示

**前提**: `.claude/skills/plan-quality-reviewer/SKILL.md` が存在する  
**確認**: SKILL.md が「plan/todo/test-cases を読む」「実コード原則不読」「設計妥当性レーン」のキーワードを含む  
**種別**: 静的確認

### TC-02: 出力フォーマット互換

**前提**: SKILL.md の出力フォーマットセクションが存在する  
**確認**: `R-NNN`・`lane`・`severity`・`status` フィールドが明示されている  
**種別**: 静的確認

### TC-03: external-reviewer-interface.md 追記

**前提**: `docs/ai/external-reviewer-interface.md` が存在する  
**確認**: ファイルに `plan-quality-reviewer` または `plan-quality` のエントリが含まれる  
**種別**: 静的確認

### TC-04: Rule 2 準拠

**前提**: SKILL.md が存在する  
**確認**: SKILL.md に `plangate`・`TASK-` 等の固有名詞が含まれない（再利用可能）  
**例外**: `review-principles.md` 等の PlanGate 設計文書への参照リンクは許容（本リポジトリの成果物のため Rule 補足 §適用）  
**種別**: 静的確認
