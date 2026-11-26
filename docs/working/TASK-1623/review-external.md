# TASK-1623 外部レビュー結果（C-2）

> 追記専用。計画本体への反映は 1 回で確定する（`.claude/rules/working-context.md`「review-external.md」節）。
> レーン: D = 設計妥当性レーン / C = コードベース整合レーン。両レーンの重複は 1 件に統合し出典を併記する。

## Round 1（2026-11-26、対象 `ac0b11c8` の plan Rev 2）

| R-NNN | severity | 出典 | 指摘 | 反映方針 |
|---|---|---|---|---|
| R-001 | critical | D-01 / C-03(major) | MC-3 は main 上で写像と写像の自己比較になり素通りする。CI は shallow checkout（`.github/workflows/test.yml:22-25` に fetch-depth なし）のため実行時に `git show 6756a597` できない | 写像をリポジトリに埋め込み、`6756a597` の定義行の sha256 を fixture に記録して照合。main 用検査は「V2 の印が全て無い」ときだけ許可し、一部だけある・#1391 マージ後に main 用分岐へ入る場合は FAIL（一方向の番兵）。mutation に「V2 tree で main 用分岐を強制」を追加 |
| R-002 | critical | D-02 / C-01(major) | MC-2（#1391 PR の CI で実行確認）が前半 C-4 の前提となり循環依存 | Human 決定 D-2（2026-11-26）で解決。前半 CI は定義行ハッシュ一致と skip 0 件、実 validator 照合は #1391 の C-4 前提へ移す |
| R-003 | major | C-02 | 新規テストは ta-118（`tests/extras/ta-118-ai-loop-v2-limits.sh:40-48` は `test_limits.py` 1 本を実行し rc=0 で PASS）にも run-tests にも自動収集されず、unittest の skip は rc=0 | `test_limits.py` に同居させるか ta-118 に実行行を追加し、出力に `skipped=` があれば FAIL。`tests/extras/` で足り `.github/workflows/` 変更不要 |
| R-004 | major | C-04 / D-05 | 写像と RT-2 の監視対象が不足。`<head>` が未定義で SHA 到達不能時に照合できない | 監視対象に `EVENT_PAYLOAD_KEYS["decision_made"]`・`_validate_decision`・`canonical_bytes` の `json.dumps` 引数（`ensure_ascii=False`）・`_validate_append_only`（`6756a597:run_event.py:467` 付近）を追加。`<head>` = `origin/feat/1391-phase1b-exec` の tip と #1391 PR の merge commit。定義行ハッシュで照合可能にする |
| R-005 | major | D-03 | TC-01「最大値 event が `validate_event` を通る」は main では実行不能 | main 上は byte 計算の再現を合格条件にし、validator 通過は V2 tree 用検査（#1391 側条件）へ寄せる |
| R-006 | major | D-04 | 後半の I-11 の数え方が Q-2 と食い違う可能性。前半マージ後に上限が未強制である事実が handoff に無い | 後半向け Replan trigger を予約（食い違えば定数を測り直す）。MC-1 の handoff に「後半マージまで上限は強制されていない」を明記 |
| R-007 | minor | C-05 / D-08 | TC-06 の #1392 reserve 契約 fixture が #1392 所有物を定義しかねない | 前半の `test_limits` 系に置き、`TERMINAL_RESERVE` は fixture 内の契約値（#1392 の exec で置換）とする |
| R-008 | minor | C-06 | `ENVELOPE_OVERHEAD` の範囲が曖昧 | docstring 方針に「event 内 envelope。store 側の追加は 0（TASK-1392 plan.md:293）」 |
| R-009 | minor | D-06 | §7-quater の打ち切り条件が機械値でない | 「R2 で新しい回避クラス 0 件なら終了、1 件以上で R3」 |
| R-010 | minor | D-07 | RT-3 の owner 確認に期限が無い | 期限 5 営業日 |
| R-011 | AC 候補 | C | 「CI 上 skip 0 件、ta-118 は `skipped=` を FAIL 判定」 | AC として採否を plan に記載 |
| R-012 | AC 候補 | C | 「V2 `decision_made` 構造が main に着地したら写像だけの検査は FAIL し実照合へ切替」 | AC として採否を plan に記載 |

## 監査表

| R-NNN | status | reflected_in(commit) | notes |
|---|---|---|---|
| R-001 | reflected | 1e133ce6 | plan MC-3・Files・WB4/6、todo T-05/T-08、TC-03/TC-11 |
| R-002 | reflected | 1e133ce6 | Human 決定 D-2。plan D-2・MC-2・H-1391-1〜3・RT-7、todo T-11、TC-08 |
| R-003 | reflected | 1e133ce6 | plan Files・WB4、todo T-05b、TC-10 |
| R-004 | reflected | 1e133ce6 | plan Files・RT-2・H-1391-3、TC-03 |
| R-005 | reflected | 1e133ce6 | plan AC-1 割当、TC-01 |
| R-006 | reflected | 1e133ce6 | plan MC-1・RT-8、todo T-10 |
| R-007 | reflected | 1e133ce6 | plan AC-3 割当・WB5、todo T-07、TC-06 |
| R-008 | reflected | 1e133ce6 | plan Files |
| R-009 | reflected | 1e133ce6 | plan レビューレーン計画、todo T-09 |
| R-010 | reflected | 1e133ce6 | plan RT-3、todo H-02 |
| R-011 | reflected | 1e133ce6 | 採用 → AC-4（前半） |
| R-012 | reflected | 1e133ce6 | 採用 → AC-5（前半は番兵、実照合 PASS は #1391 側） |

## 回避クラス台帳（追記専用）

| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
|---|---|---|---|---|
| 自己参照検査 | main 上で埋め込み写像を同じ写像と比較し常に一致 | R1 | R-001 | C-1 は作成者と同一で、CI checkout 深度を測っていなかった |
| 未収集の緑 | 新規テストが ta-118 / run-tests に載らず、または skip で rc=0 | R1 | R-003 | C-1 は収集経路（ta-118 の実行対象）を実測していなかった |
