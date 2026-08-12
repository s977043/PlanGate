# C-1 セルフレビュー — TASK-1061（S-2 / S-3 スライス）

> 対象: `plan.md` / `todo.md` / `test-cases.md`（いずれも 2026-08-13 版）
> 実施: 2026-08-13 / 実施者: 実装担当（自己レビュー）
> 判定: **PASS**（FAIL 0 / WARN 3）

> 注: `working-context.md` は「17 項目」と記すが、同ファイルが列挙するのは
> Plan 7 + ToDo 5 + TestCases 3 = **15 項目**である。ここでは列挙された 15 項目を
> 判定し、加えて本 PBI 固有の観点（承認境界 / HO 判定）を §4 に置く。

## 1. Plan チェック（7 項目）

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| C1-PLAN-01 | 受入基準網羅性 | PASS | AC-1〜5 が plan の Work Breakdown S2〜S6 と 1:1 で対応。AC に対応しない Step は無い |
| C1-PLAN-02 | Unknowns 処理 | PASS | U-1〜U-3 を明示し、いずれも **本スライスの Non-goal** として処理先（後続スライス / V2）を記載 |
| C1-PLAN-03 | スコープ制御 | PASS | pbi-input の S-1 / S-5 / S-6 / S-7 を Non-goal として明示的に切り出し、触るファイルを列挙。列挙外は触らないと明記 |
| C1-PLAN-04 | テスト戦略 | PASS | Unit（正例 1 + 負例 9）/ Integration（harness・standalone）/ Verification Automation（diff 同一性・名前衝突・ドッグフーディング）を分けて記載 |
| C1-PLAN-05 | Work Breakdown の Output | PASS | S1〜S6 すべてに Output と 🚩 チェックポイントがある |
| C1-PLAN-06 | 依存関係 | PASS | todo.md の「依存関係」節で T-03→T-04（RED→GREEN）、T-05→T-06（正本→ミラー）を明示 |
| C1-PLAN-07 | 動作検証の自動化 | PASS | TC-01〜TC-17 を `tests/extras/ta-63-*.sh` で自動化。手動は実行経路そのものの TC-18 / TC-19 のみ |

## 2. ToDo チェック（5 項目）

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| C1-TODO-01 | タスク粒度 | PASS | T-01〜T-13。1 タスク = 1 ファイルまたは 1 検証コマンドで、途中中断しても状態が判別できる |
| C1-TODO-02 | depends_on 設定 | PASS | 依存関係節に記載。TDD 順序（RED→GREEN）と正本→ミラー順序が固定されている |
| C1-TODO-03 | チェックポイント設定 | PASS | 実装 4 タスクすべてに 🚩。準備 T-01 には停止条件（既存 FAIL > 0 で即停止）を付与 |
| C1-TODO-04 | Iron Law 遵守 | PASS | HO パス不可触・`approvals/*.json` 非作成・PR 非作成・merge しない、を Constraints に明記。todo に承認代行タスクは無い |
| C1-TODO-05 | 完了条件 | PASS | 各タスクが検証可能（ファイル存在 / diff exit 0 / rc=0 / FAIL 数不増）。`rollback:` を全タスクに記載 |

## 3. TestCases チェック（3 項目）

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| C1-TEST-01 | 受入基準との紐付き | PASS | 冒頭のマッピング表で AC-1〜5 → TC を全件対応付け。孤立 TC は無い |
| C1-TEST-02 | Edge case 網羅 | **WARN** | E-1〜E-6 を列挙したが、E-2（OUTCOME 後に空行のみ）と E-3〜E-5（空入力 / stdin / 不在ファイル）は **TC 化せず実装内対応**に留めた。理由: 負側 TC が 9 件あり、これ以上の増加は ta-61 の per-file standalone ループの実行時間を押し上げるため。**残存リスク: 空行のみ後続と使い方エラーの回帰は自動検知されない** |
| C1-TEST-03 | 自動化可否 | PASS | TC-01〜17 自動 / TC-18・19 は実行経路そのものの手動確認と明記 |

## 4. 本 PBI 固有の観点（承認境界・HO）

| # | 項目 | 判定 | 根拠 |
|---|---|---|---|
| X-01 | HO 9 カテゴリ非該当 | PASS | 触るのは `.agents/skills/` `.claude/skills/` `scripts/check-*.sh` `tests/extras/` `plugin/plangate/skills/`（生成物）`docs/working/`。`check-plan-hash.sh` の case 文（9 カテゴリ正本）に `skills` / `scripts/check-` の語は 0 件 |
| X-02 | 承認境界を変更しない | PASS | 成果物は skill（ソフト）と検証スクリプト（読取のみ）。C-3 / C-4 / merge の担い手を変える記述は無い |
| X-03 | 二重正本を作らない | PASS | skill は 8 要素・OUTCOME の**定義を持たず**リンクのみ。TC-06 で正本リンクの存在を機械検証 |
| X-04 | 二重配置の drift | **WARN** | `.agents` / `.claude` / `plugin` の 3 箇所に同一 SKILL.md が並ぶ。TC-03 が `.agents`↔`.claude` を、CI の drift-check が `.agents`↔`plugin` を守るが、**3 者が同時に崩れる経路は塞いでいない**（現実的には `.claude` 側の単独編集が最大のリスク） |
| X-05 | 機械判定の false positive | **WARN** | コードフェンス内の行頭 `OUTCOME:` を区別しない。報告に契約の実例を貼るとき行頭に置くと誤検出する。script のコメントと skill §5 に明記済みだが、**運用で踏む可能性は残る**（V2 候補） |

## 5. 指摘事項（WARN 3 件・いずれも exec 続行可）

| ID | Severity | 内容 | 対応 |
|---|---|---|---|
| W-1 | minor | Edge case E-2 / E-3〜E-5 が TC 化されていない | 実装内で対応済み。回帰検知は手動。handoff の既知課題へ |
| W-2 | minor | skill の 3 箇所配置の drift を完全には塞げない | 本 PBI は 2 箇所の同一性固定まで。片側欠落検出は pbi-input S-5（後続スライス） |
| W-3 | minor | コードフェンス内 `OUTCOME:` の誤検出 | 既知の限界として明記。フェンス解釈は V2 候補 |

**critical 0 / major 0 / minor 3。**

## 6. 判定

**PASS** — FAIL 0、WARN 3 はいずれも minor かつ回避策・後続処理が明記されている。exec 続行可。
