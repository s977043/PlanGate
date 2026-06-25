---
task_id: TASK-0144
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-06-26
author: qa-reviewer
v1_release: "1f645be (main)"
---

# Handoff Package — TASK-0144

## メタ情報

```yaml
task: TASK-0144
related_issue: https://github.com/s977043/plangate/issues/626
author: qa-reviewer
issued_at: 2026-06-26
v1_release: "1f645be (main, PR#632 マージコミット)"
```

## 1. 要件適合確認結果

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-01: `.plangate.yml` に `c3_approval: {mode: conversation}` → EH-3 が c3.json SKIP → `bin/plangate exec` 通過 | PASS | `check-plan-hash.sh` L143-174 に conversation モード経路（`^docs/working/TASK-[0-9]+/approvals/c3\.json$` マッチ → exit 0）が実装。ta-45 TC-01 が apply 後 PASS（テスト結果: 349 passed / 0 failed）|
| AC-02: `c3_approval: {mode: cli}` またはファイル未存在 → 現行動作維持 | PASS | デフォルト `cli`、`.plangate.yml` 未存在時は `_read_plangate_config()` が `cli` にフォールバック。ta-45 TC-02/TC-03 が PASS |
| AC-03: 生成された c3.json に `source: conversation` フィールド | PASS | `schemas/c3-approval.schema.json` L54-58 に `source: {enum: ["cli", "conversation"]}` が optional フィールドとして追加。`bin/plangate approve` が `source: "cli"` を付与（PR#631 実装済み）|
| AC-04: `bin/plangate doctor` が現在の承認モードを出力 | PASS | `bin/plangate` L606-611 に `=== C-3 Approval Mode ===` セクション追加。`.plangate.yml` 存在時は `c3_approval.mode=<値>` を表示、未存在時は `default: c3_approval.mode=cli` を表示。ta-45 TC-05 が PASS |
| AC-05: `schemas/plangate-config.schema.json` が `c3_approval.mode` を enum 検証 | PASS | `schemas/plangate-config.schema.json` 新規作成済み。`c3_approval.mode` を `enum: ["cli", "conversation"]` で検証。ta-45 TC-06 が PASS（有効値 PASS / 無効値 FAIL を確認）|
| AC-06: 既存テスト 0 FAIL | PASS | 349 passed / 0 failed（PR#632 マージ後確認済み）|

**総合**: 6/6 基準 PASS

## 2. 既知課題一覧

| 課題 | Severity | 状態 | V2 候補か |
|------|---------|------|---------|
| conversation モードの HMAC 署名・セッション検証が未実装 | major | accepted（Out of scope 明記済み） | Yes（issue #420 後続 PBI）|
| EH-3 provenance 検証（発行元が本当に人間か）が機械的に保証されない | major | accepted（issue #420 で追跡中）| Yes |
| `_approver_identity_unverified: true` — c3.json の `approved_by` が git-config 由来で暗号署名なし | major | accepted（既存制約・TASK-0128 以来の既知）| Yes（issue #420）|
| `.plangate.yml` の PyYAML 未インストール時に WARN 止まり（exec を止めない）| minor | accepted（fail-open 設計で安全側フォールバック。doctor で可視化）| No |
| c3.json スキーマの `source` フィールドが optional のため、source なし c3.json も valid | minor | accepted（後方互換維持の設計判断。既存 c3.json を破壊しない）| No |

**Critical 課題**: なし（V1 リリース可）

## 3. V2 候補

| V2 候補 | 理由 | 推定優先度 | 関連 Issue |
|--------|------|----------|-----------|
| EH-3 provenance 完全検証（HMAC + セッション系譜） | 設計複雑度が大きく、本 PBI スコープ外として Out of scope 明記 | Medium | #420 |
| conversation モードの HMAC 署名・セッション検証 | 「人間 APPROVE 発話 → AI が c3.json 生成」の経路で AI 自己承認リスクが残る。署名による技術的保証が必要 | Medium | #420 |
| `.plangate.yml` の他設定項目サポート（例: exec_timeout, log_level）| 本 PBI は `c3_approval` のみスコープ | Low | — |
| GUI / Web UI 承認フロー | 本 PBI スコープ外 | Low | — |
| `bin/plangate approve` での conversation モード c3.json 生成を `cmd_approve` に組み込む | 現行は会話内 AI 直接 Write。cmd_approve 統合でロジックを一箇所に集約できる | Low | — |

## 4. 妥協点

| 選択した実装 | 諦めた代替案 | 理由 |
|------------|-----------|------|
| `cmd_exec` は変更しない（R-001/R-002 反映） | cmd_exec 内で c3.json を自動生成（当初案） | C-3 ゲートの自己充足を防ぐ。「exec が承認を確認する」から「exec が承認を作る」への変質を避けるため Codex critical 指摘に従い再設計 |
| EH-3 SKIP は「通す」役割のみ（R-003 反映）、中身検証は EH-2 と AI 生成コードに委ねる | EH-3 で schema / plan_hash / source を検証する | EH-3 は write ポリシー制御のみとし、内容検証を exec 時 EH-2 に一元化。責務分離が明確になる |
| `source` フィールドを optional として schema 追加（R-004 反映） | additionalProperties: false を前提に source なし c3.json を FAIL 扱い | 既存 c3.json との後方互換維持が必須。旧 c3.json（source なし）も引き続き valid |
| `.plangate.yml` 不正値は fail-open（cli フォールバック）+ stderr WARN（R-005 反映） | 不正値で fail-closed（exec を止める） | ユーザーへの可視化（doctor WARN）を優先しつつ、既存動作を維持。完全 fail-closed は doctor チェック義務化が整備されてから検討 |
| apply-script 経由の HO パス適用（`scripts/_apply_task_0144_patches.py`） | AI が bin/plangate / hook / schema を直接編集 | HO（Hardening Override）対象パスの AI 自己改変は禁止（settings-wiring-contract）。Human が apply-script を実行することで Shadow Config を防ぐ |

## 5. 引き継ぎ文書

### 概要

TASK-0144 は、C-3 承認を CLI（`bin/plangate approve`）と会話内 APPROVE（AI が exec 前に c3.json を生成）の 2 モードで切り替えるプロジェクト設定機能を実装した。`.plangate.yml` に `c3_approval: {mode: cli|conversation}` を記述することで動作が変わる。デフォルトは `cli`（後方互換）。

主要な実装変更は PR#631（非 HO 変更: `.plangate.yml` サンプル、`schemas/plangate-config.schema.json`、`tests/extras/ta-45-c3-mode-config.sh`、`docs/ai/settings-wiring-contract.md`）と PR#632（HO パス適用: `bin/plangate`、`schemas/c3-approval.schema.json`、`scripts/hooks/check-plan-hash.sh`）の 2 PR に分割されており、両方 main にマージ済み（main HEAD: 1f645be）。テストは 349 passed / 0 failed。

C-2 レビュー（Codex、R-001〜R-008）で critical 2 件を含む 8 件の指摘があり、plan を再設計後に exec した。特に「cmd_exec に c3.json 自動生成を入れるとゲート自己充足になる」という critical 指摘（R-001/R-002）を受けて、c3.json 生成を exec 前の独立したステップとし、cmd_exec は変更しない設計にした。

### 触れないでほしいファイル

- `scripts/hooks/check-plan-hash.sh`: EH-3 の conversation SKIP 経路（L143-174）は `.plangate.yml` mode 読み込みロジックと密結合。変更する場合は ta-45 TC-01/TC-03 を必ず通すこと
- `schemas/c3-approval.schema.json`: `source` フィールドを `required` に変更すると既存 c3.json（source なし）が schema FAIL になる。optional のまま維持すること
- `bin/plangate` の `_read_plangate_config()` 関数（L113-161): PyYAML fallback ロジックが複雑。変更する場合は python3 未インストール環境でも動作確認すること

### 次に手を入れるなら

- **issue #420（EH-3 provenance 完全検証）**: conversation モードで AI が生成した c3.json の発行元を機械的に保証する仕組み。HMAC + セッション系譜。本 PBI では暫定対応（`source: conversation` フィールド + 規範層のみ）で、技術層の保証は #420 で実装
- **`.plangate.yml` スキーマ検証の doctor 統合**: 現行 doctor は `c3_approval.mode` の値表示のみ。`.plangate.yml` が schema に適合するかの自動検証を doctor に組み込むと、不正設定を早期発見できる
- **conversation モード時の c3.json テンプレート提供**: AI が c3.json を生成するとき、plan_hash を自動算出して正しく埋め込むヘルパーコマンド（例: `bin/plangate conversation-approve TASK-XXXX`）があると誤生成を防げる

### 参照リンク

- 親 issue: https://github.com/s977043/plangate/issues/626
- PR#631: feat/task-0144-c3-mode（非 HO 変更）
- PR#632: feat/task-0144-ho-apply-result（HO パス適用）
- plan.md: `docs/working/TASK-0144/plan.md`
- pbi-input.md: `docs/working/TASK-0144/pbi-input.md`
- status.md: `docs/working/TASK-0144/status.md`
- 関連 PBI: TASK-0143（EH-4/5/7 CLI 配線）
- 設計正本: `docs/ai/settings-wiring-contract.md`

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP | カバレッジ |
|---------|------|------|-----------|----------|
| Unit（ta-45: TC-04/05/06）| 3 | 3 | 0 | AC-03/04/05 を直接カバー |
| Integration（ta-45: TC-01/02/03/07）| 4 | 4 | 0 | AC-01/02/06 をカバー |
| Regression（tests/run-tests.sh 全件）| 349 | 349 | 0 | 既存 TC 全件 0 FAIL |

**FAIL / SKIP の詳細**: なし。ta-45 は apply-script 適用前（PR#631 のみ）は TC-01〜04 が SKIP（apply 未完）となるが、PR#632 マージ後（HO 適用済み）は全 TC PASS に移行。

**外部レビュー（C-2）**:
- Codex レビュー: R-001(critical)/R-002(critical)/R-003(major)/R-004(major)/R-005(major)/R-006(major) → 全て plan 再設計・test-cases 更新で反映済み
- Codex R-007(minor)/R-008(minor) → plan.md / test-cases.md の記載修正で反映済み
- Gemini レビュー: C-2 段階では `IneligibleTierError` で実行不可（WARN）。実装後 Gemini レビュー（PR#632）で high（tr エスケープ）/ medium（2>/dev/null）指摘が検出され対応済み

## 7. Metrics summary（opt-in）

該当なし（metrics 収集未実施）
