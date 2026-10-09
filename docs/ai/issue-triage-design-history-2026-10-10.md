# Design History — Issue Triageから学習する運用へ（2026-10-10）

> **Status**: Discussion record / article seed（設計時点の履歴。運用効果は未実証）
> **Recorded**: 2026-10-10
> **Scope**: PlanGate OSS Issue管理における発見・整理・実行・継続的改善
> **Living rule**: [Issue Triage Living Playbook](./issue-triage-playbook.md)
> **Rules SSoT**: [Issue Governance](./issue-governance.md)
> **Trace**: [棚卸し Issue #1503](https://github.com/s977043/PlanGate/issues/1503) / [PR #1548](https://github.com/s977043/PlanGate/pull/1548)
> **Change policy**: 過去の議論・判断の履歴は書き換えて「当初から決まっていた」と見せない。新しい発見や判断は末尾の追記履歴に日付とEvidenceを伴って追記する。現行の実行ルールはLiving Playbookに反映する。

## 1. なぜこの議論を残すのか

OSS Issueの数を減らすための機械的な棚卸しではなく、**Issueの整理を通じて、Issueの管理方法も学習・改善し続ける**運用を目指した。

検討の出発点は、完了済みIssueのClose、重複の集約、関連・依存関係のリンク、旧環境で再現不能なIssueの合理的な整理だった。調査後、「判断の根拠を残しながら小さく試す」Living Playbookへ進み、さらに「その運用自体を改善するループ」が重要であると気付いた。

**大切な転換**: 一度作ったプロセスを完成品とみなさず、プロセス自体も仮説として扱う。アジャイルの経験主義と、AIが提案・検証を支援する開発運用の接点を残す。

## 2. 2026-10-10の検討の流れ（履歴スナップショット）

| 段階 | 当時の問い | 得られた判断・変更 | 検証状況 |
| --- | --- | --- | --- |
| OSSベストプラクティスの確認 | completed、duplicate、obsolete、blocked をどう区別するか | Close理由と証拠、残AC移管、関連/依存の区別を明文化。staleはClose理由ではなく確認のきっかけ | 分類の考え方を設計 |
| Living Playbook化 | 永続不変の規則ではなく改善する文書にできないか | 基本規約は既存 `issue-governance.md`、実運用は `issue-triage-playbook.md`、個別判断はGitHub Issue/PRに分離 | PR #1548で提案 |
| Fast Fail / Quick Recovery | 完璧な棚卸し準備で止まらないか | 3〜5件の小バッチ、事後再取得、誤Close・未移管ACの早期検知とreopen/訂正 | 初期仮説。実走前 |
| 棚卸しと改善の二重ループ | Issue整理**そのもの**も改善できるか | Loop A = Issue Triage、Loop B = Process Evolution。2バッチの事実から1仮説ずつ改善 | 運用実測待ち |
| Dual Trackとの比較 | 二重ループとDual Trackは同じか | **別概念**。Dual TrackはDiscovery/Deliveryの並走、今回の二重ループは実行と実行方法の改善という階層関係 | 概念整理 |
| Double-Loop Learningとの比較 | 実行手順の改善だけで十分か | 前提・判断基準・目的まで問い直せる余地を残す。ただし**運用改善の全てがDouble-Loop Learningではない** | 今後の学習テーマ |
| 記事ネタ化 | この議論を外部へどう伝えるか | 実践の背景、採用しなかった案、未検証仮説と実験後の結果を分けて残す | 記事未作成・未公開 |

ここに記したのは**議論と設計判断の履歴**であり、Playbookの実効性、運用変更の効果、CI、Humanによる最終承認の完了を証明するものではない。

## 3. 用語の整理 — 混同しないための決定

| 用語 | 主目的 | 具体的なPlanGateの活動 | 注意点 |
| --- | --- | --- | --- |
| **Dual Track Agile / Continuous Discovery & Delivery** | 何が有効かを発見し、価値を継続的に届ける | Discovery: 課題、証拠、価値、リスクを検証。Delivery: 採用された変更を設計・実装・検証・提供 | 2つの**並行する活動**。単純なDiscovery完了→Delivery着手の直列ゲートや別チームへの丸投げではない |
| **Issue Triage (Loop A)** | 管理するIssueを実態と一致させる | Issueの分類・統合・関連付け・適切なClose/保留・実施後の照合 | IssueのCloseもTriage成果になり得るが、ソフトウェアのDeliveryそのものではない |
| **Process Evolution (Loop B)** | Issue Triageや関連フローの進め方を改善する | Frictionを観測→改善仮説→小バッチ試行→Keep/Adapt/Revert/Defer | **運用対象と運用方法という階層の違い**。Dual Trackの別名ではない |
| **Single-Loop Learning** | 現在の目的・判断基準を保持して手段を修正する | 分類手順を短縮、リンクチェックの順番を改善 | 単にループが1本あるという意味ではない |
| **Double-Loop Learning** | 必要に応じて目的・規範・判断基準も問い直す | 「発見をすべて独立Issueとして起票すべきか」「Close件数を成功と呼ぶべきか」を検討 | Process Evolutionが前提まで問い直した**場合に限り**該当。二重ループと語が似るだけで自動的に同義ではない |

### 将来の運用モデル（提案。固定ルールではない）

```text
Continuous Discovery  <---->  Continuous Delivery
    (what / why)               (build / verify / deliver)
         \                        /
          \   observations       /
           v                    v
          Process Evolution (Inspect & Adapt)
                   |
       experiment / evidence / judgment
                   |
          changed operational practice
                   |
          feedback into both tracks
```

Issue Triageはこの全体の**具体的な適用例**。Issueの棚卸しの範囲では、分類・Close・リンク更新という作業と、その方法の改善を別ループとして観測する。PlanGate全体にDual Trackを制度として新設したことを意味しない。

## 4. 意図して採用しなかったこと・守る境界

- **採用しない**: 全件棚卸しを完全に設計・自動化してから実走する、stale件数だけで一括Closeする、類似タイトルだけで重複判定する、二重ループをDual Trackと呼び替える。
- **変更しない**: 既存のkind/area/priority/status、Milestone、PR linkageの正本と、C-3/C-4、HO、Human-owned decision・mergeの責務。
- **誤解防止**: Fast Failは品質を落とすことではない。戻せるのは主にIssueの状態・コメントなどの運用上の判断であり、過去のセキュリティ事故や権限逸脱をなかったことにはできない。
- **AIの役割**: 仮説・分類・観測・実装候補・独立観点レビューを支援する。EvidenceとJudgment、提案と承認を混同しない。
- **未決定**: #1005のBacklog Admission / Committed WIP案は別の未完了の検討であり、今回の履歴だけで正式採用に格上げしない。

## 5. 次に実際の運用で確かめること

**Design Hypothesis H1**: 3〜5件という小さな棚卸しバッチは、全件一括整理よりも、確認可能な証拠と高速な修復を両立しやすい。

**Design Hypothesis H2**: Triage自体のfrictionを2バッチごとに観測して「改善は1仮説ずつ」とすると、チェック項目を増やしすぎずに見落としを減らせる。

**Design Hypothesis H3**: Close速度だけでなく、誤Close・残AC移管漏れ・誤リンク・Human待ちを観測すると、バックログの見た目ではなく判断の質を改善できる。

| 実験 | 対象候補 | Evidence to collect | 判定基準 |
| --- | --- | --- | --- |
| Batch 1 | #1507 / #1519 / #1524 | 確認に要した負荷、各Issueの残AC・PR・Open継続理由、誤判定と修復 | 「残ACがあるからOpen」をClose漏れと誤認しない。根拠付きの判断を残せたか |
| Batch 2 | Batch 1後に選ぶ同程度の小バッチ | 分類・リンクの正確性、完了時間、迷った判断 | Batch 1との比較が可能か。対象難度差を記す |
| Evolution 1 | 観測したfrictionから1件だけ改善 | before / after と負の副作用 | Keep / Adapt / Revert / Defer をEvidence付きで決めたか |
| Assumption review | 2バッチ終了後 | 独立Issue化の妥当性、カテゴリの意味、運用負荷 | 前提変更が必要か。必要ならHuman判断・別PR |

**現在地**: 実験はこの履歴を記録した時点では未実施。Issueへの変更・Closeは検証前の成果に数えない。

## 6. 外部向け記事のタネ（未公開の編集メモ）

### 記事候補

1. **「Issueを整理するAI」から「Issue管理を改善し続けるAI」へ — アジャイルの経験主義をAI駆動開発に持ち込む**
2. **Dual Trackと二重ループは違う — OSSのIssue運用から考えた3階層の学習**
3. **Fast Failは雑なCloseではない — 小さなIssue棚卸しに必要だった可逆性と証拠**

**推奨する主記事**: 1。2は用語整理の補足または独立記事、3は実測後に切り出す。

### 読者への核心的なメッセージ（仮説）

> AIに分類・レビュー・更新を委ねるだけでなく、AIの運用フローそのものを仮説検証の対象にする。既存のアジャイルの知見は捨てず、AIによって観測と改善の周期を短縮する方向に再設計できる。

### 記事の構成素材

1. **問題**: Issueが溜まり、すべてを厳密に棚卸ししようとすると運用の整備自体がボトルネックになる。
2. **最初の転換**: 完了/重複/陳腐化を根拠付きで見直し、3〜5件の小バッチと再検証を試す。
3. **次の転換**: Issueの棚卸しだけでなく棚卸し方法も改善するLoop Bを設計する。
4. **重要な気付き**: Dual Track（Discovery/Deliveryの並走）と今回のLoop A/B（活動とその方法の改善）は異なる。「2つある」だけで同一視しない。
5. **学習の深さ**: 手順改善＝Single Loop、前提・判断基準そのものの再検討＝Double Loopという区別。
6. **AIとHumanの境界**: AIのEvidence生成/分類提案と、承認・リスク受容・マージの判断を切り離す。
7. **実証**: バッチ前後の観測、想定外の失敗、実際の回復、採用した変更（**実験後に追記**）。
8. **再利用できる実践**: 小バッチ、信頼できる証拠、二種類の学習、Living Playbook、変更履歴。

### 公開前に満たす編集チェック

- **設計・仮説・運用結果を区別**し、存在しない改善率・実験結果・事例を作らない。
- 具体例は公開Issue/PRや許可されたコード・ログだけを使う。内部情報・個人情報・未公開の承認記録を引用しない。
- 他社理論を「PlanGateの発明」と誤読させず、元の概念と今回の適用・解釈を分ける。
- 他者の記事や解説をコピーしない。構成、文章、図は自身の観測・説明に基づいて独自に作る。
- 仕組みが機能したかは、結果が取れてから記述する。「PR作成済み」は「運用検証済み」と同義ではない。

### 参考となる一次ソース（公開前に再確認）

- Marty Cagan, [Dual-Track Agile](https://www.svpg.com/dual-track-agile/) — Discovery/Deliveryを並行させる理由。本人は後にContinuous Discovery/Deliveryという表現を好むと注記。
- Marty Cagan, [Continuous Discovery](https://www.svpg.com/continuous-discovery/) — Discoveryも継続的な活動とする立場。
- Chris Argyris, [Double Loop Learning in Organizations](https://hbr.org/1977/09/double-loop-learning-in-organizations) — 目的・規範を問い直す学習との区別。
- [The Scrum Guide (2020)](https://scrumguides.org/scrum-guide.html) — Transparency / Inspection / Adaptation。Issue管理に関する今回の運用はScrum Guideの規定そのものではなく独自適用。

## 7. 追記ログ（判断の履歴を保存する）

| 日付 | 記録種別 | 内容 / Evidence | 状態 |
| --- | --- | --- | --- |
| 2026-10-10 | Discussion snapshot | OSS Issue分類 → Living Playbook → Fast Fail / Quick Recovery → Loop A/B → Dual Trackとの相違 → Double-Loop Learning / 記事のタネ | 設計の記録。実験前 |
| 2026-10-10 | Proposed operational artifact | [PR #1548](https://github.com/s977043/PlanGate/pull/1548) / [#1503](https://github.com/s977043/PlanGate/issues/1503) | PR review / CI / Human C-4待ち。merge済みとは扱わない |
| 2026-10-10 | First pilot evidence | [#1503 第三次棚卸し](https://github.com/s977043/PlanGate/issues/1503#issuecomment-6088127351) — 2バッチ6件、#1241の古い前提修正、3 areaラベル補完、#1519の事後review debt更新 | 事実の記録。Close 0。時間・改善効果未計測、提案の有効性は未評価 |

新しい実験・レビュー・判断が生じたら**当時の記録を消さず**この表に追記し、最新の運用方法だけを[Living Playbook](./issue-triage-playbook.md)へ同期する。外部記事の編集は別途行い、本ファイルをそのまま記事として公開しない。
