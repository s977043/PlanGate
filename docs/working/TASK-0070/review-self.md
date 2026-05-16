---
task_id: TASK-0070
artifact_type: review-self
schema_version: 1
status: draft
---

# C-1 セルフレビュー — TASK-0070

## Plan チェック（7項目）

| ID | 項目 | 判定 | 備考 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜7 が plan の Approach/Step に対応 |
| C1-PLAN-02 | Unknowns 処理 | PASS | 既存テスト配置を S1/T2 で確定する手順あり |
| C1-PLAN-03 | スコープ制御 | PASS | settings wiring を明示的に Out of scope |
| C1-PLAN-04 | テスト戦略 | PASS | TC-1〜8 + 回帰 + dash -n |
| C1-PLAN-05 | Work Breakdown Output | PASS | 各 Step に Output 記載 |
| C1-PLAN-06 | 依存関係 | PASS | TDD 順序・C-3 ゲート・PR#242 依存を明記 |
| C1-PLAN-07 | 動作検証自動化 | PASS | テストスクリプト化 + dash -n |

## ToDo チェック（5項目）

| ID | 判定 | 備考 |
|----|------|------|
| 粒度 | PASS | T1〜T10 適切 |
| depends_on | PASS | TDD 順序・ゲート依存を明記 |
| チェックポイント | PASS | 🚩 3 箇所 |
| Iron Law 遵守 | PASS | C-3 後に exec 開始 |
| 完了条件 | PASS | 全 AC 突合 + handoff |

## TestCases チェック（3項目）

| ID | 判定 | 備考 |
|----|------|------|
| 受入基準紐付き | PASS | AC↔TC マッピング表あり |
| Edge case 網羅 | WARN | E4 に未解決の設計論点（下記）|
| 自動化可否 | PASS | 全 TC シェルテスト化可能 |

## 総合判定: CONDITIONAL（C-3 で設計判断が必要）

### 🔴 重大論点 F-1（C-3 での意思決定を要請）: target_file 空時の fail-safe 方向

**問題**: P4(d) は `target_file` が `plan.md` か否かで BLOCK/SKIP を分岐する。
しかし現行 `settings.example.json` の EH-3 wiring は `PLANGATE_HOOK_TASK` のみ
渡し `PLANGATE_HOOK_FILE` を渡していない（wiring 追加は本 PBI Out of scope）。
よって実運用では `target_file` の唯一の供給源は stdin JSON fallback のみ。

stdin JSON のパースに失敗 / stdin が空 の場合 `target_file` が空になり、
plan.md パターンに一致しない → **SKIP**。これは「TASK 文脈を消して plan.md を
編集する」攻撃を P4(d) が防げないケースが残ることを意味する（Gemini が P4(a)
で指摘した穴が、wiring 未整備の条件下で部分的に再発）。

**選択肢**:

- **(F1-a) fail-safe = BLOCK**: `task_id 空 AND target_file 空 AND 非STRICT`
  → BLOCK。安全側だが「対象不明の汎用編集」も再びブロックされ、P4(d) の
  本来目的（汎用編集の SKIP）が wiring 整備まで実現しない。
- **(F1-b) fail-safe = SKIP（草案どおり）+ wiring を In scope に格上げ**:
  本 PBI で `settings.example.json` / `.claude/settings*.json` に
  `PLANGATE_HOOK_FILE` wiring を追加し、target_file が常に供給される前提を
  成立させる。スコープ拡大だがセキュリティ穴を実質的に塞ぐ。
- **(F1-c) fail-safe = SKIP（草案どおり）+ 残留リスクを既知課題化**:
  wiring は別 PBI のまま。stdin 供給に依存し、未供給時の plan.md 改変は
  検知できない残留リスクを handoff の既知課題に明記して受容。

**推奨**: F1-b（セキュリティ強制 Hook の改修でセキュリティ穴を残すのは
本末転倒。wiring 追加は数行で完結し、target_file 供給を保証できる）。
ただしスコープ拡大の可否は C-3 人間判断に委ねる。

### その他

- minor: E2（plan.md.bak）の扱いはテストで境界確認すれば足りる（指摘のみ）
