# PBI INPUT PACKAGE — TASK-0132 (#566)

## Context / Why
agent-skills 取り込み検討の差分。`intent-classifier` / `skill-policy-router` は `plugin/plangate/skills/` にのみ存在し、`.claude/skills/` 本体に正本が無く本体フロー（ai-driven-development / docs/workflows / bin/plangate）から呼ばれていない。hybrid-architecture の原則（本体正本=`.claude/`、plugin=配布 export）と逆転している。

## What (Scope)
### In scope（Codex 助言で初回スコープを限定）
- 2 スキル（intent-classifier / skill-policy-router）を `.claude/skills/` へ正本移動し、`plugin/plangate/` は mirror 化
- skill-policy-router の「Mode別ポリシー表」を削除し、`mode-classification.md` を単一正本として参照（drift 解消）
- WF-00（docs/workflows）への **advisory 配線**（依頼→intent→mode→router→GatePolicy→ai-dev-plan 前段。初回は強制でなく advisory 出力）

### Out of scope（初回）
- 強制配線（gate を機械強制）— 初回は advisory のみ
- GatePolicy JSON schema の厳密化・互換性テスト
- bin/plangate への実装配線（将来 thin entrypoint）
- #565 / #567

## 受入基準
- AC-01: intent-classifier / skill-policy-router の正本が `.claude/skills/` に存在し、plugin 側は mirror（内容一致）
- AC-02: skill-policy-router から Mode別ポリシー表が削除され、mode-classification.md への参照に置換（重複ゼロ）
- AC-03: WF-00 に advisory 配線（依頼→intent→mode→router→plan 前段）が文書化されている
- AC-04: hybrid-architecture の正本/export 方向（.claude 正本・plugin mirror）に整合
- AC-05: lite_eligible 自動推定との責務関係が明記（classifier/mode判定/router のどこが担うか）

## Estimation Evidence
- Risks: `.claude/rules/mode-classification.md` を参照される側として確認（編集はrouter側＝.claude/skills 追加で AI 可）。bin/plangate は初回触らない（advisory）。
- Unknowns（Codex Q4）: intent 7分類を本体契約に固定するか暫定か / GatePolicy schema 正本置き場 / export 同期手順 / advisory→強制の移行。
- Mode 見込み: **critical**（横断的・正本移動・重複解消・複数レイヤー。lite_eligible=false・人間 C-3 必須・autonomous 不可）。
