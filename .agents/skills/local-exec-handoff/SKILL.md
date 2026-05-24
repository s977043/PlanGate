---
name: local-exec-handoff
description: "PlanGate のローカル実行（Codex CLI / Claude Code）で exec を再開・引き継ぐための短い指示パケットを作る。Use when: セッション断後に exec を再開したい時、別エージェント・別ツールに作業を引き継ぎたい時。"
---

# Local Exec Handoff (PlanGate / Codex 共用)

PlanGate は Claude Code / Codex CLI ともローカル実行が原則。本 skill は **ローカルでの exec 再開・ツール間引き継ぎ** に使う短いパケットを組み立てる（Codex Cloud 用は `manual-cloud-task` を参照）。

## Read First

1. `CLAUDE.md`
2. `AGENTS.md`
3. `.claude/rules/working-context.md`（current-state.md / status.md 役割分担の正本）
4. `docs/working/TASK-XXXX/INDEX.md`
5. `docs/working/TASK-XXXX/current-state.md`
6. `docs/working/TASK-XXXX/status.md`（最終セクション）
7. `docs/working/TASK-XXXX/approvals/c3.json`（APPROVED 確認）

## Rules

- C-3 未承認なら exec 再開を拒否（`approvals/c3.json` APPROVED 必須）
- handoff packet は **次の担当者が 1 分で再開できる粒度**
- 機密情報（events.ndjson / 個人情報 / 認証情報）を含めない（EH-8 Privacy 準拠）
- ツール依存（Claude Code 固有コマンド等）を含めず、PlanGate 共通 CLI（`bin/plangate` / `scripts/ai-dev-workflow`）に統一

## Deliverable

以下を含む短い再開指示（10〜30 行程度）:

- **TASK ID**
- **現在のフェーズ**: exec / verify / handoff のどれか
- **直近の完了タスク**: todo.md 該当行
- **次にやること**: 1〜3 件の具体的な手順
- **触ってよいファイル範囲**: plan.md「Files / Components to Touch」抜粋
- **触ってはいけないファイル**: forbidden_files / Hardening Override 領域
- **再開コマンド**: `bin/plangate resume TASK-XXXX` で current-state を表示後、フェーズに応じ `bin/plangate exec/validate TASK-XXXX`

## CLI 呼び出し

- セッション再開時の current-state 表示: `bin/plangate resume TASK-XXXX`
- フェーズ確認: `bin/plangate status TASK-XXXX`
- exec 継続: `bin/plangate exec TASK-XXXX`
- 検証: `bin/plangate validate TASK-XXXX`

> packet 自体は手動構築。専用 CLI は未提供（`bin/plangate resume` + `bin/plangate status` の出力を整形する）。

## ツール別読み替え

- **Codex CLI**: `.codex/` 配下にパケットを置く必要なし。`bin/plangate resume` 出力と本 skill Deliverable で十分。
- **Claude Code**: `/working-context` skill と組み合わせて利用。
