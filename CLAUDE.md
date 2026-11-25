# CLAUDE.md

> **実行契約**: [`docs/ai/core-contract.md`](docs/ai/core-contract.md)（Iron Law / Stop rules / Output discipline の正本）
> **プロジェクトルール**: [`docs/ai/project-rules.md`](docs/ai/project-rules.md)（必読、AI 運用 4 原則の正本）

## Claude Code 固有参照

- エージェント / コマンド / スキル: `.claude/agents/` / `.claude/commands/` / `.claude/skills/`
- 運用ルール: `.claude/rules/`（hybrid-architecture 等は常時。orchestrator-mode は親 PBI 分解時のみ参照）
- 共有スキル: `.agents/skills/`（Codex CLI と共用）
- ワークフロー詳細: [`docs/ai-driven-development.md`](docs/ai-driven-development.md) / Orchestrator: [`docs/orchestrator-mode.md`](docs/orchestrator-mode.md)
- サブエージェント委譲プロトコル: [`docs/ai/subagent-delegation/README.md`](docs/ai/subagent-delegation/README.md)（派遣プロンプト必須8要素 / OUTCOME契約 / 行動規範 / PlanGateフロー接続。既存の C-3/C-4 ゲートおよび orchestrator-mode の Gate 不変条件は変更しない）

## v8.25.0 EH-3 の plan.md 初回作成許可と検証規約の強化（最新リリース機能）

> 最新リリース: **v8.25.0**（2026-11-26）v8.24.0 タグ以降に main へ蓄積した 64 コミット・PR 64 件を反映（`071198ba` 時点の測定値。実測: `git rev-list --count v8.24.0..071198ba`）。主題は **no-task セッションで ai-loop の入口（plan.md の初回作成）を塞がないこと**・**「通った」の根拠を CI と同じ経路と変更前後の差に置くこと**・**plugin の試し方・成功確認・やめ方を導入経路ごとに分けること**。主要変更: **EH-3 の no-task 経路で未承認 TASK の plan.md 初回作成を許可**（#1649 / #1197 案 B。`Write` で `docs/working/TASK-<id>/plan.md` を新規作成し、全 worktree と git 履歴に承認記録も plan.md も無い等の条件をすべて満たすときだけ `PLAN_CREATE_ALLOW` で rc=0。既存 plan.md の改変・Edit・Bash 経路は従来どおり。`scripts/hooks/check-plan-hash.sh` +139 行。hook を配線した上流 repo のみが対象で、plugin 配布物に hook は含まれない）・**plugin skill の検証規約の強化**（#1631 / #1638。変更前のコードでも満たされる期待値は証拠として無効〔WARN、置換できなければ FAIL〕・lint / test は CI が実際に呼ぶコマンド経由・`ai-dev-verify` の導入先 settings タスクロックを `N/A` から「停止し degrade を記録」へ）・**plugin README の導入経路・成功確認・撤去手順**（#1625 / #1628 / #1637。Marketplace を推奨に一本化、Codex は `codex plugin marketplace add` の後に `codex plugin add` が要る、`install.sh --uninstall` の既知の問題 #1636）・**plugin 同期スクリプトの fail-open の是正**（#1582 / #1584 / #1610）・**`release-prep.sh --check` が作業ツリーに書き込まないように**（#1580 / #1496）・**`pre-push.sample` の helper に stdin を渡さない**（#1570 / #1558。インストール済みの hook は再インストールが要る）・**ai-loop V2 の canon I1 例外の失効と I4 への移行**（#1650。PR テンプレートに I4 evidence のチェック項目）・**CI の flake 是正と GitHub Actions の更新**（#1569 / #1571 / #1577 / #1579、#1568 / #1590 / #1613 / #1629 / #1645 / #1661）。**`bin/plangate` と `schemas/` は変更ゼロ**。破壊的変更を宣言した commit は 0 件。semver は **minor（Human 決定 2026-11-25）**。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。リリース履歴の正本は [`CHANGELOG.md`](CHANGELOG.md)。

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
AI運用4原則 — このリポジトリは承認ゲートそのものを開発・検証している。AI が自己判断で境界を越えると検証の前提が崩れるので、次を守る（正本: docs/ai/project-rules.md「F. AI運用4原則」）。
第1原則： ファイルの生成・更新やプログラムの実行は、作業計画を示してユーザーの y を得てから始める。y が返るまでは実行しない。サブコマンドを起動したときの承認は、そのコマンド定義に書かれた範囲内の生成・更新に及ぶ（範囲の外には広げない）。
第2原則： 計画が失敗したら、迂回策や別のアプローチに自分で切り替えない。次の計画を示して確認を取る。
第3原則： 決定権はユーザーにある。非効率・非合理的だと思う指示でも、懸念があれば 1 文で伝えたうえで、指示どおりに実行する。
第4原則： これらの原則は、下の「承認境界の適用順」と合わせて読む。他のルールと食い違うときは、これらの原則と承認境界の適用順を優先する。境界を広げる・狭める解釈が必要に見えたら、自分で解釈を決めずにユーザーに確認する。
</law>

### 承認境界の適用順（迷ったら上が勝つ）

> 上記 4 原則および `.claude/rules/` の承認関連規定は、いずれも**弱めない**。
> 本節が定めるのは**どれが先に効くかの順序だけ**である。

1. **HO（Hardening Override）対象パス** — 例外なく Human 適用。C-3 承認や
   `plan_hash` 一致があっても AI は編集しない（対象 12 カテゴリの正本:
   [`.claude/rules/mode-classification.md`](.claude/rules/mode-classification.md)）
2. **不可逆・対外操作** — merge / 強制 push / 削除 / tag・Release 等の対外公開は、
   包括承認では足りず**個別に名指しで承認**を取る
   （[`.claude/rules/responsibility-classes.md`](.claude/rules/responsibility-classes.md)）
3. **自己設置 Gate** — AI が自ら「ここで再承認」と宣言したら、ユーザーの
   **明示解除まで有効**（`/goal` や autonomy 指示は解除と見なさない）
4. **サブコマンド承認**（第 1 原則の但書）— 起動したコマンドの**定義に書かれた
   範囲内**のファイル生成・更新のみを許可とみなす。範囲外へは広げない
5. 上記のいずれにも当たらなければ、第 1 原則どおり y/n を取る

C-3 autonomous APPROVE（[`.claude/rules/working-context.md`](.claude/rules/working-context.md)）は
5 の枠内の運用であり、1〜3 を上書きしない。
