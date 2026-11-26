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

## Round 2（2026-11-26、対象 `ca60a335` の plan Rev 3。§7-quater: R1 是正そのものを疑う）

| R-NNN | severity | 出典 | 指摘 | 反映方針 |
|---|---|---|---|---|
| R-013 | critical | R2 | 自己参照ハッシュ: shallow checkout の CI では `6756a597` を読めず、MC-2a「写像から再計算したハッシュ＝fixture 記録値」は fixture 内で閉じた照合になる（写像と記録値を同時編集すれば PASS） | `.github/workflows/` は変更しない（オーガナイザー判断・AI 推奨。C-3 で Human が覆せる）。MC-2a を CI の保証とは書かず、「C-3 時点と前半 PR の C-4 時点で `git show 6756a597:scripts/ai-loop-v2/run_event.py` と fixture の写像を突き合わせた evidence（Human、または AI が提示し Human が確認）」に格下げ。CI のハッシュ照合は「偶発的な破損の検出」とだけ位置づける。残存脅威に記載 |
| R-014 | critical | R2 | 改名・移設で番兵が素通り: 番兵が V2 の印を名前の有無で判定するため、印の改名や別モジュールへの移設で「印が全て無い」と判定され main 用分岐に入る | 番兵を振る舞いで判定（`run_event` が V2 形式の `decision_made` を受理するか、`EVENT_PAYLOAD_KEYS` の該当 key の有無、validator 呼び出し結果）。mutation に「印を改名」「別モジュールへ移設」を追加 |
| R-015 | major | R2 | 文書だけの引き継ぎ: H-1391-x は plan にしか無く、#1391 側で誰も拾わない責任の空白になる | MC-4 追加: 前半マージ時に #1391 の Issue へ H-1391-x をチェックリストとしてコメントし URL を evidence 化（投稿は前半マージ時の todo。今は投稿しない）。#1623-b の C-3 条件に「H-1391-1 の evidence」 |
| R-016 | major | R2 | skip 以外の未実行: `skipped=` の文字列判定だけでは、テスト未収集・分岐未通過を検出できない | `verbosity=2` で実行し必須テスト名を ta-118 側の固定リストと照合。「main 用分岐を通った / V2 用分岐を通った」を明示行で出力して照合。AC-4 の定義を `skipped=` だけにしない |
| R-017 | minor | R2 | 切替手順の欠落: 印の導入と V2 分岐 PASS が別 PR になると番兵 FAIL の部分着地が起き得る。FAIL 時の対処が無い | H-1391-2 に「印の導入と V2 分岐の PASS は同一 PR。部分着地 PR は作らない」「番兵 FAIL 時は revert か同一 PR 内で是正」を明記 |

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
| R-013 | reflected | 60540c4d | plan MC-2a/MC-2a'・残存脅威モデル・WB4b・RT-9・Human 境界、todo T-05c/H-03/H-03b、TC-03/TC-12。`.github/workflows/` 不変は AI 推奨（C-3 で Human が覆せる） |
| R-014 | reflected | 60540c4d | plan MC-3・AC-5・WB4/6、todo T-05/T-08、TC-11(d)(e) |
| R-015 | reflected | 60540c4d | plan 受け渡し節・MC-4・WB8・Human 境界、todo T-12/H-05、TC-13 |
| R-016 | reflected | 60540c4d | plan AC-4・MC-2b・Files・WB4/6・RT-7、todo T-05b/T-08/T-11、TC-08/TC-10 |
| R-017 | reflected | 60540c4d | plan H-1391-2 |

## 回避クラス台帳（追記専用）

| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
|---|---|---|---|---|
| 自己参照検査 | main 上で埋め込み写像を同じ写像と比較し常に一致 | R1 | R-001 | C-1 は作成者と同一で、CI checkout 深度を測っていなかった |
| 未収集の緑 | 新規テストが ta-118 / run-tests に載らず、または skip で rc=0 | R1 | R-003 | C-1 は収集経路（ta-118 の実行対象）を実測していなかった |
| 自己参照ハッシュ | 写像と fixture 記録ハッシュを同じ commit で同時に書き換えると CI の照合が PASS | R2 | R-013 | R1 は「実行時に `git show` できない」を写像の埋め込みで塞いだが、埋め込んだ写像と記録値が同じ信頼境界（同一 PR で編集可能）に入ることを検査モデルに持っていなかった |
| 名前の改名・移設による番兵の素通り | `_validate_decision` を別名に改名、または別モジュールへ移すと「印が全て無い」と判定され main 用分岐に入る | R2 | R-014 | R1 の番兵は印の集合を名前で列挙する設計で、R1 の mutation（印の部分一致・分岐強制）も名前が残る前提だった。別名・別経路は §7-quater 2 ラウンド目焦点 1 の型で、R1 時点では是正が未設計 |
| 文書だけの引き継ぎ（責任の空白） | H-1391-1〜3 が本 TASK の plan にしか無く、#1391 の C-4 で誰も参照しない | R2 | R-015 | R1 の R-002 是正（D-2）で条件を #1391 側へ移したことで新たに生まれた穴。R1 は循環依存の解消だけを見ており、移した先に受け手がいるかを検査していなかった |
| skip 以外の形での未実行 | テスト名の未収集・分岐の未通過・早期 return で `skipped=` が出ず rc=0 | R2 | R-016 | R1 の R-003 是正は未実行を skip の一形態として扱い、`skipped=` の文字列判定に寄せた。未実行の他の形を列挙していなかった |
