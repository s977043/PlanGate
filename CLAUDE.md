# CLAUDE.md

> **実行契約**: [`docs/ai/core-contract.md`](docs/ai/core-contract.md)（Iron Law / Stop rules / Output discipline の正本）
> **プロジェクトルール**: [`docs/ai/project-rules.md`](docs/ai/project-rules.md)（必読、AI 運用 4 原則の正本）

## Claude Code 固有参照

- エージェント / コマンド / スキル: `.claude/agents/` / `.claude/commands/` / `.claude/skills/`
- 運用ルール: `.claude/rules/`（hybrid-architecture 等は常時。orchestrator-mode は親 PBI 分解時のみ参照）
- 共有スキル: `.agents/skills/`（Codex CLI と共用）
- ワークフロー詳細: [`docs/ai-driven-development.md`](docs/ai-driven-development.md) / Orchestrator: [`docs/orchestrator-mode.md`](docs/orchestrator-mode.md)
- サブエージェント委譲プロトコル: [`docs/ai/subagent-delegation/README.md`](docs/ai/subagent-delegation/README.md)（派遣プロンプト必須8要素 / OUTCOME契約 / 行動規範 / PlanGateフロー接続。既存の C-3/C-4 ゲートおよび orchestrator-mode の Gate 不変条件は変更しない）

## v8.24.0 計画レビューの対話フィードバックと Ratchet の実差分判定（最新リリース機能）

> 最新リリース: **v8.24.0**（2026-10-12）v8.23.0 タグ以降に main へ蓄積した 36 コミット・PR 36 件を反映（`1f091e97` 時点の測定値。実測: `git rev-list --count v8.23.0..1f091e97`。PR 36 件のうち #1504 は v8.23.0 の release note 保存）。主題は **計画レビューの回答を機械可読に受け取る経路（opt-in）**・**ai-loop V2 の Ratchet を repository の実差分で判定すること**・**導入先 repo での `bin/plangate` の使い方（#1497）に Skill / Agent / Command の案内を合わせること**。主要変更: **`plangate render` の対話フィードバック HTML**（#1527。任意の `review-questions.json` から生成し、回答・保留・未回答を plan / questions の SHA-256 つきで JSON にエクスポートする。**フィードバック専用で承認ではない**・質問を渡さない従来の出力は byte 同一）・**エクスポート JSON の fail-closed 検証器 `scripts/validate_plan_feedback.py`**（#1534。鮮度の確認であり承認・gate には影響しない）・**実 Chromium での検証**（#1536 / #1542 / #1551。CI に 2 job を追加）・**Ratchet の delta を deterministic scope observer へ**（#1516。新規 `scope_observer.py`）・**Ratchet の expected prevention claim の束縛**（#1495。claim は prevention evidence ではない）・**外部 verifier P1 を P0 preflight の背後へ**（#1511）・**plugin の案内文 13 ファイル**（#1512 / #1518 / #1538 / #1539 / #1561 / #1563。project root の解決順・retained memory の読み込み境界・`workflow-conductor` の見出し重複の解消。文面のみで挙動は不変。`/plugin update` には version bump が要る）・**C-3 ゲートの記述に外部レビュー Decision → c3_status の対応を追加**（#1563 / #543。未知値・欠落は人間 C-3 強制。`bin/plangate` の承認判定は不変。ta-77 の承認面台帳を同時に更新）・**適用待ち apply スクリプトの棚卸し**（#1563 で 2 本適用・#1565 で 2 本削除。残る 3 本と検出器の偽陰性は既知の課題 #1562）・**`pre-push.sample` のマージ済みブランチ名の再作成ガード**（#1552。push 先 ref で判定する opt-in のローカル hook）・**CI の Test job で ta-61 を並列度 2 に**（#1555。kill-switch は `PG_T61_PARALLEL=1`・merge 後 5 run の観測は閾値内）・**運用方針の文書化**（#1549 実践進化 / #1548 Issue 棚卸し playbook / #1547 PR テンプレートの Rollback / Detection 節）。**`bin/plangate` と `schemas/` は変更ゼロ**。破壊的変更を宣言した commit は 0 件。semver は **minor（Human 決定 2026-10-11）**。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。リリース履歴の正本は [`CHANGELOG.md`](CHANGELOG.md)。

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
