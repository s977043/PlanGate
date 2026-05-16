---
task_id: TASK-0069
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-16
author: qa-reviewer
v1_release: ""
---

# Handoff Package — TASK-0069: `plangate doctor --fix`

> WF-05 Verify & Handoff 出力。V-1 PASS 後 / C-4 ゲート前に発行。

## メタ情報

```yaml
task: TASK-0069
related_issue: "(導入初期環境構築の最終 1 マイル / 親 PBI #22 v7 ハイブリッド系)"
author: qa-reviewer
issued_at: 2026-05-16
v1_release: "<PR マージ後の merge commit SHA を記入> (base: 63c9914)"
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: doctor に `=== Hook Enforcement Wiring ===` + 未配線で `[FAIL] PlanGate hooks not wired` | PASS | TC-1 PASS。E2E で隔離ルート実行: セクション出力 + `[FAIL] ... (5/5 expected hook block(s) missing)` + exit 1 を実機確認 |
| AC-2: `--fix --dry-run` が一切書き換えない | PASS | TC-2 PASS。doctor_fix.py dry-run は no-write、bin/plangate 側も settings/EH-8/.gitignore/mkdir を全て `[PLAN]` 表示のみ。非tty+`--yes`無し abort（TC-E4）は exit 3 を実機確認 |
| AC-3: `--fix --yes` で配線 + 既存時のみ `.bak`、既存 `.bak` は `.bak.<epoch>` ローテート | PASS | TC-3a（新規=`.bak`なし）/ TC-3b（既存→新規`.bak`生成・旧`.bak`を`.bak.<epoch>`へ退避・内容保全）PASS |
| AC-4: 既存キー温存（merge-only） | PASS | TC-4 PASS。`permissions.allow` + 既存 `SessionStart` 独自 hook が温存、example hook が重複なく追加マージ |
| AC-5: 2 回連続実行で 2 回目 no-op（冪等） | PASS | TC-5 PASS。2 回目 `--apply` が first-run.json とバイト一致。冪等判定は serialize 後の文字列一致で実装 |
| AC-6: gh/codex 未導入は案内のみ（自動インストールしない） | PASS | TC-6 PASS。`PATH=/usr/bin:/bin` で gh/codex 非検出 → `[INFO] not installed` 案内のみ、`brew/apt install` 文字列なし、exit は他修復に従う |
| AC-7: `--json --scope hooks` で name/ok/level 出力、既存 `--json`（v8.6.0 default）バイト無改変 | PASS | TC-7 PASS。default==explicit v8.6.0 バイト一致。旧 doctor_check.py をリポジトリ内に配置して比較 → `--scope v8.6.0` 出力バイト完全一致を QA で再検証。hooks JSON に絶対パス/settings 内容/`${CLAUDE_PROJECT_DIR}` 漏洩なし |
| AC-8: doctor_fix.py 単体テスト PASS + 既存回帰なし | PASS | `sh tests/run-tests.sh` = 63 passed / 0 failed（既存 60 + TA-10 内 11 ケース、回帰 0）。`dash -n bin/plangate` PASS、`py_compile` PASS |

**総合**: 8/8 基準 PASS
**FAIL / WARN の扱い**: なし（全 PASS）。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| `checkbashisms` 未実行（macOS 開発機に devscripts 未導入）。POSIX sh 互換は `dash -n bin/plangate` PASS + 手動レビューで代替担保 | minor | accepted | No（CI で checkbashisms を実行する環境があれば自動充足） |
| `bin/plangate cmd_doctor` の `--fix` は plangate_root（=bin/plangate の親）を対象に固定。他リポジトリ導入先を対象にした `--project-dir` 相当は **doctor_fix.py 側のみ** 対応（CLI からは未公開）。導入先で使うには `python3 scripts/doctor_fix.py --project-dir <導入先> --apply` を直接叩く必要がある | major | accepted（設計範囲内: 本 PBI は「PlanGate リポ自身/clone 直下」を主対象） | Yes |
| `check-plan-hash.sh` hook の `PLANGATE_HOOK_TASK` が実装環境で未配線だったため implementer が Bash 経由のファイル編集を回避して作業した（環境課題。成果物コードには影響なし） | minor | workaround | No（環境セットアップ手順の課題、本成果物が解決対象とする一例でもある） |
| doctor_fix.py の atomic write は `.tmp` → `replace`。同一 `.claude/` への並行 `--apply` 同時実行時の競合は未保護（実運用では単発実行前提） | info | accepted | Maybe（並行実行は想定外ユースケース） |
| EH-8 を将来 `settings.example.json` の hook 配線正本へ含めるかは本 PBI で判断保留（Out of scope 明記済み） | info | accepted | Yes |

**Critical 課題の対応**: Critical 課題なし。リリース可。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| `bin/plangate doctor --fix --project-dir <DIR>`（他リポ導入先を CLI から直接修復） | 本 PBI は plangate リポ自身/clone 直下が主対象。多リポ運用は別ニーズ | Medium | （新規起票推奨） |
| 対話的オンボーディング skill（案 D `/setup-plangate`、`doctor --fix` の薄いラッパ） | UX 改善。本 PBI で基盤確立済みのため無駄にならない | Low | （Notes from Refinement 記載） |
| EH-8 を hook 配線正本（settings.example.json）へ含める設計判断 | presence 検査は v8.6.0 セクション責務。配線正本化は別設計 | Low | （新規起票推奨） |
| plugin 側 `plugin/plangate/hooks/` への hook 実体配置（配布戦略） | 配布戦略は別 PBI、本 PBI Out of scope | Medium | （新規起票推奨） |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| JSON マージを Python（標準ライブラリのみ）に隔離 | `jq` でのマージ | jq 非依存が確実。bin/plangate を薄く保つ（Rule: 複雑性を Python へ隔離） |
| 配線判定を `(event, matcher, type, command)` ブロック単位 | command 文字列のみの集合一致 | 別 event/matcher に同名 command があると誤 PASS するため。false positive ガード |
| 確認ゲート + 非tty `--yes`無し abort（exit 3） | 非tty で自動続行 | `set -eu` 下 `read` の EOF 誤動作回避 + 破壊操作の暗黙実行を禁止（PlanGate 思想: 強制力は決定論的・確認付き） |
| `--fix` 対象を plangate_root 固定 | CLI から任意 `--project-dir` | 本 PBI scope は導入最終 1 マイル（リポ自身/clone 直下）。多リポ対応は V2 へ |
| `tests/extras/ta-10-*.sh` を置くだけ（loader 自動 source） | `tests/run-tests.sh` 本体編集 | Issue #170 衝突回避規約。本体無編集を維持 |
| 案 A（`doctor --fix` 拡張） | 案 B（対話 skill） | 強制力を LLM 判断に委ねず決定論的 CLI に置く（hybrid-architecture: Hook はハード強制） |

## 5. 引き継ぎ文書

### 概要
`bin/plangate doctor` に hook 配線状態の検査セクション（`=== Hook Enforcement Wiring ===`）と決定論的修復 `--fix`（`--dry-run`/`--yes`/`--scope` 付き）を追加。JSON マージの安全性（merge-only / `.bak` ローテート / 冪等 / 不正 JSON abort / atomic write）は新規 `scripts/doctor_fix.py` に隔離。`scripts/doctor_check.py` は scope dispatch table 化し新 scope `hooks` を追加（`v8.6.0` 出力はバイト互換維持を QA 実機再検証済み）。AC-1〜AC-8 全 PASS、`sh tests/run-tests.sh` 63 passed / 0 failed、回帰なし。commit/PR 直前の状態。

### 触れないでほしいファイル
- `scripts/doctor_check.py` の `run_v860_checks()` / `V860_FILE_CHECKS` / 出力シリアライズ: AC-7 のバイト互換を支える。変更すると既存 CI 統合が壊れる
- `scripts/doctor_fix.py` の backup ローテート・冪等・atomic write 順序: AC-3/AC-5/TC-E1/TC-E3 を担保。順序変更は破壊リスク
- `tests/run-tests.sh` 本体: extras loader が `ta-*.sh` を自動 source（Issue #170 規約）。本体は編集しない

### 次に手を入れるなら
- 他リポ導入対応は `cmd_doctor` に `--project-dir` 透過を足し doctor_fix.py へ転送（V2 候補）。plangate_root 算出ロジックとの整合に注意
- checkbashisms を CI に組み込めば既知課題 1 が自動充足
- アンチパターン: settings.json を bin/plangate から直接書換しない（必ず doctor_fix.py 経由）。JSON マージを jq へ戻さない

### 参照リンク
- 親 PBI: #22（v7 ハイブリッドアーキテクチャ系）
- pbi-input: `docs/working/TASK-0069/pbi-input.md`
- plan: `docs/working/TASK-0069/plan.md`
- test-cases: `docs/working/TASK-0069/test-cases.md`
- status.md: `docs/working/TASK-0069/status.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit (TA-10: doctor_fix.py 直叩き / TC-2,3a,3b,4,5,E1,E2,E3) | 8 | 8 | 0 | AC-2〜AC-5, TC-E1〜E3 網羅 |
| Integration (TA-10: bin/plangate 経由 / TC-1,6,7) | 3 | 3 | 0 | AC-1,6,7 網羅 |
| 既存スイート全体（tests/run-tests.sh） | 63 | 63 | 0 | 回帰 0（既存 60 + 新規 3 群） |
| E2E（隔離ルート: 未配線 FAIL → `--fix --yes` → 再 doctor PASS） | 1 | 1 | 0 | 配線一巡を実機確認 |
| 静的検査 | 3 | 3 | 0 | `dash -n bin/plangate` / `py_compile` / `markdownlint`（report 上） |

**FAIL / SKIP の詳細**: なし。`checkbashisms` のみ環境未導入により未実行（既知課題 1、`dash -n` + 手動レビューで代替）。TC-E4（非tty abort, exit 3）は QA E2E で実機確認済み。

## 7. Metrics summary

該当なし（本 PBI で metrics 収集は opt-in 未実施）。

---

備考: AC-7 のバイト互換について、`/tmp` へ旧 `doctor_check.py` をコピーして実行すると `__file__` ベースの REPO 解決が `/tmp` を指し runtime 値（ok/detail）が変わる見かけ上の差分が出るが、旧スクリプトをリポジトリ内に配置して同一 cwd で比較すると `--scope v8.6.0` 出力はバイト完全一致。構造（キー名/順序/インデント/配列形状）も無改変。
