# テストケース定義 — TASK-1101

> plan: [plan.md](./plan.md)（**v4**） / AC: [pbi-input.md](./pbi-input.md)（AC-1〜AC-11）
> 実行対象: `tests/extras/ta-65-eh3-ho-task-context.sh`（拡充）+ 正規化関数の単体評価
>
> **⚠️ 採番の注意**（RiverReview info）: 本ファイルの `TC-05` / `TC-06` と、`ta-65` 内の `TC-06` / `TC-07` は**別の採番体系**。本ファイルの TC-05 本文が「既存 TC-06 の 10 件」と書いているのは **`ta-65` の TC-06** を指す。exec 時に読み違えないこと。

## 受入基準 → テストケース マッピング

| AC | 内容 | TC |
|---|---|---|
| AC-1 | 直積（9 カテゴリ 15 パターン × 変換 7 種 + 2 種複合）が全件 rc=2 | TC-01 |
| AC-2 | `_norm_target` の下流 consumer が不変 | TC-02 / TC-03 / TC-04 |
| AC-3 | 偽陽性なし（TC-06 拡充） | TC-05 / TC-06 |
| AC-4 | 4 シェルで正規化関数の入出力が一致 | TC-07 |
| AC-5 | 変異注入で対応 TC が FAIL | TC-08 |
| AC-6 | `run-tests.sh` rc=0 + 既存 4 本 PASS | TC-09 |
| AC-7 | `hook-enforcement.md` の更新と件数訂正 | TC-10 |
| AC-8 | fail-closed 2 条件で block + 絶対パスは block しない | TC-11 / **TC-11b** |
| AC-9 | 監査ログが生パスを保持 | TC-12 |
| AC-10 | apply スクリプトの `--revert` と smoke check | TC-13 |
| AC-11 | fork 増加ゼロ | TC-14 |

## テストケース一覧

### TC-01 — 直積: 全変換クラスで HO が block（AC-1）

- **前提**: patch 適用済み hook（sandbox 複製）/ TASK 文脈（`PLANGATE_HOOK_TASK` 設定）
- **入力**: HO 9 カテゴリの代表パス（`case` 文から導出・**15 パターン**）× 変換 7 種 + 2 種複合
  | 変換クラス | 適用例（対象が `bin/plangate` の場合） |
  |---|---|
  | 原形 | `bin/plangate` |
  | `./` 前置 | `./bin/plangate` |
  | `//` | `bin//plangate` / **`.//bin/plangate`** |
  | `/./` | `bin/./plangate` |
  | `..` 往復 | `bin/../bin/plangate` |
  | repo root 跨ぎ | `$REPO_ROOT/./bin/plangate` |
  | 大小文字 | `Bin/PlanGate` |
  | 末尾空白 | `"bin/plangate "` |
  | 2 種複合 | `./bin/../bin/plangate` / `.//BIN/plangate` |
- **期待出力**: **全件 rc=2** かつ `HARDENING_OVERRIDE` を出力
- **種別**: Integration / 自動化可
- 🚩 **件数を固定しない**（`case` 文から導出する既存 TC-00 の方式を踏襲）
- 🚩 **`.//` 形（`.//CLAUDE.md` / `.//bin/plangate`）を必ず含める**（RiverReview critical）。**v3 の順序（先頭 `./` 除去 → 畳み込み）では skip されていた**ケースで、**4 回のレビューが見逃した**。畳み込みを先に置く設計（v4）でのみ block される。**このケースが落ちると critical がそのまま残る**

### TC-02 — maintenance `allowed_paths` が一致し続ける（AC-2）

- **前提**: patch 適用済み hook / `allowed_paths: ["docs/working/TASK-1101/*"]` の maintenance ファイル
- **入力**: `PLANGATE_HOOK_FILE=docs/working/TASK-1101/status.md`
- **期待出力**: `MAINTENANCE_SKIP`（**`OUT_OF_SCOPE` にならない**）
- **根拠**: L207-225 の `fnmatch.fnmatchcase` は**大小文字を区別**する。`_norm_target` が小文字化されると一致しなくなる
- **種別**: Integration / 自動化可

### TC-03 — C-3 conversation 経路が生き続ける（AC-2）

- **前提**: patch 適用済み hook / conversation mode 有効
- **入力**: `PLANGATE_HOOK_FILE=docs/working/TASK-T45/approvals/c3.json`
- **期待出力**: **rc=0 / `C3_CONVERSATION_SKIP`**
- **根拠**: C-2 の mutation 実測では `_norm_target` 小文字化により **rc=2「SKIP 拒否: SKIP_REASON 未設定」** に転じた（`TASK-` の大文字が潰れて L152 の case に不一致）
- **種別**: Integration / 自動化可
- 🚩 **これは fail-open ではなく fail-closed 方向の退行**だが、**block されないケース**（conversation 経路に入らないだけ）なので**気づきにくい**

### TC-04 — doc-light の拡張子判定が不変（AC-2）

- **前提**: patch 適用済み hook / no-task 文脈 / maintenance ファイル不在
- **入力**: `PLANGATE_HOOK_FILE=docs/working/TASK-1101/status.md`（非 HO の `.md`）
- **期待出力**: **rc=0 / `DOC_LIGHT_SKIP`**
- **種別**: Integration / 自動化可

### TC-05 — 既存 TC-06 の 10 件が block されない（AC-3）

- **前提**: patch 適用済み hook / TASK 文脈と no-task 文脈の両方
- **入力**: `.claude/rules/x.txt` / `.claude/skills/x/SKILL.md` / `scripts/hooks/x.py` / `scripts/_helper.py` / `scripts/x.sh` / `bin/other` / `schemas/x.json` / `.github/workflows/x.json` / `docs/AGENTS.md` / `docs/working/TASK-T65/CLAUDE.md.bak`
- **期待出力**: **rc≠2 かつ `HARDENING_OVERRIDE` を出力しない**
- **種別**: Integration / 自動化可

### TC-06 — 変換を施した非 HO ケースが block されない（AC-3）

- **前提**: 同上
- **入力**: `docs/x/../AGENTS.md` / `scripts/hooks/../hooks/x.py` / `bin/../bin/other` / `docs/working/TASK-T65/../TASK-T65/CLAUDE.md.bak` / `.claude//skills/x/SKILL.md`
- **期待出力**: **rc≠2 かつ `HARDENING_OVERRIDE` なし**
- **根拠**: 既存 TC-06 の 10 件は**正規化しても値が変わらない**ため、正規化強化による偽陽性を検出できない
- **種別**: Integration / 自動化可
- ⚠️ **注意**: `docs/x/../AGENTS.md` → 畳み込みで `docs/AGENTS.md`（**非 HO・正しい**）。一方 `x/../AGENTS.md` → `AGENTS.md`（**HO へ変化・仕様どおり**）。この差を TC で明示する

### TC-07 — 4 シェルで正規化関数の入出力が一致（AC-4）

- **前提**: 正規化関数の単体ファイル
- **入力**: 各シェル（`sh` / `dash` / `bash` / `zsh`）で `_pg_fold_path` を直接評価
  | 入力 | 期待出力 | 変換クラス |
  |---|---|---|
  | `docs/../CLAUDE.md` | `CLAUDE.md` | `..` |
  | `bin/../bin/plangate` | `bin/plangate` | `..` |
  | `a/b/../../c` | `c` | `..` 多段 |
  | `bin//plangate` | `bin/plangate` | `//` |
  | **`.//CLAUDE.md`** | **`CLAUDE.md`** | **`//` + `./`（critical ケース）** |
  | `bin/./plangate` | `bin/plangate` | `/./` |
  | **`Bin/PlanGate`** | **`bin/plangate`** | **大小文字** |
  | **`"CLAUDE.MD "`** | **`claude.md`** | **大小文字 + 末尾空白** |
  | **`$REPO_ROOT/./BIN/plangate`** | **`bin/plangate`** | **repo root 跨ぎ + 大小文字** |
  | `/private/tmp/x/note.md` | `/private/tmp/x/note.md` | **絶対パスは不変**（skip 側） |
- **期待出力**: **4 シェルすべてで同一**
- **種別**: Unit / 自動化可
- 🚩 **`ta-65` 経由では検出できない**（hook を常に `sh` で起動する）
- 🚩 `LANG=ja_JP.UTF-8` のケースを含める（小文字化のマルチバイト挙動 / plan Q3）
- 🚩 **大文字を含む入力を必ず含める**（M-7）。**旧版は `..` / `//` / `/./` の 3 クラスしか測っておらず、最もシェル差・locale 差が出る小文字化が未測定だった**
- **回帰の根拠 1**: C-2 実測で **zsh のみ無変換**（`docs/../CLAUDE.md` → `docs/../CLAUDE.md`）だった
- **回帰の根拠 2**: RiverReview 実測で **`sh`（bash 3.2）/ `dash` とも `${v,,}` は `bad substitution`**。小文字化は自作ロジックになるため、**AC-4 が小文字化について再び false green になる**リスクがあった

### TC-08 — 変異注入で検出力を実証（AC-5）

- **前提**: patch 適用済み hook（sandbox）
- **入力**: **関数内の各正規化ステップ**を 1 つずつ無効化した **7 変異**（末尾空白 / `./` / `//` / `/./` / `..` / repo root / 小文字化）**+ 第 8 変異**
- **第 8 変異（M-4 / 必須）**: **`_norm_target` 自体に `_ho_key` の正規化（特に小文字化）を適用する** ＝ **v1 の設計そのものを注入**する
  - **期待**: **TC-02 / TC-03 / TC-04 と `ta-45` が FAIL** する
  - **理由**: TC-02/03/04 は「壊れていないこと」の表明で、**patch 未適用でも PASS する**。7 変異はいずれも `_ho_key` 側しか壊さないため **TC-02/03/04 を kill できない**。第 8 変異が無いと、**R-001（critical / maintenance 窓の全滅・C-3 conversation の silent 死）に対する唯一の回帰網が空振り fixture のまま残る**
- **期待出力**: **各変異に対応する TC が FAIL** する
- **種別**: Verification Automation
- 🚩 **call site を壊さない**（全変異が同じ FAIL に潰れる）
- 🚩 **patch 未適用の hook に対して TC-01 が FAIL** することも確認する
- 🚩 **`.//` 形の変異**（畳み込みを `./` 除去の後ろへ動かす）で **TC-01 が FAIL** することを確認する（RiverReview critical の回帰検出）

### TC-09 — 既存テストの回帰（AC-6 / S-4）

- **前提**: patch 適用済み hook
- **入力**: `ta-65` / `ta-12`（TC-24 / TC-33）/ `ta-39`（TC-03 / TC-06）/ `ta-45` / `sh tests/run-tests.sh`
- **期待出力**: **すべて PASS / rc=0**
- **種別**: Integration
- 🚩 baseline は**着手時に現 main で再測定**。**絶対件数を契約値にしない**
- 🚩 `ta-45` が PASS することが **AC-2 の実質的な担保**

### TC-10 — 文書の更新（AC-7 / S-3）

- **入力**: `docs/ai/hook-enforcement.md`
- **期待出力**（**機械確認できる形に是正 / M-8・m-7**）:
  | # | 検査 | 方法 |
  |---|---|---|
  | a | 「既知の残存」に**解消済み項目が残っていない** | grep |
  | b | **残存ゼロ、または追跡 issue 番号が本文に存在** | grep |
  | c | **`Edit\|Write` 経路に限定されることが明示**されている | `grep -F 'Edit|Write'` |
  | d | **`Bash` 経路の追跡先として `#1104` が本文にある** | `grep -F '#1104'` |
  | e | **変換クラスの列挙が 7 種**（旧記述は `..` / 大小文字 / 末尾空白 の 3 種のみ） | grep |
- **種別**: `grep` による機械確認（**手動判断に委ねない** — 旧版は「残存があれば明示」で、**残存を書けば PASS してしまう**構造だった）
- 🚩 **(c)(d) が無いと「HO は常時 block」へ戻り、Bash 経路の穴が文書上消える**（M-8）
- ⚠️ **(e) の表現に注意**（m-7）: 旧記述は「ta-65 TC-07 が **4 ケース**を KNOWN-GAP として固定している」と **TC の内容**を述べており、**迂回総数を 4 件と主張してはいない**。訂正対象は「総数」ではなく「**列挙した変換クラスの不足**」

### TC-11 — fail-closed（AC-8 / 2 条件）

> **簡易 C-1 の N-2 を受けて修正**。旧版にあった「畳み込み後も絶対パスが残る入力」は **到達不能な条件**で、入力値を書けない**空振り fixture** だった（正規化順序の (5) 先頭 `/` 除去がある限り (5) 通過後に絶対パスは残らない）。**(5) を削除**し、当該行も削除した。

- **前提**: patch 適用済み hook / TASK 文脈
- **入力 / 期待出力**（**すべて具体的な入力値を持つ**）:
  | # | 入力 | 期待 | 条件 |
  |---|---|---|---|
  | a | `../plangate/CLAUDE.md` | **rc=2** | 先頭 `..` が残る |
  | b | `../../CLAUDE.md` | **rc=2** | 同上（多段） |
  | c | `..` | **rc=2** | 畳み込み結果が空 + 先頭 `..` |
  | d | `a/b/../../../CLAUDE.md` | **rc=2** | 畳み込みで先頭 `..` に転じる |
  | e | `x/`×257 + `CLAUDE.md` | **rc=2** | セグメント上限（256）超過 |
- **種別**: Integration / 自動化可
- 🚩 **(d) が重要**: 畳み込み**前**は先頭 `..` でないが、**後**に転じる。判定を畳み込みの後に置かないと素通りする

### TC-11b — 絶対パスは block しない（AC-8 の偽陽性防止 / N-1）

- **前提**: 同上
- **入力 / 期待出力**:
  | 入力（**具体値。省略記法を使わない** / m-6） | 期待 | 理由 |
  |---|---|---|
  | `/tmp/plangate-tc11b/note.md` | **rc≠2** | **作業ディレクトリへの書き込み。block すると作業が止まる** |
  | `/tmp/foo.txt` | **rc≠2** | repo 外 |
  | `/tmp/plangate-tc11b-other-repo/CLAUDE.md` | **rc≠2** | **別リポジトリ**の `CLAUDE.md` は本 repo の HO ではない |
  | `/CLAUDE.md` | **rc≠2** | FS root。repo に到達しない |

  > テスト実行時に `/tmp/plangate-tc11b*` を作成・削除する（自己完結。**実在の scratchpad パスを埋め込まない** — 環境依存になり自動化不能になるため）
- **種別**: Integration / 自動化可
- 🚩 **これは「塞がないことの表明」**。AC-8 を「絶対パスも block」に広げる実装が入ったら **FAIL する**（偽陽性の回帰検出）
- **根拠**: 現 main での実測 rc=0（4 件とも）

### TC-12 — 監査ログが生パスを保持（AC-9 / S-1）

- **前提**: patch 適用済み hook
- **入力**: `PLANGATE_HOOK_FILE=bin/../bin/plangate`
- **期待出力**: block（rc=2）し、**`reason` と `_audit/hook-events.log`** に **`bin/../bin/plangate`（原文）** が残る。正規化後の `bin/plangate` **ではない**
- **種別**: Integration / 自動化可
- **根拠**: 攻撃を塞ぐ変更が「誰が何を編集しようとしたか」の証跡を消してはならない
- ⚠️ **`skip-decision-log.jsonl` は対象外**（M-1 / v4 で是正）。実測: HO block 経路は `log_event` → **`hook-events.log` のみ**を呼んで `exit 2` する。`skip-decision-log.jsonl` は **SKIP 3 経路でしか書かれない**。旧版の TC-12 は両方を要求しており、**永久 RED か、HO 保護ファイルへ新規ログ出力を足す（= Human 適用範囲の拡大）かの二択**になっていた

### TC-13 — apply スクリプトの安全性（AC-10）

- **入力**: `sh scripts/apply-1101-ho-normalization.sh --dry-run` / `--apply` / `--revert`（**`--apply` と `--revert` は sandbox で実行**）
- **期待出力**:
  - `--dry-run` が既定で、実ファイルを変更しない
  - `--apply` 直後に smoke check（HO 1 件 rc=2 / 非 HO 1 件 rc≠2 / 実行時間が閾値内）が走る
  - smoke check 失敗時に**自動 revert** され、元の hook に戻る
  - `--revert` が単独でも機能する
- **種別**: Integration
- 🚩 **AI は本 repo の実ファイルに対して `--apply` を実行しない**

### TC-14 — fork 増加ゼロ（AC-11）

- **入力**: 正規化前後の hook を 200 回実行し、`sed` / `tr` の呼び出し回数と実行時間を比較
- **期待出力**: **追加 fork ゼロ**。実行時間の増加が hook 全体（0.048s）に対して無視できる範囲
- **種別**: Verification Automation
- **参考実測（C-2）**: `sed` 1 回挟む実装 ≒8ms/回 / 純シェル ≒1〜2ms/回

## エッジケース

| ケース | 扱い | 根拠 |
|---|---|---|
| 空文字列 | skip（現行踏襲） | 現行挙動を変えない |
| `/` のみ | skip | FS 到達不能 |
| `/CLAUDE.md`（FS root） | **skip** | 到達不能を実測確認（C-2）。**TC-11b で「block しないこと」を表明**（N-1 の確定） |
| `CLAUDE.md/`（末尾スラッシュ） | skip | 到達不能（ENOTDIR） |
| `" CLAUDE.md"`（先頭空白） | skip | 到達不能を実測確認 |
| `bin\plangate`（Windows 風） | skip | 到達不能を実測確認 |
| `..` のみ | **block** | fail-closed（TC-11） |
| シンボリックリンク経由 | **解決しない**（現行踏襲） | 意味論を変えない。Non-goal |
| マルチバイトを含むパス | TC-07 で `LANG` を変えて確認 | plan Q3 |
