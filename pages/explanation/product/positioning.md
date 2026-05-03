# Positioning: PlanGate

> **Status**: v0
> **Review cadence**: Monthly

## Category

PlanGate is a **governance-first workflow harness for AI coding agents**.

日本語では、PlanGate は **AI コーディングエージェントのためのガバナンス優先ワークフローハーネス**である。

## Positioning statement

For product teams using AI coding agents,
who need to keep scope, acceptance criteria, and review boundaries under control,
PlanGate is a governance-first workflow harness
that prevents AI agents from writing production code until a human-approved plan and acceptance tests exist.

Unlike autonomous agent frameworks that optimize for speed,
PlanGate optimizes for approval boundaries, auditability, and Scrum-friendly delivery.

## 日本語版

PlanGate は、AI コーディングエージェントを使うプロダクトチーム向けの、ガバナンス優先ワークフローハーネスである。

AI が本番コードを書く前に、PBI、計画、受入条件、人間承認を必須化することで、スコープ、Done の定義、検証証拠を守る。

自律性や速度を最優先するエージェントフレームワークと異なり、PlanGate は承認境界、監査可能性、スクラム親和性を重視する。

## Differentiation

| Alternative | Optimizes for | PlanGate difference |
| --- | --- | --- |
| Cursor / IDE agents | Developer productivity inside IDE | PlanGate adds PBI, approval, verification, and handoff governance around agent work |
| Claude Code / Codex CLI | Agent execution | PlanGate governs when and how execution is allowed |
| Autonomous agent frameworks | Autonomy and task completion | PlanGate prioritizes approval boundaries and auditability |
| Manual process docs | Human-readable guidance | PlanGate aims to make gate, artifact, hook, eval, and metrics operational |
| CI only | Post-implementation checks | PlanGate adds pre-implementation approval and acceptance clarity |

## Core tagline candidates

| Audience | Tagline |
| --- | --- |
| PM / PO | AI 時代の Backlog Governance |
| Engineering | No approved plan, no code |
| Executive | AI 開発の速度に、承認・検証・監査を組み込む |
| OSS | Governance-first workflow harness for AI coding agents |
| General | AI がコードを書く前に、計画と受入条件を通す |

## Messaging pillars

| Pillar | Message |
| --- | --- |
| Value alignment | AI が作るものを PBI と受入条件に接続する |
| Approval boundary | C-3 / C-4 によって人間の判断点を固定する |
| Verification honesty | 未実行、失敗、残リスクを隠さない |
| Auditability | plan、review、verification、handoff を残す |
| Continuous harness improvement | eval、metrics、Keep Rate で PlanGate 自体を改善する |

## What PlanGate is not

PlanGate is not:

- an IDE
- a coding model
- a replacement for Cursor / Claude Code / Codex
- a fully autonomous coding agent
- a CI/CD tool only
- a prompt collection only

PlanGate is the governance layer that makes AI agent work safer, more reviewable, and more aligned with product delivery.

## Recommended main positioning

```text
PlanGate is a governance-first workflow harness for AI coding agents.
It prevents AI agents from writing production code until a human-approved plan, task list, and acceptance test set exist.
Unlike agent frameworks that focus on autonomy, PlanGate focuses on approval boundaries, auditability, and Scrum-friendly delivery.
```

日本語では以下を使う。

```text
PlanGate は、AI コーディングエージェントをプロダクト開発に安全に組み込むためのゲート型ワークフローハーネスです。
AI が本番コードを書く前に、PBI、計画、受入条件、人間承認を必須化します。
これにより、AI 開発でもスコープ、Done の定義、検証証拠を守れます。
```
