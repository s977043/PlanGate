# PBI INPUT PACKAGE: TASK-0128

## Context / Why

PlanGate のコンセプトは「**人間は C-3 / C-4 の承認『判断』をする。c3.json 発行・CLI 作業などの『作業』は人間に負わせない**」（オーナー宣言 2026-06-12）。

しかし現状の C-3 承認は人間が `c3.json` を手動発行する運用に倒れており、コンセプトと逆行している。一方で「完全ゼロ作業」は harness の auto-mode classifier が「AI による人間なりすまし」として原理的に拒否するため不可能（2026-06-12 実測）。

そこで **人間のワンアクション認証**で c3.json を自動生成する `plangate approve` 機構（討議メモ 案 A）を導入する。人間は「承認ボタン1押し」相当、plan_hash 算出・approved_by 解決・timestamp は CLI が自動化する。`bin/plangate maintenance start` の Human-TTY 方式を踏襲し provenance を担保する。

討議メモ: `docs/working/discussions/2026-06-12-c3c4-approval-ux-vs-provenance.md`
関連: #420（EH-3 provenance hardening）/ TASK-0123（check-approval-token-write.sh）

## What

### In scope

- `bin/plangate approve <TASK-XXXX> [--reject|--conditional]` サブコマンド追加
  - `bin/plangate` は Hardening Override 対象 → AI は apply-script を作成し**人間が適用**
  - **Human-TTY 必須**（`[ -t 0 ]` 等）: 非対話 Bash（= AI）からは実行不可。`maintenance start` と同方式
  - `plan.md` の plan_hash を自動算出（plangate_sha256）
  - `approved_by` を `git config user.email`（または name）から自動解決
  - `approved_at` を自動付与
  - `docs/working/<TASK>/approvals/c3.json` を `c3_status: APPROVED`（または REJECTED / CONDITIONAL）で生成
  - 既存 c3.json があれば確認の上で上書き（再承認 = plan 変更後の再算出に対応）
- `scripts/check-approval-token-write.sh` を `.claude/settings.json` に**配線**（AI の c3.json 直接書込を block）し、`plangate approve`（TTY）を唯一の正規経路にする
  - settings 配線は Human-owned 適用（apply-script + 人間実行）
- ドキュメント追記（C-3 承認手順を「c3.json 手書き」から「plangate approve」へ更新）

### Out of scope（V2）

- 案 B（GitHub PR review ベース C-3 承認 → CI 生成）
- #420 のフル provenance hardening（HMAC + プロセス系譜 + CI 検証の全体）
- C-4 承認の機構変更（既に GitHub Approve でコンセプト適合済み）
- 親 PBI（parent-c3.json / parent-integration.json）への展開

## 受入基準

| AC | 内容 |
|----|------|
| AC-01 | `plangate approve TASK-XXXX` を **対話 TTY** で実行すると `approvals/c3.json`（c3_status=APPROVED）が生成される |
| AC-02 | 生成 c3.json の plan_hash が現 plan.md の sha256 と一致する（自動算出） |
| AC-03 | approved_by が git config から自動解決される（人間が手入力しない） |
| AC-04 | **非対話実行（AI の Bash 等、TTY なし）では拒否**され c3.json を生成しない |
| AC-05 | `--reject` / `--conditional` で対応する c3_status を発行できる |
| AC-06 | `check-approval-token-write.sh` が settings に配線され、AI の c3.json 直接 Write/Edit が block される |
| AC-07 | `bin/plangate` 変更は apply-script 経由で AI は直接編集しない（人間適用） |
| AC-08 | 既存 c3.json がある場合の再承認（plan 変更後）で plan_hash が更新される |
| AC-09 | 承認後 `bin/plangate validate TASK-XXXX` が PASS する |
| AC-10 | 生成 c3.json が `schemas/c3-approval.schema.json` に準拠（三値の条件付き必須フィールド含む / R-004,R-008） |
| AC-11 | REJECTED/CONDITIONAL は validate を呼ばず schema+plan_hash+status 表示で完了（R-003） |

## Notes from Refinement

- コンセプト: 承認＝判断（人間）、転記＝自動（CLI）。完全ゼロ作業は不可（なりすまし防止）→ 人間ワンアクション認証が最小単位
- TTY 必須が AI 自己承認を物理的に防ぐ要（exec をアンブロックするトークンの自己発行防止）
- 既存 memory `feedback_maintenance_json_provenance_gap` と階層整合（AI 代理作成は引き続き禁止、人間 TTY 経由のみ正規）

## Estimation Evidence

### Risks / Unknowns

- `! plangate approve` をセッションから実行した場合に TTY が得られるか（maintenance start の TTY 判定実装を要確認）
- settings 配線（HO + Human-owned）と doctor/CI の整合
- Mode = high-risk（bin/plangate + settings = 承認境界 touch）→ lite_eligible=false / Standard C-3 同期固定（本 PBI 自身の承認もこの機構の bootstrap 問題を内包）

### Assumptions

- `bin/plangate maintenance` の TTY 判定・apply-script パターンを踏襲
- approved_by は git config user.email を既定とする
- 本 PBI 完成後、TASK-0127 の C-3 は `plangate approve` で正規承認する
