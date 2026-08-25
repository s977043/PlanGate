# C-1 チェック項目数の参照規約（#960 再発防止）

> Status: 決定済み（2026-08-25）
> 対象 issue: [#960](https://github.com/s977043/plangate/issues/960)
> 機械検査: `scripts/check-c1-item-count.py`（`tests/extras/ta-77-c1-item-count.sh` 経由で `tests/run-tests.sh` から実行）

## 背景

C-1 セルフレビューのチェック項目数が複数のドキュメントに数値で直書きされ、
正本を更新しても追随しなかった。その結果、同じ 1 つの事実に対して
`15` / `17` / `20` / `25` の 4 通りの値が repo 内に同時に存在した（#960）。

原因は「数値そのものを各所で再宣言していた」構造であり、個別の値を直しても
次に正本が増減した時点で同じ乖離が再発する。

## 決定

1. **正本は [`docs/working/templates/review-self.md`](../working/templates/review-self.md) の
   「C-1 チェック項目数（正本）」表**とする。項目の実体は同ファイルの
   `### C1-` 見出しであり、表の合計はその実数と一致していなければならない。
2. **他ドキュメントは項目数を数値で直書きしない。正本を参照する。**
   本文には「全項目」「Plan 項目のみ」のように**区分名で書く**。
3. やむを得ず数値を書く場合は、**正本から導出できる値に限る**
   （表の合計 / 表の区分ごとの数 / 簡易版 `C1-PLAN-01`〜`07` の数）。
   導出できない数を書いた時点で機械検査が落ちる。
4. **項目数を契約値として複写しない。** 項目数は追加 PBI で増減する。
   実測は `grep -c '^### C1-' docs/working/templates/review-self.md`。

## 強制（機械検査）

`scripts/check-c1-item-count.py` が 2 点を検査する。

| # | 検査 | 落ちる条件 |
|---|------|-----------|
| 1 | 正本の自己整合 | 「合計」の宣言値が `### C1-` 見出しの実数と一致しない |
| 2 | 他ドキュメントの追随 | 走査対象の `*.md` に、正本から導出できない項目数の直書きがある |

- 走査対象: `.claude` / `plugin/plangate` / `docs/ai` / `docs/workflows` / `.agents` / `.codex` の `*.md`
- **許容値を定数で持たない**（すべて正本から導出する）。定数で持つと、
  正本を更新したときに検査器自身が古い値を守り続ける。
- 検査器は項目 ID の形を仮定しない。ID は `C1-PLAN-01` / `C1-PLAN-08-AEE` /
  `C1-SUP-PLAN-01` / `C1-TODO-RB` / `C1-B1B2-16` / `C1-SCOPE-DISC-01` と
  形が揃っておらず、`C1-[A-Z]+-[0-9]+` のような決め打ちは**少なく数える**。
- 回帰テスト: `tests/extras/ta-77-c1-item-count.sh`
  （陰性コントロール / 正本の自己整合ズレ / 導出不能な直書き / 除外パスの 4 系統と、
  各注入が実際に効いていることの実証）。

## 限界（この規約と検査が守らないもの）

- **数値を伴わない誤りは検出しない。** 項目の**内容**が正本と食い違う記述
  （例: 存在しない項目名を挙げる、区分の意味を取り違える）は検出対象外。
- **`docs/working/` 配下は走査対象外。** 過去の TASK 記録は当時の値のまま
  残ってよい（記録の書き換えはしない）。
- **`.claude/worktrees/` は走査対象外。** エージェント作業用 worktree は
  任意時点のコピーであり、正本の状態を表さない。
- 走査対象外のディレクトリ（例: `README.md` 直下や `docs/` 直下）に新たに
  直書きが増えた場合は検出できない。必要になった時点で走査 root を足す。

## 参照

- 正本: [`docs/working/templates/review-self.md`](../working/templates/review-self.md)
- 検査器: `scripts/check-c1-item-count.py`
- 回帰テスト: `tests/extras/ta-77-c1-item-count.sh`
- 同型の検査: [`docs/ai/stale-ref-detection.md`](./stale-ref-detection.md) / [`docs/ai/skill-collision-detection.md`](./skill-collision-detection.md)
