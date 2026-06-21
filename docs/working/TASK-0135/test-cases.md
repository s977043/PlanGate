# TEST CASES — TASK-0135 (#578)

## AC → TC
### AC-01: Verification 実行不能時の理由+代替欄
- TC-01: plan.md に「実行不能」かつ「代替確認」を含む行が存在。種別: 機械（grep）
### AC-02: Security 観点追加
- TC-02: review-self.md に `C1-SEC-01` が存在し、finding に「.env / 秘密情報 / 個人パス」「secret scan」を含む。種別: 機械（grep）
### AC-03: Scope 予防チェック
- TC-03: review-self.md に `C1-SCOPE-DISC-01`（実装中の発見を別 Issue/メモへ分離）が存在 + plan.md Scope に予防注記。種別: 機械（grep）
### AC-04: 既存参照で役割分担 Done 充足・_docs 新設しない
- TC-04: plan/review-self に decision-log.jsonl / AGENT_LEARNINGS.md / `_audit/` / documentation-management への参照リンクがある（4 参照すべて）。`_docs/` ディレクトリを新設していない（find で不在 or 本 PBI で作らない）。種別: 機械（grep + find）
### AC-05: 重複ゼロ
- TC-05: 追加項目が既存 C1（C1-PLAN-03 スコープ / C1-PLAN-08-AEE / C1-SUP-PLAN-01 No Placeholders 等）と重複しない（観点が直交）。種別: レビュー

## Edge cases
- EC-01: Security 観点は「秘密情報を扱わない Plan」では「該当なし（N/A）」を許容（過検出しない）
- EC-02: Scope 予防は「発見ゼロ」でも FAIL にしない（発見時の分離方針の有無を問う）
- EC-03: 件数更新は実数で（{N+} のような曖昧表記にしない）
