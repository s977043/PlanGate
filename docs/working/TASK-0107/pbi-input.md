# TASK-0107 PBI INPUT PACKAGE: PlanGate Setup Command（`/plangate-setup`）

> **Phase**: A（PBI INPUT PACKAGE）
> **Date**: 2026-05-21
> **Source**: [`brainstorm.md`](./brainstorm.md)（B→A の順で進行。brainstorm §6.5 で `/setup-cowork` 実体調査済み）
> **Revision**: r1（2026-05-21 C-2 外部レビュー R-001〜R-005 を 1 回確定反映。[`review-external.md`](./review-external.md) 参照）

---

## 1. Context / Why

PlanGate は導入時に複数の Human-owned 設定が必要（`.claude/settings.json` wiring、`apply-claude-settings.sh` 実行、`bin/plangate doctor` での検証、`docs/working/` 構造の理解等）だが、現状は手順が散在しており、新規導入者にとって学習コストが高い。

Claude Cowork の `/setup-cowork` 相当の「対話的に初期設定を進められる入口」を PlanGate にも提供することで、以下を達成する:

- **新規導入時の摩擦を最小化**（一箇所から起動し、不足項目の検知・提示・検証を対話的に行う）
- **Human-owned 操作の追跡・確認**を AI 側で構造的に担保（Shadow Config 防止と整合）
- **既存 doctor を中核**に据えることで、settings 自己改変ガードの制約を活かしたガイド型設計

### 関連調査

Claude Cowork 公式に組み込みの `/setup-cowork` slash command は**存在しない**ことを確認済み（brainstorm §6.5）。Cowork は GUI ベースで Context files / Global instructions / Folder instructions / Plugins / Connectors の 5 要素を整える形。PlanGate 版は公式仕様に縛られず独自設計で進める。

### 責務 4 分類との整合（[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)）

| 操作 | 分類 | 本 PBI での担当 |
|------|------|---------------|
| settings.json wiring 適用 | **Human-owned** | Agent が提示、ユーザーが実行 |
| `apply-claude-settings.sh` 実行 | **Human-owned** | Agent が提示、ユーザーが実行 |
| doctor による検証 | **AI-owned** | Agent が CLI 呼び出し |
| **適用待ちの追跡 / 完了 lock** | **Workflow-owned** | **`status.md` / `decision-log.jsonl` への永続記録 + `doctor --check-settings PASS` ゲート**（R-001 反映） |
| drift 検出（reference） | **CI-owned** | 既存 CI（変更なし） |

---

## 2. What (Scope)

### In scope

1. **Command**: `.claude/commands/plangate-setup.md` 新設（薄い起動口。Agent を呼び出すだけ）
2. **Agent**: `.claude/agents/setup-coordinator.md` 新設（Human action の追跡・Gate 保持・対話・進捗管理を単一責務化）
3. **Skill**: `.claude/skills/plangate-setup/SKILL.md` 新設（チェックリスト・観点・script 提示テンプレを再利用単位として保持）
4. **既存 `bin/plangate doctor` との連携**: Agent から呼び出し、`doctor --json`（構造化出力）を解釈して未適用項目をリスト化（R-003 反映）
5. **進捗永続化**: 各 Step 完了ごとに `status.md` / `decision-log.jsonl` に manual action の pending/resolved を記録（R-001 反映）
6. **完了サマリ出力**: 完了項目・残項目・次のアクション候補（PBI 作成 / `/ai-dev-workflow` 等）を提示
7. **解消不能 FAIL の脱出経路**: フォローアップ PBI 起票誘導 or 承知スキップ（status.md に記録）の対話パス（R-005 反映）
8. **TASK-0107 handoff.md** 生成（Rule 5 遵守）

### Out of scope

- `bin/plangate doctor` 本体の改修（出力フォーマット変更含む。`--json` は既存実装に存在することを前提）
- `scripts/apply-claude-settings.sh` 本体の改修
- 新規 Hook（EH-x）の追加
- MCP 接続の自動化・自動検出
- 配布 plugin（`plugin/plangate/`）への export（v2 範囲）
- **再設定 / 健康診断 / 部分再適用**の用途（v2 範囲。初回 setup 専用に限定）
- Cowork 公式の 5 要素（Context files / Instructions / Plugins / Connectors）の完全再現
- 新規 CI workflow の追加
- 既存 Agent（acceptance-tester / linter-fixer 等）の改修

---

## 3. 受入基準（Acceptance Criteria）

> **改訂**: r1 で R-001〜R-005 を反映。AC-2〜AC-5 を test-cases 検証可能な形に書き直し（R-003）、AC-11〜AC-13 を新設（R-001/R-004/R-005）。

| ID | 受入基準 | 検証方法 |
|----|---------|---------|
| **AC-1** | `/plangate-setup` 入力で `setup-coordinator` Agent が起動する | `.claude/commands/plangate-setup.md` 存在 + Agent invocation を含むこと |
| **AC-2** | Agent が `bin/plangate doctor --json` を実行し、構造化出力から不足項目を抽出してユーザーに提示する | test-case: doctor --json 出力を mock として与え、Agent が抽出ロジック通りに項目をリスト化することを検証 |
| **AC-3** | Agent は Human-owned 操作（settings wiring / `apply-claude-settings.sh` 実行）を**実行せず提示のみ**する | test-case: Agent が apply-claude-settings.sh を起動するパスが存在しないこと（grep 検査）+ Agent definition に「実行禁止・提示のみ」が明記 |
| **AC-4** | ユーザーの「完了」報告を受けて Agent が `bin/plangate doctor --json` を再実行し、PASS まで完了しない | test-case: doctor が FAIL を返す mock 状況で Agent が次 Step に進まないこと（再検証ループ） |
| **AC-5** | 完了時にサマリ（完了項目・残項目・次のアクション候補）を出力する | test-case: 全項目 PASS の doctor --json mock で Agent が完了サマリ形式の出力を行うこと |
| **AC-6** | Skill `plangate-setup` が「PlanGate 5 要素対応観点」（CLAUDE.md / settings wiring / docs/working / agents-skills-commands / Hook-CI-MCP）を再利用単位として保持する | SKILL.md frontmatter + 本文に 5 要素対応表が存在すること |
| **AC-7** | Command / Agent / Skill の三者が [`hybrid-architecture.md`](../../../.claude/rules/hybrid-architecture.md) Rule 1〜5 を満たす | Rule 1（順序のみ）/ Rule 2（再利用単位）/ Rule 3（責務のみ）/ Rule 4（案件固有は CLAUDE.md）/ Rule 5（handoff）の機械検出（grep） |
| **AC-8** | TASK-0107 の `handoff.md` が生成される | `docs/working/TASK-0107/handoff.md` 存在 + 6 要素網羅 |
| **AC-9** | 既存 Agent（`acceptance-tester` / `linter-fixer`）と一貫した frontmatter / 構造で実装される | Agent definition の frontmatter 比較（diff） |
| **AC-10** | EH-3 / EH-8 等の Hook を新規追加しない（Out of scope の機械的担保） | `.claude/settings.json` の hooks セクションが変更されていないこと（diff 検査） |
| **AC-11** [新規] | **各 Step 完了ごとに `docs/working/TASK-0107/status.md` および `decision-log.jsonl` に manual action の pending/resolved を永続記録する**（Workflow-owned ロック） | test-case: Step 1〜5 を踏んだ後、status.md に各 Step の完了マーカーが、decision-log.jsonl に append-only エントリが存在すること（R-001 反映） |
| **AC-12** [新規] | **V-1 / handoff 完了の前提条件として `bin/plangate doctor --check-settings PASS` を確認する** | test-case: `--check-settings` が FAIL の状態で V-1 受け入れ検査 / handoff 完了処理がブロックされること（[`working-context.md`](../../../.claude/rules/working-context.md):126-135 settings タスクロック準拠）（R-004 反映） |
| **AC-13** [新規] | **解消不能な FAIL（環境制約等）に対して、フォローアップ PBI 起票誘導 or 承知スキップ（status.md に明示記録）の脱出経路を Agent 対話方針として持つ** | Agent definition に脱出経路の対話パスが明記 + test-case: 解消不能 FAIL mock で Agent が脱出経路を提示すること（R-005 反映） |

---

## 4. Notes from Refinement

### 検討経緯の要点（brainstorm.md より）

- **当初案 → 修正案**: Command + Skill の二層 → Command + Agent + Skill の三層
  - 「Human action の追跡」責務は Agent 側に置くべき（Skill は手順、Agent は責務）
  - 既存 Agent パターン（acceptance-tester / linter-fixer）と一貫
- **Cowork 公式調査の結論**: 組み込み `/setup-cowork` は存在しない。PlanGate 版は独自設計
- **Cowork 5 要素 → PlanGate 対応**:

| Cowork 5 要素 | PlanGate 対応物 |
|--------------|----------------|
| Context files | `CLAUDE.md` / `AGENTS.md` |
| Global instructions | `.claude/settings.json` wiring |
| Folder/Project instructions | `docs/working/` 構造 |
| Plugins | `.claude/{agents,skills,commands}` |
| Connectors | Hook / CI / MCP 等 |

### 設計原則

- **doctor を単一の検証源とする**: Agent は doctor（特に `--json` 構造化出力）の判定を踏襲し、独自の状態保持・判定を増やさない
- **AI は実行せず提示のみ**: Human-owned 操作（settings 適用等）は提示まで。実行はユーザー
- **Shadow Config 防止**: ユーザーの「やった」報告を信用せず doctor 再実行で実体検証
- **Workflow-owned 永続ロック**（R-001 反映）: Agent の対話状態に依存せず、status.md / decision-log.jsonl への記録と `doctor --check-settings PASS` ゲートで完了条件を構造化
- **UX デッドロック回避**（R-005 反映）: 解消不能 FAIL に対して脱出経路を提供（フォローアップ起票 or 承知スキップ）

### C-2 外部レビュー反映（r1 確定）

- 反映元: [`review-external.md`](./review-external.md) R-001〜R-005
- 反映方針: 1 回確定反映（[`working-context.md`](../../../.claude/rules/working-context.md) F5-C / V-3 MJ-1 準拠）
- 反映後の手順: 簡易 C-1 再実行 → 人間が APPROVED `c3.json` 発行 → plan 生成（phase B）

---

## 5. Estimation Evidence

### Risks

| ID | リスク | 影響 | 緩和策 |
|----|-------|------|--------|
| **R1** | setup-coordinator の責務肥大化（再設定 / 健康診断と混在） | Agent definition が膨れ Rule 3 違反気味になる | Out of scope に「再設定 / 健康診断は v2 範囲」を明記。初回 setup 専用に絞る |
| **R2** | doctor 出力フォーマット変更で Agent 解釈が壊れる | 将来的に Agent が動作不能 | `bin/plangate doctor --json` の活用前提。文字列パース回避（AC-2 反映） |
| **R3** | 三層構成（Command + Agent + Skill）で管理対象増 | 保守コスト | 既存 Agent パターン踏襲で構造を統一。テンプレ化 |
| **R4** | 完了サマリと PBI handoff.md の命名混同 | 運用ミス | サマリは「setup-summary」等別命名。handoff.md は Rule 5 通り別途生成 |
| **R5** | Agent invocation の方法が既存 Command と乖離 | 起動経路が分断 | 既存 `.claude/commands/` を参照し、最も近いパターンを踏襲（実装段階で決定） |
| **R6** [r1 追加] | Workflow-owned 永続ロック実装の不備 | セッション断絶時に Human-owned 操作の未完了を見失う（Shadow Config の構造防止漏れ） | AC-11/AC-12 で status.md / decision-log.jsonl / `--check-settings PASS` を明示。test-case 化 |
| **R7** [r1 追加] | 解消不能 FAIL での UX デッドロック | ユーザーが setup から抜けられず PBI 着手が遅延 | AC-13 で脱出経路（フォローアップ起票 / 承知スキップ）を Agent 対話方針に組込 |

### Unknowns

| ID | Unknown | 解決タイミング |
|----|---------|-------------|
| **U1** | setup-coordinator の tools 設定（最小: Bash, Read, Write [status.md 更新用]。Edit は不要か） | Plan 段階で確定 |
| ~~**U2**~~ | ~~モード判定（standard / light）~~ | **解決済 (r1)**: high-risk（R-002 反映、§5 モード判定参照） |
| **U3** | 完了サマリの配置・命名（status.md 統合 or 別ファイル） | Plan 段階で確定 |
| **U4** | Command が Agent を起動する具体的な方法 | Plan 段階で既存 commands を調査 |
| **U5** | Skill のチェックリスト粒度（doctor 12 検査項目すべて含めるか抜粋か） | Plan 段階で確定 |
| **U6** [r1 追加] | `bin/plangate doctor --json` の現在の出力スキーマ（実装で利用可能か） | Plan 段階で `bin/plangate doctor --help` で確認 |
| **U7** [r1.1 追加] | `/plangate-setup` 実行時の TASK ID / 記録先ディレクトリの動的解決（Task-local: 起動時に docs/working/TASK-XXXX/ を特定 or Global: 専用 setup ログ） | Plan 段階で確定（R-008 反映） |

### Assumptions

- A1: 既存 `bin/plangate doctor` の 12 検査項目を仕様変更せず活用する
- A2: `bin/plangate doctor --json` は既存実装に存在し、構造化出力が安定している（U6 で確認予定）
- A3: Hook EH-3 等の wiring 検証対象に含めるが、適用は Human-owned のまま
- A4: 配布 plugin への export は v2 範囲（今回は本リポジトリ正本のみ）
- A5: Cowork 公式仕様への準拠は不要（UX 参考に留める）
- A6: 既存 Agent（acceptance-tester / linter-fixer）の改修は不要

### モード判定（r1 改訂: R-002 反映）

- **判定**: **`high-risk`**
- **判定根拠**:
  - **AC 数**: 13 → 定量基準では超高（critical）レンジだが、AC-11〜13 は test-case 検証可能な独立小単位のため critical までは行かない
  - **変更ファイル数**: 3-5（Command / Agent / Skill / handoff / status / decision-log）→ standard レンジ
  - **変更種別**: 新規 Agent 追加 + Command + Skill 三層 + Workflow-owned 永続ロック新規 → 高（high-risk）
  - **リスク**: 高（Human-owned 操作の追跡漏れは Shadow Config 構造防止に直結）
  - **影響範囲**: 新規 Agent + 既存 doctor 利用 + status.md / decision-log.jsonl への新規書込 → 中〜高
  - **ロールバック**: 容易（新規ファイルのみで既存挙動破壊なし）→ standard
  - **Hardening Override**（[`working-context.md`](../../../.claude/rules/working-context.md) C-3 条件付き降格 AC-10）: 責務4分類・Shadow Config 防止に直接接続するため **Lite 不可・lite_eligible=false 確定**
  - **critical 不要の理由**: 段階的ロールバック不要（新規ファイル削除で復元可）/ 公開 API 破壊変更なし / DB スキーマ変更なし
- **フェーズ適用**（[`mode-classification.md`](../../../.claude/rules/mode-classification.md) high-risk 列）: brainstorm ○ / plan ○ / C-1 17項目 ○ / **C-2 ○（本レビュー実施済）** / C-3 ○ / exec TDD+並列 / L-0 ○ / V-1 ○ / V-2 ○ / V-3 ○ / V-4 - / PR ○ / C-4 ○

---

## 6. References

- [`brainstorm.md`](./brainstorm.md): 検討経緯（§6.5 に Cowork 実体調査結果）
- [`review-external.md`](./review-external.md): C-2 外部レビュー集約（R-001〜R-005 / Codex + Gemini）
- [`hybrid-architecture.md`](../../../.claude/rules/hybrid-architecture.md): Rule 1〜5
- [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md): AI/Human/CI/Workflow-owned
- [`working-context.md`](../../../.claude/rules/working-context.md): settings タスクロック / Shadow Config 防止 / C-3 条件付き降格
- [`mode-classification.md`](../../../.claude/rules/mode-classification.md): モード判定基準
- [`docs/ai/settings-wiring-contract.md`](../../ai/settings-wiring-contract.md): wiring 契約
- 既存 Agent: `.claude/agents/acceptance-tester.md` / `.claude/agents/linter-fixer.md`
- 既存 CLI: `bin/plangate doctor`
