# Step 4 — 新 TC の検出力（patch 未適用の hook に対して FAIL すること）

> 実施: 2026-08-15（exec） / branch `feat/1101-ho-normalization` / base `73ac1db`
> OS: Darwin 25.6.0 (macOS 26.6.1 / arm64) / `/bin/sh` = bash 3.2 系

plan Step 4 の🚩「**patch 未適用の hook に対して新 TC が FAIL すること**」の実証。

## (a) TC-07（real hook に適用済みかを測る TC）

使い捨て clone（`73ac1db`）に本 PBI の `ta-65` / fixture / apply スクリプトだけを入れ、
**hook は未適用のまま・PENDING-APPLY flag も置かない**（= fixed 期待）状態で実行。

```
sh tests/extras/ta-65-eh3-ho-task-context.sh </dev/null   # rc=1
  [FAIL] TC-07 (#1101): 期待 fixed に対し 9/9 件が不一致
TA-65 standalone: 15 passed, 1 failed
```

→ **未適用を 9/9 で検出する**。flag を置くと PENDING-APPLY として受理し PASS に戻る
（`--apply` が flag を自動削除するため、適用後に flag を残すと TC-07b が
「stale PENDING-APPLY 宣言」で FAIL する）。

## (b) TC-08（直積）

TC-08 と同一のパターン導出・同一の変換 11 形を、**未適用の
`scripts/hooks/check-plan-hash.sh`**（本リポジトリ現行）に対して実行:

```
(b) patterns=15 / 未適用 hook 直積: 133 / 165 件が block されない
```

同じ直積を **patch 済み hook** に対して実行した結果（ta-65 TC-08 本体）:

```
[PASS] TC-08 (AC-1): 直積 165 件（15 パターン × 変換 11 形）すべて rc=2 + HARDENING_OVERRIDE
```

→ **未適用では 133/165 が素通り、適用後は 0/165**。TC-08 は「既知 4 ケースの
狙い撃ち実装」では PASS しない（変換 11 形 × 15 パターンを全数評価するため）。

## (c) TC-09 / TC-09b / TC-10 / TC-11 / TC-12

| TC | 未適用 hook での状態 | 備考 |
|---|---|---|
| TC-09（fail-closed） | 未適用 hook には fail-closed 判定自体が存在しない（`..` は素通り = rc=0） | Step 0 再実測で `../plangate/CLAUDE.md` → rc=0 を確認済み |
| TC-09b（絶対パス非 block） | 未適用でも PASS（**塞がないことの表明**なので当然） | 偽陽性の回帰検出用。M1〜M9 でも FAIL しない |
| TC-10（`_norm_target` 不変） | 未適用でも PASS（**壊れていないことの表明**） | 検出力は**第 8 変異 M8**で実証（`evidence/test-runs/mutation-step5.md`） |
| TC-11（監査ログ生パス） | 未適用では `reason` が `_norm_target`（=生パスと同値のため PASS しうる） | 検出力は変異 M5 で実証（3 件 FAIL） |
| TC-12（正本 byte 一致） | patch 済み複製が作れない場合は TC-00c が FAIL | drift 検出は M1〜M7・M9 で FAIL を実測 |
