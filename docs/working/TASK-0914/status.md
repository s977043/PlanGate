# TASK-0914 作業ステータス

> 最終更新: 2026-08-02 12:50
> 現在フェーズ: exec
> モード: high-risk

## フェーズ履歴

> **日時は `YYYY-MM-DD HH:mm`（分まで）必須**（#463）。日付のみ・時刻欠落は不可。

| 日時 (YYYY-MM-DD HH:mm) | フェーズ | 結果 / メモ |
|------------------------|---------|------------|
| 2026-07-25 08:30 | A: PBI INPUT | 作成完了（PR #918 で main 実在） |
| 2026-07-25 11:20 | B: plan 生成 | plan/todo/test-cases 生成（C-2 major 7 + River major 4 反映済・C-1 PASS） |
| 2026-08-02 12:40 | C-3 Gate | APPROVED（`approvals/c3.json`・plan_hash 検証済み — オーガナイザー確認） |
| 2026-08-02 12:44 | D: exec 開始 | ブランチ `fix/914-mass-delete-guard` を origin/main `f25ae8b` から作成 |
| 2026-08-02 12:46 | T-01 完了 | baseline 実測（下表）+ 失敗表記統一確認 + AC-7 検出力証明（NG_TOTAL=8） |

## 全体構成（PR 一覧）

| PR | ブランチ | 状態 |
|----|---------|------|
| （未作成） | fix/914-mass-delete-guard | ローカル（exec 中） |

## T-01: AC-6 baseline 実測（R-301 / U-4）

実測条件: clean env（`env -u PLANGATE_HOOK_TASK -u PLANGATE_HOOK_FILE -u PG_HARNESS_SOURCED -u FIXTURES_DIR -u PLANGATE_ALLOW_MASS_DELETE`）+ `sh "$f" </dev/null`、cwd = repo root。
実測日時: 2026-08-02 12:45 / head `f25ae8b` / evidence: `evidence/test-runs/t01-baseline-clean.log`

| ファイル | `[PASS]` 件数 (baseline) | rc | `[FAIL]` 行 |
|---------|------------------------|----|------------|
| ta-39-eh3-doc-light.sh | **8** | 0 | 0 |
| ta-43-eh2-strict-json.sh | **6** | 0 | 0 |
| ta-44-eh457-cli-wiring.sh | **5** | 0 | 0 |
| ta-45-c3-mode-config.sh | **6** | 0 | 0 |
| ta-46-ehs-wiring.sh | **4** | 0 | 0 |
| ta-47-ehs23-wiring.sh | **6** | 0 | 0 |
| ta-49-bias-export.sh | **6** | 0 | 0 |
| ta-50-precompact-guard.sh | **9** | 0 | 0 |
| ta-51-doctor-w6.sh | **5** | 0 | 0 |
| ta-52-doctor-skill-collision.sh | **5** | 0 | 0 |
| ta-53-doctor-prepush.sh | **4** | 0 | 0 |
| **計** | **64** | — | — |

- 参考値（River Review 実測 `ta-39=8 ta-43=6 ta-44=5 ta-45=6 ta-46=4 ta-47=6 ta-49=6 ta-50=9 ta-51=5 ta-52=5 ta-53=4` 計 64）と**全件一致**
- **失敗表記の統一（U-4）**: 11 本すべて source 内の失敗マーカーは `[FAIL]`（grep 実測: 各 1〜6 箇所）。`[NG]` / `not ok` / `[ERROR]` 等の別表記は **0 件**（grep rc=1）→ AC-6 条件①の判定語彙拡張は**不要**
- **AC-7 検出力証明（R-302 / RV-M2）**: 移行前に V-1-B 型汚染 env（`PLANGATE_SKIP_REASON/HOOK_TASK/HOOK_FILE/BYPASS_HOOK/HOOK_STRICT/ALLOW_MASS_DELETE` + `FIXTURES_DIR=/nonexistent/fixtures`。`PG_HARNESS_SOURCED` は注入しない）で 11 本実行 → **NG_TOTAL=8**（ta-45/46/47/49/50/51/52/53 が `[FAIL]` を出力）。さらに ta-39/43/44 は `[PASS]`=0（baseline 8/6/5 から消失 = 1 件も実行せず素通り）となり、条件③（件数一致）の検出対象。evidence: `evidence/test-runs/t01-ac7-contaminated-pre.log`
- 全ファイル rc=0 のまま `[FAIL]` が出る = exit code 伝播欠落（AC-8 別 issue の根拠）も同時に再確認

## 残タスク

- [x] T-01: baseline 実測（2026-08-02 12:46 完了）
- [ ] T-02: `_mass_delete_blocked()` 導入 + `sync_dir` guard 置換 🚩
- [ ] T-03: 経路2（ai-loop references）guard 適用 🚩
- [ ] T-04: 経路1（汎用 references）guard 適用 🚩
- [ ] T-05a/b/c: TC 追加（別ワーカー担当）
- [ ] T-06: 変異注入（別ワーカー担当）
- [ ] T-07: extras 11 本判別式統一 + unset（別ワーカー担当）
- [ ] T-08: README 規約追記（別ワーカー担当）
- [ ] T-09: AC-6/7/9 機械検証（別ワーカー担当）
- [ ] T-10: 別 issue 起票 + handoff 妥協点（別ワーカー担当）
- [ ] T-11: 回帰フルテスト（別ワーカー担当）

## 計画からの変更点

- **exec 基点が main `f25ae8b`**（plan 基点 `90c313d` から前進）。`scripts/sync-plugin-plangate.sh` の 90c313d→f25ae8b 差分は **L342 以降（scripts allowlist 節 = 本 PBI Non-goal 領域）のコメント3+2行と集合拡張のみ**で、本 PBI の対象 3 領域（sync_dir guard L103-113 / 経路1 L173-183 / 経路2 L316-329）は**行番号・内容とも 90c313d と同一**（`git diff 90c313d f25ae8b -- scripts/sync-plugin-plangate.sh` で実測）。plan の行番号参照はそのまま有効
- **`tests/extras/ta-57-pr-convergence.sh` が新設**（#941）・ta-56 に 1 行変更 → `sh tests/run-tests.sh` の総数 baseline は plan 記載の 430 から増えているはず。T-11 実施時に現 main 基点で再実測して「+新規 14 TC」の期待値を再計算する必要あり（RT-6 の 444 固定値は 90c313d 基点の値）
- 変異注入の復元元 `git show 90c313d:scripts/sync-plugin-plangate.sh`（RV-i1）は、対象 3 領域が同一なため引き続き有効（allowlist 節の差分は変異対象外）

## V 系ステップ進捗

| ステップ | 結果 |
|---------|------|
| L-0 | — |
| V-1 | — |
| V-2 | — |
| V-3 | — |
| V-4 | — |

## 次の作業（Claude Code プロンプト）

TASK-0914 exec 続行。T-02（`_mass_delete_blocked()` 共通関数導入 + sync_dir guard L103-113 置換）→ T-03（経路2 L316-329）→ T-04（経路1 L173-183）を todo.md の指示どおり直列実施。チェックポイントは `sh -n` + ta-26 既存 16 TC 全 PASS（T-02）、sandbox 手動再現ログの evidence 保存（T-03/T-04）。
