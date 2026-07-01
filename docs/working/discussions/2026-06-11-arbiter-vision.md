# Arbiter 構想まとめ — 枠内自律 AI 開発の裁定ランタイム

> **Status**: 構想まとめ（2026-06-11）。**ブレスト由来・未確定**。確定仕様・設計決定・
> 実装方針ではない。意思決定とリソース投下は人間のもの。
> **置き場所**: 中立ローカル（独立プロジェクト。既存リポジトリ未配置）。
> **位置づけ**: PlanGate / RiverReview とは**別の新規プロジェクト**。PlanGate は前提でなく
> 「先行事例・threat model の提供元」、RiverReview は判断実行を委譲する外部依存。
> **出典**: 同日ブレストログ `2026-06-11-governed-autonomy-river-review.md`（§1-11）。

---

## 1. 一言で

**Arbiter** は、**AI を走らせたまま安全な枠の中に保ち、逸脱だけを人間に昇格する**、
枠内自律（governed autonomy）AI 開発の**裁定ランタイム**。人間をループの中（in）から
ループの上（on）へ出し、各実行を承認する役割から「自律の枠と例外条件を定める」
メタ統治へ移す。

名の由来: 仕組みの心臓は **裁定層**（流れてきた変更を、二分ルールと二重判定で
auto-approve / 人間昇格 / ブロックへ決する Arbiter）。

---

## 2. 解く問題

- AI のコード生成速度は指数的に伸びるが、**人的レビューはリニアにしか伸びない**。
- 「実行前に人間が1件ずつ承認する」モデル（in-the-loop）は、この速度差で必ず
  ボトルネック化する。
- かといって統制を捨てれば、承認境界・provenance なき自律は事故を生む。
- **Arbiter の解**: 統制を緩めず、承認の時制を「実行前」から「逸脱検知時」へ移す。
  流して、検知して、例外だけ人に上げる（flow → detect → escalate）。

---

## 3. コア原理：3 つの動作

```text
flow      : 低リスク変更は実行前ブロックせず流す
detect    : 流れる変更を二重判定（W チェック2モデル）で逸脱検知
escalate  : 逸脱（2モデル不一致 / 承認境界接触 / critical）だけ人間へ昇格
            合意 clean は auto-approve＋provenance 刻印
```

人間は「各実行の承認者」をやめ、「**枠（policy）の制定者・例外の裁定者・事後の
監督者**」になる。

---

## 4. アーキテクチャ（6 層）

```text
L5 コンテキスト基盤   任意。コード/docs/DB/インフラを統合グラフ化（AI が辿る燃料）
L4 学習層            判断結果を次の gate に変換する閉ループ（誤検知抑制 / 真指摘の昇格）
L3 自律実行層        非同期フロー・親子並列・self-healing・サーキットブレーカー
L2 裁定層 ★          Arbiter の心臓。二分ルール / policy 評価 / provenance 発行
L1 判断実行層        RiverReview 委譲（versioned skills / gates / W チェック / riverbed）
─────────────────────────────────────────
L0 統制契約層        承認境界 / 責務モデル / HO / mode 判定（on-the-loop 用に新規設計）
```

- **L2 が新規性の中核**。「block until approved」型でなく「flow → detect → escalate」型の
  決定エンジン。
- **L1 は内製せず RiverReview に委譲**（判断基準を versioned skill 化する既存資産を活用）。
- **L0 はゼロから設計**（既存ガバナンスの設計哲学だけ参照し、契約定義は on-the-loop 用に
  書き起こす。§9 参照）。

---

## 5. 裁定の二分ルール（L2 の中核ロジック）

判断は**決定論・明示的失敗・トレース可能**。出力は4値
（auto-approve / human 昇格 / 同期ブロック / 拒否）。

### 5.1 入力（4 軸）

- `boundary`: 承認境界（HO 相当）に触れるか — touches / clean
- `lite`: 低リスク要件を満たすか — true / false
- `verdict`: RiverReview の critical/major 件数
- `class`: merge を含むか

### 5.2 W チェック（2 モデル）＝裁定の第一信号

**2 モデルが割れた所だけ人間が見る**。モデルは非対称:
A=順方向（設計妥当性「正しく作られているか」）/ B=逆方向（adversarial「どう壊れるか」）。

| モデル A | モデル B | → 裁定 |
|---|---|---|
| approve | approve | 合意 → auto-approve 候補（clean 時） |
| approve | reject | 不一致 → **human 昇格**（最も価値ある信号） |
| reject | reject | 合意 → ブロック |

### 5.3 要石

**承認境界に触れた瞬間に全部 human に戻る**。それさえ越えなければ
verdict 質 × lite × 2 モデル合意度で機械的に分かれる。この一点を死守すれば
承認境界を溶かさず自動範囲だけ広げられる。

### 5.4 設計/PR 両ゲートへの適用

- **設計ゲート**（plan 相当）: 実行前なので巻き戻しが安く、閾値は緩め。
- **PR/merge ゲート**: 最も硬い。`verdict 生成`→`approve 判定`→`merge 実行`を
  3 レイヤーに分離。merge 実行は **policy-gated auto-merge（最低リスク帯のみ）or 人間**。
  承認境界・merge-policy 変更は人間 merge 固定。

---

## 6. 安全装置（on-the-loop 固有の死因への抗体）

| 死因 | 抗体 |
|---|---|
| サイレント逸脱 | 逸脱検知の完全配線（検知器に穴を残さない） |
| 監督の幻想 | **承認 provenance**（誰が・どの policy で・対象 SHA・W チェック結果を刻印） |
| 自己免疫疾患 | **policy/gate 生成は永久 in-the-loop**（第0の承認境界） |
| 例外昇格の洪水 | human 昇格の**予算**（上限 N＋重大度トリアージ） |
| 承認境界の漸進侵食 | 境界の常時 block 維持＋発行元検証（provenance）を塞ぐ |
| 不可逆性 | **サーキットブレーカー**（事後 reject で巻き戻し / policy 自動失効） |

### 第0の承認境界（policy 制定）

auto-approve を許す policy（例 `auto-approve-lite-clean@v1`）自体がメタ承認境界。
**policy の制定・改版だけは必ず人間**（AI は draft 提案まで、発行不可）。
「自分の枠を自分で書き換えない」。

---

## 7. 責務モデル（6 分類）

| 主体 | 責務 |
|---|---|
| AI-owned | 実装・テスト・PR準備・自律実行・auto-approve 発行 |
| Human-owned | **policy 制定・例外裁定・事後監督**（実行前承認から退却） |
| CI-owned | drift 検出・逸脱検知・サーキットブレーカー発火 |
| Workflow-owned | DoD・学習ループ・昇格予算管理 |
| **Policy-owned** | 事前定義された自律許可の裁定（人間でも AI でもない第三主体） |
| **Sensor-owned** | 逸脱検知の責務 |

核心は **Human-owned が「実行前承認」から「メタ統治」へ総入れ替え**され、空席に
Policy-owned が座ること。

---

## 8. PlanGate / RiverReview との関係

| 既存資産 | Arbiter での扱い |
|---|---|
| **PlanGate** | 前提でなく**先行事例**。承認境界・provenance・決定論・HO の**設計哲学のみ参照**。契約・実装は継承しない。最大の遺産は**失敗履歴（INC群・HO由来・provenance ギャップ）＝Arbiter の threat model 初期値** |
| **RiverReview** | **L1 判断実行を委譲**。versioned skill / W チェック / riverbed memory を活用。外部依存（CLI 公開・verify ゲートの成熟がクリティカルパス） |

> Arbiter は PlanGate の延長（v9 / 2.0）ではなく**独立プロジェクト**。同一リポジトリに
> 同居させると in/on の契約が混在し承認境界が二重定義になるため、別リポジトリ・別名で
> 建てる。PlanGate は freeze（参照実装・生きた教師）として残す。

---

## 9. L0 はゼロから設計する理由

既存ガバナンス（PlanGate L0）は「人間が実行ループの中にいる」前提に最適化された契約。
Arbiter は前提が違う（人間はループの上）。よって:

- **継承するのは L0-メタ（設計哲学）**: 境界・provenance・決定論で自律を統制する思想。
- **作り直すのは L0-契約**: 責務モデル / 承認の時制 / 境界の挙動 / mode 判定。
- 制御の極性が反転する（block → flow）ため、実行エンジンも別物。

---

## 10. ロードマップ（並走期前提）

```text
Phase 0  哲学抽出     PlanGate threat model 移植 / L0 設計哲学の明文化 / 勝利条件定義
Phase 1  心臓         L2 裁定層を薄く実装（二分ルール＋policy＋provenance 発行）
Phase 2  PoC          1 領域（最低リスク帯）で flow→detect→escalate の存在証明
Phase 3  L1 接続      RiverReview 成熟に合わせ判断実行を委譲
Phase 4  拡張         L3 自律オーケストレーション / L4 学習閉ループ
Phase 5  解禁判定     policy maturity で領域ごと on-the-loop 委譲を拡大（人間が判定）
並走期   全期間       Arbiter が存在証明を超えるまで PlanGate が本番統制を担う
```

**最初の一手**: 第1コミットは実装でなく「threat model 移植 / L0 設計哲学 / 勝利条件」の
ドキュメント。

---

## 11. non-goals

- 既存ツールの全機能カバー（valley of death を招く）
- レビューエンジンの内蔵（L1 は RiverReview 委譲・再発明しない）
- 人間承認ゼロの即時実現（policy maturity が満ちるまで保留）
- 承認境界の緩和（touches-boundary は常に同期ブロック固定）
- L5 コンテキスト基盤の先行実装（PoC が極性反転を証明してから）

---

## 12. 未解決の問い

- Q1: Arbiter は OSS か。PlanGate / RiverReview の OSS 戦略との関係。
- Q2: L2 の policy 言語の表現（YAML / DSL / RiverReview skill 流用）。
- Q3: Phase 3 の RiverReview 外部依存律速。内製フォールバックを持つか。
- Q4: 並走期に PlanGate と Arbiter の統制が衝突したらどちらが勝つか。
- Q5: policy maturity の定量指標（eval baseline 接続の具体）。
- Q6: L1 を RiverReview 単独に依存するか、複数レビューア抽象に開くか。

---

## 13. 一行サマリ

> **Arbiter ＝ AI を走らせたまま安全な枠に保ち、二重判定で逸脱だけを人間に昇格する、
> 枠内自律 AI 開発の裁定ランタイム。判断実行は RiverReview に委ね、PlanGate の設計哲学と
> 失敗の記憶を threat model として継承する、独立プロジェクト。**

---

## 付録: 関連

- ブレストログ: `2026-06-11-governed-autonomy-river-review.md`（§1-11）
- 先行事例: PlanGate（承認境界 / provenance / HO / mode の設計哲学）
- L1 委譲先: RiverReview（versioned skill / W チェック / riverbed memory）
- 参照: AirCloset cortex（Zenn @aircloset: 91824e55b7fc9c / d416342f46f16b / f6c990989e60d4）
