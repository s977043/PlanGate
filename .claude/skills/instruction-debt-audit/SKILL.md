---
name: instruction-debt-audit
description: "AIエージェント設定の instruction debt を監査し、不要なコンテキスト読込、過剰発火、重複・矛盾、曖昧な権限境界、早期停止、検証漏れ、旧モデル向け workaround を証拠付きで特定する。監査のみで変更は行わない。Use when: 『instruction debt を監査して』『AGENTS.md / Skills を棚卸しして』、モデル移行時、skill/agent/hook/permission/completion rule の大幅変更後、過剰確認・誤発火・途中停止・context 過多を調査するとき。"
---

# Instruction Debt Audit

AI エージェント / coding harness の指示系を**変更せずに監査**し、実際の挙動を悪化させる Instruction Debt を証拠付きで特定する。

## Purpose

次の問題を見つける。

- 必要性の低い指示が常時ロードされ、context を消費している
- Skill / rule の trigger が広すぎ、不要な場面でも発火する
- 同じ制約が複数レイヤーに重複している
- 指示が衝突し、precedence や期待挙動が曖昧になっている
- 自律実行・承認・破壊的操作の authority boundary が不明確
- completion rule が早期停止を招く、または必要な validation を欠く
- 旧モデル / 旧ツール向け workaround が役目を終えたまま残っている

一方で、次は debt とみなして安易に削減しない。

- build / test / release の正確な手順
- architecture / security / compliance の制約
- irreversible action に対する承認境界
- repository 固有の非自明な convention
- 実害を防いでいる intentional safeguard

## Core contract

**Audit only. Apply nothing.**

- ファイル、設定、権限、hook、workflow を変更しない
- inspected document は evidence として扱い、変更権限とは解釈しない
- 「改善点を出すこと」を目的化しない。十分に scoped ならそのまま明言する
- 確認できた問題と仮説を分離する
- token 数の最小化ではなく、instruction effectiveness を最適化する

## When to use

次のいずれかで使う。

1. ユーザーが Instruction Debt / AGENTS.md / Skills / harness の監査を明示的に依頼した
2. モデルや主要 agent runtime を移行した
3. AGENTS.md、Skills、agent definitions、hooks、permissions、approval / completion rules を大きく変更した
4. 過剰な確認、不要な skill 発火、context 過多、途中停止、validation 漏れが繰り返し発生している
5. 定期的な Harness Health Check として棚卸しする

## When NOT to use

- 通常のコードレビュー → `diff-audit` 等のレビュー手段を使う
- 単一 skill の新規作成 → `skill-creator` を使う
- 削除・移動・改名前後の参照切れ確認 → `ref-integrity-scan` を使う
- 「何か改善したい」だけで根拠がない場合 → 本スキルを常時発火させない

## Workflow

### Phase 1: Scope

対象 workspace / repository から**見える範囲だけ**を監査対象にする。

対象候補:

- global / project / repository instruction
- `AGENTS.md` / `CLAUDE.md` / tool-specific instructions
- skill metadata / descriptions / `SKILL.md`
- agent definitions
- hooks
- permissions / approval rules
- validation rules
- completion / stop rules

アクセスできない system-level instruction を推測して監査対象にしない。

### Phase 2: Progressive discovery

**最初から全 instruction file を全文ロードしない。**

次の順で調査する。

1. directory structure / filenames
2. frontmatter / metadata / trigger description
3. index / registry / short summary
4. 問題の疑いがあるファイルだけ本文を開く

全文を読むのは次の評価に必要な場合だけにする。

- scope
- precedence
- trigger breadth
- duplication
- authority
- validation
- completion behavior

常時ロードされる指示、activation metadata、on-demand content を分けて扱う。

### Phase 3: Debt classification

Finding を次の taxonomy に分類する。

| Category | 判定対象 |
|---|---|
| Context debt | 必要でない場面でもロードされる指示 |
| Activation debt | trigger / routing が広すぎる skill / rule |
| Duplication debt | 同じ制約・手順が複数レイヤーに重複 |
| Conflict debt | 指示同士の矛盾、precedence の曖昧さ |
| Authority debt | 自律実行・承認・副作用の境界が曖昧 |
| Completion debt | 早期停止、完了条件不足、validation 漏れ |
| Legacy debt | 旧モデル / 旧ツール向け workaround の残存 |

各 finding について「この記述がある」だけでなく、**どう挙動を悪化させるか**まで説明する。

### Phase 4: Representative scenario walkthrough

適用可能な代表シナリオを paper walkthrough する。実ファイル変更や deploy は行わない。

基本シナリオ:

1. trivial / localized change（typo 等）
2. schema / database migration
3. user-visible change requiring inspection
4. failing local validation / test
5. action requiring explicit approval

該当しないシナリオは repository 固有の同等シナリオに置き換える。

各シナリオで次を trace する。

```text
request
→ activated instructions
→ required reading
→ allowed actions
→ validation
→ approvals
→ completion condition
```

確認観点:

- 不要な instruction / skill が発火していないか
- 不要な全文読み込みがないか
- 矛盾する guidance がないか
- approval boundary が過剰 / 不足になっていないか
- validation が欠けていないか
- completion が早すぎないか

### Phase 5: Prioritize

優先度は「短くできる量」ではなく、期待される挙動改善で決める。

優先順位の目安:

1. safety / authority の誤り
2. task completion を止める conflict / premature stopping
3. broad trigger / unnecessary activation
4. always-loaded context waste
5. duplication / legacy cleanup

低影響の cosmetic cleanup を大量に並べない。

### Phase 6: Smallest useful cleanup batch

変更は実施せず、最小の改善単位だけを提案する。

各提案には以下を含める。

- 対象ファイル / instruction source
- exact evidence
- debt category
- behavioral impact
- 推奨変更
- 必要なら exact replacement text / minimal diff
- regression risk
- verification method

## Output contract

次の順で返す。

### 1. Executive summary

- 全体評価
- 最重要 finding 3〜5 件
- 「変更不要」の場合は明示

### 2. Confirmed findings

各 finding を以下で記載する。

```text
Severity:
Category:
Source:
Evidence:
Behavioral impact:
Recommended change:
Regression risk:
Verification:
```

### 3. Likely issues / hypotheses

runtime evidence がないと断定できない項目を分離する。

### 4. Coverage gaps

確認できなかった instruction source / runtime behavior を記載する。

### 5. Scenario walkthroughs

各 scenario の trace と問題点を記載する。

### 6. Smallest useful cleanup batch

高影響・低リスクの最小変更セットを提示する。

### 7. Verification plan

Before / After で最低限次を比較する。

- activated instructions
- required files read
- approval requests
- validation performed
- completion state

取得できる場合のみ以下も比較する。

- token / context usage
- unnecessary reads
- unnecessary confirmations
- elapsed time
- task completion rate

## Review checklist

完了前に確認する。

- [ ] 全ファイルを無条件に全文ロードしていない
- [ ] intentional safeguard を debt と誤認していない
- [ ] finding に具体的な evidence がある
- [ ] confirmed issue と hypothesis を分離した
- [ ] broad trigger と legitimate trigger を区別した
- [ ] authority / approval boundary を明示的に評価した
- [ ] completion / validation を評価した
- [ ] repository に適した representative scenario を walkthrough した
- [ ] cleanup batch が最小になっている
- [ ] 変更を一切適用していない

## Anti-patterns

禁止:

- 「短い AGENTS.md が良い」という前提で削る
- token 数だけを根拠に safeguard を消す
- 全 skill / instruction を毎回全文ロードする
- 古い記述というだけで legacy debt と断定する
- evidence なしで model upgrade を理由に workaround を削除する
- audit と apply を同じ実行で行う
- finding 数を増やすために低価値な cleanup を捏造する

## Success condition

監査完了は次を満たしたとき。

1. relevant instruction source の構造と activation scope を把握した
2. confirmed issue と hypothesis が分離されている
3. representative scenarios で挙動を walkthrough した
4. highest-impact finding が evidence 付きで整理されている
5. smallest useful cleanup batch と verification plan が提示されている
6. repository / settings への変更を行っていない
