# TASK-0123 current-state

> 更新日時: 2026-07-05（bookkeeping 是正 / stale 状態を実態へ修正）
> フェーズ: 部分完了（Part A ガード deployed / Part B HMAC 未適用・要 Human 判断）

## 実態（2026-07-05 実測）

- **C-3: APPROVED** — `approvals/c3.json` 実在（approved_by: human-s977043、#427 で ship）。旧記載「C-3 待ち / c3.json 未発行」は stale。
- **Part A（承認トークン書込ガード / AC-1〜4）: 稼働済み** — `scripts/check-approval-token-write.sh` 実在 + `.claude/settings.json` L65/74 の PreToolUse に配線済。exec は #427（c70563b）でマージ済。
- **Part B（HMAC 署名 / AC-5）: 未適用** — `schemas/maintenance.schema.json` に `hmac_signature` フィールド不在（grep 実測 0 件）。`scripts/apply-task-0123-patches.sh` は生成済だが未実行（引数なし実行で適用・`--dry-run` で事前確認。HO パス / Human-owned）。
- 親 issue **#420 は #427 で CLOSED COMPLETED**（コミット本文が "Closes #420 (partial — HO patches pending human application)" と明記）。

## 次のアクション（要 Human 判断・承認境界 / security）

HMAC 署名層（Part B）を、以下のいずれかに決定する:

- **(a) 適用**: Human が `sh scripts/apply-task-0123-patches.sh`（`--dry-run` 確認後、引数なしで適用）を実行 → HMAC による多層防御を完成。
- **(b) Deferred / Superseded クローズ**: Part A ガードで #420 の実害は解消済みとして HMAC 層を見送る。

AI は本判断を行わない（`.claude/rules/responsibility-classes.md`）。詳細は `handoff.md` の「状態訂正（bookkeeping 2026-07-05）」節を参照。

## ブロッカー

Part B のみ: HO 実適用（Human-owned）の要否が未決。Part A（ガード稼働・C-3 承認）は解消済み。

## 重要な設計決定

- 全 HO ファイルは patch 方式で Human が apply（AI 直接変更不可）
- HMAC 署名: `PLANGATE_MAINTENANCE_KEY` 設定済みの場合のみ検証有効（後方互換考慮）
- `check-approval-token-write.sh`: maintenance 窓でも常時 block（HO 相当）
