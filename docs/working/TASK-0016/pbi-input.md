# PBI INPUT PACKAGE: Claude Code plugin 化 — PlanGate の配布パッケージ整備

> 作成日: 2026-04-19
> PBI: Claude Code plugin 化: PlanGate の配布パッケージを整備する
> チケットURL: https://github.com/s977043/plangate/issues/16

---

## Context / Why

PlanGate は現在、`.claude/commands/`、`.claude/agents/`、`.claude/skills/`、`scripts/`、`.codex/` を含むリポジトリ配布前提の構成になっている。

単一リポジトリ内では十分機能しているが、Claude Code 向けに plugin 化することで以下を改善できる:

- **横展開容易化**: 複数リポジトリ・複数開発者への導入を簡単にする
- **単一導入単位**: PlanGate の Claude Code 側機能を 1 つの導入単位として配布する
- **将来の versioning / update / marketplace 配布に備える**
- **責務明確化**: `commands` / `skills` / `agents` / `hooks` を整理し、役割を明示する

---

## What（Scope）

### In scope

- Claude Code plugin ディレクトリ構成の追加（最小構成スケルトン）
- plugin 名称: **`plangate`**（namespace 無し）
- 配布境界: **B. 中核**構成
  - skills: `working-context`, `ai-dev-workflow`, `brainstorming`, `self-review`, `pr-review-response`, `pr-code-review`, `setup-team`
  - agents（8 体）: `workflow-conductor`, `spec-writer`, `implementer`, `test-engineer`, `linter-fixer`, `acceptance-tester`, `code-optimizer`, `release-manager`
  - rules: `working-context.md`, `review-principles.md`, `mode-classification.md`
  - scripts: PlanGate 中核スクリプトのみ `bin/` に配置
- commands→skills 移行: **C. ハイブリッド**（主要導線のみ skills 化、utility は commands 併存）
- 互換方針: **A. デュアル運用**（既存 `.claude/` 維持 + plugin 追加導入可能）
- `hooks/` ディレクトリの枠だけ用意（初版は空、将来の deterministic hooks 用）
- README に plugin 導入手順と新旧導入方法の差分を追記
- 既存ユーザー向け migration note の用意

### Out of scope

- Codex CLI 向け `.codex/` 配布方式の統合
- marketplace 公開そのもの（構成は準備するが公開は別チケット）
- 既存 workflow の全面的な仕様変更
- プロジェクト固有エージェントの plugin 同梱（`backend-specialist`, `frontend-specialist`, `database-architect`, `devops-engineer` 等）
- 専門用途エージェント（`security-auditor`, `penetration-tester`, `performance-optimizer` 等）の同梱（opt-in 拡張として別途検討）
- 補助エージェント（`migration-agent`, `research-analyst`, `explorer-agent`, `project-planner`, `retrospective-analyst`）の同梱
- deterministic hooks の実装本体（枠のみ）
- `.claude/` の削除または縮小（A. デュアル運用により温存）

---

## 受入基準

- [ ] Claude Code plugin として **インストール可能**である（`plugin.json` + ディレクトリ構成が Claude Code の plugin 仕様に準拠）
- [ ] plugin 単体で **PlanGate 主要導線が再現**できる
  - [ ] `/working-context` が plugin 経由で動作する
  - [ ] `/ai-dev-workflow` が plugin 経由で動作する
  - [ ] plan → C-1 セルフレビュー → exec → L-0 → V-1 → PR のフローが 8 agents で完結する
- [ ] 既存 `plangate` リポジトリ利用者が **移行判断可能**な状態である
  - [ ] README に新旧導入方法の差分が明記されている
  - [ ] migration note が `docs/` 配下に用意されている
- [ ] **Codex CLI 側が plugin 化対象外**であることが README で明記されている
- [ ] plugin 同梱 agents（8 体）が **プロジェクト固有依存を持たない**ことを確認済み（`backend-specialist` 等が含まれていない）
- [ ] `.claude/` 既存構成が **破壊されない**（デュアル運用が成立する）
- [ ] `hooks/` ディレクトリが存在し、将来拡張可能な構造である

---

## Notes from Refinement

### 決定事項（2026-04-19 brainstorming）

| 項目 | 決定 | 根拠 |
|------|------|------|
| **Q1. 配布境界** | B. 中核 | 受入条件「主要導線が plugin 経由で再現」を最小満たす。A は不足、C は他プロジェクト汎用性喪失 |
| **Q2. plugin 名称** | `plangate` | プロジェクト名と一致、短く直感的 |
| **Q3. commands 移行** | C. ハイブリッド | 段階移行でリスク分散、主要導線のみ skills 化 |
| **Q4. 互換方針** | A. デュアル運用 | 既存利用者無影響、移行期間を確保 |
| **Q5. agents 同梱範囲** | 8 体（PlanGate 中核 agents） | プロジェクト固有/専門/補助 agents は除外し汎用性確保 |
| **Q6. scripts 配置** | plugin 内 `bin/` | 中核のみ配置、プロジェクト固有は repo 側に残す |
| **Q7. hooks 設計** | 枠のみ用意 | 初版は空、将来の deterministic hooks 土台として準備 |

### 想定ディレクトリ構造

```text
plangate/                        # plugin 配布単位
├── plugin.json                  # Claude Code plugin manifest
├── README.md                    # plugin 用 README
├── skills/
│   ├── ai-dev-workflow/
│   ├── working-context/
│   ├── brainstorming/
│   ├── self-review/
│   ├── pr-review-response/
│   ├── pr-code-review/
│   └── setup-team/
├── agents/
│   ├── workflow-conductor.md
│   ├── spec-writer.md
│   ├── implementer.md
│   ├── test-engineer.md
│   ├── linter-fixer.md
│   ├── acceptance-tester.md
│   ├── code-optimizer.md
│   └── release-manager.md
├── rules/
│   ├── working-context.md
│   ├── review-principles.md
│   └── mode-classification.md
├── hooks/                       # 将来拡張用（初版は空）
├── bin/                         # PlanGate 中核スクリプト
└── settings.json                # plugin デフォルト設定
```

### 将来計画（2 層構成）

1. **`plangate` リポジトリ**: 正本 / ドキュメント / Claude + Codex の共通資産
2. **Claude Code plugin**: Claude 向け配布パッケージ

運用実績を積んだ後、将来的に plugin を marketplace へ公開する可能性を残す。

### 想定モード判定

**full**（高）を想定。

- 変更ファイル数: 16+ 体（plugin 構成ファイル多数）
- 受入基準数: 9 件
- 変更種別: アーキテクチャ再構成
- リスク: 中（既存ユーザーへの影響は A. デュアル運用で最小化）
- 影響範囲: 複数レイヤー

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Claude Code plugin 仕様の変更・未確定部分があり、構造が後日変わる可能性 | Medium | plugin 仕様を事前に調査・検証し、公式ドキュメントに準拠。変更リスクのある部分は最小構造に留める |
| 同梱 agents がプロジェクト固有依存を隠れて持っている可能性 | Medium | 各 agent 定義を精査し、Laravel/PostgreSQL/ECS 等の前提が無いか確認する手順を受入条件に含める |
| デュアル運用により `.claude/` と plugin で設定が重複し、保守負荷が倍増する | Medium | plugin 側を正本候補と位置付け、将来的に `.claude/` を薄くする前提を migration note に記載 |
| plugin 経由で導入したユーザーが rules/ の参照先に迷う | Low | README で参照優先順位（project-rules.md > plugin 内 rules）を明記 |
| skills の一部が commands との併存で挙動差分が出る | Low | ハイブリッド方式の境界ルール（どれを skills 化するか）を事前策定 |

### Unknowns

- Claude Code の plugin 仕様の正式版（`plugin.json` のスキーマ、namespace ルール、marketplace 登録要件）
- plugin 内の skills 呼び出し prefix（`plangate:ai-dev-workflow` の形式が正確に使えるか）
- hooks の実装タイミング（本チケット内で枠のみか、PoC 実装まで含めるか）
- plugin に同梱する scripts の具体的な範囲（ci スクリプトは含めるか）

### Assumptions

- Claude Code は 2026-04 時点で plugin 機構を持ち、`plugin.json` で skills/agents/rules/hooks を束ねられる
- 既存の `.claude/commands/*.md` をそのまま skills に変換可能（中身は構造的に互換）
- 同梱対象 8 agents は PlanGate 中核に関わる最小セットであり、相互依存が閉じている
- `hooks/` の仕様は初版では定義せず、ディレクトリ存在のみで将来拡張を示唆できる
- plugin 経由の `/working-context` と `/ai-dev-workflow` は、既存 slash command と同一 UX を提供できる

---

## 次フェーズへの申し送り

このPBI INPUT PACKAGE は **C-3 ゲート（plan 承認）前の素材**として、次フェーズで以下に展開される:

1. **B: plan 生成** — workflow-conductor 経由で `plan.md` / `todo.md` / `test-cases.md` を生成
2. **C-1: セルフレビュー** — 17 項目チェック（full モードのため）
3. **C-2: 外部AIレビュー** — full モードで必須
4. **C-3: 人間レビュー** — 三値ゲート（APPROVE / CONDITIONAL / REJECT）

**モード判定**: `full`（plan.md の Mode判定セクションで確定）
