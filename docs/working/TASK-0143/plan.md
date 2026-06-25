# TASK-0143 EXECUTION PLAN — hook 物理配線 6/12 → 12/12（#527 子1 / #500 §1）

> 由来: EPIC [#527](https://github.com/s977043/plangate/issues/527) 子 PBI 第1号 ／ [#500](https://github.com/s977043/plangate/issues/500) §1 Shadow Config 解消
> 前提: TASK-0141（#500 EH-2 strict / apply-script）の Human 適用（H-03）完了が望ましい（独立だが同じ承認境界領域）

## Goal

実装済みだが発火経路のない 6 hook（EH-4 / EH-5 / EH-7 / EHS-1 / EHS-2 / EHS-3）に物理配線を与え、`docs/ai/hook-enforcement.md` の配線状態表を **6/12 → 12/12** にする。配線済みを `bin/plangate doctor` が機械検証し、drift を exit≠0 で検出できる状態を到達点とする（Shadow Config の構造的再発防止）。

## Constraints / Non-goals

- **Non-goal**: hook ロジック自体の新規実装（12/12 すべて実装済み・単体テスト済み）。本 PBI は「配線 + 配線検証」に限定。
- **Non-goal**: GitHub branch protection の自動連携（EH-7 の GitHub 側強制は別 PBI 候補）。
- **Constraint**: 承認境界パス（`scripts/hooks/` は触れない／`.claude/settings.example.json`・`bin/plangate`・`.github/workflows/` は触れる）→ **mode=high-risk 固定・lite_eligible=false**（mode-classification 承認境界ルール）。
- **Constraint**: 既定挙動不変。新規配線は **default=warning（continue:true）** で導入し、strict 昇格は段階化（#527 Risk の fallback 方針）。

## Approach Overview

6 hook を性質で 2 群に分ける。

| 群 | hook | 種別 | 発火経路（配線先） |
|----|------|------|------------------|
| **A: フェーズ呼出型** | EH-4（test-cases なし V-1 block）/ EH-5（検証ログなし PR block）/ EH-7（2段階レビューなしマージ block） | CLI（conductor が各フェーズ前に呼ぶ） | workflow-conductor のフェーズ前チェック + CI（PR/merge ガード） |
| **B: strict プロファイル発火型** | EHS-1（V-3 必須）/ EHS-2（handoff 6要素）/ EHS-3（fix loop 上限） | CLI（`validation_bias: strict` 時のみ追加発火） | **発火条件 `validation_bias: strict` の判定層が未配線**（要設計判断） |

**群 B の Unknown（#527 明記の未確定点）**: `validation_bias: strict` を「どの層が」判定して EHS-1〜3 を発火させるか。候補:
1. workflow-conductor runtime が model-profiles.yaml の `validation_bias` を解決し、strict 時のみ EHS チェックを呼ぶ（参照層 → 強制層への昇格）
2. hook 内で profile を自己解決（責務肥大・非推奨）

→ **C-3 で候補1を確定する想定**（conductor を単一判定層に集約）。確定後に群 B を配線。

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | EH-4/5/7 の現行呼出有無を conductor / CI で棚卸し（既に部分呼出があるか） | 棚卸しメモ | agent | 低 | 🚩配線先の重複確認 |
| S2 | 群 A 配線: conductor のフェーズ前（V-1前/PR前/merge前）に CLI 呼出を追加。CI（PR/merge）にもガード追加 | conductor 定義 + `.github/workflows/*.yml` 差分 | agent | 中 | 🚩default=warning で導入 |
| S3 | `bin/plangate doctor --check-settings` のモード別必須 hook 表を 6→9（群A含む）に拡張し drift 検出 | `bin/plangate` + `scripts/check-settings-wiring.sh` 差分 | agent | 中 | 🚩exit≠0 で drift block |
| S4 | 群 B の発火層を C-3 確定案（候補1）で配線。strict 時のみ EHS-1〜3 発火 | conductor + model-profiles 参照配線 | agent | **高** | 🚩strict 限定・既定 OFF を回帰確認 |
| S5 | `docs/ai/hook-enforcement.md` 配線表を 12/12 に更新 | doc 差分 | agent | 低 | 🚩doctor 出力と一致 |

## Files / Components to Touch

- `.claude/settings.example.json`（群A PreToolUse 非該当分は conductor 側／CI 側に寄せる）
- `bin/plangate` + `scripts/check-settings-wiring.sh`（doctor wiring 検証拡張）
- `.claude/agents/workflow-conductor.md`（フェーズ前チェック呼出の明文化）
- `.github/workflows/*.yml`（PR/merge ガード）
- `docs/ai/hook-enforcement.md`（配線表更新）
- **触れない**: `scripts/hooks/*.sh`（実装は完了・凍結）

## Testing Strategy

- **Unit/Integration**: `tests/extras/ta-06-hooks.sh` を拡張し EH-4/5/7 の「呼出されること」を assert（ta-06 のログ握りつぶし解消は #500 §3 で着手済 → 整合確認）。
- **Wiring 検証**: `bin/plangate doctor --check-settings` が群A未配線時に exit≠0 を返す negative test を追加。
- **群 B 回帰**: `validation_bias` 非 strict（既定）で EHS-1〜3 が発火しない（既存挙動不変）ことを assert。
- **Verification Automation**: `sh tests/run-tests.sh` 全 PASS を V-1 完了条件とする。

## Risks & Mitigations

| Risk | 対策 |
|------|------|
| 群A配線で既存フローを誤 block | default=warning 導入 → 実績後に strict 昇格（段階化） |
| 群B発火層の設計誤り（conductor 肥大） | C-3 で候補1を明示承認。判定は単一層に集約 |
| doctor 拡張が既存 6 hook 検証を退行 | 既存 ta-10-doctor-fix / check-settings-wiring の回帰を必須化 |

## Questions / Unknowns

1. **群 B 発火層**（candidate1=conductor runtime）→ C-3 で確定。
2. EH-7 は hook + GitHub branch protection の二重化が理想だが、本 PBI は hook/CI 配線まで。GH 側は別 PBI に切り出し可か？ → C-3 判断。

## Mode判定

**モード**: high-risk

**判定根拠**:
- 変更ファイル数: 5-6（settings.example / bin/plangate / conductor / workflows / doc）→ high-risk
- 受入基準数: 5（#527 受入基準のうち配線系2 + 本 PBI 固有3）→ standard〜high-risk
- 変更種別: 承認境界（settings / bin/plangate / .github/workflows）配線 → **承認境界ルールにより最低 high-risk 強制**
- リスク: 高（強制力の発火経路そのもの。誤配線で誤 block / 強制漏れ両方のリスク）
- **最終判定**: **high-risk**（承認境界周辺 → lite_eligible=false / Standard 同期 C-3 固定）
