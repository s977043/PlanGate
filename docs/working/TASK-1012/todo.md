# EXECUTION TODO — TASK-1012

> plan: `docs/working/TASK-1012/plan.md`（**改訂 1** = C-1 FAIL 反映済み）/ Mode: **standard**（`lite_eligible=true`）
> ゲート: Human C-3 の代わりに **ai-loop C-3' 裁定**（`/ai-loop-cycle`）

## 👤 Human タスク

| ID | 内容 | 依存 |
|----|------|------|
| **H-1** | **C-4: PR レビュー**（GitHub 上・三値）。merge は Human-owned 固定 | A-10 完了後 |

> **C-3 は ai-loop の C-3' 裁定に置換**（`lite_eligible=true`）。`arbiter.py` が `HUMAN_ESCALATED`（exit 2）を返した場合のみ Human 判断を仰ぐ。

## 🤖 Agent タスク

### 準備

| ID | 内容 | depends_on | 🚩 | rollback |
|----|------|-----------|----|----------|
| **A-1**（T-01） | baseline 実測: 現行 tree で `ta-26` standalone の TC 総数 / PASS 数 / rc + 実行時間 2 回 | — | 🚩 総数・PASS 数・rc を記録 | 不要（読取のみ） |
| **A-2**（T-02） | ゲート A / B の範囲確定 + **シンボル越境検査**（ゲート内で定義しゲート外で参照される関数・変数が 0 件） | A-1 | 🚩 **越境 0 件を機械確認**（行境界の一致だけでは不十分） | 不要（読取のみ） |

### 実装

| ID | 内容 | depends_on | 🚩 | rollback |
|----|------|-----------|----|----------|
| **A-3**（T-03） | ゲート A / B を適用（L62-68 と同型）。**ヘルパー定義は移動しない**。インデント調整のみ | A-2 | 🚩 `sh -n` rc=0 + **`git diff -w` の変化がゲート追加分のみ** | `git checkout -- tests/extras/ta-26-plugin-sync.sh` |

### 検証

| ID | 内容 | depends_on | 🚩 | rollback |
|----|------|-----------|----|----------|
| **A-4**（T-04） | **AC-1**: `PG_T26_NO_RECURSE=1` で `[SKIP]` 2 本が出て、ゲート対象 TC が 1 件も実行されない | A-3 | 🚩 SKIP 2 本 + 非実行の両方 | 不要（読取のみ） |
| **A-5**（T-05） | **AC-2**: 親の TC 総数・PASS 数が A-1 baseline と**完全一致** | A-3 | 🚩 baseline と数値一致 | 不要（読取のみ） |
| **A-6**（T-06） | **AC-3 / AC-4**: `ta-26` standalone 0 failed・フルスイート 0 failed | A-3 | 🚩 両方 rc=0 | 不要（読取のみ） |
| **A-7**（T-07） | **AC-5**: 交互 A/B で実行時間を実測（BASE / OPT を交互に各 2 回以上） | A-6 | 🚩 交互測定であること | 不要（読取のみ） |
| **A-8**（T-08a） | 変異①: ゲート条件を反転（`!= "1"`）→ **A-5 が FAIL** → 復元 | A-5 | 🚩 期待 FAIL 実測 + 復元後 A-5 再 PASS | `git checkout -- tests/extras/ta-26-plugin-sync.sh` **必須** |
| **A-9**（T-08b） | 変異②: ゲート B の終端を TC-36 の手前へ縮める → 子で **TC-36** が走り **A-4 が FAIL** → 復元 | A-4 | 🚩 期待 FAIL 実測 + 復元後 A-4 再 PASS | `git checkout -- tests/extras/ta-26-plugin-sync.sh` **必須** |
| **A-9b**（T-08c） | 変異③: `_t26_mk_refs_guard_sandbox` の定義をゲート B の内側へ移す → **A-2 の越境検査が ≥1 件**を報告し、子は `command not found` で A-6 も FAIL → 復元 | A-2, A-6 | 🚩 越境 ≥1 の検出 + 復元後 A-2 再 PASS | `git checkout -- tests/extras/ta-26-plugin-sync.sh` **必須** |

### 完了

| ID | 内容 | depends_on | 🚩 | rollback |
|----|------|-----------|----|----------|
| **A-10**（T-09） | handoff / status / current-state / INDEX を整備。handoff に「**ゲート境界の直後に TC を足すときはシンボル越境検査を再実行する**」旨を明記 | A-4〜A-9 | 🚩 handoff 6 要素 + 再発防止の申し送り | 不要 |

## ⚠️ 依存関係

```text
A-1 → A-2 → A-3 → ┬→ A-4 (AC-1)    → A-9  (変異②) → A-4 再実行
                  ├→ A-5 (AC-2)    → A-8  (変異①) → A-5 再実行
                  └→ A-6 (AC-3/4)  → A-9b (変異③) → A-2 再実行
                          ↓
                        A-7 (AC-5)  →  A-10 → 【PR 作成】 → H-1 (C-4)
```

- **A-2 は最重要**。ここを行境界だけで済ませると、初版 plan が踏んだ「ゲート内定義をゲート外が参照して子が壊れる」欠陥を再現する
- **A-8 / A-9 の復元漏れは致命的**。復元後に対応する検証（A-5 / A-4）を再実行して PASS を確認するまでが各タスク
- A-8 / A-9 / A-9b は**別々の変異**なので、1 つずつ入れて戻す（同時に入れない）
- **A-9b は A-2 の検出力を実証する**（初版 plan が実際に踏んだ構造の再現）。A-2 が静的検査のみで空振りしていないことの証明

## 完了条件

- AC-1〜AC-5 がすべて PASS（AC-1 は静的前提＝シンボル越境 0 件を含む）
- A-8 / A-9 / A-9b の変異でそれぞれ A-5 / A-4 / A-2 が期待どおり FAIL し、復元後に再 PASS
- `git diff -w` が `tests/extras/ta-26-plugin-sync.sh` の**ゲート追加分のみ**（+ working context）

> L-0（リンター）/ V-1（受け入れ検査）/ V-3（外部レビュー）/ PR 作成は workflow-conductor が制御するため本 ToDo には含めない。
> Mode=standard のため **V-2 / V-4 は適用外**（`.claude/rules/mode-classification.md` フェーズ適用マトリクス）。
