# TASK-1544 外部レビュー結果（C-2 / 追記専用）

> 対象: plan-draft.md（sha 31935b77）/ todo.md / test-cases.md。PR #1612 head `7806ca01` 時点。
> 出典: Phase P / L1 レビュー（Claude 敵対 + Codex）— https://github.com/s977043/PlanGate/pull/1612#issuecomment-6404933620
> 手順: `.claude/rules/working-context.md`「review-external.md」節。(1) 本ファイルに R-NNN 集約 → (2) 1 回確定反映 → (3) 簡易 C-1 → (4) Human が c3.json 発行 → (5) exec。

## 指摘一覧

| ID | 出典レーン | severity | 指摘 | 是正方針 |
|----|----------|----------|------|---------|
| R-001 | Claude 敵対 major-1 | major | append の confirm 判定が L2（`improvement_seed_delta.is_unconfirmed` / `UNCONFIRMED`）とずれ、`TBD` を追記すると seeds 全体が L2 で ValueError になる。ZWSP は `str.strip()` で除かれず `is_unconfirmed` が False を返す | L2 の `is_unconfirmed` / `read_declared_seeds` を import して使う。値から Unicode 書式文字（category `Cf`。ZWSP 等）を除いてから空判定する。追記後の全文に `read_declared_seeds` を適用し、例外なら追記しない。TC-04b〜04d、変異 M-2b |
| R-002 | Claude 敵対 major-2 | major | opt-in 行がコード fence 内・コメント内でも成立しうる | `mask_code_blocks` で fence 内を伏せ、複数行を含む HTML コメント（`<!-- ... -->`）を除いてから行照合する。TC-E02b / E02c |
| R-003 | Claude 敵対 major-3 | major | 追記が「1 エントリ」であることの検査が無い（AC-4） | AC-4 を具体化（追記部の見出しは 1 件・見出しの task_id が task-dir と一致・`confirmed_by` 行は 1 行）。TC-14 / TC-15 |
| R-004 | Claude 敵対 minor-1 | minor | 守らないものが書かれていない | 残存脅威モデルを plan と docstring に書く。最終保証は C-4 |
| R-005 | Claude 敵対 minor-2 | minor | `--out` の別名経路（symlink, `../`）で seeds を指せる | 既に存在するパスを指す `--out` は一律 exit 2。TC-09b |
| R-006 | Claude 敵対 minor-3 | minor | TC-11 が素通りしうる | TC-11 は `read_declared_seeds` を直接呼び、件数が追記前 +1 であることを assert |
| R-007 | Codex 高 | major | opt-in ゲートが pbi-input.md にあり plan_hash に束縛されない（Unknown U-1） | opt-in 行を plan 側にも置き、c3.json の `plan_hash` と plan.md の sha256 の一致を確かめる。不一致・plan.md 欠落は exit 3。U-1 解消。TC-16〜18、変異 M-5 |
| R-008 | Codex 高 | major | `confirmed_by` は記入者を証明しない | 信頼境界を明記（本人確認済みとして扱わない。値は申告） |
| R-009 | Codex 中 | minor | 同じ下書きの二重 append の扱いが無い | 同じ task_id の見出しが seeds に既にあれば exit 5 で終了し seeds は変えない（冪等）。TC-19、変異 M-6 |

severity は review-principles §3 に読み替えた（Codex「高」→ major、「中」→ minor）。

## 監査表（追記専用）

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|---------------------|-------|
| R-001 | reflected | 本 commit（`docs(TASK-1544): L1 / Codex 指摘を plan-draft に反映する`） | plan-draft ゲート/append 節・test-cases TC-04b〜04d・M-2b |
| R-002 | reflected | 同上 | plan-draft ゲート 1・test-cases TC-E02b/E02c |
| R-003 | reflected | 同上 | pbi-input AC-4 具体化・test-cases TC-14/15 |
| R-004 | reflected | 同上 | plan-draft「残存脅威モデル」 |
| R-005 | reflected | 同上 | plan-draft CLI・test-cases TC-09b |
| R-006 | reflected | 同上 | test-cases TC-11 |
| R-007 | reflected | 同上 | pbi-input AC-1 追加条件・U-1 解消・plan-draft ゲート 3・TC-16〜18・M-5 |
| R-008 | reflected | 同上 | plan-draft「信頼境界」 |
| R-009 | reflected | 同上 | plan-draft 終了コード 5・pbi-input AC-6・TC-19・M-6 |

commit SHA は push 後に status.md へ記録する（squash 後も追えるよう commit メッセージで特定する）。
