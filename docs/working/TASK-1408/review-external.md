# TASK-1408 C-2 Round 1（追記専用）

- 基準: origin/main `9445df17`
- レーン: River Review（WARN）、独立検証（WARN）。どちらも LLM で、独立性は I1 相当。Codex の I2 は未実施
- 測定値（M-1〜M-3、失効後 4 merge、exit criteria 不在）は独立検証で全数一致
- オーガナイザーの実物照合: `#1487` の author = mergedBy = `s977043`、reviewDecision 空、review は COMMENTED 2 件。他は検証者の報告値で、再現していない
- 判定: 下表を plan / todo / test-cases へ 1 回反映済み。**R2 は未実施**

| ID | severity | 出所 | 指摘 | status | reflected_in | notes |
|---|---|---|---|---|---|---|
| R-001 | major | RR | `measure.sh` の再実行 hash 一致は決定性しか示さない | reflected | ME-6、Q-3、T-10 | 読まずに組み立てて集合で照合 |
| R-002 | major | RR + 検証 | exit 項目の起点が曖昧で 4 差分と未接続 | reflected | §8 文案、Q-1 | 起点を失効日に固定 |
| R-003 | major | RR | 別 issue がプレースホルダで、規定追加の扱いが未定 | reflected | Q-1、H-04、TC-11 | 起票は名指し承認 |
| R-004 | major | RR + 検証 | AC-4 の再測定の置き場所に未回答 | reflected | Q-6、テンプレート、TC-09 | |
| R-005 | major | RR | テンプレートの除外文言が自己申告の抜け道 | reflected | テンプレート | 判定は reviewer、不能は normative |
| R-006 | major | 検証 + RR | 「Human merge は確認」は証拠を超える | reflected | 差分表、文案、TC-10 | |
| R-007 | minor | RR + 検証 | Q-2 が #1329 の既存処分（次回更新で再帰へ是正）と逆 | reflected | Q-2、裁定表 | |
| R-008 | minor | 検証 | 確定の読み替えが merge 後の Q-5 に寄っている | reflected | Q-5 | C-3 で裁定 |
| R-009 | minor | 検証 | 結論と本文の不整合（4 回とも I4 必要と読める） | reflected | 結論、差分表 | 3 件 + 索引 1 件。判定は検証者の読みで確定ではない |
| R-010 | minor | RR | 文案に Human C-4 不変と semantic 判定が未記載 | reflected | 文案 | |
| R-011 | minor | RR | 既存 `reviewed_at_sha` 表に `7b523a45`（#1350）が未記載 | deferred | Q-1 の別 issue | 既存表は本 PR で触らない |
| R-012 | info | RR | `measurements.txt` の再生成と `<base>` / `<head>` 固定が todo にない | reflected | T-04 | |
| R-013 | info | 検証 | #1329 の「baseline 欄へ反映」と「baseline 不変」が字面で衝突 | reflected | 文案 | 別節に記録と説明 |
| R-014 | info | 検証 | `3331e5c4` は squash で「merge 前 / 時」は厳密でない | reflected | 文案 | |

## 回避クラス台帳

| クラス | 代表例 | 検出 | 是正 | 前の工程が見つけられなかった理由 |
|---|---|---|---|---|
| 主体の推定 | `mergedBy` を Human と読む | R1 | 機械証跡なしと明記 | C-1 が値の一致だけを確認 |
| 証跡の循環 | 同じスクリプトの再実行で hash 一致 | R1 | 独立に組み立てる | 決定性と独立性を分けて見ていなかった |
| 自己申告の抜け道 | 「索引のみ」の申告で I4 を回避 | R1 | reviewer 判定 | テンプレートを脅威として見ていなかった |

## Human 裁定（2026-11-06）

Q-1〜Q-6 はいずれも plan の推奨どおり。Human の返信は「y」。別 issue の起票は未承認で、C-3 時に名指しで確認する。C-3 自体は未承認。

## C-2 Round 2（2026-11-07）

- 基準: origin/main `9445df17`（照合時に ls-remote で不変を確認）
- レーン: 敵対レビュー 1 体。同系 LLM で独立性は I1 相当。Codex の I2 は未実施
- 判定: **FAIL**
- オーガナイザーの照合: R2-9 / R2-10 の文言（plan L138、L148）のみ確認。他はレビュアーの報告値で、再現していない
- 反映: **未反映**。Human の判断待ち

| ID | severity | 指摘 | status | reflected_in | notes |
|---|---|---|---|---|---|
| R2-9 | major | exit 項目の「または別 issue で裁定」で、将来の変更も I4 を免除できる | open | | 記録時点の列挙 commit と記録以後を分ける。Replan Trigger の該当は Human が判断 |
| R2-10 | major | template の reviewer は LLM でもよく、R-005 の是正が効いていない | open | | non-normative の確定は Human に限る |
| R2-11 | major | machine evidence の定義が §7 と template にない | open | | 最低要件を失効節に書く |
| R2-12 | major | ME-6 の独立性が成立していない | open | | evidence と plan を除いて実行し、assertion と明記 |
| R2-13 | major | 証跡が自己参照になり、head が動く。PR 番号も canon に入らない | open | | 測定対象を固定 SHA に |
| R2-14 | minor | 再測定の置き換えが §7 既存本文と二重規定 | open | | |
| R2-15 | minor | TC-11 の検査語に抜け | open | | |
| R2-16 | minor | T-05 が H-04 に未依存、TC-E02 の範囲誤り | open | | |

### 回避クラス台帳（R2 追記）

| クラス | 代表例 | 検出 | 是正 | 前の工程が見つけられなかった理由 |
|---|---|---|---|---|
| 判定主体の未指定 | reviewer、別 issue の裁定 | R2 | 未反映 | R1 は申告の抜け道を塞いだが、判定者の資格を見なかった |
| 証跡の自己参照 | head の測定結果を同じ head に commit | R2 | 未反映 | R1 は決定性と独立性を分けたが、測定対象の固定を見なかった |

### 収束判定

未収束。

### 反映記録（2026-11-07）

Human の「ｙ」を受け、R2-9 を Replan Trigger 該当として扱い、R2-9〜R2-16 を plan / todo / test-cases へ反映した（上表の status は記録時点の値として残す）。R2-14 は §7 L331 の実物で確認した。

## C-2 Round 3（2026-11-07）

- レーン: Codex 敵対レビュー（I2、read-only、静的照合のみ）。rollout: `~/.codex/sessions/2026/11/07/rollout-2026-11-07T09-37-15-01a1b370-2994-7d53-a5bb-06cb4e629bcf.jsonl`
- 判定: **FAIL**。オーガナイザー照合: R3-5 の根拠は計画の文面で確認（再測定の終了を追記しつつ ME-4 は削除 0 で不変と扱う）。他は Codex の読みで、再現していない
- 反映: **未反映**。新クラスが出たので停止し、Human に報告する

| ID | severity | 指摘 | status | notes |
|---|---|---|---|---|
| R3-4 | major | `<canon-sha>` 固定後に `measure.sh` と出力を変更できる | open | 新クラス。R2-13 の是正が生んだ穴 |
| R3-5 | major | 削除 0 では、追記による規定の上書きを検出できない | open | 新クラス |
| R3-6 | major | ME-1〜5 の独立性の根拠が決定性だけで、作成者外の実行者が未定 | open | 証跡の循環と同型 |
| R3-7 | minor | issue 作成と番号照合のタスクがない | open | 検証の順序外れと同型 |

### 回避クラス台帳（R3 追記）

| クラス | 代表例 | 検出 | 是正 | 前の工程が見つけられなかった理由 |
|---|---|---|---|---|
| 固定点と証跡の結合不足 | 固定後の `measure.sh` 変更 | R3 | 未反映 | R2 は canon の自己参照だけを見た |
| 差分形状による意味判定 | 削除 0 の追記で規則を終了 | R3 | 未反映 | R1 / R2 は差分の形を不変の証拠として疑わなかった |

未収束（新クラス 3 ラウンド連続）。

### 反映記録（2026-11-07）

Human の「ｙ」を受け、R3-4〜R3-7 を反映した（上表の status は記録時点の値）。R4 は行わず、未収束のまま打ち切る可否を C-3 に諮る。反映後のレビューは未実施。

## C-3（2026-11-07）

Human 判定: **CONDITIONAL**（選択式の回答）。未収束のまま計画レビューを打ち切り、pbi-input を確定した。別 issue は名指し承認のうえ #1643 として起票し、番号とタイトルを照合した。C-3 の確定反映は完了。残りは Human の c3.json 発行（確定後の plan_hash）。

## exec レビュー記録（T-08 / T-09。追記専用）

> exec レビューの指摘は C-2 と衝突しないよう **R-101 以降**で採番する。

### 対象と範囲

- 対象: canon commit `80e49220`（下書き clone）。転記後の canon commit は `e5573cc8`
- ラウンド: X-R1〜X-R5（exec 後のレビュー。オーガナイザーが実施し、作成者へ是正を指示した）
- `reviewed_at_sha`: 各ラウンドの対象は下書き clone の SHA であり、転記後の SHA ではない。**転記後の `reviewed_at_sha` はレビュアーが記録する**（status.md「記録欄」）
- 出典: 各ラウンドの是正指示と、status.md「回避クラス台帳」。severity が指示に無かった指摘は「未記載」と書き、推測で補わない

### 監査表（exec）

| R-NNN | status | reflected_in | notes |
| --- | --- | --- | --- |
| R-101 | reflected | evidence commit（measure.sh） | X-R1 / minor。numstat が空のときの失敗メッセージを「差分なし」にする |
| R-102 | reflected | canon commit（`phase0-migration.md` 失効節） | X-R2 R2-a / minor。`9445df17` までの 4 commit の扱いは #1643 の Human 裁定に従うと明記。plan 文案からの軽微な逸脱（status.md 記録済み） |
| R-103 | reflected | evidence commit（make-manifest.sh / regen.sh） | X-R2 R2-b / major。manifest の手書きをやめて生成する。固定検査を入れる。再生成を 1 本にまとめる。TC 検査を repo 内に置く |
| R-104 | reflected | evidence commit（measure.sh） | X-R2 R2-c / minor。ヘッダの SHA を `rev-parse` で正規化する |
| R-105 | reflected | evidence commit（manifest 宣言 + check.sh 全数照合） | X-R3 R3-a / R3-b / severity 未記載。固定対象が宣言されていない（canon commit への別ファイル混入、`C^ ≠ B`、別系統の C、stale evidence）。継ぎ当てをやめて作り直した |
| R-106 | reflected（設計変更。防御はしない） | evidence commit（位置づけの格下げ） | X-R4 / severity 未記載。同じ commit で check.sh / measure.sh と manifest を同時に書き換えると通る（自己参照）。repo 内の照合は書き換え忘れの検出に限定し、信頼の起点を commit 外の記録と Human C-4 へ移した |
| R-107 | reflected | evidence commit（check.sh） | X-R4 R4-b / minor。declared-me1 で `mergedAt` も照合する |
| R-108 | reflected | evidence commit（check.sh） | X-R4 R4-c / minor。clean-tree が FAIL なら以降を実行せず非 0 で終える |
| R-109 | reflected | evidence commit（check.sh、status.md） | X-R4 / info。検査力のない TC-08 の digest 変化テストを削除し、TC-08 の主張を縮小した（計画からの逸脱。status.md 記録済み） |
| R-110 | reflected | evidence commit（check.sh 引数、status.md 手順 2） | X-R5 R5-a / severity 未記載。記録と照合せずに実行できる（r5.sh T1）。停止条件（HEAD / `reviewed_at_sha` / digest）を追加。T1 は rc=3 |
| R-111 | reflected | evidence commit（check.sh / make-manifest.sh / regen.sh） | X-R5 R5-b / severity 未記載。VERIFY を REPRO-CHECK に改名し、文言を格下げ後の位置づけに合わせた |
| R-112 | reflected | evidence commit（status.md 記録欄） | X-R5 R5-c / severity 未記載。記録者はレビュアーとした。TODO が残る間は C-4 に渡さない |

### 回避クラス台帳との対応

| クラス（status.md 台帳） | 検出ラウンド | 対応する R-NNN |
| --- | --- | --- |
| 測定入力の非正規化 | X-R2 | R-103, R-104 |
| 固定対象の未宣言 | X-R3 | R-105 |
| 自己参照 | X-R4 | R-106 |
| 記録と照合せずに実行できる | X-R5 | R-110 |

R-101、R-102、R-107〜R-109、R-111、R-112 は新しいクラスではない（同型の是正漏れ、文言、または記録の不足）。

### 収束判定（exec）

- canon 文案（`phase0-migration.md` / テンプレート）: X-R2 の R2-a（minor）以外に新しいクラスは出ていない
- evidence 層: X-R2〜X-R5 の 4 ラウンド続けて新しいクラスが出た。§7-quater の「打ち切り方」に従って X-R5 で打ち切った（オーガナイザー判断）。収束したとは主張しない。残存脅威モデルは status.md にある
- §3 / §4 の弱化の指摘: 作成者に届いた是正指示には含まれていない。各ラウンドの原文での有無はレビュアーが確認する
