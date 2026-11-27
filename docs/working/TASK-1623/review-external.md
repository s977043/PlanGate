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

## Round 3（2026-11-26、対象 `9b607be1` の plan Rev 4。§7-quater: R2 是正そのものを疑う）

| R-NNN | severity | 出典 | 指摘 | 反映方針 |
|---|---|---|---|---|
| R-018 | critical | R3 | 番兵の印（振る舞い判定）が main でも真になる。main の `run_event.py:50` に `"decision_made": {"decision"}` があり（実物確認済み）、必須 4 key の event は main validator も受理する。main 上で「印あり」と判定され V2 用分岐に入る | 対象消滅（D-3）: 番兵を前半から外し #1391 後半へ移管（H-1391-4） |
| R-019 | major | R3 | 判定中の例外を「印なし」に倒すと main 用分岐へ素通りする。3 値化（印あり / 印なし / 判定不能=FAIL）が要る | 対象消滅（D-3）: 番兵ごと移管。3 値化は #1391 後半の設計条件として H-1391-4 に残す |
| R-020 | major | R3 | 分岐明示行の期待値が tree 依存。main で「main 用分岐」を固定すると #1391 PR で FAIL、どちらでも可にすると偽造可 | 対象消滅（D-3）: 分岐明示行を前半から外す。前半 ta-118 は分岐を持たない |
| R-021 | major | R3 | ta-118 の必須テスト名固定リストは、テストと固定リストの同時改名や部分一致で素通りする | 反映（縮小）: 前半の AC-4 は「ta-118 で `skipped=` 0 件・rc=0」に戻し、必須テスト名照合は前半から外す（D-3）。同時改名の残存は残存脅威モデルに記載、名前照合の要否は #1391 後半へ（H-1391-5） |
| R-022 | major | R3 | MC-4（#1391 Issue への投稿）がマージ後で gate が無く、投稿漏れを止められない | 反映: 本文案と投稿先を前半 C-4 前に evidence 化し Human が確認。マージ後の投稿 URL を handoff に残すことを #1623-b の C-3 前提にする |
| R-023 | minor | R3 | MC-2a の evidence の形式・保存先が未定 | 反映: `git show 6756a597:scripts/ai-loop-v2/run_event.py \| sed -n '<行範囲>p'` の出力と写像の diff を `evidence/mc2a-<時点>.txt` に保存し、Human の確認記録を status.md に残す |

### §7-quater 打ち切り記録（R3）

- 新しい回避クラス: R2 = 4 件、R3 = 3 件。収束しないため、§7-quater「毎ラウンド新しいクラスが出続けるなら設計モデルそのものを疑う」に該当
- 根: main に存在しない構造（V2 `decision_made`）を main 上で照合する設計。番兵・分岐明示行・ハッシュ照合はいずれもこの前提の上に積んだ防御だった
- 対応: Human 決定 D-3（2026-11-26）で設計モデルを変更。前半からズレ検出を外し、実照合・番兵・ズレ検出は構造が実在する #1391 後半へ移す
- 打ち切りは完全性を主張しない。残存脅威モデルを plan.md で更新（前半マージ〜#1391 後半の間、構造ズレは CI で検出されない。保証の主体は MC-2a の Human 突き合わせと #1391 後半の実照合）

## Round 4（2026-11-26、対象 `e518a58c` の plan Rev 5。§7-quater: D-3 後の縮小設計そのものを疑う）

| R-NNN | severity | 出典 | 指摘 | 反映方針 |
|---|---|---|---|---|
| R-024 | major | R4 | D-3 で移管した H-1391-1〜6 は TASK-1623 の plan と MC-4（issue コメント）にしか無く、#1391 側の gate にならない（D-2「#1391 側の文書は変えない」が受け手の gate を作らせない） | Human 決定 D-4（2026-11-26）で閉じる。TASK-1391 の文書にスライス B の C-4 前提として H-1391-1〜6 の evidence を記載（TASK-1391 の plan.md と c3.json は変えない）。H-1391-3 も含める。#1623-b の C-3 条件を H-1391-1〜6 すべての evidence に拡張。MC-4 は残すが gate の主体は #1391 の C-4 前提 |
| R-025 | major | R4 | C-3 時点の MC-2a が実行不能: 行範囲は exec の T-02、fixture は T-03 で作られ、いずれも C-3（H-03）より後 | 行範囲の特定を計画段階に前倒しし、`6756a597:scripts/ai-loop-v2/run_event.py` の行範囲を plan に実物で記載。C-3 時点の MC-2a は「行範囲と、fixture の前提構造を文章で書いた仕様（キー集合・`json.dumps` 引数）の突き合わせ」に限定。fixture 実物との突き合わせは C-4 時点の 1 回。todo の依存を修正 |
| R-026 | minor | R4 | H-1391-1 / H-1391-2 が D-3 前の言い方（前半のズレ検出テスト・V2 用分岐・番兵）のままで、読み替え注記に頼っており H-1391-4（番兵不要の可能性）と食い違う。MC-4 本文案にも旧文面が入る | H-1391-1 / H-1391-2 を「#1391 後半で新設する実照合」と「その実行確認」の文面に書き直す。MC-4 チェックリスト本文には書き直し後の文面を入れる |
| R-027 | minor | R4 | `skipped=` 判定の残存脅威が未記載: テスト内の早期 return・トートロジー assert、`expectedFailure`（出力は `expected failures=`）、`Ran 0 tests` はいずれも rc=0 | 残存脅威モデルに追記。ta-118 は `Ran 0 tests` と `expected failures=` も FAIL とする（AC-4 / Files / TC 更新） |
| R-028 | info | R4 | AC-1 の前半達成は validator 通過を含まず「数値の自己再現」にとどまる。定数の切り上げ幅の根拠が無い | AC-1 前半達成を「数値の自己再現」と明記。切り上げ幅は「構造が出典から外れたときに起き得る最大の byte 増」に対する余裕として根拠づける方針を plan に記載 |

### §7-quater 推移（R4）

- 新しい回避クラス: R2 = 4 件、R3 = 3 件、R4 = 1 件（「gate の判定材料がその gate の後に作られる」）。D-3 後に減少したが 0 ではない
- R-024 / R-026 / R-027 / R-028 は既存クラス（文書だけの引き継ぎ / skip 以外の形での未実行）の同型の再検出または精度の指摘

## Round 5（2026-11-26、対象 `ba206960` の plan Rev 6。§7-quater: R4 是正そのものを疑う）

| R-NNN | severity | 出典 | 指摘 | 反映方針 |
|---|---|---|---|---|
| R-029 | major | R5 | 既知クラス「gate の判定材料が gate の後に作られる」の是正漏れ: `evidence/mc2a-c4.txt`（T-05c）は T-03 直後に作れ、以後の T-04 / T-07 / T-09 で fixture が変わっても作り直されない | T-05c の依存に T-09・T-11 を追加し前半 C-4 前の最後に作るタスクにする。evidence に fixture の blob SHA と PR head SHA を記録し、H-03b でその SHA が PR head と一致することを確かめる |
| R-030 | major | R5 | 同型の是正漏れ: C-3 時点の `mc2a-c3` は `6756a597` の行範囲を前提にするが、tip が行範囲を変えていないかを測る T-02 が C-3 の後 | T-00 で `origin/feat/1391-phase1b-exec` の tip SHA と RT-2 の diff 結果を `mc2a-c3.txt` に同時記録。T-02 は「C-3 で記録した tip から変わっていないか」の再確認にする |
| R-031 | minor | R5 | 新クラス（正本循環）: H-1391-1〜6 の文面が TASK-1623 plan と `docs/working/TASK-1391/c4-preconditions.md`（commit `3a7373f0`、未マージ）の両方にあり、改訂が伝わらず判定版が決まらない | 正本は `c4-preconditions.md` とし、TASK-1623 plan は ID と 1 行要約（正本でないと明記）と commit 参照のみにする。文面変更時は両方を同じ変更で更新する規則を書く |
| R-032 | info | R5 | exec 開始条件に、TASK-1391 の todo の C-4 行から `c4-preconditions.md` が参照されていることが無い | H-01d 付近に exec 開始条件として追加。TASK-1391 の status / todo には別セッションの未 commit 変更があり未追記のため、Human 側の扱い待ちとして Human タスクに残す |
| （補足）R-027 | — | R5 | ta-118 の判定方法が未規定 | 行頭固定の正規表現（例 `^Ran 0 tests$`）とし、対象を unittest の要約行に限ると AC-4 / Files に明記 |

### §7-quater 推移（R5）

- 新しい回避クラス: R2 = 4 件、R3 = 3 件、R4 = 1 件、R5 = 1 件（正本循環, R-031）
- R-029 / R-030 は既存クラス「gate の判定材料がその gate の後に作られる」の同型の再検出（是正漏れ）。R-032 は R-031 の受け手側の確認

## Round 6（2026-11-26、対象 `a02089f1` の plan Rev 7。§7-quater: R5 是正そのものを疑う）

| R-NNN | severity | 出典 | 指摘 | 反映方針 |
|---|---|---|---|---|
| R-033 | major | R6 | 既知クラス「gate の判定材料が gate の後に作られる」の是正漏れ（R-029 の自己参照）: `mc2a-c4.txt` を PR に commit するとその commit で head SHA が動き、記録 head と現 head が一致しない | 照合対象を「記録 head から現 head までの diff に fixture のパスと MC-2a 対象の変化が無いこと」に変更。evidence は PR 内に commit し、diff に evidence 自身（`docs/working/TASK-1623/`）の追加だけが出ることを許容 |
| R-034 | minor | R6 | T-05c の depends_on に T-04 / T-07 が無く本文（T-04 / T-07 / T-09 / T-11 の後）と不整合 | depends_on に T-04 / T-07 を追加 |
| R-035 | major | R6 | 既知クラス「正本循環」の是正漏れ: 参照先 `3a7373f0` は `origin/feat/1391-phase1b-exec` にしか無く rebase / squash で到達不能になる。正本と plan は別ブランチで「同じ変更で両方更新」は守れない | plan に正本「## C-4 前提」節本文の sha256 を記録し再計算手順を書く。#1391 マージ後は main 上のパス＋commit に参照を切り替える条件を定める。改訂規則を「正本 commit → plan の参照・ハッシュ更新」の順序規則に書き直す |

### §7-quater 推移（R6）と収束判定

- 新しい回避クラス: R2 = 4、R3 = 3、R4 = 1、R5 = 1、**R6 = 0 → 収束**（回避クラス台帳への追加なし）
- R-033 は「gate の判定材料が gate の後に作られる」、R-035 は「正本循環」の同型の再検出（是正漏れ）。R-034 は整合の指摘
- 打ち切りは完全性を主張しない。残存脅威モデルは plan.md「残存脅威モデル」節（Rev 8 で更新）を参照

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
| R-018 | 対象消滅（D-3） | 66bb1a45 | plan D-3・MC-3・H-1391-4、TC-11 を移管表記 |
| R-019 | 対象消滅（D-3） | 66bb1a45 | plan H-1391-4（3 値化を設計条件として引き継ぎ） |
| R-020 | 対象消滅（D-3） | 66bb1a45 | plan AC-4・MC-2b・H-1391-6、todo T-05b、TC-08/TC-10 |
| R-021 | reflected（縮小） | 66bb1a45 | plan AC-4・残存脅威モデル・H-1391-5、todo T-05b、TC-10 |
| R-022 | reflected | 66bb1a45 | plan MC-4・受け渡し・Human 境界、todo T-05d/T-12/H-03c/H-05、TC-13 |
| R-023 | reflected | 66bb1a45 | plan MC-2a・Files・WB4b、todo T-02/T-05c/H-03/H-03b、TC-12 |
| R-024 | reflected | 5b92ff27 | Human 決定 D-4。plan D-4・引き継ぎ節・MC-2・MC-4・WB8・Human 境界、todo H-01d/H-05/依存、TC-13 (3)。TASK-1391 文書への記載はオーガナイザー（未実施） |
| R-025 | reflected | 5b92ff27 | plan MC-2a（行範囲を実測記載・C-3 は文章仕様・C-4 は fixture 実物）・WB4b、todo T-00/T-02/T-05c/H-03/H-03b/依存、TC-12 |
| R-026 | reflected | 5b92ff27 | plan H-1391-1/2 書き直し・受け渡し・MC-4、todo T-05d、TC-13 |
| R-027 | reflected | 5b92ff27 | plan AC-4・MC-2b・残存脅威モデル・Files・WB4・Verification・RT-7、todo T-05b/T-11、TC-08/TC-10 |
| R-028 | reflected | 5b92ff27 | plan AC-1 割当・残存脅威モデル・WB3、TC-01 |
| R-029 | reflected | 45811756 | plan MC-2a（C-4 時点）、todo T-05c/H-03b/依存、TC-12 |
| R-030 | reflected | 45811756 | plan MC-2a（C-3 時点、例: tip `3a7373f0` で diff 空）、todo T-00/T-02、TC-12 |
| R-031 | reflected | 45811756 | plan 引き継ぎ節（正本 `TASK-1391/c4-preconditions.md` @ `3a7373f0` を参照、改訂規則）・受け渡し・Human 境界、todo H-01d、TC-13 (0)(1)。R-027 補足も同 commit（AC-4・Files・T-05b・TC-10） |
| R-032 | reflected（Human 待ち） | 45811756 | plan Human 境界の exec 開始条件、todo H-01e/依存、TC-13 (4)。TASK-1391 todo への追記は Human 判断待ち |
| R-033 | reflected | 792972bd | plan MC-2a（C-4 時点）・残存脅威モデル、todo T-05c/H-03b、TC-12 |
| R-034 | reflected | 792972bd | todo T-05c depends_on・依存関係節 |
| R-035 | reflected | 792972bd | plan 引き継ぎ節（文面ハッシュ・照合手順・参照切替条件・順序規則）・残存脅威モデル、TC-13 (0) |

## 回避クラス台帳（追記専用）

| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
|---|---|---|---|---|
| 自己参照検査 | main 上で埋め込み写像を同じ写像と比較し常に一致 | R1 | R-001 | C-1 は作成者と同一で、CI checkout 深度を測っていなかった |
| 未収集の緑 | 新規テストが ta-118 / run-tests に載らず、または skip で rc=0 | R1 | R-003 | C-1 は収集経路（ta-118 の実行対象）を実測していなかった |
| 自己参照ハッシュ | 写像と fixture 記録ハッシュを同じ commit で同時に書き換えると CI の照合が PASS | R2 | R-013 | R1 は「実行時に `git show` できない」を写像の埋め込みで塞いだが、埋め込んだ写像と記録値が同じ信頼境界（同一 PR で編集可能）に入ることを検査モデルに持っていなかった |
| 名前の改名・移設による番兵の素通り | `_validate_decision` を別名に改名、または別モジュールへ移すと「印が全て無い」と判定され main 用分岐に入る | R2 | R-014 | R1 の番兵は印の集合を名前で列挙する設計で、R1 の mutation（印の部分一致・分岐強制）も名前が残る前提だった。別名・別経路は §7-quater 2 ラウンド目焦点 1 の型で、R1 時点では是正が未設計 |
| 文書だけの引き継ぎ（責任の空白） | H-1391-1〜3 が本 TASK の plan にしか無く、#1391 の C-4 で誰も参照しない | R2 | R-015 | R1 の R-002 是正（D-2）で条件を #1391 側へ移したことで新たに生まれた穴。R1 は循環依存の解消だけを見ており、移した先に受け手がいるかを検査していなかった |
| skip 以外の形での未実行 | テスト名の未収集・分岐の未通過・早期 return で `skipped=` が出ず rc=0 | R2 | R-016 | R1 の R-003 是正は未実行を skip の一形態として扱い、`skipped=` の文字列判定に寄せた。未実行の他の形を列挙していなかった |
| 印の判定条件が基準 tree でも成立 | main の `EVENT_PAYLOAD_KEYS` に `decision_made` があり、必須 4 key の event を main validator が受理するため「印あり」と判定される | R3 | R-018 / R-019（D-3 で対象消滅） | R2 の R-014 是正は改名・移設への耐性（V2 tree 側で偽陰性にならないこと）だけを見て、振る舞い判定の各条件が main（基準 tree）で偽になるかを実物で測っていなかった |
| fail-closed の期待値が片方の tree に固定 | 分岐明示行の期待を「main 用分岐」に固定すると #1391 PR で FAIL、どちらでも可にすると偽造可 | R3 | R-020（D-3 で対象消滅） | R2 の R-016 是正は main 上の未実行検出だけを設計し、同じ検査が V2 tree でも走ることを検査モデルに含めていなかった（両端で緑を確かめていない） |
| マージ後の作業に gate が無い | MC-4 の #1391 Issue への投稿がマージ後で、投稿漏れでも誰も止めない | R3 | R-022 | R2 の R-015 是正は受け手を作ることに集中し、その作業自体がどの gate の前提にもならない時点に置かれたことを見ていなかった |
| gate の判定材料がその gate の後に作られる | C-3 時点の MC-2a（`evidence/mc2a-c3.txt`）が、exec の T-02（行範囲の測定）と T-03（fixture 作成）の成果物を前提にしている。exec 開始は C-3（H-03）の後 | R4 | R-025 | R1〜R3 は各検査の中身（判定条件・照合対象・期待値・受け手）を見ており、gate と工程（todo の depends_on と exec 開始条件）の時間順を突き合わせていなかった。R3 の R-023 是正は MC-2a の形式（行範囲は T-02 で測る）を決めたが、T-02 が C-3 後の exec 工程であることを照合しなかった |
| 正本循環 | 2 文書がそれぞれ相手を正本・gate 主体と書き、片方が未マージ commit に固定されて改訂が伝わらず判定版が決まらない | R5 | 正本を 1 文書に定め他方は commit 参照のみ（R-031） | R4 の R-024 是正（D-4）は受け手側に gate を作ることだけを見て、同じ文面が 2 文書に複製されること（どちらが正本か・改訂の伝播）を検査モデルに持っていなかった。受け手文書は R4 時点で未作成で、実物を読めなかった |
