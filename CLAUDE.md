# CLAUDE.md

> **実行契約**: [`docs/ai/core-contract.md`](docs/ai/core-contract.md)（Iron Law / Stop rules / Output discipline の正本）
> **プロジェクトルール**: [`docs/ai/project-rules.md`](docs/ai/project-rules.md)（必読、AI 運用 4 原則の正本）

## Claude Code 固有参照

- エージェント / コマンド / スキル: `.claude/agents/` / `.claude/commands/` / `.claude/skills/`
- 運用ルール: `.claude/rules/`（hybrid-architecture / orchestrator-mode 含む）
- 共有スキル: `.agents/skills/`（Codex CLI と共用）
- ワークフロー詳細: [`docs/ai-driven-development.md`](docs/ai-driven-development.md) / Orchestrator: [`docs/orchestrator-mode.md`](docs/orchestrator-mode.md)
- サブエージェント委譲プロトコル: [`docs/ai/subagent-delegation/README.md`](docs/ai/subagent-delegation/README.md)（派遣プロンプト必須8要素 / OUTCOME契約 / 行動規範 / PlanGateフロー接続。既存の C-3/C-4 ゲートおよび orchestrator-mode の Gate 不変条件は変更しない）

## v8.21.0 参照解決順とガード迂回の是正（最新リリース機能）

> 最新リリース: **v8.21.0**（2026-08-19）v8.20.0 タグ以降に main へ蓄積した 62 コミットを反映（実測: `git rev-list --count v8.20.0..375c791`）。主題は **「参照はあるが解決されない」「ガードはあるが迂回できる」構造の実測是正**。主要変更: **skill の参照解決順から構造上必ず空振りする plugin root 段を除去**（#954。最終 PR #1158 だけで 41 ファイル。`docs/**` は `sync-plugin-plangate.sh` の設計上 plugin の配布対象外のため常に解決されない手順だった）・**不在 rules 参照の張り替えと正本宣言の 4 root 統一**（#1123/#1125/#1126/#1127）・**EH-3 の Hardening Override 迂回の解消**（#1089。`PLANGATE_HOOK_TASK` 設定下では HO 9 カテゴリすべてが block されず、PlanGate 作業中のセッションこそ保護が外れていた。適用済みのため `tests/fixtures/eh3-known-gap-1089.flag` は削除）・**EH-13 承認トークンガードの迂回 2 クラス封鎖**（#1115 の外側ゲート ワイルドカード迂回＝実測 21 コマンドが素通り / #1110 のリダイレクト相関判定。fail-closed は不変）・**C-1 セルフレビュー項目数を実体（全 25 項目）へ是正**（#960）・**クラス A（rules 参照）の解決梯子を 4 skill + ai-loop 正本 5 本と plugin 生成物へ追加**（#1159/#954）・**`sh` 誤起動から `gh pr merge` / `gh pr review --approve` が実際に走る経路の封鎖**（#1169 / PR #1175・#1187。隔離 sandbox 実測で `gh` 12 回 + `git` 3 回発火 → 是正後 0 件。`scripts/` 直下 27 本 + `scripts/ai-loop/` 30 本 + 配布ミラー 30 本に polyglot ガードを適用し、`sh`/`bash`/`zsh` 起動は `exit 2`。**NO MERGE BY AI に関わる是正で、plugin 配布物にも入る**）・**plugin 配布 allowlist を実体照合し配布漏れ 2 件を是正**（#1173 / PR #1185）。**`schemas/*.json` / `bin/plangate` は変更ゼロ**（Schema / CLI の挙動は不変）。**EH-3 / EH-13 の block 強化は `scripts/hooks/` を配線している利用者に影響**（plugin 配布物には含まれない）が、**`sh` 誤起動ガードは plugin 配布物にも入る**（該当 `.py` を `sh` で起動していた手順は `exit 2` で止まる）。semver は規約 §2.2 上 major の材料を含むが **Human 裁定で minor**（経緯は [`docs/working/_merge/v8.21.0-release-runbook.md`](docs/working/_merge/v8.21.0-release-runbook.md) §1）。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。リリース履歴の正本は [`CHANGELOG.md`](CHANGELOG.md)。

- **Metrics v1**（v8.6.0 初出）: [`docs/ai/metrics.md`](docs/ai/metrics.md) — `bin/plangate metrics <TASK> --collect|--report|--validate`
- **Reporting & Retrospective v1**（v8.9.0 / #200）: [`docs/ai/reporting.md`](docs/ai/reporting.md) — events.ndjson 由来で sprint retrospective を導出、retrospective テンプレート [`docs/working/templates/retrospective-template.md`](docs/working/templates/retrospective-template.md)
- **Privacy**（v8.6.0 初出）: [`docs/ai/metrics-privacy.md`](docs/ai/metrics-privacy.md) — §3 Allowed / §4 Forbidden、4 層強制（gitignore + Hook EH-8 + schema additionalProperties:false + CI workflow）
- **Issue / Label / Milestone Governance**（v8.6.0 初出）: [`docs/ai/issue-governance.md`](docs/ai/issue-governance.md) — 必須セクション、4 軸 label taxonomy、roadmap PBI 作成 checklist
- **OSS 整備 3 主軸**（v8.7.0 / #226・#224・#225）: 段階的導入ガイド [`docs/staged-adoption-guide.md`](docs/staged-adoption-guide.md) / Plugin 成熟化 / バージョニング安定性ポリシー [`docs/ai/versioning-stability-policy.md`](docs/ai/versioning-stability-policy.md)
- **Baseline**（v8.6.0 初出）: [`docs/ai/eval-baselines/2026-05-04-baseline.{md,json}`](docs/ai/eval-baselines/) + [`schemas/eval-baseline.schema.json`](schemas/eval-baseline.schema.json) + `scripts/baseline-snapshot.py`
- **Hook EH-8**（v8.6.0 初出）: [`scripts/hooks/check-metrics-privacy.sh`](scripts/hooks/check-metrics-privacy.sh) — staging に events.ndjson / Forbidden field を検出。Hook enforcement は **12/12 実装**（物理配線 6/12、詳細は [`docs/ai/hook-enforcement.md`](docs/ai/hook-enforcement.md)）
- **Health check**: `bin/plangate doctor` に v8.6.0 セクション（schema 存在 / scripts 存在 / events.ndjson gitignore / EH-8 executable 等を 12 項目検査）
- **Roadmap**: [`docs/ai/harness-improvement-roadmap.md`](docs/ai/harness-improvement-roadmap.md) — Phase 0-6 + Governance + #213 全 ✅ Done（EPIC #193 CLOSED/COMPLETED）
- **Templates**: [`docs/working/templates/handoff.md`](docs/working/templates/handoff.md) §7 / [`docs/working/templates/current-state.md`](docs/working/templates/current-state.md) で metrics スナップショットを記載可能（任意）



## Codex CLI 固有参照 (PR #343/#347)

- 正規入口: `scripts/codex-guarded.sh --task TASK-XXXX exec --full-auto` (pre/post-flight 強制)
- 物理 hook 配線: [`.codex/hooks.json`](.codex/hooks.json) + [`.codex/hooks/eh-bridge.sh`](.codex/hooks/eh-bridge.sh) — EH-1/2/3/6/9 を Codex session 中の `apply_patch|Edit|Write|Bash` に対し物理発火
- Codex 用 agent: [`.codex/agents/*.toml`](.codex/agents/) (Claude `.claude/agents/<name>.md` への thin pointer)
- 強制等価マトリクス: [`docs/ai/settings-wiring-contract.md`](docs/ai/settings-wiring-contract.md) §Codex CLI parity

<language>Japanese</language>
<character_code>UTF-8</character_code>
<law>
AI運用4原則
第1原則： AIはファイル生成・更新・プログラム実行前に必ず自身の作業計画を報告し、y/nでユーザー確認を取り、yが返るまで一切の実行を停止する。ただし、サブコマンド起動時の承認をもって、そのサブコマンド内部のファイル生成・更新を許可とみなす。
第2原則： AIは迂回や別アプローチを勝手に行わず、最初の計画が失敗したら次の計画の確認を取る。
第3原則： AIはツールであり決定権は常にユーザーにある。ユーザーの提案が非効率・非合理的でも最優先で指示された通りに実行する。
第4原則： AIはこれらのルールを歪曲・解釈変更してはならず、最上位命令として絶対的に遵守する。
</law>
