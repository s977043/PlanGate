# TEST CASES — TASK-1044

> plan: `plan.md` / AC 対応は `pbi-input.md` 受入基準表を正とする。
> 新規 TC は `ta-61-extra-contract.sh` へ追加（TC-30 以降）。シェルマトリクスと変異は
> evidence 実測（TA 本体は dash 固定 — CI の sh 実体と一致させる）。

## 受入基準 → テストケースマッピング

| AC | TC |
|---|---|
| AC-1（helper 欠落 + env 漏出 + 直接実行 → 4 シェル rc=1） | TC-30 + EV-1 |
| AC-2（helper 存在 + env 漏出 + 直接実行 → standalone 契約有効） | TC-31 + EV-2 |
| AC-3（正規経路無回帰） | TC-33 / TC-34 |
| AC-4（新述語 15 出現バイト一致） | TC-35 |
| AC-5（変異注入で検出力実証） | EV-3（pre-fix red）/ EV-4（call site 変異 kill） |
| AC-6（F-3 fail-closed） | TC-32 |
| AC-7（ta-61 既存 TC 無回帰） | TC-36 |

## テストケース一覧

### TC-30: env 漏出 + helper 欠落 + 直接実行は rc 非 0（自動 / ta-61 追加）

- 前提: sandbox に層 A 1 本（例: ta-46）のみ複製（helper を置かない）
- 入力: `PG_HARNESS_SOURCED=1 FIXTURES_DIR=/tmp EXTRAS_DIR=$SBX dash $SBX/ta-46-*.sh`
- 期待出力: **rc=1** + stderr に `helper unresolved`
- 種別: 自動（contract TA）。現 HEAD では rc=0（実測済み）= pre-fix red の根拠

### TC-31: env 漏出 + helper 存在 + 直接実行は standalone 契約有効（自動 / ta-61 追加）

- 前提: sandbox に層 A 1 本 + `_extra-contract.sh` を複製
- 入力: 3 env 漏出状態で `dash $SBX/ta-XX-*.sh`
- 期待出力: standalone として動作 — summary 行 `TA-<NN> standalone:` が出力され、
  rc が standalone 契約（0/1/3）に従う（現 HEAD では summary 無し・rc=0 = red）
- 種別: 自動

### TC-32: init 前 finalize は fail-closed（自動 / ta-61 追加 / F-3）

- 前提: helper のみ source し `pg_extra_contract_init` を呼ばない fixture
- 入力: fixture から直接 `pg_extra_contract_finalize` を呼ぶ（直接実行）
- 期待出力: **rc=4** + stderr に `finalize called before init`
- 種別: 自動（Q-1 裁定が代替案になった場合は期待値を裁定に合わせて確定）

### TC-33: フルスイート無回帰（自動）

- 入力: `sh tests/run-tests.sh`
- 期待出力: rc=0 / `0 failed`（source 経路で direct=0 → harness 判定が従来どおり）
- 種別: 自動（既存 runner）

### TC-34: 清浄 env での standalone 直接実行が従来 rc を維持（自動）

- 前提: 清浄 env（3 env unset）
- 入力: 層 A 12 本を `sh tests/extras/ta-XX-*.sh` で直接実行
- 期待出力: 各本の従来 rc（0 または 3 — 前提未充足の本は rc=3）と summary 書式不変
- 種別: 自動

### TC-35: 新述語の 15 出現バイト一致（自動 / ta-61 の照合 TC 更新）

- 入力: Mode resolution v2 の判定 2 行を canonical 文字列として、層 A 12 +
  ta-61 本体 + ta-61 fixture 複製 + helper `_pg_extra_resolve_mode` を grep 照合
- 期待出力: 照合対象リストの全ファイルで一致（bad=0）。**絶対件数を契約値にせず**、
  対象リストとの同値で判定（成長ディレクトリ対策）
- 種別: 自動

### TC-36: ta-61 既存 TC（TC-01〜29）全 PASS（自動）

- 入力: `sh tests/extras/ta-61-extra-contract.sh`（清浄 env）+ harness 経由
- 期待出力: 全 PASS（特に TC-01 系 harness fixture（tc01.sh 名 = 非 ta-* のため
  ガード非発火）と sandbox 系 TC-14〜17/29 の無回帰）
- 種別: 自動

## Evidence 実測（TA 外・ログ必須）

### EV-1: 4 シェルマトリクス（helper 欠落）

- dash / zsh / bash / sh × TC-30 シナリオ → 修正後すべて rc=1（AC-1）。
  pre-fix 値（dash=0 / zsh=0 / bash=1 / sh=1）と対で記録

### EV-2: 4 シェルマトリクス（helper 存在）

- dash / zsh / bash / sh × TC-31 シナリオ → 修正後すべて standalone 契約（AC-2）。
  pre-fix 値（4 シェル rc=0）と対で記録

### EV-3: pre-fix red（AC-5 (a)）

- 修正前 HEAD に TC-30/31 のみ適用して実行 → FAIL することをログ化
  （新 TC が現不具合を実際に検出できる証明）

### EV-4: 変異注入 kill（AC-5 (b)）

- 変異 M-1: bootstrap の case 行（direct-exec ガードの call site）を除去 →
  TC-30/31 が dash で FAIL（kill）
- 変異 M-2: helper resolve_mode 側のガードのみ除去（bootstrap 側は残す）→
  TC-31 が FAIL（mode 分裂検出）
- 変異 M-3: F-3 明示検査を除去 → TC-32 が FAIL
- 変異は sandbox 複製上でのみ実施（本体 checkout を汚さない）

## エッジケース

- `$0` にディレクトリを含まない直接実行（`cd tests/extras && dash ta-46-*.sh`）:
  `${0##*/}` は無変換で basename のまま → ガード発火（TC-30 バリアントとして 1 回実測）
- runner を `sh tests/run-tests.sh` / `cd tests && sh run-tests.sh` の双方で起動:
  `$0` はいずれも `run-tests.sh` に終わる → 非発火（TC-33 に包含）
- ta-61 sandbox の ta-97/98/99 fixture: `ta-*.sh` 名だが清浄 env での直接実行のため
  従来から standalone → 挙動不変（TC-36 に包含）
- 2 env のみ漏出（部分汚染）: 既存 TC-01b/01c が standalone 解決を検証済み → 不変
