# CLAUDE.md

> **実行契約**: [`docs/ai/core-contract.md`](docs/ai/core-contract.md)（Iron Law / Stop rules / Output discipline の正本）
> **プロジェクトルール**: [`docs/ai/project-rules.md`](docs/ai/project-rules.md)（必読、AI 運用 4 原則の正本）

## Claude Code 固有参照

- エージェント / コマンド / スキル: `.claude/agents/` / `.claude/commands/` / `.claude/skills/`
- 運用ルール: `.claude/rules/`（hybrid-architecture 等は常時。orchestrator-mode は親 PBI 分解時のみ参照）
- 共有スキル: `.agents/skills/`（Codex CLI と共用）
- ワークフロー詳細: [`docs/ai-driven-development.md`](docs/ai-driven-development.md) / Orchestrator: [`docs/orchestrator-mode.md`](docs/orchestrator-mode.md)
- サブエージェント委譲プロトコル: [`docs/ai/subagent-delegation/README.md`](docs/ai/subagent-delegation/README.md)（派遣プロンプト必須8要素 / OUTCOME契約 / 行動規範 / PlanGateフロー接続。既存の C-3/C-4 ゲートおよび orchestrator-mode の Gate 不変条件は変更しない）

## v8.22.0 承認境界ガードの判定精度（最新リリース機能）

> 最新リリース: **v8.22.0**（2026-09-23）v8.21.0 タグ以降に main へ蓄積した 102 コミットを反映（実測: `git rev-list --count v8.21.0..319d6121`）。主題は **承認境界ガードの判定精度** — 「文字列で近似する」実装から「トークン列で判定する」実装への作り直し。主要変更: **EH-3 が linked worktree 配下の Hardening Override を素通りさせていた穴の解消**（#1277。`.claude/worktrees/<name>/` のような REPO_ROOT **配下**の linked worktree と REPO_ROOT 外の worktree の双方で HO 12 カテゴリが block されていなかった。本リポジトリは linked worktree が 60 本以上あり、**承認境界が最も使われる経路で外れていた**。回帰網 `ta-80` は 40 → 52 TC で、TC-R05〜R08 が**実 hook**に対して assert する）・**EH-3 の残存欠陥 3 件**（#1278 の `log_event` fail-open 化 / #1234 の `OUTSIDE_REPO_SKIP` / #1226 の承認サーフェス台帳）・**EH-3 の Bash レーン配線と HO パス正規化**（#1104 / #1101。`bin/../bin/plangate` のような別表記による迂回を封鎖）・**EH-12 の判定を同一コマンドのトークン列へ限定**（#1326。`git push` のトークン列に属さない `--force` / `+` を拾い、`echo` の引数やコミットメッセージのような**実行されない文字列**でも block していた。`;` `&&` `||` `|` `&` と**物理改行**でセグメント分割し、先頭語が `git` そのもののときだけ精密解析へ入る。それ以外は**従来の部分文字列判定へ落とす fail-closed**。実 hook 44 ケースの対照で**本物の破壊的操作 32 件は是正前後とも 32/32 BLOCK**・非破壊 12 件が 6 件の誤 block → 0 件。回帰網 `ta-86` を 56 TC で新設）・**EH-13 配線の回帰防止**（#1259。`EH-13-EDIT` / `-WRITE` を `TRACKED_FAIL` として登録し `ta-83` で gate の liveness を固定）・**承認の適用順の明示**（#1318。`<law>` 直後に 5 段。**各層を弱めず順序だけを定める**）・**version bump ゲートのリリース時配線**（#1257。`plugin/` に差分があるのに version が据え置きなら NOT READY。**bump しないと `/plugin update` は no-op で consumer に 1 件も届かない**）・**ai-dev ワークフローの実行資材を plugin へ同梱**（#1232）・**`.codex/skills` の drift 検査を push レーンへ拡張**（#1288。従来は `pull_request` でしか走らず main に drift が入っても main の CI は緑のままだった）・**ai-loop V2 Phase 0.1 完了**（#1275。canon docs 自身の Independence Level は I1 を**明示的な例外**とし、**失効条件 M-1 / M-2 / M-3 を判定コマンド + baseline つきで定義**。follow-up は #1329）・**`ho-apply-script` skill の新設**（#1316。HO 適用の型と**実際に踏んだ落とし穴 11 件**）。**`bin/plangate` は変更ゼロ**、`schemas/` は `review-result.schema.json` の説明文 1 行のみ（Schema / CLI の挙動は不変）。**`scripts/hooks/` / `scripts/check-git-destructive.sh` を配線している利用者は block 挙動が変わる**（plugin 配布物には含まれない）。semver は v8.21.0 と同型の材料で **Human 裁定により minor**。**PlanGate 本番フロー WF-00〜07 は不変・NO MERGE BY AI／C-4・merge は Human-owned 固定**。リリース履歴の正本は [`CHANGELOG.md`](CHANGELOG.md)。

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
