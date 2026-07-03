# 既存 plan→exec ワークフローとの共存・部分導入ガイド

> 導入先リポジトリに **既に plan→exec 系ワークフロー**（独自の `/plan` コマンド、
> 承認フロー、TDD skill 等）がある場合の判断基準と部分導入パターンを示す。
> 「機能の二重化」を理由に導入を見送る前に、共存・部分導入の選択肢を検討する
> ための正本。
> 背景: [#687](https://github.com/s977043/plangate/issues/687)（growth-lab
> 導入検討時、既存 `ai-dev-workflow` との二重化により統合を見送った実例）
> 関連: [`staged-adoption-guide.md`](./staged-adoption-guide.md) /
> [`pages/explanation/product/when-not-to-use.md`](./pages/explanation/product/when-not-to-use.md) /
> [`ai/plugin-stability-and-sync.md`](./ai/plugin-stability-and-sync.md)

## 1. 前提: 全面導入だけが選択肢ではない

PlanGate は「統制層（ゲート・承認・状態保存）」と「実行層（Workflow /
Skill / Agent）」に分離されている
（[`workflows/README.md`](./workflows/README.md) 参照）。既存ワークフローが
plan→exec の**実行層**を既に持っている場合、それを置き換えず、PlanGate の
**統制層（C-3/C-4 承認ゲート・レビュー観点・handoff）だけ**を差し込む部分
導入が可能。全面移行の検証コストを払わずに価値の一部を得られる。

## 2. 共存の判断マトリクス

既存ワークフローの何を残し、PlanGate の何を足すかを 3〜4 パターンで示す。

| パターン | 既存側を残す | PlanGate 側を足す | 向くケース |
|---------|------------|------------------|-----------|
| **A. ゲートのみ併用** | 既存の計画フォーマット・plan コマンド全体 | C-3/C-4 承認ゲートの型（三値判定・plan_hash 改竄検知の考え方）のみ | 既存 plan の質は十分だが、承認プロセスが暗黙的で属人化している |
| **B. レビュー観点のみ移植** | 既存の plan→exec フロー全体 | [`review-principles.md`](../.claude/rules/review-principles.md) の 5 観点 + Severity 定義、[`plan-review-readiness-gate.md`](./ai/plan-review-readiness-gate.md) のチェック項目 | 既存レビューが「読んで OK/NG」止まりで、観点・Severity が体系化されていない |
| **C. handoff / mode 分類のみ移植** | 既存の計画・実装・レビュー全工程 | handoff 6 要素テンプレート、[`mode-classification.md`](../.claude/rules/mode-classification.md) の 5 段階規模判定 | 実装は完了するが引き継ぎ資産が残らない／規模に応じた工程の重さ調整がない |
| **D. 検証ゲートのみ補完** | 既存の CI・plan→exec 全体 | L-0（リンター自動修正）/ V-1（受け入れ検査）相当の機械検証だけ | 既存 CI は静的解析止まりで、受入基準との突合が手動 |

**選び方の目安**: 既存側の**欠けている工程**（承認の型がない／レビュー観点が
属人化／handoff が残らない／受入基準との機械突合がない）を特定し、その工程
だけを PlanGate から移植する。複数パターンの併用も可（例: B + C）。

## 3. 部分導入パス（staged-adoption-guide との接続）

[`staged-adoption-guide.md`](./staged-adoption-guide.md) の Phase は「ゼロ
から PlanGate を全面導入する」前提だが、共存時は以下の順で**価値の高い
単位から**段階採用する。各ステップは独立して止めてよい。

1. **観点だけ輸入**（コストほぼゼロ）: [`review-principles.md`](../.claude/rules/review-principles.md)
   の 5 観点・Severity 定義・判定基準を既存レビューのチェックリストに転記する。
   PlanGate 側のフック・エージェントは一切導入しない。
2. **handoff テンプレートだけ輸入**（Phase 1 相当）: 既存の完了報告に
   [`docs/working/templates/handoff.md`](./working/templates/handoff.md) の
   6 要素を足す。plan フォーマットは変更しない。
3. **承認ゲートの型だけ輸入**（Phase 2 相当）: 既存承認フローに三値判定
   （APPROVE / CONDITIONAL・REQUEST CHANGES / REJECT）を導入する。
   `EH-2`/`EH-3` 相当のフックは既存 CI 側に自前実装してもよい（PlanGate の
   フック機構そのものは必須ではない）。
4. **機械検証ゲートを補完**（Phase 3 相当・任意）: 既存 CI に L-0/V-1 相当の
   受入基準突合を追加する場合のみ、PlanGate 本体（`bin/plangate` / hooks）の
   部分導入を検討する。

ステップ 1〜2 は CLI・hook 配線が不要なため、CLI 未導入のリポジトリでも
着手できる（growth-lab の実例で障壁になった CLI 未導入問題を回避できる）。

## 4. 二重化の解消指針

既存ゲートと PlanGate ゲートが同じ工程をカバーする場合、**どちらを正とする
か**を以下の優先順位で決める。

1. **機械実行できる方を優先する**: 人間の目視確認より、hook / CI で自動検証
   できる方を正とする（誤検知は許容度合いを個別調整）。
2. **承認境界に厳しい方を優先する**: 一方が「レビュー任意」、他方が「承認
   なしでは進めない」なら、後者を正とする（[`responsibility-classes.md`](../.claude/rules/responsibility-classes.md)
   の Human-owned 境界と整合させる）。
3. **監査証跡が残る方を優先する**: 承認記録・decision log が append-only で
   残る方を正とする。
4. 1〜3 で決まらない場合は、既存側を正とし PlanGate 側は導入しない
   （§5 参照）。**両方を並走させて二重運用しない**（監査対象の分裂を防ぐ）。

## 5. 非採用でよいもの

既存ワークフローで工程が既に足りている場合、PlanGate 側の対応機能を**導入
しないという判断も正当**とする。過剰導入（既に持っている機能を重ねて足す
こと）は避ける。

- 既存の plan フォーマットが十分に構造化されている → PlanGate の
  plan.md/todo.md/test-cases.md 生成は不要
- 既存 CI が受入基準との突合を自動化済み → V-1 相当の追加は不要
- 既存の承認フローが三値判定・監査ログを既に備える → C-3/C-4 の型移植は不要
- チーム規模・継続期間が [`when-not-to-use.md`](./pages/explanation/product/when-not-to-use.md)
  の非採用ケースに該当する → 部分導入も見送ってよい

## 6. 判断フロー（要約）

```text
既存 plan→exec ワークフローがある
  ↓
欠けている工程はあるか？（承認の型／レビュー観点／handoff／機械検証）
  ├─ ない → 導入見送り（§5）。既存を正本のまま維持
  └─ ある → §2 のパターン A〜D から該当箇所のみ選択
              ↓
            §3 の順序で最小コストの単位から段階採用
              ↓
            工程が重複する箇所は §4 の優先順位で正本を一本化
```

## 関連

- [`staged-adoption-guide.md`](./staged-adoption-guide.md) — 全面導入時の Phase 0〜3
- [`pages/explanation/product/when-not-to-use.md`](./pages/explanation/product/when-not-to-use.md) — 非採用ケース一覧
- [`workflows/README.md`](./workflows/README.md) — 統制層/実行層の分離（部分導入の前提）
- [`.claude/rules/review-principles.md`](../.claude/rules/review-principles.md) — レビュー観点・Severity（パターン B）
- [`.claude/rules/mode-classification.md`](../.claude/rules/mode-classification.md) — 5 段階規模判定（パターン C）
- [`.claude/rules/responsibility-classes.md`](../.claude/rules/responsibility-classes.md) — Human-owned 境界（§4 二重化解消指針）
- [#687](https://github.com/s977043/plangate/issues/687) — 本ガイドの起票 issue
