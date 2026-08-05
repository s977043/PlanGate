# PBI INPUT PACKAGE: Reliability Recovery と backlog admission control

> フェーズ A（PBI INPUT）。関連 Issue: [#1005](https://github.com/s977043/PlanGate/issues/1005)

## Context / Why

2026-08-05 時点で open 48 件のうち plan 到達は 2 件、pbi-input のみ 19 件、作業ディレクトリなし 27 件である。46/48（95.8%）が plan 未到達であり、33/48（68.8%）は起票後に更新されていない。

月次の純増は 6 月 -1、7 月 +35、8 月 1〜4 日 +13（+2.9 件/日）である。7 月は close 数も 52 から 85 へ増えているため、単純な実装能力低下ではなく、AI agent・レビュー・実走による発見生成が Human の triage / C-3 / C-4 判断能力を上回ったと診断する。

現在は未評価の finding、要件化途中、plan 済みの実行候補がすべて open issue として同じキューに見えている。また、#921、#947、#997、#994、#991、#970、#942 では、検査が存在しても失敗を exit code へ伝播しない、題目どおりの対象を見ない、CI で実行されないといった共通欠陥が確認されている。

信用できない baseline のまま 15 件を同時に進めると、誤った成功シグナル、Human review queue、部分完了からの follow-up 増殖を拡大する。

## What（Scope）

### In scope

- Issue lifecycle を Discovery / Qualified / Committed に分離する昇格契約
- Human decision throughput を基準にした WIP 制限
- Reliability Recovery 1 の対象・順序・Exit Criteria
- #921 を先頭とする Minimum Trust Kernel
- #978 を用いた縦切り実走の開始条件と completion boundary
- negative control / mutation test を検査修復の必須証拠とする規則
- follow-up Issue の scope split 契約
- merge 後の Issue writeback を Definition of Done に含める規則
- 大型構想 Issue を RFC / Discussion 相当へ分離する判定基準
- 2 サイクル後に WIP 制限を見直すための flow metrics
- 既存 Issue へ実行順・依存・証拠要件を writeback する

### Out of scope

- C-3 承認前のコード・hook・CI・rules・settings の実装変更
- 既存 48 Issue の推測による一括 close / label / milestone 変更
- AI による C-3 / C-4 / merge / milestone commitment
- #906 / #916 を #978 に吸収すること
- 大型構想 9 件の設計裁定そのもの
- 新規 finding の記録停止
- 新しい外部依存・SaaS・project management tool の導入

## 受入基準

- [ ] AC-01: Discovery / Qualified / Committed の定義、入口条件、昇格主体、禁止事項が文書化されている
- [ ] AC-02: plan 作成中、C-3 待ち、implementation、C-4 待ち、直近 milestone に WIP 上限が設定され、超過時に新規着手を止める規則がある
- [ ] AC-03: Reliability Recovery 1 の Committed 候補が 6〜8 件以内に絞られ、#921 を先頭に置く依存理由が明記されている
- [ ] AC-04: #921、#997/#947、#994、#991/#970、#942 の各修復で、修正前に FAIL する negative control または mutation test が要求されている
- [ ] AC-05: #921 と 2 種類以上の negative control 成立後に #978 を縦切り開始できる条件が定義されている
- [ ] AC-06: #978 の初回実装境界が source provenance、downstream での bundled template fail-closed、実行記録に限定され、#906/#916 を含めない
- [ ] AC-07: 現 Issue の未充足 AC を follow-up へ移すだけでは close 不可とし、Human による scope split 決定と記録項目が定義されている
- [ ] AC-08: PR/commit/evidence、AC 実績、未充足、follow-up 理由、completion class の Issue writeback が DoD に含まれる
- [ ] AC-09: Current / Existing implementation / Desired invariant / Alternatives / Human decision / Trigger を書けない大型構想は Committed にしない基準がある
- [ ] AC-10: Discovery→Qualified、triage time、Qualified→plan、C-3/C-4 wait、fully satisfied close、follow-up ratio、writeback ratio、negative control rate、WIP exceed time を2サイクル記録できる
- [ ] AC-11: #921、#997、#994、#942、#978 の Issue に #1005 との関係と実行条件が writeback されている
- [ ] AC-12: C-3 / C-4 / merge / HO apply / milestone commitment が Human-owned のまま維持される

## Notes from Refinement

- backlog の絶対件数 48 は廃棄理由にしない。実行可能性と成熟度の混在を解消する
- 「発見を止める」のではなく「Committed への自動昇格を止める」
- 8 件の検査足場をすべて終えるまで本線を止めない。Minimum Trust Kernel が成立した段階で #978 を縦切りする
- #997 は `git status` の前後文字列比較より、対象 record の `path -> content hash` 前後比較を第一候補とする。検査題目に直接対応し、無関係な untracked file や表示順に依存しないため
- #942 は `.github/workflows/**` を含むため AI は patch / test plan / negative PR 設計までとし、適用は Human が行う
- 同一ファイルを触ることだけでは Issue 統合理由にしない。同一 root cause / invariant / verification / atomic intermediate state を満たす場合だけ同一 PR を検討する

## Estimation Evidence

### Risks

- governance 文書整備だけで満足し、完全充足 Issue が 1 件も流れない
- label を追加しても昇格主体と WIP stop rule がなければ形骸化する
- test foundation を大規模再設計し scope が膨張する
- #978 が #906/#916 の共通化へ広がり縦切りにならない
- Human-only HO 適用が隠れ WIP となる
- close velocity が部分完了を含み、改善を誤判定する

### Unknowns

- 現行ラベル体系に lifecycle state を表現するラベルが既に存在するか
- milestone 9 の正式名称と、15 件から 6〜8 件へ commitment を変更する Human 判断
- repository identity / downstream context を判定する既存の正本インターフェース
- metrics を既存 events / scripts から導出できる範囲と、追加実装が必要な範囲

### Assumptions

- C-3 / C-4 / merge は Human-only を維持する
- 直近 milestone への割当は実行 commitment として Human が決定する
- #921 の exit status 修復が、後続 negative control の証拠信頼性に先行する
- #978 は PlanGate の中核価値を実走で確認できる最小の approval-boundary vertical slice である
- 2 サイクルは「Committed item を選定して review まで終える一連の運用」を単位とし、暦週固定にはしない
