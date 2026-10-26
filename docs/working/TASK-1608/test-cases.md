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
| AC-10 | TC-BLK-01〜05, TC-HTML-01〜04 |
| AC-11 | TC-CB-01〜07, TC-INT-03, TC-NEST-N1〜N3 |
| AC-10（改訂 2） | TC-NEST-A / B / 03〜07 |
| AC-10 / AC-11（改訂 3） | TC-NEST-C4〜C7 / N4〜N6、TC-DIFF-*、TC-CORPUS-* |

## 改訂 3（2026-10-26 / plan D-1d・検証モデル）

### 列の上限なしの入れ子（D-1d / R-001）

前提: 正規の seed の後に続ける。拒否側の期待は `ValueError`（nested container）。

| ID | 入力 | 期待 |
|----|------|------|
| TC-NEST-C4 | `- confirmed_by: alice` / `    - x` / 空行 / `        confirmed_by: rejected`（R7 の再現） | 拒否 |
| TC-NEST-C5 | `- a` / 列 5 の `> b` | 拒否 |
| TC-NEST-C6 | `- a` / 列 6 の `- b` | 拒否 |
| TC-NEST-C7 | `> a` / `>` の後に 7 空白 + `- b` | 拒否 |
| TC-NEST-N4 | `- a` / 列 4 の地の文の継続 | 受理（誤拒否しない） |
| TC-NEST-N5 | `- a` / 空行 / 列 2 の fence 内に列 6 の `- x` | 受理（コードの中は数えない） |
| TC-NEST-N6 | `> a` / `> 本文に - を含む` | 受理 |

### 差分テスト（V-A / V-B / R-002・R-005〜R-010・R-012）

| ID | 内容 | 期待 |
|----|------|------|
| TC-DIFF-01 | seed 0〜19,999 の生成入力を 4 値で判定 | MISMATCH 0・FALSE_REJECT 0 |
| TC-DIFF-02 | 生成件数（4 値 AGREE / REJECT / FALSE_REJECT / MISMATCH の合計）・参照パーサーの版・準拠 spec 版の assert（wheel ハッシュは pip `--require-hashes` に任せ assert しない。R-016） | 合計 20,000 件・`markdown-it-py` 4.2.0・spec 版が記録と一致 |
| TC-DIFF-03 | 軸別（各軸の各値）の `out_of_scope=False` かつ AGREE の件数（R-017） | 各軸値で下限以上（下限は T-25 で実測して決定）。REJECT 率・全体割合はログに記録のみ |
| TC-DIFF-04 | `SEED_DELTA_REFERENCE=1` で参照パーサーが import できない / 変数未設定 | 前者は FAIL（skip しない）、後者は `SKIP: SEED_DELTA_REFERENCE unset` を出力 |
| TC-DIFF-05 | 陽性対照: `ca9a8b33` / `1c26e9de` の旧実装で差分テスト | それぞれ MISMATCH または FALSE_REJECT ≥ 1 |
| TC-DIFF-06 | `reference_view` / `out_of_scope` の射影規則ごとの手書き期待値。`out_of_scope=False` が期待される入力（列 2 以上の段落継続・リスト内 fence・同じ深さの blockquote 継続・トップレベルの複数項目）を含む（R-015） | 全件一致 |
| TC-DIFF-07 | 差分ハーネスが impl を import していない（参照側モジュールの import グラフ） | impl の import 0 件（positive control: impl を import した疑似モジュールで検出 1） |
| TC-DIFF-08 | 生成器がコンテナマーカー直前の不可視文字を生成する | 該当ケース ≥ 1 件、すべて REJECT |
| TC-DIFF-09 | 証跡: seed 範囲・版・spec 版・実行時間をログに出力 | ログに 4 項目 |
| TC-DIFF-10 | 実行時間（`SEED_DELTA_MINIMIZE=0`）が E-1 の上限内。CI では最小化せず失敗 seed のみ出力（R-018） | 上限内（上限は T-26 で実測して決定、CI step `timeout-minutes` 以内） |

### コーパス（V-C / R-003）

| ID | 内容 | 期待 |
|----|------|------|
| TC-CORPUS-01 | `improvement-seeds.md` 全 7 リビジョン | FALSE_REJECT 0・全件 AGREE |
| TC-CORPUS-02 | `improvement-digest.md` 全 1 リビジョン | 同上 |
| TC-CORPUS-03 | fixture 件数と blob SHA の照合 | 8 件・記録と一致 |

### 変異注入（E-5、改訂 3 追加分）

「常に `ValueError`」「常に空集合で受理」、`reference_view` の level 判定・トップレベル判定・節境界、D-1d の列上限の復活、
`out_of_scope` の過大変異（常に True / 列 2 以上で True。改訂 4 / R-015）を各 1 変異とし、すべて KILLED。

### HO 適用スクリプト（改訂 4 / R-013・R-014。AI は dry-run のみ）

| ID | 内容 | 期待 |
|----|------|------|
| TC-HO-01 | `apply-test-yml.sh --dry-run`（AI 実行） | rc=0、forward apply possible |
| TC-HO-02 | patch 適用後の test.yml を `yaml.safe_load` で解析（スクラッチ複製で確認） | 2 step に hashFiles ガード、差分 step に env 2 つと `timeout-minutes` |
| TC-HO-03 | main 上での apply / rollback（Human の手順確認） | ABORT（feature ブランチ必須） |

## コンテナ境界（改訂 2026-10-24 / plan D-1b）

前提: 正規の seed `## 2026-01-01 — A` / `- confirmed_by: alice` の後に続ける。期待はすべて `ValueError`（container boundary）。

| ID | 入力（空行を挟まない） | 期待 | 由来 |
|----|---------------------|------|------|
| TC-CB-01 | `- note` / `> q` / `  ```` / `## 2026-09-09 — HIDDEN` / `- confirmed_by: bob` | 拒否 | 敵対レビュー R4 の再現 |
| TC-CB-02 | `- note` / ```` ``` ```` / `x` / ```` ``` ```` / `  ```` / `## 2026-09-09 — HIDDEN` | 拒否 | R4（列 0 の閉じた fence 経路） |
| TC-CB-03 | `- note` / `***` / `  ```` / `## 2026-09-09 — HIDDEN` | 拒否 | R4（thematic break 経路） |
| TC-CB-04 | `- note` / `<div>` | 拒否 | R4（HTML 経路、レビュアー未実走分） |
| TC-CB-05 | `- note` / `## 2026-09-09 — B` | 拒否 | ATX 見出しでの切り替え |
| TC-CB-06 | `> q` / `- item` | 拒否 | blockquote → リスト |
| TC-CB-07 | `> q` / `***` | 拒否 | blockquote → thematic break |

## 入れ子コンテナ（改訂 2 2026-10-25 / plan D-1c）

AC 対応: AC-10（守備範囲外の構造は fail-closed）/ AC-11（現行データで誤拒否なし）。期待はすべて `ValueError`（nested container）。

| ID | 入力 | 期待 | 由来 |
|----|------|------|------|
| TC-NEST-A | `- a` / `  > b` / 空行 / `  ```` / `## 2026-01-01 — TASK-1` / `- confirmed_by: alice` / `  ```` / 空行 / `## 2026-01-02 — TASK-2` / `- confirmed_by: bob` | 拒否（現実装は TASK-1 を黙って落とし rc=0） | 敵対レビュー R6 の再現 A（fence 版） |
| TC-NEST-B | 再現 A の fence を `  <div>` に替えたもの（`- a` / `  > b` / 空行 / `  <div>` / `## 2026-01-01 — TASK-1` / …） | 拒否 | R6 の再現 B（div 版） |
| TC-NEST-03 | `> - a`（blockquote 内のリスト、同じ行） | 拒否 | 定義 1 |
| TC-NEST-04 | `- > a`（リスト内の blockquote、同じ行） | 拒否 | 定義 1 |
| TC-NEST-05 | `- a` / `  - b`（リスト内のリスト） | 拒否 | 定義 2 |
| TC-NEST-06 | `> a` / `> > b`（blockquote 内の blockquote） | 拒否 | 定義 1・3 |
| TC-NEST-07 | `1. a` / `   - b`（番号付きリスト内のリスト） | 拒否 | 定義 2 |

入れ子でないことを固定する正常系（受理）:

| ID | 入力 | 期待 |
|----|------|------|
| TC-NEST-N1 | `> a` / `> b`（同じ深さの blockquote の継続） | 受理 |
| TC-NEST-N2 | `- a` / `- b` / `- c`（トップレベルのリストの複数項目） | 受理 |
| TC-NEST-N3 | `- a` / 空行 / `  ```` / `  x` / `  ```` / 空行 / 正規 seed（リスト内の fence） | 受理、seed を数える |

拒否しないことを固定する正常系:

| ID | 入力 | 期待 |
|----|------|------|
| TC-CB-N1 | `> a` / `> b`（blockquote の継続）、`- a` / `- b`（リストの継続）、`- a` / `  b`（インデント継続） | 受理 |
| TC-CB-N2 | `- a` / `lazy text`（段落の継続） | 受理 |
| TC-CB-N3 | `- a` / 空行 / `## 2026-…`（空行で閉じる） | 受理 |

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
| TC-INT-03 | 現行 seeds / digest で CLI 実行 | REVIEW_CANDIDATE / 7 / 2 / 5（コンテナ境界規則による誤拒否なし = AC-11） |

## エッジケース

- 空ファイル / 見出しゼロ → 既存どおり `no seed entries found`
- `confirmed_by` が 2 行 → 既存どおり拒否
- fence と HTML コメントの入れ子（fence 内の `<!--`、コメント内の ```）→ 外側のブロックだけが有効（TC-HTML / TC-R3 の組み合わせを exec で 1 件追加）

## 変異注入（S5）

状態遷移ごとに 1 変異を入れ、上表のいずれかが FAIL することを `evidence/test-runs/` に記録する。
FAIL しない変異があれば、そのテストは空振りとして追加・修正する。
