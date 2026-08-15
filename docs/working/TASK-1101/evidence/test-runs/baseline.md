# T-01 baseline — TASK-1101（Step 0）

> 実施: 2026-08-15T10:31〜10:40Z / **絶対件数を契約値にしない**（T-01 🚩）

## 測定環境

| 項目 | 値 |
|---|---|
| `origin/main` | `dfaeebb` |
| OS | Darwin 25.6.0 |
| `/bin/sh` | bash 3.2 系（`/bin/sh` 実体） |
| 作業ツリー | **dirty**（`docs/working/TASK-1101/` 新規 + `ai-loop-runs/*.json` 3 件 untracked + `skip-decision-log.jsonl` 変更） |

## `sh tests/run-tests.sh`

```
Results: 738 passed, 2 failed
TA-01 〜 TA-66 まで完走
```

| 指標 | 値 |
|---|---|
| passed | 738 |
| **failed** | **2** |
| skipped | 3 |

## ⚠️ baseline に既に 2 件の失敗がある

**AC-6「`sh tests/run-tests.sh` が rc=0」は、着手前の時点で既に満たされていない。** 両方とも**本 PBI とは無関係**であることを切り分け済み。

### 失敗 1: `TA-60 / unit: test_run_evidence.py が FAIL（exit 1）`

**原因: 作業ツリーが dirty であることによる誤 FAIL = 既知 issue [#997](https://github.com/s977043/PlanGate/issues/997)。**

> #997: 「TC-45 が作業ツリーの dirty 状態で誤 FAIL（`ai-loop-runs/` は運用出力先・前後差分で判定すべき）」

`git status --short` に `?? docs/working/ai-loop-runs/*.json` が 3 件あり、**#997 の再現条件そのもの**。本 PBI の変更（HO 正規化）とは無関係。

### 失敗 2: `TA-42 / TC-04 AC-02: status rc=? expected non-zero+error for missing task`

**原因: テスト側のバイナリ解決の問題。本 PBI の対象（HO 判定）とは無関係。**

実測:

| 実行方法 | rc |
|---|---|
| `bin/plangate status TASK-T999`（直接） | **1**（期待どおり非ゼロ） |
| harness 経由（`run-tests.sh`） | 0 と報告 |
| standalone（`sh tests/extras/ta-42-*.sh`） | **127**（command not found） |

`TASK-T999` のディレクトリは**存在しない**ため前提は満たされている。**`$_t42_bin` の解決が実行経路で割れている**のが原因で、[#1044](https://github.com/s977043/PlanGate/issues/1044)（extras bootstrap の helper 欠落経路が実行方法で rc が変わる）と同じクラスの可能性が高い。

## AC-6 の扱い（**この baseline に基づく判定基準**）

AC-6 の文言は「`sh tests/run-tests.sh` が rc=0」だが、**着手前から 2 件失敗している**ため、そのままでは達成不能。**judged as follows**:

> **AC-6 の実質判定 = 「本 PBI の変更によって新たな失敗が増えないこと」**
> baseline: **738 passed / 2 failed**（上記 2 件）
> 完了時: **失敗が上記 2 件と同一であること**（新規 FAIL ゼロ）。**件数の増減ではなく、失敗している TC の同一性で照合する**

※ **絶対件数を契約値にしない**（無関係な PR で総数が動くため）。`738` という数値は**この測定時点のもの**であり、着手中に main が進めば変わる。

## AC-6 の主対象 4 本（S-4）

**いずれも FAIL なし**（`awk` で TA 見出しごとに FAIL を突合して確認）:

| テスト | baseline |
|---|---|
| `ta-65-eh3-ho-task-context` | **PASS**（standalone clean run も PASS） |
| `ta-12-maintenance` | **PASS** |
| `ta-39-eh3-doc-light` | **PASS**（standalone clean run も PASS） |
| `ta-45-c3-mode-config` | **PASS**（standalone clean run も PASS） |

## 測定上の注意（本セッションで踏んだ失敗）

1 回目の baseline は **`rc=` を書かずに 372 行で停止**した。`run_in_background` の内側でさらに `&` を使い、**二重背景化でプロセスが孤児化**したため。取得できたのは TA-01〜TA-26 のみで、**AC-6 の対象 4 本に到達していなかった**。

→ **背景実行は harness 側の機構のみを使う**こと。ログの末尾に完了マーカー（`Results:` 行）があることを確認してから baseline として採用する。
