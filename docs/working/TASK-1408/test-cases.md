# TASK-1408 TEST CASES（C-3 CONDITIONAL / c3.json 未発行）

共通: 検証は commit 指定で行い作業ツリーに依存しない。`<base>` = exec 開始時の origin/main、`<head>` = PR head、`P` = `docs/ai/ai-loop-v2/phase0-migration.md`。文字列の照合は `grep -F`。

## 受入基準 → テストケース マッピング

| 受入基準 | テストケース | 備考 |
| --- | --- | --- |
| 1408-AC-1 | TC-01 | |
| 1408-AC-2 / 1329-AC-1 | TC-02 | 負の対照を含む |
| 1408-AC-3, 4 / 1329-AC-2 | TC-03 | |
| 1408-AC-5 | TC-04 | |
| 1329-AC-3 | TC-05 | |
| 1329-AC-5 | TC-06 | |
| 1408-AC-6 | TC-07, TC-08 | |
| 1329-AC-4 | TC-09 | |
| 1408-AC-7 | TC-10 | 手動 |

## Verification Trace

| Trace Type | 内容 | Source | テストケース |
| --- | --- | --- | --- |
| Invariant | INV-01: §3 / §4 不変 | Human 指示、#1329 Out of scope | TC-07 |
| Invariant | INV-02: baseline 不変 | §7 判定規則、#1408 Safety | TC-08 |
| Invariant | INV-03: 既存本文の削除なし | `経緯` 節の保存方針 | TC-07 |
| Contract | CONTRACT-01: 失効後差分を隠さない | Iron Law #4 | TC-E02 |

## テストケース一覧

### TC-01: merge SHA の一次証拠

- 対応 AC: 1408-AC-1 / 種別: integration
- 入力: `gh pr view 1402 --json state,mergedAt,mergeCommit`、`git show <head>:P`
- 期待出力: API の oid `3331e5c49751b268412d4db8e5862982ac0005d8` が §7 に完全一致で 1 件以上。`<base>` では失効節に存在しない
- 期待値の出所: 既存実装（GitHub 記録）

### TC-02: M-1〜M-3 の 3 時点

- 対応 AC: 1408-AC-2, 1329-AC-1 / 種別: integration
- 入力: `sh docs/working/TASK-1408/evidence/measure.sh`
- 期待出力: `3331e5c4^1` で M-1 `(none)`、M-2 0 ファイル、M-3 が baseline 4 行と完全一致。`3331e5c4` で M-2 に `scripts/ai-loop-v2/run_state.py` を含む。M-3 の集合が baseline の真の上位集合。件数は assert しない
- 期待値の出所: 既存実装

### TC-03: 失効と I4 の明記

- 対応 AC: 1408-AC-3, 4, 1329-AC-2 / 種別: manual + grep
- 入力: `<head>:P`
- 期待出力: 「例外の失効」節に失効日 `2026-09-29`、動いた条件 M-2 / M-3、以後 I4 を含む。`<base>` では同節 0 件
- 期待値の出所: 既存実装（§7 規定）

### TC-04: 非遡及

- 対応 AC: 1408-AC-5 / 種別: manual + grep
- 期待出力: 新節に Phase 0 / 0.1 の I1 が有効なまま残る旨がある。既存の `reviewed_at_sha` 行と exit criteria が `<base>` と byte 一致

### TC-05: exit criteria

- 対応 AC: 1329-AC-3 / 種別: grep
- 期待出力: `<head>` に `### Phase 1 exit criteria` と canon 7 I4 の行が各 1 件。`<base>` では 0 件

### TC-06: 残指摘の裁定

- 対応 AC: 1329-AC-5 / 種別: manual
- 期待出力: 指摘 2 / 4 / 5 の裁定が表にあり、Human が H-00 で承認済み

### TC-07: 規定の不変

- 対応 AC: 1408-AC-6, INV-01, INV-03 / 種別: integration
- 入力: `git diff --exit-code <base> <head> -- <canon のうち phase0-migration 以外の 6 本>`、`git diff --numstat <base> <head> -- P`
- 期待出力: 6 本の差分なし。`P` の削除数 0
- 備考: 変更前でも一部成立するため、head に新節があること（TC-03）と組で意味を持つ。削除 0 は規定の意味の不変を示さない。意味の変更は PR 本文の列挙と C-4 で判断する

### TC-08: baseline 不変と独立再実行

- 対応 AC: 1408-AC-6, INV-02 / 種別: integration
- 入力: 両 SHA の §7 baseline ブロック抽出、別 context の実行者が `measure.sh` を読まず組み立てたコマンド
- 期待出力: ブロック byte 一致、ファイル集合が `measurements.txt` と一致。集合の一致は assertion として記録し、機械証跡に数えない。`git diff --exit-code <canon-sha> <head> -- docs/ai/ai-loop-v2 .github/PULL_REQUEST_TEMPLATE.md` が空。最終 head で `manifest.txt` の blob SHA と digest が一致（`measure.sh` を 1 byte 変えると不一致になる負の対照つき）

### TC-09: AC-4 の置き場所

- 対応 AC: 1329-AC-4 / 種別: grep
- 期待出力: テンプレートに canon 7 の項目 1 件。再測定の置き換え、CI 単独不可、Human のみが non-normative を確定できる旨の文言を含む。§7 に I4 の最低要件と、再測定の 2 つの時機の終了がある。§7 の裁定表に再測定の行がある。`<base>` では 0 件。CI 緑

### TC-10: Human merge

- 対応 AC: 1408-AC-7 / 種別: manual
- 期待出力: merge 後の `gh pr view` の `mergedBy` が `s977043`。これは Human を機械的に示さないので、C-4 の名指し承認の記録を PR または handoff で確認する。**本 PR の本文では充足を宣言しない**

### TC-11: 未置換プレースホルダ

- 対応 AC: Q-1 / 種別: grep
- 入力: `<head>:P`
- 期待出力: `<別 issue>`、`<PR 番号>`、`<記録時 SHA>`、`<base>`、`<実測>`、`2026-11-XX`、`<canon 7 本>`、`<!-- Q-1`、`（Q-1）`、`（Q-5）` が新節と §8 新設節でいずれも 0 件

## Edge Cases

### TC-E01: 検出器の素通り（異常系）

- Trace: INV-02
- 入力: `measure.sh` の語彙を空に変えた変異、または不在 SHA
- 期待出力: 空出力で PASS せず非 0 終了（fail-closed）。陽性対照 `run_state.py` 未検出で FAIL

### TC-E02: 失効後差分の漏れ（境界）

- Trace: CONTRACT-01
- 入力: `git log --first-parent 3331e5c4..<base> -- <canon 7 本>`
- 期待出力: 記録時点までの全 commit が §7 の差分一覧に含まれる。exec 中に増えたら追加

### TC-E03: 親 commit の取り違え（境界）

- Trace: 1408-AC-2
- 入力: `git rev-parse 3331e5c4^1`、`git rev-list --parents -n1 3331e5c4`
- 期待出力: `^1` が main 側の親で、記録の「merge 前」と一致（実測 `50fe9d5f`）

## Convention Evidence

| 規約の記述 | 実値 | 一致 | 判定 |
| --- | --- | --- | --- |
| §7 M-3 baseline 4 ファイル | `3331e5c4^1` の測定が 4 行完全一致 | ✅ | 採用 |
| 依頼: M-2 merge 時 6、現在 11 | 再測定 6、11 | ✅ | 採用（測定値としてのみ。契約にしない） |
| 依頼: M-3 merge 時 9、現在 13 | 再測定 9、13 | ✅ | 採用（同上） |

## 自動化可否

| テストケース | 自動化 | 理由 / 代替手段 |
| --- | --- | --- |
| TC-01, 02, 05, 07, 08, 09, E01〜E03 | 可（`measure.sh`、CI には載せない） | CI は過去 SHA を持たない見込み（未確認） |
| TC-03, 04, 06 | 一部 | 意味判定はレビューと C-4 |
| TC-10 | 不可 | Human 操作 |

## 検証結果（V-1 で記入）

未実施。
