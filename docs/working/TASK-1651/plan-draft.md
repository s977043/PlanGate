# TASK-1651 Implementation Plan（下書き。TASK 文脈付きセッション（`PLANGATE_HOOK_TASK=TASK-1651`）で plan.md へ移す）

> EH-3 が TASK context なしの plan.md 書き込みを block したため、本文をこのファイルに置いている。
> plan.md へ移した後に本ファイルは削除する。c3.json の plan_hash は plan.md に対して発行すること。

## Goal

`tests/extras/ta-10-doctor-fix.sh` TC-7 の絶対パス漏れ検査を、OS に依存しない形（`os.path.isabs` による再帰検査）に直し、
契約上許可した 1 キー（トップレベルの `project_root`）以外の絶対パスを macOS / Linux の両方で検出できるようにする。
あわせて `scripts/doctor_check.py` の docstring と TC-7 の見出しコメントの契約を揃える。

## Context

pbi-input.md を参照。照合: origin/main `8a689907`。
`doctor_check.py` `main()` が全 scope の JSON に `project_root = str(REPO)` を足す（#1497）一方、TC-7 は JSON 全体に
`"/Users/"` が含まれれば FAIL とする。macOS では常に FAIL、Linux CI（`/home/runner/...`）では空振りしている。

## Scope

### In Scope

- `tests/extras/ta-10-doctor-fix.sh` の TC-7（検査ロジックと見出しコメント）と、検査器の検出力を示す合成入力の TC（TC-7b）
- `scripts/doctor_check.py` の module docstring の Privacy 文（文言のみ。挙動は変えない）

### Out of Scope / Non-goals

pbi-input.md「Out of scope」のとおり（`bin/plangate`、JSON 出力の変更 = 是正案 B / C、#921、`metrics-privacy.md`）。
TC-7 の既存 leak 文字列（`${CLAUDE_PROJECT_DIR}` / `scripts/hooks/check-plan-exists.sh` / `settings.example.json`）の検査は残す。

## Global Constraints

- HO 対象パスは編集しない。変更 2 ファイルはいずれも HO 12 カテゴリ（`mode-classification.md`）外
  （`scripts/hooks/` ではなく `scripts/` 直下、`tests/extras/` は対象外）
- `doctor_check.py` の実行時の挙動（JSON のキー・値・exit code）は変えない
- c3.json / approvals/ は作らない

## 決定事項

| ID | 決定 | 理由 |
|----|------|------|
| D-1 | 是正案 A を採る。`project_root` を契約として認め、`/Users/` 固定の文字列検査を `os.path.isabs` による再帰検査に置き換える | #1497 の downstream 診断を壊さずに、Linux でも検出力を戻せる。B は診断が見えなくなり、C は `bin/plangate`（HO）に波及しうる。D は Linux の空振りが残る |
| D-2 | 除外するのはトップレベルの `project_root` キーとの**完全一致だけ**。`project_root_source` やネストした同名キーは除外しない | 除外を広げると検査が弱まる（pbi-input Risks）。`project_root_source` の値は既定で `script-root` 等の識別子であり、絶対パスなら漏れとして検出すべき |
| D-3 | 加えて、`project_root` の値そのもの（`str(REPO)`）が他の文字列値に部分文字列として現れないことも検査する | `os.path.isabs` は値の先頭しか見ないため、`"missing: /Users/..."` のような埋め込みを取りこぼす。REPO 値との照合は OS 非依存 |
| D-4 | `doctor_check.py` の docstring（`__doc__` の "Privacy:" 文、origin/main で "no paths beyond what is already public"）と TC-7 見出し（「絶対パス値は JSON に含まれない」）を、「絶対パスはトップレベル `project_root`（診断対象の明示、#962/#1497）の 1 キーのみ」という同じ契約に書き換える | AC-3。現状は両者とも実装と矛盾している |

## 前提の実測検証

| 前提 | 実測（静的読解、origin/main `8a689907`） |
|------|------|
| `project_root` の追加箇所 | `scripts/doctor_check.py` `main()` の `result["project_root"] = str(REPO)` / `result["project_root_source"] = os.environ.get("PLANGATE_PROJECT_ROOT_SOURCE", "script-root")` |
| TC-7 の判定 | `tests/extras/ta-10-doctor-fix.sh` TC-7 の python 内 `for leak in (... "/Users/" ...)` |
| hooks scope の他キー | `run_hooks_checks()` の `check_hooks_wired()` の `detail` は相対パスの固定文言のみ（静的読解）。exec の最初に実出力で再確認する（U-1） |

## Questions / Unknowns

- U-1: hooks scope に `project_root` 以外の絶対パス値が実在するか → Task 1 で `sh bin/plangate doctor --json --scope hooks` の実出力を見て確定する。実在した場合は Stop（スコープ判断が要る）
- U-2: `PLANGATE_PROJECT_ROOT_SOURCE` に `bin/plangate` が絶対パスを入れる経路があるか → Task 1 で `grep -n PLANGATE_PROJECT_ROOT_SOURCE bin/plangate` を読む。ある場合、D-2 により TC-7 が FAIL するので Stop して Human 判断
- U-3: `metrics-privacy.md` §4 が CLI 出力全般に及ぶか → 本 PBI では扱わない（Out of scope）。handoff の既知課題に残す

## Approach Comparison

| 案 | 内容 | 採否 |
|----|------|------|
| A | `project_root` 完全一致のみ除外 + `os.path.isabs` 再帰 + REPO 値の部分一致検査 | **採用**（D-1〜D-3） |
| B | `doctor_check.py` から `project_root` を外す / 相対化 | 不採用（#1497 の診断が失われる） |
| C | `--json` の `project_root` を opt-in に | 不採用（CLI 変更、HO 波及の恐れ） |
| D | `/Users/` を `$HOME` に置換するだけ | 不採用（`project_root` で必ず落ちる / Linux の空振りが残る） |

## Change Type / Verification Strategy

test fix + doc。検査器の検出力は変異注入（陽性対照）と合成入力 TC で示す。変更前のコードで新 TC が macOS で FAIL→変更後 PASS、
変異注入で変更後 FAIL を確認する（期待出力が変更前でも満たされないことを差分で示す）。

## Files / Interfaces

| ファイル | 種別 | HO |
|---------|------|----|
| `tests/extras/ta-10-doctor-fix.sh` | 更新（TC-7 / TC-7b） | 非該当 |
| `scripts/doctor_check.py` | 更新（docstring のみ） | 非該当 |

検査器（TC-7 の python 部）の仕様:

1. JSON を再帰走査し、すべての文字列値について (key path, value) を得る
2. key path がちょうど `["project_root"]`（トップレベル）のものだけを除外する
3. 残りの値で `os.path.isabs(value)` が真なら FAIL
4. 残りの値に `d["project_root"]` の値が部分文字列として含まれれば FAIL（`project_root` が空/欠落なら FAIL）
5. 既存の leak 文字列 3 種の検査は維持（`"/Users/"` は削除）

TC-7b: 同じ検査器を合成 JSON（`/home/runner/...` と `/Users/...` を `project_root` 以外に入れたもの、および `project_root` のみ絶対パスのもの）に適用し、前者は検出・後者は通過することを OS に依存せず確認する。検査器はファイル内で 1 箇所に定義し TC-7 / TC-7b で共有する。

## Work Breakdown

### Task 1: 前提の実測（U-1 / U-2）

- Output: hooks / v8.6.0 / maintenance の `--json` 実出力に含まれる絶対パス値の一覧（evidence/test-runs/）
- Completion: `project_root` 以外に絶対パス値なし、`PLANGATE_PROJECT_ROOT_SOURCE` は識別子のみ。違えば Stop
- Rollback: 不要（読み取りのみ）

### Task 2: TC-7b を先に書く（RED）

- Output: `ta-10-doctor-fix.sh` の検査器関数 + TC-7b
- Completion: 旧検査（`"/Users/"` 固定）相当では `/home/runner/...` の合成入力を検出できないことを記録し、新検査器で TC-7b PASS
- Rollback: `git checkout -- tests/extras/ta-10-doctor-fix.sh`

### Task 3: TC-7 を新検査器に切り替える（GREEN）

- Output: TC-7 の python 部の置換と見出しコメント更新
- Completion: macOS で TC-7 PASS（変更前は FAIL）。test-cases.md の TC-01〜TC-03
- Rollback: `git checkout -- tests/extras/ta-10-doctor-fix.sh`

### Task 4: docstring 更新

- Output: `doctor_check.py` `__doc__` の Privacy 文
- Completion: TC-7 見出しと同じ契約文言（D-4）。`python3 -m py_compile scripts/doctor_check.py` 成功、`--json` 出力が変更前後でバイト一致
- Rollback: `git checkout -- scripts/doctor_check.py`

### Task 5: 変異注入（陽性対照）

- Output: test-cases.md M-1〜M-3 の結果記録（commit しない）。各変異の stderr を evidence/test-runs/mutation.txt に保存する（既存の `2>/dev/null` で assert メッセージが捨てられるため。R-004）
- Completion: M-1 / M-2 は TC-7、M-3 は TC-7b（TC-03）が FAIL。戻して PASS（R-002）
- Rollback: `git checkout -- scripts/doctor_check.py tests/extras/ta-10-doctor-fix.sh`

## Testing Strategy

- Unit: TC-7b（合成入力。OS 非依存の検出力）
- Integration: TC-7（実 `bin/plangate doctor --json`）、`sh tests/run-tests.sh` の harness 経由（`set -eu` source でハングしないこと）
- E2E: 該当なし
- Verification Automation: `sh tests/extras/ta-10-doctor-fix.sh` / `sh tests/run-tests.sh`、main で同テストを流して既存 FAIL の対照、変異注入 M-1〜M-3。検出ロジックは OS に依存しない（CI の checkout `/home/runner/...` も `isabs` と D-3 の双方で検出される）。Linux での実行は CI（ubuntu）に依存し、ローカル exec では TC-7b の `/home/runner/...` 合成入力で Linux 型の入力を確認する（R-003）

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| 除外が広すぎて検査が弱まる | D-2（トップレベル完全一致のみ）+ TC-03（ネスト同名キーは検出） |
| `isabs` が埋め込みパスを取りこぼす | D-3（REPO 値の部分一致検査） |
| 既存の正当な値に誤反応 | Task 1 で実出力を確認、Replan Trigger |
| python の例外が `2>/dev/null` で隠れ素通り | 検査器は assert 失敗・例外とも非 0 で終わり TC は FAIL 側に倒れる（既存構造を踏襲）。M-3 で確認 |

## 残存脅威（R-001）

- TC-7 が再帰検査するのは **hooks scope の JSON だけ**。v8.6.0 / maintenance 等の他 scope は対象外
- 例: v8.6.0 scope の例外文字列（`could not run collision check: {exc}`）には REPO 以外の絶対パス（REPO の値と一致しないため D-3 でも拾えない）が入りうるが、本検査では検出できない
- AC-1 の対象を hooks scope と明記するのは範囲の明確化であり、hooks scope に対する検査（`isabs` 再帰 + D-3）は弱めない。他 scope への拡張は handoff の V2 候補に残す

## Replan Triggers

- 変更ファイルが 2 件を超える
- HO 対象パス（`bin/plangate` 等）の変更が必要になる
- `project_root` 以外に絶対パスを出す既存キーが 1 件以上見つかる
- ta-10 の実行時間が変更前比 +10 秒を超える

## Stop Condition

- 上の Replan Trigger のいずれか
- EH-3 が `.md` 以外の書き込みを block した場合。exec は `PLANGATE_HOOK_TASK=TASK-1651` を付けた再起動の後に行う

## Human Approval Boundary

- plan.md への移動: TASK 文脈付きセッションで行う
- C-3: Human が `bin/plangate approve TASK-1651` で c3.json を発行する（AI は作らない）
- C-4 / merge: Human-owned

## Mode判定

**モード**: standard

- 変更ファイル数: 2 → light
- 受入基準数: 3 → standard
- 変更種別: テスト修正 + docstring（privacy 検査の契約変更を含む） → standard
- リスク: 中（privacy 検査の強度を変える） → standard
- HO 対象パス: なし（tests/extras と scripts 直下のみ） → 例外ルール非該当
- **最終判定**: standard。privacy 検査（セキュリティ境界寄り）の変更のため安全側で standard とし、V-3 は review-principles §7-quater に従い 2 ラウンドを下限とする
