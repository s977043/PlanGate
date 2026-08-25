# Plan Normalization Gate

> Issue #1220 — レビュー済み Plan を Current Canonical State へ正規化する。

## 1. 目的

C-1 / C-2 のレビューと修正を繰り返した `plan.md` から、途中案・破棄済み判断・会話履歴への依存を除去し、後続の実装 Agent が現在の合意状態だけを読んで実行できる **Canonical Plan** を作る。

PlanGate では新しい `canonical-plan.md` を作らない。**正規化後の `plan.md` 自体を Canonical Plan の正本**とする。

履歴と現在状態は次のように分離する。

| Artifact | 責務 |
|---|---|
| `plan.md` | 今、何をどう実装するかという Current Canonical State |
| `decision-log.jsonl` | なぜその判断をしたか、何を却下したかという append-only の意思決定履歴 |
| `review-external.md` | C-2 のレビュー指摘と R-NNN の監査履歴 |
| `evidence/plan-normalization/plan.before.md` | 正規化前後の契約保存を検証するための snapshot |

## 2. Gate の位置

Normalization は **C-3 承認前**に行う。

```text
C-2 external review
  ↓
R-NNN 確定反映
  ↓
Plan Normalization
  ↓
Normalization invariant check
  ↓
簡易 C-1 再実行
  ↓
C-3 human approval / plan_hash 固定
  ↓
exec
```

### C-3 後に置かない理由

C-3 は承認対象 `plan.md` の SHA-256 を `c3.json.plan_hash` に固定する。exec 時は EH-3 がこの hash と現在の `plan.md` を突合する。

したがって C-3 後に正規化すると、正しい意図の編集でも `plan_hash mismatch` となる。Normalization は必ず hash 固定前に完了させる。

## 3. 適用条件

次のいずれかに該当する場合は Plan Normalization を実施する。

- C-2 の指摘を `plan.md` に確定反映した
- 複数回のレビュー修正で途中案・変更履歴が Plan に蓄積した
- Plan 内に過去会話を知らないと意味が通じない記述がある
- superseded / rejected な選択肢が後続 Agent の実行判断を曖昧にする

C-2 を実施せず Plan に修正履歴もない light / ultra-light task では N/A としてよい。ただし N/A を理由に既存の C-1 / C-3 条件を緩和しない。

## 4. Canonical Plan の契約

正規化後の `plan.md` は最低限、次を現在形で自己完結して記述する。

1. Goal
2. Scope（In Scope / Out of Scope）
3. Global Constraints
4. 採用している Approach / Architecture
5. Files / Interfaces
6. Work Breakdown
7. Acceptance Criteria と実装 Task の対応
8. Verification Plan
9. Replan Triggers / Stop Condition
10. Human Approval Boundary

新規参加 Agent が通常の L1 artifact と `plan.md` だけを読み、次を判断できること。

- 何を達成するか
- 何を変更するか / 変更しないか
- どの設計が採用済みか
- どの順序で実装するか
- 何をもって完了とするか
- どう検証するか
- どこで停止し Human に戻すか

## 5. Normalization Rules

### Plan から除去するもの

- 当初案・旧案・一時案など、現在は採用していない実行方針
- superseded / rejected な設計を現在案と並列に見せる記述
- 「前述の指摘」「先ほどのレビュー」「レビューで変更した」など、会話履歴への参照
- 同じ決定を修正履歴として重複説明する文章
- 現在の実装判断に不要な途中経過だけの比較

### Plan に保持するもの

- 最終的に採用した設計と現在の rationale
- Goal / Scope / Constraints
- Acceptance Criteria / requirement 契約
- Files / Interfaces / Work Breakdown
- Test / Verification 契約
- rollback / stop / approval boundary

### Decision Log に保持するもの

Plan から消すと将来同じ誤判断を繰り返す可能性がある情報は、削除ではなく `decision-log.jsonl` に退避する。

- 重要な却下案
- 採用案と代替案の trade-off
- C-2 で却下した理由
- 将来 Agent が同じ案を再提案しないために必要な rationale

`decision-log.jsonl` は append-only とし、Normalization のために既存行を書き換えない。

## 6. Preservation Check

意味的な再構成そのものは Agent が行うが、機械的に確認できる不変条件は `scripts/check-plan-normalization.py` で fail-closed に検証する。

```bash
python3 scripts/check-plan-normalization.py \
  --before docs/working/TASK-XXXX/evidence/plan-normalization/plan.before.md \
  --after docs/working/TASK-XXXX/plan.md
```

Checker は次を確認する。

- `Goal` / `Scope` / `Global Constraints` / `Work Breakdown` / `Verification Plan` が残っている
- before に存在した `AC-*` / `REQ-*` / `FR-*` / `NFR-*` が after から消えていない
- 代表的な履歴依存表現が Canonical Plan に残っていない

### 機械検証の限界

ID を持たない自然言語要件の意味保存、rationale の妥当性、`todo.md` / `test-cases.md` との意味的整合は静的 checker だけでは保証できない。

そのため checker PASS は C-1 の代替ではない。Normalization 後に必ず簡易 C-1 を再実行する。

## 7. C-1 再実行

Normalization 後は少なくとも以下を再確認する。

- AC と Work Breakdown の対応
- Files / Interfaces が具体的である
- Verification Plan が欠落していない
- placeholder / unresolved unknown が混入していない
- scope / risk / security / backward compatibility が変質していない
- `todo.md` / `test-cases.md` と矛盾しない

FAIL の場合は C-3 に進まず Plan を修正し、Normalization / checker / 簡易 C-1 を再実行する。

## 8. 禁止事項

- C-3 APPROVED 後に `plan.md` を Normalize して hash を変える
- `canonical-plan.md` を追加して `plan.md` と二重正本にする
- 読みやすさを理由に AC / requirement を削除・再採番する
- unresolved な論点を Agent が勝手に確定状態へ変換する
- Decision Log や C-2 review を削除して監査履歴を失う
- checker PASS だけで C-1 を省略する

## 9. PASS 条件

Plan Normalization Gate は以下をすべて満たした時だけ PASS とする。

- [ ] 正規化前 snapshot が保存されている
- [ ] `plan.md` が Current Canonical State として自己完結している
- [ ] superseded / rejected な案が実行指示として残っていない
- [ ] 必要な rejected rationale / trade-off が `decision-log.jsonl` に保持されている
- [ ] stable contract ID が欠落していない
- [ ] normalization checker が PASS（利用可能な環境）
- [ ] `todo.md` / `test-cases.md` と意味的に整合する
- [ ] 簡易 C-1 が PASS
- [ ] C-3 はまだ発行されていない

この Gate を通過した `plan.md` を C-3 の承認対象とし、その hash を exec まで不変として扱う。
