---
task_id: TASK-0143
artifact_type: pbi-input
schema_version: 1
status: draft
---

# PBI INPUT PACKAGE — TASK-0143

## Context / Why

EPIC #527（Enforcement Integrity Roadmap）子 PBI 第 1 号。

`docs/ai/hook-enforcement.md` 2026-06-10 棚卸しで、EH-4 / EH-5 / EH-7 は
スクリプト実装済みながら**発火経路が皆無**と確認された（配線状態表：⏳ 実装済み・未配線）。
スクリプトが存在しても呼ばれなければ守れない — これが「仕様と強制実態の乖離」
（issue #500 §1）の核心。

加えて、#529（dogfooding）では「次 PBI から metrics 採取 + WF-06 retro opt-in を
必須試行」と定義されているため、本 PBI でその初回試行を実施する。

## What — Scope

### In scope

| # | 内容 | HO |
|---|------|-----|
| S1 | EH-4（`check-test-cases.sh`）を `bin/plangate verify` 実行前に CLI 配線 | ✅ bin/plangate |
| S2 | EH-5（`check-verification-evidence.sh`）を PR 作成フロー前に CLI 配線、またはサブコマンドがない場合は `doctor` wiring-check へ追加 | ✅ bin/plangate |
| S3 | EH-7（`check-merge-approvals.sh`）を merge フロー前に CLI 配線、またはサブコマンドがない場合は `doctor` wiring-check へ追加 | ✅ bin/plangate |
| S4 | `docs/ai/settings-wiring-contract.md` に「CLI 配線（EH-4/5/7）」セクション追加・明文化 | — |
| S5 | EHS-1〜3（validation_bias: strict 発火条件）の設計・ドキュメント化（実装は後続 PBI） | — |
| S6 | `bin/plangate doctor` が EH-4/5/7 配線欠落を警告（警告レベル可） | ✅ bin/plangate |
| S7 | ta-44（または ta-45）: EH-4/5/7 CLI 配線テスト追加（`sh tests/run-tests.sh` 通過） | — |
| S8 | (#529) フェーズ遷移ごとに `bin/plangate metrics TASK-0143 --collect` を実行（運用試行） | — |
| S9 | (#529) 完了後に `docs/working/improvement-seeds.md` へ WF-06 retro エントリを追記 | — |

### Out of scope

- EHS-1〜3 の実装（本 PBI は設計・ドキュメント化のみ）
- EH-4/5/7 の PreToolUse hook 化（CLI 配線のみ）
- C-4 自律承認・CI 縮退モード（#527 子 PBI 3）
- yaml schema 検証 CI（TA-35 で対応済みのため対象外）
- bin/plangate に `pr` / `merge` サブコマンドがない場合の新規サブコマンド実装

## Acceptance Criteria

| AC | 内容 |
|----|------|
| AC-01 | `plangate verify TASK-XXXX` 実行時に EH-4（test-cases.md 存在確認）が発火し、なければ FAIL + メッセージを出力する |
| AC-02 | EH-5（verification evidence 存在確認）が PR 作成フローまたは doctor で検証される |
| AC-03 | EH-7（C-3/C-4 承認状態確認）が merge フローまたは doctor で検証される |
| AC-04 | ta-44（または ta-45）で EH-4/5/7 の CLI 配線が PASS（`sh tests/run-tests.sh` 0 FAIL） |
| AC-05 | `docs/ai/settings-wiring-contract.md` に CLI 配線（EH-4/5/7）セクションが追加されている |
| AC-06 | EHS-1〜3 発火条件の設計が `docs/ai/hook-enforcement.md` または別ドキュメントに明文化 |
| AC-07 | `bin/plangate doctor` が EH-4/5/7 の配線欠落を警告出力する |
| AC-08 | (#529) `docs/working/_metrics/events.ndjson` が生成され `bin/plangate metrics TASK-0143 --report` が集計を返す |
| AC-09 | (#529) `docs/working/improvement-seeds.md` に本 PBI の 1 エントリが追記される |

## Notes from Refinement

- EH-4/5/7 は PreToolUse hook ではなく **CLI 配線**（V-1 前 / PR 前 / merge 前で `bin/plangate` が呼ぶ）として設計（hook-enforcement.md §4 由来欄参照）
- `bin/plangate` は HO パス → apply-script 経由で Human が実行
- EH-4 が既に `cmd_validate` 内でアーティファクト確認しているか要調査（二重化を避ける）
- EHS-1〜3 は `model-profiles.yaml` の `validation_bias: strict` と連携するが発火経路が未設計。本 PBI は設計・ドキュメント化まで
- `docs/ai/settings-wiring-contract.md` は `docs/ai/` 配下（HO 非対象）のため AI 直接編集可
- #529 は「実装でなく運用試行」— metrics collect / retro opt-in を本 PBI の実作業に乗せて初回動作確認する

## Estimation Evidence

**Risks**:
- bin/plangate（HO パス）へのすべての変更は apply-script 経由 → Human 実行ステップが 1〜2 件発生
- EH-5/7 の配線先（PR/merge サブコマンド）が未実装の場合、doctor 拡張に設計変更が必要（plan フェーズで確定）
- EHS-1〜3 設計は model-profiles.yaml との連携仕様が不明確 → plan フェーズで調査

**Unknowns**:
- `bin/plangate` に `pr` / `merge` サブコマンドが存在するか
- EH-4 が `cmd_validate` 内で test-cases.md をアーティファクトとして既に確認しているか（二重化）
- settings-wiring-contract.md 追加が HO 制約を受けるか（`docs/ai/` は非 HO のはず）

**Assumptions**:
- `check-test-cases.sh` / `check-verification-evidence.sh` / `check-merge-approvals.sh` の実装は既存のまま使用可能
- テスト番号は ta-44 から採番
- metrics opt-in は既存の `bin/plangate metrics` を使用（新規実装なし）

## 関連

- EPIC: #527（Enforcement Integrity Roadmap）
- 親 issue: #500（承認境界の強制実態ギャップ是正）
- Metrics dogfooding: #529
- 配線仕様: `docs/ai/hook-enforcement.md`
- 契約: `docs/ai/settings-wiring-contract.md`
- 先行完了 PBI: TASK-0141（EH-2 strict JSON + stdin fallback）
