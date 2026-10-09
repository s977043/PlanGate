# Issue Triage Living Playbook

> **Status**: Living / v0.1（運用仮説。完成版ではない）
> **Owner**: Maintainer / Governance
> **Started**: 2026-10-10
> **Review cadence**: 運用中の随時改善 + 月次レビュー（週次の軽量Triageは試行）
> **Related**: [Issue Governance](./issue-governance.md) / [棚卸し #1503](https://github.com/s977043/PlanGate/issues/1503)
> **Design history / article seed**: [2026-10-10の設計議論・比較・公開記事のタネ](./issue-triage-design-history-2026-10-10.md)

## 1. 目的と正本の境界

Open Issue を「過去に発見したことの保管庫」ではなく「現在、何を判断・実行するかが分かるバックログ」に保つ。過去の証跡は GitHub の Closed Issue / PR に残るため、不要な Open 状態を保存しない。

この文書は **変化する運用合意（Living Playbook）**。実行中の観測により改訂するもので、別の固定ガバナンスや自動 Gate を新設するものではない。

- **固定側の正本**: [issue-governance.md](./issue-governance.md) が Issue 必須項目、kind / area / priority / status、Milestone、PR linkage を管理する。本書でラベル体系を二重定義しない。
- **事実の正本**: 現在の `main`、GitHub Issue、PR、関連するテストと実行ログ。棚卸しレポートと [#1503](https://github.com/s977043/PlanGate/issues/1503) は測定時点のスナップショットであり、現在値とは限らない。
- **権限の境界**: C-3 / C-4、Hardening Override (HO)、Human-owned decision、merge の責務を変更しない。AI の分類は候補であり、検証・承認の代替ではない。
- **原則**: 余分なラベル、bot、CI、完璧な初期分類を増やすより、既存の GitHub 機能と小さな実地検証を優先する。判断待ちと全作業停止を同一視しない。具体的な判断準備とHuman Attention最適化は [PR #1549のDecision-Ready方針案](https://github.com/s977043/PlanGate/pull/1549) に整理している（**未マージの提案であり、新たな許可ではない**）。

## 2. Agile / Fast Fail & Quick Recovery

**完璧な一括棚卸しより、小さな変更を速く試し、誤りを早く見つけて直す**。

| 原則 | 今回の運用への適用 | フィードバック |
| --- | --- | --- |
| Small batch / fast feedback | 最初は **3〜5件**を1バッチとして分類 → 必要な変更・相互リンク → **Closeは根拠を満たす場合だけ** → 再取得・照合。慣れたら件数を調整 | バッチ終了時に判断・誤分類・残ACを確認 |
| Fail fast | PR merge 後の Close 漏れ、統合後の未移管AC、壊れた相互リンクを早期検知。機械判定は参考であり、false green を許容しない | リンクと状態を再取得し、重要な判定は証拠で確認 |
| Quick recovery | Close 前に根拠と代表先を残す。誤Closeなら理由を記録して reopen。仕様が変わった後の再発は旧Issue参照付きの新Issueを起こす | 修復所要時間・再発・未移管ACを振り返る |
| Risk-based verification | doc/軽微な整理は安価な確認で進める。承認・セキュリティ・データ損失・fail-open は追加の照合が要る | 残存リスクが不明なら Close せず Blocked/Decision required |
| Inspect & Adapt | ルールを試した結果と採否を記録し、効果がないルールを廃止・変更する | 月次に運用仮説を見直す |

「Fast Fail」は検証を省くことでも、成功を装うことでもない。「リバーシブル」は**Issue の状態変更**についてであり、過去に発生した安全上の危害や権限の越境を取り消せるという意味ではない。

## 3. 分類と処置

次の区分は **Triage の判断結果**であり、追加の kind / status ラベルではない。

| 判定 | 判断基準 | 処置 |
| --- | --- | --- |
| Completed | 受入基準 (AC) が現行実装・テスト・merge済みPR等で充足している | 根拠を書き、GitHub `completed` で Close |
| Duplicate | 問題と解決条件が同一で、代表 Issue に残ACを保持できる | 残AC移管 → 相互リンク → `duplicate` で Close（GitHubで使えなければ `not planned` と理由） |
| Superseded | 現行設計・別Issueに置換済み | 置換先・引継ぎ先を明記し `not planned` で Close |
| Not reproducible / Obsolete | 旧実装・旧環境でのみ発生、現在の継続リスクが低い | 限定した確認範囲と再発時の起票条件を残し `not planned` で Close |
| Out of scope | 現行方針・ロードマップから外れる | 判断理由・再検討条件を記録し `not planned` で Close |
| Actionable | 今も価値・未達AC・実装可能な次の一手がある | Open維持。最小スライス・受入条件・担当境界を明記 |
| Blocked / Decision required | 特定の操作に必須の先行条件・外部アクセス・Human決定が残る | Open維持。**停止すべき操作だけ**を特定し、AIが今できる調査・検証・PR準備、判断の推奨案・根拠・判断後の検証を記録。Issue全体は自動停止しない |

注意:
- **古い / チェックボックス未更新 / PR merge 済み**のいずれも単独では Close の証明にならない。
- 逆に、昔の不具合を無期限に調べ直さない。現在のコード・旧前提・関連PRを合理的な範囲で確認し、調査打切り理由を記録する。
- **security / data loss / approval・HO・C-3・C-4 bypass / fail-open / 下流配布**への現在の影響が疑われる場合は、単なる「古い・再現不能」で Close しない。まず継続リスク、代替防御、責務ownerを照合し、重要な判断は Human に残す。

## 4. 重複・関連・依存のリンク方針

| 関係 | 用途 | やること |
| --- | --- | --- |
| Duplicate | 同じ問題・同じ完了条件 | 代表を決め、閉じる側の未達AC・議論の参照を代表へ移す。双方にリンクを残す |
| Parent / Sub-issue | 1つの成果を独立した実装スライスに分ける | GitHub の Sub-issue 機能を優先。不可なら双方向の親子参照 |
| Blocked by / Blocking | 先行作業の完了が**必須** | GitHub の Dependency 機能を優先。不可なら両側に依存理由・解除条件を書く |
| Related | 一緒に考えると漏れを防げるが必須の順序制約はない | 双方向にリンクし「何を合わせて確認するか」を1行で記す |

類似タイトルだけで統合しない。**目的、残AC、所有者、独立にCloseできるか**を比較する。Parentや関連であるだけのIssueは重複扱いしない。

### PR と Close

[Issue Governance §9](./issue-governance.md#9-pr-と-issue-の連動) に従い、**全ACを満たすPR**だけ `closes #N` 等を記す。途中のPRは `Refs: #N` / `Part of #N` にする。merge後にACの残りを確認し、必要なら別Issueへ具体的に引き継ぐ。

## 5. 1バッチの実行とリカバリー

1. **Select**: 3〜5件を選び、確認日・`main` SHA・対象範囲を記録する。安全境界関連は別バッチにする。
2. **Observe**: Issue本文・コメント・PR・現行実装を読む。「観測」「推測」「判断」を分ける。検証対象が消えていれば無理に復元しない。
3. **Propose**: 分類、代表Issue、関連/依存、Close候補、リスク、必要な最小確認を示す。判断待ちの場合は**既決事項 / 今AIが進められる作業 / 停止する操作 / 推奨判断 / Evidence**を分ける。
4. **Review**: 別視点で **誤Close / ACの消失 / 誤った依存 / 現行境界の弱体化** をレビューする。重大な不確実性が残ればCloseしない。
5. **Apply**: 代表側への残AC移管とリンクを**先に**行う。その後に許可された範囲でコメント・ラベル・Close。**未充足AC・Human-owned判断は勝手に省略しない**。決定を待つ間は独立したread-only調査・検証・許可済みの他タスクを進める。
6. **Verify**: 変更したIssueを再取得し、リンク・Close reason・残AC・blocker・追跡先を確認。失敗時は再オープン/コメント訂正を優先する。
7. **Adapt**: 失敗、不要な手順、役立った確認を数行残し、次のバッチで1つ改善する。毎回の大規模制度変更はしない。

一括で大量に閉じず、**1バッチで品質を確かめてから次のバッチへ進む**。失敗を観測したら同じ型の変更を一時停止し、原因・影響範囲を調べてから再開する。

### Close コメント例

```markdown
Triage: <Completed | Duplicate | Superseded | Not reproducible | Out of scope>
Checked: <YYYY-MM-DD> / main <SHA> / scope <確認範囲>
Evidence: <PR・commit・test・現行仕様等へのリンク>
Decision: <この処置を選ぶ理由 / 未確認部分>
Follow-up: <代表Issue / 残ACの所有先 / 再発時に新規起票する条件。なければ none>
Recovery: <誤判定の場合はこのIssueをreopen、または現行事象を新Issueで起票>
```

このコメントは判断の追跡可能性を作るもので、テストやHuman承認の代用品ではない。

## 6. 2つの改善ループ（Triage × Process Evolution）

この仕組みは、Issue 自体の整理だけで終わらせず、**Issue を整理する運用も検証・改善する**。大規模な新ハーネスや新しい承認権限は作らず、既存 Issue / PR の証跡で回す。

### Loop A — Issue Triage（1バッチ = 初期仮説3〜5件）

```text
Select → Observe → Propose → Review → Apply → Verify
   ↑                                           │
   └───────── 次の候補 ←────────── 振り返り ──────┘
```

- **Input**: 今の main / Open Issue / 関連 PR、前バッチの既知リスク。
- **Output**: 各 Issue の判定・根拠・Close/維持状態・代表先・関連/依存・再発時の扱い、必要なら次の候補。
- **Fast feedback**: 反映直後に再取得して、**残ACの行方、リンクの双方向性、状態/理由、意図しない変更**を検査。
- **Stop & Recover**: 誤Close、未移管AC、重大リスクの見落とし、リンク先誤りが1つでも判明したら、**同型の一括変更を止める**。当該 Issue を reopen または説明コメントで訂正し、影響した同型Issueを確認してから次のバッチへ。
- **Timebox**: 最初から全件の詳細再現を目指さない。1バッチで証拠が足りない項目は「未確認」と分離して次へ。ただし重要リスクは情報不足を理由にCloseしない。

### Loop B — Process Evolution（試行2バッチごと＋月次）

```text
Loop A の事実 → Friction / Failure の観測
             → 改善仮説（1つ）
             → 最小の試行（次の1〜2バッチ）
             → Evidence / 副作用の確認
             → Keep / Adapt / Revert / Defer
             → Playbook 改訂 → 次の Loop A
```

- **Input**: バッチの判定ログ、誤判定、重複/依存見落とし、実行負荷、Human判断待ち。
- **Owner**: AI は集計・仮説・試行提案・文書PRを用意できる。**ガバナンスの変更・リスク受容・承認権限の変更は Human-owned**。Issue側の個別判断も現行の責務分界に従う。
- **1回の改善は1仮説**: 例「3〜5件で分類負荷が高いなら、まずPR merge 済み Issue だけを選ぶ」。採用前に既存ルールとの競合を確認する。
- **安価な反証**: 変更前/変更後の1〜2バッチで「どの判断が速く・正確になったか」を比較。改善したという感想だけで恒久化しない。
- **終了判断**:
  - **Keep**: 誤判定や残AC漏れを増やさず、確認負荷・見落としなどが改善 → 本書に反映。
  - **Adapt**: 改善の兆しはあるが副作用もある → 次の1仮説へ縮小。
  - **Revert**: 誤Close・見落とし・負荷悪化 → 元の手順に戻し理由を残す。
  - **Defer**: サンプルが不足 → 未検証として残す。採用済みと表現しない。

### 観測指標とガードレール（最初の2バッチはベースライン）

| 観測 | 記録単位 | 改善のシグナル |
| --- | --- | --- |
| Triage リードタイム / 確認時間 | バッチごと | 根拠品質を落とさず短縮できたか |
| 誤Close・reopen（同じ誤判定の訂正） | Issueとバッチ | 重大な誤判定ゼロ。発見したら停止・回復 |
| 代表Issueへの残AC移管漏れ | 統合ごと | ゼロを維持できたか |
| 関連/依存の未リンク・誤リンク | バッチごと | 次に着手した人の確認漏れが減ったか |
| PR merge 後の未クローズ完全達成Issue | 週次 | 意図したOpen維持と、単純なClose漏れを区別できたか |
| バッチ終了時のHuman判断待ち・未検証件数 | バッチごと | 判断を勝手に補完せず、阻害要因を見える化できたか |

**Close件数やOpen総数の減少を成功条件にしない**。初期の値は仮説であり、2バッチ後に記録負荷・効果を見て項目を削る/調整する。特に #1005 の **admission / commitment / WIP** と本書の **整理・Close** は別の責務であり、昇格やWIPを本書だけで決定しない。

### 改善サイクルの記録（既存Issueのコメントに残す）

新しい台帳を作らず、棚卸しの親 Issue（初回は [#1503](https://github.com/s977043/PlanGate/issues/1503)）に以下を追記する。進行中の個別判断の根拠は各 Issue 側を正本とする。

```markdown
### Triage batch <ID>（YYYY-MM-DD）
- Baseline: main <SHA> / 対象Issue: #A, #B, #C
- Decisions: completed N / duplicate N / superseded N / not planned N / kept N
- Verification: 再取得 <実施/未実施> / 残AC・リンク整合 <結果>
- Friction / Failure: <観測事実。なければ none>
- Recovery: <修復したこと。なければ none>

### Process experiment <ID>
- Observation: <繰り返し起きた問題>
- Hypothesis: <変更すれば改善するはずのこと>
- Change: <次のバッチで試す最小の変更>
- Evidence: <前後のバッチ・実績へのリンク>
- Decision: <Keep / Adapt / Revert / Defer>
- Next: <次バッチの行動とPlaybook改訂PR。未検証なら未検証>
```

### 最初の2バッチ（2026-10-10 実施・効果評価は保留）

**事実の正本**: [#1503 第三次棚卸しの実測記録](https://github.com/s977043/PlanGate/issues/1503#issuecomment-6088127351)。測定した`main`は `715a4a8a`。GitHub Open Issueを月別に重複なく数えると**108件**。

- **Batch A / merged PR起点**: #1507、#1519、#1524 を検討。**3件ともOpen維持**。#1507はPhase 3/4、#1519は元のC-4逸脱に対するHuman判断、#1524はFirefox/A11y/CSP/negativeケース等が残る。#1519は後続PR #1543のmergeを再取得し、事実を追記。
- **Batch B / 残AC・Issue本文の鮮度起点**: #1241、#1505、#1529を検討。**3件ともOpen維持**。#1241の古い「3ファイル」を現行「4ファイル＋配布ミラー等の依存」へ更新。#1241・#1529のareaラベルを補完。
- **追加整備**: #1093のareaラベルを補完。更新したIssueを再取得してstate/label/bodyを照合。
- **今回の結果**: Open **108 → 108**、誤Closeを増やさない。クローズ件数を成果指標としない。
- **学び**: PR merge済みのIssueを起点にすると残ACとHuman判断待ちが分かるが、必ずしもClose対象ではない。同じ判断をIssueコメントに再投稿せず、**新しい根拠・変更がある時だけ個別Issueを更新**する。
- **未計測**: 調査時間・比較バッチの難度・誤Closeを発見して回復するまでの時間。速度改善や分類精度向上を実証したとは主張しない。
- **次の1仮説（未検証）**: merged PR起点に限らず、**古くなった前提を含むIssueを各バッチ1件選ぶ**。関係先の見落としと再調査コストが減るかを比較する。Evidenceが得られるまでKeep/恒久化しない。

## 7. プレイブック自体の更新手順

1. **観測**: 何が困ったか（誤分類、過剰確認、見落とし、待ち時間）を実際のIssueで示す。
2. **仮説**: 変更を1つに絞り、検出すべき副作用と戻し方を先に決める。
3. **試行**: 直近の小バッチで比較し、Evidenceと判断を親Issueへ記録する。
4. **適応**: 採用が妥当なら本書を小さく改訂しPRでレビュー。悪化なら戻す。
5. **正本への反映**: ラベル・milestone・PR linkage等の規約そのものを変える場合は [issue-governance.md](./issue-governance.md) の変更として分離し、必要なHuman判断を得る。C-3/C-4、HO、merge権限には触れない。

| 日付 | 仮説・変更 | ステータス / 次に確かめること |
| --- | --- | --- |
| 2026-10-10 | 初版。Fast Fail / Quick Recovery、3〜5件の小バッチ、分類・Close・相互リンク | Trial: 2バッチで運用負荷と誤判定を観測 |
| 2026-10-10 | Loop A（棚卸し）と Loop B（運用改善）を分離。1仮説ずつ試行、Keep/Adapt/Revert/Defer | Proposed: 初回PR merge済み3件を小バッチで確認 |
| 2026-10-10 | 初回2バッチ計6件を実測し、古い前提1件を修正。重複した運用説明も削減 | 実行事実は#1503。効果の検証は保留（Defer）、次に前提が古いIssueを含むバッチを試す |

## 8. Non-goals

- Issue Close自動化、stale bot、新しいCI Gate・ラベル、GitHub Projects導入
- 過去すべてのIssueに強制再現実験や長大な証跡を課すこと
- 設計を置き換えた旧Issueを理由なくOpenに維持すること
- AIによるHuman承認・merge権限の代行
