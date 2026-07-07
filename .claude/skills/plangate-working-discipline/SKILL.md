---
name: plangate-working-discipline
description: "PlanGate の中核作業規律。Plan → Review → Approve → Execute → Verify → Remember のループで AI 駆動開発の暴走・見落とし・偽の完了を防ぐ。Use when: 実装・修正・リファクタ・レビュー・長期タスク・セッション跨ぎ開発・サブエージェント利用判断のすべての作業開始時。Do not use when: 単発の質問応答・読み取りのみの調査（ループ全体は過剰。Verify/Report の規律のみ適用）。"
---

# PlanGate Working Discipline

AI 駆動開発の品質ゲート。**計画を固定し、リスクを先に見て、承認要否を判定し、
観測可能な証拠で検証し、判断を記録する**ための作業規律。

高度なモデルの能力を再現するものではなく、どのモデルでも継承できる
「判断基準・検証ループ・停止条件」の集合である。

## When to use / When not to use

- **Use**: 実装・修正・リファクタ・バグ修正・設計/差分レビュー・長期タスク・
  複数セッション跨ぎ・サブエージェント委託を伴う作業のすべて。
- **Do not use**: 読み取りのみの単発調査・会話的な質問応答
  （ただし報告時の「観測事実と推測の区別」は常時適用）。

## Core Principles（中核原則）

1. **完了条件を先に固定する** — 着手前に「何が観測できたら完了か」を書く。
   書けないなら作業を始めない。
2. **検証方法を書けない作業は、まだ理解できていないと見なす** — 「どう確かめるか」が
   言えない時点で、対象の理解が不足している。調査に戻る。
3. **実装前にリスクが高い箇所を特定する** — 不可逆操作・共有状態・承認境界・
   外部影響を先に列挙する。次の一手は常に「いま最もリスクが高い場所」から。
4. **「動くはず」ではなく、観測された証拠を信じる** — 完了・修正・マージなどの
   完了系の主張は、一次証跡（コマンド出力・SHA・CI 結果・grep 件数）で実測してから報告する。
   番号や名前の一致ではなく、SHA・内容の紐付けで同一性を判定する。
5. **宣言と実態を突合する** — ドキュメントの「DONE」「適用済み」を信じず、
   実ファイル・実コミットで確認する。宣言と実態の乖離（偽の完了）は最優先で是正する。
6. **着手前に並行作業を確認する** — 同じ issue・同じ領域を別の PR / セッションが
   既に実装していないかを確認してから着手する（重複実装は棄却コストが高い）。
7. **差分を小さく保つ** — 要求に紐づかない変更を混ぜない。stage は明示パス指定で行い、
   コミット前に staged 内容を必ず確認する。
8. **破壊的変更は承認ゲートを必須にする** — 削除・上書き・force 系・本番影響は
   [approval-gate-template.md](./approval-gate-template.md) を通す。迷ったら承認側に倒す。
9. **サブエージェント利用を目的化しない** — 委託は「複雑さ・独立性・並列性」の判断が先。
   委託しても統合責任者として自ら検証する。委託結果を無検証で採用しない。
10. **作業後は memory に判断・却下理由・未解決事項を残す** — 未来のセッションが
    同じ調査・同じ失敗を繰り返さないために。確定していない事項は PENDING を明記する。

## Phase Rules

### Plan Phase

実装前に必ず定義する（テンプレート: [plan-gate-loop.md](./plan-gate-loop.md) §1）:

Goal / Non-goals / Scope / Constraints / Existing Design Fit（既存設計との適合）/
Risk Areas / Assumptions / Unknowns / Required Files / Expected Diff /
Verification Method / Rollback Plan / Human Approval Required Conditions

- Unknowns が Goal に影響するなら、実装ではなく調査タスクを先に切る。
- Expected Diff（触るファイルの宣言）は Execute 後の差分検証の基準になる。

### Review Phase

計画レビューの観点（テンプレート: [review-gate-template.md](./review-gate-template.md)）:

要件整合 / 既存設計整合 / 過剰実装 / セキュリティ / データ破壊リスク /
テスト容易性 / 保守性 / 将来拡張性 / 実装コスト / 代替案比較 /
未検証の前提 / 人間承認が必要な箇所

- レビューは生成者と独立した視点で行う（自己レビューのみで通さない。
  可能なら別モデル・別セッション・adversarial 観点を 1 系統以上）。

### Approval Phase

以下は**明示的な人間承認がない限り禁止**（テンプレート:
[approval-gate-template.md](./approval-gate-template.md)）:

破壊的操作 / データ削除 / 大規模リファクタ / 認証・権限・課金・本番設定の変更 /
CI/CD・デプロイ設定変更 / 外部 API・料金・規約に影響する変更

ゲートの出力は `Requires Human Approval: yes / no` + `Risk Level`
（[approval-gate-template.md](./approval-gate-template.md)）。`yes` の場合、人間の承認**判断の結果**を
`approved` / `needs_revision` / `blocked` / `rejected` で記録する（Review Gate と共通の 4 値）。
自分で設置した再承認ゲートを、包括承認や自己解釈で解除しない。

### Execute Phase

- 計画外の変更をしない。変更理由を説明できない差分を作らない。
- 既存の命名規則・設計・責務分離に合わせる。依存関係をむやみに追加しない。
- エラーを握りつぶさない。テストしにくい構造にしない。
- **途中で前提が崩れたら実装を止めて Plan Phase に戻る**（迂回や別アプローチを
  勝手に始めない）。

### Verify Phase

必ず区別して記録する（テンプレート:
[verification-report-template.md](./verification-report-template.md)）:

実行したコマンド / 実行結果 / 成功した検証 / 失敗した検証 / **未実行の検証** /
未確認のリスク / 人間が確認すべき項目

- 検証コマンドはプロジェクトに存在するものを使う（lint / typecheck / test / build /
  format check / unit / integration / e2e / manual）。**存在しないコマンドを勝手に
  追加・捏造しない**。
- 失敗はそのまま報告する。失敗を隠した「完了」は偽の完了として扱う。

### Remember Phase

[plan-memory.md](./plan-memory.md) に残す: 採用した判断 / 却下した案と理由 /
既存設計上の制約 / 繰り返し発生しそうな失敗 / 次回参照すべき検証コマンド /
未解決リスク / 次に見るべきファイル / 次の一手。

- 完了系の記述は**確定後のみ**書く。未確定は `PENDING-VERIFY` を前置する
  （セッション跨ぎの汚染防止）。

### Report Phase

最終報告に必ず含める: 実施内容 / 変更ファイル / 検証結果 / **未検証事項** /
残リスク / 判断が必要な点（優先度付き）/ 次の推奨アクション。

**「完了」と言う場合は、観測可能な検証結果を添える。** 検証結果のない完了報告は
`partial` として扱う。

## 判定値の対応（既存契約とのマッピング）

リポジトリ内に並立する判定 enum の対応と優先関係。**再定義せず、文脈で正本を切り替える**:

| 文脈 | 使う値体系 | 正本 |
|---|---|---|
| 計画レビューの判定 | `approved` / `needs_revision` / `blocked` / `rejected` | 本 skill（review-gate）。PlanGate C-3 の `APPROVE / CONDITIONAL / REJECT` とは approved↔APPROVE / needs_revision↔CONDITIONAL / rejected↔REJECT で対応（blocked は「情報不足で判定不能」の追加状態） |
| 人間承認の要否 | `yes` / `no` + Risk Level | 本 skill（approval-gate）。HO 接触は `mode-classification.md` が最優先 |
| 検証レポートの完了判定 | `complete` / `partial` / `not_complete` | 本 skill（verification-report） |
| サブエージェントの最終行 | `OUTCOME: success / partial / failure` | `docs/ai/subagent-delegation/outcome-contract.md`（**委譲時はこちらが最終判定の正本**。complete↔success / partial↔partial / not_complete↔failure） |

> 注: `outcome-contract.md` の `review=true`（レビュータスクの判定緩和フラグ）と
> 本 skill の「Review Phase」（ループの段階名）は**無関係な別概念**。混同しない。

## 既存資産との棲み分け（demarcation）

本 skill は**ループ運用の型とテンプレート集**であり、以下の正本を再定義しない。
矛盾したら**常に正本が優先**（本 skill 側を修正する）:

| 正本 | 責務（本 skill はこれを再定義しない） |
|---|---|
| `docs/ai/core-contract.md` | Iron Law / Stop rules / Output discipline（実行契約の正本） |
| `.claude/rules/review-principles.md` | レビュー観点・Severity・auto-approve 判定（C-2 / CI / コードレビュー） |
| `.claude/rules/mode-classification.md` | 5 段階モード・**HO 9 カテゴリ**・lite_eligible（承認境界の機械判定） |
| `.claude/rules/responsibility-classes.md` | AI/Human/CI/Workflow の責務 4 分類・自己設置 Gate 非緩和 |
| `.claude/rules/working-context.md` | C-3/C-4 ゲート・handoff・作業コンテキスト構造 |
| `docs/ai/subagent-delegation/` | 派遣プロンプト 8 要素・OUTCOME 契約・行動規範（委譲の契約層） |
| `.claude/skills/self-review` | commit/PR 前のセルフレビュー手順（本 skill の Verify を補完する実行手段） |
| `.claude/skills/subagent-driven-development` | 委託実装の 2 段階レビュー開発手法 |

本 skill の固有価値は「**8 フェーズループとしての接続**」（各正本をいつ・どの順で使い、
どこで止まるか）と「**偽の完了を防ぐ検証・記録の型**」にある。

## 関連ファイル

- [plan-gate-loop.md](./plan-gate-loop.md) — 標準ループ（0. Intake〜7. Next Action）
- [plan-memory.md](./plan-memory.md) — メモリテンプレート
- [review-gate-template.md](./review-gate-template.md) — 計画レビュー
- [approval-gate-template.md](./approval-gate-template.md) — 人間承認判定
- [verification-report-template.md](./verification-report-template.md) — 検証レポート
- [anti-patterns.md](./anti-patterns.md) — アンチパターン集
- [example-prompts.md](./example-prompts.md) — 用途別プロンプト例
