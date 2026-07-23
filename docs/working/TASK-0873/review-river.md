# River Review（PR 作成前・2026-07-23）— TASK-0873

> レビュアー: river-review agent（code + security + testing 併用・R1/R2 敵対レビューの見落とし角度優先）
> 対象: branch `feat/task-0873-delivery` HEAD 5738859（15 ファイル +3164/-11）
> 実測: unit 51/51 PASS・ta-56 10/10 PASS・repo 非破壊確認・敵対入力実走
> 総合: **critical 0 / major 2 / minor 3 / info 1** — PR 作成可（F-1 は PR 前是正推奨）
> オーガナイザー裁定: F-1 は L272 の実装確認で CONFIRMED（採用・PR 前是正）

## Findings と disposition（採否はオーガナイザー裁定・2026-07-23）

| ID | sev | 内容 | disposition |
|----|-----|------|-------------|
| RV-1 | major | `delivery.py:272` — conclusion 語彙が open（`not in ("success","failure")` = pending）。cancelled / timed_out / action_required / startup_failure が恒久 WAITING_FOR_CHECKS に livelock（escalate せず round も進まない）。R1 の allowlist 化（mergeable/severity）から conclusion だけ漏れた非対称 | **採用・PR 前是正**: conclusion allowlist 導入 — `failure\|cancelled\|timed_out\|action_required\|startup_failure` → failed（taxonomy 経由）/ `success` → green / `pending\|queued\|in_progress\|neutral\|skipped` の扱いを doc §4 に定義 / **未知値 → HUMAN_ESCALATED**。負側テスト（cancelled → escalate or repair・未知値 → escalate）追加 |
| RV-2 | major | required checks の完全性が snapshot に束縛されず、check 登録ラグ中の部分 green（1 job のみ登録・全 success）が MERGE_READY に到達（善意でも起きる temporal completeness の穴。後段防衛 = C-4 Human + branch protection あり） | **部分採用**: Phase 1 は doc §4 に「supplier は required check 全登録を確認してから snapshot を切る」責務を明記。`required_checks[]` の機械束縛は **V2 候補として handoff に記録** |
| RV-3 | minor | contract emit の `priority_order` と実装評価順の乖離（taxonomy 検証不能が same_type_recurrence より先に実評価される — 安全側だが契約の予測が外れる。実測で確認済み） | **採用**: doc §3 + `PRIORITY_ORDER` に `taxonomy_unverifiable` を独立項目として same_type_recurrence より前に明記（実装に合わせる・安全側優先の設計判断と注記） |
| RV-4 | minor | `delivery.py:383-384` state_entry に `pr_number` が無く、同一 task 別 PR（同 head・同 reasons）で監査 record の dedup 欠落 | **採用**: `"pr_number": pr` を 1 フィールド追加 |
| RV-5 | minor | 禁止トークン走査が unit と ta-56 で同一 8 トークンリストを共有（同一盲点: os.popen / pty / 動的合成）。主防御は純関数設計のため実害確率低 | **follow-up**: handoff V2 候補（ta-56 に popen 追加 or AST import allowlist 化） |
| RV-6 | info | `_parse_kv` が値欠落時に次の `--flag` を値として飲む（bypass にはならない・診断性の問題） | **follow-up**: handoff V2 候補 |

## 指摘なしの検証済み観点（8 観点 PASS）

NO MERGE BY AI（TRANSITIONS["MERGE_READY"]=[]・merge API/subprocess 0 件）/ head SHA 束縛・stale 拒否 / 決定論・冪等（--now 注入・entry_id dedup・resume 差分ゼロ実走）/ #896 c3_contract 再利用（重複実装なし）/ ta-56 非破壊（#861 教訓遵守）/ record 改竄耐性 / plugin sync byte 一致 / doc↔contract byte 一致（RV-3 の意味論乖離のみ）

## 是正の実施先

RV-1〜RV-4 の是正は **TASK-0873 exec セッション**（`PLANGATE_HOOK_TASK=TASK-0873`・EH-1/EH-3 の TASK 文脈が必要）。是正 commit → targeted（test_delivery + ta-56）→ full regression → PR 作成の順。RV-5/RV-6 は handoff の V2 候補へ転記。
