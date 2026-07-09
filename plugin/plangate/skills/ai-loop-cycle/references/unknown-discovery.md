# Unknown Discovery — 未知の発見・記録・レビュー可能化

> 対応 issue: [#729](https://github.com/s977043/plangate/issues/729)
> 根拠となる第一原理: [`design-philosophy.md`](./design-philosophy.md) I-9（承認された宣言は実差分で再検証される — 二段 detect）
> 本書の位置づけ: design-philosophy.md §8 トリアージにおける #729 の配置先（「plan 前ゲートは
> PlanGate 側と ai-loop 側の両建て、Deviation Log は decision record と統合検討、I-9 の運用面を補完」）
> を具体化した**機構**正本。思想的根拠（なぜ）は design-philosophy.md に譲り、本書は「何を・いつ・
> どう記録するか」の手順のみを定義する。

---

## 1. 背景 — なぜ unknown discovery が要るか

PlanGate はすでに「Plan → Review → 承認 → 実行」の統制を持つが、以下のリスクは
既存フローだけでは潰しきれない:

- 実装前に未知の前提が十分に洗い出されない
- AI がユーザー意図を推測して作業を進めてしまう
- 実装中に発見した制約・逸脱理由が記録されず、レビュー時に意図が見えない
- 要約・コンテキスト圧縮後に「却下した理由」「計画変更の理由」「未解決の論点」が失われる

Unknown Discovery は、この「未知」を **発見（Plan 前）→ 明示（Plan 中）→ 記録（実装中）** の
3 ゲートに分けて構造化し、[`design-philosophy.md`](./design-philosophy.md) I-9
（宣言と実差分は別命題であり、二段で検証する）の**運用面**を補完する。

---

## 2. unknowns の 4 分類

AI 駆動開発で発生する典型例を併記する。

| 分類                 | 定義                                           | AI 駆動開発での典型例                                                                                                                   |
| -------------------- | ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| **Known Knowns**     | 分かっていて明示していること                   | plan.md の受入基準・Constraints に書かれている前提                                                                                      |
| **Known Unknowns**   | 分からないと自覚していること                   | 「この API のレート制限が不明」「既存テストが該当パスをカバーしているか未確認」等、plan.md の Questions / Unknowns 節に書ける粒度のもの |
| **Unknown Knowns**   | 見れば分かるが、事前に言語化できていない暗黙知 | 既存コードの命名規約・エラーハンドリング方針など、コードを読めば分かるが指示文には書かれていない慣習                                    |
| **Unknown Unknowns** | 知らないことにすら気づいていないリスク・制約   | 「この変更が別サービスの契約を暗黙に壊す」「HO パスに波及する副作用がある」など、事前に問いすら立っていない領域                         |

Unknown Discovery の目的は、**Unknown Unknowns をできる限り Known Unknowns に変換し、
残った Unknown Unknowns の存在を「分からないものが残っている」という形で明示すること**である
（ゼロにする、ではなく「不可視を可視化する」）。

---

## 3. 適用対象（過剰適用の抑制）

小規模タスクへの過剰適用を避けるため、以下の基準で適用要否を判定する。

### 適用対象（推奨）

- 初めて触るコード領域
- 認証・課金・権限・データ移行など失敗コストが高い作業
- UI/UX のように「見ないと判断できない」作業
- AI に長時間実装させる作業（`mode-classification.md` の high-risk / critical 相当）
- PR レビューで差分だけ見ても意図が分かりづらい作業

### 対象外（適用しなくてよい）

- 小さな文言修正
- 明確なバグ修正
- 既存パターンに沿った単純追加
- 影響範囲が限定されているリファクタ
- `mode-classification.md` の ultra-light / light 相当

判定不能・境界事例は、design-philosophy I-4（安全側デフォルト）に従い**適用する側**に倒す。

---

## 4. 3 ゲート

### 4.1 Plan 前 — Unknown Discovery Gate

実装計画を作る前に、AI に blindspot pass を実行させる。

**確認観点（5 つ）**:

1. ユーザーが見落としていそうな unknown unknowns
2. 事前に確認すべき設計・運用・セキュリティ上の論点
3. このまま実装すると危険な仮定
4. 既存コード・既存設計との整合性
5. より良い実装依頼にするための修正案

**成果物**: `plan.md` 内 `## Unknowns / Blindspots` 節（既存 plan.md の
「Questions / Unknowns」節を拡張する形。新規ファイル `unknowns.md` は本書では採用しない
— plan.md と別ファイルに分裂させると参照漏れが起きやすく、C-3 レビュー時に一体で読める
ほうが実効性が高いため。ただし高リスク・複数論点で plan.md が肥大化する場合は、担当者判断で
別ファイル化してよい）。

### 4.2 Plan 中 — Tweakable Decision Gate

単なる作業順序ではなく、**人間が調整・判断しそうな論点**を先に出す。

**優先して明示する 6 領域**:

1. アーキテクチャに影響する判断
2. データモデルに影響する判断
3. API 設計に影響する判断
4. UX フローに影響する判断
5. セキュリティ・権限に影響する判断
6. テスト戦略に影響する判断

これらは plan.md の Work Breakdown / Risks & Mitigations 節に、「この論点は人間の
判断待ちである」ことが分かる形で明記する。C-3 ゲート（人間レビュー）が、この明示を前提に
判断できることが目的であり、C-3 の判定基準自体は変更しない。

### 4.3 実装中 — Deviation Log Gate

実装中に計画と現実の差分が出た場合、**勝手に大きく設計変更せず**、理由を記録する。

**記録する 5 項目**:

1. 発見した事実
2. 当初計画と違った点
3. 選んだ保守的な対応
4. 後で人間が判断すべき論点
5. 次回の計画に反映すべき学び

**成果物**: `plan.md` 内 `## Deviations` 節、または `docs/working/TASK-XXXX/status.md`
の「計画からの変更点」節（`working-context.md`
既存節を流用。新規 `implementation-notes.md` は本書では採用しない — status.md が既に
「計画からの変更点」を持つため、成果物を増やすより既存節に統合するほうが Progressive
Disclosure（L1 で読める）と整合する）。

**「勝手に大きく設計変更しない」の運用境界**:

- 保守的な対応（当初計画の範囲内での小さな調整）は記録のうえ続行してよい
- 設計そのものを変える必要がある逸脱を発見した場合は、記録した上で**実行を止め**、
  人間または C-3' 相当のゲートに判断を仰ぐ（ai-loop 文脈では
  [`design-philosophy.md`](./design-philosophy.md) I-1 の枠内で、
  承認境界の拡大解釈を自己判断しない）

---

## 5. Deviation Log と decision record の統合方針

Deviation Log（4.3）と、ai-loop の decision record
（[`execution-runbook.md`](./execution-runbook.md) §2-(4) 「decision record を保存」）は、
**別の記録ではなく同一の記録機構への異なる入力**として扱う方針とする。

| 項目           | Deviation Log（本書）                                                                                                                                                                                                                | decision record（execution-runbook §2-(4)） |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------- |
| 記録主体       | PlanGate 標準フロー（人間 C-3/C-4 前提）                                                                                                                                                                                             | ai-loop（Arbiter 裁定後）                   |
| 記録タイミング | 実装中、計画との差分発生時                                                                                                                                                                                                           | 1 サイクル完了後                            |
| 記録先         | plan.md `## Deviations` / status.md                                                                                                                                                                                                  | decision record（ai-loop 側の永続化先）     |
| 統合方針       | PlanGate 標準フローの Deviation Log は decision record の**前身データ**として扱い、ai-loop 適用領域では同一項目（発見事実・計画差分・対応・要判断論点・学び）を decision record のフィールドに写像する。二重記録・二重正本は作らない | —                                           |

具体的なフィールド対応（decision record 側スキーマの拡張）は、ai-loop 側の実装 PBI で
[`decision-table.md`](./decision-table.md) §5 provenance スキーマとの整合を確認した上で
確定する。本書は「統合する」という方針表明までとし、スキーマ確定は本書の scope 外。

---

## 6. Review 前 — Understanding / Quiz Gate（参考・任意）

issue #729 の検討事項に含まれる「Review 前の Understanding / Quiz Gate」は、
本書の 3 ゲート（Discovery / Tweakable Decision / Deviation Log）とは性質が異なり
（実装前後ではなく PR レビュー直前が対象）、PlanGate の C-4（PR レビュー）運用に接続する
別ゲートとして扱う。本書では **導入するかどうかの検討事項として記録するに留め**、
確定した観点定義は別途 PR レビュー関連の正本（`review-principles.md`
等）側で扱う。

想定される確認観点（参考）:

- 背景 / 何が変わったか / なぜその設計にしたか / 既存挙動への影響 / 注意すべきリスク /
  レビュアーが確認すべき観点 / マージ前に答えるべき確認クイズ

---

## 7. I-9 との関係（運用面の補完）

[`design-philosophy.md`](./design-philosophy.md) I-9 は「承認された宣言
（plan）と実差分は別命題であり、二段で検証する」という**検証構造**の原理である。
本書の 3 ゲートは、その運用面を以下のように補完する:

- **Discovery Gate（4.1）/ Tweakable Decision Gate（4.2）** は、第 1 段 detect（plan 宣言の
  裁定）が判断すべき材料を**充実させる**（未知が潰れていない plan は、そもそも良い宣言に
  なっていない）
- **Deviation Log Gate（4.3）** は、第 2 段 detect（実差分の検証）が「宣言外の変更」を
  検知した際に、**なぜ逸脱が起きたかの文脈**を提供する。逸脱の記録があることで、
  第 2 段 detect が「悪意ある逸脱」と「保守的な現実対応」を区別しやすくなる

本書は I-9 の検証構造そのものを変更しない。あくまで、その前後に人間・AI が参照する
記録の質を上げるための運用手順である。

---

## 8. 関連ドキュメント

- [`design-philosophy.md`](./design-philosophy.md) §2 I-9 / §8 トリアージ（#729 行）
- [`execution-runbook.md`](./execution-runbook.md) §2-(4)（decision record 保存）
- [`decision-table.md`](./decision-table.md) §5（provenance スキーマ）
- `working-context.md`（status.md「計画からの変更点」節）
- `mode-classification.md`（適用対象の mode 判定）
- issue [#729](https://github.com/s977043/plangate/issues/729)
