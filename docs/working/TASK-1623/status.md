# TASK-1623 作業ステータス

- Issue: s977043/PlanGate#1623
- Mode: high-risk
- 現在フェーズ: exec
- スライス: 前半（#1623-a）のみ本計画の exec 対象。後半（#1623-b、I-11 / AC-2）は #1393 core と同時かその直後・別 C-3。#1623 は前半マージ後も Open

## フェーズ履歴

| 日時 | フェーズ | 内容 |
|---|---|---|
| 2026-11-26 17:10 | plan | pbi-input / plan / todo / test-cases 作成（基準 main `fd6b6843`、スライス A `6756a597`） |
| 2026-11-26 17:24 | C-1 | review-self.md: WARN（指摘は同ファイル） |
| 2026-11-26 17:24 | C-3 待ち | Q-1（H-10 と AC-2 の衝突）の Human 決定待ち。c3.json 未発行 |
| 2026-11-26 17:42 | plan | Human 決定 D-1（Q-1 = 案 B、前半/後半分割）を plan Rev 2 に反映。todo / test-cases 追従 |
| 2026-11-26 17:42 | C-1 | 簡易 C-1 再実行: WARN（review-self.md 追記分） |
| 2026-11-26 17:42 | C-2 | C-2（2 レーン・2 ラウンド）待ち。c3.json 未発行 |
| 2026-11-26 18:41 | C-2 | R1〜R6 完了（review-external.md）。新しい回避クラス R2:4, R3:3, R4:1, R5:1, R6:0 → 収束。R6 の R-033〜R-035 を plan Rev 8 に反映（`792972bd`） |
| 2026-11-26 18:41 | C-1 | 簡易 C-1（Rev 8）: WARN（FAIL 0、review-self.md 追記分） |
| 2026-11-26 18:41 | C-3 待ち | 前半のみの C-3 待ち。T-00（`evidence/mc2a-c3.txt`）・H-01e・Q-2 が未了。c3.json 未発行 |
| 2026-11-27 08:49 | C-3 待ち | MC-2a（C-3 時点）: AI が照合して提示、Human が一致を確認（2026-11-26 19:03 JST）。evidence/mc2a-c3.txt |
| 2026-11-27 18:50 | exec | C-3 APPROVED（前半のみ）。`approvals/c3.json` approved_at 2026-11-27T04:52:05Z、plan_hash は plan.md 実測と一致 |
| 2026-11-27 18:50 | exec | H-01e（R-032）充足: `origin/feat/1391-phase1b-exec`（`924e45c0`）の TASK-1391 todo.md:75（C-4 行）と status.md:99 が `c4-preconditions.md` を参照。exec-1391 worktree の tracked な未 commit 変更 0 件（オーガナイザー実測 2026-11-27） |
| 2026-11-27 18:50 | exec | Q-2 確定: Human がチャットで「この値で確定」と回答（2026-11-27）。値は「## Q-2 確定値」節 |

## C-3 Gate: APPROVED

- 対象: 前半（#1623-a）のみ
- `docs/working/TASK-1623/approvals/c3.json`: `c3_status` APPROVED、`approved_at` 2026-11-27T04:52:05Z
- `plan_hash`: `sha256:0ec670f7002502aed8e509464d748b588ff52b9748d8e2541ba2091b152b0ed0`
- `shasum -a 256 docs/working/TASK-1623/plan.md` の実測値と一致（2026-11-27 18:50）
- C-1 Rev 8 の WARN 4 件を Human が確認のうえ承認
- exec 開始条件 H-01e（R-032）は充足（フェーズ履歴参照）

## Q-2 確定値

Human がチャットで「この値で確定」と回答（2026-11-27）。T-01 は本節から転記する。

| 対象 | 上限 |
|---|---|
| `run_id` | ≤68 文字 |
| `event_seq` / `revision` / `input_last_event_seq` / `contract_bound_seq` | ≤2048 |
| `inputs` + `failure_fingerprints` 合計 | ≤256 |
| `verdicts` | ≤16 件・キー ASCII ≤71 |
| `stop_reasons` | ≤9 件（`ALLOWED_STOP_REASONS` 9 種、重複も件数に数える） |
| `artifact_ref` / `source_sha` | 既に確定済み |

## 全体構成（PR 一覧）

| ブランチ | 状態 |
|---|---|
| `docs/TASK-1623-plan` | [計画 PR #1668](https://github.com/s977043/PlanGate/pull/1668) main `2d5bd4fb` にマージ済み |
| `feat/1391-phase1b-exec` | [Draft #1667](https://github.com/s977043/PlanGate/pull/1667)。照合時のリモートは `924e45c0` |

## 残タスク

- [x] Human: Q-1 順序決定 → 案 B（2026-11-26、plan.md D-1）
- [x] Human / owner: Q-2 の上限確認（H-02、2026-11-27 確定。「## Q-2 確定値」）
- [x] C-2（R1〜R6、R6 で収束）
- [x] Human: C-3（前半のみ）→ APPROVED（2026-11-27）
- [x] Human: H-01e exec 開始条件（R-032）→ 充足（2026-11-27）
- [ ] 前半マージ条件 MC-1〜MC-3（plan.md）。MC-2 は #1391 PR の CI で確認

BLOCKED 相当:

| blocker | owner | unblock_condition |
|---|---|---|
| I-11 / `DecisionInputError` が main に無い | #1393 | #1393 core（または案 A の最小入口）が main に入る |
| `decision_made` 構造が main に無い | #1391 | #1391 PR のマージ（前半は固定 SHA の写像で先行） |

上表 1 行目は後半のみの blocker（前半は非依存）。

## 計画からの変更点

- 下書き（exec-1391 worktree の未コミット plan.md）の結論を採用しつつ、V-3（構造自体も main に無い）を追加した
- Rev 2: D-1 により exec 対象を前半に限定。I-11 接続（旧 T-06）を後半へ移し、前半マージ条件 MC-1〜MC-3・RT-6/RT-7・T-11 を追加

## 次の作業（Claude Code プロンプト）

`docs/working/TASK-1623/plan.md` Rev 2（前半スコープ）に対し C-2 を 2 レーン・2 ラウンドで実施し、review-external.md に R-NNN で集約する。c3.json は作らない。

## #1623-a 着手前照合（2026-11-27）

- T-00 / T-01: MC-2a の Human 確認と Q-2 確定値の転記を確認。C-3 の `plan_hash` と現行 plan の SHA-256 が一致。
- T-02: GitHub main は `f67c7956`。計画の基準 `fd6b6843` からは実行計画の文書変更のみ。#1391 のリモート先端は MC-2a 記録時の `924e45c0` と一致し、`6756a597..924e45c0` の `run_event.py` 差分は空。RT-2 非発火。
- 次工程は T-03 → T-04 → T-05b / T-07 → T-08 → T-09。前半 PR で T-11 の CI ログを採取し、fixture を確定したあと T-05c の Human 照合へ進む。実 validator の照合は #1391 後半、正式 I-11 は #1623-b。

## #1623-a ローカル実装と検証

- T-03 RED: 定数の追加前に、新 fixture テストが欠落した byte 定数の参照で FAIL。
- T-04: 算定は input 由来 26,259 + fixed 223 + event envelope 515 = 26,997 bytes。固定した契約内の区分最大を合計し、余裕分は加えていない。契約変更時は再計測する。
- T-05b / T-07: TA-118 standalone 7 テスト PASS、skip 0。reserve は契約 fixture。Model B の store は #1392 の受入で確認する。
- T-08 確認済みの mutation: 上限 −1、escape の過少計上、二重計上、skip、expected failure、0 件収集で FAIL。通常本文の同名表現では PASS。outcome 欠落の実行確認、レビュー、PR CI、C-4 時点照合は次工程。

### T-08 の完了と T-09 自己レビューでの是正

- Q-2 は停止理由の重複を 9 件の枠に数える。各理由を 1 回ずつ使った初版は、最長の理由を 9 回使う場合を過少算定していた。旧値 26,997 を新 fixture が拒否することを確認し、固定部分を 223 → 268 bytes、全体上限を **27,042 bytes** に是正した。入力由来 26,259 bytes と event envelope 515 bytes は同じ。
- 一時コピーで outcome 1 種欠落、理由の重複を数えない旧算定、上限 −1 の全件を検出。最終ローカル TA-118 は 7 件 PASS。T-09 の独立レビュー、実装 PR の CI、C-4 の Human 照合は未了。

### T-05d と追加の算定検証

- 投稿本文案を [evidence/mc4-draft.md](evidence/mc4-draft.md) に保存。正本 commit `3a7373f0` の C-4 前提 6 項目を抽出し、節の SHA-256 が承認済み plan の値と一致した。H-03c の Human 確認待ち。
- 各 outcome・artifact 有無の 7 組 × inputs と fingerprints の全配分 257 通り、計 1,799 event をローカルで測定。全件で区分合計と event サイズが一致し、固定部分と envelope は各定数以下。全体の最大は HUMAN_ESCALATED・artifact ありの 27,042 bytes。
- 実装 PR のレビュー順は T-09 → 実装 PR の CI で T-11 → T-05c。本分岐の計画 PR #1668 のチェックは実装 PR の証拠に流用しない。#1392 の terminal reserve は #1623-a を取り込んだ #1391 の C-4 の後に実装・検証する。

### T-09 独立レビュー R1

- PR #1669 の `c1dd5e81` を算定契約と検証経路の 2 観点で独立レビュー。I-10 の厳密不等式に合わせて fixture の `contract_bound_seq` を 2046 に修正し、4 桁と 27,042 bytes は維持。
- 任意 artifact の片側だけが欠落した場合も検出するため、期待値表と合法な 7 組を照合。TA-118 は要約を 1 回で判定し、違反検出コマンドのエラーを「違反なし」と扱う経路を解消。
- 是正後のローカル TA-118 は 7 件 PASS。T-09 R2 と修正 head の CI 証跡は確認待ち。

- T-09 R2（`f2d414a2`）: 算定レーンは新規回避クラス 0 件。検証レーンは正常要約と 0 件要約が混在した場合に TA-118 が通る新規クラス 1 件を検出。0 件要約を失敗扱いにし、通常ログ、本文中の類似文字列、0 件・正常の混在、単独 0 件、skip、expected failure を実際の awk 判定で確認。ローカル TA-118 も 7 件 PASS。R3 で修正を再確認する。

- T-09 R3（`996a965b`）: 新規回避クラス 0。実際の awk を 12 入力で検証し、正常出力を受理、0 件要約の単独・混在、skip、expected failure、重複・欠落要約を拒否。R2→R3 は 1→0 で収束。
- #1668 のマージ後に main `2d5bd4fb` を #1669 に取り込み、status / todo の add/add 競合を解消。計画本文と実装・fixture の内容を保持。T-11 は競合解消後の head の PR CI で確認する。
