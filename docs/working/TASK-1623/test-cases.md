# TASK-1623 TEST CASES

## 受入基準 → テストケース マッピング

| AC | TC | スライス |
|---|---|---|
| AC-1 最悪ケース event の組み立てと byte 計算が fixture で再現 | TC-01, TC-02, TC-E01, TC-E02, TC-E03（TC-03 は D-3 で移管） | 前半 |
| AC-2 I-11 が上限超過を `DecisionInputError` にする | TC-04, TC-05, TC-E04 | 後半 |
| 派生 AC-3 #1392 reserve が同じ定数を参照 | TC-06 | 前半（契約 fixture） |
| 回帰（`test_no_byte_constants` の置換）| TC-07 | 前半 |
| AC-4 新規テストの実行確認（ta-118 で `skipped=` 0 件・`expected failures=` 0 件・`Ran 0 tests` でない・rc=0。D-3 で縮小、R-027 で拡張） | TC-10 | 前半 |
| AC-5 V2 構造着地時は写像だけの検査が FAIL し実照合へ（R-012 / R-014） | TC-11 | **D-3 で #1391 後半へ移管**（plan.md H-1391-4 / H-1391-6） |
| 前半マージ条件 MC-1 / MC-2a / MC-2b / MC-4（plan.md） | TC-08, TC-09, TC-12, TC-13 | 前半 |

## テストケース一覧

### TC-01: outcome 別の最悪ケース event の byte 数

- 前提: 構造の出典は `6756a597` の `run_event` に固定（MC-2a の Human 突き合わせ evidence で束縛。D-3 で定義行ハッシュ・写像の埋め込みは外した）
- 入力: MERGE_READY / BLOCKED / HUMAN_ESCALATED / null の各合法最悪 event
- 期待: `canonical_bytes` 相当（`6756a597:run_event.py:81-84` の `json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")`）で fixture の byte 数が再現され、最大 ≤ `MAX_DECISION_EVENT_BYTES`。前半での合格は数値の自己再現であり構造の正しさを保証しない（R-028）
- 前半の合格条件外: 最大値の event が実 `validate_event` を通ることは #1391 後半（plan.md H-1391-6、R-005 / D-3）
- 種別: unit（自動）

### TC-02: 3 定数の区分整合

- 入力: 最悪 event を input 由来 / fixed / envelope に分割
- 期待: 各区分の実測 ≤ 対応定数、`input 由来上限 + DECISION_FIXED_OVERHEAD + ENVELOPE_OVERHEAD ≤ MAX_DECISION_EVENT_BYTES`、キー・区切りの二重計上なし
- 種別: unit

### TC-03: drift 照合 — **D-3 で #1391 後半へ移管**（前半では実施しない。以下は Rev 4 の記録）

- 入力: 埋め込み写像・fixture 記録の定義行 sha256（`6756a597` の監視対象: plan.md RT-2）
- 期待: 写像から再計算した定義行ハッシュが記録値と一致（MC-2a'）。構造キーが増減したら FAIL。実行時に `git show` しない（shallow checkout 前提 / R-001）
- 位置づけ: 偶発的な破損の検出のみ。写像と記録値の同時編集は検出できない（自己参照、R-013）。写像の正しさは TC-12
- 種別: unit

### TC-08: 前半 PR の CI で skip 0 件（MC-2b / D-2 / D-3）

- 入力: 前半 PR の CI run ログ（ta-118）
- 期待: ta-118 が rc=0 で PASS、`skipped=` 0 件・`expected failures=` 0 件・`Ran 0 tests` でない（いずれかに該当すれば FAIL, R-027）。Rev 4 の必須テスト名・分岐明示行・定義行ハッシュは D-3 で移管
- 種別: 手動確認（ログ evidence 保存）

### TC-10: skip による未実行の検出（AC-4、D-3 で縮小）

- 入力: ta-118 の実行。mutation で (a) 新規テストに skip を注入、(b) 新規テストに `expectedFailure` を付与（出力は `expected failures=`）、(c) テストが 0 件収集される状態（`Ran 0 tests`）にする（R-027）
- 期待: 通常は PASS（`skipped=` / `expected failures=` なし・`Ran 0 tests` でない・rc=0）。(a)(b)(c) のいずれでも ta-118 が FAIL。判定は行頭固定の正規表現で unittest の要約行だけを対象にし、(d) テスト名や docstring などの本文に `skipped=` / `Ran 0 tests` の文字列が出ても要約行でなければ FAIL にしない（R-027 補足）
- 検出しないもの（R-027）: テスト内の早期 return・トートロジー assert。C-4 レビューと WB6 の mutation（定数 −1 等が FAIL すること）で扱う
- 移管: Rev 4 の (b) 必須テストの未収集・(c) 分岐明示行の欠落は D-3 で #1391 後半へ（plan.md H-1391-5）。前半では未収集・改名による未実行は検出しない（残存脅威モデル）
- 種別: unit / mutation

### TC-11: 一方向の番兵（AC-5 / R-014）— **D-3 で #1391 後半へ移管**（前半では実施しない。以下は Rev 4 の記録。R-018 により (a) の前提は main で成立しない）

- 入力: (a) V2 の印が全て無い tree、(b) 印の一部だけある tree、(c) V2 tree で main 用分岐を強制した版、(d) V2 tree で印（`_validate_decision` 等）を改名した版、(e) V2 tree で印を別モジュールへ移設した版
- 期待: (a) 写像検査で PASS、(b)〜(e) FAIL（振る舞いで判定するため名前の有無に依存しない）
- 種別: unit / mutation

### TC-12: 構造の出典の Human 突き合わせ（MC-2a / R-013 / R-023）

- 入力: `git show 6756a597:scripts/ai-loop-v2/run_event.py | sed -n '39,43p;52,74p;81,84p;136,171p;467,474p'`（行範囲は plan.md MC-2a に計画段階で記載, R-025）と、C-3 時点は fixture の前提構造の文章仕様（キー集合・`json.dumps` 引数）、C-4 時点は fixture 実物
- 期待: `evidence/mc2a-c3.txt`（C-3 前、T-00）・`evidence/mc2a-c4.txt`（前半 C-4 前、T-05c）に基準 SHA・日時・行範囲・diff があり、全行一致、Human の確認が status.md に記録済み。不一致なら RT-9
- 期待（R-030）: `mc2a-c3.txt` に `origin/feat/1391-phase1b-exec` の tip SHA と `git diff 6756a597 <tip> -- scripts/ai-loop-v2/run_event.py` の結果が同時に記録されている。T-02 は記録 tip からの変化だけを再確認する
- 期待（R-029 / R-033）: `mc2a-c4.txt` に fixture の blob SHA と作成時点の PR head SHA（記録 head）があり、PR 内に commit されている。H-03b 時点で `git diff --name-only <記録 head> <現 head>` が `docs/working/TASK-1623/` 配下の evidence だけを含み、fixture のパスと `scripts/ai-loop-v2/` 配下を含まない（head の一致は求めない）。T-04 / T-07 / T-09 / T-11 より後に作られている
- 種別: 手動確認（evidence 保存）

### TC-13: #1391 への受け渡し（MC-4 / R-015 / R-022）

- 期待: (0) H-1391-1〜6 の文面は正本 `docs/working/TASK-1391/c4-preconditions.md` の参照 commit（初版 `3a7373f0`）にのみあり、plan.md は ID・1 行要約（正本でない旨の明記）・commit 参照・文面ハッシュだけを持つ（R-031）。plan.md の照合手順で再計算した「## C-4 前提」節本文の sha256 が plan.md の記録値（初版 `ba4a1f16…704b`）と一致する。参照 commit が到達不能、または #1391 マージ後は、plan.md の切替条件どおり到達可能な版で一致を確かめ参照を更新している（R-035）、(1) 前半 C-4 前に `evidence/mc4-draft.md`（H-1391-1〜6 の本文案は正本の参照 commit の文面（R-026 / R-031）・投稿先）を Human が確認済み、(2) 前半マージ後に #1391 Issue へコメントがあり URL が handoff に記録されている（(2) は #1623-b の C-3 前提）、(3) TASK-1391 文書に H-1391-1〜6 の evidence がスライス B の C-4 前提として記載され、記載先と commit が status.md にある（D-4 / R-024。記載はオーガナイザー）、(4) exec 開始前に TASK-1391 の todo の C-4 行から `c4-preconditions.md` が参照されている（R-032、H-01e）
- 種別: 手動確認

### TC-09: #1623 Open 維持（MC-1）

- 期待: 前半 PR 本文に closing keyword がない（`Refs #1623` のみ）、マージ後 issue #1623 が Open
- 種別: 手動確認

### TC-04: I-11 上限ちょうどは受理

- 入力: byte 合計が上限ちょうどの `make_decision_input` 引数
- 期待: 例外なし
- 種別: unit（#1393 core 前提）

### TC-05: I-11 上限 +1 byte は拒否

- 期待: `DecisionInputError`、Decision を生成しない
- 種別: unit（#1393 core 前提）

### TC-06: reserve 契約

- 期待: 前半の `test_limits` 系に置いた契約 fixture が `limits.MAX_DECISION_EVENT_BYTES` を import し、fixture 内の契約値 `TERMINAL_RESERVE`（#1392 の exec で置換）が `>= 1 event and >= MAX_DECISION_EVENT_BYTES` を満たす。#1392 所有物を定義しない（R-007）
- 種別: unit（契約 fixture）

### TC-07: limits.py leaf 維持

- 期待: 既存 `test_imports_no_ai_loop_v2_module` / positive control が PASS、旧 `test_no_byte_constants` は削除のみで終わらず TC-01/02 に置換されている
- 種別: unit

## Edge Cases

- TC-E01: `verifier_id` 16 件 × 71 文字の ASCII 制御文字（escape 最大、#1635 の 428 byte/要素）
- TC-E02: 整数 field の最大桁（Q-2 で確定した `MAX_EVENTS_PER_RUN` と revision 上限）
- TC-E03: 任意 `artifact_ref` あり / なし、`stop_reasons` の最大合法組（重複可否は Q-2 の決定に従う）
- TC-E04: 件数上限内でも byte 超過になる入力（件数検査で止まらないこと）

## 自動化可否

TC-01 / 02 / 06 / 07 / 10 は自動化可（TC-03 / 11 は D-3 で #1391 後半へ移管）、TC-08 / 09 / 12 / 13 は手動確認。TC-04 / 05 / E04 は後半（#1623-b、#1393 core で `DecisionInputError` 導入後）で実行し、前半では実行しない。

## 検証結果（V-1 で記入）

未実施。
