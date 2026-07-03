# review-feedback-c4-extension — R-NNN 監査表の C-4（PR 段階）拡張仕様

> issue [#689](https://github.com/s977043/plangate/issues/689) の実装仕様。
> 位置づけ: [`docs/workflows/ai-loop/review-feedback-loop.md`](../workflows/ai-loop/review-feedback-loop.md)（#667
> L4 学習層 PoC）の**最小サブセット**。ai-loop-workflow 全体を導入せずに、
> PlanGate 本番フロー（WF-00〜WF-07）の C-4（PR レビュー）指摘だけを
> 追記集約・還元できるようにする。
> **本ドキュメントは非 Hardening Override（HO）**。HO 対象の
> [`.claude/rules/working-context.md`](../../.claude/rules/working-context.md) /
> [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md)
> への実反映は [`scripts/apply-rnnn-c4-extension.sh`](../../scripts/apply-rnnn-c4-extension.sh)
> が dry-run で差分提示し、**Human が `--apply` で実適用**する
> （[`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md) の
> AI-owned / Human-owned 境界に従う）。

## 背景

[`working-context.md`](../../.claude/rules/working-context.md) の R-NNN 監査表
（追記専用・squash/rebase 耐性）は現在 **C-2（plan ゲート外部レビュー）のみ**
を対象にしている。下流リポジトリ（PocketEitan）の実運用では、C-4（PR 段階）
のレビュー bot（gemini-code-assist 等）が継続的に high severity の指摘を出して
おり、以下 3 つの問題が生じている（issue #689 背景を参照）。

1. C-4 指摘は同一 PR 内で修正されるが、squash 後に「指摘→反映」の証跡が
   監査表に載らず切れる
2. C-2（Codex 等）と C-4（bot）で同一欠陥を二重検出する無駄が発生する
3. C-4 で頻出する指摘パターンが、次回の C-1 / V-1 チェック観点へ還元される
   仕組みがない

## 1. P-NNN 監査表（C-4 指摘の追記専用集約）

### 1.1 ID 体系（R-NNN との区別）

| ID prefix | 対象フェーズ | 発生源 | 正本 |
|-----------|------------|--------|------|
| `R-NNN` | C-2（plan ゲート外部レビュー） | 外部 AI レビューア（Codex 等） | working-context.md 既存節 |
| `P-NNN`（新設） | C-4（PR 段階レビュー） | レビュー bot（gemini-code-assist 等）/ 人間レビュアー | 本節 |

`R-NNN` と `P-NNN` は独立した採番系列とする（フェーズが異なるため同一連番に
すると「どの段階の指摘か」が ID から読み取れなくなる）。両者とも
`review-external.md` に**追記専用で集約**する（C-2 指摘との集約先を分けない。
1 PBI の指摘履歴を 1 ファイルで追える状態を維持する）。

### 1.2 監査表フィールド

```text
| P-NNN | source(bot/human) | severity | reflected_in(commit) | status |
```

| フィールド | 値域 | 説明 |
|-----------|------|------|
| `P-NNN` | `P-001`, `P-002`, ... | PBI 内で単調増加、squash 後も欠番を埋めない（追記専用） |
| `source` | `bot` \| `human` | 指摘の発生源。`bot` はレビューツール名を括弧書きで併記（例: `bot(gemini-code-assist)`） |
| `severity` | `critical` \| `major` \| `minor` \| `info` | [`review-principles.md`](../../.claude/rules/review-principles.md) §3 の 4 段階定義に従う（別軸を作らない） |
| `reflected_in` | commit SHA \| `n/a` | 反映コミット。指摘が却下された場合は `n/a` + `notes` に却下理由 |
| `status` | `open` \| `reflected` \| `rejected` \| `duplicate(R-NNN)` | `duplicate(R-NNN)` は §3 の二重検出時の記録方法 |

指摘ゼロの PR でも「指摘なし」を明示記録する（R-NNN 節と同じ監査連続性の
原則）。

### 1.3 反映タイミング

C-2/R-NNN が「plan 本体への 1 回確定反映」を必須とするのに対し、C-4/P-NNN は
**PR 内での実装修正コミットへの反映**であるため、確定反映の概念を separate に
持たない。指摘発生 → 修正コミット → `reflected_in` に SHA 記録、の 1 ステップ
で完結する。squash マージされる場合は、squash 前の最終コミット SHA を
`reflected_in` に記録してから squash する（squash 後は個別コミットが失われる
ため、記録は squash 前に行う）。

## 2. 頻出指摘の観点還元（3-strike 手順）

[`review-feedback-loop.md`](../workflows/ai-loop/review-feedback-loop.md) の
6 ステップフロー（収集→分類→還元先判定→反映→事前適用→効果測定）の**最小版**。
ai-loop-workflow 全体を導入せずに、PlanGate 本番フローで使える軽量手順として
以下を定義する。

### 2.1 手順

1. **収集**: `review-external.md` の `P-NNN` 監査表に指摘を都度記録する（1.2 節）
2. **パターン検知**: 同一パターン（同種の欠陥カテゴリ、例: 「エラーハンドリング
   不足」「stale state」「localStorage/SSR 起因」）の指摘が **3 回**
   （`P-NNN` 3 件以上、PBI 横断でも可）観測された時点で還元候補とする
3. **還元先判定**: 指摘内容に応じて以下いずれかへ 1 行追加する
   - 実装観点（コーディング時に気をつけるべき点） →
     [`self-review`](../../.claude/skills/self-review/SKILL.md) スキルの該当
     Phase、または [`plan-review-readiness-gate.md`](./plan-review-readiness-gate.md)
     の該当セクション（§7〜§9 を参照。既存の「シェル/ドキュメント品質観点」
     「シェル/Python コード変更観点」節と同様の粒度で追加する）
   - 受け入れ検査観点（動作確認で気をつけるべき点） → V-1 に相当するチェック
     リスト（`acceptance-review` スキル、または `test-cases.md` テンプレート）
4. **反映**: 還元先ドキュメントへの追記 PR を作成する。追記コミットに
   `Refs: P-NNN, P-NNN, P-NNN`（還元契機となった 3 件の ID）を記載する
5. **効果測定**: 次回以降の C-4 で同型パターンが再発しないかを観察する。
   再発した場合は還元が不十分であったシグナルとして扱い、手順 3 の還元先を
   見直す

### 2.2 policy 相当の指摘

還元先が auto-approve 条件・裁定ルールに関わる場合（HO 対象パスの変更を伴う
場合）は、[`review-feedback-loop.md`](../workflows/ai-loop/review-feedback-loop.md)
§2-3 と同じく **Human-owned 固定**。AI は draft 提案までで、適用は Human が
[`scripts/apply-rnnn-c4-extension.sh`](../../scripts/apply-rnnn-c4-extension.sh)
相当の apply スクリプト経由で行う。

## 3. C-2 と C-4 の責務分界

[`review-principles.md`](../../.claude/rules/review-principles.md) §7-bis
（C-2 レビュア責務契約・2 レーン）と整合させ、C-2/C-4 の検出責務を以下のように
分界する。

| フェーズ | 対象 | 主眼 | 実装コード精読 |
|---------|------|------|--------------|
| C-2（設計妥当性レーン） | plan / todo / test-cases / pbi-input | plan の論理・受入基準網羅・スコープ整合 | 原則しない |
| C-2（コードベース整合レーン） | 既存パターン該当箇所 | 「踏襲すべき既存パターン」との不整合 | 該当箇所のみ |
| **C-4（新設・本節）** | **実装コード差分（PR diff）** | **実装済みコードの欠陥検出**（エラーハンドリング・状態管理・SSR 起因等） | **する（PR diff 全体）** |

### 3.1 どちらの検出を正とするか

- **実装コードの欠陥は C-4 を正とする**（§7-bis により C-2 は実装詳細レビューを
  原則行わず V-3/C-4 に寄せる方針と一貫）。C-2 で実装コードへの言及があった
  場合も、確定判断は C-4 の指摘（`P-NNN`）で行う
- **plan の論理・受入基準網羅の欠陥は C-2 を正とする**。C-4 で plan レベルの
  欠陥（そもそも受入基準が漏れている等）が発覚した場合は、`P-NNN` として
  記録しつつ `notes` に「本来 C-2 で捕捉すべきだった」旨を残し、2.1 節の
  還元手順で C-2 レーンの観点強化に繋げる

### 3.2 二重検出時の記録方法

C-2（`R-NNN`）と C-4（`P-NNN`）が同一欠陥を検出した場合:

1. 先に記録された ID を正とする（時系列順。通常は `R-NNN` が先）
2. 後から記録される側は `status = duplicate(R-NNN)` として記録する
   （1.2 節の `status` 値域）。**削除・不記載にしない**（追記専用の原則を
   維持し、二重検出そのものも監査対象として残す）
3. `notes` に重複元 ID と一致箇所（欠陥の種類）を明記する
4. 二重検出が頻発するパターンは 2.1 節の 3-strike 対象としてもカウントする
   （C-2/C-4 どちらの検出であっても、パターンとしての頻度は合算する）

## 4. 実装ステップ（Human 適用フロー）

1. 本ドキュメント（非 HO）で仕様を確定する（本 PR）
2. [`scripts/apply-rnnn-c4-extension.sh`](../../scripts/apply-rnnn-c4-extension.sh)
   を dry-run で実行し、`working-context.md` / `review-principles.md` への
   追記差分をプレビューする
3. Human が `--apply` で実適用する（HO のため AI は実行不可）
4. 適用後、`working-context.md` の R-NNN 節に「P-NNN（C-4 拡張）は本節を参照」
   のクロスリファレンスが入り、`review-principles.md` §7-bis に C-2/C-4
   責務分界（本ドキュメント §3 の要約）が入る

## 参照

- [issue #689](https://github.com/s977043/plangate/issues/689)
- [`docs/workflows/ai-loop/review-feedback-loop.md`](../workflows/ai-loop/review-feedback-loop.md)
- [`.claude/rules/working-context.md`](../../.claude/rules/working-context.md)
- [`.claude/rules/review-principles.md`](../../.claude/rules/review-principles.md)
- [`.claude/rules/responsibility-classes.md`](../../.claude/rules/responsibility-classes.md)
- [`scripts/apply-rnnn-c4-extension.sh`](../../scripts/apply-rnnn-c4-extension.sh)
