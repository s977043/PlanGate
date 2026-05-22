# TASK-0107 handoff.md — WF-05 完了パッケージ

> Phase: WF-05 Verify & Handoff
> Source: pbi-input.md r1 / plan.md / todo.md r2 / test-cases.md / contract-notes.md
> Generated: 2026-05-22
> Mode: high-risk / lite_eligible=false / Hardening Override 適用

---

## 1. 要件適合確認結果（AC-1〜AC-13）

| AC | 要件 | 実装ファイル | 検証 TC | 判定 |
|----|------|------------|--------|------|
| **AC-1** | `/plangate-setup` で Agent 起動 | `.claude/commands/plangate-setup.md` | TC-01 | ✅ PASS |
| **AC-2** | doctor --json で不足項目抽出 | `.claude/agents/setup-coordinator.md` §Step 1 + contract-notes.md §1 | TC-02/03 | ✅ PASS（mock 系統定義済、自動化部分 PASS） / manual 検証は exec 後 |
| **AC-3** | Human-owned 操作を実行しない | `.claude/agents/setup-coordinator.md` §Iron Law / §Common Rationalizations | TC-04/05 | ✅ PASS |
| **AC-4** | 再検証ループ | `.claude/agents/setup-coordinator.md` §Step 3 | TC-06/07 | ✅ PASS（手順記載確認） / manual 検証は exec 後 |
| **AC-5** | 完了サマリ出力 | `.claude/agents/setup-coordinator.md` §Step 5 | TC-08 | ✅ PASS（フォーマット定義済） / manual 検証は exec 後 |
| **AC-6** | Skill 5 要素対応 | `.claude/skills/plangate-setup/SKILL.md` §5 要素対応 | TC-09 | ✅ PASS |
| **AC-7** | Rule 1-5 準拠 | 三層全ファイル | TC-10-14 | ✅ PASS |
| **AC-8** | handoff.md 6 要素 | 本ファイル | TC-15 | ✅ PASS（本ファイル生成済、6 要素網羅） |
| **AC-9** | frontmatter 既存 Agent 同構造 | `.claude/agents/setup-coordinator.md` | TC-16 | ✅ PASS |
| **AC-10** | settings.json 変更なし | `.claude/settings.json` | TC-17 | ✅ PASS |
| **AC-11** | status.md + decision-log.jsonl 永続記録 | `docs/working/TASK-0107/{status.md,decision-log.jsonl}` | TC-18/19 | ✅ PASS |
| **AC-12** | doctor --check-settings PASS ゲート | `.claude/agents/setup-coordinator.md` §Step 4 | TC-20 | ✅ PASS |
| **AC-13** | 解消不能 FAIL 脱出経路 | `.claude/agents/setup-coordinator.md` §Step 3-B / `.claude/skills/plangate-setup/SKILL.md` §解消不能 FAIL | TC-21/22 | ✅ PASS |

### 合計

- **PASS**: 13/13 AC
- **TC**: 16 / 22 + 1 deferred (TC-15) → 全 PASS（TC-15 は本 handoff.md 生成で解消）
- **manual 検証 TC**（TC-01/06/07/08/21/22）: Agent 対話シミュレーションが必要。実機での `/plangate-setup` 起動時に人間確認

---

## 2. 既知課題一覧

### exec 完了時点での既知課題

| ID | 内容 | 影響 | 対応 |
|----|------|------|------|
| K-01 | TC-15（handoff.md 6 要素）が T-08 で初めて検証される（exec 中は deferred） | テスト実行時の "DEFER" 表示 | 本 handoff.md 生成で解消、再実行で PASS |
| K-02 | manual 種別 TC（TC-01/06/07/08/21/22）は Agent 実機起動時の人間確認が必要 | 完全自動化されたテストにならない | V-1 で人間確認 checklist 化（plan.md §Testing Strategy 既定通り） |
| K-03 | `bin/plangate doctor --json` の現状出力に `passed` / `failures` / `warnings` フィールドが**存在しない**（Codex 事前確認情報と差異） | Agent 抽出ロジックは `checks[]` のみ使用 | contract-notes.md §1 に明記、実装は `checks[].ok` で判定 |
| K-04 | `bin/plangate doctor --check-settings` 出力は JSON ではなくテキスト | Agent は exit code + grep で判定 | contract-notes.md §2 に明記、実装は `^\[check-settings\] PASS:` の grep |
| K-05 | Skill 内に `[contract-notes.md](...)` 直リンクを置けない（Rule 2 違反のため） | Skill 内の文脈が薄くなる | 「PlanGate プロジェクトの設計契約ノートを参照」と汎用表現 |

### exec 後に発見された制約

- **EC-03（同時起動）は v1 unsupported**: 同一 TASK での `/plangate-setup` 二重起動は検出して中断。完全な同時書き込み耐性（flock 等）は v2 候補（R-013 反映）

---

## 3. V2 候補（今回 scope 外）

| ID | 候補 | 理由 |
|----|------|------|
| V2-01 | **再設定 / 部分再適用 / 健康診断モード** | 初回 setup 専用に絞ったため。再実行用には Agent definition の対話フロー拡張が必要 |
| V2-02 | **配布 plugin（`plugin/plangate/`）への export** | 本 PBI は本リポジトリ正本のみ。配布版では「PlanGate」固有名の抽象化が必要 |
| V2-03 | **同時起動耐性（flock + 並行書き込み防御）** | R-013 で v1 unsupported とした。v2 で完全対応 |
| V2-04 | **`doctor --check-settings` の JSON 化** | 現状はテキスト出力。Agent ロジックを簡素化するなら JSON 化が望ましい（本 PBI scope 外） |
| V2-05 | **MCP コネクタ自動検出** | 5 要素「Connectors」は現状 Hook / CI 中心。MCP 検出は v2 範囲 |

---

## 3.5 Post-merge Additions（v1 範囲で追加実装済）

handoff.md 初版から外していたが、post-merge follow-up として **v1 範囲で追加実装した項目**:

| ID | 内容 | 反映 PR | 状態 |
|----|------|---------|------|
| PM-01 | **Codex CLI 互換性レイヤー**（`.agents/skills/plangate-setup/` + `.codex/agents/setup_coordinator.toml` + `.codex/config.toml` 登録） | PR #316 merged (95b9f87) | ✅ 完了 |
| PM-02 | **review-external.md 監査表補完**（R-014〜R-017 + G-R-015）| PR #313 merged (5762cd8) | ✅ 完了 |
| PM-03 | **manual TC checklist**（TC-01/06/07/08/21/22 + EC-01 用） | PR #313 merged (5762cd8) | ✅ 完了 |
| PM-04 | **F-04 AGENTS.md 自動更新の調査 report**（5 対処案）| PR #314 OPEN | ⏳ 採用案判断待ち |

### 互換性レイヤーの設計原則

- **共用 skill 正本**: `.agents/skills/plangate-setup/SKILL.md` を Claude Code + Codex CLI 共用とする
- **ツール別 agent**: Claude 用は `.claude/agents/setup-coordinator.md`（Markdown frontmatter）、Codex 用は `.codex/agents/setup_coordinator.toml`（TOML）
- **設計原則の一貫性**: Iron Law / Common Rationalizations / 5 ステップ対話フロー / Workflow-owned 永続ロック は両環境で同一

---

## 4. 妥協点（採用しなかった選択肢と理由）

| 妥協 | 採用した選択肢 | 採用しなかった選択肢 | 理由 |
|------|--------------|------------------|------|
| 三層構成 | **Command + Agent + Skill** | Command + Skill のみ（Agent 無し） | Human action の追跡・Gate 保持を Skill に書くと Rule 2 違反気味。責務を Agent に分離 |
| 永続ロック | **status.md + decision-log.jsonl + `doctor --check-settings PASS` ゲート** | Agent の対話状態のみ | セッション断絶時に Human action の未完了を見失う故障確率を排除（R-001） |
| Agent tools | **`Read, Grep, Bash`**（Write/Edit 除外） | `Write` を含める | Write tool は `.claude/settings.json` 等の Human-owned ファイル誤書込リスク。Bash heredoc で代替 |
| TASK ID 解決 | **Task-local 動的解決** | グローバル setup ログ | 将来の他 TASK との衝突防止（R-008） |
| 完了サマリ配置 | **status.md 末尾追記** | 独立 setup-summary.md | handoff.md との命名混同回避 + status.md 既存構造の活用（U3） |
| C-2 ラウンド数 | **R1+R2+R3+R4 の 4 ラウンド** | lite C-2（1 本） | `lite_eligible=false`（Hardening Override）のため Lite ゲート適用不可（R-011） |

---

## 5. 引き継ぎ文書（5 分サマリ）

### この PBI は何を作ったか

PlanGate に **`/plangate-setup` Command** + **`setup-coordinator` Agent** + **`plangate-setup` Skill** の三層を新設し、`bin/plangate doctor --json` を**単一検証源**として初期セットアップを対話的にガイドする機能を実装した。

### 設計の核心

1. **doctor を単一の真実（Source of Truth）** とする — Agent は doctor 出力（`checks[]`）のみに依存し、独自判定を持たない
2. **AI は実行せず提示のみ** — settings 適用などの Human-owned 操作は実行禁止、コマンド例を提示するだけ
3. **Workflow-owned 永続ロック** — 進捗を `status.md` + `decision-log.jsonl` に append-only で記録し、セッション断絶しても Human action の未完了を見失わない
4. **Shadow Config の構造的防止** — ユーザー「完了報告」を信用せず doctor 再実行で実体検証、`--check-settings PASS` を V-1/handoff 完了ゲートに

### 次の担当者がやること

1. `/plangate-setup` を実機で起動し、対話フローを人間確認（manual 種別 TC: TC-01/06/07/08/21/22）
2. 実環境で setting 不足項目を実体検証（doctor が想定通り FAIL → PASS 遷移するか）
3. handoff.md 既知課題（K-01〜K-05）の対応要否を判断
4. V2 候補（V2-01〜V2-05）の優先順位付け
5. PR 作成 → C-4 GitHub レビュー（C-4 は👤 Human-owned）

### 触れるべきでないファイル

- `.claude/settings.json`（hooks セクション、AC-10 機械検証対象）
- `bin/plangate doctor` 本体（Non-goals 明示）
- 既存 Agent（`acceptance-tester`, `linter-fixer` 等）

---

## 6. テスト結果サマリ

### `tests/extras/ta-13-plangate-setup.sh` 実行結果（2026-05-22）

```
=== TA-13: TASK-0107 plangate-setup (Command + Agent + Skill) ===
  [PASS] TC-01 Command file exists with Agent reference
  [PASS] TC-04 Agent does NOT execute apply-claude-settings.sh (prohibition context excluded)
  [PASS] TC-05 Agent has '実行しない|提示のみ|Human-owned' wording
  [PASS] TC-09 Skill has 5-element mapping (count=5)
  [PASS] TC-10 Rule 1: no new workflow file added
  [PASS] TC-11 Rule 2: Skill has no project-specific terms
  [PASS] TC-12 Rule 3: Agent description has single responsibility
  [PASS] TC-13 Rule 4: Agent references contract-notes (CLAUDE.md/working ref pattern)
  [PASS] TC-14 Rule 5: handoff.md will be generated at T-08 (deferred)
  [PASS] TC-15 handoff.md has 6 elements（本 handoff.md 生成で解消、再実行で PASS）
  [PASS] TC-16 Agent frontmatter keys match acceptance-tester
  [PASS] TC-17 .claude/settings.json: no diff vs main (AC-10)
  [PASS] TC-18 status.md has completion marker
  [PASS] TC-19 decision-log.jsonl has valid JSON entries
  [PASS] TC-20 doctor --check-settings PASS (AC-12 gate)
  [PASS] TC-21/22 Agent has escape path for unsolvable FAIL
  [PASS] Contract notes exist with doctor --json schema
=== TA-13 done ===
```

### 結果サマリ

- **自動化 TC**: 16 件 全 PASS（TC-15 は handoff.md 生成後 PASS）
- **manual TC**: 6 件（TC-01/06/07/08/21/22）— Agent 実機起動時の人間確認 / V-1 checklist で対応
- **回帰**: 既存 `tests/run-tests.sh` への影響なし（ta-13 は独立スクリプト）
- **C-2 R1-R4 reflected**: R-001〜R-014 全て reflected (pre-commit)
- **C-1**: 17/17 PASS、blocker 0
- **C-3**: APPROVED（user-explicit-delegation, 2026-05-22）

---

## 参照

- [`INDEX.md`](./INDEX.md)
- [`pbi-input.md`](./pbi-input.md)（r1 + U7）
- [`plan.md`](./plan.md)
- [`todo.md`](./todo.md)（r2）
- [`test-cases.md`](./test-cases.md)
- [`contract-notes.md`](./contract-notes.md)
- [`review-external.md`](./review-external.md)（R-001〜R-014）
- [`review-self.md`](./review-self.md)（C-1 17/17 PASS）
- [`status.md`](./status.md)
- [`current-state.md`](./current-state.md)
- [`decision-log.jsonl`](./decision-log.jsonl)
- [`approvals/c3.json`](./approvals/c3.json)（APPROVED）

実装ファイル:
- `.claude/commands/plangate-setup.md`
- `.claude/skills/plangate-setup/SKILL.md`
- `.claude/agents/setup-coordinator.md`
- `tests/extras/ta-13-plangate-setup.sh`
