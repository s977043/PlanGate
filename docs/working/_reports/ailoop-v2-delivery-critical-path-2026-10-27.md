# ai-loop v2 Delivery First Release — クリティカルパスと Human 判断材料（2026-10-27）

> 測定基準: `origin/main` = `7cf715c623602ece11ad0db43d5938664780963e`（2026-10-27 取得）。
> issue の状態は 2026-10-27 に `gh issue view` で取得した値。
> 本レポートは判断材料であって、承認・実行許可ではない。実装・plan 改訂・c3.json の発行はしていない。

## 結論

- **Delivery First Release は BLOCKED。** owner 実装（#1391 Phase 1B / #1392 モデル B / #1393 core）は 3 本とも main に入っていない。main にある `scripts/ai-loop-v2/*.py` は #1402 由来の暫定実装と fixture で、owner-backed E2E（#1395）の証拠にならない。
- **`limits.py` の循環依存は文書上成立している。** #1391 の exec は「`limits.py` が main にあること」を前提にしている。`limits.py` は #1393 の exec で作る。その #1393 の exec は「#1391 event contract consumable」を待っている。このままではどちらも着手できない。
- **C-3 の状態（記録上）**: TASK-1392 は現行 plan と承認記録の hash が一致する。TASK-1393 は Rev 2.7 が未承認で、TASK-1391 は C-3 を実施していない。
- **Human に最初に決めてほしいこと**は、循環をどの案で切るか（§3 の判断 H-1）。推奨は案 1（`limits.py` を先行して独立 PR にする）だが、決めるのは Human。

## 1. 現在地（issue の状態）

| # | 状態 | 最終更新 (UTC) | 最新の要点 |
|---|---|---|---|
| #870 EPIC | OPEN | 2026-10-21 | Iteration 1 のレビュー: #1393 plan Rev 2.6 を C-3 APPROVED（`ec2a0db8…`）。その後 Rev 2.7 に改訂されたので、現在は再承認待ち（§2） |
| #1391 RunEvent / RunEvidence | OPEN | 2026-10-09 | 最後のコメントは #1047 の棚卸し。plan は Phase 1B 差分計画 Rev 2.4（TASK-1391/plan.md）で、C-3 待ち |
| #1392 RunState CAS | OPEN | 2026-10-09 | 最後のコメントは #1047 の棚卸し。一度は 2026-09-29 に #1402 の `Closes` で CLOSED になっていた（TASK-1392 INDEX「2026-09-29 追記」）が、現在は OPEN |
| #1393 Decision core | OPEN | 2026-10-07 | 2026-10-08 の依存再確認: `ratchet.py` が provisional な `decision_core` を import している点が未解消 |
| #1422 Decision Input Binding | OPEN | 2026-10-21 | Human 裁定（2026-10-21）: B-1〜B-6・B-9〜B-12 は部分凍結。B-7 は B-9 に統合して廃止。B-8 / B-13 は #1391 plan（C-3）で決める gap として残る |
| #1395 owner-backed Delivery E2E | OPEN | 2026-10-07 | #1516 で `scope_observer.py` を導入。owner への移行はまだ |
| #1383 Delivery E2E Gate | OPEN | 2026-10-06 | 2026-09-29 に reopen。AC 15 件のうち 達成 9 / 一部 2 / 未達 4（AC-3・AC-7 が一部、AC-9・AC-11・AC-14・AC-15 が未達） |
| #1381 Ratchet vertical slice | OPEN | 2026-10-08 | AC-6 が未達。依存の連鎖は `#1422 → #1391 / #1392 → #1393 → #1395 → #1381` |
| #1376 Ratchet Traceability | OPEN | 2026-10-07 | Phase B として #1516 の scope observer を merge 済み |
| #869 Retrospective 駆動のハーネス改善 | OPEN | 2026-10-09 | 関連 issue の照合のみ。Evidence≠Judgment を維持 |
| #1329 canon の I1 例外 | OPEN | 2026-10-06 | V2 実行系の変更は semantic invalidation の候補になる。#1391 の exec 前提に「#1329 preflight の記録」がある |
| #1465 materializer の live-shadow | OPEN | 2026-10-08 | 実運用の live-shadow Evidence は 0 件。Delivery のクリティカルパスには入らない |
| #1468 R1 runtime attestation | OPEN | 2026-10-07 | 独立に運用される verifier の provenance が未証明。クリティカルパスには入らない |
| #1473 独立 runtime verifier の境界 | OPEN | 2026-10-08 | ADR-007 は `Proposed` / `NOT_MADE` で、Human Decision Record の 8 項目が `UNDECIDED`。クリティカルパスには入らない |

この範囲（#1391 / #1392 / #1393 / #1395 / #1422）に紐づく open PR は 0 件（`gh pr list --state open --search` で確認）。

## 2. C-3 状態表

c3.json は Git で追跡されていない（TASK-1392 INDEX: 承認に使った worktree に untracked で保管）。そのため下表の「承認記録」は **INDEX.md / status.md に書かれた記録上の値**であり、c3.json の実物ではない。**実行許可の根拠には使わない**。exec の前に Human が c3.json の実物と照合する必要がある。

| TASK | 現行 plan.md の sha256（origin/main で実測） | plan の最終 commit | 承認記録（記録上） | 一致 | 判定 |
|---|---|---|---|---|---|
| TASK-1391 | `d4f69f26a238d71d0a6339e7c5635ab701648cdea0d50d035319573af81acd5d` | `69387d32`（2026-10-22, Rev 2.4） | なし（status.md:9「`approvals/` が無い」/ :43「Human C-3」が未チェック） | — | **C-3 未実施** |
| TASK-1392 | `f02d69cf7c8b9b29991e48dc7280ea9d693588bde4bed48c0074607ed09699bb` | `d9211850`（#1606, 2026-10-23 00:21:41Z） | APPROVED 2026-10-23T00:19:01Z、`plan_hash` = `sha256:f02d69cf…`（INDEX.md:16） | **一致** | **記録上は有効** |
| TASK-1393 | `404c432a60157932cda967b4c3d90c77979c6d00df874a295828bfd8b0af35b3` | `742f63f6`（#1605, 2026-10-22, Rev 2.7） | 直近の APPROVED は Rev 2.6 の `ec2a0db8…`（2026-10-21T09:15:23Z, INDEX.md「現在のフェーズ」） | **不一致** | **Rev 2.7 は未承認**（Human による c3.json の再発行待ち） |

TASK-1392 の補足:

- 承認時刻（00:19:01Z）は #1606 の merge commit（00:21:41Z）より約 2.6 分早い。ただし hash が現行 plan と一致するので、承認したのは merge された内容と同じ plan と判断できる。INDEX.md:16 の「plan Rev は PR #1606 の merge 後の版」とも矛盾しない。
- INDEX.md:18（R-105〜R-108 追記）には「plan_hash が変わり C-3 の再承認が必要」と残っている。これは追記の順番による古い記述で、その再承認が :16 の承認にあたる。INDEX の鮮度を直すかどうかは別途判断してほしい（本 PR では触れていない）。
- 承認が有効でも、exec は BLOCKED のまま。blocker は #1391 が consumable でないこと・`limits.py` が main に無いこと・#1329 preflight が未通過であること（INDEX.md:16）。

## 3. `limits.py` の循環依存

### 3.1 一次ソース

| # | 出典（記号アンカー / 行） | 内容 |
|---|---|---|
| a | TASK-1391/plan.md「Current verdict」:9 | `Exec: BLOCKED until #1393 PF-5 agreement fixes MAX_* values + the module that defines them (D-6)` |
| b | TASK-1391/plan.md「P1B-7 decision_made」:180 | 「`MAX_INPUT_REFS` / `MAX_DECISION_EVENT_BYTES` を #1393 から import し、`validate_append` の append-only 層で再検査する。#1391 は値を定義しない」 |
| c | TASK-1391/status.md「#1393 PF-5 の合意」:24 | 「R-086（PF-5-2）: 定数は新設 `scripts/ai-loop-v2/limits.py`（葉 module、所有者 #1393）」 |
| d | TASK-1391/status.md「R-034 の前提の照合」:35 | 「ただし `limits.py` は main に未作成（#1393 の exec で作る）」 |
| e | TASK-1391/status.md「残タスク」:44 | 「exec 前提: #1329 preflight 記録 / reviewed_at_sha 記録 / `limits.py` が main にあること」 |
| f | TASK-1393/plan.md「APIs」内の **Limits module (R-086 / R-087)**:337 | 「defined in a new leaf module `scripts/ai-loop-v2/limits.py` (no imports from other ai-loop-v2 modules; owner #1393) … The file is created at exec, not in this plan revision.」 |
| g | TASK-1393/todo.md「Preflight」:35 | 「exec: `scripts/ai-loop-v2/limits.py`（葉 module）を作成し仮値を fixture 固定（R-086 / R-087）」 |
| h | TASK-1393/todo.md「Preflight」:30 | 「#1391 event contract consumable」（未チェック） |
| i | TASK-1393/plan.md「Preflight before exec」PF-2 / PF-3 / PF-7 / PF-8 | #1391 の event（`failure_recorded.verification_ref` / `pr_convergence_recorded.observed_artifact_ref` / 値域検査 / `plan_contract_bound`）が前提 |
| j | TASK-1393/INDEX.md「現在のフェーズ」 | 「blocker: exec 前依存（#1391 / #1392 / #1422 の owner 実装、PF-2〜PF-8）が未解消」 |
| k | TASK-1392/INDEX.md:16 | 「blocker: #1391 が consumable でない・`scripts/ai-loop-v2/limits.py` が main に無い・#1329 preflight が未通過」 |

### 3.2 判定: 循環は成立する

```text
#1391 exec ──requires──> limits.py on main            (e, b)
limits.py  ──created by─> #1393 exec                   (d, f, g)
#1393 exec ──requires──> #1391 event contract consumable (h, i, j)
#1392 exec ──requires──> #1391 consumable AND limits.py   (k)
```

`#1391 → limits.py → #1393 → #1391` で閉路になる。#1392 はこの閉路の下流にあり、どちらか一方が解けない限り着手できない。

循環が生まれた経緯: TASK-1383/dependency-matrix.md「Gate B」の DAG は `#1391 ─> #1393` の一方向だった。そこへ PF-5 の Human 決定（2026-10-22, R-086）で「#1393 所有・exec で作成」の定数 module を #1391 が import する形になり、逆向きの辺が加わった。決定のどれかが誤っていたわけではなく、**所有者と作成タイミングの組み合わせ**で閉路ができている。

なお `limits.py` は葉 module（他の ai-loop-v2 module を import しない。出典 f）なので、**コードの import 上は循環しない**。循環しているのは exec の順序の前提だけで、所有者は変えずに作成のタイミングを切り出せば解ける。

### 3.3 解消案の比較

| 案 | 内容 | 必要な手続き | 利点 | 欠点 / リスク |
|---|---|---|---|---|
| **案 1** `limits.py` だけを先に独立 PR にする（所有者は #1393 のまま） | 仮値（256 / 16 / 256、バイト上限は算出値の切上げ）と DI-46 相当の fixture テストだけを入れる | スコープ変更（Human 判断）。TASK-1393 の exec 範囲の一部を前倒しすることになるので、**TASK-1393 の re-C3 が要るかどうか**を Human が決める。HO パスには当たらないが、V2 実行系の変更なので #1329 の semantic invalidation 候補になる | 所有境界（D-3 / R-086）を変えない。#1391・#1392 の plan を改訂せずに閉路が解ける。葉 module なので差分は小さく、ロールバックも容易 | Rev 2.7 は未承認のまま。どの plan の承認でこの PR を作るのかを明示する必要がある（候補: Rev 2.7 を再承認してから、その exec の最初の 1 commit として出す）。仮値が後で変わると #1391 / #1392 の fixture も追従が要る |
| **案 2** #1391 の plan から `limits.py` 依存を外す | #1391 は MAX_* の再検査を exec 範囲から外す、または定数を注入可能にする（後で `limits.py` に配線する） | TASK-1391 plan の改訂 → 簡易 C-1 → C-3。#1391 は**まだ C-3 を実施していない**ので、再承認のやり直しは発生しない | 改訂コストが低い。#1391 を先に consumable にできる | D-3 / D-6（Human 決定 2026-10-22）を弱める。append 時の上限検査が後回しになり、その間の残存脅威（上限の無い event が accept される）を明記する必要がある。後で配線する作業が増え、#1392 の terminal reserve の保証（「`limits.py` が main にあり reserve fixture がそこから導出されてから主張」）も遅れる |
| **案 3** `limits.py` の所有者を中立にする（例: #1391 または共有の葉 module に移す） | 所有者と作成タイミングを #1391 の exec 側に移す | PF-5-2（R-086）の Human 決定を変更する。TASK-1391 / TASK-1393 の両方の plan を改訂し、TASK-1393 は re-C3（TASK-1392 も plan に出典を書いているので影響を確認する） | 閉路が構造ごとなくなる | 決定済みの所有境界を動かすので手続きが最も重い。TASK-1392 の承認済み plan の記述（出典 = `limits.py`、owner #1393）に波及する可能性がある |
| 案 4（参考）#1391 と #1393 を 1 PR で同時に exec | 2 本の exec を統合する | 両方の C-3 と、統合レビュー | 順序の問題が消える | high-risk 同士を束ねるので、レビュー単位が巨大になる。§7-quater のラウンド設計が重くなる。推奨しない |

**推奨（Human が選ぶ前提）: 案 1。** 理由（判断基準の優先順: 要件適合 → 安全性 → 保守性 → コスト）:

1. 要件適合: Human 決定 D-3 / D-6 / R-086 を一つも弱めない。
2. 安全性: #1391 の append 時の上限検査を先送りしないので、案 2 の残存脅威が生まれない。
3. コスト: 変更は葉 module 1 つと fixture だけ。承認済みの TASK-1392 plan にも影響しない。

案 1 を選ぶ場合に Human が決めること: (a) TASK-1393 Rev 2.7 を先に再承認して「exec の最初の 1 commit」として出すか、(b) `limits.py` だけを別 PBI として C-3 にかけるか（H-2）。

## 4. main にある `scripts/ai-loop-v2/*.py` の分類（#1402 由来の暫定実装）

| ファイル | 行数 | 分類 | 根拠（引用） |
|---|---|---|---|
| `run_state.py` | 251 | **暫定 / fixture-only / 削除予定** | ファイル冒頭のコメント:11「暫定実装（#1402 由来・fixture 専用）。R-023 により RunState の永続化は #1392 が持つ。#1392（model B）への移行後に本ファイルと専用テストを削除する（Human 決定 2）」。dependency-reconciliation.md:13「temporary **fixture-only** implementation; Human R-023」 |
| `decision_core.py` | 235 | **暫定 / 移行予定**（#1393 の core に置き換える） | dependency-reconciliation.md:14「`decision_core.py` from #1402 (**provisional**; not approved owner core)」。TASK-1393/plan.md PF-1「#1393 is rebuilt from this plan and replaces the #1402 `decision_core`」 |
| `run_event.py` | 318 | **暫定**（#1391 Phase 1A の初期実装。Phase 1B の差分を当てる対象） | dependency-reconciliation.md:12「`run_event.py`, `run_evidence.py` (provisional)」。TASK-1391/plan.md「Current verdict」「Phase 1A (initial implementation): MERGED via #1402」 |
| `run_evidence.py` | 80 | **暫定**（同上） | 同上 |
| `delivery_runtime.py` | 262 | **暫定 / fixture-only / 移行予定**（#1395 で #1392・#1393 へ移す） | `run_spec_fixture`:73-75「only non-authoritative spec fixtures are accepted」。dependency-reconciliation.md:15「`delivery_runtime.py` / TA-93 consume provisional state/Decision」。#1383 reopen コメント「`run_state.py` から #1392 API への delivery の書き換えは #1395」 |
| `ratchet.py` | 851 | **不明**（ファイル全体の位置づけは一次ソースに記載が無い）。一部は暫定 | 決まっているのは部分だけ: `simulate_completion`（:146）は「must remain explicitly non-authoritative until owner integration」（dependency-reconciliation.md:89）。provisional な `decision_core` からの `DecisionError` / `decide` の import は #1393 PF-1 で移行予定（todo「caller migration」）。ファイル全体を正式採用とする記録は見つからなかった |
| `scope_observer.py` | 231 | **不明**（正式採用に近いが、owner による採用記録は無い） | dependency-reconciliation.md:21「Scope observation is now in `scripts/ai-loop-v2/scope_observer.py` and can be consumed by #1395 **after its own artifact/source binding review**」。#1395 / #1376 のコメントによれば #1516 で merge 済み。一方、binding のレビューは未実施 |
| shadow-only | — | 該当なし | 上の 7 ファイルに shadow-only と書かれたものは無い（canon の shadow は PBI materialization の文脈。artifact-responsibilities.md「Shadow evaluation / write authority boundary」） |

**暫定実装のテスト PASS は owner-backed E2E の証拠にならない。** TA-87 は non-authoritative な executable specification（#1383 reopen コメント「`ta-87:3-6`」）で、TA-93 の入力は non-authoritative な fixture だけ（`delivery_runtime.py:74-75`）。`test_delivery_v2.py` / `test_ratchet.py` / TA-92 / TA-93 が PASS しても、#1383 AC-11（owner contract を consume して再実装しない）・#1381 AC-6（simulation 不可）は満たされない。

## 5. クリティカルパス（再構成）

```text
H-1 循環の解消方式（Human）
  │
  ├─(案1)→ limits.py 先行 PR ──────────────┐
  │                                         │
TASK-1391 C-3 (Human) ── #1329 preflight ──> #1391 Phase 1B exec ──┐  (B-8 / B-13 の語彙を確定)
                                            │                       │
TASK-1393 Rev2.7 re-C3 (Human) ─────────────┴──> #1393 core exec <──┘
                                                    │  (PF-1: decision_core / ratchet / delivery_runtime の caller 移行)
TASK-1392 (C-3 記録上有効) ── limits.py + #1391 ──> #1392 model B exec
                                                    │
                     #1392 + #1393 consumable ──> #1395 owner-backed E2E（run_state.py を削除、TA-87 を実走）
                                                    │
                     #1383 evidence（AC-11/14/15）──> #870 へ evidence ──> #1381 AC-6 の解除判定
```

| ノード | blocker | owner | unblock_condition |
|---|---|---|---|
| H-1 循環の解消 | §3 の閉路 | Human | 案 1〜3 のいずれかを選ぶ |
| `limits.py`（案 1 の場合） | H-1、H-2（どの承認で作るか） | #1393 担当 + Human | 選んだ承認経路の C-3 を通ったうえで PR を merge（merge は Human） |
| TASK-1391 C-3 | Human がまだ承認していない | Human | c3.json の発行（`d4f69f26…` に対して） |
| #1391 Phase 1B exec | C-3 / #1329 preflight / reviewed_at_sha / `limits.py` が main にあること | #1391 担当 | TASK-1391/status.md:44 の前提をすべて満たす |
| TASK-1393 re-C3 | Rev 2.7 が未承認 | Human | `404c432a…` に対する c3.json の発行 |
| #1393 core exec | #1391 consumable / PF-2〜PF-4・PF-6〜PF-8 / #1392 の入力形状の凍結 / #1395 の budget | #1393 担当 | todo「Preflight」の未チェック項目がすべて解消 |
| #1392 model B exec | #1391 consumable / `limits.py` / #1329 preflight | #1392 担当 | todo「Preflight」の条件（INDEX.md:16） |
| #1422 B-8 / B-13 | 未凍結の gap | #1391 plan（C-3） | TASK-1391 の C-3 で語彙と形状が決まる |
| #1395 owner-backed E2E | #1392 + #1393 が consumable でない | #1395 担当 | owner API への移行と、I3 以上の独立した evidence |
| #1383 / #870 / #1381 | #1395 | Human（解除判定） | AC-11 / AC-14 / AC-15 の evidence がそろう |

クリティカルパス外（並行して進めてよい / Delivery の判定には使わない）: #1465 / #1468 / #1473 / #869 / #1376。

## 6. Human 判断事項

| ID | 問い | 選択肢 | 推奨 | 影響 |
|---|---|---|---|---|
| H-1 | `limits.py` の循環をどう解くか | 1 = 先行の独立 PR（所有者 #1393）/ 2 = #1391 plan から依存を外す / 3 = 所有者を移す / 4 = 同時 exec | **1** | 1 は所有境界を変えない。2 は D-3 / D-6 を弱める。3 は R-086 を変更し、TASK-1392 にも波及しうる |
| H-2 | （H-1 = 1 の場合）`limits.py` をどの承認で作るか | a = TASK-1393 Rev 2.7 を re-C3 し、その exec の最初の commit とする / b = `limits.py` 単独の PBI を C-3 にかける | **a** | a は承認を 1 回で済ませられる。b は小さいが PBI が増える |
| H-3 | TASK-1393 Rev 2.7（`404c432a…`）を承認するか | y / n | 判断材料: C-1 は PASS（review-self.md C1-PLAN-03〜05） | 承認しなければ H-2 = a は取れない |
| H-4 | TASK-1391 Rev 2.4（`d4f69f26…`）を C-3 にかけるか | y / n | — | B-8 / B-13 の gap は TASK-1391 の C-3 でしか閉じない |
| H-5 | TASK-1392 の c3.json の実物が `f02d69cf…` か照合するか | y（Human が承認に使った worktree を確認する）/ n | **y** | 記録上は一致している。exec 前の確認として必要 |
| H-6 | `ratchet.py` / `scope_observer.py` の位置づけ（§4 で「不明」とした 2 つ） | 1 = 正式採用 / 2 = 暫定（移行・レビュー対象）/ 3 = 保留 | — | #1395 で consume するときの扱いが決まる |
| H-7 | TASK-1392 INDEX.md:18 の古い記述（再承認が必要）を直すか | y / n | y | INDEX の鮮度契約（L0 の誤読を防ぐ） |

## 7. Delivery First Release の判定

**BLOCKED。**

north-star.md「Delivery V2 first release」が求めるもの: `Request → … → Verify FAIL → Diagnose → Repair → Verify PASS → PR → Review finding → Repair → MERGE_READY` と、`NO_PROGRESS → safe stop / escalation` を E2E で実証すること。

| 根拠 | 状態 |
|---|---|
| owner 実装（#1391 Phase 1B / #1392 model B / #1393 core） | 3 本とも main に無い。C-3 は 1 本（TASK-1392、記録上）だけ |
| owner-backed E2E（#1395） | 未着手。main の runtime は暫定実装と non-authoritative な fixture |
| #1383 AC | 未達 4（AC-9 無限 retry しない / AC-11 owner contract の consume / AC-14 / AC-15）、一部 2（AC-3 / AC-7）。2026-09-29 の測定値で、その後これらを満たす owner 実装は merge されていない |
| `limits.py` の循環 | 未解消（H-1） |

不足している Evidence:

- owner-backed の Run で `Verify FAIL → Repair → Verify PASS → MERGE_READY` を通した evidence（fixture ではない）
- `NO_PROGRESS` / budget 超過で停止した evidence（AC-7 / AC-9）
- #1395 の exact-head での独立した I3 / I4 レビュー（TASK-1393 todo「Handoff」）
- #870 に返す evidence bundle と、#1381 の解除判定（AC-14 / AC-15）

## 付記: 依頼文と一次ソースの食い違い

- 依頼文の「#1391 plan R-086」について: TASK-1391/plan.md には `limits.py` も R-086 も出てこない。plan にあるのは D-3 / D-6 と :180 の「#1393 から import」だけで、`limits.py` という名前と R-086 は TASK-1391/status.md:24 と review-external.md:306 にある。本レポートでは両方を引用した。
- 依頼文の「TASK-1392 の APPROVED は PR #1606 merge 後の plan に対するもの」について: hash は現行 plan と一致した。ただし承認時刻は merge commit の約 2.6 分前（§2）。
- TASK-1393/todo.md:27「Revision 2.6 に対する c3.json を Human が再発行」が未チェックのままになっている。INDEX.md によれば Rev 2.6 は 2026-10-21 に APPROVED なので、todo の更新漏れとみられる（本 PR では触れていない）。
