# Arbiter Phase 3 — PlanGate 影響評価レポート

> **Status**: Phase 3 ドキュメント（2026-07-02）。
> **位置づけ**: Phase 0〜2 + follow-up の検証結果を踏まえ、「PlanGate 内継続」vs
> 「別リポジトリ分離」vs「中止」の判断材料を提供する。**判定は人間が行う**。
> **出典**: [issue #659](https://github.com/s977043/plangate/issues/659)
> **パス表記**: 本レポート §a の `docs/ai/arbiter/`・`docs/workflows/arbiter/` は
> Phase 0〜3 当時の実パス（監査証跡のため改変しない）。2026-07-02 に
> `docs/ai/ai-loop/`・`docs/workflows/ai-loop/` へ改称された（issue #672）。

---

## a. PlanGate への変更差分

### a.1 一次確認コマンド

```sh
git log --oneline origin/main -- docs/ai/arbiter/ docs/workflows/arbiter/
git show <sha> --stat
git show <sha> --name-only
```

上記コマンドで検出された Arbiter 関連マージ済みコミットは以下の 5 件（新しい順）。

### a.2 変更ファイル一覧（PR 番号つき）

| PR | コミット | 変更ファイル | `.claude/rules/` / `docs/ai/`（arbiter 以外）影響 |
|----|---------|-------------|------------------------------------------------|
| #660 (Phase 0) | `435d84f` | `docs/ai/arbiter/asset-inventory.md`（新規）、`docs/ai/arbiter/concept.md`（新規）、`docs/ai/arbiter/ho-paths.md`（新規）、`docs/ai/arbiter/related-specs.md`（新規）、`docs/working/TASK-0655/TASK-0655-c3-review.html`（新規）、`docs/working/_audit/skip-decision-log.jsonl`（追記） | なし |
| #661 (Phase 1/2a) | `fbe6c6e` | `docs/ai/arbiter/arbiter-policy.md`（新規）、`docs/workflows/arbiter/00_concept.md`（新規）、`docs/workflows/arbiter/flow-detect.md`（新規） | なし |
| #662 (Phase 2b) | `c8c8fdb` | `docs/ai/arbiter/arbiter-policy.md`、`docs/ai/arbiter/concept.md`、`docs/ai/arbiter/ho-paths.md`（以上 3 件は既存 arbiter ファイルの改訂）、`docs/workflows/arbiter/decision-table.md`（新規）、`docs/workflows/arbiter/flow-detect.md`、`docs/working/discussions/2026-06-11-arbiter-vision.md`（新規）、`docs/working/discussions/2026-06-11-governed-autonomy-river-review.md`（新規） | なし |
| #665 (Phase 2 follow-up) | `072ab10` | `docs/ai/arbiter/concept.md`、`docs/workflows/arbiter/00_concept.md`、`docs/workflows/arbiter/flow-detect.md` | なし |
| #668 (L4 PoC) | `b947fb8` | `docs/workflows/arbiter/decision-table.md`、`docs/workflows/arbiter/flow-detect.md`、`docs/workflows/arbiter/review-feedback-loop.md`（新規） | なし |

**変更ファイル数**: 上記 5 PR の変更ファイルを実体（重複除去）で数えると、
`docs/ai/arbiter/` 5 件（arbiter-policy / asset-inventory / concept / ho-paths /
related-specs）、`docs/workflows/arbiter/` 4 件（00_concept / decision-table /
flow-detect / review-feedback-loop）の **計 9 ファイル**。加えて `docs/working/`
配下に一時生成物 4 件（TASK-0655 レビュー html、audit ログ追記、discussion ログ
2 件）が付随する。

### a.3 `.claude/rules/` / `docs/ai/` 既存ファイルへの影響

**影響なし。** 上記 5 コミットすべてで `git show <sha> --name-only` を実行し、
`docs/ai/arbiter/` と `docs/workflows/arbiter/` 以外に変更が及ぶ範囲は
`docs/working/`（作業ログ・討議ログ・監査ログの新規追加のみ）に限定されることを
確認した。`.claude/rules/*.md`・`docs/ai/*.md`（arbiter 以外の既存正本）・
`docs/workflows/*.md`（arbiter 以外の既存正本）・`bin/plangate`・`schemas/*`・
`.github/workflows/*` への変更は 5 コミット中いずれにも存在しない。

### a.4 Arbiter 起点で PlanGate 側に還元された改善（副作用ではなく便益）

PR #663（`docs: plan-review-readiness-gate.md にドキュメント仕様変更レビュー観点を追加`）
と PR #666（`feat(skill): self-review にシェル/ドキュメント品質観点 + 文章品質
チェックを追加`）は、Arbiter PoC 中の PR レビュー（Gemini/Copilot 指摘対応）から
派生した **PlanGate 側の恒久的な品質改善**であり、Arbiter PoC 自体の変更スコープ
には含めない。これらは「Arbiter が PlanGate 本体を意図せず変更した副作用」では
なく、「Arbiter の検証活動が PlanGate の C-1/C-3 観点を強化する形で還元された便益」
として区別する。

---

## b. 分岐判断基準

### b.1 「別リポジトリ分離」トリガー条件（3 件以上）

| # | トリガー条件 | 根拠 |
|---|------------|------|
| 1 | **実行エンジン実装が必要になった** | `concept.md` §2 のとおり、PlanGate は block-until-approved、Arbiter は flow→detect→escalate と制御極性が逆。docs 層の PoC を超えて実行コード（hook / CLI）を書く段階に入ると、同一リポジトリ内に 2 つの相反する L0 契約が同居し、承認境界が二重定義になるリスクが顕在化する |
| 2 | **L0 契約が `responsibility-classes.md` と整合できなくなった** | Arbiter L0（`arbiter-policy.md`）は PlanGate の責務 4 分類（AI/Human/CI/Workflow-owned）を前提に「detect/escalate 判断基準のみ追加」する設計。この前提が崩れ、責務 4 分類そのものの改訂を要求する事態になった場合は分離が必要 |
| 3 | **PlanGate 本番への副作用が検出された** | `a.3` で確認したとおり現状は副作用ゼロ。今後 `.claude/rules/`・`docs/ai/` 既存正本・`bin/plangate`・`schemas/` のいずれかに変更が及んだ場合、PoC の隔離が破綻したとみなす |
| 4 | **provenance / severity 判定の実装が PlanGate の EH（Enforcement Hook）体系と競合する** | `decision-table.md` の provenance スキーマは PlanGate 側の課題（issue #420 EH-3 発行元検証）と同型の未解決課題を抱える。両者を同一リポジトリで別々に実装すると二重管理・矛盾のリスクがある |
| 5 | **PoC の継続期間が長期化し docs 層のみでの検証に限界が生じた** | `concept.md` §6 のとおり Phase 0 は「まず docs/ 層で PoC」の判断。実装検証（severity 判定器・W チェック自動化等）が必要になった時点で、[`concept.md`](./concept.md) §2 配置方針に記録された当初推奨（別リポジトリ）に立ち返るべき局面 |

### b.2 「PlanGate 内継続」維持条件

| # | 条件 |
|---|------|
| 1 | 変更が `docs/ai/arbiter/` と `docs/workflows/arbiter/` 配下の docs 層のみで完結している |
| 2 | PlanGate 本番（`.claude/rules/`・`docs/ai/` 既存正本・`bin/plangate`・`schemas/`・`.github/workflows/`）への副作用がゼロである |
| 3 | Arbiter L0 policy が PlanGate 既存契約（[`core-contract.md`](../core-contract.md) > [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md)）の優先順位を明示的に維持している |

---

## c. 継続 / 分岐 / 中止の 3 択

> **判定は人間が行う。** 以下は各選択を支持する条件の整理であり、AI が判定を確定
> するものではない。

| 選択肢 | 選択を支持する条件 |
|--------|------------------|
| **継続**（PlanGate 内 docs 層 PoC を継続） | `b.2` の維持条件を全て満たし、かつ `b.1` のトリガー条件がいずれも未発生。次フェーズ（severity 判定主体の確定・lite 低リスク帯の定義等）も docs 層の仕様策定で完結する見込みがある |
| **分岐**（別リポジトリへ移行） | `b.1` のトリガー条件のいずれか 1 件以上が発生、または実行コードの実装フェーズに入ることが決定した。`concept.md` §2 の当初推奨（別リポジトリ）に立ち返る |
| **中止**（Arbiter PoC を終了） | PoC の検証目的（governed autonomy の実現可能性）が Phase 0〜3 の範囲で否定的な結論に至った、または PlanGate 側の優先度変更により継続コストが便益を上回ると人間が判断した |

---

## d. 未解決リスク（5 件）

| # | リスク | 影響度 | 対応 Phase | 状況 |
|---|--------|--------|-----------|------|
| 1 | `lite` 判定の具体基準が未定義（低リスク帯の閾値が Phase 1 以降 TBD） | 中 — flow フェーズの中核条件が未確定のため、detect フェーズの実効性を評価できない | Phase 1 | 解消済み（2026-07-02、[`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md)、issue #674） |
| 2 | `lite=true` の要件に「可逆であること」を含めるかが未決 | 中 — CB-1（Circuit Breaker）の巻き戻し条件「不可逆操作を除く」との整合が取れていない | Phase 1 | 解消済み（2026-07-02、[`lite-criteria.md`](../../workflows/ai-loop/lite-criteria.md) §2 可逆性要件、issue #674） |
| 3 | severity 分類の判定主体が未確定（Model B の reject 理由から導出するか、専用分類器を置くか） | 中 — `flow-detect.md` §3.2 に「Phase 1 論点（未確定）」として明記済み | Phase 1 | 解消済み（2026-07-02、[`flow-detect.md`](../../workflows/ai-loop/flow-detect.md) §3.2、issue #674） |
| 4 | `ho-paths.md` の `approvals/*.json` glob が実際の配置 `docs/working/TASK-XXXX/approvals/*.json` にマッチしない可能性 | 高 — HO 判定の実効性に直結する。マッチしない場合、承認トークンパスへの変更が touches-HO として検出されない | Phase 2 実装移行時（現状は docs 層のみのため実害なし） | 解消済み（[`ho-paths.md`](./ho-paths.md) glob 修正、issue #674） |
| 5 | provenance の発行元検証（`issued_by` は自己申告、署名等は別途） | 高 — PlanGate 側の未解決課題（issue #420 EH-3 発行元検証）と同型。Arbiter が実装段階に入る前に PlanGate 側の解決方針と整合させる必要がある | Phase 2 実装移行時 / PlanGate issue #420 の解決と連動 | 未解消 |

**件数**: 5 件（0 件ではない）。

---

## e. 関連ドキュメント

- [`docs/ai/arbiter/concept.md`](./concept.md) — コンセプト定義（§2 配置方針の判断根拠）
- [`docs/ai/arbiter/arbiter-policy.md`](./arbiter-policy.md) — Arbiter L0 policy
- [`docs/ai/arbiter/ho-paths.md`](./ho-paths.md) — HO パス集約リスト
- [`docs/ai/arbiter/asset-inventory.md`](./asset-inventory.md) — PlanGate 共通資産棚卸し
- [`docs/ai/arbiter/related-specs.md`](./related-specs.md) — 既存仕様との関係整理
- [`docs/workflows/arbiter/00_concept.md`](../../workflows/ai-loop/00_concept.md) — ワークフローコンセプト
- [`docs/workflows/arbiter/flow-detect.md`](../../workflows/ai-loop/flow-detect.md) — flow/detect フロー定義
- [`docs/workflows/arbiter/decision-table.md`](../../workflows/ai-loop/decision-table.md) — Decision table・provenance schema
- [`docs/workflows/arbiter/review-feedback-loop.md`](../../workflows/ai-loop/review-feedback-loop.md) — レビュー指摘還元閉ループ
- [`.claude/rules/responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) — 責務 4 分類正本
