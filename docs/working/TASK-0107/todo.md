# TASK-0107 EXECUTION TODO

> Source: `plan.md` Work Breakdown / Mode: **high-risk** / C-3 同期固定（lite_eligible=false）
> Generated: 2026-05-22
> Revision: r1（C-2 R3 R-009/R-010 反映: C-3 を exec 前に移動、workflow-conductor 自動制御範囲を分離）

## Legend

- 🤖 = Agent タスク（人手 todo の対象）
- 👤 = Human タスク
- 🚩 = チェックポイント（plan.md の Work Breakdown 連動）
- ⬜ = 未着手 / 🟡 = 進行中 / ✅ = 完了

> **Iron Law（working-context.md 準拠）**:
> L-0 / V-1 / V-2 / V-3 / V-4 / PR 作成は **workflow-conductor が自動制御**するため本 todo の実装タスクには含めない（「§ workflow-conductor 後続フェーズ」欄を参照）。

---

## Phase 1: 準備（C-3 ゲート前）

### T-01 🤖 Step 1: 事前契約確定
- **Output**: `docs/working/TASK-0107/contract-notes.md`
- **内容**:
  - `bin/plangate doctor --json` を実行し、実 schema を取得・保存（U6）
  - Agent tools 最小集合の決定（U1）
  - Command の Agent invocation 方式（U4）— 既存 `.claude/commands/` から最も近いパターンを採用
  - TASK ID 動的解決ロジック（U7）— Task-local 方式 + 不明時 guard 仕様
- **🚩 Checkpoint**: schema に `scope/checks[]/passed` 等が含まれることを確認、tools 集合決定
- **depends_on**: なし

### T-02 🤖 Step 2: 三層責務設計確定
- **Output**: `contract-notes.md` 末尾に責務境界表 + Cowork 5 要素 ⇄ PlanGate 対応表
- **🚩 Checkpoint**: Command / Agent / Skill の入出力境界が表で 1:1 マップ
- **depends_on**: T-01

---

## C-3 ゲート（人間レビュー・同期固定）

### G-C3 👤 C-3: 人間レビュー（**exec 前 / 必須**）
- **Output**: `docs/working/TASK-0107/approvals/c3.json`（`decision: APPROVED`、`plan_hash`、`c3_status: APPROVED`）
- **三値**:
  - APPROVE → 以下の Phase 2 exec 開始
  - CONDITIONAL → review-external.md `R-NNN` 集約 → 1 回確定反映 → 簡易 C-1 → 人間が APPROVED `c3.json` 発行
  - REJECT → plan 再生成
- **🚩 Checkpoint**: T-01/T-02 完了 + C-1 完了 + plan / todo / test-cases / review-external（R-009〜R-013 反映済）を確認
- **depends_on**: T-01, T-02 完了、C-1 完了（C-1 は workflow-conductor 制御）
- **Note**: **`lite_eligible=false` 確定**（Hardening Override 対象、同期 C-3 固定）。`bin/plangate exec` は APPROVED のみ受理

---

## Phase 2: exec（C-3 APPROVED 後のみ着手）

> **重要**: T-03〜T-08 は **G-C3 APPROVED が前提**。`depends_on` に `G-C3` を明示。

### T-03 🤖 Step 3: Skill 実装
- **Output**: `.claude/skills/plangate-setup/SKILL.md`
- **内容**:
  - frontmatter（name, description）
  - 5 要素対応表（Cowork 5 要素 ⇄ PlanGate 対応物）
  - チェックリスト（doctor 検査項目から抜粋）
  - Rule 1-5 準拠
- **🚩 Checkpoint**: frontmatter 検証 + 5 要素表 grep + Rule 2 準拠（再利用単位、案件固有なし）
- **depends_on**: G-C3
- **並列可**: T-04, T-05 と並列

### T-04 🤖 Step 4: Command 実装
- **Output**: `.claude/commands/plangate-setup.md`
- **内容**:
  - Agent invocation のみ（実装手順は書かない）
  - 起動時の TASK ID 動的解決ロジック呼び出し
- **🚩 Checkpoint**: Command 内に `bin/plangate` 直接呼び出しがゼロ + `.claude/settings.json` diff = 0
- **depends_on**: G-C3
- **並列可**: T-03, T-05 と並列

### T-05 🤖 Step 5: Agent 実装
- **Output**: `.claude/agents/setup-coordinator.md`
- **内容**:
  - frontmatter（name, description, tools 最小集合, model）— 既存 `acceptance-tester` / `linter-fixer` 構造踏襲
  - 責務本文: doctor --json 連携 / Human-owned 提示のみ / 再検証ループ / 解消不能 FAIL 脱出経路
  - 「実行禁止・提示のみ」を明文化（grep negative test 用の固定文言）
- **🚩 Checkpoint**: frontmatter 既存 Agent と同構造 + tools 最小 + `apply-claude-settings.sh` を呼ぶパス無し（grep）
- **depends_on**: G-C3
- **並列可**: T-03, T-04 と並列

### T-06 🤖 Step 6: Workflow-owned 永続ロック実装
- **Output**: Agent definition への append-only 記録ルール組込み + `status.md` / `decision-log.jsonl` の更新仕様
- **内容**:
  - 各 Step 完了ごとに `status.md` 追記 + `decision-log.jsonl` append（pending → resolved）
  - 解消不能 FAIL の skip 記録パス（AC-13）
  - TASK ID 不明時 guard
- **🚩 Checkpoint**: status.md / jsonl の append が test-case で検証可能 + `doctor --check-settings PASS` がゲート条件として記述
- **depends_on**: T-05

### T-07 🤖 Step 7: テスト/検証資産
- **Output**: `tests/extras/ta-XX-plangate-setup.sh`
- **内容**:
  - doctor --json mock 3 系統（passed / 不足 / 解消不能 FAIL）
  - Rule 1-5 grep 検査 / `.claude/settings.json` diff = 0 / status.md / decision-log.jsonl append 検査 / frontmatter 構造比較 / handoff 6 要素存在検査
- **🚩 Checkpoint**: 全 22 test-case PASS（test-cases.md 参照）。manual 種別 TC は V-1 で人間確認チェックリスト化
- **depends_on**: T-03, T-04, T-05, T-06

### T-08 🤖 Step 8: handoff.md 生成
- **Output**: `docs/working/TASK-0107/handoff.md`（6 要素網羅）
- **内容**:
  - 要件適合確認結果（AC ごとの PASS / FAIL / WARN）
  - 既知課題一覧
  - V2 候補（再設定 / 健康診断 / plugin export / 同時起動耐性）
  - 妥協点（採用しなかった選択肢と理由）
  - 引き継ぎ文書（5 分サマリ）
  - テスト結果サマリ
- **🚩 Checkpoint**: 6 要素網羅 + V-1 PASS 後に生成 + `doctor --check-settings PASS` 確認済（AC-12 ゲート）
- **depends_on**: T-07 完了 + workflow-conductor 経由の V-1 PASS

---

## § workflow-conductor 後続フェーズ（自動制御範囲・実装 todo に含めない）

> 以下は workflow-conductor が plan の Mode（high-risk）に基づき**自動的に実行**するため、本 todo の実装タスクには含めない（[`mode-classification.md`](../../../.claude/rules/mode-classification.md) high-risk 列 / [`working-context.md`](../../../.claude/rules/working-context.md) Iron Law）。

| Phase | 対象 | conductor 制御 | 本 todo タスクとの関係 |
|------|------|---------------|--------------------|
| C-1 | 17 項目セルフレビュー | ✅ 自動 | G-C3 前提（plan / todo / test-cases に対して） |
| **L-0** | リンター自動修正 | ✅ 自動 | T-07 完了後に自動実行 |
| **V-1** | 受け入れ検査（AC-1〜AC-13） | ✅ 自動 | T-07 完了後に自動実行（`doctor --check-settings PASS` 必須） |
| **V-2** | コード最適化（high-risk 必須） | ✅ 自動 | V-1 PASS 後に自動実行 |
| **V-3** | 外部モデルレビュー（実装後） | ✅ 自動 | V-2 後に自動実行（critical/major = 0 確認） |
| ~~V-4~~ | リリース前チェック | — | critical のみ。本 PBI は high-risk のため不要 |
| **PR 作成** | GitHub PR | ✅ 自動 | T-08 (handoff) + V-3 完了後 |
| **C-4** | PR レビュー（人間） | 👤 | GitHub 上で実施 |

---

## 依存関係グラフ

```
T-01 (契約確定)
   ↓
T-02 (責務設計)
   ↓
[C-1: workflow-conductor 自動制御 / 17 項目]
   ↓
G-C3 (👤 人間レビュー / 同期ゲート / APPROVED 必須)
   ↓
   ├─→ T-03 (Skill)  ─┐
   ├─→ T-04 (Command) ─┤
   └─→ T-05 (Agent)  ─┴─→ T-06 (永続ロック) ─→ T-07 (テスト)
                                                  ↓
                              [L-0 → V-1 → V-2 → V-3: workflow-conductor 自動制御]
                                                  ↓
                                                T-08 (handoff)
                                                  ↓
                              [PR 作成: workflow-conductor 自動制御]
                                                  ↓
                                                C-4 (👤 GitHub レビュー)
                                                  ↓
                                                Done
```

## 残タスク

- ⬜ T-01〜T-08: 全て未着手
- ⬜ G-C3: 人間レビュー待ち（C-1 完了後）
- 次の Action:
  1. C-2 R3 R-009〜R-013 反映完了 → 簡易 C-1 → G-C3 ゲート（人間）
  2. G-C3 APPROVED → workflow-conductor が exec（T-03〜T-08）+ L-0/V-1/V-2/V-3/PR を制御
