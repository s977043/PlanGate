# Adoption UX & Ecosystem Roadmap

> PlanGate の導入摩擦を下げつつ、MCP / GitHub / Evals へ拡張するときの設計境界。
> Issue: #1476
>
> この文書は「何を今すぐ実装するか」ではなく、既存の PlanGate の責務境界を壊さずに
> 成長させるための product / architecture 方針を定める。

## 1. 目的

PlanGate の価値は、AI に多くのことを任せること自体ではない。

- 実装前に意図・計画・受入条件をレビューできる
- 実装中の scope / approval / evidence の逸脱を検出できる
- 実装後に「なぜこの変更になったか」を追跡できる
- model / provider を変えても、開発運用の判断境界を維持できる

今後の成長では、この価値を保ったまま次の2点を強化する。

1. **Time to First Value を短くする**
2. **外部エージェント / GitHub との接続面を増やす**

## 2. 導入メリットを誰に届けるか

### Reviewer / Tech Lead

PlanGate は「大きな AI-generated diff を最後に全部読む」だけのレビューを避け、
先に plan / scope / verification 方針をレビュー可能にする。

期待する効果:

- 実装前に architecture drift を発見しやすい
- 変更対象・非対象が明確になる
- PR review を「合意した plan と diff の差分確認」へ寄せられる
- 独立 reviewer / verifier の evidence を残せる

### Implementer

期待する効果:

- 実装途中の scope drift / rabbit hole を検出しやすい
- task artifact を session / model 切替後も引き継げる
- plan / todo / test-cases を実装コンテキストの anchor にできる
- provider 固有の会話履歴ではなく、repository artifact を正本にできる

### EM / PM / PO

期待する効果:

- Why / Plan / Approval / Verification の判断過程を追跡できる
- AI による変更でも責任境界を説明できる
- metrics / eval で導入効果を観測できる

ただし、**token / API cost の削減は測定前に効果として断定しない**。
削減が期待できる場合でも、PlanGate 自身の overhead を含めて比較する。

## 3. Progressive Disclosure

### 原則

初見ユーザーに C-X / V-X / WF-XX / EH-X を暗記させない。

表層では、まず plain language を使う。

| 表層 | 内部 / reference |
|---|---|
| Plan review | C-1 / C-2 |
| Human plan approval | C-3 |
| Build | WF-04 |
| Verify | V-1〜V-4 |
| PR approval | C-4 |
| Hook enforcement | EH-X |

内部コードは監査・仕様・実装の安定した識別子として残すが、
Quickstart / CLI error / onboarding では補助表記にする。

### 「PlanGate Lite」は新設しない

PlanGate にはすでに複数の最小導入経路がある。

- README の段階的導入 Level
- `docs/staged-adoption-guide.md` の Phase 0〜3
- `ultra-light` / `light` mode
- plugin-only adoption

したがって、新しい「Lite mode / 1-Gate mode」を追加すると、
mode / adoption level / phase の概念がさらに増える。

**最小体験は既存の段階導入を整理して提供する。新しい mode は作らない。**

### Level / Phase / Mode / Gate は別軸

初見時の認知負荷を下げるには、既存用語を単純に減らすだけでなく、
**何を表す軸なのかを混ぜない**ことが重要。

| 軸 | 何を表すか | 例 |
| --- | --- | --- |
| Adoption Level | 組織・チームとして、どこまで PlanGate capability を採用するか | Level 1〜5 |
| Staged Phase | 導入をどの時間軸で進めるかを示す onboarding guide | Phase 0〜3 |
| Task Mode | 個々のタスクの変更リスク・複雑性に応じた実行分類 | ultra-light〜critical |
| Gate / Identifier | workflow 内の具体的な制御点・検証点 | C-X / V-X / WF-XX / EH-X |

これらは alias ではない。たとえば、チームが Adoption Level 3 に到達していても、
個々の typo 修正は ultra-light になり得る。

互換性のため既存名称は維持するが、新規 onboarding document では
「導入レベル」と「タスク mode」を同じものとして説明しない。

## 4. Repository onboarding

### 現状

PlanGate には以下がすでにある。

- `bin/plangate init <TASK>`: TASK artifact の初期化
- `bin/plangate doctor`: 環境確認
- `bin/plangate doctor --fix`: hook wiring の修復

### 設計判断

`plangate init` は TASK 初期化として既存契約があるため、
repository bootstrap の意味を追加しない。

repository onboarding を1コマンド化する場合は、
`setup` / `bootstrap` 等の別 surface として設計する。

候補責務:

- prerequisites の検査
- provider-specific config の検出
- dry-run
- idempotent wiring
- 変更ファイルの一覧
- rollback / backup
- 完了後の smoke check

既存 `doctor --fix` と機能が重なるため、**先に gap analysis を行い、
新しいコマンドを追加する前に既存 surface の拡張で足りるかを判断する。**

## 5. Actionable CLI guidance

block / fail は「理由」だけで終わらせない。

可能な場合、次の1アクションを提示する。

    Blocked: plan approval is missing.
    Next: review the plan, then run the Human-owned approval command.

ただし、次のルールを守る。

- Human-owned action を AI 自身が実行したように見せない
- destructive / write command を無条件に提案しない
- status が CONDITIONAL / REJECT の場合に approve を機械的に勧めない
- read-only diagnosis を優先する
- HO surface の変更は通常の C-3 / review を通す

## 6. MCP integration

### 位置づけ

PlanGate MCP は **authority ではなく adapter**。

MCP client が PlanGate の canonical artifact / gate / evidence を読み取り、
既存の command / workflow へ request を渡すための接続面とする。

### Read surface 候補

- current task / current plan
- current phase / next action
- gate status
- verification status
- evidence references
- policy / mode / allowed paths

### Request surface 候補

- request plan review
- request Human approval **review / notification**
- request verification
- request PR convergence

ここでいう request は workflow を開始・通知する要求であり、
**approval artifact / approval decision 自体を MCP が発行することを意味しない**。

### 禁止

- MCP client による C-3 自己承認
- MCP client による C-4 自己承認
- automatic merge authority
- repository-local claim のみで independent verification 済みと扱う
- MCP server を新しい canonical state store にする

MCP が無い環境でも PlanGate core は動作できる状態を維持する。

## 7. GitHub-native integration

GitHub integration は PlanGate state の **projection / enforcement surface** とする。

候補:

- PR status check
- plan / approval / verification artifact existence check
- Issue / PR / TASK linkage check
- PR comment command for read-only status
- Human approval request notification

### 不変条件

- canonical artifact は repository 内の既存 contract を優先
- GitHub comment だけを唯一の approval provenance にしない
- C-4 / merge は Human-owned
- Bot は gate を観測・投影できるが、Human authority を偽装しない

## 8. Harness efficacy benchmark

PlanGate の効果は、単一の成功例ではなく比較可能な evidence で評価する。

### 既存資産を再利用する

- `bin/plangate eval`
- metrics
- fixed eval cases
- #1337 の paired evaluation 規律
- ai-loop V2 の RunEvidence / VerificationResult

### 比較設計

原則:

- same task
- same model / effort
- same tool permissions
- same context budget
- same acceptance criteria
- baseline / candidate の revision を固定
- raw output / evidence を保存
- independent scoring
- missing evidence は PASS にしない
- **INCONCLUSIVE を許容する**

### 候補指標

- first-pass verification rate
- repair count
- replan count
- PR review rework
- Human intervention rate
- Human review time
- latency
- token / API cost
- scope violation
- gate violation
- defect escape / rollback

「PlanGate で token が必ず減る」のような結論は、
測定条件と evidence が揃うまで出さない。

## 9. 優先順位

| Priority | Slice | 理由 |
|---|---|---|
| P0 | Actionable CLI guidance | 毎日の friction に直接効く |
| P1 | Repository onboarding gap analysis | Time to First Value を縮める |
| P1 | Harness efficacy benchmark | 成長施策の根拠になる |
| P2 | GitHub-native integration | チームの日常フローへ接続できる |
| P2 | MCP adapter | provider 横断の接続面を作れる |

MCP / Bot は魅力的だが、local UX と measurement より先には置かない。

## 10. 成長の判定基準

新機能は次を満たす場合に採用する。

1. 既存の authority boundary を弱めない
2. canonical state を二重化しない
3. provider lock-in を増やさない
4. failure 時に explainable である
5. test / evidence で効果を測れる
6. 未導入環境でも core workflow が壊れない

この6条件を満たさない integration は、露出が増えても PlanGate の成長とは扱わない。
