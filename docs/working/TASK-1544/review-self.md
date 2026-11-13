# TASK-1544 セルフレビュー結果（C-1）

> 実施: 2026-10-26 06:25 / 対象: pbi-input.md, plan.md, todo.md, test-cases.md

## サマリー

**判定: PASS（WARN 1 件）**

| 区分 | PASS | WARN | FAIL |
|------|------|------|------|
| Plan（7 + AEE 2） | 8 | 1 | 0 |
| Plan 品質追加（2） | 2 | 0 | 0 |
| ToDo（6） | 6 | 0 | 0 |
| TestCases（3） | 3 | 0 | 0 |
| B-1/B-2（2） | 2 | 0 | 0 |
| SEC / SCOPE-DISC（2） | 2 | 0 | 0 |

## Plan チェック

- C1-PLAN-01 受入基準網羅性: PASS — AC-1〜5 を test-cases.md のマッピング表で全件 TC に対応づけた
- C1-PLAN-02 Unknowns処理: **WARN** — U-1（pbi-input の改変は c3 の plan_hash に束縛されない）を本 PBI では解消しない。残存リスクとして生成器の docstring に明記する計画。C-3 で受け入れ可否の判断を求める
- C1-PLAN-03 スコープ制御: PASS — 変更 3 ファイル。HO パス・opt-in source の追加・CLI 経路は Out of scope に明記
- C1-PLAN-04 テスト戦略: PASS — TDD（RED を記録）+ 変異注入 4 種 + harness 経由の実行と main 対照
- C1-PLAN-05 Work Breakdown Output: PASS — Task 1〜4 に Files / Completion Criteria / Rollback あり
- C1-PLAN-06 依存関係: PASS — todo.md に depends_on と Human 依存（H-1）を記載
- C1-PLAN-07 動作検証自動化: PASS — 全 TC を TA-118 で自動実行
- C1-PLAN-08-AEE Stop Condition: PASS — EH-3 による block を含めて記載
- C1-PLAN-09-AEE Replan Triggers 機械値: PASS — 変更ファイル 3 件超 / 実行 30 秒超など数値で記載

## Plan 品質追加チェック

- C1-SUP-PLAN-01 No Placeholders: PASS — TC-11 の引数だけは exec 時に確定と明記（理由: 既存スクリプトの CLI に合わせる）
- C1-SUP-PLAN-02 Task Sizing: PASS

## ToDo チェック

- C1-TODO-08〜12, RB: PASS — 粒度・depends_on・🚩・完了条件・rollback を全タスクに記載

## テストケースチェック

- C1-TEST-13: PASS — 組合せ表 retro_enabled（true / false / 欠落）× confirmed_by（空 / プレースホルダ / 入力済み）を網羅
- C1-TEST-14: PASS — 終了コードと seeds の sha256 照合で判定
- C1-TEST-15: PASS — 表記ゆれ / コメント内 / 壊れた c3.json / §2 欠落

## B-1/B-2

- C1-B1B2-16: PASS — Human 決定（2026-10-26）で方針確定済み
- C1-B1B2-17: PASS — 案 A/B/C を比較

## SEC / SCOPE-DISC

- C1-SEC-01: PASS — 秘密情報に触れない。c3.json は読むだけ
- C1-SCOPE-DISC-01: PASS — U-1 は別 issue の候補として分離

## HO 非該当の確認

変更ファイル `scripts/retro_seed_draft.py` / `tests/extras/ta-118-retro-seed-draft.sh` / `docs/workflows/06_retro.md` と、
本計画ファイル（`docs/working/TASK-1544/`）は、`mode-classification.md` の HO 12 カテゴリのいずれにも該当しない。

## 自動修正ログ

なし

## 簡易 C-1 再実行（R-NNN 反映後 / 2026-11-13）

> 対象: review-external.md R-001〜R-009 を反映した pbi-input.md / plan-draft.md / todo.md / test-cases.md。Plan 項目（C1-PLAN-01〜07）+ TC 紐付けのみ。

**判定: PASS（WARN 1 件）**

- C1-PLAN-01 受入基準網羅性: PASS — AC-1〜6 を test-cases.md マッピングで全件 TC に対応（AC-6 は TC-19）
- C1-PLAN-02 Unknowns処理: PASS — U-1 は R-007（plan.md 側の opt-in + plan_hash 照合）で解消。前回の WARN を解除
- C1-PLAN-03 スコープ制御: PASS — 変更ファイルは 3 件のまま。L2 は import のみで `improvement_seed_delta.py` は変更しない
- C1-PLAN-04 テスト戦略: PASS — 変異 M-1〜M-6・M-2b、TC-11 は `read_declared_seeds` 直呼びで +1 を assert（素通り解消）
- C1-PLAN-05 Work Breakdown Output: PASS — T-0（plan.md 移行）と T-3b（docstring）を追加
- C1-PLAN-06 依存関係: PASS — H-1 は T-0 の後
- C1-PLAN-07 動作検証自動化: PASS
- **WARN**: Mode が受入基準数 6 により standard → high-risk に上がった（安全側）。high-risk のため V-2 実行・C-3 は人間必須。C-3 で確認を求める
- AC の変更は厳格化のみ（AC-1/3/4 に条件追加、AC-6 新設、緩めた AC なし）

## 簡易 C-1 再実行（C-2 敵対レビュー R1 / R-010〜R-017 反映後 / 2026-11-13）

> 対象: review-external.md R-010〜R-017 を反映した pbi-input.md / plan-draft.md / todo.md / test-cases.md。Plan 項目（C1-PLAN-01〜07）+ TC 紐付けのみ。

**判定: PASS（WARN 1 件）**

- C1-PLAN-01 受入基準網羅性: PASS — 追加条件（AC-1 の task_id・インデント・閉じない fence・本番 seeds 宛て、AC-3 の exit 4/6 分離、AC-4 の末尾改行・exit 6/7、AC-5 の完全一致照合、AC-6 の正規化）を TC-E01 / E02d / E02e / TC-19b / 19c / TC-20 / TC-21 に対応づけた
- C1-PLAN-02 Unknowns処理: PASS — R-013 / R-015 の前提を実測（c3.json 91 件中 `task_id` あり 90 件・欠落は TASK-0038 のみ → fail-closed exit 3 と明記。現行 seeds は L2 を通る 7 件）
- C1-PLAN-03 スコープ制御: PASS — 変更ファイルは 3 件のまま。HO パスなし
- C1-PLAN-04 テスト戦略: PASS — M-2 / M-2b の FAIL 欄を exit コード分離後の実挙動に合わせた。M-6b / M-7 を追加。TC-21 (e) を陽性対照として置いた
- C1-PLAN-05 Work Breakdown Output: PASS — Task 2 の Steps と T-3 / T-3b / T-5 を更新
- C1-PLAN-06 依存関係: PASS — 変更なし
- C1-PLAN-07 動作検証自動化: PASS — 追加 TC はすべて TA-118 で自動実行（TC-20 (c) は python から関数を import して差し込む）
- **WARN**: 本番 seeds 宛ての append はゲート 5 で c3.json の git 追跡を要求するため、worktree で approve した未追跡の c3.json では追記できない（安全側。運用への影響は C-3 で確認を求める）
- AC の変更は厳格化のみ（AC-1 / 3 / 4 / 5 / 6 に条件追加、緩めた AC なし）
- high-risk のため C-2 R2 を実施する（未実施）

## 簡易 C-1 再実行（C-2 敵対レビュー R2 / R-018〜R-023 と判定 2 原則の反映後 / 2026-11-13）

> 対象: review-external.md R-018〜R-023 を反映した pbi-input.md / plan-draft.md / todo.md / test-cases.md。Plan 項目（C1-PLAN-01〜07）+ TC 紐付けのみ。

**判定: PASS（WARN 1 件）**

- C1-PLAN-01 受入基準網羅性: PASS — AC-1 の追加条件（commit 済み blob での判定・`samefile`）を TC-21 (e)〜(i)、AC-4 の追加条件（symlink・mode・exit 8）を TC-20 (d)〜(g) に対応づけた
- C1-PLAN-02 Unknowns処理: PASS — 新しい Unknown なし。発行者・commit 作成者の検証は残存脅威に明記
- C1-PLAN-03 スコープ制御: PASS — 変更ファイルは 3 件のまま。HO パスなし
- C1-PLAN-04 テスト戦略: PASS — M-8〜M-11 を追加。R1 の TC-21 (e)（`git add` で exit 0）は是正後の挙動に合わせて commit 済みの陽性対照に改め、staged のみは (g) で exit 3 とした
- C1-PLAN-05 Work Breakdown Output: PASS — Task 2 の Steps と T-3 / T-3b / T-5 を更新
- C1-PLAN-06 依存関係: PASS — 変更なし
- C1-PLAN-07 動作検証自動化: PASS — TC-21 (h) は macOS 限定で、区別する FS では SKIP を明示出力する
- 判定の 2 原則: plan-draft.md の表で全判定箇所（ゲート 1〜5・`--out`・`--seeds`・`--draft`・task-dir の位置）に原則を割り当て、適用しない箇所は理由を記載
- **WARN**: 本番 seeds への append は c3.json 等の commit 後に限られる（運用手順を plan に明記。一時コピー経路を正規手段として明記）。C-3 で運用への影響の確認を求める
- AC の変更は厳格化のみ（AC-1 / AC-4 に条件追加、緩めた AC なし）
- high-risk・未収束のため C-2 R3 を実施する（未実施）

## 簡易 C-1 再実行（C-2 敵対レビュー R3 / R-024〜R-026・TC-21 (f) 厳格化の反映後 / 2026-11-13）

> 対象: review-external.md R-024〜R-026 を反映した pbi-input.md / plan-draft.md / test-cases.md。Plan 項目（C1-PLAN-01〜07）+ TC 紐付けのみ。

**判定: PASS（WARN 1 件）**

- C1-PLAN-01 受入基準網羅性: PASS — AC-1 の追加条件（作業ツリーと `HEAD` の blob の一致・git を使わない本番宛て判定・判定後の git 失敗で不成立）を TC-21 (f) / (f2) / (j) / (k) に対応づけた
- C1-PLAN-02 Unknowns処理: PASS — plan-draft.md:94 と TC-21 (i) の食い違いを解消（本番宛ては root との `samefile` で決まり、git の成否に依存しない）
- C1-PLAN-03 スコープ制御: PASS — 変更ファイルは 3 件のまま。HO パスなし
- C1-PLAN-04 テスト戦略: PASS — M-8 の FAIL 欄を (f2) に改め、M-8b（blob 一致検査の除去）と M-12（git 依存の本番宛て判定）を追加
- C1-PLAN-05 Work Breakdown Output: PASS — Task 3 / Verification Plan の変異範囲を M-1〜M-12 に更新
- C1-PLAN-06 依存関係: PASS — 変更なし
- C1-PLAN-07 動作検証自動化: PASS — TC-21 の sandbox repo には生成器のコピーを置いて実行する前提を明記
- 判定の 2 原則: 表に 5 行（作業ツリーと HEAD の一致・下書きの task_id・exit 5 の重複・draft・exit 6/7/8）を追加
- **WARN**: 生成器をコピーして別の場所で実行すると本番宛てと判定されない（R-024 の帰結）。残存脅威モデルに明記し、PR と C-4 で担保する
- AC の変更は厳格化のみ（AC-1 に条件追加、緩めた AC なし）
- R4（是正箇所に絞って 1 ラウンド）を実施する（未実施）
