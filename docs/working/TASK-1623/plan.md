# TASK-1623 Implementation Plan

> Rev 4（2026-11-26, AI 作成。Rev 3 に C-2 R2 の R-013〜R-017 を反映。Rev 3 は D-2 と R1 の R-001〜R-012 を反映。`review-external.md`）。C-3 前の計画案。承認・実装許可ではない。`approvals/c3.json` は未発行。
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

### D-2（Human 決定 2026-11-26）: MC-2 は #1391 側の条件に移す（R-002）

原文:

> MC-2 は #1391 側の条件に移す。前半 PR の CI では「埋め込んだ写像と、その元になった `6756a597` の定義行のハッシュが一致すること」と「skip が 0 件であること」を確かめる。「#1391 PR の CI で実 validator と照合されたこと」は #1391 の C-4 の前提（バイト再検査の skip を外すときと同時）に移す。#1391 側の文書は変更せず、plan に #1391 への引き継ぎ事項として書く。

帰結: 前半 C-4 は #1391 PR の CI run に依存しない（循環依存の解消）。#1391 への引き継ぎは下記「#1391 への引き継ぎ事項」。

## #1391 への引き継ぎ事項（D-2。#1391 側の文書は本 TASK で変更しない）

- H-1391-1: #1391 の C-4 の前提に「前半のズレ検出テストの V2 tree 用分岐が #1391 PR の CI で実行され、実 `run_event` validator（`validate_event` 通過・`canonical_bytes` 同値・キー集合一致）で PASS したこと」を加える。バイト再検査（P1B-7）の skip を外すのと同じ PR で行う
- H-1391-2: V2 tree 上で main 用分岐（写像のみの検査）に入った場合は FAIL する番兵（R-001 / R-014）が #1391 PR の CI で FAIL しないこと＝V2 用分岐に切り替わっていること（ta-118 の明示行「V2 用分岐を通った」）を確認する。**V2 の印（振る舞い）の導入と V2 分岐の PASS は同一 PR で行い、部分着地 PR は作らない**。番兵が FAIL した場合は当該 PR を revert するか、同一 PR 内で是正する（R-017）
- H-1391-3: RT-2 の監視対象定義行（R-004）が `6756a597` から変わった場合、前半の埋め込み写像とハッシュを更新してから #1391 をマージする
- 受け渡し（R-015）: 本節は文書だけでは受け手がいない。前半マージ時に #1391 の Issue へ H-1391-1〜3 をチェックリストとしてコメントし、その URL を evidence 化する（MC-4）。#1623-b（後半）の C-3 条件に「H-1391-1 の evidence（#1391 PR の CI で V2 用分岐 PASS）」を含める

## AC 候補の採否（C-2 R1 由来）

| 候補 | 採否 | AC 文面 | スライス |
|---|---|---|---|
| R-011 / R-016 | **採用（AC-4、R-016 で改訂）** | AC-4: 前半の新規テストは CI 上で実行されたことを、(1) `verbosity=2` 出力の実行テスト名が ta-118 側の必須テスト名固定リストを全て含む、(2) 分岐の明示行（main 上は「main 用分岐を通った」）が出力される、(3) `skipped=` が無い、の 3 点で ta-118 が判定し、いずれか欠ければ FAIL とする | 前半 |
| R-012 / R-014 | **採用（AC-5、R-014 で改訂）** | AC-5: V2 `decision_made` 構造が tree に存在する（V2 の印＝振る舞いが 1 つでもある。名前の有無では判定しない）とき、写像だけの検査は FAIL し実 validator 照合へ切り替わる | 前半（番兵の実装と mutation）。V2 tree 上での実照合 PASS は #1391 側条件（H-1391-1） |

採用理由: どちらも R-001 / R-003 の是正が効いていることを合否で確かめる条件で、AC 化しないと「緑だが未実行」を受入で拒否できない。pbi-input.md の AC-1〜AC-3 の文面は変えず、本 plan で追加 AC として扱う。

## AC の前半/後半割当

| AC（文面は pbi-input.md のまま） | 満たすスライス | 前半での扱い |
|---|---|---|
| AC-1 最悪ケース event の組み立てと byte 計算が fixture テストで再現できる | **前半** | 完全に満たす（構造は `6756a597` の定義行ハッシュで束縛した埋め込み写像）。main 上の合格条件は byte 計算の再現まで。`validate_event` 通過は V2 tree 用検査＝#1391 側条件（R-005 / H-1391-1） |
| AC-1a 3 定数の導出根拠が残る（派生） | 前半 | 完全 |
| AC-1b escape・最大桁・任意 field を含む（派生） | 前半 | 完全（Q-2 の値確定が前提） |
| AC-2 I-11 が上限超過の入力を `DecisionInputError` にする | **後半** | 未達。前半では AC-2 を合格と記載しない |
| AC-2a 上限ちょうどは受理（派生） | 後半 | 未達 |
| AC-3 #1392 reserve が同じ定数を参照できる（派生・Scope 由来） | 前半（契約 fixture のみ） | 定数の import と不等式の契約 fixture まで。fixture は前半の `test_limits` 系に置き、`TERMINAL_RESERVE` は fixture 内の契約値（#1392 の exec で置換）とし #1392 所有物を定義しない（R-007）。#1392 store 本体の配線は #1392 |
| AC-4（追加, R-011） | 前半 | 完全 |
| AC-5（追加, R-012） | 前半（番兵） | 番兵と mutation まで。V2 tree での実照合 PASS は H-1391-1 |

### 前半マージの受入条件（R-C1-02 由来、D-2 / R-001 で改訂）

前半 PR は AC-1 系に加え、次をすべて満たすときだけ C-4 に渡す:

- MC-1: issue #1623 を Close しない。PR 本文は `Refs #1623` のみ（closing keyword を書かない）。handoff に「AC-2 未達・後半待ち」と「**後半マージまで byte 上限は I-11 で強制されていない**」を明記（R-006）
- MC-2（D-2 で改訂、R-013 / R-016 で再改訂）:
  - MC-2a（写像の正しさ。**CI の保証ではない**, R-013）: C-3 時点と前半 PR の C-4 時点の 2 回、`git show 6756a597:scripts/ai-loop-v2/run_event.py` の監視対象定義行（RT-2）と fixture の埋め込み写像を突き合わせた evidence を残す。実施者は Human、または AI が突き合わせ結果を提示し Human が確認する。CI は shallow checkout で `6756a597` を読めないため、CI 上の照合は写像と記録値を同時に編集すれば PASS する（自己参照）
  - MC-2a'（CI 上のハッシュ照合）: 写像から再計算した定義行 sha256 が fixture 記録値と一致すること。位置づけは**写像の改竄の検出ではなく偶発的な破損の検出**に限る
  - MC-2b: 新規テストが実行されたこと（AC-4。ta-118 が必須テスト名固定リスト・分岐明示行・`skipped=` 無しで判定）を前半 PR の CI ログで確認し evidence に残す
  - #1391 PR の CI での実 validator 照合は #1391 の C-4 前提（H-1391-1）であり前半の条件ではない
- MC-3（R-001 で改訂、R-014 で再改訂）: 写像はリポジトリに埋め込む（CI は shallow checkout のため実行時に `git show 6756a597` しない）。main 用検査（写像の byte 再現のみ）は「V2 の印が**全て無い**」ときだけ許可する。印は名前の有無ではなく**振る舞い**で判定する: `run_event` の validator が V2 形式の `decision_made` event（写像から組んだ最小 event）を受理するか、`EVENT_PAYLOAD_KEYS` に `decision_made` key があるか、validator 呼び出しの結果（V2 固有の拒否理由を返すか）。一部だけある、または V2 tree で main 用分岐に入る場合は FAIL（一方向の番兵、AC-5）。改名・別モジュールへの移設でも振る舞いが残る限り「印あり」と判定される
- MC-4（R-015）: 前半マージ時に #1391 の Issue へ H-1391-1〜3 をチェックリストとしてコメントし、コメント URL を handoff の evidence に記録する（投稿は前半マージ時の作業。計画段階では投稿しない）。#1623-b の C-3 条件に H-1391-1 の evidence を含める

### 残存脅威モデル（R-013 / §7-quater 打ち切り時の明記）

- 守るもの: 定数と写像の偶発的な不整合（CI のハッシュ照合・byte 再現）、V2 構造着地時に写像検査へ留まること（振る舞い判定の番兵）、テストの未実行（AC-4）
- 守らないもの: 写像と fixture 記録値を同一 PR で意図的に同時編集すること（CI では検出不能。MC-2a の Human 突き合わせと C-4 レビューが保証の主体）。#1391 PR での実 validator 照合（H-1391-1、#1391 の C-4 が主体）
- 本検査は多層防御の 1 層。`.github/workflows/` は変更しない（R-013 の是正としてフル fetch を足す案は HO に当たるため不採用。AI 推奨。C-3 で Human が覆せる）

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

推奨: **B**。理由（判断基準: 要件適合 → 安全 → 保守 → コスト）: AC 文面を変えず、#1391 後半・#1392 が必要とするのは定数そのもの（TASK-1392 plan.md:293、レポート P1B-7）なので critical path を最短で解除できる。A は #1393 の既存順序と C-3 に波及し影響が最大。C は skip 持ち越しの穴を再生産する。B の前提条件: (1) 「#1623 を先にマージ」を #1623-a 単位と読むことを Human が承認（D-1 で充足）、(2) drift テストが #1391 PR で必ず実行される配線（MC-2。D-2 で前半 PR の定義行ハッシュ一致・skip 0 件と #1391 の C-4 前提に分割）、(3) #1623 は #1623-b まで Open（MC-1）。

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
- 新規 fixture（例 `scripts/ai-loop-v2/fixtures/decision_event_worst_case.*`、名称は exec で確定）。`6756a597` の `DECISION_REQUIRED_KEYS` / `DECISION_OPTIONAL_KEYS` / `COMMON_ACCEPTED_KEYS` / `EVENT_PAYLOAD_KEYS["decision_made"]` / `_validate_decision` / `canonical_bytes`（`json.dumps` 引数 `ensure_ascii=False` を含む）/ `_validate_append_only`（`6756a597:run_event.py:467` 付近）の写像と、各定義行の sha256・出典 SHA を含む（R-001 / R-004）
- 新規ズレ検出テスト: `test_limits.py` に同居させる（ta-118 が実行する唯一のファイル）。別ファイルにする場合は `tests/extras/ta-118-ai-loop-v2-limits.sh` に実行行を追加し、出力に `skipped=` があれば FAIL とする（R-003 / AC-4）
- `tests/extras/ta-118-ai-loop-v2-limits.sh`（`verbosity=2` 実行、必須テスト名固定リストとの照合、分岐明示行の照合、`skipped=` の FAIL 判定を追加。`tests/extras/` は HO 非該当。R-016）
- `limits.py` の `ENVELOPE_OVERHEAD` docstring 方針: 「event 内 envelope。store 側の追加は 0（TASK-1392 plan.md:293）」（R-008）
- HO 対象パスは含まない（`scripts/hooks/` / `bin/plangate` / `schemas/` / `.github/workflows/` 非接触）。R-003 により収集は `tests/extras/` で足り `.github/workflows/` 変更は不要の見込み。不要でないと判明した場合は HO に当たるため RT-6 で停止

後半（本計画の exec 対象外。参考）: I-11 byte 検査は #1393 core の `make_decision_input`（TASK-1393 plan.md:180 / R-091）。

## Work Breakdown（前半）

1. **契約確定（owner）** Output: Q-2 表の各値の確定記録。🚩 確定前は値を書かない
2. **RED** Output: 最悪ケース fixture（outcome 別・escape・最大桁・任意 field）と区分テストが失敗する状態。`test_no_byte_constants` の置換テスト
3. **GREEN（定数）** Output: 3 定数と導出根拠（実測 byte → 切り上げ規則）。区分（input 由来 / fixed / envelope）でキー・区切りを二重計上しない
4. **ズレ検出テスト** Output: 埋め込み写像の定義行 sha256 照合（MC-2a'、偶発破損の検出のみ）、V2 の印（振る舞い判定, R-014）が全て無い tree では写像で byte 再現（MC-3）、印が 1 つでもある tree では実 validator と byte 同値・キー集合一致を照合し main 用分岐に入れば FAIL（AC-5）。各分岐で「main 用分岐を通った / V2 用分岐を通った」を明示行として出力。ta-118 の必須テスト名・分岐明示行・`skipped=` 判定（AC-4 / R-016）
4b. **写像の Human 突き合わせ（MC-2a, R-013）** Output: `git show 6756a597:scripts/ai-loop-v2/run_event.py` の監視対象定義行と fixture 写像の突き合わせ evidence（C-3 時点・前半 C-4 時点）
5. **#1392 reserve 契約 fixture** Output: `test_limits` 系に置き、`TERMINAL_RESERVE`（fixture 内の契約値）`>= 1 event and >= MAX_DECISION_EVENT_BYTES` を同じ定数 import で表現（R-007）
6. **mutation / レビュー** Output: 定数 −1、escape 無視、区分二重計上、構造キー 1 件増減、**V2 tree で main 用分岐を強制**、**V2 の印の一部だけ残す**、**テストを skip させる**、**V2 の印を改名**、**V2 の印を別モジュールへ移設**（R-014）、**必須テストを未収集にする / 分岐明示行を出さない**（R-016）の注入が検出されること。敵対レビュー 2 ラウンド
7. **前半マージ条件の確認** Output: MC-1〜MC-3 の evidence（前半 PR の CI ログで MC-2a' のハッシュ一致と MC-2b の実行確認、MC-2a の Human 突き合わせ）。🚩 未確認なら C-4 に渡さない
8. **前半マージ時の受け渡し（MC-4, R-015）** Output: #1391 Issue への H-1391-1〜3 チェックリストコメントの URL（マージ時に投稿。投稿は対外書込のため実施時に名指し承認を取る）

後半（別スライス・別 C-3）: I-11 接続（超過で `DecisionInputError`、ちょうどで受理）。#1393 core と同時かその直後。

## Verification Plan

- `python3 scripts/ai-loop-v2/test_limits.py`、TA-118、新規 fixture テスト
- mutation（上記 7）を独立コピーに注入して全て FAIL→復元で PASS
- 前半 PR の CI ログで定義行ハッシュ一致（偶発破損の検出）と、必須テスト名・分岐明示行・`skipped=` 無しを確認（MC-2a' / MC-2b / D-2）。写像の正しさは MC-2a の Human 突き合わせ evidence（R-013）。#1391 PR での実 validator 照合は H-1391-1

### レビューレーン計画（#786）

- C-2: 設計妥当性レーン（本 plan / Q-1）+ コードベース整合レーン（run_event / limits / store）
- review-principles §7-quater: high-risk のため **2 ラウンド以上**。R2 は R1 是正（例: escape 対策、番兵、収集経路）が別経路（キー側 escape、数値桁、任意 field、V2 の印の部分一致）で漏れていないかを疑う。回避クラス台帳を review-external.md に置く
- 打ち切り（R-009）: R2 で新しい回避クラス 0 件なら終了、1 件以上なら R3（以降同じ規則）
- R2 結果（2026-11-26）: 新しい回避クラス 4 件（自己参照ハッシュ / 改名・移設による番兵の素通り / 文書だけの引き継ぎ / skip 以外の未実行）→ R3 を実施する。R3 は R-013〜R-017 の是正（Human 突き合わせ・振る舞い判定・MC-4・必須テスト名照合）の回避経路を疑う

## Mode判定

**モード**: high-risk

- 変更ファイル数: 3〜5（limits / test / fixture / I-11 配置先 / reserve fixture）→ standard
- 受入基準数: 2 + 追加 2（AC-4 / AC-5）（派生検証 4）→ standard
- 変更種別: 共有契約定数（#1391 / #1392 / #1393 の 3 TASK が参照）・fail-closed 境界 → high-risk
- リスク: 過小値なら terminal を書けない Run が生じる（安全側の保証が偽になる）→ high-risk
- **最終判定**: high-risk（定性が優先）。HO 非該当だが C-3 は人間必須、C-2 必須、autonomous APPROVE 不可。`lite_eligible=false`

## Replan Triggers

- RT-1: D-1（案 B）が撤回・変更される、または #1393 core が前半より先に main に入る → スライス分割を見直す
- RT-2: `6756a597` 以降に監視対象（`DECISION_REQUIRED_KEYS` / `DECISION_OPTIONAL_KEYS` / `COMMON_ACCEPTED_KEYS` / `EVENT_PAYLOAD_KEYS["decision_made"]` / `_validate_decision` / `canonical_bytes` の `json.dumps` 引数 / `_validate_append_only`）が 1 つでも変わる。`<head>` = `origin/feat/1391-phase1b-exec` の tip、および #1391 PR の merge commit。判定は `git diff 6756a597 <head> -- scripts/ai-loop-v2/run_event.py` が定義行に非空、または SHA 到達不能時は `<head>` の定義行 sha256 が fixture 記録値と不一致（R-004）
- RT-3: Q-2 のいずれかの上限が未確定のまま 2 回の owner 確認で決まらない、または初回確認から 5 営業日で決まらない（R-010）
- RT-8（後半向け予約, R-006）: 後半で I-11 の数え方（results+FR+policy verdicts の合算・重複寄与）が Q-2 の確定値と食い違う → 前半の定数を測り直してから後半を exec する
- RT-4: 実測最大値が #1392 の `MAX_SNAPSHOT_BYTES`（暫定 8 MiB）の 1% を超える（reserve 設計の前提見直し）
- RT-5: mutation 注入 1 件でも検出されない
- RT-6: MC-2 / AC-4 を満たすのに `.github/workflows/` 等の HO 対象パス変更が必要と判明する（ta-118 経由の収集経路に載らない）
- RT-7: 前半 PR の CI ログで必須テスト名固定リストのうち 1 件でも実行行が無い、分岐明示行が無い、または `skipped=` が 1 件以上（D-2 で #1391 PR から前半 PR に移動、R-016 で判定を拡張）
- RT-9（R-013）: MC-2a の Human 突き合わせで写像と `6756a597` の定義行が 1 行でも不一致 → 写像を修正し C-3 / C-4 を取り直す

## Stop Condition

- Q-2 の値が未確定の間は定数値を書かない
- RED のテストが 2 回の修正で GREEN にならない → 停止し報告
- I-11 を正式経路以外（暫定 core / fixture 模擬）で合格扱いにする必要が出た時点で停止
- 前半で AC-2 を合格と記載する必要が出た時点で停止

## Human Approval Boundary

- C-3（本 plan）: Human。前半のみの実装許可。後半は別 C-3
- #1393 / #1392 / #1395 の owner 確認（Q-2）
- c3.json の発行・merge・C-4: Human-owned
- MC-2a の写像突き合わせの確認（C-3 時点・前半 C-4 時点）: Human（R-013）
- MC-4 の #1391 Issue へのコメント投稿: 前半マージ時に対象を名指しして承認を取る（R-015）
- #1623-b の C-3: H-1391-1 の evidence を条件に含める（R-015）

## C-1 Self Review Checklist

`review-self.md` を参照。
