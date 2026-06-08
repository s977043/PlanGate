# When NOT to use PlanGate (採用しない方が良いケース)

PlanGate は **すべての AI コーディング** に向くわけではありません。以下のケースでは導入コストの方が便益を上回ります。

## ✗ 採用しない方が良いケース

### 1. 探索的プロトタイピング (throwaway code)

- 30 分以内に書き捨てる検証コード
- Notebook での data exploration
- ワンショットの bug repro

**理由**: PBI INPUT PACKAGE → plan → C-3 承認 → exec の正規フローが overhead になる。
**代替**: 直接 AI に依頼 (Cursor / Copilot)、後で正規化が必要なら PBI 化。

### 2. 完全自律エージェントを目指す開発

- AutoGPT / agentic AI system 開発
- 人間承認を介さずに目標達成する agent loop の構築

**理由**: PlanGate の中核は **人間承認ゲート (C-3 / C-4)** であり「承認なしで AI に書かせない」を絶対化する。完全自律と相反。
**代替**: LangGraph / AutoGen / 独自 agent framework。

### 3. SaaS / 外部 store 前提のチーム

- Linear / Jira / Notion を信頼の正本とするチーム
- PR / Issue 中心の運用ではなくチケット ID で全てが回る組織

**理由**: PlanGate は `docs/working/TASK-XXXX/` の Markdown を「正本」とする。外部 SaaS と二重管理になる。
**代替**: SaaS の Webhook / API で承認境界を実装。

### 4. 1 人開発 / 短期プロジェクト

- Solo developer の personal project
- 6 週間以内に終わる limited duration project

**理由**: PlanGate のガバナンスコスト (PBI 記入 / C-3 承認 / handoff 発行) は **3 人以上のチーム & 3 ヶ月以上の継続運用** で元が取れる設計。
**代替**: Cursor + git だけで十分。

### 5. リアルタイム / 低レイテンシ要件のある AI 統合

- Voice assistant / live coding 補助
- Code completion の inline 体験

**理由**: PlanGate の hook / gate は秒〜分単位の人間判断を介在させる。millisec オーダーでは不適。
**代替**: GitHub Copilot / Cursor の inline completion。

## ⚠ Trade-offs (使う場合の覚悟)

PlanGate を採用する場合、以下のコストを受け入れる必要があります。

| コスト | 内容 | 緩和策 |
|-------|------|--------|
| **PBI 記入コスト** | Why / What / AC / Constraints / Non-goals を毎タスクで明文化 | テンプレ化、`bin/plangate brainstorm` で対話的生成 |
| **C-3 承認の同期遅延** | 人間が plan を読んで判定するまで exec 待機 | `lite_eligible` で非同期降格 (条件付き)、light mode で簡略化 |
| **学習負荷** | EH-X / WF-XX / V-X / C-X 略号、mode 分類、責務 4 分類 | [glossary.md](../../reference/glossary.md) でクイックリファレンス、[Staged Adoption Guide](../../../staged-adoption-guide.md) で段階導入 |
| **handoff 維持コスト** | 全 PBI で 6 要素 handoff.md を発行・保管 | テンプレ自動生成 (`bin/plangate handoff`)、light mode で簡易版 |
| **hook の摩擦** | EH-1〜EH-9 が誤検知する局面がある | `PLANGATE_BYPASS_HOOK=1` で一時 bypass (監査ログ記録) |

## ✓ 採用が **特に有効** なケース

参考までに、PlanGate が最も価値を出すシナリオ:

- **3 人以上 & 3 ヶ月以上**のチーム開発
- AI コーディングエージェント (Claude Code / Codex CLI / Cursor) を本格運用
- **監査可能性 / 説明責任**が要求される業界 (regulated industry / 公共系)
- **段階的に AI 自律度を上げたい**チーム (Level 1 → 5)
- **Scrum / Agile** 運用との親和性を重視

## 関連

- [philosophy.md](./philosophy.md) — 設計思想と問題設定
- [staged-adoption-guide.md](../../../staged-adoption-guide.md) — 段階的導入レベル 1〜5
- [glossary.md](../../reference/glossary.md) — 用語クイックリファレンス
