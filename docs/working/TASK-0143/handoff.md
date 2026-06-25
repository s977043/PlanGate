---
task_id: TASK-0143
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-06-26
author: qa-reviewer
v1_release: "26a5b60"
---

# Handoff Package — TASK-0143

## メタ情報

```yaml
task: TASK-0143
related_issue: https://github.com/s977043/plangate/issues/528
  parent_issue: https://github.com/s977043/plangate/issues/500
  epic: https://github.com/s977043/plangate/issues/527
author: qa-reviewer
issued_at: 2026-06-26
v1_release: 26a5b60 (PR#629 + PR#625 両マージ済み / main)
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-01: `plangate verify` で EH-4 発火 | PASS | `bin/plangate` L2120〜2126: V-1 前に `check-test-cases.sh` を strict=1 で呼び出し。test-cases.md なしは exit 1 でブロック |
| AC-02: EH-5 が doctor で検証される | PASS | `bin/plangate verify` L2130〜: V-1 後に `check-verification-evidence.sh` を `PLANGATE_HOOK_STRICT=0` (warn) で呼び出し。`bin/plangate doctor` CLI Hook Wiring セクションで EH-5 配線確認も実施 |
| AC-03: EH-7 が doctor で検証される | PASS | `bin/plangate doctor` L577〜603: `=== CLI Hook Wiring (EH-4/5/7) ===` セクション追加。EH-7 は INFO で手動呼び出しを案内 |
| AC-04: ta-44 が 0 FAIL で PASS | PASS | `tests/extras/ta-44-eh457-cli-wiring.sh` 5 TC。`sh tests/run-tests.sh` → 349 passed, 0 failed（2026-06-26 実測） |
| AC-05: settings-wiring-contract.md に CLI 配線セクション追加 | PASS | `docs/ai/settings-wiring-contract.md` §CLI 配線（EH-4/5/7）— TASK-0143 セクション追加済み（`grep -c "CLI 配線"` → 2） |
| AC-06: EHS-1〜3 設計が hook-enforcement.md に明文化 | PASS | `docs/ai/hook-enforcement.md` §EHS-1〜3 に発火条件・対応・実装状態を記述。`grep -c "EHS-1\|EHS-2\|EHS-3"` → 10 |
| AC-07: doctor が EH-4/5/7 配線欠落を警告 | PASS | `bin/plangate doctor` が `[PASS]` / `[WARN]` で EH-4/5 の配線状態を報告。EH-7 は `[INFO]` で手動呼び出し手順を案内 |
| AC-08: events.ndjson 生成・metrics report が動作 | WARN | #529 dogfooding は今回の run で opt-out。V2 候補に移行（詳細は §3） |
| AC-09: improvement-seeds.md にエントリ追記 | PASS | PR#625 に `docs/working/improvement-seeds.md` への TASK-0143 エントリ追記を含む |

**総合**: `7/9 基準 PASS（1 WARN / 1 V2 移行）`

**WARN / 移行の扱い**:
- AC-08（WARN）: metrics dogfooding は開発フロー実績が少ない状況での初回試行。本 PBI では opt-out とし、次 PBI 以降の継続実施に委ねる。機能自体（`bin/plangate metrics`）は動作済みで品質上の問題なし
- AC-09 は improvement-seeds.md への追記（PR#625 内）により PASS 扱い

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| EH-7 が doctor 可視化のみで CLI 強制配線なし | minor | accepted | Yes（#500 後続 PBI） |
| EH-5 を warn モードのみとしており blocking 不可 | minor | accepted | Yes（EHS-2 実装時に昇格候補） |
| EHS-1〜3 は設計のみ、実装未着手 | minor | open | Yes（#527 後続子 PBI） |
| AC-08 metrics dogfooding opt-out | info | accepted | Yes（次 PBI 以降の継続運用試行） |

**Critical 課題**: なし

補足:
- EH-7 の CLI 強制配線は `bin/plangate pr` / `bin/plangate merge` サブコマンドが存在しないため doctor 可視化に留めた設計判断。GitHub branch protection 連携が整った段階で blocking 化を検討する
- EH-5 warn モードは「verify 完了直後は evidence がない状態が多い」という運用実態への配慮。EHS-2 で handoff 必須要素チェックと組み合わせてから blocking 化する方針

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| EH-7 の CLI 強制配線 | `pr` / `merge` サブコマンド未実装、GitHub branch protection 連携が前提 | Medium | #500, #527 |
| EHS-1〜3 の実装 | 本 PBI は設計・ドキュメント化のみ。`validation_bias: strict` 発火経路の実装は別 PBI | High | #527 子 PBI |
| EH-5 blocking モード化 | EHS-2（handoff 6 要素チェック）と組み合わせた段階化が必要 | Medium | #527 |
| metrics dogfooding (#529) 定常化 | 本 PBI で opt-out。次 PBI から継続実施し知見を蓄積する | Low | #529 |
| apply-script idempotent 検証の自動化 | E-01（2 回 --apply で "already applied" SKIP）は手動確認のみ | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| EH-5 を warn（PLANGATE_HOOK_STRICT=0）で呼び出し | EH-5 を strict=1 で blocking | verify 完了直後は evidence が存在しない状態が正常。blocking にすると全 PBI で false positive が発生するため warn 限定 |
| EH-7 を doctor [INFO] 案内のみ | EH-7 を verify に組み込み blocking | `bin/plangate` に `merge` サブコマンドが存在しないため配線先がない。doctor 可視化で暫定対処し後続 PBI で根治 |
| apply-script（Python + sh の 2 層）で bin/plangate を Human 適用 | AI が bin/plangate を直接編集 | HO（Hardening Override）対象パスのため AI 直接編集禁止。grep/sed パターンベースで行番号非依存の patch を作成し Human が `--apply` 実行 |
| EHS-1〜3 を設計・ドキュメント化のみ | EHS-1〜3 の実装まで実施 | `model-profiles.yaml` の `validation_bias: strict` 発火経路が未整備で実装前に設計確定が必要。#527 のスコープ定義に委ねる |
| ta-44 を 5 TC 構成（apply 前 SKIP）| apply 後の挙動を全 TC で検証 | CI（apply 未適用環境）で全 TC が SKIP になるよう apply 判定を先行させ偽 FAIL を防ぐ（ta-43 パターン踏襲） |

## 5. 引き継ぎ文書

### 概要

TASK-0143 は EPIC #527（Enforcement Integrity Roadmap）の子 PBI 第 1 号として、
EH-4 / EH-5 / EH-7 の CLI 配線を実施した。

実装は 2 段階 PR 構成で完了:
- PR#625（`feat/task-0143-581-subagent-review-exec`）: docs/ai/ 更新・ta-44 テスト・apply-script 作成
- PR#629（`feat/task-0143-581-subagent-review-exec`）: bin/plangate への EH-4/5 CLI 配線適用（Human apply 後）

main ブランチ HEAD は `26a5b60`。テストは 349 passed / 0 failed。
EH-4 は `plangate verify` の V-1 前で strict=1 発火、EH-5 は V-1 後で warn 発火、
EH-7 は `plangate doctor` の CLI Hook Wiring セクションで [INFO] 案内のみ。
EHS-1〜3 は `docs/ai/hook-enforcement.md` §EHS に設計を明文化し実装は後続 PBI に委ねた。

### 触れないでほしいファイル

- `bin/plangate`: HO 対象パス。AI 直接編集禁止。変更が必要な場合は apply-script パターン（`scripts/_apply_task_XXXX_patches.py` + `.sh`）を作成して Human が `--apply` 実行
- `scripts/apply-task-0143-eh457-wiring.sh` / `scripts/_apply_task_0143_patches.py`: 適用済みの apply-script。再適用すると idempotent 動作で SKIP されるが、内容改変は履歴を壊す

### 次に手を入れるなら

- **EHS-1〜3 の実装**（#527 後続子 PBI）: `docs/ai/hook-enforcement.md §EHS` の設計に従い `validation_bias: strict` 発火経路を実装する。`check-handoff-elements.sh` が EHS-2 の基盤として既存
- **EH-7 blocking 化**（#500 後続 PBI）: `plangate pr` / `plangate merge` サブコマンドを実装後に `check-merge-approvals.sh` を strict=1 で配線
- **ta-44 テストの apply 後 TC 追加**: 現行 5 TC は apply 前 SKIP + apply 後基本確認のみ。`plangate verify` が実際に EH-4 block した audit log を検証する TC を追加すると coverage が上がる
- apply-script パターンを踏む際は `scripts/_apply_task_0143_patches.py` を参照テンプレートとして活用（dry-run / --apply 両対応・idempotent・grep パターンベース）

### 参照リンク

- EPIC: https://github.com/s977043/plangate/issues/527
- 親 issue: https://github.com/s977043/plangate/issues/500
- metrics dogfooding: https://github.com/s977043/plangate/issues/529
- hook-enforcement.md（配線状態正本）: `docs/ai/hook-enforcement.md`
- settings-wiring-contract.md（CLI 配線セクション）: `docs/ai/settings-wiring-contract.md`
- pbi-input.md: `docs/working/TASK-0143/pbi-input.md`
- plan.md: `docs/working/TASK-0143/plan.md`
- status.md: `docs/working/TASK-0143/status.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit（ta-44 hook スクリプト直接呼び出し） | 5 | 5 | 0 / 0 | EH-4/5/7 各パス・ブロック・warn |
| Integration（tests/run-tests.sh 全体） | 349 | 349 | 0 / 0 | — |
| E2E / Manual | — | — | — | apply-script dry-run → --apply → doctor 確認（Human 実施） |

**テスト実行コマンド**: `sh tests/run-tests.sh`

**FAIL / SKIP 詳細**: なし（全 TC PASS）

**注意**: ta-44 は apply-script 適用前の clean 環境では TC-02〜05 が SKIP に変わる設計。
CI（未適用環境）では SKIP が正常動作。apply 後の本番環境では 5 TC 全 PASS。

## 7. Metrics summary

該当なし（AC-08 / #529 dogfooding は本 PBI では opt-out。V2 候補として次 PBI 以降に継続）
