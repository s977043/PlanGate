# テストケース定義 — TASK-0087 / #225

| ID | 受入基準 | 入力 | 期待 | 種別 |
|----|---------|------|------|------|
| T1 | AC1 | versioning-stability-policy.md | "2.1 JSON Schema"/"2.2 Enforcement Hook"/"2.3 Workflow"/"2.4 CLI" 各表に major/minor 行が存在 | 構造突合 |
| T2 | AC2 | 同上 | "3.1 コンポーネント別宣言" に Stable/Beta/Experimental 各 1 行以上 | 構造突合 |
| T3 | AC3 | 同上 | "[BREAKING]"/"[MIGRATION REQUIRED]"/"[STABILITY]"/"[SAFE UPDATE]"/"[INTERNAL]" 全タグ + 記載例コードブロック | 構造突合 |
| T4 | AC4 | 同上 | "6. 安定版（LTS）運用方針" に「当面は 採用なし」と再評価トリガ記載 | 構造突合 |
| T5 | AC5 | oss-governance.md | "versioning-stability-policy" へのリンクが存在 | 構造突合 |

## Edge
- E1: 相対リンク `../oss-governance.md` / `ai/versioning-stability-policy.md` が実在パスを指す
