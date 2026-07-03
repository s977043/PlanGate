---
name: hypothesis-logger
description: "WF-07 探索的デバッグの仮説を記録・追跡する。Use when: 探索的デバッグ（WF-07）の Phase E-1 で仮説を定義・結果記録・AC 更新するとき。「仮説を記録して」「次の仮説に進む」「検証結果を記録して」。"
---

# Hypothesis Logger

> 正本: `.claude/skills/hypothesis-logger/SKILL.md`
> 関連: [`docs/workflows/07_exploratory_debug.md`](../../../docs/workflows/07_exploratory_debug.md) Phase E-1

WF-07 探索的デバッグの仮説→検証→学習→AC 更新サイクルを構造化して記録する。

## 手順

### Step 1: 仮説番号の採番

`docs/working/<TASK-XXXX>/status.md` のすべての「仮説-N:」プレフィックスのエントリ（完了済み `- [x]`・未完了 `- [ ]` 問わず）を走査し、最大の N を特定して N+1 を採番する（存在しない場合は `仮説-1` から始める）。完了済み仮説をカウントから除外すると番号が重複するため、完了状態に関わらず全件を対象にする。

### Step 2: status.md への仮説記録

`docs/working/<TASK-XXXX>/status.md` の残タスクに以下の形式で追記する:

```markdown
- [ ] 仮説-N: <仮説の説明（1 行）>
    prediction: <検証すれば何が分かるか>
    verification: <どうやって検証するか（コマンド / ビルド / 手順）>
    waiting_external_verification: <true|false>
```

`waiting_external_verification: true` の場合は BLOCKED 状態として扱う（`working-context.md §BLOCKED 状態` 準拠）。

### Step 3: evidence ディレクトリへの詳細記録

`docs/working/<TASK-XXXX>/evidence/exploratory/hypothesis-N.md` を作成する:

```markdown
# 仮説-N: <タイトル>

## 仮説
<詳細な仮説の説明>

## 検証手順
<再現性のある手順>

## 予測結果
<成功 / 失敗の判断基準>

## 検証結果
<!-- 検証完了後に記入 -->
- 結果: <RESOLVED|REJECTED|DEFERRED>
- 判明した事実: <text>
- 次の仮説: <text or なし>

## AC への影響
<!-- 前提変更があれば記入 -->
- 影響 AC: <ID or なし>
- 変更内容: <text>
```

### Step 4: 検証結果の記録（検証完了後）

検証が完了したら以下を実施する:

1. `evidence/exploratory/hypothesis-N.md` の「検証結果」セクションを記入
2. `status.md` の `- [ ] 仮説-N:` を `- [x]` に更新し、結果を 1 行追記
3. AC への影響がある場合（Phase E-3 発動条件）:
   - `pbi-input.md` の Notes に「前提変更 (仮説-N 由来)」として追記
   - `test-cases.md` の該当 AC を更新
   - 影響が Out of scope を超える場合は人間に C-3 再承認を求める

## 完了状態

| 状態 | 意味 |
|------|------|
| `RESOLVED` | 仮説が正しく、問題が解消された |
| `REJECTED` | 仮説が外れた（問題は別の原因）→ 次の仮説へ |
| `DEFERRED` | 外部依存で検証待ち（BLOCKED 状態に移行） |

## 使用例

**入力**: 「EAS ビルドが失敗する原因として `.gitignore` の glob 誤マッチが怪しい。仮説を記録して」

**出力イメージ** (status.md への追記):

```markdown
- [ ] 仮説-3: .gitignore の `pr*.json` glob が `primitive.json` を誤マッチしている
    prediction: glob を修正すれば EAS が primitive.json を含める
    verification: .gitignore を修正して EAS production build を再実行
    waiting_external_verification: true
```

## 関連

- WF-07: [`docs/workflows/07_exploratory_debug.md`](../../../docs/workflows/07_exploratory_debug.md)
- BLOCKED 状態: [`.claude/rules/working-context.md`](../../rules/working-context.md) §BLOCKED 状態
