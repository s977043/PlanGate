---
task_id: TASK-1636
artifact_type: review-external
schema_version: 1
status: draft
verdict: WARN
reviewer_tool: river-review
created_by: orchestrator
---

# TASK-1636 外部AIレビュー結果（C-2）

> レビュー対象: 計画一式（head `ee90bc5c`）と repo 外の `plan.md` 下書き
> 判定: **WARN**（RiverReview の判定は CONDITIONAL） — critical=0, major=3, minor=4
> 指摘の出典: PR #1639 のコメント「TASK-1636 計画レビュー（RiverReview `review-plan`、head `ee90bc5c`）」

## 外部レビュー実行可否（必須）

| 項目 | 内容 |
|------|------|
| **実行状態** | river-review エージェントは `unavailable`。独立の汎用エージェントが River Review の Skill を読んで代替実施した |
| **実行不可の理由** | Skill Registry が未解決。`flows/entry-map.json` も 1.139.0 に存在せず、SKILL.md の Flow 表と Routing で代替した |
| **代替レビュー観点** | 独立の汎用エージェントによる `review-plan` と、使い捨てプローブでの実測 |
| **未充足リスク** | minor 相当: 正規のルーティングと Skill Registry の観点が適用されていない可能性。major 相当: 実装前の計画レビューなので、実コードでの穴は V-3 まで確認されない |

代替実施のレビューは計画の下書きを対象とし、設計妥当性とコードベース整合のレーンを分けていない。C-2 として十分かは Human の判断である（`plan.md` Q-3）。

## 指摘

| ID | Severity | 指摘 | 裏取り |
|---|---|---|---|
| R-001 | major | 印字する更新コマンドに `--target` がなく auto モードで動く。`.claude` のみの cwd で成功でも rc=1、`.claude` のない cwd で失敗、`--target` の導入先を更新しない | 修正案を試作で実行し確認 |
| R-002 | major | 全件保護（rc=0、更新 0 件）でも「インストール完了」を出す見込み | レビュー側はコードからの推定。修正案で案内が出ないことを試作で確認。旧案の実機再現はしていない |
| R-003 | major | 移行手順を文書どおりに実行できない（`--target` なし、比較方法が未定義、残したファイルが更新されない） | 修正した手順を tag 付き git repo の試作でたどった |
| R-004 | minor | MU-4 は TC-04 の形では生存する | 試作で再現。rename して symlink にする形で検出できる |
| R-005 | minor | manifest なしの `--uninstall` は main で rc=1、本ブランチで rc=0 | ブランチは試作で rc=0 を確認。main はコードとレビュー側の実測による |
| R-006 | minor | `_print_caveats` 復旧の確認が C-3 の問いにない | `plan.md` で確認 |
| R-007 | minor | exec 前提の順序が plan と INDEX で異なる | `plan.md` と `INDEX.md` で確認 |

## 監査表

`status` は `reflected` が計画一式への反映済みを示す。`plan.md` は未配置なので、plan への反映は repo 外の下書きにある。

| R-NNN | status | reflected_in(commit) | notes |
|---|---|---|---|
| R-001 | reflected | `49a47842` | 下書き「導入結果の表示と案内」、TC-15。修正案が生む引用の穴は H-11 で塞ぐ |
| R-002 | reflected | `49a47842` | 下書き D-A、Task 4、TC-24。修正案が生む文字コードの穴は H-10、TC-23 で塞ぐ |
| R-003 | reflected | `49a47842` | 下書きの移行手順 Step 3、5、6、TC-14、TC-22 |
| R-004 | reflected | `49a47842` | TC-04(a)、MU-4 |
| R-005 | reflected | `49a47842` | 下書き Q-2。Human 判断は未確定 |
| R-006 | reflected | `49a47842` | 下書き Q-5。従来の Q-5（検証の限界）は問いではないので別記に移した。Human 判断は未確定 |
| R-007 | reflected | `49a47842` | 下書き「exec の前提」、`todo.md` の H-00、T-00、H-01、`INDEX.md` |

## 修正案の追加検証（R-002 / R-003）

`install.sh` のコピーに修正案を入れた使い捨て環境で確認した（scratchpad `rr1636/verify.py`、全件 PASS、exit 0）。

- **見つかった穴（H-10）**: 案内を非 ASCII で出すと、ASCII の stdout では書き込みの**後に** rc=1 になる。`reconfigure(errors='backslashreplace')` で解消した。
- **見つかった穴（H-11）**: 空白や `'` を含むパスで印字コマンドが壊れる。`shlex.quote` を使う案で、別の cwd から実行できた。
- 再導入、全件編集済みの `--force`、dry-run、途中失敗で案内が出ないことを確認した。
- 全件保持の移行は `copied=0` で v2 を作らず rc=0。撤去でも全件残る。
- 存在しない tag を「一致」と判定しない。

## 未検証

- Linux 実機。macOS の CI はない。
- MU-1〜3、MU-5〜16 の変異（exec の T-13 で実行）。
- 計画の P-08、P-11〜P-15 について、レビュー側の再実行はない（試作の実測は AI 自身によるもので、独立していない）。
- 上記の試作は計画の案の確認であり、実装のテストではない。

## Plan Alignment / Evidence Alignment / Production Readiness

- **Plan Alignment**: 反映は計画の中で完結し、新しい CLI オプションや依存は増えていない。
- **Evidence Alignment**: R-NNN と TC の対応は `test-cases.md` の Verification Trace にある。
- **Production Readiness**: v1 利用者の導入の rc が変わる点と撤去の rc は `plan.md` Q-1、Q-2 の Human 判断待ち。
