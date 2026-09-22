# TASK-XXXX TEST CASES

> フェーズ B（Prompt 1）で `plan.md` / `todo.md` と**同時生成**する。
> 正本: [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) の「test-cases.md（テストケース定義）」節 /
> [`.agents/skills/ai-dev-plan/SKILL.md`](../../../.agents/skills/ai-dev-plan/SKILL.md) の「test-cases.md 規約」。
> 設計判断からテストを導出する実行規範は同 Skill の「Plan Design Principles」節。詳細正本は上流 `docs/ai/plan-design-principles.md`。
> **本テンプレートは規約の実体化であって再定義ではない**。規約を変えるときは正本側を変える。

## 記入規約（チェックリスト）

- [ ] [`pbi-input.md`](./pbi-input.md) の**すべての受入基準に最低 1 件**のテストケースを対応させる（対応の無い AC を残さない）
- [ ] AC 以外の重要な Contract / Invariant / Regression / Conditional Requirement を検証する場合、下記 `Verification Trace` に**存在理由と現在根拠**を記録する
- [ ] Contract / Invariant を「テストを作るため」に後付けで発明しない。AC / 既存挙動 / Domain Rule / Architecture Constraint / 実測 Evidence の最低1つへ trace する
- [ ] **Minimum Sufficient Test Set**: 各 Test Case は distinct な `Trace ID` または distinct な failure / boundary / compatibility / security evidence を持つ。同じ Trace + 同じ failure mode を重複して証明するケースは、差に意味がなければ統合する（件数上限は設けない）
- [ ] **Edge case を含める**（境界値・異常系・空入力・上限・権限なし等）
- [ ] 各ケースに 前提条件 / 入力 / 期待出力 / 種別 を書く
- [ ] 各ケースの**期待値に出所を書く**（`デザイン実測` / `規約` / `既存実装`）。出所が `規約` のものは下記 `## Convention Evidence` で実値と突合する（#934）
- [ ] 自動化できないケースは「自動化可否」表に理由と代替手段を残す

> `Trace` と `期待値の出所` は別の問いである。
>
> - **Trace**: なぜこのテストケースが存在するか。`Verification Trace` を正とし、各ケースでは `Trace ID` だけを参照する
> - **期待値の出所**: なぜその期待値が正しいか

## 受入基準 → テストケース マッピング

| 受入基準 | テストケース | 備考 |
| --- | --- | --- |
| AC-01: {受入基準の要旨} | TC-01, TC-02 | {補足} |
| AC-02: {受入基準の要旨} | TC-03, TC-E01 | {補足} |

> 未対応の AC が 1 つでも残る場合は plan に戻す（C-1 の「受入基準との紐付き」で FAIL になる）。

## Verification Trace

> AC の網羅表を置き換えない。AC 以外を含む「このテストがなぜ必要か」を追跡するための表。
> `Contract` / `Invariant` は Source / Evidence が空なら採用しない。

| Trace Type | Trace ID / 内容 | Source / Evidence | テストケース |
| --- | --- | --- | --- |
| AC | AC-01 | `pbi-input.md#AC-01` | TC-01, TC-02 |
| Contract | CONTRACT-01: {現在守る契約} | `{既存API / ADR / schema / 実測}` | TC-03 |
| Invariant | INV-01: {現在守る不変条件} | `{Domain Rule / 既存実装 / 実測}` | TC-04 |
| Regression | REG-01: {観測済みfailure} | `{Issue / evidence / failing test}` | TC-R01 |
| Conditional Requirement | CR-01: {failure / compatibility 等} | `{発火したDesign Guidanceと根拠}` | TC-E01 |

## テストケース一覧

### TC-01: {テストケース名}

- 対応 AC: AC-01
- Trace ID: AC-01
- 種別: unit / integration / e2e / manual
- 前提条件: {実行前に成立している必要がある状態}
- 入力: {具体値。「適切な値」と書かない}
- 期待出力: {具体値・exit code・エラーメッセージ}
- 期待値の出所: デザイン実測 / 規約 / 既存実装（`規約` の場合は `## Convention Evidence` に突合行が必要）
- 検証コマンド: `{実行コマンド}`

### TC-02: {テストケース名}

- 対応 AC: AC-01
- Trace ID: AC-01
- 種別: unit / integration / e2e / manual
- 前提条件: {前提}
- 入力: {入力}
- 期待出力: {期待}
- 期待値の出所: デザイン実測 / 規約 / 既存実装
- 検証コマンド: `{実行コマンド}`

## Edge Cases

> 正常系だけの一覧にしない。最低 1 件は異常系・境界値を置く。
> Failure / Compatibility / Security / Observability 等の Conditional Design Guidance が発火した場合だけ、必要なケースを追加する。全観点を一律に展開しない。

### TC-E01: {エッジケース名}

- 対応 AC: AC-02 / N/A
- Trace ID: {AC-02 / CONTRACT-01 / INV-01 / REG-01 / CR-01}
- 種別: unit / integration / e2e / manual
- 分類: 境界値 / 異常系 / 空入力 / 上限・下限 / 権限なし / 並行実行
- 前提条件: {前提}
- 入力: {境界値・異常値}
- 期待出力: {期待する失敗の仕方（fail-closed か fail-open か）を明記する}
- 期待値の出所: デザイン実測 / 規約 / 既存実装
- 検証コマンド: `{実行コマンド}`

## Convention Evidence（規約由来の期待値の突合 / #934）

> 「規約に準拠しているか」と「規約が実態と合っているか」は別の問いで、AC に書けるのは前者だけ。
> 後者が未検証のまま前者を AC 化すると、**AC を満たすほど実態から離れる**。
> 事前メトリクス検証（正本: `docs/ai/plan-metrics-verification.md`）が「全部 / 全件」系に実数を要求するのと
> 同じ理由で、**規約由来の期待値には実値との突合を要求する**。

規約（コーディング規約・スタイルガイド・設計ドキュメント等）を根拠にした期待値を
テストケースに書く場合、**その規約が実値と一致していることを確認してから AC 化する**。

| 規約の記述（出典パス付き） | 実値（デザイン実測 / 既存実装。取得方法も書く） | 一致 | 判定 |
| --- | --- | --- | --- |
| {規約の記述}（`path/to/rule.md`） | {実測値}（取得: `{コマンドまたは確認手順}`） | ✅ / ❌ | 採用 / **AC から除外** |

> 凡例:
>
> - ✅ 一致 → 期待値として **採用**してよい
> - ❌ 不一致 → **AC に採用しない**。安全側に倒し、`plan.md` の 🚩 人間確認ポイントへ落とし、
>   規約と実装のどちらを正とするかは**人間の設計判断**に委ねる（規約側の更新が要る場合は別 Issue を起票する）
>
> **不一致を AI が黙って片側に寄せて一括変更しない**
> （[`.claude/rules/mode-classification.md`](../../../.claude/rules/mode-classification.md) の安全側不変条件と一貫）。
> 規約由来の期待値が 1 件も無い場合は本節に「該当なし」と明記する（空欄のまま残さない）。

## 自動化可否

| テストケース | 自動化 | 理由 / 代替手段 |
| --- | --- | --- |
| TC-01 | 可 | — |
| TC-E01 | 不可 | {自動化できない理由と、代わりに行う手動確認の手順} |

## 検証結果（V-1 で記入）

| テストケース | 結果 | Evidence |
| --- | --- | --- |
| TC-01 | PASS / FAIL / WARN | `evidence/test-runs/{ログ}` |

> FAIL の判定には evidence が**必須**（evidence の無い FAIL は無効）。PASS は evidence 省略可、WARN は推奨。