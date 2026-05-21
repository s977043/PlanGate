# TASK-0107 EXECUTION PLAN

> Source: `pbi-input.md` r1 + Unknowns U7 / Mode: **high-risk**
> Generated: 2026-05-22
> Advisory: Codex + Gemini（C-2 R2 後）GO for plan generation

## Goal

PlanGate に **対話的初期セットアップの入口**を提供する: `/plangate-setup` Command + `setup-coordinator` Agent + `plangate-setup` Skill の三層構成を新設し、既存 `bin/plangate doctor --json` を**単一検証源**として未適用項目の検知 → 提示 → ユーザー実行 → 再検証ループを実現する。**Workflow-owned 永続ロック**（`status.md` / `decision-log.jsonl` + `doctor --check-settings PASS`）で Shadow Configuration を構造的に防ぐ。

## Constraints / Non-goals

### Constraints

- **doctor を単一検証源とする**: Agent は `bin/plangate doctor --json` の構造化出力（`scope` / `checks[]{name,ok,level,detail}` / `failures` / `warnings` / `passed`）のみを使い、文字列パースや独自判定を持たない（R-003）
- **AI は提示のみ、実行しない**: settings 適用 / `apply-claude-settings.sh` 実行などの **Human-owned 操作は Agent が一切実行しない**（grep negative test で固定）
- **Workflow-owned 永続ロック**: Agent の対話状態に依存せず、Step 完了ごとに `status.md` + `decision-log.jsonl` へ append-only 記録（R-001）
- **新規 Hook 追加禁止**: `.claude/settings.json` の hooks セクション diff = 0（AC-10）
- **既存 Agent パターン踏襲**: `acceptance-tester` / `linter-fixer` の frontmatter 構造に揃える（AC-9）
- **C-3 同期固定**: `lite_eligible=false`（Hardening Override: Shadow Config / 責務 4 分類に直接接続するため）
- **TASK ID 動的解決**: 記録先 `docs/working/TASK-XXXX/` は実行時解決（U7 / R-008）

### Non-goals

- `bin/plangate doctor` 本体改修（`--json` 出力形式の変更含む。**現状の schema をそのまま使う**）
- `scripts/apply-claude-settings.sh` 改修
- 新規 Hook（EH-x）追加
- MCP 接続の自動検出 / 自動化
- 配布 plugin（`plugin/plangate/`）への export（v2 範囲）
- **再設定 / 健康診断 / 部分再適用**ユースケース（v2 範囲。初回 setup 専用）
- Cowork 公式 5 要素の完全再現
- 新規 CI workflow 追加
- 既存 Agent の改修

## Approach Overview

**「契約確定 → 三層実装 → 永続ロック → 検証/handoff」** の 4 ブロック・8 Steps で進める。

1. **Step 1（契約確定）** で `doctor --json` 実 schema を取得（U6）、Agent tools 最小集合を確定（U1）、Command invocation 方式（U4）、TASK ID 動的解決ロジック（U7）を文書化する。**ここを潰さないと Agent / Skill の実装が空振る**。
2. **Step 2（三層責務設計）** で Command / Agent / Skill の責務境界表 + Cowork 5 要素 ⇄ PlanGate 対応表を確定する。
3. **Step 3-5（三層実装）** は Step 2 後に並列可能（Skill / Command / Agent）。ただし Agent は Step 1 の schema 確定が前提。
4. **Step 6（Workflow-owned 永続ロック）** は最重要。`status.md` + `decision-log.jsonl` append-only + 解消不能 FAIL の skip 記録パスを Agent 仕様に組み込む。
5. **Step 7（テスト）** は mock-driven Agent test（3 系統: passed / 不足 / 解消不能 FAIL）+ grep / diff / handoff 6 要素検査。
6. **Step 8（V-1 + handoff）** で `doctor --check-settings PASS` ゲートを通過させてから handoff.md 生成。

## Work Breakdown

| # | Step | Output | Owner | Risk | 並列可否 | 🚩 Checkpoint |
|---|------|--------|-------|------|---------|--------------|
| 1 | **事前契約確定**（U6/U1/U4/U7） | `docs/working/TASK-0107/contract-notes.md`（`doctor --json` 実 schema、Agent tools 最小集合、Command invocation 方式、TASK ID 動的解決ロジック） | AI | medium | 不可 | `bin/plangate doctor --json` 実行で `scope / checks[] / passed` を確認、tools=[Bash(`bin/plangate doctor --json`),Read,Write(限定)] 確定 |
| 2 | **三層責務設計確定** | `contract-notes.md` 末尾に責務境界表 + Cowork 5 要素対応表 | AI | low | 不可（Step 1 後） | Command/Agent/Skill の入出力境界が表で 1:1 にマップ |
| 3 | **Skill 実装** | `.claude/skills/plangate-setup/SKILL.md` | AI | low | Step 2 後並列可 | frontmatter + 5 要素対応 + チェックリスト + Rule 1-5 grep PASS |
| 4 | **Command 実装** | `.claude/commands/plangate-setup.md` | AI | low | Step 2 後並列可 | Command が Agent invocation だけを持ち他に責務なし（Rule 1）+ `.claude/settings.json` diff = 0 |
| 5 | **Agent 実装** | `.claude/agents/setup-coordinator.md` | AI | **high** | Step 1+2 後（Step 3/4 と並列可） | frontmatter (`tools` 最小)+ doctor --json 連携 + Human-owned 提示のみ明示（grep negative test 用文言）+ 既存 Agent（acceptance-tester / linter-fixer）と frontmatter 構造一致 |
| 6 | **Workflow-owned 永続ロック実装** | Agent definition への append-only 記録ルール組込み + `status.md` / `decision-log.jsonl` の更新仕様 | AI | **critical** | 不可（Step 5 後） | 各 Step 完了 → `status.md` 追記 + `decision-log.jsonl` append、解消不能 FAIL skip 記録パス（AC-13）、TASK ID 不明時 guard（U7） |
| 7 | **テスト/検証資産** | `tests/extras/ta-XX-plangate-setup.sh`（mock-driven）+ grep / diff 検査 + handoff 6 要素検査 | AI | medium | Step 3〜6 後 | doctor --json mock 3 系統（passed / 不足 / 解消不能 FAIL）+ Rule 1-5 grep + `.claude/settings.json` diff=0 + AC-11 の status/jsonl append 検証 |
| 8 | **V-1 受け入れ + handoff.md 生成** | `docs/working/TASK-0107/handoff.md`（6 要素網羅）+ V-1 PASS | AI | medium | 不可（全 Step 後） | `bin/plangate doctor --check-settings PASS` 確認 → V-1 全 AC PASS → handoff.md 6 要素網羅（要件適合 / 既知課題 / V2 候補 / 妥協点 / 引き継ぎ / テスト結果） |

## Files / Components to Touch

| ファイル | 性質 |
|---------|------|
| `docs/working/TASK-0107/contract-notes.md` | 新規（Step 1 成果物） |
| `.claude/skills/plangate-setup/SKILL.md` | 新規 |
| `.claude/commands/plangate-setup.md` | 新規 |
| `.claude/agents/setup-coordinator.md` | 新規 |
| `tests/extras/ta-XX-plangate-setup.sh` | 新規 |
| `docs/working/TASK-0107/status.md` | 新規（Workflow-owned 永続記録、本 PBI 進行用） |
| `docs/working/TASK-0107/decision-log.jsonl` | 新規（append-only） |
| `docs/working/TASK-0107/handoff.md` | 新規（WF-05） |
| `.claude/settings.json` | **変更禁止**（AC-10 機械検証） |
| `bin/plangate doctor` | **変更禁止**（Non-goals） |

## Testing Strategy

### Unit / Mock-driven Agent Tests（3 mock 系統）

- **Mock A**: `bin/plangate doctor --json` 出力で `passed=true` → Agent が完了サマリへ進む（AC-5）
- **Mock B**: `passed=false`、`checks[]` に `ok=false` 項目あり → Agent が不足項目をリスト化（AC-2）、Human-owned 操作を**提示のみ**（AC-3）、人間「完了」報告 → doctor 再実行 → PASS まで進まない（AC-4）
- **Mock C**: 解消不能 FAIL（例: 環境制約）→ Agent がフォローアップ PBI 起票 or 承知スキップを提示し `status.md` に記録（AC-13）

### Static / Grep Tests

- **AC-3**: Agent definition に `apply-claude-settings.sh` を実行するパスがないこと（grep negative）
- **AC-6**: SKILL.md に 5 要素対応表が存在（grep positive）
- **AC-7**: Rule 1-5 ごとに grep（Workflow 順序のみ / Skill 再利用 / Agent 責務のみ / 案件固有 CLAUDE.md / handoff 集約）
- **AC-9**: Agent frontmatter が `acceptance-tester` / `linter-fixer` と同構造（diff）
- **AC-10**: `.claude/settings.json` の git diff が空（hooks セクション変更なし）

### Integration / Gate Tests

- **AC-8**: `docs/working/TASK-0107/handoff.md` 存在 + 6 要素網羅（grep）
- **AC-11**: Step 1〜5 を踏んだ後 `status.md` に完了マーカー + `decision-log.jsonl` に append-only エントリ
- **AC-12**: `bin/plangate doctor --check-settings` FAIL 状態で V-1 / handoff 完了処理がブロックされること

### 回帰

- 既存 `tests/run-tests.sh` 全 PASS 維持
- 既存 Agent / Skill / Command への影響なし

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| **doctor --json schema 未確認のまま Agent 実装が空振る** | **critical** | Step 1 で `bin/plangate doctor --json` を実行し schema を `contract-notes.md` に保存。実 schema に `scope / checks[] / passed` 等が含まれることを確認後に Agent 実装開始（U6） |
| **Agent が apply-claude-settings.sh を実行可能になる**（責務違反） | **critical** | grep negative test を test-cases に固定 + Agent definition 本文に「実行禁止・提示のみ」を明文化（AC-3） |
| **Workflow-owned 永続ロックの不備で Shadow Config 防止漏れ** | **critical** | Step 6 を独立 Step に分離し、append-only 記録 + `--check-settings PASS` ゲート + 解消不能 FAIL skip 記録パスを必須化（AC-11/12/13） |
| **TASK ID 解決の不整合（U7）**: 固定パス記録で `/plangate-setup` の将来利用と衝突 | **major** | Step 1 で TASK ID 動的解決ロジック（起動時に `docs/working/TASK-XXXX/` 特定 or 不明時 guard）を確定（R-008） |
| **AC-12 自己言及デッドロック**: TASK-0107 自身の handoff 生成時に `--check-settings` FAIL | **major** | 本 PBI 開発中は手動で wiring を完了させてから V-1/handoff 検証に入る手順を Step 8 に明文化（Gemini 指摘） |
| **Command が薄くなくなる**（Rule 1 違反） | **major** | Step 4 で Command 内に実装手順を書かず Agent invocation のみとする（grep 検査で `bin/plangate` 等の実装記述ゼロ確認） |
| **既存 Agent との frontmatter 構造の乖離** | minor | Step 5 で `acceptance-tester` / `linter-fixer` を Read し frontmatter を踏襲（AC-9） |
| **doctor --json 出力フォーマット将来変更** | medium | Codex 確認情報に基づき `level / ok / passed` 中心の解釈にし、メッセージ内容に依存しない（R-003） |
| **三層構成の管理コスト増** | minor | 既存 Agent パターン踏襲で構造統一。Skill / Agent / Command 各テンプレ準拠 |
| **C-3 条件付き降格の誤適用** | major | `lite_eligible=false` 確定（Hardening Override: Shadow Config / 責務4分類に直接接続）。同期 C-3 固定（R-002） |

## Questions / Unknowns

全 Unknowns は Step 1 で解決見込み。pbi-input.md r1 §5 の対応:

| Unknown | 解決 Step | 解決方法 |
|---------|---------|---------|
| **U1** Agent tools 最小集合 | Step 1 | tools=[Bash(`bin/plangate doctor --json`),Read,Write(`docs/working/TASK-*/`限定)] を検討。Edit は不要想定 |
| ~~U2~~ Mode | 解決済 (r1) | `high-risk` |
| **U3** 完了サマリ配置・命名 | Step 6 | `status.md` 末尾 or `setup-summary.md` 別ファイル、Step 1 で確定 |
| **U4** Command の Agent 起動方式 | Step 1 | 既存 `.claude/commands/` を Read し最も近いパターンを採用 |
| **U5** Skill チェックリスト粒度 | Step 3 | doctor schema + 5 要素対応表確定後に決定（抜粋方針） |
| **U6** `doctor --json` 出力 schema | Step 1 | 実行で確認。Codex 事前確認情報: `scope`, `checks[]{name,ok,level,detail}`, `failures`, `warnings`, `passed` |
| **U7** TASK ID / 記録先動的解決 | Step 1 | Task-local（起動時に `docs/working/TASK-XXXX/` 特定）+ Task ID 不明時 guard（「Task ID 指定 or 新規 Task 作成」促し） |

## Mode 判定

**`high-risk`** 確定（C-2 R-002 反映、r1 §5 と一致）

### 判定根拠

- **AC 数**: 13 件 → 定量上 critical レンジだが、AC-11〜13 は test-case 検証可能な独立小単位のため high-risk が妥当
- **変更ファイル数**: 6-8（contract-notes / SKILL / Command / Agent / test / status / decision-log / handoff）→ high-risk レンジ
- **変更種別**: 新規三層 + Workflow-owned 永続ロック新規 → 高
- **リスク**: 高（Human-owned 操作の追跡漏れは Shadow Config 構造防止に直結）
- **影響範囲**: 新規ファイルのみで既存挙動破壊なし、ロールバック容易
- **Hardening Override 適用**: 責務 4 分類・Shadow Config 防止に接続 → `lite_eligible=false` 固定
- **critical 不要**: 段階的ロールバック不要 / 公開 API 破壊変更なし / DB スキーマ変更なし

### フェーズ適用（mode-classification.md high-risk 列）

| フェーズ | 適用 |
|---------|------|
| brainstorm | ○（完了） |
| plan 生成 | ○（本 plan） |
| C-1 17 項目 | ○ |
| C-2 外部 AI レビュー | **R1+R2+R3 実施**（pbi-input.md r0/r1 で R1+R2、plan/todo/test-cases に対する R3 で plan 段階の最終確認。`lite_eligible=false` のため Lite ゲートは適用せず、review round 数の積上で品質担保。各 round の指摘は review-external.md に R-NNN として集約） |
| C-3 人間レビュー | ○（**同期固定**、lite_eligible=false） |
| exec TDD + 並列 | ○ |
| L-0 リンター | ○ |
| V-1 受け入れ検査 | ○（`doctor --check-settings PASS` 必須） |
| V-2 コード最適化 | ○ |
| V-3 外部レビュー | ○ |
| V-4 リリース前 | -（critical でないため不要） |
| PR 作成 | ○ |
| C-4 PR レビュー | ○ |
