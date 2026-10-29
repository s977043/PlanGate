# ai-loop v2 Delivery First Release — クリティカルパスと Human 判断材料（2026-10-27）

> 初版の測定基準: `origin/main` = `7cf715c623602ece11ad0db43d5938664780963e`（2026-10-27 取得）。
> **更新（2026-10-30）**: `origin/main` = `46685615dcb396b1048443136e6dca6a468b44c1`（#1619 / #1622 merge 後）に合わせて §結論・§1・§2・§3・§4・§5・§6・§7 を更新した。更新箇所には「（2026-10-30 更新）」と書く。§3.1 の出典表と §3.3 の案の比較は 2026-10-27 時点の分析として残し、現状との差を §3 冒頭に注記した。
> issue の状態は 2026-10-27 に `gh issue view` で取得した値（#1391 / #1393 は 2026-10-30 に再確認し、いずれも OPEN・更新日時は変わらず）。
> 本レポートは判断材料であって、承認・実行許可ではない。実装・plan 改訂・c3.json の発行はしていない。

## 結論

- **Delivery First Release は BLOCKED（2026-10-30 更新後も変わらない）。** owner 実装（#1391 Phase 1B / #1392 モデル B / #1393 core）は 3 本とも main に入っていない。main にある `scripts/ai-loop-v2/*.py` のうち、`limits.py` と `test_limits.py` は #1622 で入った owner 側の成果だが、それ以外は #1402 由来の暫定実装と fixture で、owner-backed E2E（#1395）の証拠にならない。
- **`limits.py` の循環依存（2026-10-30 更新）: 件数・文字数の 3 定数は main に入り、初版で挙げた閉路は解けた。** #1622（merge 2026-10-29T16:19:12Z）が TASK-1393 plan Rev 2.9 の C-3 APPROVED（2026-10-29T07:44:37Z）のもとで `limits.py`（`MAX_INPUT_REFS = 256` / `MAX_REQUIRED_VERIFIERS = 16` / `MAX_REF_CHARS = 71`）を入れた。**byte 系 3 定数（`MAX_DECISION_EVENT_BYTES` / `DECISION_FIXED_OVERHEAD` / `ENVELOPE_OVERHEAD`）は Human 決定（2026-10-29、R-091）で #1623 へ移管**され、main にはまだ無い。TASK-1391 plan:181 は `MAX_DECISION_EVENT_BYTES` の import を前提にしているので、byte 系が #1391 の exec 前提にどう効くかは一次ソースでは確定できない（§3.4）。
- **C-3 の状態（2026-10-30 更新）**: TASK-1393 は Rev 2.10 が 2026-10-29T10:09:18Z に APPROVED、TASK-1391 は 10:09:24Z に APPROVED（オーガナイザーが c3.json の plan_hash を照合して確認した値。c3.json は untracked で repo に無いので、本レポートはその報告をそのまま記録する）。TASK-1392 は現行 plan と承認記録（2026-10-23）の hash が一致するまま。3 本とも exec は他の前提（#1391 consumable / #1329 preflight ほか）で BLOCKED のまま。
- **Human に最初に決めてほしいこと（2026-10-30 更新）**: 初版の H-1（循環の解消方式）は #1622 の実績で決着した。残る判断は H-5〜H-9（§6）。#1623（byte 系）をクリティカルパスのどこに置くかは H-10 として新設した。

## 1. 現在地（issue の状態）

| # | 状態 | 最終更新 (UTC) | 最新の要点 |
|---|---|---|---|
| #870 EPIC | OPEN | 2026-10-21 | Iteration 1 のレビュー: #1393 plan Rev 2.6 を C-3 APPROVED（`ec2a0db8…`）。その後 Rev 2.7〜2.10 に改訂され、2026-10-30 更新時点の最新は Rev 2.10（2026-10-29T10:09:18Z に APPROVED、§2） |
| #1391 RunEvent / RunEvidence | OPEN | 2026-10-09 | 最後のコメントは #1047 の棚卸し。plan は Phase 1B 差分計画 Rev 2.4（TASK-1391/plan.md。D-15 / R-065 を反映済み）で、2026-10-29T10:09:24Z に C-3 APPROVED（2026-10-30 更新、§2） |
| #1392 RunState CAS | OPEN | 2026-10-09 | 最後のコメントは #1047 の棚卸し。一度は 2026-09-29 に #1402 の `Closes` で CLOSED になっていた（TASK-1392 INDEX「2026-09-29 追記」）が、現在は OPEN |
| #1393 Decision core | OPEN | 2026-10-07 | 2026-10-08 の依存再確認: `ratchet.py` が provisional な `decision_core` を import している点が未解消 |
| #1623 limits.py の byte 系 3 定数と I-11 byte 検査（2026-10-30 追加） | OPEN | 2026-10-29 | TASK-1393 R-091 の follow-up。前提は V2 `decision_made` の payload / envelope 構造が #1391 / #1406 で確定していること。#1391 plan:181 が import する `MAX_DECISION_EVENT_BYTES` の供給元（§3.4） |
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

この範囲（#1391 / #1392 / #1393 / #1395 / #1422）に紐づく open PR は 0 件（`gh pr list --state open --search` で確認）。2026-10-30 更新: open PR は #1621 / #1617（本レポート）/ #1612 / #1611 の 4 件で、いずれもこの範囲の実装ではない（`gh pr list --state open` の title / ブランチ名で判断。本文までは読んでいない）。範囲内の merge 済みは #1619（plan Rev 2.8）と #1622（`limits.py`）。

## 2. C-3 状態表

c3.json は Git で追跡されていない（TASK-1392 INDEX: 承認に使った worktree に untracked で保管）。そのため下表の「承認記録」は **INDEX.md / status.md に書かれた記録上の値**であり、c3.json の実物ではない。**実行許可の根拠には使わない**。exec の前に Human が c3.json の実物と照合する必要がある。

| TASK | 現行 plan.md の sha256（origin/main で実測） | plan の最終 commit | 承認記録（記録上） | 一致 | 判定 |
|---|---|---|---|---|---|
| TASK-1391（2026-10-30 更新） | `d46411248590749d3d5c3a1f88901c3a3be6ad517beb71e4e9df15ab00d16b15`（`origin/main` `46685615` で実測。初版の `d4f69f26…` は #1619 の D-15 / R-065 反映前の値） | `62b9a5df`（#1619, 2026-10-30 JST。plan 見出しは Rev 2.4 のまま） | APPROVED 2026-10-29T10:09:24Z（オーガナイザーが c3.json の plan_hash を照合して報告。c3.json は untracked で、本 PR からは直接確認していない） | 一致（報告による） | **記録上は有効**。TASK-1391/status.md:9 / :43 と plan「Current verdict」の「C-3 待ち」は未更新で、この記録と食い違う |
| TASK-1392 | `f02d69cf7c8b9b29991e48dc7280ea9d693588bde4bed48c0074607ed09699bb`（2026-10-30 に再実測、初版と同値） | `d9211850`（#1606, 2026-10-23 00:21:41Z） | APPROVED 2026-10-23T00:19:01Z、`plan_hash` = `sha256:f02d69cf…`（INDEX.md:16） | **一致** | **記録上は有効** |
| TASK-1393（2026-10-30 更新） | `ed637f48bdf91d7cd5cb38d9f4b988f2ba2ad800a0767e18bd87539130e0d668`（Rev 2.10。初版の `404c432a…` は Rev 2.7） | `62b9a5df`（#1619, 2026-10-30 JST, Rev 2.10） | APPROVED 2026-10-29T10:09:18Z（Rev 2.10。オーガナイザー照合の報告）。履歴: Rev 2.6 は 2026-10-21T09:15:23Z、Rev 2.9 は 2026-10-29T07:44:37Z（#1622 本文） | 一致（報告による） | **記録上は有効**。TASK-1393/INDEX.md の「現在のフェーズ: C-3 待ち」（Rev 2.7）は未更新 |

TASK-1392 の補足:

- 承認時刻（00:19:01Z）は #1606 の merge commit（00:21:41Z）より約 2.6 分早い。ただし hash が現行 plan と一致するので、承認したのは merge された内容と同じ plan と判断できる。INDEX.md:16 の「plan Rev は PR #1606 の merge 後の版」とも矛盾しない。
- INDEX.md:18（R-105〜R-108 追記）には「plan_hash が変わり C-3 の再承認が必要」と残っている（2026-10-30 に再確認、変更なし）。これは追記の順番による古い記述で、その再承認が :16 の承認にあたる。INDEX の鮮度を直すかどうかは別途判断してほしい（本 PR では触れていない。H-7）。
- 承認が有効でも、exec は BLOCKED のまま。blocker は #1391 が consumable でないこと・`limits.py` が main に無いこと・#1329 preflight が未通過であること（INDEX.md:16）。2026-10-30 更新: このうち「`limits.py` が main に無い」は #1622 で件数・文字数の 3 定数について解消した。ただし TASK-1392 plan:293 が参照する terminal reserve の `MAX_DECISION_EVENT_BYTES` は byte 系で、#1623 に移管された。INDEX.md:16 の blocker 記述は未更新。

## 3. `limits.py` の循環依存

> **2026-10-30 更新（先に読むこと）**: §3.1〜§3.3 は 2026-10-27 時点の分析である。その後、(1) #1619（merge 2026-10-29T15:58:15Z）で TASK-1393 plan が Rev 2.8 になり、Rev 2.9 / 2.10 が続いた。(2) #1622（merge 2026-10-29T16:19:12Z）が TASK-1393 の exec 第 1 歩として `limits.py` に件数・文字数の 3 定数だけを入れた。(3) byte 系 3 定数は Human 決定（2026-10-29、R-091）で #1623 に移管された。以下の行番号は 2026-10-27 時点の値で、TASK-1393 plan / todo は改訂で行がずれている（例: Limits module は plan:337 → :343、`limits.py` の todo は :35 のまま、`#1391 consumable` は :30 のまま）。現状の扱いは §3.4。

### 3.1 一次ソース

| # | 出典（記号アンカー / 行） | 内容 |
|---|---|---|
| a | TASK-1391/plan.md「Current verdict」:9 | `Exec: BLOCKED until #1393 PF-5 agreement fixes MAX_* values + the module that defines them (D-6)`。**この条件は充足済み**: PF-5 は 2026-10-22 に合意（TASK-1393/todo.md:33 が `[x]`、TASK-1391/status.md:37「D-6 の exec BLOCKED 条件のうち『PF-5 合意』と『module 位置』は満たされた」）。plan:9 自体は「`limits.py` が main にあること」を要求していない |
| b | TASK-1391/plan.md「P1B-7 decision_made」:180 | 「`MAX_INPUT_REFS` / `MAX_DECISION_EVENT_BYTES` を #1393 から import し、`validate_append` の append-only 層で再検査する。#1391 は値を定義しない」 |
| c | TASK-1391/status.md「#1393 PF-5 の合意」:24 | 「R-086（PF-5-2）: 定数は新設 `scripts/ai-loop-v2/limits.py`（葉 module、所有者 #1393）」 |
| d | TASK-1391/status.md「R-034 の前提の照合」:35 | 「ただし `limits.py` は main に未作成（#1393 の exec で作る）」 |
| e | TASK-1391/status.md「残タスク」:44 | 「exec 前提: #1329 preflight 記録 / reviewed_at_sha 記録 / `limits.py` が main にあること」。**「`limits.py` が main にあること」を明記する一次ソースはこの行だけ**。status.md は C-3 の承認対象（plan_hash）に入らない |
| f | TASK-1393/plan.md「APIs」内の **Limits module (R-086 / R-087)**:337 | 「defined in a new leaf module `scripts/ai-loop-v2/limits.py` (no imports from other ai-loop-v2 modules; owner #1393) … The file is created at exec, not in this plan revision.」 |
| g | TASK-1393/todo.md「Preflight」:35 | 「exec: `scripts/ai-loop-v2/limits.py`（葉 module）を作成し仮値を fixture 固定（R-086 / R-087）」。「exec:」の接頭辞はあるが、置き場所は「RED/GREEN」節ではなく「Preflight」節のチェックボックス |
| h | TASK-1393/todo.md「Preflight」:30 | 「#1391 event contract consumable」（未チェック）。:35 と同じ「Preflight」節にあり、節内の順序（前提か並列か）は明記されていない |
| i | TASK-1393/plan.md「Preflight before exec」PF-2 / PF-3 / PF-7 / PF-8 | #1391 の event（`failure_recorded.verification_ref` / `pr_convergence_recorded.observed_artifact_ref` / 値域検査 / `plan_contract_bound`）が前提 |
| j | TASK-1393/INDEX.md「現在のフェーズ」 | 「blocker: exec 前依存（#1391 / #1392 / #1422 の owner 実装、PF-2〜PF-8）が未解消」 |
| k | TASK-1392/INDEX.md:16 | 「blocker: #1391 が consumable でない・`scripts/ai-loop-v2/limits.py` が main に無い・#1329 preflight が未通過」 |

### 3.2 判定: 循環は条件付きで成立する

```text
#1391 exec ──requires──> limits.py on main            (e。b は含意のみ)
limits.py  ──created by─> #1393 exec                   (d, f, g)
#1393 exec ──requires──> #1391 event contract consumable (h, i, j)
#1392 exec ──requires──> #1391 consumable AND limits.py   (k)
```

辺の根拠と条件:

- **辺 1（#1391 → `limits.py`）**: 明記は TASK-1391/status.md:44（出典 e）だけで、plan.md では :180 の「#1393 から import」からの含意にとどまる（出典 b）。plan.md:9（出典 a）の条件は PF-5 合意で、すでに満たされている。つまりこの辺は **C-3 の承認対象外である status.md の記録に依存している**。
- **辺 3（`limits.py` 作成 → #1391 consumable の後）**: TASK-1393/todo.md:35 の位置づけで決まる。:35 が同じ「Preflight」節の :30（#1391 consumable）より後に実行する exec ステップなら閉路になる。Preflight 内の順序のない項目（:30 を待たずに作ってよい）なら閉路にならない。todo には節内の順序が書かれておらず、一次ソースだけではどちらか確定できない。

したがって、**:35 が :30 の後の exec ステップと解釈される場合に限り** `#1391 → limits.py → #1393 → #1391` で閉路になる。この場合 #1392 は閉路の下流にあり、どちらか一方が解けない限り着手できない。解釈の確定は Human に委ねる（H-2 の判断項目）。

循環が生まれた経緯: TASK-1383/dependency-matrix.md「Gate B」の DAG は `#1391 ─> #1393` の一方向だった。そこへ PF-5 の Human 決定（2026-10-22, R-086）で「#1393 所有・exec で作成」の定数 module を #1391 が import する形になり、逆向きの辺が加わった。決定のどれかが誤っていたわけではなく、**所有者と作成タイミングの組み合わせ**で閉路ができている。

なお `limits.py` は葉 module（他の ai-loop-v2 module を import しない。出典 f）なので、**コードの import 上は循環しない**。循環しているのは exec の順序の前提だけで、所有者は変えずに作成のタイミングを切り出せば解ける。

### 3.3 解消案の比較

| 案 | 内容 | 必要な手続き | 利点 | 欠点 / リスク |
|---|---|---|---|---|
| **案 1** `limits.py` だけを先に独立 PR にする（所有者は #1393 のまま） | 仮値（256 / 16 / 256、バイト上限は算出値の切上げ）と DI-46 相当の fixture テストだけを入れる | スコープ変更（Human 判断）。TASK-1393 の exec 範囲の一部を前倒しすることになるので、**TASK-1393 の re-C3 が要るかどうか**を Human が決める。HO パスには当たらないが、V2 実行系の変更なので #1329 の semantic invalidation 候補になる | 所有境界（D-3 / R-086）を変えない。#1391・#1392 の plan を改訂せずに閉路が解ける。葉 module なので差分は小さく、ロールバックも容易 | Rev 2.7 は未承認のまま。どの plan の承認でこの PR を作るのかを明示する必要がある（候補: Rev 2.7 を再承認してから、その exec の最初の 1 commit として出す）。仮値が後で変わると #1391 / #1392 の fixture も追従が要る |
| **案 2** #1391 の plan から `limits.py` 依存を外す | #1391 は MAX_* の再検査を exec 範囲から外す、または定数を注入可能にする（後で `limits.py` に配線する） | TASK-1391 plan の改訂 → 簡易 C-1 → C-3。#1391 は**まだ C-3 を実施していない**ので、再承認のやり直しは発生しない | 改訂コストが低い。#1391 を先に consumable にできる。plan.md:9 は不変のまま、status.md:44 の exec 前提を見直すだけで成立し得る（「`limits.py` が main にあること」を明記しているのは status.md:44 のみ。§3.2） | D-3 / D-6（Human 決定 2026-10-22）を弱める。append 時の上限検査が後回しになり、その間の残存脅威（上限の無い event が accept される）を明記する必要がある。後で配線する作業が増え、#1392 の terminal reserve の保証（「`limits.py` が main にあり reserve fixture がそこから導出されてから主張」）も遅れる |
| **案 3** `limits.py` の所有者を中立にする（例: #1391 または共有の葉 module に移す） | 所有者と作成タイミングを #1391 の exec 側に移す | PF-5-2（R-086）の Human 決定を変更する。TASK-1391 / TASK-1393 の両方の plan を改訂し、TASK-1393 は re-C3（TASK-1392 も plan に出典を書いているので影響を確認する） | 閉路が構造ごとなくなる | 決定済みの所有境界を動かすので手続きが最も重い。TASK-1392 の承認済み plan の記述（出典 = `limits.py`、owner #1393）に波及する可能性がある |
| 案 4（参考）#1391 と #1393 を 1 PR で同時に exec | 2 本の exec を統合する | 両方の C-3 と、統合レビュー | 順序の問題が消える | high-risk 同士を束ねるので、レビュー単位が巨大になる。§7-quater のラウンド設計が重くなる。推奨しない |

**推奨（Human が選ぶ前提）: 案 1。** 理由（判断基準の優先順: 要件適合 → 安全性 → 保守性 → コスト）:

1. 要件適合: Human 決定 D-3 / D-6 / R-086 を一つも弱めない。
2. 安全性: #1391 の append 時の上限検査を先送りしないので、案 2 の残存脅威が生まれない。
3. コスト: 変更は葉 module 1 つと fixture だけ。承認済みの TASK-1392 plan にも影響しない。根拠: TASK-1392/plan.md:293 は定数を `limits.py` から import すると書くだけで、`MAX_INPUT_REFS` 等の値を本文に持たない（「provisional values fixed by fixture」）。また保証の主張は「`limits.py` が main に fixture 固定値つきで存在してから」と条件づけられている。案 1 で値が R-087 の仮値どおりに入る限り plan_hash は動かない。

案 1 を選ぶ場合に Human が決めること: (a) TASK-1393 Rev 2.7 を先に再承認して「exec の最初の 1 commit」として出すか、(b) `limits.py` だけを別 PBI として C-3 にかけるか（H-2）。(a) の「承認 1 回で済む」は、**Preflight（:30 #1391 consumable ほか）が未完のまま `limits.py` だけを exec する部分例外を Human が明示許可すること**が前提になる。この許可が無ければ (a) では閉路が解けない。また #1329 preflight をこの PR に課すかも別に決める（H-8）。

### 3.4 現状（2026-10-30 更新）

| 項目 | 状態 | 出典 |
|---|---|---|
| 件数・文字数の 3 定数（`MAX_INPUT_REFS = 256` / `MAX_REQUIRED_VERIFIERS = 16` / `MAX_REF_CHARS = 71`） | **main に入った**。葉 module（他の ai-loop-v2 module を import しない）。`test_limits.py` は 4 tests、`tests/extras` には未配線で CI では走らない（配線するかは #1622 本文で「要判断」） | #1622（`46685615`）、`scripts/ai-loop-v2/limits.py` |
| `MAX_REF_CHARS` の値 | 初版の 256 から **71** に変更。ref / identifier / fingerprint を `^sha256:[0-9a-f]{64}$` の ASCII に限る Human 決定（2026-10-28）による。`verifier_id` は対象外で ASCII かつ長さ ≤ 71（Human 決定 2026-10-29 D1） | #1619、TASK-1393 R-089 / R-090 / R-092、TASK-1391 plan D-15 / R-064 / R-065 |
| byte 系 3 定数（`MAX_DECISION_EVENT_BYTES` / `DECISION_FIXED_OVERHEAD` / `ENVELOPE_OVERHEAD`）と I-11 の byte 検査 | **main に無い。#1623（OPEN）へ移管**。理由: V2 `decision_made` の最悪ケース event 構造が repo に無く、plan の「計算前に数値を書かない」を守れない。#1623 の前提は payload / envelope 構造が #1391 / #1406 で確定していること | TASK-1393 R-091、#1623 |
| 初版の閉路（`#1391 → limits.py → #1393 → #1391`） | 件数・文字数の 3 定数については、`limits.py` が #1393 の exec 第 1 歩として先に入ったので **成立しなくなった** | #1622 |
| 新たに生じうる順序依存 | TASK-1391 plan:181 は `MAX_INPUT_REFS` / `MAX_DECISION_EVENT_BYTES` を #1393 から import して append 時に再検査すると書く。`MAX_DECISION_EVENT_BYTES` の供給元は #1623 で、#1623 の前提は #1391 / #1406 の event 構造の確定。したがって「#1391 の byte 再検査」と「#1623」が互いを待つ形になるかは、TASK-1391 plan の P1B-7 が byte 再検査を #1391 の exec 範囲に含め続けるかで決まる。**含め続けるかは一次ソースで確定できない** | TASK-1391/plan.md:181、#1623、TASK-1393 R-091 |

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
| `limits.py` / `test_limits.py`（2026-10-30 追加） | 20 / 80 | **owner 側の成果（暫定ではない）。ただし範囲は件数・文字数の 3 定数だけ** | #1622。TASK-1393 plan Rev 2.9 の C-3 APPROVED（2026-10-29T07:44:37Z）のもとで入れた。byte 系 3 定数は #1623 に移管され未定義（`limits.py` 内のコメント）。値は「provisional、fixture で固定」 |
| shadow-only | — | 該当なし | 上の 8 ファイルに shadow-only と書かれたものは無い（canon の shadow は PBI materialization の文脈。artifact-responsibilities.md「Shadow evaluation / write authority boundary」） |

**暫定実装のテスト PASS は owner-backed E2E の証拠にならない。** TA-87 は non-authoritative な executable specification（#1383 reopen コメント「`ta-87:3-6`」）で、TA-93 の入力は non-authoritative な fixture だけ（`delivery_runtime.py:74-75`）。`test_delivery_v2.py` / `test_ratchet.py` / TA-92 / TA-93 が PASS しても、#1383 AC-11（owner contract を consume して再実装しない）・#1381 AC-6（simulation 不可）は満たされない。

## 5. クリティカルパス（再構成）

2026-10-30 更新後の図。済んだものは `[済]` と書く。

```text
[済] limits.py 件数・文字数 3 定数（#1622, 2026-10-29）──────────────┐
[済] TASK-1393 Rev2.10 C-3 APPROVED (2026-10-29T10:09:18Z) ──────────┤
[済] TASK-1391 C-3 APPROVED (2026-10-29T10:09:24Z) ──────────────────┤
                                                                     │
#1329 preflight ──> #1391 Phase 1B exec ──┐  (B-8 / B-13 の語彙を確定)
                       │                  │
                       │ event 構造の確定  └──> #1393 core exec
                       v                        │  (PF-1: decision_core / ratchet / delivery_runtime の caller 移行)
                  #1623 byte 系 3 定数 + I-11 byte 検査（OPEN）
                       │
TASK-1392 (C-3 記録上有効) ── #1391 consumable + #1329 ──> #1392 model B exec
                                                    │
                     #1392 + #1393 consumable ──> #1395 owner-backed E2E（run_state.py を削除、TA-87 を実走）
                                                    │
                     #1383 evidence（AC-11/14/15）──> #870 へ evidence ──> #1381 AC-6 の解除判定
```

#1623 から #1391 / #1392 / #1393 のどの exec への矢印があるかは一次ソースで確定できない（§3.4）。上の図は #1623 の前提（event 構造の確定）だけを描き、#1391 plan:181 の byte 再検査との順序は描いていない。

| ノード | blocker | owner | unblock_condition |
|---|---|---|---|
| [済] H-1 循環の解消 | — | — | #1622 で件数・文字数の 3 定数が先に入った（§6 H-1） |
| [済] `limits.py`（3 定数） | — | — | #1622 merge（2026-10-29T16:19:12Z） |
| #1623 byte 系 3 定数 + I-11 byte 検査（2026-10-30 追加） | V2 `decision_made` の payload / envelope 構造が #1391 / #1406 で未確定 | #1393 担当 | 構造の確定後に最悪ケース event を組んで値を fixture 固定（H-10） |
| [済] TASK-1391 C-3 | — | — | APPROVED 2026-10-29T10:09:24Z（plan_hash 照合はオーガナイザー報告）。現行 plan の sha256 は `d4641124…` |
| #1391 Phase 1B exec | #1329 preflight / reviewed_at_sha。`limits.py` が main にあること（3 定数分）は解消。byte 系との関係は §3.4 | #1391 担当 | TASK-1391/status.md:44 の前提を満たす（status.md は未更新で、`limits.py` の項は事実上済み） |
| [済] TASK-1393 re-C3 | — | — | Rev 2.10 が APPROVED 2026-10-29T10:09:18Z。現行 plan の sha256 は `ed637f48…` |
| #1393 core exec | #1391 consumable / PF-2〜PF-4・PF-6〜PF-8 / #1392 の入力形状の凍結 / #1395 の budget | #1393 担当 | todo「Preflight」の未チェック項目がすべて解消 |
| #1392 model B exec | #1391 consumable / #1329 preflight。`limits.py` の 3 定数は main にあるが、terminal reserve が参照する byte 系は #1623 | #1392 担当 | todo「Preflight」の条件（INDEX.md:16） |
| #1422 B-8 / B-13 | 未凍結の gap | #1391 plan（C-3） | TASK-1391 の C-3 で語彙と形状が決まる |
| #1395 owner-backed E2E | #1392 + #1393 が consumable でない | #1395 担当 | owner API への移行と、I3 以上の独立した evidence |
| #1383 / #870 / #1381 | #1395 | Human（解除判定） | AC-11 / AC-14 / AC-15 の evidence がそろう |

クリティカルパス外（並行して進めてよい / Delivery の判定には使わない）: #1465 / #1468 / #1473 / #869 / #1376。

## 6. Human 判断事項

| ID | 問い | 選択肢 | 推奨 | 影響 |
|---|---|---|---|---|
| H-1 | **[決着（実績, 2026-10-29）]** `limits.py` の循環をどう解くか | 1 = 先行の独立 PR（所有者 #1393）/ 2 = #1391 plan から依存を外す / 3 = 所有者を移す / 4 = 同時 exec | 初版の推奨は 1 | **決着の内容**: 件数・文字数の 3 定数を #1393 の exec 第 1 歩として `limits.py` に入れた（所有者は #1393 のまま）。出典: #1622（merge 2026-10-29T16:19:12Z）、#1619、TASK-1393 R-091。これは案 1 と実施経路が一致する。**ただし「案 1 を選ぶ」という Human の明示記録は見つかっていない**（実績からの判定）。**未解消の部分**: byte 系 3 定数は #1623 へ移管（Human 決定 2026-10-29、R-091）。#1391 plan:181 の byte 再検査との順序は §3.4 のとおり確定できず、H-10 で扱う |
| H-2 | **[決着（実績, 2026-10-29）]** （H-1 = 1 の場合）`limits.py` をどの承認で作るか | a = TASK-1393 を re-C3 し、その exec の最初の commit とする / b = `limits.py` 単独の PBI を C-3 にかける。あわせて、todo:35 を Preflight 未完（:30 ほか）のまま exec する**部分例外を明示許可するか**（y / n） | 初版の推奨は a | **a で実施された**。TASK-1393 plan Rev 2.9 の C-3 APPROVED（2026-10-29T07:44:37Z）のもとで、#1622 が「exec の第 1 歩」として入れた（#1622 本文）。**部分例外の明示許可の記録は見つかっていない**。todo:30（#1391 consumable）は未チェックのまま #1622 が merge された事実があるのみ |
| H-3 | **[決着（置換, 2026-10-29）]** TASK-1393 Rev 2.7（`404c432a…`）を承認するか | y / n | — | Rev 2.7 のまま承認された記録は無い。Rev 2.8（#1619, R-089 / R-090）→ Rev 2.9（R-091）→ Rev 2.10（R-092）に置き換わり、**Rev 2.10 が 2026-10-29T10:09:18Z に APPROVED**（オーガナイザーが c3.json の plan_hash を照合）。Rev 2.7 に対する簡易 C-1 は PASS（Unknowns / 依存 WARN）だったが（review-self.md:158〜）、承認の対象は Rev 2.10 |
| H-4 | **[決着, 2026-10-29]** TASK-1391 Rev 2.4 を C-3 にかけるか | y / n | — | **Rev 2.4（D-15 / R-065 反映後、sha256 `d4641124…`）が 2026-10-29T10:09:24Z に APPROVED**（オーガナイザーが c3.json の plan_hash を照合）。初版の `d4f69f26…` は #1619 の反映前の値。B-8 / B-13 の gap が C-3 で閉じたかは本レポートでは確認していない（#1422 の最新コメントは未再取得）。TASK-1391/status.md と plan「Current verdict」の「C-3 待ち」は未更新 |
| H-5 | **[未決着]** TASK-1392 の c3.json の実物が `f02d69cf…` か照合するか | y（Human が承認に使った worktree を確認する）/ n | **y** | 記録上は一致している（plan sha256 は 2026-10-30 も `f02d69cf…`）。exec 前の確認として必要。2026-10-29 の照合報告は TASK-1391 / TASK-1393 の 2 本で、TASK-1392 の言及は無い |
| H-6 | **[未決着]** `ratchet.py` / `scope_observer.py` の位置づけ（§4 で「不明」とした 2 つ） | 1 = 正式採用 / 2 = 暫定（移行・レビュー対象）/ 3 = 保留 | — | #1395 で consume するときの扱いが決まる |
| H-7 | **[未決着]** TASK-1392 INDEX.md:18 の古い記述（再承認が必要）を直すか | y / n | y | INDEX の鮮度契約（L0 の誤読を防ぐ） |
| H-8 | **[未決着]** （H-1 = 1 の場合）`limits.py` 先行 PR に #1329 preflight を課すか。課すなら誰が記録するか | y（記録者: #1393 担当 / Human）/ n | — | #1622 は merge 済みだが、本文に #1329 preflight の記録は無い。課す / 課さない・理由の記録は見つかっていない。#1391 / #1392 の exec は #1329 preflight 未通過で blocked のまま（TASK-1392 INDEX.md:16、TASK-1391 status.md:44）。V2 実行系の変更は #1329 の semantic invalidation 候補（TASK-1393 todo.md:41。2026-10-27 時点は :40）なので、課さない場合はその理由を記録する必要がある |
| H-9 | **[未決着]** TASK-1393/todo.md:27「Revision 2.6 に対する c3.json を Human が再発行」が未チェックのまま。チェックするか | y / n | y | review-self.md:156 では Rev 2.6 は 2026-10-21 に APPROVED。todo の更新漏れとみられる。2026-10-30 時点でも :27 は `[ ]`。さらに :34「Revision 2.10 に対する c3.json を Human が再発行」も `[ ]` のままで、Rev 2.10 は APPROVED 済みと食い違う |
| H-10（2026-10-30 新設） | **[未決着]** #1623（byte 系 3 定数）をクリティカルパスのどこに置くか。#1391 plan:181 の byte 再検査を #1391 の exec 範囲に含め続けるか | a = #1391 exec 前に #1623 を完了する / b = #1391 の byte 再検査を #1623 まで後ろ倒しする（TASK-1391 plan の改訂）/ c = 現状維持で #1391 / #1623 の順序は exec 時に決める | — | #1623 の前提は event 構造の確定（#1391 / #1406）。a だと #1391 の構造確定を待つ側に #1623 が入り、順序が閉じるか確認が要る。b は plan 改訂で、#1391 は C-3 済み（plan_hash が変わる）。出典: #1623、TASK-1391 plan:181、TASK-1393 R-091 |

## 7. Delivery First Release の判定

**BLOCKED。**（2026-10-30 更新後も判定は変わらない）

north-star.md「Delivery V2 first release」が求めるもの: `Request → … → Verify FAIL → Diagnose → Repair → Verify PASS → PR → Review finding → Repair → MERGE_READY` と、`NO_PROGRESS → safe stop / escalation` を E2E で実証すること。

| 根拠 | 状態 |
|---|---|
| owner 実装（#1391 Phase 1B / #1392 model B / #1393 core） | 3 本とも main に無い（2026-10-30 更新: main に入ったのは `limits.py` の 3 定数だけ）。C-3 は 3 本とも記録上 APPROVED（TASK-1391 / TASK-1393 は 2026-10-29、TASK-1392 は 2026-10-23）だが、exec は前提未了のまま |
| owner-backed E2E（#1395） | 未着手。main の runtime は暫定実装と non-authoritative な fixture |
| #1383 AC | 未達 4（AC-9 無限 retry しない / AC-11 owner contract の consume / AC-14 / AC-15）、一部 2（AC-3 / AC-7）。2026-09-29 の測定値で、その後これらを満たす owner 実装は merge されていない |
| `limits.py` の循環 | 件数・文字数の 3 定数については解消（#1622）。byte 系 3 定数は #1623（OPEN）で未実装、#1391 との順序は未確定（H-10） |

不足している Evidence:

- owner-backed の Run で `Verify FAIL → Repair → Verify PASS → MERGE_READY` を通した evidence（fixture ではない）
- `NO_PROGRESS` / budget 超過で停止した evidence（AC-7 / AC-9）
- #1395 の exact-head での独立した I3 / I4 レビュー（TASK-1393 todo「Handoff」）
- #870 に返す evidence bundle と、#1381 の解除判定（AC-14 / AC-15）

## 付記: 依頼文と一次ソースの食い違い

- 依頼文の「#1391 plan R-086」について: TASK-1391/plan.md には `limits.py` も R-086 も出てこない。plan にあるのは D-3 / D-6 と :180 の「#1393 から import」だけで、`limits.py` という名前と R-086 は TASK-1391/status.md:24 と review-external.md:306 にある。本レポートでは両方を引用した。
- 依頼文の「TASK-1392 の APPROVED は PR #1606 merge 後の plan に対するもの」について: hash は現行 plan と一致した。ただし承認時刻は merge commit の約 2.6 分前（§2）。
- TASK-1393/todo.md:27「Revision 2.6 に対する c3.json を Human が再発行」が未チェックのままになっている。INDEX.md によれば Rev 2.6 は 2026-10-21 に APPROVED なので、todo の更新漏れとみられる（本 PR では触れていない。2026-10-30 時点でも未チェック。H-9）。
