# PBI INPUT PACKAGE: install.sh 所有権修正のレビュー指摘是正（PR #1639）

> **下書き（AI 作成・Human 確認待ち）**: issue #1636 と PR #1639 の敵対レビュー（head `e683fd4d`）から AI が起こした。受入基準と Notes の判断は Human の確認を経ていない。C-3 で確認する。

## Context / Why

PR #1639 は、導入前からあるファイルを `--uninstall` が削除する #1636 の欠陥を直す。敵対レビューは「ユーザーファイルが削除される経路は見つからない」としたうえで、次の理由で NOT_OK とした。

- **major-1**: target の祖先に symlink があると導入できない。macOS の `/tmp`・`/var` 配下と、symlink の `~/.claude` が該当する。
- **major-2**: v1 manifest だけがある環境で `sh install.sh --force` が rc=0 のまま何も更新しない。

どちらも修正の安全性ではなく、利用者が導入・更新できるかの問題である。ただし major-1 は安全側に置いた制限を緩めるので、緩めて開く穴を同時に塞ぐ必要がある。

### Bounded Discovery

- Discovery depth: expanded
- PBI author: ai
- Application timing: replan_current
- Target layer: delivery
- Source run / failure refs: PR #1639 コメント「敵対レビュー（head `e683fd4d`）: NOT_OK」

#### Source / Feedback Provenance

| Claim ID | Claim | Source Ref | Source Kind | Claim Class | Supports |
| --- | --- | --- | --- | --- | --- |
| CLM-001 | symlink の祖先を持つ target はすべて `ERROR: symlink in target path` rc=1 | `plan.md` P-01〜P-03 | measurement | observed | AC-01 |
| CLM-002 | v1 のみで `--force` は rc=0、内容は不変、v2 も作られない | `plan.md` P-05 | measurement | observed | AC-05 |
| CLM-003 | v1 のみで新規配布ファイルがあると v2 が生まれ、以後「v2 なし」では検出できない | `plan.md` P-06 | measurement | observed | AC-05 |
| CLM-004 | `_print_caveats` に呼び出し元がない | `install.sh:293`（定義のみ） | measurement | observed | AC-07 |
| CLM-005 | v1 manifest は導入前のファイルも記録しうる | issue #1636 Root cause / `origin/main:install.sh` `_write_manifest` | existing_behavior | observed | AC-06 |

#### Existing Work Check

- Checked refs: PR #1639 / issue #1636 / `docs/working/TASK-1636/`
- Materialization decision: update_existing（同じ PR・同じ TASK で是正する）

## What（Scope）

### In scope

- major-1、major-2、レビューの minor 5 件の是正
- 導入先の symlink に関する残存脅威と、v1 からの移行手順の文書化

### Out of scope

- Codex 直接展開の撤去（#1636 の範囲外）
- v1 manifest の自動所有化、および所有化のための新しいオプション
- 悪意ある並行プロセスへの TOCTOU 防御
- auto モードの終了コード（`plan.md` の Out of Scope 参照）

## 受入基準

- [ ] AC-01: 既存ディレクトリへの symlink を祖先または target 自身に持つ target に導入でき、撤去できる。macOS と Linux の両方で fixture が明示的に symlink を作って確認する。
- [ ] AC-02: root より下の symlink（親ディレクトリ、配布ファイル位置、manifest）を経由する書き込みと削除が起きない。symlink の target 経由でも同じ。
- [ ] AC-03: root の表記（symlink 経由、実パス、相対、`..`、末尾スラッシュ）が違っても同じ所有記録を使う。root の symlink を別ディレクトリのコピーへ向け替えても削除しない。
- [ ] AC-04: 解決できない symlink（dangling、循環）を含む target は rc≠0 で止まり、リンク先にも何も作らない。
- [ ] AC-05: v1 manifest があり v2 manifest がない状態の導入は、`--force` の有無と `--dry-run` の有無によらず rc≠0 で止まり、1 ファイルも書かない。エラー文に移行手順の参照先を含む。
- [ ] AC-06: v1 manifest を所有の根拠にしない方針を保つ。撤去は v1 のみの状態で rc=0 のまま全ファイルを保持し、移行手順を案内する。文書の移行手順を fixture でたどると v2 管理へ移れ、残したファイルは撤去されない。
- [ ] AC-07: 導入成功後の案内が実行時に表示され、更新コマンドは導入先プロジェクトで実行して効果がある形になっている。
- [ ] AC-08: テストの弱さを解消する。rc≠0 を許す呼び出しは終了コードと理由を検証し、legacy テストは両分岐 PASS をやめ、ctime のみの変化を固定し、docstring の参照を実在のものにする。既存 17 件の意図は維持する。
- [ ] AC-09: TOCTOU と symlink 追従の残存脅威を `install.sh` と `installer-ownership-review.md` の両方に書く。「祖先の symlink を拒否する」旧記述を残さない。
- [ ] AC-10: 新テストの検出力を示す。`e683fd4d` の installer で対象テストが想定の理由で FAIL し、`plan.md` の変異すべてで少なくとも 1 件 FAIL する。

## Notes from Refinement

- 比較と棄却の要約は `plan.md` の Approach Comparison にある。exec の最初に `decision-log.jsonl` へ `alternatives_rejected` として記録する。
- レビューの改善案「v1 があって v2 が無い場合」だけで `--force` を止めると、`--force` なしの導入が v2 を作って素通りになる（CLM-003）。そのため `--force` に限定しない。

## Estimation Evidence

### Risks

- symlink 追従の解禁は意図した利用者以外の経路も広げる。`plan.md` の穴リストとテストで固定する。
- v1 のみの環境で、これまで rc=0 だった `sh install.sh` が rc≠0 になる。

### Unknowns

`plan.md` の Questions / Unknowns を参照。

### Assumptions

- PR #1639 は未 merge の Draft で、v2 と v1 が共存する環境は配布されていない（`gh pr view 1639` で isDraft=true）。
