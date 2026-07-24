# TEST CASES — TASK-0877

> 入力: [`plan.md`](./plan.md)
> 実装先: `tests/extras/ta-26-plugin-sync.sh`（既存 TC-01〜TC-08 は非退行、TC-03 のみ判定式是正）
> C-2 反映済み（R-101 / R-102 / R-202 / R-105 / R-208 / R-107 ほか）

## 共通の実装規約（C-2 由来）

- **非ゼロ rc の捕捉書式**は `tests/extras/README.md` 規約 4 の正書式に統一する: `rc=0; out="$(cmd)" || rc=$?`。`out=$(cmd) || true` の直後に `$?` を読む書法は禁止（Refs: R-103 / 既存の誤りは `ta-26:51` の 1 箇所のみ）
- **sandbox は TC-08 と同じ最小構成**（`CHANGELOG.md` と `.claude-plugin/marketplace.json` を置かない）。TC-05 のフル sandbox を真似ると marketplace 経路の `exit 1` が有効化され exit 3 の assert を汚染する（Refs: R-208）
- `mktemp -d` + `register_cleanup` + 末尾早期 `rm -rf`（冪等）。trap は使わない。変数は `_t26_` / `PG_T26_` プレフィクス

## 受入基準 → テストケース マッピング

| AC | 内容 | テストケース |
|----|------|------------|
| AC-1 | guard 発火時に exit 3（複数 label でも 1 回） | TC-10 / TC-16 |
| AC-2 | `PLANGATE_ALLOW_MASS_DELETE=1` で override + 解除ログ | TC-11（+ TC-15 で CI env 不使用を担保） |
| AC-3 | stale カウントが dry-run と実行で一致 | TC-12 |
| AC-4 | `PG_HARNESS_SOURCED` で standalone 判別 | TC-13 |
| AC-5 | DELETE 正常系の固定 | TC-09 |
| AC-6 | F5 の別 issue 分離を明示記録 | TC-14（文書検査） |
| AC-7 | `.github/workflows/*.yml` を touch しない | TC-15（差分検査） |
| AC-8 | TC-03 が dry-run の exit code を AND 判定で実検証 | TC-03（是正版） |
| AC-9 | guard メッセージが stderr + label + override 手順を含む | TC-10 |

## テストケース一覧

### TC-03（是正）— dry-run の exit code を実検証

| 項目 | 内容 |
|------|------|
| 前提 | 実リポジトリ（guard が発火しない通常状態。全 label で stale=0 を C-2 実測済み） |
| 入力 | `rc=0; _t26_out="$(sh scripts/sync-plugin-plangate.sh --dry-run 2>&1)" || rc=$?` |
| 期待 | **`rc = 0`** **かつ** 出力に `Sync complete` を含む（**AND**。OR 判定は禁止 — guard 発火時も終端で `Sync complete` を出してから exit 3 するため OR だと空振りが再発する） |
| 種別 | Integration（自動） |
| 現状の欠陥 | `_t26_out=$(...) || true` の直後の `$?` が常に 0 で、exit code を検証していない（`ta-26:50-51`） |

### TC-08（既存・非退行）— guard 発火時に削除を保留

| 項目 | 内容 |
|------|------|
| 前提 | sandbox: `.claude/agents/` に 1 件（keep.md）、`plugin/plangate/agents/` に stale 4 件 |
| 入力 | `sh <sandbox>/scripts/sync-plugin-plangate.sh` |
| 期待 | 出力に `#861 safety guard` を含み、stale 4 件が全て残存 |
| 種別 | Integration（自動） |

### TC-09（新規・AC-5）— DELETE 正常系

| 項目 | 内容 |
|------|------|
| 前提 | sandbox: src 2 件（keep-a.md / keep-b.md）、dst に同 2 件 + stale 1 件 |
| 入力 | `sh <sandbox>/scripts/sync-plugin-plangate.sh` |
| 期待 | stale 1 件が **削除される**・出力に `#861 safety guard` の WARN を**含まない**・exit 0 |
| 種別 | Integration（自動） |

### TC-10（新規・AC-1 / AC-9）— guard 発火時 exit 3 + メッセージ要件

| 項目 | 内容 |
|------|------|
| 前提 | TC-08 と同じ**最小** sandbox（src=1 / stale=4） |
| 入力 | `rc=0; out="$(sh <sandbox>/scripts/sync-plugin-plangate.sh 2>&1)" || rc=$?` および stderr 単独捕捉 |
| 期待 | **`rc = 3`**（**`rc = 1` でないこと**を明示 assert。先行 fatal の `exit 1` と取り違えない / Refs: R-206）・stale 4 件残存・発火メッセージが **stderr** に出る・メッセージが **対象 label（`agents`）** と **`PLANGATE_ALLOW_MASS_DELETE=1`** の文字列を含む |
| 種別 | Integration（自動） |

### TC-11（新規・AC-2）— override

| 項目 | 内容 |
|------|------|
| 前提 | TC-10 と同じ最小 sandbox |
| 入力 | `rc=0; out="$(PLANGATE_ALLOW_MASS_DELETE=1 sh <sandbox>/scripts/sync-plugin-plangate.sh 2>&1)" || rc=$?` |
| 期待 | **`rc = 0`**・stale 4 件が削除される・**override した旨の解除ログが必ず出力される**（監査可能性 / Refs: R-106, R-211） |
| 種別 | Integration（自動） |

### TC-12（新規・AC-3）— dry-run と実行で guard 判定が一致

| 項目 | 内容 |
|------|------|
| 前提 | **乖離帯 src=3 / stale=4** の最小 sandbox を 2 部用意（A: dry-run 用 / B: 実行用）。src は `keep-a/b/c`、dst は src と重複しない stale 4 件 |
| 入力 | A に `--dry-run`、B に通常実行 |
| 期待 | **両方で guard が発火する**（＝判定が一致）。A は exit 0 かつファイル不変・`WOULD DELETE` を出さない / B は exit 3 かつ stale 4 件残存 |
| 空振り防止 | src=1 / stale=4 を使ってはならない。この条件は**現行実装でも両モードで発火**するため B-1 判定式の回帰検出力がゼロになる。乖離が起きるのは `src < stale ≤ 2*src` の帯であり、現行実装ではこの fixture で dry-run 非発火（`WOULD DELETE` 4 件予告）/ 実行発火（`src=3 / dst=7`）と食い違うことをオーガナイザーが実測済み（Refs: R-101） |
| 種別 | Integration（自動） |

### TC-13（新規・AC-4）— `PG_HARNESS_SOURCED` による standalone 判別

| 項目 | 内容 |
|------|------|
| 前提 | **自己再帰しない設計であること**（extras から `tests/run-tests.sh` や自身を無条件に再実行すると全スイート再入ループになる / Refs: R-202・critical。repo 内に前例 0 件） |
| 入力 | ① `PG_T26_NO_RECURSE=1`（export 済みガード env）を前置した `sh tests/extras/ta-26-plugin-sync.sh` を **1 段だけ**起動。ta-26 冒頭でこの env を検出したら TC-13 自体をスキップする<br>② `FIXTURES_DIR=/tmp/pg-t26-dummy PG_T26_NO_RECURSE=1 sh tests/extras/ta-26-plugin-sync.sh`（`PG_HARNESS_SOURCED` 未設定・`FIXTURES_DIR` のみ汚染）<br>③ harness 側は子プロセスを起動せず、**静的自己証明**（このテストが run-tests から source されて走っている事実）+ `grep -q 'PG_HARNESS_SOURCED=1' tests/run-tests.sh` で確認 |
| 期待 | ① 出力に `TA-26 standalone:` サマリ行が出る・exit 0<br>② **standalone として扱われる**（サマリ行が出る・誤ルート導出で壊れない）＝ `FIXTURES_DIR` 汚染に耐える。現行の `FIXTURES_DIR` 判定ではここが standalone 判定に失敗するため、この入力が AC-4 の実質的な検証点（Refs: R-102）<br>③ harness source 時はサマリ行が出ず run-tests の Results に合算され、run-tests 側に `PG_HARNESS_SOURCED=1` の代入が存在する |
| 種別 | Integration（自動） |

### TC-16（新規・AC-1）— 複数 label 同時発火

| 項目 | 内容 |
|------|------|
| 前提 | 最小 sandbox に **agents / rules / commands の 3 label 分**の src（各 1 件）と dst（各 stale 4 件）を用意（TC-08 の sandbox は agents しか作らず、他 label は `SKIP (src not found)` で早期 return するため 1 label しか通らない / Refs: R-209） |
| 入力 | `rc=0; out="$(sh <sandbox>/scripts/sync-plugin-plangate.sh 2>&1)" || rc=$?` |
| 期待 | **WARN が label ごとに 3 行**出る・**`rc = 3` が 1 回**（終端集約）・**各 label のコピーは実行済み**（A-1 案の中核「コピーは阻害しない」の担保 / Refs: R-105, R-209） |
| 種別 | Integration（自動） |

### TC-14（AC-6）— F5 の分離記録

| 項目 | 内容 |
|------|------|
| 入力 | `plan.md` Q2 / `handoff.md` / follow-up issue 番号 |
| 期待 | 3 箇所すべてに「F5（**src 駆動の無ガード削除 2 経路** = L140-150 / L283-296。L317-330 は allowlist 駆動で対象外）は別 issue（**#914**）へ分離」と記録され、R-204（README 規約追記と既存 11 extras の移行）も同 issue に含まれている |
| 種別 | 文書検査（手動） |

### TC-15（AC-7）— CI yml 不変

| 項目 | 内容 |
|------|------|
| 入力 | `git diff --name-only origin/main...HEAD` および `grep -rn "PLANGATE_ALLOW_MASS_DELETE" .github/` |
| 期待 | `.github/workflows/` 配下の変更ファイルが 0 件、かつ `.github/` 配下に `PLANGATE_ALLOW_MASS_DELETE` の出現が 0 件（override を CI `env:` に置かない / AC-2 後段） |
| 種別 | 差分検査（自動） |

## エッジケース

| # | ケース | 期待 | 対応 TC |
|---|--------|------|--------|
| E-1 | stale = 0（削除候補なし） | guard 非発火・exit 0 | TC-03 / TC-04（実 repo は stale=0） |
| E-2 | dst が空（stale = 0 に帰着） | guard 非発火（初回同期を阻害しない） | — |
| E-3 | src が空・dst に多数 | guard 発火・exit 3（#861 の本来ケース） | TC-10 の縮退形 |
| E-4 | 複数 label（agents / rules / commands）で同時発火 | 終端で 1 回だけ exit 3・各 label の WARN は個別に出る・コピーは全 label で実行済み | **TC-16** |
| E-5 | dry-run で発火 | WARN 出力あり・**exit 0**・ファイル不変 | TC-12(A) |
| E-6 | override 指定時に guard 条件を満たさない | 通常どおり削除・解除ログは出さない（出しても無害） | TC-09 の派生 |
| E-7 | 外部 env に `FIXTURES_DIR` が漏れた状態での standalone 実行 | standalone として扱われ誤ルート導出で壊れない | TC-13② |
