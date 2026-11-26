# TASK-1623 Implementation Plan

> Rev 2（2026-11-26, AI 作成。Rev 1 に Human 決定 D-1 を反映）。C-3 前の計画案。承認・実装許可ではない。`approvals/c3.json` は未発行。
> 基準: `origin/main` = `fd6b6843`。#1391 スライス A = `origin/feat/1391-phase1b-exec` の `6756a597`（main 未マージ・PR なし）。
> 既存の #1393 C-3 は本 TASK の実装許可として流用しない（issue #1623 2026-11-03 追記）。

## Goal

whole `decision_made` event の最大 canonical byte 数を最悪ケース event から導出して `limits.py` に fixture 固定し、I-11 がそれを超える入力を `DecisionInputError` で拒否し、#1392 terminal reserve が同じ定数を参照できる状態にする。

## Decisions

### D-1（Human 決定 2026-11-26）: Q-1 は案 B

原文（委任プロンプト経由で受領した Human 決定の記載）:

> plan の Q-1 の順序は **案 B**。#1623 を前半・後半に分ける。前半 = byte 系 3 定数（`MAX_DECISION_EVENT_BYTES` / `DECISION_FIXED_OVERHEAD` / `ENVELOPE_OVERHEAD`）と最悪ケースの fixture、#1391 スライス A（`origin/feat/1391-phase1b-exec` の `6756a597`）の `decision_made` 構造を固定 SHA で写したズレ検出テストを先にマージ。後半 = I-11 の byte 検査（AC-2）で、#1393 本体と同時かその直後。issue #1623 は前半マージ後も Open のまま。

帰結:

- 前半（#1623-a）・後半（#1623-b）を別 PR とする。本計画 Rev 2 の exec 対象は **前半のみ**。後半は #1393 core の plan 側で接続し、本 TASK の後半スライスとして再度 C-3 を取る（本 C-3 は後半の実装許可を含まない）
- AC 文面は不変（pbi-input.md）。割当は下記「AC の前半/後半割当」

## AC の前半/後半割当

| AC（文面は pbi-input.md のまま） | 満たすスライス | 前半での扱い |
|---|---|---|
| AC-1 最悪ケース event の組み立てと byte 計算が fixture テストで再現できる | **前半** | 完全に満たす（構造は `6756a597` の固定 SHA 写像） |
| AC-1a 3 定数の導出根拠が残る（派生） | 前半 | 完全 |
| AC-1b escape・最大桁・任意 field を含む（派生） | 前半 | 完全（Q-2 の値確定が前提） |
| AC-2 I-11 が上限超過の入力を `DecisionInputError` にする | **後半** | 未達。前半では AC-2 を合格と記載しない |
| AC-2a 上限ちょうどは受理（派生） | 後半 | 未達 |
| AC-3 #1392 reserve が同じ定数を参照できる（派生・Scope 由来） | 前半（契約 fixture のみ） | 定数の import と不等式の契約 fixture まで。#1392 store 本体の配線は #1392 |

### 前半マージの受入条件（R-C1-02 由来）

前半 PR は AC-1 系に加え、次をすべて満たすときだけ C-4 に渡す:

- MC-1: issue #1623 を Close しない。PR 本文は `Refs #1623` のみ（closing keyword を書かない）。handoff に「AC-2 未達・後半待ち」を明記
- MC-2: ズレ検出テスト（TC-03）が #1391 PR の CI で**実際に実行される**こと。skip / 未収集で緑にならない（#1391 PR 上の CI ログでテスト名と PASS/FAIL を確認し、evidence に残す）。確認できない間は前半を C-4 に渡さない
- MC-3: main 上（#1391 未マージ）でもズレ検出テストが skip でなく固定 SHA の写像を検査する（構造未着地を理由に黙って通過しない）

## Context

- 定義: TASK-1393 plan.md:180（I-11）、:341（Payload size）、:343（Limits module）。#1392 側: TASK-1392 plan.md:293（`TERMINAL_RESERVE >= 1 event and >= MAX_DECISION_EVENT_BYTES`）。
- #1391 P1B-7 は byte 再検査を skip で RED 保持し、#1623 の定数が main に入った後に GREEN にする（critical path レポート 2026-11-25 更新）。
- #1635 の反例: 71 文字 ASCII でも escape で最大 428 byte/要素。ref 専用の `n × 74` を `verifier_id` に流用しない。

## 前提の実測検証（#786）

下書き（exec-1391 worktree `docs/working/TASK-1623/plan.md`、未コミット）の結論「現行受入条件では #1623 の先行マージ不可」を main `fd6b6843` で裏取りした。**結論は支持する**。根拠:

| # | 主張 | 実測 | 判定 |
|---|---|---|---|
| V-1 | main に正式な DecisionInput 経路・`DecisionInputError` が無い | `grep -rn -e DecisionInputError -e decision_to_event_draft -e "class DecisionInput" scripts/ai-loop-v2/` → 0 件。`decision_core.py:19` は `DecisionError` のみ、`decide()`（:132-143）は旧 kwargs 署名（`loop_contract`, `run_state`, `verifications`, …, `changed_paths`）| 一致 |
| V-2 | #1392 terminal reserve が main に無い | `grep -rn reserve scripts/ai-loop-v2/` → `ratchet.py:746` のコメントのみ。`run_state.py:76-99` の `DurableRunStore.init` は件数・byte 上限を持たず、`revision` は任意 int を受理（:92）| 一致 |
| V-3（追加） | V2 `decision_made` 構造自体も main に無い | main の `run_event.py` に `_validate_decision` / `DECISION_REQUIRED_KEYS` / `_validate_append_only` が無い（grep 0 件）。構造は `6756a597` の `run_event.py` にのみ存在 | 下書きに無い論点。AC-1 の「最悪ケース event」も main 単独では組めない |
| V-4 | limits.py は件数・文字数 3 定数のみ | `limits.py:18-20`（256 / 16 / 71）、`test_limits.py:58` `test_no_byte_constants` | 一致 |

訂正点: 下書きは「main の暫定 core」に焦点を置くが、V-3 により **I-11 だけでなく AC-1 も main 単独では満たせない**（構造は未マージのスライス A に依存）。fixture は `6756a597` の構造を固定 SHA として写す必要がある。

## Questions / Unknowns（#786）

### Q-1（**解決済み 2026-11-26: 案 B**、D-1）: H-10 と AC-2 の衝突

> 以下は判断時の比較記録として残す。決定は「Decisions」D-1。

H-10（2026-11-26）は「#1623 を先にマージし、byte 再検査は #1391 後半」。一方 AC-2 は `DecisionInputError` と I-11（`make_decision_input`、TASK-1393 plan.md:149/180）を要し、これは #1393 core exec（レポート上の順序 6 番目＝#1391・#1392 の後）で初めて main に入る。さらに V-3 により event 構造も #1391 のマージまで main に無い。**現行 AC のままでは #1623 を #1391 より先にマージできない**。

| 案 | 内容 | AC 変更 | H-10 | #1391 後半の解除 | #1392 reserve | 主なリスク | 承認境界への影響 |
|---|---|---|---|---|---|---|---|
| A: #1393 core の最小入口を先行 | `DecisionInput` / `make_decision_input` / `DecisionInputError` と accepted event 写像だけを #1393 から切り出して先に着地 → #1623 を完全 AC で → #1391 後半 | なし | 維持 | 遅い（#1393 の部分 exec を先に要する） | 定数あり | #1393 plan（PF-1 の caller 移行等）と順序の再設計が要る。#1393 C-3 再発行の可能性 | #1393 のスコープ・順序変更（Human） |
| **B: fixture 契約で分割先行（推奨）** | #1623-a: 3 定数 + 最悪ケース fixture（`6756a597` 構造を固定 SHA で写し、#1391 マージ時に実 validator と byte 同値を照合する drift テストを含む）を先にマージ。#1623-b: I-11 byte 検査（AC-2）は #1393 core に同梱または直後。#1623 は b 完了まで Open | AC-2 の達成時期を分ける（AC 文面は不変） | 維持（定数は先行） | 早い（定数が main に入る） | 定数あり | 構造 drift（drift テストで検出）。「#1623 完了」の誤認（Open 維持で防ぐ） | #1623 のマージ単位変更（Human） |
| C: H-10 見直し | #1391 を byte 再検査なしでマージ（件数上限のみ）、#1623 は #1393 core と同時に完全 AC | なし | 変更 | byte 再検査は #1391 後の別 PR へ | 定数が遅れる | #1391 の skip を別 PR に持ち越す穴（plan.md:33 と同型）| H-10 の再決定（Human） |
| D: fixture だけで AC-2 合格扱い | 暫定 core / fixture で `DecisionInputError` を模擬 | 実質変更 | 維持 | 早い | 定数あり | 正式 I-11 未経由を合格と誤記 | **不採用**（下書き・issue の方針と矛盾） |

推奨: **B**。理由（判断基準: 要件適合 → 安全 → 保守 → コスト）: AC 文面を変えず、#1391 後半・#1392 が必要とするのは定数そのもの（TASK-1392 plan.md:293、レポート P1B-7）なので critical path を最短で解除できる。A は #1393 の既存順序と C-3 に波及し影響が最大。C は skip 持ち越しの穴を再生産する。B の前提条件: (1) 「#1623 を先にマージ」を #1623-a 単位と読むことを Human が承認（D-1 で充足）、(2) drift テストが #1391 PR で必ず実行される配線（MC-2）、(3) #1623 は #1623-b まで Open（MC-1）。

### Q-2: 可変 field の上限（各 owner 確認）

| field | 現状 | 確認先 |
|---|---|---|
| `run_id` | TASK-1392 plan.md:66 `RUN-[A-Z0-9][A-Z0-9_-]{0,63}`（≤68）。validator は非空のみ | #1392 |
| `event_seq` / `revision` / `input_last_event_seq` / `contract_bound_seq` | `MAX_EVENTS_PER_RUN` 暫定 2048（TASK-1392 plan.md:291）。main store は任意 int revision | #1392 / #1395 |
| `inputs` / `failure_fingerprints` | I-11 は results+FR+policy verdicts 合計 ≤256。event 上は別配列で同一 FR が両方に寄与し得る | #1391 / #1393 |
| `verdicts` | I-11: ≤16、ASCII ≤71、sha256 形不要（R-092）。event validator はキー長・件数を検査しない。escape 込みで測る | #1393 |
| `stop_reasons` | 列挙制。event validator は重複を拒否しない（`6756a597` run_event `_validate_decision`）| #1391 / #1393 |
| `artifact_ref` / `source_sha` | sha256 形 71 文字 / commit 7〜40 hex | 確定済み |

### Q-3: I-11 の保証範囲

I-11 は「valid な DecisionInput から作る Decision の event」を守る（TASK-1393 plan.md:341）。任意の append 候補は #1391 スライス B が強制する。load 時に再適用しない。

## Approach Comparison

順序案は Q-1 の表。計算方式:

| 方式 | 採否 | 理由 |
|---|---|---|
| 最悪ケース event を実 serializer で組んで測る | 採用 | plan.md:343「計算前に数値を書かない」 |
| `n × 74` 等の算術見積 | 補助のみ | escape を数えない（#1635）|
| 各 outcome（MERGE_READY / BLOCKED / HUMAN_ESCALATED / null）を個別に測り最大を取る | 採用 | MERGE_READY は `stop_reasons` 空・`artifact_ref` 必須で組が異なる |

## Files / Interfaces（前半 exec 時。本計画 Rev では変更しない）

前半（本計画の exec 対象）:

- `scripts/ai-loop-v2/limits.py`（3 定数追加。leaf module 維持）
- `scripts/ai-loop-v2/test_limits.py`（`test_no_byte_constants` を最大 event・区分テストへ置換）
- 新規 fixture（例 `scripts/ai-loop-v2/fixtures/decision_event_worst_case.*`、名称は exec で確定）。`6756a597` の `DECISION_REQUIRED_KEYS` / `DECISION_OPTIONAL_KEYS` / `COMMON_ACCEPTED_KEYS` / `canonical_bytes` の写像と出典 SHA を含む
- 新規ズレ検出テスト（配置は既存 ai-loop-v2 テストの収集経路に載る場所。名称は exec で確定）
- HO 対象パスは含まない（`scripts/hooks/` / `bin/plangate` / `schemas/` / `.github/workflows/` 非接触）。MC-2 の CI 配線が既存ワークフローの収集経路で満たせない場合は `.github/workflows/` 変更が必要になり HO に当たるため RT-6 で停止

後半（本計画の exec 対象外。参考）: I-11 byte 検査は #1393 core の `make_decision_input`（TASK-1393 plan.md:180 / R-091）。

## Work Breakdown（前半）

1. **契約確定（owner）** Output: Q-2 表の各値の確定記録。🚩 確定前は値を書かない
2. **RED** Output: 最悪ケース fixture（outcome 別・escape・最大桁・任意 field）と区分テストが失敗する状態。`test_no_byte_constants` の置換テスト
3. **GREEN（定数）** Output: 3 定数と導出根拠（実測 byte → 切り上げ規則）。区分（input 由来 / fixed / envelope）でキー・区切りを二重計上しない
4. **ズレ検出テスト** Output: main 上では固定 SHA 写像を検査（MC-3）、`run_event` に V2 構造がある tree（#1391 PR）では実 validator と byte 同値・キー集合一致を照合
5. **#1392 reserve 契約 fixture** Output: `TERMINAL_RESERVE >= 1 event and >= MAX_DECISION_EVENT_BYTES` を同じ定数 import で表現
6. **mutation / レビュー** Output: 定数 −1、escape 無視、区分二重計上、構造キー 1 件増減の注入が検出されること。敵対レビュー 2 ラウンド
7. **前半マージ条件の確認** Output: MC-1〜MC-3 の evidence（#1391 PR の CI ログでズレ検出テストの実行を確認）。🚩 未確認なら C-4 に渡さない

後半（別スライス・別 C-3）: I-11 接続（超過で `DecisionInputError`、ちょうどで受理）。#1393 core と同時かその直後。

## Verification Plan

- `python3 scripts/ai-loop-v2/test_limits.py`、TA-118、新規 fixture テスト
- mutation（上記 7）を独立コピーに注入して全て FAIL→復元で PASS
- #1391 PR 上でズレ検出テストが実行されることを CI ログで確認（MC-2）

### レビューレーン計画（#786）

- C-2: 設計妥当性レーン（本 plan / Q-1）+ コードベース整合レーン（run_event / limits / store）
- review-principles §7-quater: high-risk のため **2 ラウンド以上**。R2 は R1 是正（例: escape 対策）が別経路（キー側 escape、数値桁、任意 field）で漏れていないかを疑う。回避クラス台帳を review-external.md に置く

## Mode判定

**モード**: high-risk

- 変更ファイル数: 3〜5（limits / test / fixture / I-11 配置先 / reserve fixture）→ standard
- 受入基準数: 2（派生検証 4）→ light〜standard
- 変更種別: 共有契約定数（#1391 / #1392 / #1393 の 3 TASK が参照）・fail-closed 境界 → high-risk
- リスク: 過小値なら terminal を書けない Run が生じる（安全側の保証が偽になる）→ high-risk
- **最終判定**: high-risk（定性が優先）。HO 非該当だが C-3 は人間必須、C-2 必須、autonomous APPROVE 不可。`lite_eligible=false`

## Replan Triggers

- RT-1: D-1（案 B）が撤回・変更される、または #1393 core が前半より先に main に入る → スライス分割を見直す
- RT-2: `6756a597` 以降に `DECISION_REQUIRED_KEYS` / `DECISION_OPTIONAL_KEYS` / `COMMON_ACCEPTED_KEYS` / `canonical_bytes` が 1 つでも変わる（`git diff 6756a597 <head> -- scripts/ai-loop-v2/run_event.py` が上記定義行に非空）
- RT-3: Q-2 のいずれかの上限が未確定のまま 2 回の owner 確認で決まらない
- RT-4: 実測最大値が #1392 の `MAX_SNAPSHOT_BYTES`（暫定 8 MiB）の 1% を超える（reserve 設計の前提見直し）
- RT-5: mutation 注入 1 件でも検出されない
- RT-6: MC-2 を満たすのに `.github/workflows/` 等の HO 対象パス変更が必要と判明する（既存 CI の収集経路に載らない）
- RT-7: #1391 PR の CI ログにズレ検出テストの実行行が 0 件（skip / 未収集）

## Stop Condition

- Q-2 の値が未確定の間は定数値を書かない
- RED のテストが 2 回の修正で GREEN にならない → 停止し報告
- I-11 を正式経路以外（暫定 core / fixture 模擬）で合格扱いにする必要が出た時点で停止
- 前半で AC-2 を合格と記載する必要が出た時点で停止

## Human Approval Boundary

- C-3（本 plan）: Human。前半のみの実装許可。後半は別 C-3
- #1393 / #1392 / #1395 の owner 確認（Q-2）
- c3.json の発行・merge・C-4: Human-owned

## C-1 Self Review Checklist

`review-self.md` を参照。
