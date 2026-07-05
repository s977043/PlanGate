# adaptive-production-loop — 6層自己改善ループ 正本

> 対応: [#709](https://github.com/s977043/plangate/issues/709)
> AC 対応: AC-1（6層の概念文書化）/ AC-2（L0〜L5 対応表）/ AC-3（Evaluate と
> flow→detect→escalate の整合）/ AC-4（Remember と Optimize の分離）/
> AC-5（Scheduling の独立責務化）/ AC-6（policy/HO/C-4 merge の Human-owned
> 固定維持）/ AC-7（学習ループの承認境界自己変更禁止）/ AC-8（既存 L4 との
> 重複回避・上位概念化）/ AC-9（Recurse 条件の明記）
> 適用ドメイン: ai-loop-workflow（`docs/workflows/ai-loop/` 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）
> 位置づけ: 本書は **6層モデル（Generate → Evaluate → Remember → Schedule →
> Optimize → Recurse）の正本**。既存の判定ロジック・還元フロー・実行手順は
> 再定義せず、[`00_concept.md`](./00_concept.md)・[`flow-detect.md`](./flow-detect.md)・
> [`review-feedback-loop.md`](./review-feedback-loop.md)・
> [`execution-runbook.md`](./execution-runbook.md)・
> [`docs/ai/ai-loop/concept.md`](../../ai/ai-loop/concept.md) を参照する
> 上位概念として整理する（AC-8）。

---

## 1. 目的とスコープ

ai-loop-workflow は AI を「**低リスク帯・境界内に限定した適応型生産システム
（bounded adaptive production loop / human-on-the-loop）**」として扱う
（[`docs/ai/ai-loop/concept.md`](../../ai/ai-loop/concept.md) §1「Arbiter とは
何か」）。本書はその 1 サイクルの手順を **Generate → Evaluate → Remember →
Schedule → Optimize → Recurse** の 6 ステップとして定義し、既に個別に存在する
判定フロー（flow→detect→escalate）・学習閉ループ（L4 6 ステップ）・実行手順
（PR 後ループ）を、**時間軸上の 1 サイクルの手順**として束ねる。

- **本書が新規に定義するもの**: 6 層モデルのステップ区分、各ステップと
  既存 L0〜L5 アーキテクチャ層との対応、Remember と Optimize の分離軸、
  Recurse（次サイクルへの引き継ぎ）条件。
- **本書が再定義しないもの**: W チェックの判定ロジック（flow-detect.md）、
  L4 6 ステップフローの内部手順（review-feedback-loop.md）、PR 後ループの
  収束ルール・Scheduling 判断表（execution-runbook.md）、承認境界そのもの
  （arbiter-policy.md / ho-paths.md）。これらは single source のまま
  参照する。
- **非ゴール**: WF-00〜07 の置換、`bin/plangate` / `schemas/` /
  `.github/workflows/` / `.claude/` 配下（HO パス）の変更、人間承認ゼロの
  即時解禁、policy/HO/C-4 merge の Human-owned 固定の緩和、L5 コンテキスト
  基盤の先行実装（[`docs/ai/ai-loop/concept.md`](../../ai/ai-loop/concept.md)
  §8 non-goals と一致）。

---

## 2. 6層モデル（Generate → Evaluate → Remember → Schedule → Optimize → Recurse）

```text
Generate → Evaluate → Remember → Schedule → Optimize → Recurse
                                                            │
                                          （次サイクルの Generate/Evaluate へ）
                                                            └──────────────┘
```

| 層           | 定義                                                                     | 対応する既存概念（正本）                                                                                                                                                                                                           |
| ------------ | ------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Generate** | 変更（plan / 実装）を生成する                                            | [`00_concept.md`](./00_concept.md) §3.2 パイプラインの生成工程、[`execution-runbook.md`](./execution-runbook.md) §2-(1)(2)（W チェック用の変更取得・verdict 生成）                                                                 |
| **Evaluate** | 生成された変更の妥当性を判定する                                         | [`flow-detect.md`](./flow-detect.md) §2〜§4（flow→detect→escalate）、[`00_concept.md`](./00_concept.md) §3.2〜§3.3（C-3' 裁定パイプライン・merge-ready DoD 判定）                                                                  |
| **Remember** | 判定結果を事実として記録・蓄積する（まだ改善に変換しない）               | [`review-feedback-loop.md`](./review-feedback-loop.md) §2-1「収集」・§2-2「分類」、[`decision-table.md`](./decision-table.md) §5 provenance スキーマ、[`execution-runbook.md`](./execution-runbook.md) §2-(4) decision record 保存 |
| **Schedule** | 記録された状態から「次に何をするか」を選択する（独立責務）               | [`execution-runbook.md`](./execution-runbook.md) §2-(7) PR 後ループの優先順位判断（Scheduling 判断表）                                                                                                                             |
| **Optimize** | 記憶した事実を次サイクルの gate / skill / pre-check に変換し精度を上げる | [`review-feedback-loop.md`](./review-feedback-loop.md) §2-3「還元先判定」・§2-4「反映」・§2-5「事前適用」・§2-6「効果測定」                                                                                                        |
| **Recurse**  | 1 サイクルの出力を次サイクルの入力に接続する不変条件                     | [`review-feedback-loop.md`](./review-feedback-loop.md) §2-6 の再発検出ループ（§2-1 へ戻る）                                                                                                                                        |

### 2-1. Generate

W チェック（Evaluate）の入力になる変更そのものを生成する層。判断実行の主体は
[`docs/ai/ai-loop/concept.md`](../../ai/ai-loop/concept.md) §7 の **L1（判断実行層）**
であり、L1 は内製せず RiverReview に委譲する方針（concept.md §7）を踏襲する。
将来的に L5（コンテキスト基盤）が実装されれば Generate の入力燃料となり得るが、
L5 の先行実装は非ゴール（concept.md §8）。

### 2-2. Evaluate

Evaluate は **[`flow-detect.md`](./flow-detect.md) の flow→detect→escalate を
再定義せず、その別名でもなく、内包する上位ラベル**として定義する（AC-3）。

- flow フェーズ（boundary / lite / class の前提チェック）と detect フェーズ
  （W チェック・severity 分類・決定論分類器・Model C/D 裁定）は
  [`flow-detect.md`](./flow-detect.md) §2〜§3 を single source とする。
- merge-ready 判定（CI green + AI レビュー指摘対応完了の DoD）も Evaluate の
  一部だが、**merge そのものは Evaluate の外**（Human-owned の C-4。
  [`00_concept.md`](./00_concept.md) §3.2〜§3.3）。
- detect は「plan（宣言）に対する第 1 段」と「CI/PR 時の AI レビュー（実差分に
  対する第 2 段）」の二段構成（[`00_concept.md`](./00_concept.md) §3.3
  「detect の二段構成」）であり、Evaluate はこの両方を含む。

### 2-3. Remember

Remember は「まだ何も改善しない、ただ覚える」層であり、
[`review-feedback-loop.md`](./review-feedback-loop.md) §2 6 ステップの
**§2-1（収集）と §2-2（分類）**が実体である。指摘 ID（`R-NNN`）付きの収集、
再発性/severity の 2 軸分類、[`decision-table.md`](./decision-table.md) §5 の
provenance 刻印（`AUTO_APPROVED` の正本記録）、
[`execution-runbook.md`](./execution-runbook.md) §2-(4) の decision record
保存が Remember の具体的な出力物である。詳細は §4 を参照。

### 2-4. Schedule

Schedule は「判定が下った後、次に何をするか」を選ぶ**独立の責務**であり、
Evaluate（判定そのもの）にも Optimize（学習反映）にも属さない。判断の実体は
[`execution-runbook.md`](./execution-runbook.md) §2-(7) の PR 後ループに
定義される Scheduling 判断表（次アクション優先順位: fix CI → address AI
review → re-run self-review → update suppression → escalate to human →
stop-block、対応ラウンド上限 3、human escalate 条件）であり、本書では
再定義しない（AC-8）。実行主体は
[`docs/ai/ai-loop/concept.md`](../../ai/ai-loop/concept.md) §7 の
**L3（自律実行層）**に対応する。

### 2-5. Optimize

Optimize は Remember が蓄積した事実を、次サイクルの gate / skill / pre-check
に変換して精度を上げる層であり、
[`review-feedback-loop.md`](./review-feedback-loop.md) §2 6 ステップの
**§2-3（還元先判定）・§2-4（反映）・§2-5（事前適用）・§2-6（効果測定）**が
実体である。真指摘の昇格（gate 観点への反映）と誤検知抑制（suppression 登録、
review-feedback-loop.md §5）の両方向を含む。実行主体は
[`docs/ai/ai-loop/concept.md`](../../ai/ai-loop/concept.md) §7 の
**L4（学習層）**に対応する。詳細な分離軸は §4 を参照。

### 2-6. Recurse

1 サイクルの出力（Remember の記録・Optimize が反映した gate/skill 更新）が
次サイクルの Generate / Evaluate の入力になる不変条件。詳細は §5 を参照。

---

## 3. L0〜L5 との対応表

6 層モデル（Generate→Evaluate→Remember→Schedule→Optimize→Recurse）は
「**時間軸上の 1 サイクルの手順**」であり、L0〜L5
（[`docs/ai/ai-loop/concept.md`](../../ai/ai-loop/concept.md) §7
「アーキテクチャ（6層）」）は「**静的な層アーキテクチャ**」である。両者は
直交する概念であり、以下は 6 層の各ステップがどの L0〜L5 層で実行されるかを
示す多対多の写像である（AC-2）。

| 6 層モデルのステップ | 対応する L0〜L5 層                                                | 根拠                                                                                                   |
| -------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| Generate             | L1（判断実行層。RiverReview 委譲）＋ L5（任意・コンテキスト燃料） | concept.md §7「L1 は内製せず RiverReview に委譲」                                                      |
| Evaluate             | L1（実行主体）＋ L2（裁定の心臓）                                 | concept.md §7「L2 が新規性の中核」、flow-detect.md §3                                                  |
| Remember             | L2（provenance 刻印）＋ L4（学習層への入力）                      | decision-table.md §5、review-feedback-loop.md §2-1〜2-2                                                |
| Schedule             | L3（自律実行層）                                                  | execution-runbook.md §2-(7)                                                                            |
| Optimize             | L4（学習層）                                                      | review-feedback-loop.md §2-3〜2-6、concept.md §7「L4 学習層 = 判断結果を次の gate に変換する閉ループ」 |
| Recurse              | L3（非同期での次サイクル継続）＋ L4（学習フィードバックの再入力） | review-feedback-loop.md §2-6 再発検出ループ                                                            |
| （6 層すべてを拘束） | **L0（統制契約層）**                                              | arbiter-policy.md、ho-paths.md。§6 参照                                                                |

- **L0 は全ステップの拘束条件**であり、6 層のどのステップにも個別対応しない
  （承認境界・責務モデル・HO・mode 判定はすべてのステップを横断して拘束する。
  concept.md §7「L0 はゼロから設計」）。
- **L5 は Generate の任意燃料**にとどまる。L5 コンテキスト基盤の先行実装は
  非ゴール（concept.md §8）であり、6 層モデルの必須要素ではない。
- **L2 が新規性の中核**（concept.md §7）であることに対応し、6 層モデルでは
  Evaluate（裁定）と Remember（provenance 刻印）の両方の中核が L2 に位置する。

---

## 4. Remember と Optimize の分離

Remember と Optimize の境界は
[`review-feedback-loop.md`](./review-feedback-loop.md) §2 6 ステップフローの
**§2-2（分類）と §2-3（還元先判定）の間**に引く（AC-4）。

| review-feedback-loop.md §2 のステップ | 概念層                                           | 内容                                                                          |
| ------------------------------------- | ------------------------------------------------ | ----------------------------------------------------------------------------- |
| §2-1 収集                             | **Remember**                                     | PR レビュー指摘を `R-NNN` 方式で収集。指摘ゼロでも「指摘なし」を明示記録      |
| §2-2 分類                             | **Remember**                                     | 再発性（再発性あり/一過性）× severity（critical/major/minor/info）の 2 軸分類 |
| §2-3 還元先判定                       | **Optimize**                                     | skill / gate 観点ドキュメント / policy / 還元不要の 4 分岐へ振り分け          |
| §2-4 反映                             | **Optimize**                                     | 還元 PR 作成、トレーサビリティ表（R-NNN｜還元先｜commit）                     |
| §2-5 事前適用                         | **Optimize**                                     | 次回 flow 前の pre-check で観点が効くことを確認                               |
| §2-6 効果測定                         | **Optimize**（再発時は Remember へ戻り Recurse） | 次回 PR で同型再発の有無を確認                                                |

- **Remember** = 事実の蓄積・保持（まだ何も改善しない、ただ覚える）。
  provenance 刻印（[`decision-table.md`](./decision-table.md) §5）、decision
  record 保存（[`execution-runbook.md`](./execution-runbook.md) §2-(4)）、
  `R-NNN` 集約、[`review-feedback-loop.md`](./review-feedback-loop.md) §5
  の suppression 登録もすべて Remember の実体に含まれる。
- **Optimize** = 記憶を次サイクルの gate / skill / pre-check に変換して
  精度を上げる工程。誤検知抑制（suppression の適用側）と真指摘の昇格の
  両方向を持つ（review-feedback-loop.md §1）。

本書は review-feedback-loop.md §2 の 6 ステップを再定義せず、Remember /
Optimize の**上位概念名**として参照する（AC-8）。すなわち、Remember の
PoC 実体は §2-1〜§2-2、Optimize の PoC 実体は §2-3〜§2-6 である。

---

## 5. Recurse 条件（1サイクル出力→次サイクル入力）

Recurse は「1 サイクルの出力が次サイクルの入力になる」不変条件を定義する
（AC-9）。

### 5-1. 通常終了（Recurse しない経路）

Evaluate（merge-ready DoD 判定）が満たされ C-4（人間の merge 承認）へ遷移
した場合、そのサイクルは Recurse せず完了する
（[`00_concept.md`](./00_concept.md) §3.3 DoD 定義）。

### 5-2. Recurse する経路（次サイクルへの接続）

以下のいずれかが次サイクルの入力として引き継がれる：

| 次サイクルへの入力                                   | 生成元（本サイクルの出力）                                   | 接続先（次サイクルの層）                                                 |
| ---------------------------------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------ |
| 更新済み severity 分類マッピング表・suppression 登録 | Optimize（review-feedback-loop.md §2-4 反映）                | 次サイクルの Evaluate（decision 分類器・C/D 裁定基準）                   |
| 更新済み self-review / readiness gate 観点           | Optimize（review-feedback-loop.md §2-5 事前適用）            | 次サイクルの Generate（強化セルフレビュー、execution-runbook.md §2-(6)） |
| 再発検出（同型指摘の再出現）                         | Remember→Optimize の効果測定（review-feedback-loop.md §2-6） | 次サイクルの Remember（§2-1 収集へ再ループ）                             |
| decision record（provenance）                        | Remember（decision-table.md §5）                             | 次サイクルの L4 学習入力（review-feedback-loop.md §3）                   |

Recurse の発火条件は
[`review-feedback-loop.md`](./review-feedback-loop.md) §2-6「効果測定」の
再発検出ループ（再発時は §2-1 収集へ戻る）と一致し、本書はこれを 6 層モデル
上の呼称として引用する（再定義しない）。

### 5-3. Recurse の不変条件

Recurse は **既存サイクルの記憶・学習結果を積み増すだけ**であり、次サイクルの
承認境界（boundary=touches-HO の human escalate 固定など）を変更しない。
Recurse によって Evaluate の判定基準そのものが緩和されることはない
（§6 参照）。

---

## 6. 承認境界の不変条件（policy / HO / C-4 merge は Human-owned 固定）

6 層モデルは「**低リスク帯・境界内に限定した適応型生産システム
（bounded adaptive production loop / human-on-the-loop）**」として動作し、
以下は 6 層のどのサイクルにおいても **永久 Human-owned 固定**である
（AC-6）：

1. **policy 制定・改版**（第0の承認境界。
   [`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §6）
2. **boundary=touches-HO の操作**（
   [`ho-paths.md`](../../ai/ai-loop/ho-paths.md) の touches-HO 判定ルール＝絶対条件）
3. **W チェック不一致かつ severity=critical/major**（
   [`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §2「Human-owned
   の変化」）
4. **merge（C-4）**（[`00_concept.md`](./00_concept.md) §3.2「C-4・merge —
   Human-owned 固定（不変）」）

これは [`arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) §2 の
責務モデル拡張で定義された永久 Human-owned 4 項目そのものであり、6 層モデル
はこの境界を**緩和しない**。

### 6-1. 学習ループ（Remember / Optimize）は承認境界を自己変更しない（AC-7）

Optimize（review-feedback-loop.md §2-3〜§2-6 の還元・反映・事前適用・効果
測定）は、次のいずれの経路も持たない：

- policy への還元を AI が自己承認する経路
  （[`review-feedback-loop.md`](./review-feedback-loop.md) §6「学習ループ
  自身が承認境界を侵食してはならない（『自分の枠を自分で書き換えない』の
  L4 版）」）
- HO パス（[`ho-paths.md`](../../ai/ai-loop/ho-paths.md)）に触れる skill /
  gate 還元を human escalate なしで適用する経路（同 §6）

policy への還元候補は AI が draft 提案までしか行えず、発行・適用は
Human-owned 固定である（[`review-feedback-loop.md`](./review-feedback-loop.md)
§2-3）。この原則は 6 層モデル全体（L0 が全ステップを拘束する、§3 参照）の
不変条件であり、Recurse（§5）によって積み増される学習結果によっても緩和
されない。

---

## 7. 関連ドキュメント

- [`docs/ai/ai-loop/concept.md`](../../ai/ai-loop/concept.md) §7「アーキテク
  チャ（6層）」— L0〜L5 の定義（正本）
- [`docs/workflows/ai-loop/00_concept.md`](./00_concept.md) §3 — PlanGate
  フロー共通化と C-3 置換（C-3'）の確定パイプライン・merge-ready 責務範囲
- [`docs/workflows/ai-loop/flow-detect.md`](./flow-detect.md) — Evaluate の
  実体（flow→detect→escalate、W チェック、severity 分類、C/D 裁定）
- [`docs/workflows/ai-loop/review-feedback-loop.md`](./review-feedback-loop.md) —
  Remember / Optimize の実体（L4 学習閉ループ 6 ステップ）
- [`docs/workflows/ai-loop/execution-runbook.md`](./execution-runbook.md) —
  Generate の実行手順・Schedule の判断表（PR 後ループ §2-(7)）
- [`docs/workflows/ai-loop/decision-table.md`](./decision-table.md) §5 —
  Remember の刻印フィールド正本（provenance スキーマ）
- [`docs/ai/ai-loop/arbiter-policy.md`](../../ai/ai-loop/arbiter-policy.md) —
  承認境界の不変条件（永久 Human-owned 4 項目、第0の承認境界）
- [`docs/ai/ai-loop/ho-paths.md`](../../ai/ai-loop/ho-paths.md) —
  boundary=touches-HO 判定の正本
- [`.claude/rules/responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) —
  PlanGate 責務 4 分類（参照のみ、本 PoC は独自の責務モデルを持つ）
