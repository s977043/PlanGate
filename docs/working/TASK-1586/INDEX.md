# TASK-1586 — 保守コスト調査のEvidence索引

> Status: **READ_ONLY_RESEARCH / C-3未承認 / 実装BLOCKED**
> Issue: [#1586](https://github.com/s977043/PlanGate/issues/1586)
> Baseline: `main@1d624d95e597c711ec7f659868d4e1bf49d87d7a`（2026-10-18にGitHubから再取得）
> 旧観測: `5fcdb2e3`。**観測対象SHAは現行mainとは別**。

## 目的と現況

重複している保守タスクを除き、CIの実測時間とSkillsの配布先driftをEvidence付きでHumanに提示する。OpenAI公式記事は研究の参考であり、PlanGateへの効果は未測定。

今回の作業は**文書化のみ**。保守対象コード、`.claude/skills/**`、配布スクリプト、`.github/workflows/**`、HO/承認トークンを変更せず、テストをskipしない。C-3/C-4またはHuman-owned HOを代理承認しない。

## ファイルマップ

| ファイル | 用途 |
| --- | --- |
| [report.md](./report.md) | 出典SHAを含む候補別Evidence、Unknown、Risk、Verification、Rollback、Recommendation |
| [handoff.md](./handoff.md) | Humanが次の判断をできる6項目と未完了のGate |

## Done / Not done

- **済**: 既存Issue/PR・CIの再取得、正本と3つの配布先の2 Skill比較、負例2件の閉鎖時系列確認。
- **未実施**: CI時間の課金単位再集計、全Skillsのdrift棚卸し、修正後の実測改善、HO apply scriptの作成・実行、Skill本体の修正、独立Review/C-3/C-4。
- 変更対象の候補・実行手順はHumanが個別承認するまで**提案**に留める。

## 正本と関連作業

- [#1586](https://github.com/s977043/PlanGate/issues/1586) — Candidate/Evidence/UnknownのIssue正本
- [#1585](https://github.com/s977043/PlanGate/issues/1585) — V2のBounded Discovery / Artifactへの接続検討（実装許可ではない）
- [V2 North Star](../../ai/ai-loop-v2/north-star.md) / [Artifact責務](../../ai/ai-loop-v2/artifact-responsibilities.md) — この文書をRunEvidenceや承認に昇格させないための規範
- [Core Contract](../../ai/core-contract.md) — C-3/C-4、Human-owned merge
