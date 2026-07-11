# ai-loop-workflow — コンセプト定義

> **Status**: Phase 0 ドキュメント（2026-07-01）。PoC 段階の構想固定。確定仕様・実装方針ではない。
> **置き場所**: docs/ai/ai-loop/（PlanGate リポジトリ内 PoC 用サブディレクトリ）
> **名称**: ai-loop-workflow（旧称: Arbiter-workflow、2026-07-02 改称）。
> 「Arbiter」は本 workflow の L2 裁定エンジン（部品）の名称として存続する。

---

## 1. Arbiter とは何か

**Arbiter** は、**AI を走らせたまま安全な枠に保ち、逸脱だけを人間に昇格する**、
枠内自律（governed autonomy）AI 開発の**裁定ランタイム**。ai-loop-workflow
全体では PlanGate の WF-00〜03・C-1・C-2 を共通利用し、**Arbiter は C-3
（人間の計画承認）を置換する C-3' として動作する**
（位置づけの詳細は
[`docs/workflows/ai-loop/00_concept.md`](../../workflows/ai-loop/00_concept.md) §3）。

動作の核心は 3 ステップ:

```text
flow      : 低リスク変更は人間承認を待たずに裁定まで流す（Arbiter の裁定を経る）
detect    : 流れる変更を二重判定（W チェック 2 モデル）で逸脱検知
escalate  : 逸脱（2 モデル不一致 / 承認境界接触 / critical）だけ人間へ昇格
            合意 clean は auto-approve + provenance 刻印
```

人間は「各実行の承認者」をやめ、「**枠（policy）の制定者・例外の裁定者・事後の監督者**」になる。

### 一行サマリ

> Arbiter = AI を走らせたまま安全な枠に保ち、二重判定で逸脱だけを人間に昇格する、
> 枠内自律 AI 開発の裁定ランタイム。

### 目的（なぜ PlanGate リポジトリ内で PoC するか）

Arbiter は、PlanGate で積み重ねた統制資産 — 失敗履歴・INC 群（threat model
初期値）、HO（Hardening Override）・承認境界・provenance・決定論の設計哲学 —
を継承し、堅牢な on-the-loop モデルを構築することを目的とする。
本 PoC を独立リポジトリではなく PlanGate リポジトリ内で行う本質的な理由は、
これらの資産が**ここにしか存在しない**ためである。詳細な資産分類は
[`docs/ai/ai-loop/asset-inventory.md`](./asset-inventory.md) を参照。

---

## 2. PlanGate との関係

Arbiter は PlanGate の延長（v9 / 2.0）ではなく、**次世代検証プロジェクト**として位置づける。

| 項目 | PlanGate | Arbiter |
|------|----------|---------|
| 人間の役割 | ループの中（in-the-loop）= 実行前承認者 | ループの上（on-the-loop）= 枠の制定者・例外裁定者 |
| 承認の時制 | 実行前 | 逸脱検知時 |
| 制御の基本姿勢 | block until approved | flow → detect → escalate |
| 現在の位置づけ | 本番統制を担う（並走期全体） | PoC 段階の独立プロジェクト |
| AI 責務の終点 | PR 作成まで（C-4 は人間） | **merge-ready**（CI green + AI レビュー指摘対応完了）まで一気通貫（[`00_concept.md`](../../workflows/ai-loop/00_concept.md) §3.3） |

### 配置方針（Phase 0 判断）

構想（`arbiter-vision.md` §8）では「別リポジトリ」を推奨している（同一リポジトリに同居すると
in/on の契約が混在し承認境界が二重定義になるため）。

ただし、CLI 非依存設計への移行方針により、**まず docs/ 層で PoC を進める**。
PlanGate 本番は**並走期全体で in-the-loop を維持**する。PoC の結果に応じて独立リポジトリへの移行を判断する。

### L0 をゼロから設計する理由

PlanGate L0（既存の統制契約）は「人間が実行ループの中にいる」前提に最適化された契約。
Arbiter はその前提が異なる（人間はループの上）ため、L0 は2層に分けて扱う：

- **継承するのは L0-メタ（設計哲学）**: 境界・provenance・決定論で自律を統制する思想。
- **作り直すのは L0-契約**: 責務モデル / 承認の時制 / 境界の挙動 / mode 判定。

制御の極性が反転する（block → flow）ため、実行エンジンも別物。

---

## 3. 検証スコープ（変更可否の境界）

> **この制約は plangate 本体では Phase 1 移行（#807）後も据え置きの不変条件**
> （`docs/workflows/ai-loop/00_concept.md` Phase 1 節参照。なお本節の Phase 1 以降等の
> 番号は構築フェーズ番号であり、#807 のデプロイ段階 Phase 0/1 とは別系）。

### 変更可能な範囲

```text
docs/ai/ai-loop/   配下のみ（新規作成・更新）
docs/workflows/ai-loop/  配下のみ（新規作成・更新、Phase 1 以降）
```

### 変更禁止（読み取り専用・参照のみ）

```text
.claude/rules/              L0 契約正本。in-the-loop 前提の契約を Arbiter が変更しない
docs/ai/*.md                既存の PlanGate ドキュメント（ai-loop/ サブディレクトリを除く）
docs/workflows/*.md         既存のワークフロー定義
bin/plangate                実行エンジン。AI 直接編集不可（HO-core）
schemas/                    バリデーション定義。AI 直接編集不可
.claude/settings*.json      Human-owned 設定
.claude/settings.local.json 同上
CLAUDE.md                   AI-Human 間の基本契約
AGENTS.md                   同上
.github/workflows/          CI/CD 定義。AI 直接編集不可
```

「変更可能なのは `docs/ai/ai-loop/` および `docs/workflows/ai-loop/` 配下のみ。
`.claude/rules/`、`docs/ai/` 既存ファイル、`bin/plangate`、`schemas/`、`CLAUDE.md`、
`AGENTS.md`、`.github/workflows/` は変更禁止。」

---

## 4. flow → detect → escalate の基本フロー

本フローは C-1 PASS・C-2 完了後の **C-3' ゲート**として発火する
（[`00_concept.md`](../../workflows/ai-loop/00_concept.md) §3.2 パイプライン参照）。
W チェックの対象は C-2 通過済みの plan アーティファクト（plan.md /
todo.md / test-cases.md）である。実差分（実装コード）に対する独立判定は
第 2 段の detect（CI/PR 時の AI レビュー。00_concept.md §3.3）が担う。

```text
┌────────────────────────────────────────────────┐
│ AI が変更を生成                                  │
└──────────────────┬─────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────┐
│ [FLOW] boundary チェック                         │
│  • touches-HO? → YES: 即 human escalate         │
│  • touches-HO? → NO: detect フェーズへ           │
└──────────────────┬─────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────┐
│ [DETECT] W チェック（2 モデル非対称）              │
│  Model A: 順方向（設計妥当性「正しく作られているか」）│
│  Model B: 逆方向（adversarial「どう壊れるか」）    │
│                                                 │
│  A=approve & B=approve → 合意 clean             │
│  A=approve & B=reject  → 不一致 → human escalate│
│  A=reject  & B=reject  → 合意 → block           │
└──────────────────┬─────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────┐
│ [ESCALATE / AUTO-APPROVE]                       │
│  • 合意 clean: auto-approve + provenance 刻印   │
│  • 不一致 / touches-HO / critical: human へ昇格 │
└────────────────────────────────────────────────┘
```

> **注（簡略版であることの明示）**: 上図は簡略版であり、
> `A=approve & B=reject`（不一致）は実際には「即 human escalate」ではなく
> **severity 分類**（critical/major → human escalate、minor/low →
> Model C/D 裁定で auto-approve に到達し得る）へ進む。詳細分岐の正本は
> [`docs/workflows/ai-loop/flow-detect.md`](../../workflows/ai-loop/flow-detect.md)
> §3.2〜3.3。

### detect フェーズの入力（L2 入力 4 軸）

W チェックは以下の 4 軸を入力として評価する（Phase 1/2 で Decision table に展開）：

- `boundary`: touches-HO / clean（HO パスに触れるか）
- `lite`: true / false（低リスク要件を満たすか）
- `verdict`: W チェック合意結果（approve-approve / approve-reject / reject-approve / reject-reject）
- `class`: merge を含む / 含まない

`boundary=touches-HO` の場合は残りの 3 軸を無視して即 human escalate。
`boundary=clean` かつ `lite=false`、W チェック不一致（approve-reject）、または merge class を含む変更の場合も human escalate とする。

---

## 5. human-in-the-loop との違い

| 観点 | human-in-the-loop（PlanGate） | human-on-the-loop（Arbiter） |
|------|-------------------------------|------------------------------|
| 承認の時制 | 実行前（block until approved） | 逸脱検知時（flow → detect → escalate） |
| 人間の関与 | 各実行を1件ずつ承認 | 枠の制定・例外の裁定・事後監督 |
| AI の動作 | 承認を待ってから実行 | 枠内では自律実行、逸脱時に停止 |
| ボトルネック | 人的レビューがリニアにしか伸びない | 低リスク帯はボトルネックを回避 |
| 安全装置 | 実行前ゲート | provenance 刻印・逸脱検知・サーキットブレーカー |
| policy 制定 | 都度人間判断 | **policy 制定は永久 in-the-loop**（第0の承認境界） |

### 不変の原則

「**承認境界に触れた瞬間に全部 human に戻る**」。
touches-HO は常に同期ブロック固定（Arbiter でも緩和しない）。

---

## 6. Phase 0 の位置づけ

```text
Phase 0  哲学抽出  ← 現在地
  PlanGate threat model 移植 / L0 設計哲学の明文化 / 勝利条件定義
  成果物: concept.md / asset-inventory.md / ho-paths.md / related-specs.md

Phase 1  心臓
  L2 裁定層を薄く実装（二分ルール + policy + provenance 発行）

Phase 2  PoC
  1 領域（最低リスク帯）で flow→detect→escalate の存在証明

Phase 3  L1 接続
  RiverReview 成熟に合わせ判断実行を委譲

Phase 4  拡張
  L3 自律オーケストレーション / L4 学習閉ループ

Phase 5  解禁判定
  policy maturity で領域ごと on-the-loop 委譲を拡大（人間が判定）

並走期（全期間）
  Arbiter が存在証明を超えるまで PlanGate が本番統制を担う
```

---

## 7. アーキテクチャ（6層）

```text
L5 コンテキスト基盤   任意。コード/docs/DB/インフラを統合グラフ化（AI が辿る燃料）
L4 学習層            判断結果を次の gate に変換する閉ループ（誤検知抑制 / 真指摘の昇格）
L3 自律実行層        非同期フロー・親子並列・self-healing・サーキットブレーカー
L2 裁定層 ★          Arbiter の心臓。二分ルール / policy 評価 / provenance 発行
L1 判断実行層        RiverReview 委譲（versioned skills / gates / W チェック / riverbed）
─────────────────────────────────────────
L0 統制契約層        承認境界 / 責務モデル / HO / mode 判定（on-the-loop 用に新規設計）
```

- **L2 が新規性の中核**。「block until approved」型でなく「flow → detect → escalate」型の決定エンジン。
- **L1 は内製せず RiverReview に委譲**（判断基準を versioned skill 化する既存資産を活用）。
- **L0 はゼロから設計**（既存ガバナンスの設計哲学だけ参照し、契約定義は on-the-loop 用に書き起こす。§2 参照）。

---

## 8. non-goals

- 既存ツールの全機能カバー（valley of death を招く）
- レビューエンジンの内蔵（L1 は RiverReview 委譲・再発明しない）
- 人間承認ゼロの即時実現（policy maturity が満ちるまで保留）
- 承認境界の緩和（touches-HO は常に同期ブロック固定）
- L5 コンテキスト基盤の先行実装（PoC が極性反転を証明してから）

---

## 9. 関連ドキュメント

- `docs/ai/ai-loop/asset-inventory.md` — PlanGate 共通資産の uses/not-uses 分類
- `docs/ai/ai-loop/ho-paths.md` — touches-HO 判定基準リスト
- `docs/ai/ai-loop/related-specs.md` — 既存仕様との関係整理
- [`docs/workflows/ai-loop/00_concept.md`](../../workflows/ai-loop/00_concept.md) §3 — PlanGate フロー共通化と C-3 置換（C-3'）の確定パイプライン・責務範囲
