# テストケース: TASK-0030

## 受入基準 → テストケースマッピング

| AC | 受入基準 | テストケース ID |
|----|---------|--------------|
| AC-1 | command + exitCode + outputExcerpt を記録できる | TC-001 |
| AC-2 | exitCode != 0 → status = failed | TC-002 |
| AC-3 | missingEvidence → Completion Gate ブロック | TC-003 |
| AC-4 | /pg verify の出力形式として使える | TC-004 |
| AC-5 | docs に Evidence Ledger の例がある | TC-005 |

## テストケース一覧

### TC-001: EvidenceItem スキーマ定義の確認

**前提条件**: SKILL.md が存在する

**確認方法**: `plugin/plangate/skills/evidence-ledger/SKILL.md` を読み、
EvidenceItem に `command`, `exitCode`, `outputExcerpt`, `conclusion` フィールドが定義されているか確認

**期待結果**: 全フィールドがスキーマに含まれている

**種別**: ドキュメント確認

---

### TC-002: exitCode != 0 → status = failed ルール

**前提条件**: rules/evidence-ledger.md が存在する

**確認方法**: `plugin/plangate/rules/evidence-ledger.md` を読み、
「exitCode != 0 → status = failed」のルールが明記されているか確認

**期待結果**: ステータス計算ルール表に `exitCode != 0` → `"failed"` が含まれている

**種別**: ドキュメント確認

---

### TC-003: missingEvidence → Completion Gate ブロック

**前提条件**: rules/evidence-ledger.md が存在する

**確認方法**: `plugin/plangate/rules/evidence-ledger.md` の Completion Gate ブロック条件セクションを読み、
`missingEvidence` が 1 件以上ある場合のブロック条件が明記されているか確認

**期待結果**: Completion Gate ブロック条件に `missingEvidence` の条件が含まれている

**種別**: ドキュメント確認

---

### TC-004: /pg verify の出力形式定義

**前提条件**: SKILL.md が存在する

**確認方法**: `plugin/plangate/skills/evidence-ledger/SKILL.md` の出力フォーマットセクションを読み、
EvidenceLedger JSON の出力例が定義されているか、/pg verify との連携が記述されているか確認

**期待結果**: 出力フォーマットセクションに EvidenceLedger の JSON 例が含まれている

**種別**: ドキュメント確認

---

### TC-005: Evidence Ledger の例

**前提条件**: SKILL.md または rules ファイルが存在する

**確認方法**: SKILL.md または rules/evidence-ledger.md を読み、
具体的な JSON 例（claim + evidence 配列 + status）が含まれているか確認

**期待結果**: 最小ユースケース例として EvidenceLedger の完全な JSON が含まれている

**種別**: ドキュメント確認
