# C-3 承認コマンド `plangate approve`（TASK-0128）

> PlanGate コンセプト: **人間は承認の「判断」をする。c3.json の発行作業（JSON 手書き・plan_hash 算出）は負わない。**
> 討議: [`docs/working/discussions/2026-06-12-c3c4-approval-ux-vs-provenance.md`](working/discussions/2026-06-12-c3c4-approval-ux-vs-provenance.md) / 関連 #420。

## 目的

C-3 人間承認を「JSON 手書き」から「**ワンアクション承認**」へ移す。人間は対話 TTY で承認意思を示すだけで、`plan_hash` 算出・`approved_by` 解決・`approved_at` 付与・schema 準拠 `c3.json` 生成を CLI が自動化する。

完全ゼロ作業は harness が原理拒否（AI による人間なりすまし）するため、**人間の最小認証アクション（対話 TTY での承認）** を provenance のアンカーとする。これは C-4 の GitHub「Approve」ボタンと同じ構図。

## 使い方

```sh
# 承認（APPROVED）
plangate approve TASK-XXXX

# 条件付き承認（conditions 必須）
plangate approve TASK-XXXX --conditional --conditions "AC-3 のテスト追加後に exec"

# 却下（rejection_reason 必須）
plangate approve TASK-XXXX --reject --reason "設計の前提が未確定"
```

実行すると L1-L4 の Human-presence 検証（下記）が走り、通過後に `docs/working/TASK-XXXX/approvals/c3.json` を schema 準拠で生成する。

## Human-presence 多層防御（L1-L4）

`maintenance start` と同等の **best-effort 多層防御**で、非対話実行（AI の Bash 等）からの自己承認を**抑止する**（絶対防御ではない・下記「防御の限界」参照）:

| 層 | 検証 |
|----|------|
| L1 | isatty（stdin が対話 TTY か） |
| L2 | env barrier（CI / CLAUDE_AGENT / CURSOR_AGENT / PLANGATE_BYPASS_HOOK 不在） |
| L3 | 親プロセスヒューリスティック（ppid comm が claude/codex/cursor でない） |
| L4 | 対話 nonce challenge（8-hex を人間が打鍵） |

> **防御の限界（best-effort であって絶対ではない / #546 Codex review）**: L1-L4 は
> 「非対話 stdin・既知 agent env・AI 親プロセス」を確実に拒否するが、**疑似 TTY を
> 持ち表示された nonce を読み取って応答できる自動化**は理論上突破しうる。また
> `PLANGATE_FAKE_PPID_COMM` はテスト注入用で L3 を上書きできる。真の security
> boundary が必要なら、承認を agent が観測・応答できない **out-of-band 操作**
> （human-owned apply / OS keychain / 外部署名 等）へ寄せる強化が必要（follow-up）。

いずれか不成立で承認は中断し `c3.json` は生成されない。

## 多層の唯一経路化（R-002）

`scripts/check-approval-token-write.sh` を PreToolUse の **Edit|Write と Bash 両 matcher**で配線し、AI による `approvals/*.json` への直接書込（`cat > .../c3.json` 等の Bash 経由を含む）を block する。これにより `plangate approve`（TTY）が承認トークン生成の唯一の正規経路になる。

## 生成される c3.json（schema 準拠）

`schemas/c3-approval.schema.json` 準拠。`approved_by` は git config 由来のため、identity の限界を `_approver_identity_unverified` / `_approved_by_source` 注釈で明示する（presence は検証、identity は未検証 / R-006）。

## 最終確認の分離（R-003）

- **APPROVED**: `plangate validate` を実行（c3_status=APPROVED + plan_hash 一致）
- **CONDITIONAL / REJECTED**: validate は実行せず（APPROVED 以外は validate が FAIL のため）、schema 検証 + plan_hash 記録 + status 表示にとどめる

## 責務分界

| 操作 | 担当 |
|------|------|
| `approve` コマンド実装・apply-script 作成 | AI-owned |
| `bin/plangate` への適用（HO）/ settings 配線（self-mod） | Human-owned（apply-script を人間が適用） |
| 承認の判断（approve 実行） | Human-owned（対話 TTY） |

## 関連

- 仕様: [`docs/working/TASK-0128/plan.md`](working/TASK-0128/plan.md)
- apply-script: `scripts/apply-task-0128-approve.sh` / `scripts/apply-task-0128-token-guard-wiring.sh`
- 既存: `bin/plangate maintenance`（L1-L4 の原型）/ TASK-0123 `check-approval-token-write.sh`
- follow-up: `.claude/rules/working-context.md` の C-3 手順記述を本コマンドへ更新（HO のため別 apply-script / 別 PBI）
