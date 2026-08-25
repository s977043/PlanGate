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

## 適用範囲（この Gate が掛かる対象）

本 Gate は **これから normalization を通す Plan にだけ**適用する。既存の
`docs/working/TASK-XXXX/plan.md` 全体を後から一括で検査する lint ではない。

| 対象 | 扱い |
|---|---|
| 本 skill を通して正規化する Plan（C-2 反映後・C-3 前） | **適用**（checker 必須） |
| 既に C-3 承認済み / 完了済みの過去 Plan | **対象外**（遡って是正しない。C-3 後の書き換えは `plan_hash` を壊すため禁止） |
| C-2 を実施せず修正履歴も無い light / ultra-light の Plan | N/A（実施しない。ただし C-1 / C-3 の既存条件は緩和しない） |

理由: checker の必須見出しは `docs/working/templates/plan.md` 系の Canonical
Plan 構造を前提としており、過去に別テンプレートで書かれた Plan は構造的に
一致しない。既存資産を一括で違反判定にしないため、適用対象を「正規化を通す
Plan」に限定する。過去 Plan を canonical 化したい場合は、その Plan を本 skill
に通す時点で初めて対象になる。

## Read First

1. `docs/working/TASK-XXXX/plan.md`
2. `docs/working/TASK-XXXX/pbi-input.md`
3. `docs/working/TASK-XXXX/test-cases.md`
4. `docs/working/TASK-XXXX/todo.md`
5. `docs/working/TASK-XXXX/review-external.md`（存在すれば）
6. `docs/working/TASK-XXXX/review-self.md`
7. `docs/working/TASK-XXXX/decision-log.jsonl`
8. `docs/ai/plan-normalization-gate.md`（上流リポジトリで参照可能な場合。**本 Skill が正本**であり、当該 docs は上流向けの概要と入口）

> **参照解決順（`docs/**` / 導入先で必ずこの順に探す）**: 本 Skill が参照する `docs/**` は上流リポジトリ基準の相対パスであり、`install.sh --claude` / plugin（Claude marketplace）/ Codex の **3 経路とも配布対象外**（解決不可）。(1) 導入先リポジトリの同名パスを探す → (2) 見つからなければ **「正本 `<path>` を参照できなかった」と明示**し、本 Skill 内の記述を代替正本として扱い、推測で内容を補わない。**plugin root 配下の探索は `docs/**` には適用しない**: plugin が配布するのは `agents` / `commands` / `skills` / `rules` 等の定義ディレクトリのみで `docs/` を配布対象として認識せず、plugin root 配下に相当する配布物が存在しないため、plugin root 段を置いても必ず空振りする（クラス A の rules 参照が plugin root 配下で解決できるのは `rules/` が実際に配布されるからであり、この非対称を `docs/**` に持ち込まない）。

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

上流リポジトリでスクリプトが利用可能なら実行する。**baseline は git 由来を
既定にする**（`--before-ref`）。

```bash
python3 scripts/check-plan-normalization.py \
  --before-ref HEAD \
  --after docs/working/TASK-XXXX/plan.md
```

`--before-ref <git-ref>` は `git show <ref>:<path>` で正規化前の Plan を読む。
これは **baseline を正規化 Agent 自身が書けないようにする**ための既定経路で、
C-3 が `plan_hash` を C-3 発行時の SHA-256 で固定して EH-3 が突合するのと
同じ考え方（承認対象は自己申告でない）。

step 1 の snapshot を `--before` に渡す経路も残っているが、それは **Agent が
自分で書いたファイル**なので checker は `[WARN]` を出す。commit 前で git ref が
無い等の理由でこの経路を使った場合、その run では「baseline は未検証」である
ことを review-external / decision-log に明記する。

```bash
python3 scripts/check-plan-normalization.py \
  --before docs/working/TASK-XXXX/evidence/plan-normalization/plan.before.md \
  --after docs/working/TASK-XXXX/plan.md
```

この checker は少なくとも次を fail-closed で確認する（exit 1）。

- **before と after が同一（no-op）** — 何も正規化していない状態で gate を
  自己証明することを塞ぐ
- core heading 欠落（番号接頭辞 `## 1. Goal` / h1 `# Goal` / 副題併記
  `## Scope（In Scope / Out of Scope）` は同一見出しとして扱う）
- before に存在した `AC-*` / `REQ-*` / `FR-*` / `NFR-*` / `R-*` の消失
  （`R-NNN` は C-2 指摘 ID。本 Gate は R-NNN 確定反映の直後に置かれるため
  保存対象に含める）
- **契約 ID が 1 つも無い** — ID が空だと「消えた ID の集合」は常に空になり、
  ID 保存の検査が何も見ないまま PASS する（恒真 PASS）。この Gate に到達する
  Plan は C-1 / C-2 を通っており AC を持つ前提なので、WARN ではなく違反として
  扱う
- canonical Plan に残った代表的な履歴依存表現と、superseded 状態の構造
  （取り消し線 / 「代替案」「変更履歴」等を宣言する見出し）

起動不正・入力不良（引数不足 / 不在ファイル / 非 UTF-8）は exit 2 で、契約違反
（exit 1）と区別する。

#### 機械検証の限界（denylist であること）

履歴依存表現の検出は **固定パターンの denylist** であり、再現率は低い。
「元々の方針から改めた」「初期案では別実装だった」「we changed this after
feedback」のような言い換えは **検出されない**。構造マーカー（取り消し線 /
履歴・代替案を宣言する見出し）を併用して「言い換えでは消せない形」を拾って
いるが、これも網羅ではない。

したがって **checker PASS は step 5 の自己完結性チェックの代替にならない**。
ID を持たない自然言語要件の意味保存、rationale の妥当性、`todo.md` /
`test-cases.md` との意味的整合はいずれも静的検査では保証できない。手動チェックを
省略しない。

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
- checker PASS だけを根拠に簡易 C-1 を省略する
- `--before` に after と同一内容を渡して gate を自己証明する

## PASS 条件（正本 / 全 9 項目）

Plan Normalization Gate は次を **すべて**満たしたときだけ PASS とする。

- [ ] 正規化前 baseline が確定している（`--before-ref` の git ref、または
      step 1 の snapshot）
- [ ] `plan.md` 単体が Current Canonical State として自己完結して読める
- [ ] superseded / rejected な案が Plan の実行指示に残っていない
- [ ] 重要な rejected rationale / trade-off が `decision-log.jsonl` に保持
      されている
- [ ] stable contract ID（`AC-*` / `REQ-*` / `FR-*` / `NFR-*` / `R-*`）が
      欠落していない
- [ ] checker が PASS（利用可能な環境。no-op でないことを含む）
- [ ] `todo.md` / `test-cases.md` と意味的に整合する
- [ ] 簡易 C-1 が PASS
- [ ] C-3 がまだ発行されていない

1 つでも満たさない場合は C-3 に進まない。この Gate を通過した `plan.md` を
C-3 の承認対象とし、その hash を exec まで不変として扱う。
