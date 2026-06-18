# HANDOFF — TASK-0132 (#566)

> 生成: 2026-06-18T22:31:52Z / exec（C-3 APPROVED・critical・HO 非該当）

## 1. 要件適合確認結果（AC ごと）

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-01 | 2スキルを .claude/skills 正本へ + plugin mirror | PASS | 本体新設・本体↔mirror diff 一致 |
| AC-02 | mode-classification との重複解消 | PASS | router に「Mode 判定基準・lite_eligible は mode-classification 単一正本」明記、表は写像と位置づけ |
| AC-03 | WF-00 advisory 配線 | PASS | 00_intent_intake.md 新設（依頼→intent→mode→router→plan）+ README 目次 |
| AC-04 | advisory 限定（強制化しない） | PASS | WF-00 は非強制・既存 WF-01〜05 不変を明記 |
| AC-05 | hybrid 正本/export 方向整合 | PASS | .claude 正本・plugin ミラー注記（両ファイル同一文言で diff 一致） |
| AC-06 | critical 制約維持（人間 C-3 必須・autonomous 不可・lite_eligible=false） | PASS | 人間 C-3 APPROVED（presence gate 通過）で exec |

## 2. 既知課題一覧
- intent 7 分類の本体契約固定は初回 advisory（暫定）。固定・GatePolicy schema 化・bin/plangate 配線・gate 機械強制は別 PBI（plan Non-goals）。

## 3. V2 候補
- GatePolicy JSON schema 正本化 / bin/plangate thin entrypoint 配線 / advisory→強制 gate 化 / plugin export 同期の自動化。

## 4. 妥協点
- **plan S2「Mode 別表を削除→参照置換」の解釈調整**: mode-classification に GatePolicy(requiredSkills) 表が無く、完全削除は router 機能喪失。表は GatePolicy *写像* として残し、Mode 判定基準・lite_eligible を mode-classification 正本参照とすることで重複解消（判定基準は参照・写像は router 固有）。
- plugin export 同期は手動 mirror + 注記（自動化は将来）。
- 正本/ミラー注記は両ファイル同一文言で diff 一致を維持。

## 5. 引き継ぎ文書（サマリ）
plugin 専用だった intent-classifier / skill-policy-router を .claude/skills 正本へ移し、plugin をミラー化（diff 一致）。router の Mode 判定基準・lite_eligible を mode-classification 単一正本参照とし重複解消（写像表は維持）。WF-00 advisory（依頼→intent→mode→router→plan）を新設・既存 WF は不変。初回は advisory 限定で強制化しない。

## 6. テスト結果サマリ
- 正本2スキル存在 / 本体↔plugin mirror diff 一致 / Mode 正本参照 / lite_eligible 両スキル / WF-00 advisory + README: 全 PASS
- mode-classification.md(HO) 未編集を確認
- markdownlint: CI 委譲
