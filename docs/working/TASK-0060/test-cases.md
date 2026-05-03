# TEST CASES: TASK-0060

| ID | AC | 検証 | 期待 |
|----|-----|------|------|
| TC-01 | metrics-privacy.md 存在 | `ls docs/ai/metrics-privacy.md` | exists |
| TC-02 | 保存可能 metrics 一覧 | "Allowed" / "保存可能" セクション | exists |
| TC-03 | 保存禁止 metrics 一覧 | "Forbidden" / "保存禁止" セクション | exists |
| TC-04 | file path / stack trace / command output 扱い | 各項目の扱い記載 | exists |
| TC-05 | redact / sanitize 方針 | redaction policy | exists |
| TC-06 | retention policy | retention 章 | exists |
| TC-07 | public/private repo 運用差分 | repo 種別ごとの推奨 | exists |
| TC-08 | PBI-HI-001 event schema と矛盾なし | #195 schema 接続点記載 | exists |
