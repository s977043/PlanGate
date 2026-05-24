# TASK-0109 review-external (C-2 proactive 外部レビュー集約)

> 追記専用・差分管理用。R-NNN は指摘 ID。reflected_in = 確定反映コミット。

## Sources

- C-2 proactive (2026-05-24): Codex (設計妥当性レーン) + Gemini (コードベース整合レーン)
- 経緯: TASK-0109 C-3 直前に proactive 外部レビュー実施。Gemini に **CRITICAL** 発見

## 集約 (R-001..R-010)

| ID | Lane | Severity | 内容 | reflected_in | status |
|----|------|----------|------|--------------|--------|
| R-001 (codex#1) | 設計 (Codex) | major | CX-2 hook 起動経路が未確定。`scripts/codex-local.sh` は単に `exec codex` で hook 呼出なし、`.codex/config.toml` にも hook 登録構造なし。`.codex/hooks/*.sh` 追加しても発火保証なし → T-01 ハードゲート化 + 経路確定まで CX-2 着手禁止 | _本コミット_ | reflected |
| R-002 (codex#2) | 設計 (Codex) | major | EH-3 配線は「Cursor 版翻訳」ではなく「**新規設計**」。実際の `.cursor/hooks.json` は EH-1/EH-2 のみで EH-3 不在 → T-04 で「EH-3 新規設計」と明記 | _本コミット_ | reflected |
| R-003 (codex#3) | 設計 (Codex) | major | TC-05 manual だけでは AC-2 検証弱い → **wrapper 経由 deterministic test** (codex CLI fixture stub) に強化 | _本コミット_ | reflected |
| R-004 (codex#4) | 設計 (Codex) | minor | AC-4/AC-6 docs 整合の Work Breakdown / touch files に README.md / README_en.md / docs/index.md が無い → Files + T-09b 追加 | _本コミット_ | reflected |
| R-005 (gemini#1) | コードベース (Gemini) | **CRITICAL** | review 用 `codex exec` 呼出時に `--sandbox read-only` 必須。review プロセスがファイル改変できないことを保証 → Constraints + T-02 + Risk + TC-05c | _本コミット_ | reflected |
| R-006 (gemini#2) | コードベース (Gemini) | major | `codex` CLI に `--timeout` なし → shell `timeout` コマンドで wrap (デフォルト 600s) | _本コミット_ | reflected |
| R-007 (gemini#3) | コードベース (Gemini) | major | `--output-last-message <file>` でクリーンなレビュー出力のみファイル化 (stdout 解析の脆さ回避) | _本コミット_ | reflected |
| R-008 (gemini#4) | コードベース (Gemini) | major | Hook 発火機構の確認 (Cursor のような hooks.json native サポート不明) → R-001 と統合、T-01 で対応 | _本コミット_ | reflected |
| R-009 (gemini#5) | コードベース (Gemini) | major | shim/symlink 経由でも repo root 正しく特定 → `CDPATH= cd -- "$(dirname -- "$0")" && pwd` パターン | _本コミット_ | reflected |
| R-010 (gemini#6) | コードベース (Gemini) | minor | Role Mapping 表 (Codex Agent ↔ PlanGate Role) を `docs/rfc/provider-codex.md` に追加 | _本コミット_ (plan で確定、exec 時実装) | reflected |

## info / 採用しなかった指摘

- (Gemini#7) Status 記載 (v8.10.0 相当) → CX-3 RFC Status は本 PBI 完了 commit の merged バージョン (既存 Q/U 方針通り、再確認のみ)
- (Gemini#10) Codex CLI 未インストール時の error handling → T-02 に追加済 (info → reflected)

## 反映方針

`.claude/rules/working-context.md` の review-external 差分管理 (#234-C) に従い、本コミットで pbi-input / plan / todo / test-cases / review-self を **1 回確定反映**。Gemini CRITICAL 発見 (R-005) により Constraints / T-02 / TC-05c を強化。Codex major (R-001 hook 経路) により T-01 をハードゲート化、経路確定まで CX-2 凍結。

簡易 C-1 v2 を review-self.md に記録、blocker 0 で C-3 提出可。
