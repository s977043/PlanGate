# 討議: C-3 / C-4 承認の「人間ゼロ作業」コンセプト vs provenance 安全

- 日付: 2026-06-12
- 発端: TASK-0127（C-3 レビュー HTML 出力）の C-3 承認手続き中
- 起票者: masatake.komine（PlanGate オーナー）

## 1. コンセプト宣言（オーナー判断）

> PlanGate のコンセプトとして、C-3 の承認・C-4 の承認はするが、
> **コマンドラインの実行・JSON の発行などの作業は人間に求めない。**

人間の役割は **承認の「判断」**。承認を成果物（c3.json / approvals）へ
転記する **「作業」** は人間に負わせない、という設計思想。

## 2. 現実装とのギャップ

| 観点 | 現実装 | コンセプト |
|------|--------|-----------|
| c3.json 発行 | **人間が手動発行**（AI は代理作成禁止） | 人間に作業させない |
| 強制機構 | `scripts/check-approval-token-write.sh`（TASK-0123 / #420）で AI の承認トークン直接書込を block（※現状 settings 未配線） | — |
| harness 層 | auto-mode classifier が「AI が人間名義 + AI 算出 plan_hash の承認トークン発行」を**なりすまし／整合性違反**として拒否（2026-06-12 実測） | — |
| 規範 memory | `feedback_maintenance_json_provenance_gap`：口頭指示でも AI は承認トークンを代理作成しない | — |

→ 現状は **「人間が JSON/CLI 作業をする」方向に倒れており、コンセプトと逆**。
過去インシデント（口頭指示由来のトークン代理作成の害）への対処としてこの実装に至った。

## 3. 本質的制約：完全ゼロ作業 と なりすまし防止 は両立しない

- 承認が「本物（人間由来）」である **認証された証跡** が必要
- AI がチャットの「承認した」を人間名義の署名付きトークンへ変換すると、
  技術的に AI が人間に **なりすます**（harness が拒否する所以）
- ∴ **人間が行う最小の認証アクションが1つ**必要。これは GitHub で
  C-4 を「Approve」ボタンで押すのと同じ構図（C-4 は既に GitHub review = 人間の認証アクション）

## 4. 提案する解決方向（低作業 × provenance 安全）

### 案 A: `plangate approve` を人間 TTY で実行 → c3.json 自動生成（推奨）
- `bin/plangate maintenance start` が採る **Human-TTY 方式**を C-3 承認に適用
- 人間は `plangate approve TASK-XXXX` の **1 アクション**のみ（JSON 手書き不要）
- plan_hash 算出・approved_by 解決（git config user）・timestamp は CLI が自動
- TTY 由来 = 人間プレゼンスの証跡 → provenance 安全
- 「CLI 実行も求めない」への配慮: ワンアクション化で「作業」ではなく「承認ボタン」に近づける

### 案 B: GitHub ベース承認（C-4 と同方式に統一）
- C-3 も PR コメント / review で承認 → CI が c3.json を機械生成
- 人間は GitHub の Approve のみ。provenance = GitHub 認証
- コスト: plan 段階で PR を要する（exec 前 PR）

### 案 C: 設定で AI 代行を sanction（方針確定型）
- オーナーが `.claude/settings` に明示許可ルールを追加
- 以降は AI の c3.json 発行が「なりすまし」でなく「オーナー設定による委任」
- リスク: provenance アンカーが弱まる（#420 の逆行）。慎重採用

## 5. 推奨

**案 A を本命**（#420 EH-3 provenance hardening の延長）。人間の作業を
「JSON 発行」から「ワンアクション承認」へ移し、コンセプトと provenance を
両立する。C-4 は既に案 B 相当（GitHub Approve）で達成済み = コンセプト適合。

## 6. TASK-0127 への影響（interim）

承認機構が未整備のため、TASK-0127 の C-3 は当面 interim:
- 人間が c3.json を1行コピペ実行（暫定）、または
- 案 A の最小実装を TASK-0127 と統合 / 先行実装

## 7. 関連
- #420 EH-3 provenance hardening（HMAC + プロセス系譜 + CI + 決定論 PreToolUse ガード）
- TASK-0123 check-approval-token-write.sh
- responsibility-classes.md（Human-owned: 承認境界の適用）
- memory: feedback_maintenance_json_provenance_gap / reference_approval_boundary_two_layer_verdict
