# TASK-1623 Implementation Plan

> Rev 5（2026-11-26, AI 作成。Human 決定 D-3 と C-2 R3 の R-018〜R-023 を反映し、前半スコープを縮小。Rev 4 は R-013〜R-017 を反映。Rev 3 は D-2 と R1 の R-001〜R-012 を反映。`review-external.md`）。C-3 前の計画案。承認・実装許可ではない。`approvals/c3.json` は未発行。
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

### D-3（Human 決定 2026-11-26）: 前半からズレ検出を外す（R-018〜R-023）

原文:

> 前半からズレ検出を外す。前半は byte 定数 3 つと、最悪ケースの算定根拠・テストデータだけにする（構造の出典は 6756a597 に固定し、人が突き合わせた証跡を残す）。実際の validator との照合・番兵・ズレ検出は、構造が実在する #1391 後半（バイト再検査の skip を外す PR）に移す。

理由: C-2 で R2 に新しい回避クラス 4 件、R3 に 3 件と収束せず、review-principles §7-quater の「設計モデルそのものを疑う」に該当した。根は main に無い構造を main 上で照合する設計である。R-018 は実物確認済み（main `run_event.py:50` に `"decision_made": {"decision"}` があり、振る舞い判定の印が main でも真になる）。

帰結:

- 前半（#1623-a）= 3 定数 + 最悪ケースの算定根拠 + fixture（数値の再現）+ ta-118 で skip 0 件実行。D-1 原文の「ズレ検出テストを先にマージ」は D-3 で上書き
- ズレ検出テスト・番兵・V2 tree での実照合・MC-3・AC-5 の前半実装分・分岐明示行・必須テスト名照合は前半から外し、#1391 後半への引き継ぎ（H-1391-4〜6）とする
- 外した項目は削除せず「D-3 で移管」と明記して残す（監査連続性）

## #1391 への引き継ぎ事項（D-2 / D-3。#1391 側の文書は本 TASK で変更しない）

> D-3 により H-1391-1〜3 の「前半のズレ検出テスト」は前半に存在しない。#1391 後半（バイト再検査の skip を外す PR）で新設する検査として読み替える。

- H-1391-1: #1391 の C-4 の前提に「前半のズレ検出テストの V2 tree 用分岐が #1391 PR の CI で実行され、実 `run_event` validator（`validate_event` 通過・`canonical_bytes` 同値・キー集合一致）で PASS したこと」を加える。バイト再検査（P1B-7）の skip を外すのと同じ PR で行う
- H-1391-2: V2 tree 上で main 用分岐（写像のみの検査）に入った場合は FAIL する番兵（R-001 / R-014）が #1391 PR の CI で FAIL しないこと＝V2 用分岐に切り替わっていること（ta-118 の明示行「V2 用分岐を通った」）を確認する。**V2 の印（振る舞い）の導入と V2 分岐の PASS は同一 PR で行い、部分着地 PR は作らない**。番兵が FAIL した場合は当該 PR を revert するか、同一 PR 内で是正する（R-017）
- H-1391-3: RT-2 の監視対象定義行（R-004）が `6756a597` から変わった場合、前半の最悪ケース fixture と定数を測り直してから #1391 をマージする（D-3 で「埋め込み写像とハッシュ」は前半に無い）
- H-1391-4（D-3 / R-018 / R-019）: 番兵を #1391 後半で設計する場合、印の各判定条件が main（基準 tree）で偽になることを実物で測る（main `run_event.py:50` に `decision_made` key がある）。判定は 3 値（印あり / 印なし / 判定不能 = FAIL）とし、例外を「印なし」に倒さない。そもそも V2 構造が実在する tree では番兵は不要で、実 validator 照合だけでよい可能性を先に検討する
- H-1391-5（D-3 / R-016 / R-021）: 実照合テストの未実行検出。必須テスト名の固定リストはテストと同時改名で素通りするため、採用するなら固定リストを別ファイル・別 owner に置くか件数下限と併用する
- H-1391-6（D-3 / R-005 / R-020）: 前半の最悪ケース event が実 `validate_event` を通り、`canonical_bytes` が前半 fixture の byte 数と同値であること（AC-1 の validator 通過）を #1391 後半で確かめる。検査は V2 tree 上でだけ走らせ、tree 依存の期待値を持たない
- 受け渡し（R-015 / R-022）: 前半 C-4 の前に、#1391 Issue への H-1391-1〜6 チェックリストコメントの本文案と投稿先を `evidence/mc4-draft.md` に置き Human が確認する。投稿はマージ後（対外書込のため名指し承認）。投稿 URL を handoff に残すことを #1623-b の C-3 前提とする（MC-4）。#1623-b の C-3 条件には H-1391-1 / H-1391-6 の evidence も含める

## AC 候補の採否（C-2 R1 由来）

| 候補 | 採否 | AC 文面 | スライス |
|---|---|---|---|
| R-011 / R-016 / R-021 | **採用（AC-4、D-3 で縮小）** | AC-4: 前半の新規テストは ta-118 で実行され、`skipped=` が 0 件かつ rc=0 であることを ta-118 が判定し、skip が 1 件でもあれば FAIL とする。（Rev 4 の必須テスト名固定リスト照合・分岐明示行は D-3 で #1391 後半へ移管: H-1391-5） | 前半 |
| R-012 / R-014 | **採用（AC-5）→ D-3 で #1391 後半へ移管** | AC-5: V2 `decision_made` 構造が tree に存在するとき、写像だけの検査は FAIL し実 validator 照合へ切り替わる | 前半では実装しない（前半に写像検査が無いため番兵の対象が無い）。#1391 後半（H-1391-4 / H-1391-6） |

採用理由: どちらも R-001 / R-003 の是正が効いていることを合否で確かめる条件で、AC 化しないと「緑だが未実行」を受入で拒否できない。pbi-input.md の AC-1〜AC-3 の文面は変えず、本 plan で追加 AC として扱う。

## AC の前半/後半割当

| AC（文面は pbi-input.md のまま） | 満たすスライス | 前半での扱い |
|---|---|---|
| AC-1 最悪ケース event の組み立てと byte 計算が fixture テストで再現できる | **前半** | byte 計算の再現まで満たす（構造の出典は `6756a597` に固定し、MC-2a の Human 突き合わせ evidence で束縛。D-3 で定義行ハッシュ照合は外した）。`validate_event` 通過は #1391 後半（R-005 / H-1391-6） |
| AC-1a 3 定数の導出根拠が残る（派生） | 前半 | 完全 |
| AC-1b escape・最大桁・任意 field を含む（派生） | 前半 | 完全（Q-2 の値確定が前提） |
| AC-2 I-11 が上限超過の入力を `DecisionInputError` にする | **後半** | 未達。前半では AC-2 を合格と記載しない |
| AC-2a 上限ちょうどは受理（派生） | 後半 | 未達 |
| AC-3 #1392 reserve が同じ定数を参照できる（派生・Scope 由来） | 前半（契約 fixture のみ） | 定数の import と不等式の契約 fixture まで。fixture は前半の `test_limits` 系に置き、`TERMINAL_RESERVE` は fixture 内の契約値（#1392 の exec で置換）とし #1392 所有物を定義しない（R-007）。#1392 store 本体の配線は #1392 |
| AC-4（追加, R-011） | 前半 | 完全 |
| AC-5（追加, R-012） | **D-3 で #1391 後半へ移管** | 前半では実装しない（H-1391-4 / H-1391-6） |

### 前半スコープ（D-3 改訂後）

- `limits.py` に byte 定数 3 つ（`MAX_DECISION_EVENT_BYTES` / `DECISION_FIXED_OVERHEAD` / `ENVELOPE_OVERHEAD`）と導出根拠
- 最悪ケースの算定根拠（outcome 別・escape・最大桁・任意 field、切り上げ規則）
- fixture（最悪ケース event と byte 数の再現。構造の出典は `6756a597` に固定し、MC-2a で Human が突き合わせた evidence を残す）
- #1392 reserve 契約 fixture（AC-3）
- ta-118 で skip 0 件実行（AC-4）

前半から外したもの（D-3 で #1391 後半へ移管。削除せず記録として残す）: ズレ検出テスト / 定義行 sha256 照合（MC-2a'）/ 番兵（MC-3・AC-5）/ V2 tree での実照合 / 分岐明示行と必須テスト名固定リスト（MC-2b の一部・R-016）/ 関連 mutation

### 前半マージの受入条件（R-C1-02 由来、D-2 / R-001 で改訂、D-3 で縮小）

前半 PR は AC-1 系に加え、次をすべて満たすときだけ C-4 に渡す:

- MC-1: issue #1623 を Close しない。PR 本文は `Refs #1623` のみ（closing keyword を書かない）。handoff に「AC-2 未達・後半待ち」と「**後半マージまで byte 上限は I-11 で強制されていない**」を明記（R-006）
- MC-2（D-2 で改訂、R-013 / R-016 で再改訂、D-3 / R-023 で縮小・具体化）:
  - MC-2a（構造の出典の Human 突き合わせ。**CI の保証ではない**, R-013 / R-023）: C-3 時点と前半 PR の C-4 時点の 2 回実施する。
    - コマンド: `git show 6756a597:scripts/ai-loop-v2/run_event.py | sed -n '<行範囲>p'`（行範囲は監視対象 = RT-2 の各定義行。exec の T-02 で `6756a597` 上の行番号を測って evidence に記す）の出力と、fixture が前提とする構造（キー集合・`json.dumps` 引数）を並べた diff
    - 保存先: `docs/working/TASK-1623/evidence/mc2a-<時点>.txt`（`<時点>` = `c3` / `c4`。各ファイル先頭に基準 SHA `6756a597`・実施日時・行範囲を記す）
    - 確認記録: Human の確認（一致 / 不一致・日時）を `status.md` に記録し、handoff.md から参照する。実施者は Human、または AI が提示し Human が確認
  - MC-2a'（CI 上の定義行ハッシュ照合）: **D-3 で #1391 後半へ移管**（前半に写像を埋め込まない）
  - MC-2b（D-3 で縮小）: 新規テストが ta-118 で実行され `skipped=` 0 件・rc=0 であること（AC-4）を前半 PR の CI ログで確認し evidence に残す。必須テスト名固定リストと分岐明示行は D-3 で移管（H-1391-5）
  - #1391 PR の CI での実 validator 照合は #1391 後半の条件（H-1391-1 / H-1391-6）であり前半の条件ではない
- MC-3（番兵）: **D-3 で #1391 後半へ移管**（H-1391-4）。前半には写像検査も分岐も無い
- MC-4（R-015、R-022 で gate を追加）: 前半 C-4 の前に、#1391 Issue へのコメント本文案（H-1391-1〜6 のチェックリスト）と投稿先（#1391 Issue の URL）を `docs/working/TASK-1623/evidence/mc4-draft.md` に置き、Human が確認する（未確認なら C-4 に渡さない）。投稿は前半マージ後で、対外書込のため対象を名指しして承認を取る。投稿 URL を handoff に記録することを **#1623-b の C-3 前提**とする

### 残存脅威モデル（R-013 / §7-quater 打ち切り時の明記、D-3 で更新）

- 守るもの: 定数と最悪ケース fixture の byte 数の整合（fixture テスト）、テストの skip による未実行（AC-4）
- 守らないもの:
  - **前半マージ〜#1391 後半の間、`6756a597` と前半 fixture の構造ズレは CI で検出されない**。保証の主体は MC-2a の Human 突き合わせ（C-3・前半 C-4 の 2 回）と、#1391 後半の実照合（H-1391-1 / H-1391-6）
  - ta-118 の `skipped=` 判定は、テストの未収集・削除・改名による未実行を検出しない（R-016 / R-021。C-4 レビューと #1391 後半 H-1391-5 が主体）
  - 前半マージ後も byte 上限は I-11 で強制されていない（MC-1、後半が主体）
- 本検査は多層防御の 1 層。`.github/workflows/` は変更しない（HO。AI 推奨。C-3 で Human が覆せる）
- §7-quater 打ち切り: R2 で 4、R3 で 3 の新クラス → D-3 で設計モデルを変更した。完全性は主張しない

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
- 新規 fixture（例 `scripts/ai-loop-v2/fixtures/decision_event_worst_case.*`、名称は exec で確定）。outcome 別の最悪ケース event と期待 byte 数、構造の出典 SHA `6756a597` を含む。（Rev 4 の定義行 sha256・写像の埋め込みは D-3 で移管）
- fixture テストは `test_limits.py` に同居させる（ta-118 が実行する唯一のファイル）（R-003 / AC-4）。（Rev 4 の「新規ズレ検出テスト」は D-3 で #1391 後半へ移管）
- `tests/extras/ta-118-ai-loop-v2-limits.sh`（出力に `skipped=` があれば FAIL とする判定を追加。`tests/extras/` は HO 非該当。Rev 4 の `verbosity=2`・必須テスト名固定リスト・分岐明示行は D-3 で移管）
- `docs/working/TASK-1623/evidence/mc2a-c3.txt` / `mc2a-c4.txt`（MC-2a, R-023）/ `evidence/mc4-draft.md`（MC-4, R-022）
- `limits.py` の `ENVELOPE_OVERHEAD` docstring 方針: 「event 内 envelope。store 側の追加は 0（TASK-1392 plan.md:293）」（R-008）
- HO 対象パスは含まない（`scripts/hooks/` / `bin/plangate` / `schemas/` / `.github/workflows/` 非接触）。R-003 により収集は `tests/extras/` で足り `.github/workflows/` 変更は不要の見込み。不要でないと判明した場合は HO に当たるため RT-6 で停止

後半（本計画の exec 対象外。参考）: I-11 byte 検査は #1393 core の `make_decision_input`（TASK-1393 plan.md:180 / R-091）。

## Work Breakdown（前半）

1. **契約確定（owner）** Output: Q-2 表の各値の確定記録。🚩 確定前は値を書かない
2. **RED** Output: 最悪ケース fixture（outcome 別・escape・最大桁・任意 field）と区分テストが失敗する状態。`test_no_byte_constants` の置換テスト
3. **GREEN（定数）** Output: 3 定数と導出根拠（実測 byte → 切り上げ規則）。区分（input 由来 / fixed / envelope）でキー・区切りを二重計上しない
4. **ズレ検出テスト** — **D-3 で #1391 後半へ移管**（H-1391-4〜6）。前半では ta-118 の `skipped=` 判定（AC-4）だけを行う
4b. **構造の出典の Human 突き合わせ（MC-2a, R-013 / R-023）** Output: `evidence/mc2a-c3.txt`・`evidence/mc2a-c4.txt`（`git show 6756a597:scripts/ai-loop-v2/run_event.py | sed -n '<行範囲>p'` と fixture 前提構造の diff）と status.md の Human 確認記録
5. **#1392 reserve 契約 fixture** Output: `test_limits` 系に置き、`TERMINAL_RESERVE`（fixture 内の契約値）`>= 1 event and >= MAX_DECISION_EVENT_BYTES` を同じ定数 import で表現（R-007）
6. **mutation / レビュー** Output: 定数 −1、escape 無視、区分二重計上、outcome 1 種欠落、**テストを skip させる**の注入が検出されること。（Rev 4 の構造キー増減・番兵系・未収集系の mutation は D-3 で移管）。敵対レビュー 2 ラウンド
7. **前半マージ条件の確認** Output: MC-1・MC-2a（2 回目）・MC-2b・MC-4 本文案の Human 確認の evidence。🚩 未確認なら C-4 に渡さない
8. **前半マージ後の受け渡し（MC-4, R-015 / R-022）** Output: #1391 Issue への H-1391-1〜6 チェックリストコメントの URL を handoff に記録（投稿は対外書込のため実施時に名指し承認を取る）。#1623-b の C-3 前提

後半（別スライス・別 C-3）: I-11 接続（超過で `DecisionInputError`、ちょうどで受理）。#1393 core と同時かその直後。

## Verification Plan

- `python3 scripts/ai-loop-v2/test_limits.py`、TA-118、新規 fixture テスト
- mutation（上記 7）を独立コピーに注入して全て FAIL→復元で PASS
- 前半 PR の CI ログで ta-118 の `skipped=` 0 件・rc=0 を確認（MC-2b / D-3）。構造の出典は MC-2a の Human 突き合わせ evidence（R-013 / R-023）。#1391 後半での実 validator 照合は H-1391-1 / H-1391-6

### レビューレーン計画（#786）

- C-2: 設計妥当性レーン（本 plan / Q-1）+ コードベース整合レーン（run_event / limits / store）
- review-principles §7-quater: high-risk のため **2 ラウンド以上**。R2 は R1 是正（例: escape 対策、番兵、収集経路）が別経路（キー側 escape、数値桁、任意 field、V2 の印の部分一致）で漏れていないかを疑う。回避クラス台帳を review-external.md に置く
- 打ち切り（R-009）: R2 で新しい回避クラス 0 件なら終了、1 件以上なら R3（以降同じ規則）
- R2 結果（2026-11-26）: 新しい回避クラス 4 件（自己参照ハッシュ / 改名・移設による番兵の素通り / 文書だけの引き継ぎ / skip 以外の未実行）→ R3 を実施する。R3 は R-013〜R-017 の是正（Human 突き合わせ・振る舞い判定・MC-4・必須テスト名照合）の回避経路を疑う
- R3 結果（2026-11-26）: 新しい回避クラス 3 件（印の判定条件が基準 tree でも成立 / fail-closed の期待値が片方の tree に固定 / マージ後の作業に gate が無い）。§7-quater「設計モデルを疑う」に該当し、D-3 で設計モデルを変更（前半からズレ検出を外す）。R4 は実施せず、縮小後の前半は exec 後の敵対レビュー 2 ラウンド（WB6）で扱う。ズレ検出の敵対レビューは #1391 後半の責務

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
- RT-7: 前半 PR の CI ログで `skipped=` が 1 件以上、または ta-118 rc≠0（D-3 で判定を縮小。必須テスト名・分岐明示行は移管）
- RT-9（R-013 / R-023）: MC-2a の Human 突き合わせで fixture の前提構造と `6756a597` の定義行が 1 行でも不一致 → fixture と定数を測り直し C-3 / C-4 を取り直す
- RT-10（D-3）: 前半の範囲で構造ズレを CI 検出する必要が再び生じる（例: #1391 後半の着地が見込めない）→ D-3 の前提が崩れたとして Human に再判断を求める

## Stop Condition

- Q-2 の値が未確定の間は定数値を書かない
- RED のテストが 2 回の修正で GREEN にならない → 停止し報告
- I-11 を正式経路以外（暫定 core / fixture 模擬）で合格扱いにする必要が出た時点で停止
- 前半で AC-2 を合格と記載する必要が出た時点で停止

## Human Approval Boundary

- C-3（本 plan）: Human。前半のみの実装許可。後半は別 C-3
- #1393 / #1392 / #1395 の owner 確認（Q-2）
- c3.json の発行・merge・C-4: Human-owned
- MC-2a の構造突き合わせの確認（C-3 時点・前半 C-4 時点）: Human（R-013 / R-023）
- MC-4 本文案と投稿先の確認: 前半 C-4 の前に Human（R-022）
- MC-4 の #1391 Issue へのコメント投稿: 前半マージ後に対象を名指しして承認を取る（R-015）
- #1623-b の C-3: MC-4 投稿 URL が handoff にあること、H-1391-1 / H-1391-6 の evidence を条件に含める（R-015 / R-022）

## C-1 Self Review Checklist

`review-self.md` を参照。
