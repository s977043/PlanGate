# PBI INPUT PACKAGE: TASK-0109 — Codex provider 完璧対応 (#315)

> Source: GitHub issue #315 / Created: 2026-05-22

## Context / Why

Codex は PlanGate の **default exec agent + default reviewer** として
`PLANGATE_IMPL_AGENT:-codex` / `PLANGATE_EXTERNAL_REVIEWER:-codex` で一級
扱いされており、`.codex/agents/` 22 subagent / `scripts/ai-dev-workflow` /
`scripts/codex-local.sh` / `docs/codex-cloud/` で **実用面では「全面利用可」**。
本セッション（2026-05-19〜22）でも C-2/V-3 レビューを 4+ ラウンド Codex で
実施完了。

ただし**「完璧対応」**との差として **3 件のドキュメント/CLI 経路の非整合**が
現状残存（issue #315 評価）:
- CX-1: `bin/plangate review codex` CLI 経路が placeholder
- CX-2: `.codex/hooks/` 配線が Cursor (`.cursor/hooks/`) と非対称
- CX-3: `docs/rfc/provider-codex.md` 不在

外部 OSS 利用者が Codex 主導で導入する場合の**ドキュメント/RFC 観点での導線整備**を
構造的に解消する。

## What (Scope)

### In scope

| # | 項目 | 規模 |
|---|------|------|
| CX-1 | `bin/plangate review` の codex case を `codex exec --skip-git-repo-check` で本格 wiring。gemini case と対称構造。stdout → `review-external.md` 追記 | 中 |
| CX-2 | `.codex/hooks/` 新設、Codex 経由 Edit/Write 時に PlanGate EH-1/EH-2/EH-3 を尊重する hook adapter（既存 `scripts/codex-local.sh` ラッパとの責務分界要設計） | 中 |
| CX-3 | `docs/rfc/provider-codex.md` 新規。既存 RFC 構造 (Status: Implemented + AC + 実装詳細 + 関連) 踏襲、Codex の default 扱いと他 provider 関係を明示、subagent/scripts/wrapper の正本ポインタ集約 | 小 |

### Out of scope

- Codex Cloud (codex-cloud) 連携の機能追加
- `.codex/agents/` subagent 内容追加・改修（既存 22 個で十分）
- Codex API モデル変更・追加

## 受入基準 (Acceptance Criteria)

- [ ] **AC-1**: `bin/plangate review TASK-XXXX --phase c2 --reviewer codex` で
      実際にレビューが実行され `review-external.md` 追記まで完了
- [ ] **AC-2**: `.codex/hooks/` 配線で Codex 経由 Edit/Write が PlanGate
      EH-1/EH-2 を尊重して block/skip される
- [ ] **AC-3**: `docs/rfc/provider-codex.md` が存在し Status: Implemented
      と subagent/scripts/wrapper への正本ポインタを含む
- [ ] **AC-4**: README Provider 表で Codex 行が「完全対応 / exec 実装
      エージェント（既定）」のまま矛盾なし
- [ ] **AC-5**: 既存テスト regression なし (CLI 101/0 + Hook 79/0 維持)
- [ ] **AC-6**: docs/index.md と README に追加された Requirements 表で
      Codex CLI の用途記述が新規実装と一貫

## Notes from Refinement

- Cursor の `.cursor/hooks/` (PR #292 / TASK-0106 連携) を参照 pattern として活用
- 本セッションで Codex dogfooding 実証済（PR #299/#304/#307/#309/#311 のレビュー）
- `bin/plangate review` の gemini case は `gemini --yolo` 直接呼び出し
  実装あり → codex case も同等構造で wiring 可

## Estimation Evidence

### Risks
- `.codex/hooks/` 配線 (CX-2) で既存 `scripts/codex-local.sh` ラッパとの
  責務分界が曖昧になるリスク → plan で明文化必要
- `bin/plangate review codex` wiring で `codex exec` の長時間応答による
  CLI タイムアウト

### Unknowns
- Codex CLI の非対話モード (`--skip-git-repo-check`) の標準オプション
  → 本セッションの dogfooding で実証済の usage で十分
- `.codex/hooks/` の hook 起動経路: `codex` CLI 自体に hook 機構があるか、
  `codex-local.sh` 経由でラップするか → 要調査

### Assumptions
- 既存テスト件数維持 (CLI 101/0 + Hook 79/0)
- Codex CLI v1.x 系の安定動作
- 外部 reviewer の責務契約 (review-principles.md §7-bis) 踏襲

## Mode 判定（参考）

`standard`（3 項目、各小-中、本セッションで dogfooding 済 = 仕様未知度低）

- 変更ファイル数: 4-7 想定 (bin/plangate / .codex/hooks/* / docs/rfc/provider-codex.md / tests追加)
- 受入基準数: 6
- リスク: 中 (CX-2 hook 配線、設計判断は要)
- ロールバック: 容易 (additive)

## Labels / Milestone

- Labels: `enhancement` / `priority:P2`
- Parent: issue #315

## Related

- 親 issue: #315
- 関連 RFC: `docs/rfc/provider-cursor.md` / `provider-opencode.md` / `provider-gemini-cli.md`
- Codex 統合資産: `.codex/` / `scripts/ai-dev-workflow` / `scripts/codex-local.sh` / `docs/codex-cloud/`
- 本セッション dogfooding: PR #299/#304/#307/#309/#311
