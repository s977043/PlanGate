---
task_id: TASK-0146
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-07-05
author: qa-reviewer (bookkeeping, after-the-fact)
v1_release: "054b4aa (main, PR#639 HO 実適用)"
---

> **本 handoff はマージ後の事後発行（bookkeeping）である。** current-state.md
> が「C-3 ゲート待ち」と stale 表示していたが、実際は plan.md / test-cases.md /
> review-self.md（C-1 PASS）に基づき exec・PR マージ・HO 実適用まで完了して
> いたため、それらの一次証跡（plan.md / review-self.md / マージ済 PR #637・
> #639）から事後再構成して発行する。

# Handoff Package — TASK-0146（EHS-2/3 bin/plangate 配線 / EPIC #527 増分2/3）

## メタ情報

```yaml
task: TASK-0146
related_issue: EPIC #527（Enforcement Integrity Roadmap）
author: qa-reviewer (bookkeeping)
issued_at: 2026-07-05
v1_release: "054b4aa (main, PR#639 マージコミット。base 実装は d91e8e3 / PR#637)"
```

## 1. 要件適合確認結果

test-cases.md の受入基準マッピング（TC-01〜06）と PR#637/#639 のコミット
本文を根拠に事後判定する。

| 受入基準                                       | 判定 | 根拠 / コメント                                                                                                               |
| ---------------------------------------------- | ---- | ----------------------------------------------------------------------------------------------------------------------------- |
| EHS-3 が `cmd_verify` の V-1 失敗経路に配線    | PASS | PR#637 で `scripts/_apply_task_0146_patches.py` に EHS-3 patch 定義、PR#639 で `bin/plangate` へ実適用（+32 行）。ta-47 TC-01 |
| EHS-3 strict 時は fix-loop 上限超過で block    | PASS | `PLANGATE_HOOK_STRICT=1` で `check-fix-loop.sh` increment 呼び出し → 上限超過時 `return 1`。ta-47 TC-02                       |
| EHS-3 非 strict では warn のみ（既存挙動不変） | PASS | 非 strict 時は `2>/dev/null \|\| true`。ta-47 TC-03                                                                           |
| EHS-2 が `cmd_handoff --verify` に配線         | PASS | `--verify` フラグ追加 + `check-handoff-elements.sh` 呼び出し。ta-47 TC-04                                                     |
| EHS-2 strict 時は 6 要素不足で block           | PASS | strict 時 `return 1`。ta-47 TC-05                                                                                             |
| patched `bin/plangate` が構文健全              | PASS | `sh -n bin/plangate`。ta-47 TC-06。PR#639 本文「359 passed / 0 failed」で回帰確認                                             |

**総合**: 6/6 基準 PASS
**FAIL / WARN の扱い**: なし（該当なし）

## 2. 既知課題一覧

| 課題                                                                                                                 | Severity | 状態                                                                                              | V2 候補か                  |
| -------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------------- | -------------------------- |
| `docs/working/TASK-0146/approvals/c3.json` が作業ツリーに存在しない（C-3 承認記録が working context に残っていない） | minor    | accepted（PR ベースの C-4 レビューでマージ済み・実害なし。本 bookkeeping での既知課題として記録） | No                         |
| `status.md` / `pbi-input.md` が未作成のまま完了している（INDEX.md に「status.md（未作成）」の記載が残存）            | minor    | accepted（current-state.md と PR コミット本文で経緯を代替追跡可能）                               | No                         |
| `PLANGATE_VALIDATION_BIAS` の conductor 自動注入は本 PBI 対象外（Non-goals 明記）                                    | minor    | accepted（TASK-0147 で一部後続対応済み）                                                          | No（TASK-0147 で対応済み） |

**Critical 課題の対応**: なし（critical 課題なし、V1 リリース可）

## 3. V2 候補

| V2 候補                                                      | 理由                                                | 推定優先度      | 関連 Issue |
| ------------------------------------------------------------ | --------------------------------------------------- | --------------- | ---------- |
| `check-fix-loop.sh` / `check-handoff-elements.sh` 自体の改修 | 本 PBI は配線のみで既存実装を変更しない Constraints | Low             | EPIC #527  |
| `.plangate.yml` 経由での `PLANGATE_VALIDATION_BIAS` 自動供給 | TASK-0147 で `--profile` 方式として一部実現済み     | Low（一部完了） | #644       |

## 4. 妥協点

| 選択した実装                                                                                             | 諦めた代替案                    | 理由                                                                                                                        |
| -------------------------------------------------------------------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| apply-script 経由の HO 適用（`scripts/_apply_task_0146_patches.py` + `apply-task-0146-ehs23-wiring.sh`） | AI が `bin/plangate` を直接編集 | HO 対象パスの AI 自己改変は禁止（settings-wiring-contract）。Human が `--apply` を実行することで Shadow Config を防ぐ       |
| 静的検査（grep/awk/`sh -n`）中心のテスト戦略                                                             | 実行時の動的テスト              | strict/non-strict 分岐や patch 有無を軽量に検証でき、CI での SKIP/PASS 切り替えが容易なため踏襲（TASK-0145 ta-46 と同方式） |

## 5. 引き継ぎ文書

### 概要

TASK-0146 は EPIC #527（Enforcement Integrity Roadmap）の増分 2/3 として、
`bin/plangate` に EHS-2（handoff 6 要素チェック）と EHS-3（fix-loop 上限
チェック）を配線した。`PLANGATE_VALIDATION_BIAS=strict` 時に block、
非 strict（既定）では warn のみで既存挙動を維持する。

実装は PR#637（apply-script + test + doc 更新、非 HO）と PR#639
（`bin/plangate` への実適用、HO 本体反映）の 2 段階で main にマージ済み。
`sh tests/run-tests.sh` は 359 passed / 0 failed（ta-46/ta-47 含む）。

本 handoff は current-state.md の stale 表示（「C-3 ゲート待ち」）を是正する
bookkeeping セッションで、plan.md / test-cases.md / review-self.md
（C-1 全 15 項目 PASS）とマージ済み PR#637・#639 を一次証跡として事後発行
したものであり、新規実装や追加検証は行っていない。

### 触れないでほしいファイル

- `bin/plangate`（HO）: EHS-2/3 の block 分岐（`# EHS-2 BLOCK` / `# EHS-3 BLOCK`
  コメント直後）は ta-47 TC-02/TC-05 の awk 検出パターンと密結合。変更する
  場合は `tests/extras/ta-47-ehs23-wiring.sh` を通すこと

### 次に手を入れるなら

- EPIC #527 の残増分（TASK-0147 で validation_bias 供給経路は対応済み）の
  follow-up がある場合は `docs/ai/hook-enforcement.md` の配線状態表を確認
- `docs/working/TASK-0146/approvals/` と `status.md` が欠落しているため、
  同種の bookkeeping が必要な他 TASK がないか横断確認すると監査性が上がる

### 参照リンク

- EPIC: #527（Enforcement Integrity Roadmap）
- PR#637: `d91e8e3`（apply-script + test + doc、非 HO）
- PR#639: `054b4aa`（`bin/plangate` HO 実適用、TASK-0145 と合併適用）
- plan.md: `docs/working/TASK-0146/plan.md`
- test-cases.md: `docs/working/TASK-0146/test-cases.md`
- review-self.md: `docs/working/TASK-0146/review-self.md`（C-1: 全 15 項目 PASS）

## 6. テスト結果サマリ

マージ済み PR#639 のコミット本文記載の CI 実行結果を根拠に事後記載する
（本 bookkeeping セッションでの再実行は行っていない）。

| レイヤー                                | 件数 | PASS | FAIL / SKIP | カバレッジ                             |
| --------------------------------------- | ---- | ---- | ----------- | -------------------------------------- |
| 静的検査（ta-47: TC-01〜06）            | 6    | 6    | 0           | AC 6 件を 1:1 カバー                   |
| Regression（`tests/run-tests.sh` 全件） | 359  | 359  | 0           | 既存 TC 全件 0 FAIL（PR#639 本文記載） |

**FAIL / SKIP の詳細**: なし。PR#637（apply-script 未適用状態）では ta-47 は
SKIP（構造的に想定通り）、PR#639（HO 実適用後）で全 TC PASS に移行。

## 7. Metrics summary（opt-in）

該当なし（metrics 収集未実施）
