# review-feedback-loop — レビュー指摘の事前チェック還元閉ループ

> 適用ドメイン: Arbiter-workflow（docs/workflows/arbiter/ 配下）のみ
> 非適用: PlanGate 本番フロー（WF-00〜WF-07）
> 位置づけ: L4 学習層（[`concept.md`](../../ai/arbiter/concept.md) §7）の PoC 定義。
> フル実装は Phase 4、本ドキュメントはフロー定義と手動運用（human-operated L4）を先行させる

---

## 1. 目的

PR レビューで受けた指摘を観点として抽出・還元し、次の PR 時には同型の指摘が
事前チェック（self-review / readiness gate / detect フェーズ）で捕捉されている
状態をつくる閉ループを定義する。

真指摘の昇格（gate 観点への反映）と誤検知抑制（レビューボットの false-positive
を抑制する経路）の両方向が L4 の対象である。PoC 段階では誤検知抑制は
定義のみに留め、実装は Phase 4 以降のスコープとする。

---

## 2. 6 ステップフロー

```text
[1] 収集 → [2] 分類 → [3] 還元先判定 → [4] 反映 → [5] 事前適用 → [6] 効果測定
                                                                      │
                                                    再発検出 ─────────┘
                                                  （§2-1 へ戻る）
```

### 2-1. 収集

PR レビュー指摘（外部ボット・人間レビュアー）を指摘 ID（`R-NNN` 方式）付きで
収集する。ID 採番と追記専用集約の方式は
[`working-context.md`](../../../.claude/rules/working-context.md) の
`review-external.md` 節（C-2 指摘の差分管理）を資産として継承する。指摘ゼロの
回でも「指摘なし」を明示記録し、監査の連続性を保つ。

### 2-2. 分類

各指摘を以下の 2 軸で分類する。

| 軸 | 値 | 説明 |
| ---- | ---- | ---- |
| 再発性 | 再発性あり / 一過性 | 同型の指摘が将来の変更でも起こり得るか |
| severity | critical / major / minor / info | [`review-principles.md`](../../../.claude/rules/review-principles.md) §3 の 4 段階定義に従う |

> **注（severity の別軸性）**: ここでの severity は **PR レビュー指摘の分類**であり
> [`review-principles.md`](../../../.claude/rules/review-principles.md) §3（info を含む 4 段階）に従う。
> W チェック不一致の severity 分類（[`flow-detect.md`](./flow-detect.md) §3.2、low を含む 4 段階）とは
> **別軸**であり、値域も異なる。混同しないこと。

一過性（案件固有の一度きりの指摘）は還元不要（§2-3 の第4分岐）に落ちる。

### 2-3. 還元先判定

分類結果を以下の 4 分岐表で還元先へ振り分ける。

| 還元先 | 対象 | 責務 |
| -------- | ------ | ------ |
| skill（例: `self-review`） | 作業手順・チェックリストで捕捉できる指摘 | AI-owned（編集可） |
| gate 観点ドキュメント（例: `plan-review-readiness-gate.md`） | 計画・レビュー観点で捕捉できる指摘 | AI-owned（編集可） |
| policy | auto-approve 条件・裁定ルールに関わる指摘 | **Human-owned 固定**（第0の承認境界 = [`arbiter-policy.md`](../../ai/arbiter/arbiter-policy.md) §6） |
| 還元不要 | 一過性・案件固有 | 記録のみ |

policy への還元候補は AI が draft 提案までしか行えない。発行・適用は
Human-owned 固定であり、本ステップでもその境界は緩和しない（§5 参照）。

### 2-4. 反映

還元先判定に基づき、還元 PR を作成する。反映結果はトレーサビリティ表として
残す。

| 指摘 ID | 還元先 | commit |
| --------- | -------- | -------- |
| R-NNN | `<skill or gate doc path>` | `<commit SHA>` |

### 2-5. 事前適用

次回 flow フェーズ前の pre-check（self-review / readiness gate）で、還元した観点が
実際に効いていることを確認する。

### 2-6. 効果測定

次回 PR レビューで同型指摘の再発有無を確認する。再発した場合は還元が
不十分であったシグナルとして扱い、§2-1（収集）へ戻り再度ループを回す。

---

## 3. W チェックとの接続

Model C/D の裁定結果（[`flow-detect.md`](./flow-detect.md) §3.3）は
provenance 経由で L4 学習の入力になる。人間の事後 reject
（[`decision-table.md`](./decision-table.md) CB-1）も学習入力として扱う。
いずれも「二重判定・事後監督で得られた裁定結果を、次回の事前チェックへ
還元する」という本ループの入力源の一種である。

---

## 4. ケーススタディ（2026-07-01〜02 の手動実演）

本フローは issue #667 の起票に先立ち、以下の 3 件のレビュー指摘還元で
**手動で 1 周回った実績**があり、その再現可能化が本ドキュメントの目的である。

| レビュー指摘 | 還元先 | 結果 |
| -------------- | -------- | ------ |
| PR #662 G1〜G4 / C1〜C5（用語・定義・参照） | `plan-review-readiness-gate.md` §8 D-1〜D-5（PR #663） | マージ済 |
| PR #665 R-1〜R-3（助詞・冗長・リンク化） | `self-review` スキル Phase 13 文章品質（PR #666） | レビュー中（2026-07-02 時点） |
| PR #666 指摘 2 件（glob 表記・バックティック） | 即時反映（同 PR 内） | 反映済 |

さらに 2026-07-02 のセッション振り返り（3 系統レビュー: セルフ / 複数エージェント /
Codex）で検出された指摘 7 件を issue #670 で還元しており、本ループの **2 周目**に相当する。

---

## 5. 安全制約

- policy への還元は第0の承認境界（[`arbiter-policy.md`](../../ai/arbiter/arbiter-policy.md) §6）
  により Human-owned 固定。AI は policy draft の提案までしか行えず、発行・適用
  は人間が行う。
- skill / gate への還元であっても、対象が HO パス
  （[`ho-paths.md`](../../ai/arbiter/ho-paths.md)）に触れる場合は human escalate
  へ切り替える。
- 学習ループ自身が承認境界を侵食してはならない（「自分の枠を自分で書き換え
  ない」の L4 版）。還元ループが policy への還元を自己承認する経路を持たない
  ことが本ドキュメントの安全条件である。

---

## 6. 関連ドキュメント

- [`docs/ai/arbiter/concept.md`](../../ai/arbiter/concept.md) — Arbiter の基本概念・L4 学習層（§7）
- [`docs/workflows/arbiter/flow-detect.md`](./flow-detect.md) — W チェック・severity 分類・Model C/D 裁定
- [`docs/workflows/arbiter/decision-table.md`](./decision-table.md) — Decision table・provenance schema・サーキットブレーカー
- [`docs/ai/arbiter/arbiter-policy.md`](../../ai/arbiter/arbiter-policy.md) — 第0の承認境界（§6）
- [`.claude/rules/working-context.md`](../../../.claude/rules/working-context.md) — `review-external.md` R-NNN 方式（資産継承元）
