# TASK-1391 作業ステータス

> 最終更新: 2026-11-26 07:40
> 現在フェーズ: exec
> モード: high-risk（plan.md「Mode判定」）
> 発行時点 SHA (issued_at_commit): 該当なし（完了資産ではない。照合基準は `origin/main` `742f63f6`）

> 現在フェーズの値域は `INDEX.md` と共通（正本: `.claude/rules/working-context.md`）。
> TASK-1391 には `INDEX.md` / `current-state.md` / `approvals/` が無い（2026-10-23 時点）。

## フェーズ履歴

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ |
|------------------------|---------|------------|
| 2026-09-24 02:35 | plan | Phase 1A plan（`a6b96168`） |
| — | exec | Phase 1A 初期実装は #1402（`3331e5c4`）で main に入った（plan Current verdict） |
| 2026-10-22 09:07 | plan / C-1 / C-2 | Phase 1B 差分計画へ改訂（#1602 / `69387d32`、Revision 2.4）。C-2 R1〜R3 と R3 後スコープ検証を反映、簡易 C-1 PASS（WARN 2 件） |
| 2026-10-22 17:55 | C-3 待ち | #1393 PF-5 の Human 決定を review-external に記録（#1605 / `742f63f6`）。本 plan は変更なし |
| 2026-10-23 10:00 | C-3 待ち | 本 status.md を新設。`approvals/` 無し = C-3 未実施 |
| 2026-10-29 19:09 | C-3 | C-3 Gate: APPROVED（Human、`bin/plangate approve`、`approved_at` 2026-10-29T10:09:24Z、`plan_hash` `sha256:d4641124…`。c3.json は承認に使った worktree に untracked で保管。origin/main の plan.md の sha256 と一致を照合済み） |
| 2026-10-30 00:58 | BLOCKED | plan を変更した PR #1619（`62b9a5df`）が main に merge。plan_hash は上記と一致のまま。exec は下記「残タスク」の前提待ち（`blocker`: #1329 preflight 記録 / reviewed_at_sha 記録 / `owner`: Human / `unblock_condition`: 残タスクの exec 前提をすべて満たす） |
| 2026-11-24 19:18 | exec | T1 開始。`reviewed_at_sha` / base SHA と #1329 preflight を下記「T1 記録」に記録 |
| 2026-11-25 12:00 | BLOCKED | スライス A 着手前に plan 矛盾を検出（review-external R-066 / R-067）。Human 決定: 案 1（plan-gate decision 廃止）/ `contract_bound_seq` は decision のみ。`blocker`: plan Revision 2.5 反映 + 再 C-3 / `owner`: Human / `unblock_condition`: 新 c3.json を exec-1391 に配置。コード変更なし |
| 2026-11-25 21:40 | C-3 待ち | Human 指示「a」で plan Revision 2.5 を AI が反映（R-066 / R-067、D-16 / D-17）。簡易 C-1 PASS（D-13 原文の「L162」は Human 決定の記録として残し D-16 が上書き）。新 plan sha256 `0fe14701…`。旧 c3.json（`d4641124…`）は無効 → 再 C-3 待ち |
| 2026-11-26 07:23 | exec | 再 C-3 照合: c3.json（`approved_at` 2026-11-25T21:59:11Z）の `plan_hash` = plan.md sha256 `0fe14701…`（一致）。HEAD `4b9b4394`・`PLANGATE_HOOK_TASK=TASK-1391` を確認してスライス A 開始 |
| 2026-11-26 07:31 | exec | スライス A の T2 RED（`ad5bd1c3`）→ T3 GREEN（`9eed4608` / `05d1c046`）完了。下記「スライス A 記録」。バイト上限の再検査は RED を skip（#1623 待ち）。Human 確認待ちで停止 |

## #1393 PF-5 の合意（2026-10-22、Human 決定 / TASK-1393 R-085〜R-088）

- R-085（PF-5-1）: `MAX_DECISION_EVENT_BYTES` は envelope + binding キーを含む event 全体の canonical size に一本化。#1392 の envelope overhead は 0
- R-086（PF-5-2）: 定数は新設 `scripts/ai-loop-v2/limits.py`（葉 module、所有者 #1393）
- R-087（PF-5-3）: 仮値を fixture で固定（`MAX_INPUT_REFS=256` / `MAX_REQUIRED_VERIFIERS=16` / `MAX_REF_CHARS=256`、`MAX_DECISION_EVENT_BYTES` は算出値を切上げ、例 64KiB）。#1395 budget 確定時に `MAX_INPUT_REFS >= budget 最大件数` を検証
- R-088（PF-5-4）: キー名は #1391 の `artifact_ref` / `failure_fingerprints` / `verdicts`

## R-034 の前提の照合（2026-10-23 再照合）

出典: `review-external.md`「R-034 前提の照合」節（2026-10-22）。

| 前提 | 照合結果 |
|---|---|
| `MAX_*` の値が未合意 | 解消（PF-5-3 の仮値。`MAX_INPUT_REFS` の budget 照合は #1395 確定時） |
| 定数の module 位置が未確定 | 解消（`limits.py`、#1393 所有）。ただし `limits.py` は main に未作成（#1393 の exec で作る） |
| バイト上限の適用範囲が TASK-1393 / TASK-1392 / 旧 EV-22 で不一致 | TASK-1393 は Revision 2.7 で解消。TASK-1392 は 2026-10-23 の改訂（TASK-1392 R-105〜R-108）で event 全体基準に追従（C-3 再承認待ち） |
| decision の 3 キー名 | PF-5-4 で本 plan の名前を採用。再 C-3 条件には該当しない |

D-6 の exec BLOCKED 条件のうち「PF-5 合意」と「module 位置」は満たされた。exec 可否は他の前提（C-3、#1329 preflight、#1392 等）と併せて Human が判断する。

## T1 記録（2026-11-24）

- `reviewed_at_sha`: `62b9a5dfc63e37ff726d629a6898add3cfc9e5a3`（plan.md を最後に変更した commit、#1619）
- base SHA: `a21dff26fbf21b6f878a1fe7dcb18af7a840ee67`（測定時の `origin/main`）。branch HEAD は `9d55ae5d`。両者の間に `docs/working/TASK-1391` / `scripts/ai-loop-v2` / `tests` / `docs/ai/ai-loop-v2` の差分なし
- plan.md の sha256 は HEAD / `a21dff26` とも `d4641124…`（c3.json の `plan_hash` と一致）

### #1329 preflight（M-1〜M-3、HEAD `9d55ae5d` で実行。参考記録）

> 失効済みで判定条件ではない（`docs/ai/ai-loop-v2/phase0-migration.md:356`）。以下は参考として残す（H-12）。

```text
== M-1 ==
(none)
(none)
== M-2 ==
scripts/ai-loop-v2
(none)
== M-3 ==
scripts/ai-loop-v2/delivery_runtime.py
scripts/ai-loop-v2/ratchet.py
scripts/ai-loop-v2/run_event.py
scripts/ai-loop-v2/run_evidence.py
scripts/ai-loop-v2/run_state.py
scripts/ai-loop-v2/scope_observer.py
scripts/ai-loop-v2/test_delivery_v2.py
scripts/ai-loop-v2/test_ratchet.py
scripts/ai-loop/corpus_hash.py
scripts/ai-loop/run_evidence.py
scripts/ai-loop/test_corpus_hash.py
scripts/ai-loop/test_pbi_materializer.py
scripts/ai-loop/test_run_evidence.py
```

## スライス A 記録（2026-11-26）

実行順の正本: main の `docs/working/_reports/ailoop-v2-delivery-critical-path-2026-10-27.md`「2026-11-25 更新（実行計画）」。

- RED: `evidence/test-runs/slice-a-red-2026-11-26.md`（旧実装で FAIL を実測。R-009 は `ready` を再現）
- GREEN 後の結果（HEAD `05d1c046`）:
  - `test_delivery_v2.py`: 79 件 OK（skip 1 = EV-22 バイト上限、理由「#1623 待ち（H-10 = c）」）
  - `test_ratchet.py`: 49 件 OK / `test_limits.py`: OK
  - ta-87（21 mutation）/ ta-92 / ta-93 / ta-118: standalone PASS
  - `tests/run-tests.sh`: rc=2。ta-10 TC-7 と ta-100 が FAIL し、ta-100 の ERROR で以降の extras が未実行。2 件とも `origin/main`（`738986e2`）の standalone で同じく FAIL し、`scripts/ai-loop-v2` を参照しない（変更由来ではない。以降の extras の結果は未確認）
- P1B-12（replay 用 event の提供）は P1B-4〜P1B-10 の語彙で充足し、追加コードなし。P1B-13（adapter 境界文書）は T5 のためスライス B

## 残タスク

- [x] Human C-3（`approvals/c3.json` の発行、2026-10-29 19:09）
- [x] exec 前提: #1329 preflight 記録 / reviewed_at_sha 記録（2026-11-24「T1 記録」。`limits.py` は PR #1622 / `46685615` で main に入り充足）
- [x] スライス A: T2 RED → T3 GREEN（P1B-1〜P1B-11、P1B-7 は件数上限まで）
- [ ] 👤 バイト上限の再検査の置き場所（#1391 後半 / #1623 の PR）を Human が決める（BLOCKED。`blocker`: H-10 = c の確認 / `owner`: Human / `unblock_condition`: 置き場所の決定）
- [ ] スライス B: EV-22 バイト上限の skip を外して GREEN（#1623 の定数が main に入った後のみ）→ T4 mutation → T5 P1B-13 文書 → T6 敵対レビュー R1 / R2

## 計画からの変更点

- **ratchet fixture の追加変更**（P1B-9 の波及）: `failure.verification_ref` を必須にしたため、`tests/fixtures/ai-loop-v2/ratchet/verification-skipped.json` の FailureRecord（event payload と `failure_record` の 2 箇所）に `verification_ref: "verification:missing"` を足した。これに伴い plan R-063 が挙げた digest（L36 / L43 / L50）に加え、`event_ref`（3 箇所）と `failure_record_refs` も `ratchet.py` の `canonical_digest` / `compute_source_set_digest` で再計算した。`evaluation_plan_digest`（L73）は sealed plan だけに依存するため値は変わらなかった
- **plan-gate の状態遷移**（D-16）: `PLAN_VERIFYING -> EXECUTING` は `decision_made` を伴わないが、`DurableRunStore.transition` は 1 遷移に 1 event を要する。そこで plan verification（pass かつ plan_hash に束縛）の `verification_recorded` 自体を `EXECUTING` への遷移として append した
- **ta-87 L260-263**（P1B-3）: spec trace の event は envelope と payload を平らに持つため、`bound.get("plan_hash")` は既にトップレベル参照であり、書き換えていない
- **mutation の添字**: plan-gate decision の削除で ta-87 の既存 mutation 2〜18 の添字が 1 つずれたため追従した。ta-87 に mutation 19〜21（plan-gate decision の復活 / MERGE_READY の `artifact_ref` 欠落 / HUMAN_ESCALATED を ready と投影）を足した
- **未作成のテスト**: EV-37（同 seq の重複は EV-26 の seq 連続検査で invalid になる）と EV-38（静的確認）は専用テストを置いていない。PJ-23b の「digest 再計算前は不一致で FAIL」の対照は単独では取っていない（再計算前は `validate_event` の `failure keys` で先に落ちていた）

### 実装時の解釈（Human 確認を求める）

- **I-1（PJ-16 と P1B-1）**: `contract_bound_seq == 直前の bound の event_seq` は、先行する bound があるときだけ検査する。PJ-16（bound 無しの `BLOCKED` は `terminal_unready`）を満たすため。bound 無しの `MERGE_READY` は P1B-6 の ready 条件で invalid になる
- **I-2（D-15 の適用範囲）**: sha256 形（`^sha256:[0-9a-f]{64}$`）を強制したのは plan が「sha256 ref」と書いたフィールド（`loop_contract_ref` / `observed_artifact_ref` / decision の `artifact_ref`）だけ。`inputs` / verification id / `failure_fingerprints` / `blockers` は「重複なしの非空文字列」までで、sha256 形は強制していない（既存 fixture の id・fingerprint は sha256 形ではない）。`required_verifiers` は D-15 の verifier_id 規則（ASCII・長さ ≤ 71）を適用
- **I-3（`verdicts` の形）**: `verdicts` は `{verifier_id: "pass" | "fail" | "unavailable"}` の object。producer は required verifier ごとに最新結果を入れ、`inconclusive` / `unavailable` は `unavailable` に寄せた（TASK-1393 は `(verifier_id, kind)` を鍵とする）
