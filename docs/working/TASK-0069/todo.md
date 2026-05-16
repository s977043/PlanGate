# TASK-0069 EXECUTION TODO

> 生成日: 2026-05-15

## 🤖 Agent タスク

### 準備フェーズ
- [x] 🚩 T-1: Scope/受入基準を再掲し作業範囲を固定（settings.json 破壊禁止・sh 互換を明記） [Owner: agent] [depends_on: -] [files: -]
- [x] 🚩 T-2: `settings.example.json` の hook command 集合を抽出し「期待集合」仕様を確定 [Owner: agent] [depends_on: T-1] [files: -]

### 実装フェーズ（TDD: RED → GREEN → REFACTOR）
- [x] 🚩 T-3: `tests/extras/ta-10-doctor-fix.sh` に TC-2〜TC-5,TC-E1〜E3 を記述（一時 dir 隔離） [Owner: agent] [depends_on: T-2] [files: tests/extras/ta-10-doctor-fix.sh]
- [x] 🚩 T-4: テスト実行し FAIL 確認（doctor_fix.py 未実装のため） [Owner: agent] [depends_on: T-3] [files: -]
- [x] 🚩 T-5: `scripts/doctor_fix.py` 実装（--check / --apply merge-only+backup / --dry-run、json 標準ライブラリのみ） [Owner: agent] [depends_on: T-4] [files: scripts/doctor_fix.py]
- [x] 🚩 T-6: テスト実行し doctor_fix.py 系 PASS 確認 [Owner: agent] [depends_on: T-5] [files: -]
- [x] 🚩 T-6.5: `doctor_check.py` の scope 体系拡張方針を確定（`hooks` scope 追加、`scope != v8.6.0` error 分岐改修、v8.6.0 出力バイト互換を固定） [Owner: agent] [depends_on: T-2] [files: -]
- [x] 🚩 T-7: `bin/plangate` cmd_doctor に `=== Hook Enforcement Wiring ===` 検査追加（読み取り、非tty+--yes無し→abort 仕様含む） [Owner: agent] [depends_on: T-2] [files: bin/plangate]
- [x] 🚩 T-8: `bin/plangate` cmd_doctor に `--fix/--dry-run/--yes` 分岐 + 確認プロンプト（非tty abort）+ chmod/.gitignore/mkdir 修復 + usage 更新 [Owner: agent] [depends_on: T-7, T-6] [files: bin/plangate]
- [x] 🚩 T-9: `scripts/doctor_check.py` に scope `hooks` 追加（hook-wiring を name/ok/level で出力、presence のみ、v8.6.0 出力無改変） [Owner: agent] [depends_on: T-6.5, T-7] [files: scripts/doctor_check.py]
- [x] 🚩 T-10: `tests/extras/ta-10-doctor-fix.sh` を配置（run-tests.sh 本体は編集しない=自動 loader）。TC-1/TC-6/TC-7 も同ファイル内に Integration として記述 [Owner: agent] [depends_on: T-8, T-9] [files: tests/extras/ta-10-doctor-fix.sh]
- [x] 🚩 T-11: `README.md` インストール節 + `TROUBLESHOOTING.md` に `doctor --fix` 追記 [Owner: agent] [depends_on: T-8] [files: README.md, TROUBLESHOOTING.md]

### セルフレビュー①
- [x] 🚩 T-12: /self-review 実行（ロジック正確性・settings 破壊リスク・残骸・エッジケース） [Owner: agent] [depends_on: T-11] [files: -]

### 検証フェーズ
- [x] 🚩 T-13: `dash -n bin/plangate` + `checkbashisms bin/plangate` + `markdownlint` + `sh tests/run-tests.sh` 実行 [Owner: agent] [depends_on: T-12] [files: -]
- [x] 🚩 T-14: 受入基準 AC-1〜AC-8 を全件突合 [Owner: agent] [depends_on: T-13] [files: -]

### E2E検証
- [x] 🚩 T-15: `mktemp -d` でクリーン環境を作り `doctor → doctor --fix --yes → doctor` が PASS まで通ることを確認 [Owner: agent] [depends_on: T-14] [files: -]

### セルフレビュー②
- [x] 🚩 T-16: /self-review 実行（CI 互換性・コミット衛生・テスト網羅性） [Owner: agent] [depends_on: T-15] [files: -]

### orchestratorレビュー
- [x] 🚩 T-17: orchestrator エージェントで複数視点コードレビュー [Owner: agent] [depends_on: T-16] [files: -]

### 完了フェーズ
- [x] 🚩 T-18: コミット作成 [Owner: agent] [depends_on: T-17] [files: -]
- [x] 🚩 T-19: PR 作成 [Owner: agent] [depends_on: T-18] [files: -]
- [x] 🚩 T-20: status.md / handoff.md 最終更新 [Owner: agent] [depends_on: T-19] [files: status.md, handoff.md]

## 👤 Human タスク
- [ ] C-3: Plan/ToDo/Test Cases の人間レビュー（exec 前ゲート） [Owner: human]
- [ ] C-4: PR レビュー・承認 [Owner: human]

## ⚠️ 依存関係
- Agent 実装 → Human C-3 レビュー承認後に exec 開始
- PR 作成 → Human C-4 レビュー承認後にマージ
