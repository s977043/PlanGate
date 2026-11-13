# TASK-1544 Implementation Plan（下書き。`PLANGATE_HOOK_TASK=TASK-1544` のセッションで plan.md へ移す）

> EH-3 が TASK context なしの plan.md 書き込みを block したため、本文をこのファイルに置いている。
> plan.md へ移した後に本ファイルは削除する。c3.json の plan_hash は plan.md に対して発行すること。

## Goal

`retro_enabled: true` かつ C-3 APPROVED の run だけで handoff の既知課題から seeds 下書きを作り、
`confirmed_by` が入った下書きだけを seeds に追記する最小の生成器を実装する。
あわせて、その制約を実行して検査する TC（TA-118）を置く。

## Context

pbi-input.md を参照。#1573 で手順は docs に入ったが、実行コードが無いため AC2/AC3 は機械検査できない。

## Scope

### In Scope

- `scripts/retro_seed_draft.py`（新規）
- `tests/extras/ta-118-retro-seed-draft.sh`（新規）
- `docs/workflows/06_retro.md` の「検査観点」節の更新（手動 → 生成器と TA-118 の参照）

### Out of Scope

pbi-input.md「Out of scope」のとおり（opt-in source の追加・既定 ON・HO パスの変更・CLI 経路・L2）。

## Global Constraints

- HO 対象パスは編集しない。本計画の変更ファイル 3 件はいずれも HO 12 カテゴリ（`mode-classification.md`）に該当しない。
  `scripts/hooks/` ではなく `scripts/` 直下。`bin/plangate`・`schemas/`・`.claude/` は触れない
- c3.json / approvals/ は読むだけ。作らない、書かない
- 生成器は `confirmed_by` を埋めない（引数でも環境変数でも埋める経路を作らない）
- python3 標準ライブラリのみ。PG-SH-GUARD（#1169）を `improvement_seed_delta.py` と同じ形で先頭に置く

## 前提の実測検証（#786）

| 前提 | 実測 |
|------|------|
| 実行コードが無い | `grep -rn retro_enabled scripts bin` → 0 件（2026-10-26 オーガナイザー実測） |
| handoff §2 の見出し | `docs/working/templates/handoff.md:47` `## 2. 既知課題一覧`（表形式） |
| seeds スキーマ | `docs/ai/retro-phase.md` §2（見出し `## <date> — <task_id>` + 5 項目 + `confirmed_by`） |
| c3.json の判定キー | `c3_status`（既存 c3.json の大半が `"c3_status": "APPROVED"`） |
| テスト番号 | `tests/extras` の最大は ta-117。open PR に extras の ta 追加なし（2026-10-26 `gh pr list` で確認）→ 118 |

## Questions / Unknowns（#786）

- U-1（pbi-input の改変は c3 の plan_hash に束縛されない）: **解消**（R-007）。opt-in 行を plan.md 側にも要求し、c3.json の `plan_hash` と plan.md の sha256 の一致を確かめる（ゲート 3）
- seeds の 5 項目は handoff から機械的に決められない。下書きでは「未確認」と書き、既知課題の行を `失敗・手戻り` の候補として列挙する（06_retro.md 手順 3 と同じ扱い）

## Approach Comparison

| 案 | 内容 | 採否 |
|----|------|------|
| A | `bin/plangate retro-draft` サブコマンド | 不採用（`bin/plangate` は HO） |
| B | `scripts/retro_seed_draft.py` 単体 + extras TC | **採用** |
| C | docs 文言の grep のみ | 不採用（Human 決定 2026-10-26。素通りの検査になる） |

### Recommended Approach

案 B。ゲート判定・下書き出力・confirm 済みの追記の 3 つだけを 1 ファイルに持つ。これで AC2/AC3 を実行して検査できる。L2 連携や CLI 化は後続に回す。

## Change Type / Verification Strategy

new behavior。TDD（TA-118 を先に書き、生成器が無い状態で FAIL を確かめてから実装する）と、変異注入。

## Files / Interfaces

| ファイル | 種別 | HO |
|---------|------|----|
| `scripts/retro_seed_draft.py` | 新規 | 非該当 |
| `tests/extras/ta-118-retro-seed-draft.sh` | 新規 | 非該当 |
| `docs/workflows/06_retro.md` | 更新 | 非該当 |

CLI:

```text
python3 scripts/retro_seed_draft.py draft  --task-dir <docs/working/TASK-XXXX> [--out <path>]
python3 scripts/retro_seed_draft.py append --task-dir <docs/working/TASK-XXXX> --draft <path> --seeds <path>
```

終了コード: 0 = 成功 / 2 = 引数・入力の形式エラー / 3 = opt-in 不成立で停止（出力なし）/ 4 = confirm 未了で追記を拒否 / 5 = 同じ task_id のエントリが seeds に既にあり追記しない（冪等。R-009）/ 6 = 追記前または追記後の seeds 全文が L2 の `read_declared_seeds` を通らない（R-010 / R-015）/ 7 = 読み込みから置き換えまでの間に seeds が変わった（R-015）/ 8 = 追記後の全文の先頭が追記前の seeds のバイト列と一致しない（R-021）。
各コードは 1 つの判定にだけ対応させ、後段の検査が前段の拒否を同じコードで肩代わりしないようにする（R-010）。

`--out` は、既に存在するパス（通常ファイル・symlink・ディレクトリ。`../` を含む別名で seeds を指す場合も、解決前のパスが存在すれば該当）を指したら exit 2 で何も書かない（R-005）。
存在判定は `os.path.lexists` で行い（リンク先の無い symlink も存在扱い）、書き込みは `os.open(path, O_CREAT | O_EXCL | O_WRONLY | O_NOFOLLOW)` で開く。開けなければ exit 2（R-016）。

ゲート（`draft` と `append` の両方で判定する。すべて満たすときだけ成立）:

1. `<task-dir>/pbi-input.md` と `<task-dir>/plan.md` の両方に、正規表現 `^ {0,3}retro_enabled: true[ \t]*$` に一致する行がある（先頭の空白は半角スペース 0〜3 個まで、タブ不可。`true` 以外の値は不成立。R-012）。照合前に `improvement_seed_delta.mask_code_blocks` で fence 内を伏せ、HTML コメント（`<!--` 〜 `-->`、複数行を含む）を除く。fence 内・コメント内・4 スペース以上のインデント（インデントコード）の記述は不成立（R-002 / R-007 / R-012）。`mask_code_blocks` が ValueError（閉じていない fence 等）を出したら不成立（exit 3。R-012）
2. `<task-dir>/approvals/c3.json` が JSON として読め、`c3_status == "APPROVED"`
3. c3.json の `plan_hash`（`sha256:<hex>`）が `<task-dir>/plan.md` の sha256 と一致する。`plan_hash` 欠落・形式不正・不一致・plan.md 欠落は不成立（R-007。EH-3 の `check-plan-hash.sh` と同じ形式）
4. c3.json の `task_id` が文字列で、`<task-dir>` の実体（`os.path.realpath`）の basename と完全一致する。`task_id` 欠落・型不正・不一致は不成立（R-013）。origin/main の c3.json 91 件のうち `task_id` が無いものが 1 件（TASK-0038）あり、そうした c3.json は fail-closed で exit 3 になる
5. `append` で、`--seeds` が本番 seeds 宛てのとき: (i) `dirname(realpath(<task-dir>))` が `<root>/docs/working` と `samefile` で同一であり（R-028）、(ii) `pbi-input.md` / `plan.md` / `approvals/c3.json` の 3 ファイルがいずれも `HEAD` に commit 済みで、(iii) 3 ファイルとも作業ツリーのバイト列が `HEAD` の blob と一致する。このときゲート 1〜4 は **`HEAD` の blob の内容**で判定する。(i)〜(iii) とゲート 1〜4 のいずれかを満たさなければ不成立（exit 3。R-013 / R-018 / R-019 / TC-21 (f)）。作業ツリーの改変・index への登録（`git add`）だけでは成立せず、作業ツリーが `HEAD` と食い違う状態もゲートが成立する向きか否かを問わず不成立とする
   - **本番宛ての判定は git を使わず、書き込み先の側で fail-closed にする（R-024 / R-027）**: 次の (a) または (b) を満たせば本番宛てとする。
     - (a) `<gen-root>`（`os.path.realpath(__file__)` の 2 階層上。`scripts/` の親）について、`--seeds` と `<gen-root>/docs/working/improvement-seeds.md` が `os.path.samefile` で同一。後者が存在しなければ (a) は不成立
     - (b) `realpath(--seeds)` の末尾 3 要素を `casefold()` した値が `docs` / `working` / `improvement-seeds.md` であり、`dirname(dirname(dirname(realpath(--seeds))))`（2 つ上の階層の親）に `.git`（ディレクトリまたはファイル。`os.path.lexists`）がある
     - `<root>` は (a) が成立すれば `<gen-root>`、(a) が不成立で (b) が成立すれば `dirname(dirname(dirname(realpath(--seeds))))` とする。(i)〜(iii) と git の読み取りはこの `<root>` に対して行う
     - (b) はパス文字列を使うが、本番宛てと判定する向き（ゲート 5 を課す向き）にだけ働く。(b) が不成立であることを本番宛てでない根拠にはせず、(a) と (b) の両方が不成立のときだけ本番宛てでないとする。生成器のコピー・hardlink・PYTHONPATH 経由の起動で `<gen-root>` がずれても (b) で本番宛てと判定される
     - `GIT_*` 環境変数・カレントディレクトリは本番宛てかの判定に影響しない
   - **git は blob の読み取りだけに使う（R-024）**: `git -C <root>` を、環境変数から `GIT_` で始まるものをすべて除いた env で呼ぶ。本番宛てと判定した後に git の実行（`rev-parse` / `show`）が失敗したら exit 3（「本番以外」に倒さない）
   - **相対パスと HEAD の固定（R-025）**: 作業ツリー相対パスは `os.path.relpath(os.path.realpath(<task-dir>), <root>)` を 1 回だけ求め、3 ファイルで共有する。HEAD は最初に `git rev-parse --verify HEAD^{commit}` で SHA に固定し、以降は `git show <sha>:<相対パス>/<ファイル>` で読む（3 回の読み取りの間に commit が入っても同じ commit を読む）

判定の詳細は次節「判定の 2 原則」の表に従う。

append の confirm 判定（R-001）:

- `confirmed_by` の値から Unicode 書式文字（`unicodedata.category == "Cf"`。ZWSP 等）を除いたうえで、`improvement_seed_delta.is_unconfirmed` を適用する。真なら exit 4。判定語は L2 の `UNCONFIRMED` をそのまま使い、本スクリプトで独自の語彙を持たない
- 下書き側の検査: 見出し `## <date> — <task_id>` がちょうど 1 件・task_id が `<task-dir>` の名前と一致・`- confirmed_by:` 行がちょうど 1 行（R-003）。違えば exit 2
- task_id の同一性: `mask_code_blocks` 後の seeds の見出しと下書きの見出しから task_id を取り出し、`strip()` + `casefold()` した値の完全一致で比較する。日付は比較しない。seeds に同じ task_id の見出しが既にあれば exit 5（R-009 / R-014）
- 識別子の求め方の統一（R-026）: 見出しからの task_id の取り出しは 1 つの関数（`heading_task_id`）、task-dir の識別子は 1 つの関数（`task_dir_id` = `os.path.basename(os.path.realpath(<task-dir>))`）で求め、すべての判定箇所で同じ関数を使う。比較は 2 種類だけで、どちらも 1 つの関数に置く: **一致の要求**（ゲート 4・下書き見出しの task_id）は `strip()` 後の完全一致（大文字小文字を区別する。緩めない）、**重複の検出**（exit 5）は `strip()` + `casefold()` の完全一致（拒否する側に広く取る）
- 追記前の seeds を読み、その sha256 を控える。追記前の全文が `read_declared_seeds` を通らなければ exit 6（R-015）
- seeds が改行で終わっていなければ、追記部の前に改行を 1 つ補う（R-015）
- 追記後の全文を seeds と同じディレクトリの一時ファイルに作り、`improvement_seed_delta.read_declared_seeds` を適用する。例外なら exit 6 で seeds を変えない（confirm 未了の exit 4 とは別。R-010）。通れば件数が追記前 +1 であることを確かめる
- seeds は `read_bytes` で読む（テキストモードの改行変換を通さない。CRLF の seeds でも既存バイトを保つ。R-021）。追記後の全文の先頭が追記前のバイト列と一致しなければ exit 8 で seeds を変えない（R-021）
- 書き込み先は `os.path.realpath(--seeds)` に固定する。seeds が symlink のときはリンクそのものではなくリンク先を置き換える（R-020）。一時ファイルはその実体と同じディレクトリに作り、置き換え前に実体の mode（`os.stat(...).st_mode` の許可ビット）を `os.chmod` で引き継ぐ（R-020）
- `os.replace` の直前に seeds の実体を読み直して sha256 を再照合し、不一致なら一時ファイルを消して exit 7（R-015）。一致すれば `os.replace(一時ファイル, 実体)` で置き換える

### 判定の 2 原則（C-2 R2 / §7-quater「設計モデルを疑う」）

R1 の「承認トークンの文脈流用」と R2 の R-018 / R-019 は、出所と同一性をファイルの状態やパス文字列で近似していたことが共通の原因だった。判定を次の 2 原則に統一する。

- **原則 I（同一性）**: 2 つのパスが同じものかは inode（`os.path.samefile`）で判定する。パス文字列（正規化・`realpath` 後を含む）の比較で同一性を判定しない。大文字小文字を区別しない FS の別名も同一として扱う
- **原則 P（出所）**: 承認に関わる入力の出所は commit 済みの blob（`git show HEAD:<path>`）で判定する。作業ツリーと index の状態（`git ls-files`・`git add` 済みかどうか・作業ツリー上の内容）は根拠にしない

| 判定箇所 | 原則 | 適用のしかた / 適用しない理由 |
|---------|------|---------------------------|
| ゲート 1（opt-in 行） | P（本番 seeds 宛て） | 本番宛ては `HEAD` の pbi-input.md / plan.md の blob で照合。本番宛てでないとき（sandbox・一時コピー）は作業ツリーで照合する。追記先が本番でないため出所を証明する必要がない |
| ゲート 2（`c3_status`） | P（本番 seeds 宛て） | 本番宛ては `HEAD` の c3.json の blob を読む。それ以外はゲート 1 と同じ理由で作業ツリー |
| ゲート 3（`plan_hash`） | P（本番 seeds 宛て） | 本番宛ては `HEAD` の plan.md の blob の sha256 と、`HEAD` の c3.json の `plan_hash` を照合する |
| ゲート 4（`task_id`） | P（本番 seeds 宛て） | 本番宛ては `HEAD` の c3.json の `task_id` を使う。比較相手の task-dir 名は task-dir の実体の basename（識別子の比較であり、2 つのパスの同一性判定ではないため I は適用しない） |
| ゲート 5（本番 seeds 宛てか） | I（+ 拒否側にだけ広げるパス形状） | (a) `--seeds` と `<gen-root>/docs/working/improvement-seeds.md`（`<gen-root>` は `realpath(__file__)` の 2 階層上）を `samefile` で比較、または (b) `realpath(--seeds)` の末尾 3 要素（casefold）が `docs/working/improvement-seeds.md` で 2 つ上の階層の親に `.git` がある。どちらかが成立すれば本番宛て。(b) は本番宛てと判定する向きにだけ使い、同一性の否定には使わない（原則 I は「同一である」の判定に適用し、(b) は fail-closed の追加条件）。git は使わない（R-024 / R-027） |
| ゲート 5（task-dir の位置） | I | `dirname(realpath(<task-dir>))` と `<root>/docs/working` を `samefile` で比較する（R-028） |
| ゲート 5（commit 済み） | P | 固定した HEAD SHA で `git show <sha>:<path>` が成功するかで判定する。`git ls-files` は使わない。git は `GIT_*` を除いた env で呼び、失敗は exit 3（R-024 / R-025） |
| ゲート 5（作業ツリーと HEAD の一致） | P | 3 ファイルとも作業ツリーのバイト列と `HEAD` の blob が一致することを要求する。判定の根拠は blob のままで、作業ツリーは一致の確認にだけ使う（TC-21 (f)） |
| 下書きの task_id | どちらも適用しない | 識別子の比較。`heading_task_id` と `task_dir_id` で求め、`strip()` 後の完全一致（R-026） |
| exit 5 の重複 | どちらも適用しない | 識別子の比較。`heading_task_id` で seeds と下書きの両方から求め、`strip()` + `casefold()` の完全一致（R-014 / R-026） |
| `draft` サブコマンド | ゲート 1〜4 は作業ツリー | `draft` は seeds に書かないため本番宛てが存在せず、ゲート 5 の対象外。出力は `--out` の行に従う（R-026） |
| exit 6 / 7 / 8 | I（書き込み先）のみ | seeds の実体（`realpath`）の内容検査と変化の検出。同一性は書き込み先の行、出所は対象外（seeds は承認トークンではない。R-026） |
| `--out` | I は不要 | 既存パスは種類を問わず `lexists` で一律拒否し、`O_EXCL \| O_NOFOLLOW` で新規作成だけを許す。既存物と同一かを比べる場面が無いため同一性判定を要さない。出所は対象外（出力であって承認の入力ではない） |
| `--seeds`（書き込み先） | I | 書き込みは `realpath` の実体に対して行い、本番宛てかの判定はゲート 5 の `samefile` に従う。出所は対象外（seeds は承認トークンではない） |
| `--draft` | どちらも適用しない | 下書きは Human が記入する申告であり、出所も同一性も承認の根拠にしない（信頼境界 R-008。C-4 が担保） |

### 運用手順（R-018 の帰結）

- **本番 seeds への append は、c3.json（と plan.md / pbi-input.md）を commit してから行う。** worktree で approve した未 commit の c3.json では追記できない（exit 3）
- **一時コピーへの append と PR での反映は正規の手段である。** `docs/working/improvement-seeds.md` を一時ディレクトリにコピーして `--seeds` に渡すと本番宛てでないためゲート 5 の対象外になる（ゲート 1〜4 は作業ツリーで判定）。追記結果は PR で本番 seeds に反映し、C-4 で確認する

### 信頼境界（R-008）

`confirmed_by` は**記入者を証明しない**。値は申告であり、生成器は本人確認済みとして扱わない。
生成器が保証するのは「空・プレースホルダ・L2 の未確認語でない値が入っている」ことだけ。
誰が記入したかの保証は C-4（Human レビュー）が担う。

### 残存脅威モデル（R-004）

本節は完全性を主張しない。C-2 R1〜R4 で見つかったクラスを塞いだ時点の「守るもの / 守らないもの」の列挙であり、未発見のクラスが残りうる。

守るもの: opt-in 不成立・C-3 未承認・plan_hash 不一致の run での下書き生成と追記 / 他 TASK の c3.json の流用、本番 seeds 宛てでの作業ツリー外・未 commit（作業ツリーだけの改変・staged のみを含む）の c3.json（R-013 / R-018） / 本番 seeds 宛てで 3 ファイルの作業ツリーが `HEAD` と食い違う状態（TC-21 (f)） / `GIT_CEILING_DIRECTORIES` / `GIT_DIR` / `GIT_WORK_TREE` などの env による本番宛て判定の反転（R-024） / 生成器のコピー・hardlink・PYTHONPATH 経由の起動による本番宛て判定の回避（R-027） / 読み取りの間の HEAD の移動（R-025） / 大文字小文字違いなどの別名による本番 seeds 判定の回避（R-019） / symlink の seeds でリンクだけが置き換わる誤 PASS と mode の喪失（R-020） / 未 confirm の追記 / 既存内容の改変 / 二重追記（大文字小文字・空白・日付違いを含む。R-014） / `--out` による seeds の上書き（リンク先の無い symlink を含む。R-016） / 読み込みから置き換えまでの seeds の変化の検出（R-015）。

守らないもの:

- seeds を Edit で直接書き換える経路（生成器を通らない）
- `confirmed_by` に AI 名など任意の名前を書いた下書き（値の真正性は検証しない。R-008）
- `confirmed_by` の値が U+3164（HANGUL FILLER）など、category `Cf` 以外の空白に見える文字だけの場合。L2 の `is_unconfirmed` も空とみなさないため confirmed 扱いになる（R-017）
- c3.json 自体の発行元（EH-3 / Human 発行の規範に依存）。`task_id` の一致は流用を防ぐが、発行者は検証しない
- 同時実行時の競合（追記はロックしない。sha256 の再照合は検出であり、照合から `os.replace` までの間の書き込みは防がない）
- `--out` の `O_NOFOLLOW` が拒否するのは最終要素の symlink だけ。途中のディレクトリ要素が symlink の経路は防がない（R-023）
- 一時コピー経路の追記結果の正しさ（ゲート 5 の対象外。PR と C-4 で担保）
- commit の作成者（原則 P は「commit 済みか」を見るだけで、誰が commit したかは検証しない。発行者の検証は EH-3 と Human の規範に依存）
- `HEAD` は任意のローカル commit でよい。origin/main への到達や push 済みかは検証しないため、ローカルで commit した c3.json は原則 P を満たす（R3）
- seeds の hardlink。本番 seeds と inode を共有する別パスは `samefile` で本番宛てと判定されるが、hardlink を張ること自体は防がない。また `os.replace` で実体を置き換えると hardlink の共有は切れる（R3）
- `<root>` から `docs/working/` までの途中要素の symlink や bind mount による別名（`samefile` は最終的な inode を比べるだけで、経路の正当性は検証しない。R3）
- 生成器のコピー・hardlink・PYTHONPATH 経由の起動は、本番 seeds 宛ての判定 (b)（`realpath(--seeds)` の末尾 3 要素と `.git` の所在）で本番宛てと判定されるため、ゲート 5 を外す経路としては塞いでいる（R-027）。守らないのは、本番 seeds の実体を末尾 3 要素が `docs/working/improvement-seeds.md` にならないパスへ hardlink し、かつ生成器のコピーを使う経路（(a) も (b) も成立しない。hardlink を張れる主体は seeds を Edit で直接書き換えることもでき、上の「Edit で直接書き換える経路」と同じ層。PR と C-4 で担保する）
- PATH 上の偽 `git`・`refs/replace`・`.git/config`（`core.*` や alias 等）による `HEAD` の blob の偽装。git は `GIT_*` を除いた env で呼ぶが、PATH の解決とリポジトリ内の設定・置換参照は検証しない（「`HEAD` は任意のローカル commit」と同じ層。R-029）
- macOS など大文字小文字を区別しない FS で、大文字小文字だけが異なる別名の task-dir や seeds を渡した場合。`samefile` と (b) の casefold により本番宛てと判定され、ゲート 4 の task_id 完全一致や commit 済み判定で exit 3 になる（拒否側に倒れるだけで、別名での追記を成功させる経路は提供しない。R-029）

保証の主体: 本生成器は多層防御の 1 層であり、最終保証は C-4（Human レビュー）・branch protection・c3.json を Human が発行する規範（EH-3）。生成器の module docstring にも同じ内容を書く。

## Work Breakdown

### Task 1: TA-118 を先に書く（RED）

- Files: `tests/extras/ta-118-retro-seed-draft.sh`（run-tests.sh から `set -eu` で source。`register_cleanup` で一時パスを登録）
- Steps: fixture 生成関数 → test-cases.md の TC → 生成器が無い状態で実行して FAIL を記録
- Completion: 生成器が無い状態で TA-118 の TC が FAIL し、harness 全体はハングしない
- Rollback: ファイル削除

### Task 2: 生成器を実装する（GREEN）

- Files: `scripts/retro_seed_draft.py`
- Steps: ゲート関数（opt-in 2 ファイル・c3_status・plan_hash・task_id・本番 seeds 宛ての `samefile` 判定と所在・`HEAD` blob での判定）→ handoff §2 表の抽出 → 下書きの整形 → append（ゲートの再判定、下書きの 1 エントリ検査、confirmed_by の検査、正規化した task_id での重複検査、追記前全文の L2 検査、末尾改行の補完、追記後全文の `read_declared_seeds` 検査、`read_bytes` による既存内容の前方一致検証（exit 8）、`realpath` の実体への書き込みと mode の引き継ぎ、sha256 の再照合と `os.replace`）。L2 の関数は `scripts/improvement_seed_delta.py` から import する（複製しない）
- Completion: TA-118 全 PASS。追記後の fixture が `scripts/improvement_seed_delta.py` の検査で正規形として通る
- Rollback: ファイル削除

### Task 3: 変異注入

- test-cases.md「変異注入計画」M-1〜M-13（M-2b / M-6b / M-8b を含む）を 1 つずつ注入し、該当 TC の FAIL を記録して戻す（commit しない）
- Rollback: `git checkout -- scripts/retro_seed_draft.py`

### Task 4: docs の更新

- Files: `docs/workflows/06_retro.md`（検査観点節を TA-118 参照にし、手順に CLI を添える。retro-phase.md は変更しない）
- Completion: リンク切れなし。opt-in source の記述は増えていない
- Rollback: `git checkout -- docs/workflows/06_retro.md`

## Verification Plan

- `sh tests/run-tests.sh`（harness 経由）で TA-118 全 PASS、既存の FAIL を増やさない（main で同じテストを流して対照）
- TA-118 単体の実行 / 変異注入 M-1〜M-13（M-2b / M-6b / M-8b を含む） / `python3 -m py_compile scripts/retro_seed_draft.py`

### レビューレーン計画（#786）

- C-2: 設計妥当性レーン 1 本 + コードベース整合レーン 1 本（seeds の読み手 `improvement_seed_delta.py` との形式整合）
- V-3: 承認トークン（c3.json）を読むコードのため、review-principles §7-quater に従い 2 ラウンドを下限とする（安全側）

## Replan Triggers

- 変更ファイルが 3 件を超える / HO 対象パスの変更が必要になる / seeds の §2 スキーマ変更が必要になる / TA-118 の実行時間が 30 秒を超える

## Stop Condition

- 上の Replan Trigger のいずれか
- EH-3 が `.md` 以外の書き込みを block した場合。exec は `PLANGATE_HOOK_TASK=TASK-1544` を付けた再起動の後に行う

## Human Approval Boundary

- C-3: Human が `docs/working/TASK-1544/approvals/c3.json` を発行する（AI は作らない）
- C-4 / merge: Human-owned

## Mode判定

**モード**: high-risk（R-NNN 反映前は standard）

- 変更ファイル数: 3 → standard
- 受入基準数: 6 → high-risk 相当（定量軸）。ただし R-NNN 反映で AC を厳格化した結果であり変更ファイルは 3 件のまま
- C-2 反映: review-external.md R-001〜R-009 を本ファイルへ 1 回で確定反映（2026-11-13、`003f49e7`）。C-2 敵対レビュー R1 の R-010〜R-017 を 1 回で確定反映（2026-11-13、`e88104e8`）。R2 の R-018〜R-023 と判定の 2 原則を 1 回で確定反映（2026-11-13、`bec976bd`）。R3 の R-024〜R-026・TC-21 (f) の厳格化・残存脅威モデルを 1 回で確定反映（2026-11-13、`3ca7842e`）。R4 の R-027〜R-029 を 1 回で確定反映し C-2 を終了（2026-11-13）。変更ファイルは 3 件のまま
- 変更種別: 小機能追加（新規スクリプト + テスト） → standard
- リスク: 中（承認トークンを読む。書かない） → standard
- HO 対象パス: なし（3 件とも 12 カテゴリ外） → 例外ルール非該当
- **最終判定**: high-risk（判定ロジック「各軸の最大値」により受入基準数 6 を採用。安全側に引き上げ、緩めない）。承認トークンを読むため V-3 は 2 ラウンドを下限とする。high-risk のため V-2 を実行し、C-3 は人間必須（autonomous APPROVE 不可）
