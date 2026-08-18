# C-1 セルフレビュー — TASK-1109 (#1109)

> mode=**high-risk** → 17 項目フル実施。
> **判定: PASS（WARN 2 件 / FAIL 0 件）**

## Plan チェック（7 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-PLAN-01 | 受入基準の網羅性 | PASS | AC-1〜8 が test-cases.md のマッピング表で TC に 1:1 以上で紐付く。網羅されない AC なし |
| C1-PLAN-02 | Unknowns の処理 | PASS | Q-1（配布物 openai.yaml の生成を sync に組み込むか）/ Q-2（`.codex` SKILL.md stale）/ Q-3（`brand_color` の doc-impl 乖離）を **Human 判断事項として明示**し、実装で先取りしていない |
| C1-PLAN-03 | スコープ制御 | PASS | Out of scope に #1086 / #1081 / `--warn-only` 実適用 / 生成の sync 組込を明記。`.codex/skills` 再生成で巻き込んだ SKILL.md 4 件は **revert してスコープ外に出した**（F-8） |
| C1-PLAN-04 | テスト戦略 | PASS | 12 TC + 3 変異 + 既存呼び出し元回帰。フルスイート非実行の理由も明記 |
| C1-PLAN-05 | Work Breakdown の Output | PASS | S-1〜S-9 すべてに Output 列あり |
| C1-PLAN-06 | 依存関係 | PASS | 「`--warn-only` 除去は既存 violation 解消の merge 後」という**順序制約**を plan §6 / todo ⚠️ / patch ヘッダの 3 箇所に明記 |
| C1-PLAN-07 | 動作検証の自動化 | PASS | 検証はすべて `ta-68` に自動化。patch も隔離コピーへの**実適用**で検証（`--check` 単独で終わらせない） |

## ToDo チェック（5 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TODO-01 | タスク粒度 | PASS | T-01〜T-18。1 タスク = 1 検証可能な成果物 |
| C1-TODO-02 | depends_on | PASS | 全タスクに記載。T-12〜T-14 が T-11 に依存する形が明示 |
| C1-TODO-03 | チェックポイント | PASS | 全タスクに 🚩。実測可能な述語で書いている（「rc=0」「集合差が空」等） |
| C1-TODO-04 | Iron Law 遵守 | PASS | HO 編集なし / merge なし / `c3.json` 発行なし / フルスイート非実行を明記 |
| C1-TODO-05 | 完了条件 | PASS | Human タスク H-1〜H-4 を分離。AI 側の終端は T-18（push）で閉じている |

## TestCases チェック（3 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-TC-01 | 受入基準との紐付き | PASS | AC → TC マッピング表。AC-1〜8 すべてに TC あり |
| C1-TC-02 | Edge case 網羅 | PASS | 非ディレクトリ / dotfile / 両方欠落 / 全 target 不在 / 片方不在 / 空白入りパス の 6 件 |
| C1-TC-03 | 自動化可否 | PASS | TC-01〜12 は `ta-68` で自動。TC-R1 は既存 `ta-30` |

## 追加チェック（本 PBI 固有 / 2 項目）

| ID | 項目 | 判定 | 根拠 |
|----|------|------|------|
| C1-X-01 | **絶対件数を契約値にしていない** | PASS | 判定はすべて集合演算（`skill_dirs - yaml_dirs` 等）。TC-12 も対称差。39/35/8 は plan の実測記録としてのみ登場 |
| C1-X-02 | **fail-closed 方向を緩めていない** | PASS | 追加したのは violation の増加（欠落 / orphan / 明示 target 不在 / 全 target 不在）のみ。緩和は「既定 target 不在を violation にしない」1 点で、これは #1086 との両立のため**理由付きで必ず出力**する形にした |

## WARN（2 件）

| # | 内容 | severity | 対応 |
|---|------|----------|------|
| **W-1** | **既定 target 不在を violation にしない**のは fail-open 方向の例外。`.codex/skills` が誤って削除されても既定実行は `plugin/plangate/skills` だけで rc=0 になりうる | minor | 「1 つも検査できなければ violation」で最悪ケースは塞いだ。SKIPPED 行は必ず出力される。#1086 の決着時に再評価すべき点として handoff/plan に残した |
| **W-2** | 配布物 `openai.yaml` は**どの script でも生成されない手書き資産**であり、本 PBI は「欠けたら落ちる」検出は入れたが**生成側の再発防止は入れていない**。新 skill 追加時に CI が赤で気付く運用になる | minor | 意図的（Non-goal）。Q-1 として Human 判断へ回した。follow-up issue 候補 |

## C-2（外部 AI レビュー）

**未実施**。本作業は委譲スコープが「Plan Package → C-1 → 実装」であり C-2 は含まれない。
mode=high-risk のフェーズ適用マトリクスでは C-2 が ○ のため、
**C-3 の前に C-2 を実施するかは Human の判断事項**（`review-external.md` は未作成）。
review-principles §7-ter に従い、これは「指摘なし」ではなく **未実行** として記録する。

## 判定

**PASS**（critical 0 / major 0 / minor(WARN) 2）
→ C-3（人間・同期）へ。**autonomous APPROVE 不可**（HO 隣接 + high-risk）。
