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

### 監査表の補記（R1 分 / 追記専用）

| R-NNN | reflected_in(commit) |
|-------|---------------------|
| R-010〜R-017 | `e88104e8` |

---

## C-2 敵対レビュー R2（head `e88104e8` / Mode high-risk / 判定 CONDITIONAL・未収束）

> 出典: PR #1612 最新コメント（C-2 敵対レビュー R2）。major 3 / minor 2 / info 1。
> R-010〜R-017 の是正は狙った症状には効いている。R-013 のゲート 5 に迂回の余地が残り、R-015 の `os.replace` が新しい穴を作った（§7-quater「是正が生んだ穴」）。

### 指摘一覧

| ID | severity | 指摘 | 是正方針 |
|----|----------|------|---------|
| R-018 | major | ゲート 5 は `git ls-files --error-unmatch` で index 登録の有無だけを見ている。追跡済み c3.json の作業ツリー改変も、`git add` だけでも通る。ゲート 4 も同じ型 | `git show HEAD:<path>` の blob で判定する（commit 済みを条件にする）。TC-21 に「作業ツリーだけ改変」「staged のみ」を追加 |
| R-019 | major | 本番 seeds 宛てかをパス文字列で比べている。大文字小文字を区別しない FS の別名でゲート 5 を飛ばせる | `os.path.samefile`（inode）で判定する。TC-21 に別名ケース（macOS のみ） |
| R-020 | major | `os.replace` で mode が 0600 になる。seeds が symlink だとリンクを置き換え、本番不変のまま exit 0（AC-4 の誤 PASS） | 書き込み先を `realpath` に固定、一時ファイルは同じ dir、mode を引き継ぐ。TC-20 (d) symlink / (e) mode |
| R-021 | minor | 先頭バイト不一致時の exit が未定義（CRLF の seeds で起きうる） | `read_bytes` で読み、不一致専用の exit 8 |
| R-022 | minor | M-6 の FAIL 欄は同じ日付の場合にしか成り立たない | TC-19 に「同じ日付・同じ task_id」と明記 |
| R-023 | info | `O_NOFOLLOW` が守れるのは最終要素だけ | 残存脅威モデルに追記 |

### 設計モデルの変更（§7-quater）

R-018 / R-019 は R1 の「承認トークンの文脈流用」と同じ層の新クラスで、出所と同一性をファイルの状態やパス文字列で近似していたことが共通原因。判定を 2 原則（同一性は inode / 出所は commit 済み blob）に統一し、全判定箇所への割り当てを plan-draft.md「判定の 2 原則」の表に置いた。R3 はこの 2 原則が全判定箇所に適用されているかに焦点を絞る。発行者の検証は引き続き範囲外（EH-3 と Human の規範。残存脅威）。

### 回避クラス台帳（R2 分 / 追記専用）

| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
|-------|------------------|------------|------|--------------------------------|
| 状態の代理指標を出所の証明に使う | 追跡済み c3.json を作業ツリーで APPROVED に書き換える、または未 commit の c3.json を `git add` するだけでゲート 5 を通る | R2 | R-018（`HEAD` の blob で判定。原則 P） | R1 の是正（R-013）は「追跡下にあるか」を出所の証明とみなし、index の状態が作業ツリー・index 上の操作だけで作れることを照合していなかった |
| パス文字列で同一性を判定する | macOS で `Docs/Working/Improvement-Seeds.md` を `--seeds` に渡し、本番宛てでないと判定させてゲート 5 を飛ばす | R2 | R-019（`samefile`。原則 I） | R1 は `realpath` による正規化で同一性が決まると前提し、FS の大文字小文字の扱いという正規化の外側の別名を見ていなかった |
| 原子的置き換えでファイル属性・リンクを失う | symlink の seeds に append すると、リンクが通常ファイルに置き換わり本番は不変のまま exit 0。mode は 0600 になる | R2 | R-020（`realpath` の実体に書き、mode を引き継ぐ） | R1 の R-015 は TOCTOU の検出に焦点を置いて `os.replace` を導入し、置き換えがファイルの属性とリンクに与える副作用を検査対象にしていなかった |

### 監査表（R2 分 / 追記専用）

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|---------------------|-------|
| R-018 | reflected | 本 commit（`docs(TASK-1544): C-2 R2（R-018〜R-023）と判定 2 原則を反映する`） | plan-draft ゲート 5・判定の 2 原則・運用手順・pbi-input AC-1・test-cases TC-21 (e)〜(g)・M-8 |
| R-019 | reflected | 同上 | plan-draft ゲート 5・判定の 2 原則・pbi-input AC-1・test-cases TC-21 (h)・M-9 |
| R-020 | reflected | 同上 | plan-draft append 節・pbi-input AC-4・test-cases TC-20 (d) / (e)・M-10 |
| R-021 | reflected | 同上 | plan-draft 終了コード 8・append 節・pbi-input AC-4・test-cases TC-20 (f) / (g)・M-11 |
| R-022 | reflected | 同上 | test-cases TC-19 |
| R-023 | reflected | 同上 | plan-draft 残存脅威モデル |

R3（2 原則が全判定箇所に適用されているか）を実施する。

### 監査表の補記（R2 分 / 追記専用）

| R-NNN | reflected_in(commit) |
|-------|---------------------|
| R-018〜R-023 | `bec976bd` |

---

## C-2 敵対レビュー R3（head `bec976bd` / Mode high-risk / 判定 CONDITIONAL・未収束）

> 出典: PR #1612 最新コメント（C-2 敵対レビュー R3）。major 1 / minor 2。
> 2 原則は判定箇所の表におおむね全数適用されている。新しい回避クラスが 1 件（判定器の env による分岐の反転）。

### 指摘一覧

| ID | severity | 指摘 | 是正方針 |
|----|----------|------|---------|
| R-024 | major | 本番宛ての判定が `git rev-parse` に依存し、`GIT_CEILING_DIRECTORIES` / `GIT_DIR` / `GIT_WORK_TREE` で「本番以外」に反転できる。plan-draft.md:94（git 失敗は不成立）と TC-21 (i)（repo 外で git 失敗 → 本番以外で exit 0）が矛盾 | 本番宛ては git を使わずに決める（root = `realpath(__file__)` の 2 階層上、`samefile`）。git は blob の読み取りだけに使い `GIT_*` を除いた env で呼ぶ。本番宛て判定後の git 失敗は exit 3。TC-21 (j) / (k)、変異 M-12 |
| R-025 | minor | 作業ツリー相対パスの求め方が未定義。HEAD を 3 回別々に読む | `relpath(realpath(task-dir), root)` を 1 回だけ求め、HEAD は `rev-parse` で SHA に固定して `<sha>:<path>` で読む |
| R-026 | minor | 識別子の比較方法が統一されておらず、判定箇所の表から 4 行が漏れている | 同じ関数で求める。表に「下書きの task_id」「exit 5 の重複」「draft サブコマンド」「exit 6/7/8」を追加 |

TC-21 (f) の扱い（R3 で厳しい側を採用）: 本番宛てでは 3 ファイル（pbi-input / plan / c3.json）について作業ツリーと `HEAD` の blob の一致とゲートの成立の両方を要求する。(f) 前半の期待値を exit 3 に改め、(f2) を追加した。pbi-input AC-1 も同じ方向で揃えた（厳格化。緩める変更なし）。

### 回避クラス台帳（R3 分 / 追記専用）

| クラス | 代表例（最小再現） | 検出ラウンド | 是正 | 前ラウンドが見つけられなかった理由 |
|-------|------------------|------------|------|--------------------------------|
| 判定器の実行環境（env）で分岐が反転する | `GIT_CEILING_DIRECTORIES=<repo の親>` を付けて本番 seeds に append すると git が失敗し「本番以外」と判定され、原則 P を外せる | R3 | R-024（本番宛ては `realpath(__file__)` と `samefile` で決め、git は `GIT_*` を除いた env で blob の読み取りだけに使う。判定後の git 失敗は exit 3） | R2 の設計モデルはプロセス env を判定器の入力として数えていなかった |

### 収束判定

未収束。ただし新しいクラスは「P を使うかどうかを決める分岐」という 1 層に閉じており、R-024 で git をこの分岐の判定から外した。R4 は是正箇所に絞って 1 ラウンド行い、新しいクラスが出なければ打ち切る。打ち切り時の残存脅威モデルは R3 の文案で plan-draft.md「残存脅威モデル」節を更新済み（完全性は主張しない）。

### 監査表（R3 分 / 追記専用）

| R-NNN | status | reflected_in(commit) | notes |
|-------|--------|---------------------|-------|
| R-024 | reflected | 本 commit（`docs(TASK-1544): C-2 R3（R-024〜R-026）と残存脅威モデルを反映する`） | plan-draft ゲート 5・判定の 2 原則の表・残存脅威モデル・pbi-input AC-1・test-cases TC-21 前提 / (i) / (j) / (k)・M-12 |
| R-025 | reflected | 同上 | plan-draft ゲート 5（相対パスと HEAD の固定）・判定の 2 原則の表 |
| R-026 | reflected | 同上 | plan-draft append 節（識別子の求め方の統一）・判定の 2 原則の表に 4 行 |
| TC-21 (f) | reflected | 同上 | plan-draft ゲート 5 (iii)・pbi-input AC-1・test-cases TC-21 (f) / (f2)・M-8 / M-8b |
