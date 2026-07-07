# ai-loop Run-008 — LoopSpec + 計画（#749: allowed_paths / cost cap フィールドの設計判断）

> **escalate 第 2 型**（Run-006 先例）: スキーマ設計の選択肢があるため lite を誠実に
> no_new_design=false と申告し、W チェック前に human へ設計選択を昇格する。

## LoopSpec（骨子）

```yaml
loop:
  name: run-008-loopspec-scope-fields
  trigger: {type: manual, detail: "#749（#746 intake の genuine gap）の schema draft"}
  goal:
    description: "LoopSpec に変更可能範囲（allowed_paths）と cost cap の扱いを定義する"
  actors: {maker: implementation_agent(sonnet), checker: w-check(A/B)}
  escalation: {touches_ho: unconditional, budget_ref: "arbiter-policy.md §7"}
```

- **boundary**: clean（docs/workflows/ai-loop/loopspec.md）
- **lite**: size_ok=true / **no_new_design=false（スキーマ設計の選択肢 — 下記）** /
  follows_pattern=true / reversible=true
- **class**: no-merge

## Human への設計選択肢（escalate 事項）

| 案 | 内容 | 利点 | 欠点 |
|---|---|---|---|
| A | `scope.allowed_paths`（glob 列挙・必須）+ `budget.cost_note`（宣言のみ・任意） | #749 の 2 gap を一度に閉じる | **cost は enforcement 不在のまま宣言だけ = 「上限がある」という偽の安心**を生むリスク（F-18 と同族の宣言/実態乖離） |
| **B（推奨）** | `scope.allowed_paths`（glob 列挙・**必須**・exec の宣言↔実差分検証 = I-9 と接続）のみ追加。**cost cap は追加しない**（#749 に enforcement 設計と同時導入すべき旨を明記） | 実効性のあるものだけを入れる honest 設計。allowed_paths は既に運用実態（Expected Diff・宣言外変更の差し戻し）があり enforcement が存在する | cost cap の解決が #749 に残る（ただし透明） |
| C | 両方見送り（orchestrator-mode の allowed_files 参照で代替） | 変更ゼロ | ai-loop 実行単位での宣言が引き続き不可能（#746 検証 finding 2 の gap が残置） |

推奨 **B**: 「enforcement のない宣言フィールドを作らない」— Run-004〜007 で確立した
宣言↔実態一致の規律（I-9・F-12・F-14）と一貫。allowed_paths は maker への指示・
統合検証（git diff --name-only との突合）という**既存の enforcement に直結**する。

---

## Human 判断の記録（escalate 解消）

**2026-07-07 ユーザー回答: 「B」** — `scope.allowed_paths`（必須・glob）のみ追加。
cost cap は enforcement 設計と同時導入とし本 run では追加しない（#749 に残置を明記）。
以降 **no_new_design=true**（human 承認済み設計の実装・Run-002/006 先例）。

## 確定計画（W チェック対象）

- **対象**: `docs/workflows/ai-loop/loopspec.md` 1 ファイルのみ
  1. §2 YAML — `context` の後に新キー `scope` を追加:
     `allowed_paths:`（必須・最低1件・glob 文字列列挙）。コメントで
     「このループ実行が**変更してよい**パス。宣言外への変更は exec 差し戻し（I-9）」
  2. §3 表 — `loop.scope.allowed_paths` 行を追加（必須 / なし=欠落は受理拒否（I-4）/
     enforcement: maker への Expected Diff 指示 + 統合検証の `git diff --name-only` 突合。
     **boundary（touches-HO 判定）は allowed_paths と独立に全変更へ適用** — allowed_paths に
     HO パスを書いても escalate は免れない（I-1））
  3. §4 記入例 — scope.allowed_paths を追加
  4. cost cap についての 1 文注記（§3 表の直後）: 「cost cap フィールドは設けない —
     enforcement 不在の宣言フィールドを作らない（#749 で enforcement 設計と同時に検討）」
- **AC（実機事前検証済み・証跡は本ファイル直上の実行ログ）**:
  1. `test "$(grep -cF 'allowed_paths' docs/workflows/ai-loop/loopspec.md)" -ge 3`
     → exit 0（スキーマ+表+記入例。現状 count=0/exit1 実測・サンプル3件で exit 0 実測）
  2. `grep -cF 'cost cap' docs/workflows/ai-loop/loopspec.md` → 1 以上（注記。現状 0 実測）
  3. markdownlint → 0 error
  4. `git diff --name-only origin/main` が loopspec.md + run 記録に収まる
- **lite（更新）**: size_ok=true / **no_new_design=true** / follows_pattern=true / reversible=true
