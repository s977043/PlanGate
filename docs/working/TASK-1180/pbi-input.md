# PBI INPUT PACKAGE — TASK-1180

対象 issue: [#1180](https://github.com/s977043/plangate/issues/1180) の **M-1 のみ**（carve-out）

## Context / Why

PR #1174（`Closes #1153`）は TC-C3 / TC-C8 の fixture を `plugin/pa` → `plugin/plangate`
へ更新したが、**TC-C6 の `plugin/pa` を取り残した**。その結果 TC-C6 は
「パス不一致（条件④ `_same_intra_root_path`）」ではなく「非 export plugin（条件③）」で
rc=1 になるようになり、**条件④ を一切測らなくなった**。

`--selftest` はどこからも起動されないため（#1180 m-2）、**条件④ は自動テストで
まったく pin されていない**。今後 `_same_intra_root_path` が壊れても全テストが緑のまま通る。

## What (Scope)

### In scope

- `tests/extras/ta-69-distribution-checks.sh` の TC-C6 fixture を
  `plugin/pa/skills` → `plugin/plangate/skills` へ是正（**1 語**）
- 変異注入（M2b: `_same_intra_root_path` を常に True）による検出力の実証
  （修正前 SURVIVE → 修正後 KILL）

### Out of scope

- #1180 の AC-2〜AC-8（selftest 配線 / TC-C12 ガード / provenance ベースのミラー判定 /
  doctor からの `--mirror-plugin` 到達 / docs 追補）。判定ロジック変更を含み high-risk のため別スライス
- `scripts/check-skill-name-collisions.py` の変更（本 PBI では**変異注入の一時適用のみ**、
  commit しない）

## 受入基準

- **AC-1**: TC-C6 の fixture が `plugin/plangate/skills` になっている
- **AC-2**: 変異 M2b 適用下で、**修正前は TC-C6 が PASS（SURVIVE）**、
  **修正後は TC-C6 が FAIL（KILL）** することを実測出力で示す
- **AC-3**: 修正後の ta-69 が **27 passed / 0 failed**（回帰なし）
- **AC-4**: 変更は `tests/extras/ta-69-distribution-checks.sh` の 1 ファイル 1 行に閉じる

## Notes from Refinement

- #1180 の grep 出力には `plugin/pa/skills` が 3 箇所（:204 / :216 / :229）現れるが、
  :204 は TC-C4（3 定義）、:216 は TC-C5（plugin 同士の同名）で、いずれも
  **`plugin/pa` + `plugin/pb` の対として意図的**。是正対象は :229（TC-C6）のみ。
- issue AC-8 の規律「現行実装で SURVIVE することを先に示してから修正する」に従う。

## Estimation Evidence

- **Risks**: 低。テスト fixture のみで本番コードに触れない
- **Unknowns**: なし（レビュアーが修正内容と実測値を issue 本文で提示済み）
- **Assumptions**: `plugin/plangate` が本リポジトリの `DEFAULT_MIRROR_PLUGINS` である
  （`scripts/check-skill-name-collisions.py:113` で実測確認済み）
