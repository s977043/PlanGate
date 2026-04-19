# PBI INPUT PACKAGE: Workflow 5 phase を定義する（WF-01〜WF-05）

> 作成日: 2026-04-20
> PBI: [TASK-0021-A] Workflow 5 phase を定義する（WF-01〜WF-05）
> チケットURL: https://github.com/s977043/plangate/issues/23
> 親チケット: #22 / `docs/working/TASK-0021/pbi-input.md`

---

## Context / Why

親チケット #22 で合意された **PlanGate × Workflow / Skill / Agent ハイブリッドアーキテクチャ** の骨格となる **Workflow 5 phase** を定義する。本 TASK は後続サブ（#24 Skill、#25 Agent、#26 Solution Design 独立化、#27 Verify & Handoff 標準化、#28 Rule 統合）の基盤となるため、**最初に着手**する必要がある。

親 PBI で合意済みの再構築ルール（Rule 1〜5）のうち、本 TASK は **Rule 1** に直接対応する:

> **Rule 1**: Workflow は**順序と完了条件だけ**を持つ。実装ノウハウは書かない。

Workflow は「何をどの順番でやるか」と「各 phase の完了条件」だけを定義し、具体的な実装手順・観点・判断基準は Skill / Agent / CLAUDE.md に委譲する。

---

## What（Scope）

### In scope

#### Phase 定義ファイル（5個）

`docs/workflows/` 配下に 5 phase の定義ファイルを作成する:

| Phase | ファイル | 目的 | 完了条件 |
|---|---|---|---|
| WF-01 | `01_context_bootstrap.md` | 案件の前提・制約・品質基準を読み込む | 対象範囲 / 使える技術 / 禁止事項 / 成果物定義が明文化 |
| WF-02 | `02_requirement_expansion.md` | 曖昧な要求から仕様の抜け漏れを洗い出す | 機能要件 / 非機能要件 / 対象外 / 例外条件 / UX期待値が整理 |
| WF-03 | `03_solution_design.md` | 仕様を実装可能な構造へ落とす | モジュール構成 / データフロー / 状態管理 / 失敗時扱い / テスト観点が決定 |
| WF-04 | `04_build_and_refine.md` | 設計に従って最小単位で実装 | 動作するコード / 自己レビュー / 明示的な既知課題 |
| WF-05 | `05_verify_and_handoff.md` | 品質確認し、次フェーズへ渡せる状態にする | 要件適合確認 / 既知課題一覧 / V2候補 / 引き継ぎ文書 |

#### 各 phase 定義ファイルの必須項目

1. **目的**: 1〜2 文で簡潔に
2. **入力**: 前フェーズ完了時点で利用可能な artifact
3. **完了条件**: チェックリスト形式（Rule 1 準拠で手順を含まない）
4. **呼び出す Skill**: Skill 名の列挙（定義は #24 の範囲）
5. **主担当 Agent**: Agent 名の列挙（定義は #25 の範囲）
6. **次 phase への引き継ぎ**: 次 phase が受け取る artifact

#### 付随ドキュメント

- `docs/workflows/README.md`: Workflow 全体の目次・読み方・PlanGate フェーズとの対応
- **PlanGate 既存フェーズ（A/B/C-1〜D/L-0/V-1〜V-4）との対応表**（README に含める）

### Out of scope

- **Skill の実装**（#24 の範囲）: Skill 名の列挙のみで、内部実装は参照しない
- **Agent の実装**（#25 の範囲）: Agent 名の列挙のみで、内部実装は参照しない
- **WF-03 Solution Design の詳細 artifact テンプレート**（#26 の範囲）: 本 TASK では枠のみ
- **WF-05 Verify & Handoff の詳細 artifact テンプレート**（#27 の範囲）: 本 TASK では枠のみ
- **Rule 1〜5 / 境界ルールの統合ドキュメント**（#28 の範囲）: 本 TASK では Rule 1 準拠確認のみ
- **既存 PlanGate v5/v6 ドキュメントの書き換え**: 対応表の追加のみで、既存ドキュメント本体は触らない
- **実装ノウハウの記述**: Rule 1 違反となるため明示的に禁止

---

## 受入基準

- [ ] `docs/workflows/01_context_bootstrap.md` 〜 `05_verify_and_handoff.md` の 5 ファイルが存在する
- [ ] 各 phase 定義ファイルに **必須6項目**（目的 / 入力 / 完了条件 / 呼び出しSkill / 主担当Agent / 次phaseへの引き継ぎ）が全て記載されている
- [ ] 各 phase が **Rule 1 準拠**（順序と完了条件のみ、実装ノウハウなし）である
- [ ] `docs/workflows/README.md` が存在し、**PlanGate 既存フェーズとの対応表**が含まれている
- [ ] 対応表には **親 PBI で合意された実行シーケンス**（orchestrator → requirements-analyst → qa-reviewer → solution-architect → implementation-agent → qa-reviewer → orchestrator）と WF-01〜WF-05 の対応が明示されている
- [ ] 既存 `docs/plangate.md` / `docs/plangate-v6-roadmap.md` との整合（矛盾なし）が取れている
- [ ] markdown lint が通る（既存 CI との整合）

---

## Notes from Refinement

### 親 PBI からの継承事項

- **Rule 1**: Workflow は順序と完了条件だけを持つ
- **実行シーケンス**:
  1. orchestrator が WF-01 を開始
  2. requirements-analyst が requirement-gap-scan で仕様拡張（WF-02）
  3. qa-reviewer が edgecase-enumeration と acceptance-criteria-build で締める（WF-02）
  4. solution-architect が WF-03 で実装構造化
  5. implementation-agent が WF-04 で実装
  6. qa-reviewer が WF-05 で要件照合
  7. orchestrator が handoff を出す

### 設計判断（決定事項）

| 項目 | 決定 | 理由 |
|---|---|---|
| 配置先 | `docs/workflows/` | リポジトリ標準の docs 配下。`.claude/workflows/` も検討したが Claude Code に特化しすぎるため不採用 |
| ファイル命名 | `0N_snake_case.md` | ソート順と可読性を両立 |
| 目次ファイル | `docs/workflows/README.md` | PlanGate 既存フェーズとの対応表をここに置く |
| Skill / Agent 記述 | **名前の列挙のみ** | Rule 2 / Rule 3 の分離原則に従う。実装は #24 / #25 |
| 実装ノウハウ | **書かない** | Rule 1 違反を防ぐため、PR レビューで明示チェック |

### 想定モード判定

**full**（高）を想定（C-2 Codex レビュー EX-01 で standard → full に再分類済み）。

- 変更ファイル数: 6（5 phase ファイル + README） → full 帯（6-15）
- 受入基準数: 7 → full 帯（6-10）
- タスク数: 14 → full 帯（11-20）
- 変更種別: 新規ドキュメント追加（骨格定義）
- リスク: 中（後続サブ issue の骨格を決定するため、ここの定義が甘いと全体に波及）
- 影響範囲: 複数レイヤー相当（後続 5 サブ issue の基盤） → full
- ロールバック: 容易（docs のみ）

---

## Estimation Evidence

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| 実装ノウハウを誤って書き込み、Rule 1 違反になる | Medium | 各 phase 定義で「完了条件」と「手順」を明確に区別。レビュー時に `How to / Steps / 手順` の単語が含まれていないかチェック |
| 既存 PlanGate フェーズ（A/B/C-1〜D/L-0/V-1〜V-4）との対応関係が不明瞭 | Medium | README に対応表を作成し、ユーザーが既存フローからハイブリッドフローへ読み替えられるようにする |
| Skill 名 / Agent 名の命名が #24 / #25 実装時に変わる | Low | 本 TASK で確定した名前を正本とし、#24 / #25 はそれに従う（逆ではない） |
| PlanGate v5/v6 ドキュメントとの矛盾 | Medium | 本 TASK は新規追加であり、既存を書き換えない。整合確認のみ受入基準に含める |
| 5 phase を独立ファイル化することで参照コストが上がる | Low | README で目次化、1 phase あたり ~50 行に収める |

### Unknowns

- `docs/workflows/` を新設することへの既存チーム慣習上の抵抗の有無（推定: 低）
- Rule 1 に「完了条件」と「手順」のグレーゾーン（例: 「〜が明文化されている」は完了条件、「〜を明文化する」は手順）があるか
- 対応表の粒度（PlanGate の全フェーズを並べるか、主要フェーズのみ並べるか）

### Assumptions

- `docs/workflows/` は新設しても既存ワークフローを阻害しない
- Phase 定義ファイル 1 個あたり 50〜80 行程度で必要十分
- Skill / Agent の名前は親 PBI で列挙されたものを正本として扱う
- 実行シーケンス（親 PBI Notes 参照）は確定済みで、本 TASK で変更しない
- markdown lint の既存ルールに従えば品質は担保される

---

## 次フェーズへの申し送り

このPBI INPUT PACKAGE は **C-3 ゲート（plan 承認）前の素材**として、次フェーズで以下に展開される:

1. **B: plan 生成** — `plan.md` / `todo.md` / `test-cases.md` を生成
2. **C-1: セルフレビュー** — Plan 7項目 + ToDo 5項目 + TestCases 3項目 + 総合 2項目 = 17項目チェック（full モード）
3. **C-2: 外部AIレビュー** — full モードでは必須（モード分類マトリクス参照）
4. **C-3: 人間レビュー** — 三値ゲート（APPROVE / CONDITIONAL / REJECT）

**モード判定**: `full`（plan.md の Mode判定セクションで確定 / C-2 EX-01 対応後）
