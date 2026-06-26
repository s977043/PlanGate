# TASK-0146 セルフレビュー（C-1）— EHS-2/3 配線

## Planチェック（7項目）

### C1-PLAN-01: 受入基準網羅性
- 受入基準 6 件（EHS-2/3 各配線 + strict/non-strict + 構文健全）が test-cases.md TC-01〜06 にすべてマップされている。
- **判定**: PASS

### C1-PLAN-02: Unknowns 処理
- `.fix-loop-count` ファイルの sandbox 隔離を Risks に明記済み。
- `PLANGATE_VALIDATION_BIAS` の conductor 自動注入は Non-goals に記載。
- **判定**: PASS

### C1-PLAN-03: スコープ制御
- 変更対象は `bin/plangate`（HO・Human適用）+ 補助スクリプト 3 本のみ。
- `check-fix-loop.sh` / `check-handoff-elements.sh` 自体は変更しない（Constraints に明記）。
- **判定**: PASS

### C1-PLAN-04: テスト戦略
- 静的検査（grep/awk）+ 構文検査（sh -n）で網羅。
- 未適用 SKIP で CI を割らない設計（ta-46 踏襲）。
- **判定**: PASS

### C1-PLAN-05: Work Breakdown Output
- Step 1〜4 の各 Output が明示されており、チェックポイントも設定済み。
- **判定**: PASS

### C1-PLAN-06: 依存関係
- `bin/plangate` の apply-script は T-01〜T-03 完了後に dry-run（T-04）→ H-01 C-3 承認後に Human が apply（H-02）。
- 依存関係の順序が todo.md に明示されている。
- **判定**: PASS

### C1-PLAN-07: 動作検証自動化
- `sh tests/run-tests.sh` で ta-47 SKIP（未適用）→ PASS（適用後）を機械確認。
- **判定**: PASS

## ToDoチェック（5項目）

### C1-TODO-01: タスク粒度
- T-01〜06 は各 1 アクション相当。Human H-01〜03 も明確。
- **判定**: PASS

### C1-TODO-02: depends_on 設定
- 各タスクに依存関係が明記されている。
- **判定**: PASS

### C1-TODO-03: チェックポイント設定
- T-04（dry-run 確認）、T-05（全体テスト）に 🚩 チェックポイントが設定されている。
- **判定**: PASS

### C1-TODO-04: Iron Law 遵守
- `bin/plangate` は AI 直接編集不可 → Human apply（H-02）に委譲。Iron Law 第1原則に準拠。
- **判定**: PASS

### C1-TODO-05: 完了条件
- H-03（`sh tests/run-tests.sh` ta-47 全 TC PASS）が最終完了条件として明示されている。
- **判定**: PASS

## TestCasesチェック（3項目）

### C1-TC-01: 受入基準との紐付き
- 6 受入基準 → TC-01〜06 が 1:1 対応。
- **判定**: PASS

### C1-TC-02: Edge case 網羅
- EHS-1 未適用での独立動作、BYPASS フラグのエッジケースを記載。
- **判定**: PASS

### C1-TC-03: 自動化可否
- 全 TC が sh スクリプト内で自動実行可能（grep/awk/sh -n）。
- **判定**: PASS

## 総合判定

**PASS** — 全 15 項目 PASS。指摘事項なし。

C-3 ゲート提出可能。
