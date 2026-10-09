# Issue Triage Living Playbook

> **Status**: Living / v0.1（運用仮説。完成版ではない）
> **Owner**: Maintainer / Governance
> **Started**: 2026-10-10
> **Review cadence**: 運用中の随時改善 + 月次レビュー（週次の軽量Triageは試行）
> **Related**: [Issue Governance](./issue-governance.md) / [棚卸し #1503](https://github.com/s977043/PlanGate/issues/1503)

## 1. 目的と正本の境界

Open Issue を「過去に発見したことの保管庫」ではなく「現在、何を判断・実行するかが分かるバックログ」に保つ。過去の証跡は GitHub の Closed Issue / PR に残るため、不要な Open 状態を保存しない。

この文書は **変化する運用合意（Living Playbook）**。実行中の観測により改訂するもので、別の固定ガバナンスや自動 Gate を新設するものではない。

- **固定側の正本**: [issue-governance.md](./issue-governance.md) が Issue 必須項目、kind / area / priority / status、Milestone、PR linkage を管理する。本書でラベル体系を二重定義しない。
- **事実の正本**: 現在の `main`、GitHub Issue、PR、関連するテストと実行ログ。棚卸しレポートと [#1503](https://github.com/s977043/PlanGate/issues/1503) は測定時点のスナップショットであり、現在値とは限らない。
- **権限の境界**: C-3 / C-4、Hardening Override (HO)、Human-owned decision、merge の責務を変更しない。AI の分類は候補であり、検証・承認の代替ではない。
- **原則**: 余分なラベル、bot、CI、完璧な初期分類を増やすより、既存の GitHub 機能と小さな実地検証を優先する。

## 2. Agile / Fast Fail & Quick Recovery

**完璧な一括棚卸しより、小さな変更を速く試し、誤りを早く見つけて直す**。

| 原則 | 今回の運用への適用 | フィードバック |
| --- | --- | --- |
| Small batch / fast feedback | 最初は **3〜5件**を1バッチとして分類 → コメント/リンク → Close → 照合。慣れたら件数を調整 | バッチ終了時に判断・誤分類・残ACを確認 |
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
| Blocked / Decision required | 必須の先行条件・外部アクセス・Human決定が残る | Open維持。blocker・解除条件・次の担当を明記 |

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
3. **Propose**: 分類、代表Issue、関連/依存、Close候補、リスク、必要な最小確認を示す。
4. **Review**: 別視点で **誤Close / ACの消失 / 誤った依存 / 現行境界の弱体化** をレビューする。重大な不確実性が残ればCloseしない。
5. **Apply**: 代表側への残AC移管とリンクを**先に**行う。その後にコメント・ラベル・Close。小さい単位で反映する。
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

## 6. 振り返りとドキュメントの進化

- **バッチごと（約2分の見直し）**: 誤分類/残AC/リンク漏れがあったか。確認が重すぎたか。次に**変更する運用ルールは1つだけ**。
- **月次**: #1503 等の集計を参照し、観測件数・測定SHA・未決事項・採用/見送りをレビューする。週次Triageの負荷と価値も見直す。
- **改善の提案形式**: `Observation → Hypothesis → Smallest useful experiment → Evidence → Decision → Adapt`。成功/失敗どちらも残し、**有効性を確認できない改善を恒久ルール化しない**。
- **軽量な指標（必要時のみ）**: Close漏れ件数、誤Closeから復旧までの時間、統合後の残AC漏れ、着手時の依存見落とし、Triageの所要時間。**Close件数・Open数の減少だけを最適化しない**。
- **記録場所**: 個別の判断はIssueコメント、棚卸し結果はその棚卸しIssue、恒常化した運用改善だけ本書へ。別のデータ正本を作らない。

### このプレイブックの改訂方法

1. 運用から具体的な不便・事故・過剰な検証を見つけ、関連IssueやPRに観測を残す。
2. 小さな修正を本書にPRで提案し、対象の試行バッチと判定条件を明記する。
3. 試して、成果と副作用を振り返る。不要なら戻す。変更履歴は下表に短く残す。
4. ラベル・milestone・PR linkageなど**規約そのもの**の変更が必要なら、[issue-governance.md](./issue-governance.md) を別途改訂する。HO / Human authorityを本書の更新で上書きしない。

| 日付 | 仮説・変更 | 次に確かめること |
| --- | --- | --- |
| 2026-10-10 | 初版。3〜5件バッチ、Fast Fail / Quick Recovery、分類・相互リンク・Close証跡を運用仮説として設定 | バッチ当たりの確認負荷、誤Close、未移管AC、関連の張り忘れ |

## 7. Non-goals

- Issue Close自動化、stale bot、新しいCI Gate・ラベル、GitHub Projects導入
- 過去すべてのIssueに強制再現実験や長大な証跡を課すこと
- 設計を置き換えた旧Issueを理由なくOpenに維持すること
- AIによるHuman承認・merge権限の代行
