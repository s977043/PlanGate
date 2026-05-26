# Value Proposition Canvas: PlanGate

> **Status**: v0
> **Review cadence**: Monthly

## 目的

PlanGate が誰のどんな課題に効くのかを Value Proposition Canvas として整理する。

Product Overview、Positioning、FAQ、Pitch Deck、README の材料として使う。

## Customer segments

| Segment | Description |
| --- | --- |
| PM | AI 開発の成果をロードマップ、リリース判断、リスク管理に接続したい |
| PO | PBI、受入条件、Done の定義を AI 開発でも守りたい |
| EM | AI エージェントをチーム標準として安全に運用したい |
| CTO | AI 導入による速度と統制を両立したい |
| Developer | AI が作った変更をレビューしやすく、検証可能にしたい |
| OSS adopter | 自チームへ AI coding workflow を導入するための型が欲しい |

## Customer jobs

### Functional jobs

- AI coding agents をチーム開発に導入したい
- PBI から実装、検証、handoff までをつなげたい
- AI が書いたコードをレビュー可能にしたい
- 実装前に受入条件を明確にしたい
- scope creep を防ぎたい
- AI 開発の検証証拠を残したい
- provider / model が変わっても workflow を保ちたい

### Social jobs

- AI を使っても、チームとして説明責任を果たしたい
- PM / PO / EM / Developer 間で共通の判断材料を持ちたい
- AI 活用を個人芸ではなく組織能力にしたい
- 外部に対して AI 開発の統制を説明できるようにしたい

### Emotional jobs

- AI に任せても不安が少ない状態にしたい
- PR レビューで初めてズレに気づく状況を減らしたい
- AI の出力に振り回されず、プロダクト価値を守りたい
- 開発速度と品質・統制を両立している実感を持ちたい

## Pains

| Pain | Description |
| --- | --- |
| 間違ったものを速く作る | AI の速度が、価値のズレを増幅する |
| スコープ逸脱 | PBI 外の改善や実装を勝手に足す |
| 受入条件の後付け | 実装後に Done を都合よく解釈する |
| 実装前レビューがない | plan がないまま code diff だけが出る |
| 検証証拠が弱い | test 未実行、失敗、残リスクが曖昧になる |
| ブラックボックス化 | AI が何を根拠に変更したか追えない |
| チーム運用のばらつき | 個人ごとに AI の使い方が異なる |
| provider 依存 | 特定 IDE / agent の作法に workflow が引っ張られる |

## Gains

| Gain | Description |
| --- | --- |
| AI 開発を管理可能にする | PBI、plan、approval、verification、handoff が揃う |
| Done を明確にする | test-cases が実装前に固定される |
| レビューしやすくする | plan と diff を比較できる |
| リリース判断を支援する | 検証証拠と残リスクが残る |
| チーム標準化 | 同じ workflow / gate / artifact を使える |
| 継続改善 | eval、metrics、Keep Rate で改善できる |
| provider 横断性 | Cursor / Claude Code / Codex などを上位から統制できる |

## Pain relievers

| Pain | PlanGate reliever |
| --- | --- |
| 間違ったものを速く作る | C-3 承認前に実装させない |
| スコープ逸脱 | scope discipline と plan 承認で止める |
| 受入条件の後付け | test-cases を実装前に作る |
| 実装前レビューがない | plan / todo / test-cases をレビュー対象にする |
| 検証証拠が弱い | verification honesty と evidence を要求する |
| ブラックボックス化 | plan / review / handoff を残す |
| チーム運用のばらつき | workflow / mode / gate を定義する |
| provider 依存 | Model Profile / Tool Policy / Prompt Assembly で吸収する |

## Gain creators

| Gain | PlanGate creator |
| --- | --- |
| 管理可能性 | C-3 / C-4、status、approval artifacts |
| 受入条件の明確化 | test-cases artifact |
| レビューしやすさ | plan、todo、review-self、review-external |
| 検証可能性 | L-0 / V-1〜V-4、evidence、handoff |
| 継続改善 | Eval Runner、Metrics、Keep Rate |
| モデル差分への対応 | Model Profile v2、Tool Error Taxonomy |
| コンテキスト最適化 | Dynamic Context Engine |

## Value proposition

PlanGate helps product teams using AI coding agents keep scope, acceptance criteria, and review boundaries under control by requiring a human-approved plan and acceptance test set before production code changes.

日本語では以下。

PlanGate は、AI コーディングエージェントを使うプロダクトチームが、PBI のスコープ、受入条件、レビュー境界を保ったまま開発を進められるようにする。

AI が本番コードを書く前に、人間が承認した計画と受入条件を必須化することで、AI 開発を速いだけでなく、説明可能で、検証可能で、チームで運用可能なものにする。

## Message fit

| Audience | Best message |
| --- | --- |
| PM | AI 開発を、管理可能なプロダクトデリバリーにする |
| PO | AI 時代の Backlog Governance |
| EM | AI エージェント利用をチーム標準にする |
| CTO | AI 開発の速度に、承認・検証・監査を組み込む |
| Developer | AI がコードを書く前に、計画と受入条件を通す |
| OSS | Governance-first workflow harness for AI coding agents |

## Review questions

月次レビューでは以下を確認する。

- Customer jobs は変わっていないか
- Pains は実際の利用者の声と一致しているか
- Gains は実装済み機能で説明できるか
- Pain relievers が誇張になっていないか
- Roadmap 進捗により新しい gain creator が増えていないか
- PM / PO / EM / CTO の message fit は適切か
