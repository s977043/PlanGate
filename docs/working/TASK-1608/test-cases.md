# TASK-1608 Test Cases

> 実装先: `scripts/test_improvement_seed_delta.py`（unittest）。統合: ta-116 / ta-70。
> 「既存」は main（`dd7a0204` 時点）の 22 件に既にあるテスト。exec ではこれらを**変更せず**残し、新規分を追加する。

## 受入基準 → テストケース

| AC | テストケース |
|----|-------------|
| AC-1 | TC-INT-01, TC-INT-02, 既存 22 件 |
| AC-2 | TC-R4-02, TC-HTML-01〜04 |
| AC-3 | TC-INT-03 |
| AC-4 | TC-R1-*, TC-R2-*, TC-R3-*, TC-R4-* |
| AC-5 | TC-INV-01〜04 |
| AC-6 | TC-R2-06, TC-R4-03, TC-NEG-01〜02 |
| AC-7 | TC-STRUCT-01 |
| AC-8 | TC-INT-02 |
| AC-9 | TC-STRUCT-02 |

## 回避クラス台帳 → 回帰ケース（AC-4）

| ID | 台帳 | 入力（最小再現） | 期待 | 既存/新規 |
|----|------|----------------|------|----------|
| TC-R1-01 | R1 改行越え | `- confirmed_by:` の次行に `- reason: x` | `ValueError` confirmation marker | 既存 `test_empty_confirmation_does_not_take_next_line` |
| TC-R1-02 | R1 表記ゆれ | `## 2026-06-09 - task-C` / `### 2026-06-09 — task-C` | `ValueError` canonical | 既存 `test_noncanonical_seed_heading_is_rejected` |
| TC-R1-03 | R1 重複節 | `## 対象エントリ` が 2 つ | `ValueError` more than one | 既存 |
| TC-R1-04 | R1 プレースホルダ | `confirmed_by: <Human>` | `ValueError` | 既存 |
| TC-R2-01 | R2 lookalike 5 形式 | 全角空白 / NBSP / H1 / 行頭空白 / 日付が先頭に無い | `ValueError` canonical | 既存 `test_lookalike_seed_headings_are_rejected` |
| TC-R2-02 | R2 区切り | `##2026-...` / `##\t2026-...` | `ValueError` canonical | 既存（同上） |
| TC-R2-03 | R2 fence 内見出し | fence 内の非正規見出し | 受理（数えない） | 既存 |
| TC-R2-04 | R2 fence 内確認値 | 見出しは外、`confirmed_by` は fence 内 | `ValueError` | 既存 |
| TC-R2-05 | R2 fence 内 seed | `~~~` 内に正規 seed | 数えない（1 件） | 既存 |
| TC-R2-06 | R2 否定値 | `no` / `No` / `false` / `-` / `n/a` / `なし` / `no（後で確認）` | `ValueError` | 既存 |
| TC-R3-01 | R3 未閉 fence | ``` / ~~~ が閉じない | `ValueError` unclosed | 既存 |
| TC-R3-02 | R3 閉じ条件 | ```` を ``` / ``` を ~~~ / ~~~~ を ~~~ / ``` を ``` info | `ValueError` unclosed | 既存 |
| TC-R3-03 | R3 長い閉じ | ```` を ````` で閉じる | 受理 | 既存 |
| TC-R4-01 | R4 BOM | 先頭 BOM 付き seed / digest | 先頭 seed を数える | 既存 |
| TC-R4-02 | R4 HTML コメント内 seed | `<!--\n## 2026-06-09 — task-C\n- confirmed_by: human\n-->` | 数えない（seed 件数不変） | **新規**（現行は数える = RED） |
| TC-R4-03 | R4 人名 | `confirmed_by: Na Yeon` | Q-4 の決定どおり（推奨: `ValueError` を固定） | **新規** |

## 新しい構造の検査

| ID | 入力 | 期待 | 種別 |
|----|------|------|------|
| TC-HTML-01 | 未閉の `<!--`（EOF まで）の後ろに seed | `ValueError`（unclosed HTML comment） | 新規 / fail-open 防止 |
| TC-HTML-02 | 1 行の `<!-- ## 2026-06-09 — x -->` | 数えない | 新規 |
| TC-HTML-03 | `<!--` 内の `- confirmed_by: human` だけを持つ seed | `ValueError` confirmation marker | 新規 |
| TC-HTML-04 | `<div>` HTML ブロック（type 6）内の seed、空行で終了後に正規 seed | 前者は数えず後者は数える | 新規 |
| TC-BLK-01 | `> ## 2026-06-09 — x`（blockquote） | `ValueError`（守備範囲外の日付見出し） | 新規 |
| TC-BLK-02 | `- ## 2026-06-09 — x`（リスト内見出し） | `ValueError` | 新規 |
| TC-BLK-03 | setext 見出し（`2026-06-09 — x` + `---`） | `ValueError` | 新規 |
| TC-BLK-04 | 4 空白 indented code 内の seed | 数えない | 新規 |
| TC-BLK-05 | 4 空白インデントの fence（コードとして扱われる） | fence として開かない（後続 seed を数える） | 新規 |
| TC-BLK-06 | CRLF 改行のファイル | LF と同じ結果 | 新規 |
| TC-INV-01 | 見出しに ZWSP（`## 2026-06-09​ — x`） | `ValueError` | 新規（現行 RED 想定） |
| TC-INV-02 | 文中 BOM / WORD JOINER を含む見出し | `ValueError` | 新規 |
| TC-INV-03 | `confirmed_by: ​no`（ZWSP 前置） | `ValueError` | 新規 |
| TC-INV-04 | digest の索引行に ZWSP | `ValueError` | 新規 |
| TC-NEG-01 | `confirmed_by: naoki` / `nobu` | 受理 | 新規（現行挙動の固定） |
| TC-NEG-02 | `confirmed_by: no, later` / `no　後で`（全角空白） | `ValueError` | 新規 |

## 構造・統合

| ID | 内容 | 期待 |
|----|------|------|
| TC-STRUCT-01 | `improvement_seed_delta.py` に `re.MULTILINE` / `re.DOTALL` / 行マスク置換が無い（`grep` の positive control つき） | 0 件（positive control は 1 件以上） |
| TC-STRUCT-02 | import が標準ライブラリのみ | `python3 -I` で import 成功、サードパーティ import 0 件 |
| TC-INT-01 | `sh tests/extras/ta-116-improvement-seed-delta.sh` | 2 passed / 0 failed |
| TC-INT-02 | `sh tests/extras/ta-70-py-sh-misinvocation-guard.sh` | failed 0 |
| TC-INT-03 | 現行 seeds / digest で CLI 実行 | REVIEW_CANDIDATE / 7 / 2 / 5 |

## エッジケース

- 空ファイル / 見出しゼロ → 既存どおり `no seed entries found`
- `confirmed_by` が 2 行 → 既存どおり拒否
- fence と HTML コメントの入れ子（fence 内の `<!--`、コメント内の ```）→ 外側のブロックだけが有効（TC-HTML / TC-R3 の組み合わせを exec で 1 件追加）

## 変異注入（S5）

状態遷移ごとに 1 変異を入れ、上表のいずれかが FAIL することを `evidence/test-runs/` に記録する。
FAIL しない変異があれば、そのテストは空振りとして追加・修正する。
