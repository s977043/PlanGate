# EXECUTION PLAN: TASK-0128

`plangate approve` — 人間ワンアクションで C-3 承認（c3.json 自動生成）

> rev.2: C-2(codex gpt-5.5) 指摘 R-001..R-008 を確定反映。Mode を critical へ引き上げ。

## Goal

人間の「承認判断」だけで C-3 を確定し、c3.json の発行作業（JSON 手書き・plan_hash 算出）を不要にする `bin/plangate approve` を導入する。provenance は `maintenance` と同じ Human-presence 多層防御で担保し、AI の自己承認を物理的に封じる。

## Constraints / Non-goals

- **Constraints**
  - `bin/plangate` / `.claude/settings.json` は Hardening Override・self-mod 対象 → AI は apply-script を作り **人間が適用**
  - 承認は **Human-presence 多層検証**必須（`maintenance` の L1-L4 を踏襲）。非対話（AI Bash）からは発行不可
  - 生成する c3.json は **`schemas/c3-approval.schema.json` 準拠**必須（三値の条件付き必須フィールド含む / R-004,R-008）
  - Python は plan_hash 算出等で既存依存範囲のみ（新規 pip 依存なし）
- **TASK-0123 (#420) との関係（R-001）**
  - `scripts/check-approval-token-write.sh` は **TASK-0123 が作成済み**（現状 settings 未配線）。本 PBI は **その配線のみ**を行い、#420 のフル provenance hardening（HMAC / プロセス系譜 / CI 検証）は **再実装しない**。
  - #420 本体が後続で配線・強化する場合に備え、本 PBI の配線は #420 と additive（重複定義を避け、既存スクリプトを使う）。順序非依存（本 PBI 単独で成立）。
- **Non-goals（V2）**
  - 案 B（GitHub review ベース C-3）
  - #420 フル provenance hardening（HMAC / プロセス系譜の完全実装）
  - C-4 機構変更（GitHub Approve で適合済み）
  - 親 PBI（parent-c3 / parent-integration）対応
  - **identity の暗号学的証明**（本 PBI は presence 防御まで。identity 限界は注記で明示 / R-006）

## Approach Overview

`bin/plangate approve <TASK-XXXX> [--reject --reason <text>|--conditional --conditions <text>]`:
1. `maintenance` の **L1 isatty / L2 env barrier / L3 ppid heuristic / L4 nonce** を **`context` 引数付き共通関数に抽出**（R-005）。`approve` 実行時は `_maintenance` 生成や `maintenance_start_attempt` 監査を起こさず、`approve` 固有の audit event 名・プロンプトを使う。
2. `plan.md` から plan_hash を `plangate_sha256` で算出
3. `approved_by` を `git config user.email`（無ければ user.name）で解決。**`approved_by_source: git-config` / `approver_identity_unverified: true` を併記**し presence≠identity の限界を明示（R-006）
4. `approved_at` を生成
5. c3_status に応じ **schema 準拠**で `approvals/c3.json` 生成（R-004）:
   - APPROVED: plan_hash 等
   - CONDITIONAL: `conditions`（`--conditions` or 対話入力）必須
   - REJECTED: `rejection_reason`（`--reason` or 対話入力）必須
   - 既存あれば再承認として上書き（plan_hash 更新）
6. **最終確認の分離（R-003）**: APPROVED のみ `validate` 相当（c3_status=APPROVED + plan_hash 一致）を実行。REJECTED/CONDITIONAL は `validate` をかけず **schema 検証 + plan_hash 記録 + status 表示**にとどめる。

### AI 直接書込の唯一経路化（R-002）

- `scripts/check-approval-token-write.sh` を settings の **PreToolUse に `Edit|Write` と `Bash` の両 matcher**で配線する。
- Edit|Write は `PLANGATE_HOOK_FILE`、Bash は **コマンド文字列から `approvals/*.json` 等の対象 path を検出**して block。
- これにより `cat > .../approvals/c3.json` のような Bash 経由書込も防ぎ、`approve`(TTY) を唯一の正規経路にする。
- ※本反映の発端: 本セッションで AI が Bash heredoc で c3.json を書こうとした事実（classifier では止まったが hook では未配線だった）。

### アプローチ比較（B-2）

| 案 | 構成 | Pros | Cons | 採否 |
|----|------|------|------|------|
| **A（採用）** | maintenance L1-L4 を context 付き共通化し approve に適用 + Bash/Edit/Write 両 matcher 配線 | 実績ある防御を再利用・唯一経路化 | 共通化リファクタ + Bash path 検出の実装 | ✅ |
| B | approve は L1 isatty のみ・Edit\|Write のみ block | 軽量 | Bash 経由を防げない（R-002）・防御不整合 | ✗ |
| C | GitHub review ベース | provenance 強 | exec 前 PR 必須・スコープ大 | ✗(V2) |

## Work Breakdown

| Step | 内容 | Output | Owner | Risk | 🚩 |
|------|------|--------|-------|------|----|
| S1 | maintenance L1-L4 を context 引数付き共通関数へ抽出（副作用分離 / R-005） | bin/plangate（apply-script） | agent | H | 🚩 maintenance 回帰 |
| S2 | `cmd_approve` 実装（三値・schema 準拠・--reason/--conditions / R-004） | bin/plangate（apply-script） | agent | H | 🚩 自己承認不可 |
| S3 | approved_by 解決 + identity 限界注記（R-006）+ plan_hash 算出 | bin/plangate（apply-script） | agent | M | |
| S4 | 最終確認の分離: APPROVED のみ validate / 他は schema+status（R-003） | bin/plangate（apply-script） | agent | M | 🚩 |
| S5 | dispatch approve) + help 追記 | bin/plangate（apply-script） | agent | L | |
| S6 | check-approval-token-write.sh を Edit\|Write + **Bash** で配線（R-002）+ Bash path 検出ロジック | scripts/apply-task-0128-approve.sh + hook 追補 | agent | H | 🚩 唯一経路化 |
| S7 | apply-script 完成（冪等・--dry-run・アンカー検証・settings example 同期） | scripts/apply-task-0128-approve.sh | agent | M | 🚩 settings drift |
| S8 | ドキュメント更新（C-3 手順 → plangate approve） | docs/ | agent | L | |
| S9 | テスト（test-cases 全件・非対話拒否・Bash 書込 block・schema 検証 / R-008） | evidence/ | agent | H | 🚩 V-1 |
| H1 | apply-script を人間が dry-run → 適用（bin/plangate + settings） | 反映 | human | H | 🚩 HO/self-mod |

## Files / Components to Touch

- 変更（apply-script 経由・人間適用）: `bin/plangate`（L1-L4 共通化 + `cmd_approve` + dispatch + help）
- 変更（apply-script 経由・人間適用）: `.claude/settings.json` + `.claude/settings.example.json`（check-approval-token-write.sh を Edit|Write + Bash で配線）
- 変更（必要時）: `scripts/check-approval-token-write.sh`（Bash コマンド文字列からの path 検出を追補 / R-002）
- 新規: `scripts/apply-task-0128-approve.sh`（AI 作成 / 人間適用）
- 追記: ドキュメント（C-3 承認手順）

## Testing Strategy

- **Unit**: plan_hash 算出・approved_by 解決・三値 c3_status 生成（schema 準拠フィールド含む）
- **Schema（R-008）**: 生成した APPROVED/CONDITIONAL/REJECTED の c3.json を `schemas/c3-approval.schema.json` で検証（`validate-schemas` 相当）
- **Integration**: 対話 TTY で approve→（APPROVED 時）validate PASS
- **Security 負例（中核）**: 非対話 approve を L1 で拒否 / **Bash `cat > approvals/c3.json` を hook が block（R-002）** / env/ppid 不一致拒否
- **分離確認（R-003）**: REJECTED/CONDITIONAL で validate を呼ばず schema+status で完了
- **回帰**: maintenance start/stop が L1-L4 共通化後も挙動不変（R-005）
- **settings**: 配線後 doctor --check-settings / drift チェック整合

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| L1-L4 共通化で maintenance 既存挙動を壊す | context 引数で副作用分離、回帰テスト必須（S1 🚩 / R-005） |
| Bash 経由書込の検出漏れ | hook に Bash matcher + path 検出 + 専用テスト（R-002） |
| 三値 schema 違反の c3.json 生成 | 生成前後で schema 検証を acceptance 化（R-004/R-008） |
| approved_by を identity と誤認 | identity_unverified 注記で限界明示（R-006） |
| settings 配線 drift | apply-script に example 同期、doctor 検証 |
| 本 PBI の C-3 bootstrap | 完成まで interim、完成後 approve で TASK-0127/0128 正規承認 |

## Metrics Evidence

| 指標 | 実数 | 見積もり | ratio | 判定 |
|------|------|---------|-------|------|
| touch する HO/self-mod ファイル | 3（bin/plangate, settings.json, settings.example.json）+ hook 追補 | 3 | 1.0 | 採用（apply-script + 人間適用） |
| 配線する hook matcher | 2（Edit\|Write, Bash / R-002） | 2 | 1.0 | 採用 |
| 既存 schema 準拠 | 1（c3-approval.schema.json・三値条件付き必須） | 1 | 1.0 | 採用 |

## Mode判定

**モード**: critical（R-007 反映で high-risk → critical 引き上げ）

**判定根拠**:
- 変更ファイル数: bin/plangate + settings + settings.example + hook + apply-script + docs ≈ 6
- 受入基準数: 11（反映で増）
- 変更種別: **承認境界の中核機構**（c3.json 発行経路 + settings security hook 配線 + maintenance 共通化）= TASK-0123 と同等の critical 領域
- リスク: 極高（承認トークン発行経路・self-mod settings・既存防御の共通化）
- **最終判定**: critical（lite_eligible=false / Standard C-3 同期固定 / Hardening Override 優先 / V-4 リリース前チェック追加）
