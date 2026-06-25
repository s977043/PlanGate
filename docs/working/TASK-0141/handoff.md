---
task_id: TASK-0141
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-06-26
author: qa-reviewer
v1_release: "5135ceb (PR#630)"
---

# Handoff Package — TASK-0141

## メタ情報

```yaml
task: TASK-0141
related_issue: https://github.com/s977043/plangate/issues/500
author: qa-reviewer
issued_at: 2026-06-26
v1_release: 5135ceb (PR#630 マージコミット / main ブランチ)
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1: EH-2 の c3_status が python3 strict JSON 解析 | PASS | `check-c3-approval.sh` L125〜 に `python3 json.load` 実装。壊れた JSON / 非 object / フィールド欠落 → 2>/dev/null で空文字 → 非 APPROVED 扱い（fail-safe）。EH-3 と対称化済み |
| AC-2: EH-1/EH-2 が stdin `tool_input.file_path` から TASK-ID 解決 | PASS | `check-c3-approval.sh` L59〜95、`check-plan-exists.sh` L62〜98 に stdin fallback 実装。優先順: env `PLANGATE_HOOK_TASK` → arg → stdin JSON 解析（jq → python3 → grep の 3 段フォールバック）。`cat 2>/dev/null || true` によるハング防止済み |
| AC-3: ta-06 が hook テスト結果を PASS/FAIL として報告 | PASS | `tests/extras/ta-06-hooks.sh` から `>/dev/null 2>&1` を除去。run-tests.sh が hook テスト結果を PASS/FAIL として認識可能 |
| AC-4: ta-43 が壊れた JSON・コメント埋め込み・正常 JSON の 3 ケースを検証 | PASS | `tests/extras/ta-43-eh2-strict-json.sh` 新規作成。TC-01〜TC-06 の 6 ケース（正常 APPROVED・壊れた JSON・コメント埋め込み・フィールドなし・stdin 解決・stdin なし+env なし）を自動テスト化。サンドボックス構成（tmp に hook コピー）で実環境汚染なし |
| AC-5: 全テスト（run-tests.sh）が 300+ PASS、FAIL=0 | PASS | 実測: 349 PASS, 0 FAIL（`sh tests/run-tests.sh`、PR#630 マージ後） |

**総合**: 5/5 基準 PASS

**FAIL / WARN の扱い**: 全 AC が PASS のため V1 リリースにブロッカーなし。C-1 での軽微 WARN（W-01: stdin TC-05 は apply 後のみ完全検証可能、W-02: ta-06 unsilence による既存失敗露出）は意図的であり許容済み。

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| EH-3 stdin fallback 未対応（EH-2/EH-1 のみ対応） | minor | accepted（EH-3 は plan_hash 検証のため別設計が必要） | Yes |
| jq 非インストール環境での python3 フォールバック依存 | minor | workaround（python3 → grep の多段フォールバックで対応済み） | No |
| maintenance.json の発行元検証（EH-3 provenance）| major | open（issue #420 で追跡中。本 TASK 対象外） | Yes |
| EH-4/5/7 配線・EHS-1/2/3 発火条件の未整備 | minor | open（Out of scope として別 TASK に分離済み） | Yes |
| ta-06 unsilence により既存フック系テスト失敗が露出する可能性 | minor | accepted（意図的露出。個別フック修正は別 TASK） | Yes |

**Critical 課題の対応**: Critical open 課題なし。リリースに支障なし。

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue（あれば） |
|--------|------|----------|-----------------|
| EH-3 stdin fallback 追加 | check-plan-hash.sh は python3 strict JSON 化済みだが stdin fallback 未実装。EH-1/EH-2 と対称化 | Medium | #500 |
| maintenance.json 発行元検証（EH-3 provenance hardening） | HMAC / プロセス系譜 / CI 検証による EH-3 強化。#420 で設計中 | High | #420 |
| EH-4/EH-5/EH-7 hook 配線 | settings wiring 整合性の残課題（doctor --check-settings との連携含む）| Medium | #500 |
| EHS-1/2/3 発火条件整備 | shell script 系 hook の発火精度向上 | Low | — |
| settings-wiring-contract / doctor --check-settings 更新 | AC-1,2 of #500 に該当。本 TASK の Out of scope として分離済み | Medium | #500 |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| stdin 解析を jq → python3 → grep の 3 段フォールバックで実装 | jq 単一依存（jq が必須 requirement） | CI 環境・ローカル環境ともに jq が未インストールのケースがあるため。python3 は既存 hooks で使用中で安全。grep は最終手段として string パターンで抽出 |
| python3 エラー時は空文字（= 非 APPROVED）を fail-safe として採用 | python3 エラー時はブロック（exit 1） | 承認の false-negative（通るべき承認を弾く）よりも false-positive（不正 JSON を通過させる）を防ぐ方が重要。既存 EH-3 の実装と同方針 |
| ta-43 で apply-script の patch を hooks コピーに当てるサンドボックス方式 | 実環境 hooks を直接テスト | HO 対象パスのため AI は直接編集不可。apply-script を --dry-run 等せず、コピーに当てる方式で実 audit ログ汚染なし（ta-39 パターン踏襲） |
| stdin ハング対策として `cat 2>/dev/null \|\| true` を採用 | read タイムアウト付き実装 | bash 環境により timeout 挙動が異なる。`cat 2>/dev/null \|\| true` はシンプルかつ実績あり。EH-3 stdinハング知見（2026-06-10）を踏まえた選択 |

## 5. 引き継ぎ文書

### 概要

TASK-0141 は EPIC #527 の最終 open child（issue #500「承認境界の強制実態ギャップ是正」の最優先サブセット）として実施された。EH-2（check-c3-approval.sh）が grep/sed による c3_status 抽出を使っており、細工された c3.json で承認判定が誤通過するリスクを修正した。また EH-1/EH-2 が `PLANGATE_HOOK_TASK` 未設定時に無条件 SKIP していた問題を、stdin `tool_input.file_path` からの TASK-ID 解決 fallback で解消した。

PR#613（plan）と PR#630（feat/task-0141-500-exec）が main にマージ済み。HO 対象ファイル（check-c3-approval.sh / check-plan-exists.sh）は `scripts/apply-task-0141-eh2-strict.sh` により Human が適用済み。テスト結果は 349 PASS / 0 FAIL で全 AC を充足している。

### 触れないでほしいファイル

- `scripts/hooks/check-c3-approval.sh`: EH-2 承認境界の中核。変更時は Hardening Override 対象のため `scripts/apply-task-0141-eh2-strict.sh` のようなパターンで apply-script を別途作成し Human 適用が必要
- `scripts/hooks/check-plan-exists.sh`: EH-1 の中核。同上
- `tests/extras/ta-43-eh2-strict-json.sh`: EH-2 strict JSON の回帰テスト。壊れた JSON テストのサンドボックス構成を維持すること（hooks コピーへの apply-script パッチ）

### 次に手を入れるなら

- EH-3（check-plan-hash.sh）への stdin fallback 追加（V2 候補、本 TASK と同型の実装）
- issue #420 の EH-3 provenance hardening（HMAC / プロセス系譜）実装
- ta-06 unsilence で露出した既存フック系テスト失敗の個別修正
- settings-wiring-contract / doctor --check-settings の更新（issue #500 の残 AC-1,2）
- 新規 apply-script を作成する際は `scripts/apply-task-0141-eh2-strict.sh` を参照パターンとして活用できる（HO パス パッチ、dry-run 対応、ロールバック手順を含む）

### 参照リンク

- 親 EPIC: https://github.com/s977043/plangate/issues/527
- 関連 Issue: https://github.com/s977043/plangate/issues/500
- PR#613 (plan): https://github.com/s977043/plangate/pull/613
- PR#630 (exec): https://github.com/s977043/plangate/pull/630
- pbi-input.md: `docs/working/TASK-0141/pbi-input.md`
- plan.md: `docs/working/TASK-0141/plan.md`
- status.md: `docs/working/TASK-0141/status.md`
- EH-3 stdinハング知見: `docs/working/` 2026-06-10 audit session memory

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit (ta-43: EH-2 strict JSON + stdin fallback) | 6 | 6 | 0 | TC-01〜06 全網羅 |
| Integration (run-tests.sh 全体) | 349 | 349 | 0 | — |
| E2E | — | — | — | — |

**FAIL / SKIP の詳細**: FAIL=0、SKIP なし。C-1 W-01（TC-05 の stdin fallback は apply 後のみ完全検証可能）は ta-43 のサンドボックスでシミュレートしているため実質カバー済み。

**実行コマンド**: `sh tests/run-tests.sh`（PR#630 マージ後 main で実測）

## 7. Metrics summary

該当なし（metrics --collect 未実施）
