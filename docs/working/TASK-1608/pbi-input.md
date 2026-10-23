# TASK-1608 PBI INPUT PACKAGE

> 出典: [#1608](https://github.com/s977043/plangate/issues/1608)（Refs #1545 / #1574）
> 作成: 2026-10-24（AI 起草。Human の確認対象）

## Context / Why

`scripts/improvement_seed_delta.py`（#1574 で導入、Growth Harness L2 の seed→digest 差分棚卸し）は
`improvement-seeds.md` / `improvement-digest.md` を正規表現で検査している。
#1574 で敵対レビューを 4 ラウンド回したところ、**毎ラウンド新しい回避クラスが出た**（R1〜R4）。
[`review-principles.md`](../../../.claude/rules/review-principles.md) §7-quater の収束判定では、
これは打ち切りどきではなく**設計モデル（正規表現による Markdown の構造推定）そのものを疑うとき**に当たる。
R4 時点で HTML コメント内の seed の計上・BOM 以外の不可視文字・先頭語 no / na の人名の誤拒否が
「残存脅威」として docstring に残っている。

## What（Scope）

### In scope

- `scripts/improvement_seed_delta.py` の構造判定（見出し・コードブロック・HTML ブロック・リスト項目）を、
  CommonMark のブロック構造規則に従う**行単位の状態機械（ブロックパーサー）**へ置き換える
- 不可視文字（ZWSP / ZWJ / ZWNJ / WORD JOINER / BOM の文中出現 / NBSP 等）の扱いを決め、実装する
- `scripts/test_improvement_seed_delta.py` に回避クラス台帳の全クラスの回帰ケースを置く
- docstring の残存脅威モデルを新設計に合わせて書き直す

### Out of scope

- digest #002 の生成・superseded / 却下欄（#1545 の残り）
- `confirmed_by` の真正性（Human 認証）。出力の `authority` は `READ_ONLY_UNVERIFIED_MARKER_NO_PROMOTION` のまま
- 出力 JSON のスキーマ（キー・値域）の変更
- `.github/workflows/` / `requirements/` への依存追加（HO パス。Q-1 で Human が不採用と決定、2026-10-24）
- `improvement-seeds.md` / `improvement-digest.md` の内容変更

## 受入基準

| ID | 受入基準 |
|----|---------|
| AC-1 | 既存の `scripts/test_improvement_seed_delta.py`（22 件）と `tests/extras/ta-116-improvement-seed-delta.sh` が全件 PASS する |
| AC-2 | HTML コメント / HTML ブロック内の seed 見出し・`confirmed_by` を数えない（seed とも確認値とも扱わない） |
| AC-3 | 現行データ（main の seeds / digest）で `REVIEW_CANDIDATE` / 7 / 5 が変わらない |
| AC-4 | R1〜R4 の回避クラス台帳の全クラスに、少なくとも 1 件の回帰ケースがあり PASS する |
| AC-5 | 不可視文字を含む見出し・確認値は fail-closed（拒否）になるか、正規化後に正規形と一致した場合だけ受理される。どちらにするかを plan で確定し、テストで固定する |
| AC-6 | `confirmed_by` の否定値（`no`, `n/a`, `no（後で確認）`, `no, later` 等）は従来どおり拒否する。先頭語が否定値と同綴りの正当な人名（例: `Na Yeon`, `No Kim`）の扱い（安全側の誤拒否を残すか）を plan で確定し、テストで固定する。`naoki` のような先頭語が否定値でない名前は受理する |
| AC-7 | 構造判定に正規表現による Markdown 全体の構造推定（`re.MULTILINE` での見出し全文走査・行マスク置換）を使わない。正規表現の使用は 1 行内の字句判定（日付形式など）に限る |
| AC-8 | ta-70 の PG-SH-GUARD 正典ブロックとのバイト一致を保つ（ta-70 PASS） |
| AC-10 | （Q-3 決定、2026-10-24）issue の「CommonMark 準拠の Markdown パーサー（AST）」は「判定に使うブロック種別（fenced code / HTML block / indented code / ATX 見出し / 段落・リスト）は CommonMark の規則に従い、守備範囲外の構造（blockquote・ネストした見出し・setext 見出し）は日付を含めば fail-closed」と読み替える |
| AC-9 | 新しい外部依存を追加しない（標準ライブラリのみ）。追加が必要と判断した場合は exec 前に停止し Human 判断を仰ぐ |

## Notes from Refinement

- issue 本文の提案は「CommonMark 準拠の Markdown パーサー（AST）」。リポジトリには Markdown パーサーの依存が無く
  （`markdown_it` 等は未導入、CI の Python 依存は `requirements/schema-validate.txt` のハッシュ固定のみ）、
  依存追加は `.github/workflows/*.yml`（HO パス）の変更を伴う。plan では**標準ライブラリのみのブロックパーサー**を推奨案とし、
  依存追加案は代替案として Human 判断に残す（Q-1）。

## Estimation Evidence

- Risks: 自作パーサーは CommonMark の全規則を持たない。対象を「本検査が判定に使うブロック種別」に限定し、
  範囲外の構造は fail-closed で拒否する設計にしないと、新しい回避クラスが再び出る
- Unknowns: 不可視文字を「拒否」と「正規化」のどちらにするか（AC-5）
- Assumptions: seeds / digest のフォーマット正本は `docs/ai/retro-phase.md` のテンプレート（`## <date ISO8601> — <task_id>` / `- confirmed_by: <human>`）
