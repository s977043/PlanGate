# Handoff — TASK-0097 / #199 PBI-HI-005 Dynamic Context Engine v1
## 1. 要件適合確認
| AC | 判定 |
|----|------|
| AC1 context-manifest.schema.json 存在 | PASS |
| AC2 contract/dynamic 分離 | PASS |
| AC3 context --phase --profile で resolved 出力 | PASS |
| AC4 mode/profile budget 適用 | PASS（V-3 MJ-1: profile 保守側解決）|
| AC5 stale plan/c3 が Hook/validate と矛盾しない | PASS（plan_hash 実照合・抽出不可も invalidated・EH-3 補完/非代替）|
| AC6 Prompt Assembly 接続方針記載 | PASS（context-engine.md §5）|
| AC7 既存 workflow 非破壊 opt-in | PASS（明示 CLI のみ・diff context 追加のみ・keep-rate#198 非混入）|
V-1 全 PASS。V-3（Codex）critical 0/major 2/minor 2 → 全反映・回帰 PASS。
## 2. 既知課題
- dynamic_context は記述子のみ（実取得は呼び出し側 / Prompt Assembly。Vector
  /embedding は Non-goal）。
- profile↔mode budget は保守側採用（v1 設計判断）。Model Profile v2
  context_acquisition との精緻連携は将来（本 PBI は記録+保守側まで）。
## 3. V2 候補
- Prompt Assembly が dynamic_context を budget 内で実取得する実装。
- context_acquisition（#197 v2）戦略との連動（dynamic_first 等）。
- past_handoff/related_pbi の決定論索引精緻化（Vector 非導入のまま）。
## 4. 妥協点
- 決定論記述子に限定（Vector/embedding Non-goal）。opt-in・advisory で
  EH-3/C-3/C-4 を代替しない（承認境界不変）。profile は保守側で安全側。
## 5. 引き継ぎ
#199 を standard で実装。context-manifest schema + context-engine.py
（contract 固定+plan_hash 実照合 / dynamic 記述子 / mode×profile 保守側
budget / stale→invalidated exit1）+ bin/plangate context（opt-in）+ 正本 doc。
V-3 で profile 保守側解決 / plan_hash 抽出不可も invalidated / 文言・help を修正。
**EPIC #193 残: #200 Reporting & Retrospective（v8.9.0・最後の1件）。**
## 6. テスト結果
V-1: AC1-7 + E1/E2 全 PASS。V-3 反映後 smoke/schema/plan_hash 機械確認 PASS。
