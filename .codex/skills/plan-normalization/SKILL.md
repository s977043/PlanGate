---
name: plan-normalization
description: "C-2 の確定反映後・C-3 承認前に plan.md を最終合意状態へ正規化し、履歴依存を除去した Canonical Plan にする。Use when: review 修正が積み上がった時、C-3 前に plan を自己完結させたい時、実装 Agent へ clean handoff したい時。"
---

# Plan Normalization

レビュー履歴を追記した Plan を、**現在の最終合意状態だけで自己完結する Canonical Plan** に再構成する。

重要: PlanGate は C-3 で `plan_hash` を固定し、exec 時に EH-3 が照合する。したがって正規化は **C-3 承認前**に行う。C-3 後の `plan.md` 書き換えは禁止。

## 適用位置

```text
C-2 external review
  ↓
R-NNN 確定反映
  ↓
Plan Normalization  ← 本 skill
  ↓
簡易 C-1 再実行
  ↓
C-3 human approval / plan_hash 固定
  ↓
exec
```

## Read First

1. `docs/working/TASK-XXXX/plan.md`
2. `docs/working/TASK-XXXX/pbi-input.md`
3. `docs/working/TASK-XXXX/test-cases.md`
4. `docs/working/TASK-XXXX/todo.md`
5. `docs/working/TASK-XXXX/review-external.md`（存在すれば）
6. `docs/working/TASK-XXXX/review-self.md`
7. `docs/working/TASK-XXXX/decision-log.jsonl`
8. `docs/ai/plan-normalization-gate.md`（上流リポジトリで参照可能な場合）

## 出力契約

正規化後も成果物の正本は **`plan.md` のまま**とする。`canonical-plan.md` を別に増やさない。

理由:

- exec の Progressive Disclosure が `plan.md` を読む既存契約を維持できる
- `c3.json.plan_hash` の対象を増やさない
- 「draft plan と canonical plan のどちらが正か」という二重正本を作らない

履歴や却下理由は `decision-log.jsonl` に分離する。

## 手順

### 1. Before snapshot を保存

正規化前に次を保存する。

```text
docs/working/TASK-XXXX/evidence/plan-normalization/plan.before.md
```

既に存在する場合は上書きせず、timestamp 付き別名にする。

### 2. 不変条件を抽出

正規化前の Plan と関連 artifact から、削除してはいけない契約を列挙する。

- Goal
- In Scope / Out of Scope
- Global Constraints
- AC / REQ / FR / NFR の識別子と内容
- Files / Interfaces
- Work Breakdown の実装責務
- Verification Plan / test-cases 対応
- Replan Triggers / Stop Condition
- Human Approval Boundary

識別子がある契約は ID を維持する。言い換えのために ID を削除・再採番しない。

### 3. Decision Log に履歴を退避

Plan 本文から削除するが将来の再提案防止に必要な判断理由は、`decision-log.jsonl` に追記する。

対象例:

- 採用しなかったアーキテクチャ案
- C-2 で却下した代替案
- 重要な trade-off
- 「なぜ戻さないか」を将来の Agent が知るべき判断

`decision-log.jsonl` は append-only。既存行を書き換えない。

### 4. plan.md を全面再構成

**patch を追記するのではなく、最終合意状態を基準に Plan 全体を書き直す。**

以下を削除する。

- 当初案 / 旧案 / 一時案
- superseded / rejected な設計そのもの
- 「前述」「先ほどのレビュー」「レビューで変更した」など会話履歴依存表現
- 同じ決定の重複説明
- 途中経過としてのみ意味を持つ比較表

以下は残す。

- 現在採用している設計
- 実装 Agent が判断に必要な現在の rationale
- 最終要件 / AC / Constraints
- 実装順序 / Interfaces / 検証方法
- rollback / stop / approval boundary

`Approach Comparison` に却下案が残っている場合、現在案の理解に不要なら比較表を縮退し、却下理由を Decision Log へ移す。Plan には `Recommended Approach` の現在状態を中心に残す。

### 5. 自己完結性を確認

新規参加 Agent が過去会話を読まず、`plan.md` + 通常の L1 artifact だけで次を答えられること。

- 何を達成するか
- 何を変更するか / 変更しないか
- どの設計を採用するか
- どの順序で実装するか
- 何をもって完了とするか
- どう検証するか
- どこで停止し Human に戻すか

1つでも過去会話が必要なら normalization FAIL。

### 6. 機械チェック

上流リポジトリでスクリプトが利用可能なら実行する。

```bash
python3 scripts/check-plan-normalization.py \
  --before docs/working/TASK-XXXX/evidence/plan-normalization/plan.before.md \
  --after docs/working/TASK-XXXX/plan.md
```

この checker は少なくとも次を fail-closed で確認する。

- core heading 欠落
- before に存在した `AC-*` / `REQ-*` / `FR-*` / `NFR-*` の消失
- canonical Plan に残った代表的な履歴依存表現

ID が無い要件の意味保存は機械判定できないため、本 skill の手動チェックを省略しない。

### 7. 簡易 C-1 を再実行

正規化は `plan.md` の内容を変更するため、C-3 前に必ず簡易 C-1 を再実行する。

最低限確認する項目:

- AC と Work Breakdown の対応
- Files / Interfaces の具体性
- Verification Plan の欠落なし
- placeholder / unknown の混入なし
- scope / risk / security / backward compatibility の整合
- `test-cases.md` / `todo.md` と矛盾しない

PASS 後にのみ C-3 へ進む。

## 禁止事項

- C-3 APPROVED 後に normalization して `plan_hash` を変える
- `canonical-plan.md` を新たな正本として併存させる
- Decision Log を削除・圧縮して過去判断を失う
- 「読みやすくする」目的で AC / Requirement の意味を変える
- unresolved な論点を勝手に決定して canonical state に混ぜる
- `review-external.md` を消して監査履歴を失う

## PASS 条件

- `plan.md` 単体が現在状態として読める
- superseded な案が Plan の実行指示に残っていない
- 重要な rejected rationale は Decision Log に保持されている
- stable contract IDs が欠落していない
- test / acceptance / constraint が正規化前後で意味的に保存されている
- 簡易 C-1 が PASS
- まだ C-3 が発行されていない

1つでも満たさない場合は C-3 に進まない。
