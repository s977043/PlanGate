# 既存 PlanGate ドキュメント整合性チェック

> 実施日: 2026-04-20
> 対象: `docs/plangate.md` / `docs/plangate-v6-roadmap.md`
> 新規追加: `docs/workflows/` 配下 6 ファイル

## 整合確認観点

本 TASK は新規追加（`docs/workflows/` 新設）であり、既存ドキュメントの書き換えは行わない（plan.md の Non-goals に明記）。したがって整合確認の焦点は「新規追加が既存の記述と矛盾していないか」に限定する。

---

## 1. `docs/plangate.md` との整合

### 確認項目

| 項目 | 既存記述 | 新規追加 | 整合 |
|---|---|---|---|
| PlanGate フェーズ（A/B/C-1〜C-4/D/L-0/V-1〜V-4） | 本体で定義 | README の対応表で全フェーズを引用・マッピング | ✅ 矛盾なし |
| PlanGate の責務（止める / 承認する / 状態を保存する） | 本体で定義 | README で「統制層」と位置付け、新規 Workflow を「実行層」として補完関係に配置 | ✅ 矛盾なし |
| C-3 ゲート（三値判断） | 本体で定義 | Workflow 内には触れず、対応表で「計画承認ゲート（WF 外）」と明示 | ✅ 矛盾なし |
| TDD / Agent 実行 | D フェーズで定義 | WF-04 Build & Refine に対応（implementation-agent が主担当） | ✅ 補強関係 |
| 受け入れ検査 / V-1 | V-1 で定義 | WF-05 Verify に対応（qa-reviewer / acceptance-tester） | ✅ 補強関係 |

### 結論

`docs/plangate.md` の既存フェーズ定義と矛盾する記述はない。本 TASK の追加は PlanGate の実行層内部を構造化する補強であり、統制層の責務・ゲート境界には一切手を加えていない。

---

## 2. `docs/plangate-v6-roadmap.md` との整合

### 確認項目

| 項目 | 既存記述 | 新規追加 | 整合 |
|---|---|---|---|
| スクラム側責務（PBI管理 / Done判定 / ベロシティ） | PlanGate スコープ外と明記 | 本 TASK の Workflow 定義もスクラム責務には踏み込まない | ✅ 矛盾なし |
| P1 決定論的フック（A3） | v6 候補 | 本 TASK は Hook には触れない（Rule 4 準拠で CLAUDE.md / Skill / Hook の境界は #28 で統合） | ✅ 矛盾なし |
| P5 ファセットプロンプティング（C7） | v6 候補 | 本 TASK で workflow-conductor のプロンプト分離は行わない | ✅ 矛盾なし |
| サブエージェント（A6） | 境界曖昧 | 本 TASK は Agent 名の列挙のみ（実装は #25） | ✅ 矛盾なし |
| TAKT YAML（A4） | 境界曖昧、チーム合意が必要 | 本 TASK は YAML 化せず markdown で定義 | ✅ 矛盾なし |

### 結論

`docs/plangate-v6-roadmap.md` のスコープ境界（スクラム側に踏み込まない）を本 TASK でも踏襲している。v6 候補項目（P1〜P5）とは独立した領域を扱っており、矛盾なし。

---

## 3. 親 PBI（`docs/working/TASK-0021/pbi-input.md`）との整合

### 確認項目

| 項目 | 親 PBI 記述 | 新規追加 | 整合 |
|---|---|---|---|
| Rule 1〜5 | 親 PBI で定義 | Workflow は Rule 1 に準拠、README で明示 | ✅ |
| 実行シーケンス（7ステップ） | 親 PBI Notes で定義 | README の「実行シーケンス」セクションで引用 | ✅ |
| Skill 10 個の名前 | 親 PBI で定義 | 5 phase ファイルで名前のみ引用（定義は #24） | ✅ |
| Agent 5 体の名前 | 親 PBI で定義 | 5 phase ファイル + README で名前のみ引用（定義は #25） | ✅ |
| artifact 種別（クラス名） | 親 PBI では未確定（Q3） | 本 TASK で `context / requirements / design / known-issues / handoff` に確定（Codex Q3 見解採用） | ✅ 親 PBI を前進させる補強 |

### 結論

親 PBI と矛盾なし。Q3（artifact 種別）は親 PBI で未確定だった事項を本 TASK で確定する位置付け（Codex C-2 の第三者見解採用）。

---

## 総合判定

| 対象 | 矛盾 |
|---|---|
| `docs/plangate.md` | ✅ なし |
| `docs/plangate-v6-roadmap.md` | ✅ なし |
| `docs/working/TASK-0021/pbi-input.md`（親 PBI） | ✅ なし（Q3 を前進させる補強） |

**既存ドキュメント整合性チェック**: ✅ **PASS**（矛盾なし、既存記述の書き換えなし）
