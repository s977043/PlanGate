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

## 監査表の補記（追記専用）

| R-NNN | reflected_in(commit) |
|-------|---------------------|
| R-001〜R-009 | `003f49e7` |

---

## C-2 敵対レビュー R1（head `003f49e7` / Mode high-risk / 判定 CONDITIONAL）

> 出典: PR #1612 最新コメント（C-2 敵対レビュー R1）。major 4 / minor 3 / info 1。
> R-001〜R-009 の反映そのものが新しい穴を生んだクラスを含む（review-principles §7-quater「是正が生んだ穴」）。

### 前提の実測（2026-11-13、origin/main）

| 前提 | 実測 |
|------|------|
| c3.json の `task_id`（R-013） | `git grep -l '"task_id"' origin/main -- 'docs/working/*/approvals/c3.json'` → 90 件 / c3.json 総数 91 件。欠落は `docs/working/TASK-0038/approvals/c3.json` の 1 件。全件にはないため、`task_id` のない c3.json は fail-closed（exit 3）とする |
| 現行 seeds の L2 通過（R-015） | `improvement_seed_delta.read_declared_seeds` に `git show origin/main:docs/working/improvement-seeds.md` を渡すと例外なく 7 件を返す（PASS）。末尾は改行で終わる |

### 指摘一覧

| ID | severity | 指摘 | 是正方針 |
|----|----------|------|---------|
| R-010 | major | M-2（confirm 検査除去）は後段の L2 全文検査に吸収され、TC-04 / 05 が exit 4 のまま生き残る（AC-5 の欠陥） | confirm 未了（exit 4）と L2 全文検査の失敗（exit 6）を分ける。TC は終了コードを完全一致で照合する |
| R-011 | major | M-2b を検出できるのは TC-04d（ZWSP）だけ。TBD / no は後段で止まる | R-010 の exit コード分離により、M-2b では TC-04b / 04c / 05 が exit 6 になり FAIL、TC-04d は exit 0 になり FAIL。変異表の FAIL 欄を実際の挙動に合わせる |
| R-012 | major | `mask_code_blocks` が伏せるのはインデント 0〜3 の fence だけ（`FENCE = ^[ ]{0,3}`）。4 スペースのインデントコードで opt-in が成立する。閉じていない fence の ValueError の扱いが未定義 | opt-in 行の先頭空白を半角スペース 0〜3 に限定（タブ不可）。`mask_code_blocks` の ValueError は exit 3。TC-E02d / E02e |
| R-013 | major | `--task-dir` に任意のパスや他 TASK の c3.json を渡すと本番 seeds に追記できる（#1646 と同型） | c3.json の `task_id` と task-dir 名の完全一致を要求（欠落・不一致は exit 3）。本番 seeds 宛て（seeds の実体が git 作業ツリー最上位の `docs/working/improvement-seeds.md`）のときは、task-dir の実体が同じ作業ツリーの `docs/working/` 直下にあり、c3.json が git 追跡下にあることを要求（違えば exit 3）。TC-21 |
| R-014 | minor | task_id の正規化が未定義（大文字小文字・空白・日付違いで二重追記になる） | マスク後の見出しから task_id を取り出し、strip + casefold で完全一致を見る（日付は比較しない）。TC-19b / 19c |
| R-015 | minor | 末尾改行なしの seeds、追記前からの L2 失敗、TOCTOU で正常系が止まる・壊れる | 末尾改行がなければ補う。追記前の seeds が L2 を通らなければ exit 6。読み込み時の sha256 を `os.replace` の直前に再照合し、不一致は exit 7。TC-20 |
| R-016 | minor | 存在しないリンク先を指す symlink の `--out` が `exists()` を通過する | `os.path.lexists` で判定し、`O_CREAT \| O_EXCL \| O_NOFOLLOW` で開く。TC-09b (d) |
| R-017 | info | U+3164 などの空白に見える文字が confirmed 扱いになる | 「守らないもの」に追記する |

### 回避クラス台帳（追記専用）

| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
|-------|------------------|------------|------|--------------------------------|
| 冗長な後段検査による変異の吸収 | M-2 を注入しても L2 全文検査が同じ exit 4 で止め、TC-04 / 05 が PASS のまま | R1 | R-010 / R-011（exit 4 / 6 の分離、完全一致照合） | L1 は TC と変異の対応を「止まるか」で見ており、「どの層で止まったか」を区別する exit の設計を見ていなかった |
| 前提関数の対象外構文 | 4 スペースインデントの `retro_enabled: true` が `mask_code_blocks` をすり抜けて opt-in 成立 | R1 | R-012（先頭空白 0〜3、ValueError → exit 3） | R-002 の是正は `mask_code_blocks` を信頼の前提として導入し、その関数が対象とする構文の範囲を照合していなかった |
| 承認トークンの文脈流用 | 他 TASK の APPROVED c3.json を持つ task-dir（または任意パス）を `--task-dir` に渡して本番 seeds に追記 | R1 | R-013（`task_id` 一致・本番 seeds 宛ての所在と git 追跡） | L1 は c3.json の中身（status / plan_hash）を見ており、そのトークンがどの TASK に発行されたかを束縛していなかった |
| 識別子の正規化の揺れ | seeds に `task-9999` があるとき `TASK-9999` を追記すると重複検査を通る | R1 | R-014（strip + casefold の完全一致） | R-009 は重複の有無を定めたが、同一性の比較規則を定めていなかった |

### 監査表（R1 分 / 追記専用）

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|---------------------|-------|
| R-010 | reflected | 本 commit（`docs(TASK-1544): C-2 R1（R-010〜R-017）を反映する`） | plan-draft 終了コード 6・pbi-input AC-3 / AC-5・test-cases 冒頭（完全一致照合）・M-2 |
| R-011 | reflected | 同上 | test-cases 変異表 M-2b |
| R-012 | reflected | 同上 | plan-draft ゲート 1・pbi-input AC-1・test-cases TC-E01 / E02d / E02e |
| R-013 | reflected | 同上 | plan-draft ゲート 4 / 5・pbi-input AC-1・test-cases TC-21・M-7 |
| R-014 | reflected | 同上 | plan-draft append 節・pbi-input AC-6・test-cases TC-19b / 19c |
| R-015 | reflected | 同上 | plan-draft append 節・終了コード 6 / 7・test-cases TC-20 |
| R-016 | reflected | 同上 | plan-draft `--out` 節・test-cases TC-09b (d) |
| R-017 | reflected | 同上 | plan-draft 残存脅威モデル |

high-risk のため R2（是正が効いているか、是正が新しい穴を生んでいないか）を実施する。
