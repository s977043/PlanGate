---
task_id: TASK-1197
artifact_type: plan
schema_version: 1
status: draft
mode: critical
related_issue: https://github.com/s977043/plangate/issues/1197
created_by: ai-draft-pending-human
---

# TASK-1197 Implementation Plan（C-3 CONDITIONAL / c3.json 未発行）

## Goal

no-task セッションで、未承認 TASK の plan.md を `Write` で初回作成できるようにする。既存 plan.md の改変と承認済み TASK への書き込みは block のまま維持する。

## 結論（先に読む）

- 案 B は実装可能だが、**Human 方針の 2 条件だけでは足りない**。「新規作成」は Edit/Write 入力だけでは判定できず、下表の 8 条件が必要になる。
- **TOCTOU と Bash 経路は塞げない**。トークンの存在検査は、Bash を使える主体には防御にならない（R-004）。hook は早期 block の 1 層であり、保証の主体は `bin/plangate exec` の plan_hash 拒否、C-3、C-4 である（R-007）。
- **hook は「一度も承認されていない」ことを証明しない**。守るのは実在するトークンと plan で、履歴検査は補助である。reflog 失効後、gc 後、履歴を消した状態からの再作成は通るが、承認の偽装にはならず exec に再承認が要る。
- **C-2 は未収束**。新クラスが 3 ラウンド連続で出たので、Human 裁定（2026-11-07）により案 B を上記の範囲へ縮小し、R4 は行わない。打ち切りの可否は C-3 で Human が判断する。残りは patch 実装後の変異注入と V-3 で検証する。
- **案 B 単独では issue の症状が半分残る**。作成後の C-1 修正や C-2 反映は既存 plan.md の改変なので block され、再起動が必要になる（Q-1）。

## Context

- 関連 Issue: #1197、#1104、#1277、#1101、#1234、#1089
- 関連: `docs/workflows/ai-loop/rollout-policy.md`、`docs/ai/hook-enforcement.md`
- 同一 issue の open PR: 0 件（`gh pr list --search "1197 in:title,body"`）。タイトル検索でも EH-3 / plan.md / no-task の重複なし。

### 自己言及

本 TASK の plan.md 自身が、是正対象の block に当たる。`PLANGATE_HOOK_TASK` 未設定のセッションで `docs/working/TASK-1197/plan.md` へ Write すると rc=2 になる。本下書きが書けたのは scratchpad（repo 外 = `OUTSIDE_REPO_SKIP`）だからである。**repo への配置は Human が `PLANGATE_HOOK_TASK=TASK-1197` でセッションを起動して行う**（env は起動時固定。実行中の export は hook に届かない）。

## 前提の実測検証

| 前提 | 検証コマンド | 実測結果 | 判定 |
|---|---|---|---|
| no-task の plan.md 判定は末尾パス一致 | `git show origin/main:scripts/hooks/check-plan-hash.sh` の `*/plan.md\|plan.md` | TASK に束縛されない。`docs/plan.md` も block | ✅ |
| 新規 / 既存 / 非 TASK は現状すべて block | 自作 sandbox probe（下記注記） | 3 ケースとも rc=2 | ✅ |
| Claude 配線は stdin 経由で tool_name を読める | `.claude/settings.example.json` L43 | 引数は env 未設定なら空で、stdin を読む | ✅（実 Claude payload は未測定） |
| Edit/Write 入力に既存有無の情報はない | 同 hook の抽出処理 | `file_path` のみ使用 | ✅ |
| EH-13 の Bash 判定 | sandbox probe（hook に渡すのみで未実行） | c3.json の `mv` / `cp` / `ln` は rc=2。`rm`、`mv .../approvals`（dir）、`mv docs/working/TASK-1`、`cp -r`、`tar`、`rsync -a`、`git stash push -u`、`git mv`、`git restore` は rc=0 | ✅（R-004 で是正） |
| トークンは worktree ごとに置かれる | `git worktree list --porcelain`、TASK-1393 INDEX | 多数の linked worktree が存在し、prunable も混在 | ✅ |
| トークンは常に untracked ではない | `git ls-tree -r origin/main docs/working` | `docs/working/TASK-*/approvals/` の tracked ファイルが origin/main に多数ある（実測 91。測定値）。`.gitignore` に approvals の除外なし。untracked と tracked の両方を扱う必要がある | ✅（依頼の前提より広い） |
| linked worktree は `_phys_target` に worktree 相対で載る（#1277） | hook の python block | `WORKTREE\|<相対>`。ただし worktree root は出力されない | ✅ |
| history 走査は実用時間 | `/usr/bin/time -p git rev-list -1 --all -- <不在パス>` | real 1.37s と 2.80s（実 repo、計測者別に各 1 回） | ✅（負荷時は未測定） |
| Codex / Cursor では本分岐に到達しない | `eh-bridge.sh`、`cursor-adapter.sh` の TASK 自動導出 | TASK パスでは `PLANGATE_HOOK_TASK` を注入するため no-task 分岐へ入らない | ✅（コード読解。橋渡しの実走は未実施） |

> sandbox probe は origin/main の hook を scratchpad の `git init` 環境へ複製して実行した。自作隔離環境であり実環境の再現ではない。差分は `.claude/worktrees`・settings 配線・実 payload が無いこと。実 repo では監査ログへ書くため実行していない。

## 攻撃経路の評価（依頼の論点）

| 経路 | 閉じる手段 | 判定 |
|---|---|---|
| Write で既存を上書き | `lexists(target)` なら block | 閉じる |
| Edit で作成 | `tool_name == Write` のみ許可。不明・Edit・MultiEdit は block | 閉じる |
| dangling symlink の plan.md | `lexists` は true、許可しない | 閉じる |
| 親ディレクトリ symlink で別 TASK へ | 解決前の要求パスのうち worktree root より下の各要素を `lstat` で検査し、symlink を拒否（条件 3） | 閉じる（linked worktree を含め TC-13 で実測するまで未検証） |
| 別 TASK ディレクトリ | 判定する TASK は対象パスから導出し、そのトークンを見る | 閉じる |
| TASK 名詐称（`task-1`, 全角, `TASK-1/x/plan.md`, `PLAN.md`） | 物理相対パスの厳密一致。ASCII・大文字固定。`TASK-[A-Za-z0-9][A-Za-z0-9-]*` は `bin/plangate` の検証と同型 | 閉じる。大文字小文字の別名は条件 7 の `:(icase)` で閉じる（TC-17） |
| 非 TASK パス | 同上で許可しない | 閉じる |
| 実在しない TASK の新設 | **許可される**。未承認の plan を作るだけで exec には C-3 が要る | 残す（無害と判断） |
| 他 worktree に承認があり、ここには無い | 全 worktree の `approvals/` を走査 | 閉じる（下記例外） |
| 削除または移動した worktree にしかトークンが無い | 移動先は検知不能（`prunable` として skip される）。元のパスの承認は参照できず、exec には再承認が要る | 残存 |
| tracked plan を消して再作成 | `rev-list --all --reflog --full-history` に当該パスの履歴があれば block | 閉じる（未 fetch の remote、reflog 失効後を除く） |
| stash@{1} や削除した未 merge 枝へ退避 | `--reflog` で検出（TC-08d、TC-08e） | reflog が残る間だけ閉じる。`git reflog expire` や gc の後は残存 |
| サブディレクトリから起動 | `cwd=<worktree root>` と `:(top,icase)` で固定（TC-08f） | 閉じる |
| untracked の plan と c3 を両方消して再作成 | **防げない**。ただしトークンも失うので承認済み扱いにならない | 残存（承認の偽装にはならない） |
| c3 を退避し、書いて、戻す | **防げない**。ディレクトリの `mv`、`cp -r`、`tar`、`rsync` は EH-13 を通る。`git stash -u` の退避は reflog が残る間だけ条件 7 で検出し、repo 外への退避は検出不能。戻した時点の不一致は `bin/plangate exec` が拒否 | **残存**。検知は hash 照合に依存 |
| TOCTOU（hook 後 Write 前に別プロセスが作成） | 排他不能。PreToolUse に原子性はない | **残存**。同一 TASK の並走を前提外とする |
| Bash で直接書く / 消す | #1104 open。本 PBI では閉じない | **残存**（AC-4 で明文化） |

**許可条件（すべて満たすときのみ rc=0。判定不能は block）**:

共通規則: hook は `set -eu` で、想定外エラーは rc=1 となり block にならない。許可ブロック内のエラーと監査記録の失敗は明示的に捕捉して rc=2 に統一する。例外は条件 6 の prunable だけとする。


1. `STRICT != 1`、かつ maintenance.json が無い（doc-light と同じ優先順）
2. `tool_name == Write`（stdin payload のみ。jq 必須。env / 引数で対象を渡された場合は許可しない）
3. `_phys_target` の相対パス（小文字化前）が `docs/working/TASK-<id>/plan.md` に厳密一致し、かつ解決前の要求パスを root の祖先と root より下に分け、root より下の各要素を `lstat` で検査して symlink が無い。`_phys_target` は realpath 後の値なので、この検査の入力に使わない。分割できなければ block。root より上の symlink（`/tmp` や mktemp の祖先）は許容する。全パスの字句比較はしない。`_ho_key` と `_phys_key` は linked worktree で一致せず小文字化済みなので、直接比較しない
4. 対象 worktree が REPO_ROOT と同じ common dir に属する
5. 対象が `lexists` で不在
6. 対象 worktree および `git worktree list` の全 worktree に `docs/working/TASK-<id>/approvals/` の実体が無い（中身不問。壊れた JSON も発行済み扱い）。`git worktree list --porcelain -z` で解析し、`prunable` 注記がある worktree だけを走査不能として skip し、監査ログに件数を残す（INV-02 の唯一の例外）。注記のないパス不達と、locked でパスが読めない worktree は block
7. `git rev-parse --is-shallow-repository` が `false`（true や失敗は block）。かつ補助の検査として、対象 worktree root を cwd として `git rev-list -1 --all --reflog --full-history -- ':(top,icase)<plan.md>' ':(top,icase)<approvals/>'` が空（timeout 超過・git 失敗は block。`GIT_*` env は除去）。timeout は git 呼び出しごとに 10 秒（実 repo の実測最大 2.80s の約 3.5 倍。`--reflog` の実 repo 値は T-01 で再測定）
8. 許可時は allow 専用 writer で `PLAN_CREATE_ALLOW` を監査ログと skip-decision-log の両方に書き、どちらかの書き込みが失敗したら rc=2。既存の `log_event` は read-only でも 0 を返すので使わない（`check-skip-acknowledged.sh` が FAIL 扱いするのは `EH-3_SKIP` のみなので新 event は CI を落とさない）

## Questions / Unknowns

| ID | 問い | 推奨 | 判断者 |
|---|---|---|---|
| **Q-1** | 作成後の修正（C-1 自動修正・C-2 反映）は Human 方針では block のまま。no-task では再起動が要る。これを許容するか | **案 B の条件を維持し、修正が要る時点で再起動を案内して escalate**。緩めると「未承認なら上書き可」となり方針の変更になる | Human |
| Q-2 | 案 B を維持し、Human 方針の「新規作成 + トークン未発行」に条件 3〜7 を足す判断でよいか。退避は防げず、判定も複雑になる | 足して案 B を維持する。足さないと上表の経路が開く。複雑さを避けるなら案 A に戻す | Human（C-3） |
| Q-3 | 実測した既存の穴（`HOOK_TASK=TASK-2` で TASK-1 の承認済み plan を編集すると rc=0 / 非 STRICT の hash 不一致が rc=0 で WARNING のみ / STRICT の不一致が rc=1 で tool を止めない可能性）を別 issue にするか | 別 issue。no-task block より強い迂回で、案 B の残存脅威にも影響する。STRICT の実挙動は実 Claude で未検証 | Human |
| Q-4 | Codex / Cursor の TASK 自動導出により、それらの経路は元から no-task block が効かない非対称を別 issue にするか | 別 issue。なお `docs/ai/hook-enforcement.md` は Codex hook を「登録 0 件・未発火（#1078）」と記載しており、現在の発火状況は未検証 | Human |
| Q-5 | SKILL.md の更新範囲。plugin 派生同期と version bump を本 PBI に含めるか | `.claude` と `.agents` の前提節に 1 行追記し、`.codex` / plugin は生成で追従。差分が想定を超えたら replan | Human |

**Human 裁定（2026-11-06、2026-11-07）**: Q-1〜Q-5 は推奨どおり。Replan Trigger（新クラスの連続）は案 B 縮小で確定した。Q-3 は #1641、Q-4 は #1642 として起票した（2026-11-07、Human 名指し承認）。C-3 は CONDITIONAL で、未収束のまま計画レビューを打ち切ること、timeout（git 呼び出しごと 10 秒、許可経路合計 15 秒）を承認した。

## Approach Comparison

| 案 | Evidence | Complexity Cost | New Abstractions | Current-Need Trace | Verification | Trade-offs | 判定 |
|---|---|---|---|---|---|---|---|
| A: 起動導線の明記のみ | hook 無変更で全攻撃経路が閉じたまま | 低 | なし | AC-1,2,4 | doc のみ | 安全だが TASK ごとの再起動が残る（Human が不採用とした理由） | Human 方針で不採用。ただし修正時の案内として併用 |
| B: 条件付き初回作成許可 | 上表 | 高。hook に python 判定と git 呼び出しを追加 | 判定ブロック 1 個、監査 event 1 個 | Human 方針、AC-3 | 実 hook TC + 変異注入 | 初回作成は無再起動。修正は再起動、TOCTOU 残存 | **採用候補** |
| B': B + 未承認中の上書きも許可 | 未承認 plan は hash 保護対象がない | 中 | B と同じ | ai-loop の C-1 修正 | 同左 | 再起動をほぼ解消するが、Human 方針「既存改変は block」に反する | 方針変更が要るので Q-1 で提示のみ |
| C: Bash 経路へ配線（#1104） | Bash コマンド解析は未実装 | 高 | 解析器 | なし（Out of scope） | — | 穴は塞がるが症状は悪化 | 不採用 |
| D: draft 名で書き、Human が昇格 | 非 plan.md は通る | 中 | 新 artifact | なし | — | 再起動不要だが成果物規約が変わり Human 作業が増える | 不採用 |

### Recommended Approach

案 B を上記 8 条件で実装する。案 A の案内を「修正が必要な場合」に併用する。

#### Why this is the minimum sufficient design

- Required: Human 方針、AC-1〜4
- New abstractions: no-task の plan.md 分岐内の判定 1 ブロック、新 event 1 個のみ。新規 hook・CLI・設定は作らない
- Simpler alternative considered: `[ ! -e plan ] && [ ! -e c3.json ]` のみ。symlink、別 worktree、削除再作成で破れるので不採用
- Observable behavior: 許可時 rc=0 + `PLAN_CREATE_ALLOW`。それ以外は従来メッセージで rc=2
- Conditional guidance fired: Security、Failure（fail-closed）、Performance（EH-3 に timeout がなくハングは block にならない。#1101）
- Deferred: #1104、Q-3、Q-4

## Change Type / Verification Strategy

- Change type: mixed（behavior change + docs）
- Pre-change evidence: TC-02〜 の許可ケースが現行 hook で rc=2 であること
- Post-change evidence: patched 複製と適用後の実 hook で同じ TC が期待どおり
- 適用前は `tests/fixtures/` の pending flag で gap を明示する（ta-79 / ta-65 と同型）

## Files / Interfaces

| ファイル | 操作 | 目的 | 責務 |
|---|---|---|---|
| `scripts/hooks/check-plan-hash.sh` | modify（**HO: Human 適用**） | no-task plan.md 分岐に許可判定 | Human |
| `docs/working/_reports/1197-eh3-plan-create-patch.md` | create | `PG-PATCH-BEGIN/END` つき patch 文書 | AI |
| `scripts/apply-eh3-plan-create-1197.sh` | create | `ho-apply-script` の型の適用スクリプト（commit / push しない） | AI 作成 / Human 実行 |
| `tests/extras/ta-NN-eh3-plan-create.sh` | create | 実 hook + patched 複製 + 変異。番号は exec 時に再測定（現行最大は ta-118） | AI |
| `tests/fixtures/eh3-plan-create-pending-1197.flag` | create | 未適用の明示 opt-in。Human 適用時に削除 | AI / Human |
| `tests/extras/ta-79-eh3-bash-lane.sh` | 変更しない見込み | fixture は `git init` しないので TC-P06 / TC-R06 は block のままと読める（未実走）。patched 複製で FAIL が出た場合だけ対照を変更する | AI |
| `docs/workflows/ai-loop/rollout-policy.md` | modify | 起動条件・no-task 挙動・迂回禁止 | AI（carve-out なので Human C-3 経路） |
| `.claude/skills/ai-loop-cycle/SKILL.md`、`.agents/skills/ai-loop-cycle/SKILL.md` | modify | 前提節に 1 行（Q-5） | AI |
| `.codex/skills/ai-loop-cycle/SKILL.md`、`plugin/plangate/skills/ai-loop-cycle/SKILL.md` | 生成 | 同期スクリプトの出力のみ | AI |
| `docs/ai/hook-enforcement.md` | modify | EH-3 節に許可経路と残存脅威 | AI |

影響確認のみ（変更しない見込み）: ta-39 TC-04（env 指定なら tool_name が無く block 維持。exec で実測）、ta-65、ta-80（fixture に plan あり。M5 が hook のコメント文字列と `PLANGATE_HOOK_STRICT` 行に依存するので、両アンカーの順序を保つ）、ta-12、ta-15、ta-26 TC-39、ta-61、ta-77、ta-84。plugin に hook 本体は配布されない。

## AC 対応表

| AC | 実現 | Task | TC |
|---|---|---|---|
| AC-1 | rollout-policy に起動条件を明記 | Task 4 | TC-D01 |
| AC-2 | no-task 挙動を定義: plan 不在または C-1 未完なら escalate し、plan 作成の入口を案内する（ai-loop-cycle は C-1 PASS と C-2 完了が前提）。plan が実在し前提を満たすなら続行。修正が要れば再起動を案内して escalate。arbiter に虚偽 `gates.c1` を渡さない | Task 4 | TC-D02 |
| AC-3 | トークン存在下の block + 変異注入 | Task 2, 3 | TC-05〜07, TC-M01 |
| AC-4 | **許可条件の明示 + 禁止の明文化**。CLI、Bash、`PLANGATE_BYPASS_HOOK`、消して再作成を「決定に従うため」に使わない。#1104 は open のままで、ガード配線は行わないと明記 | Task 4 | TC-D03 |

## Work Breakdown

### Task 1: 回帰テストの RED と fixture

**Purpose**: 許可・block の全ケースを実 hook 形式で固定する。
**Change Type**: new behavior。`git init` + linked worktree の sandbox を mktemp に作る。実 repo に書かない。
**Files**: `tests/extras/ta-NN-eh3-plan-create.sh`、pending flag。
**Completion**: 未 patch の hook で許可ケースが rc=2 と観測される。
**Rollback**: `git revert`（新規ファイルのみ）。

### Task 2: patch 文書

**Purpose**: 8 条件の判定を unified diff にする。
**Files**: `docs/working/_reports/1197-eh3-plan-create-patch.md`。
**制約**: 許可判定は lexical の `*/plan.md` ブロックの block 文より前に置き、`_phys_key` 側の union block は変更しない。python 呼び出しはこの分岐内だけで走らせ、他経路の fork を増やさない。git 呼び出しは python の `subprocess.run(timeout=...)` で行い、`timeout` コマンドに依存しない。ta-80 M5 の 2 アンカーの順序を変えない。条件 4 は条件 3 の後で到達可能かを実測し、到達不能なら削除する。
**Completion**: 複製に適用して Task 1 の TC が GREEN、`git apply -v` に offset なし。
**Rollback**: patch 文書の revert。

### Task 3: 適用スクリプトと変異注入

**Purpose**: `.claude/skills/ho-apply-script/SKILL.md` の型で Human へ渡す。
**Files**: `scripts/apply-eh3-plan-create-1197.sh`、ta-NN。
**手順**: `apply` / 再実行 / `--verify` / `--rollback` を持ち、feature ブランチ + origin/main 分岐を必須にする。dirty ガードは対象を除外、抽出は awk、fwd / rev を確認、`$var` は `${var}`、`grep -F --`。`--verify` は marker でなく述語（ta-NN と ta-79、ta-80、ta-65、ta-39 に FAIL なし、実 repo の HO が rc=2）を測り、die 時に再現用 1 行を出す。hook 挙動の検証は実 repo 前提。
**AI の実行範囲**: `PLANGATE_APPLY_REPO` で**複製に対してのみ** 4 モードを実走する。実 repo では実行しない。
**Completion**: 複製で 4 モード成功、`--rollback` 後に対象差分 0 行、Checklist 全項目確認。全変異を検出。
**Rollback**: スクリプトの revert。

### Task 4: docs

**Purpose**: AC-1, 2, 4 の明文化。
**Files**: rollout-policy.md、SKILL.md、hook-enforcement.md、生成物。
**Completion**: TC-D01〜03 PASS、同期 drift なし。
**Rollback**: `git revert`。

### Task 5: Human 適用

**Owner**: Human。feature ブランチで適用スクリプトを実行し、pending flag を削除して commit する。AI は手順の提示のみ行う。
**Rollback**: `--rollback` または `git revert`。

## Verification Plan

| 種別 | コマンド | 期待結果 | Evidence |
|---|---|---|---|
| 新規 | `sh tests/extras/ta-NN-eh3-plan-create.sh` | FAIL なし | `evidence/test-runs/` |
| 回帰 | `sh tests/run-tests.sh`（CI 経路） | FAIL なし | 同上 |
| 適用 | `--verify`（複製 / Human 実 repo） | ABORT なし | `evidence/verification/` |
| 非機能 | no-task 許可経路の実行時間、非 plan 経路の fork 増加なし | 実測を記録。閾値は test に固定しない | 同上 |

### レビューレーン計画

`review-principles.md` §7-quater により **2 ラウンド以上**。件数でなく新しい回避クラスの有無で収束判定し、回避クラス台帳を残す。

| 成果物 | レーン | unavailable 時 |
|---|---|---|
| plan | 設計妥当性（I1）/ コードベース整合（I1）/ 敵対（I2 Codex） | §10 に記録し別 role で代替 |
| patch | R1 敵対 / R2 是正そのものを疑う | 同上 |

## Plan Review Readiness

- Success Criteria: AC-1〜4、Done は Human 適用 + C-4 まで
- Review Criteria: fail-closed、条件の全変異検出、既存 block の不変
- Required Context: 上記 Files、§7-quater、`ho-apply-script`
- Non-goals: #1104、Q-3、Q-4
- Change-prohibited: `.claude/settings*.json`、`bin/plangate`、schemas、workflows、`scripts/check-approval-token-write.sh`
- Forbidden new dependencies: なし（jq / python3 / git は既存依存）

## Replan Triggers

- H-02 後の実 Write 1 回で `PLAN_CREATE_ALLOW` が記録されない（実 payload に `tool_name` が無い場合を含む）
- 許可経路の所要時間が合計 15 秒（案。C-3 で確定）を超える、または実 repo の `rev-list --reflog` が 7 秒を超える、またはハングする
- 変異のうち 1 つでも未検出
- 既存 TC の変更が必要になる（ta-79 の 2 件を含む）
- 同期生成の差分が ai-loop-cycle の SKILL.md 以外に及ぶ
- 実装後の review で、実在するトークンや plan を破る新クラスが出る（判定モデル自体を見直す）。履歴検査だけの穴は残存脅威へ追記する

## Stop Condition

- Q-1、Q-2 が未回答のまま exec が必要になった
- HO パスの直接編集が必要になった
- `PLANGATE_BYPASS_HOOK` や Bash 経由の plan 作成が必要になった

## Human Approval Boundary

- HO の適用（`check-plan-hash.sh`）、C-3、C-4、merge、`c3.json` の発行、settings 変更は Human のみ

## 残存脅威モデル（完全性を主張しない）

守るもの: 承認トークンが存在する TASK、履歴のある plan.md、既存 plan.md への Edit/Write。

守らないもの: Bash 経路（#1104）、TOCTOU、削除または移動した worktree のみのトークン、未 fetch の remote 履歴、reflog 失効後や gc 後の履歴、トークンを repo 外へ退避して戻す行為、トークンと plan を両方消す行為（承認の偽装にはならず、exec に再承認が要る）、Codex / Cursor 経路、実在しない TASK の新設。

保証の主体: `bin/plangate exec` の plan_hash 拒否、C-3、C-4 Human レビュー。hook の hash 照合は非 STRICT で WARNING のみである。本検査は多層防御の 1 層である。実 Claude payload と実環境 1 周は exec で測るまで未検証。T-02 が測るのは実環境の正常系 1 回で、実環境の block とエラー処理は未検証として C-4 に提示する。C-2 は未収束で、計画段階のレビューは静的照合と部品の実測にとどまる。

## Mode判定

**モード**: critical

**判定根拠**:
- 変更ファイル数: 10 前後 → high-risk
- 受入基準数: 4 → standard
- 変更種別: 承認境界の **緩和**（hard block に例外を追加） → critical
- リスク: 判定漏れは承認済み plan の改変につながりうる → 極高
- 例外ルール: 承認境界周辺は最低 high。HO 接触で `lite_eligible=false`、同期 C-3 固定、autonomous APPROVE 不可
- 影響範囲: 全 no-task セッションの plan.md 書き込み
- **最終判定**: critical。issue Notes も「案 B なら critical」と想定。量的には high-risk だが、緩和方向かつ不確実なら上げる安全側規則に従う
