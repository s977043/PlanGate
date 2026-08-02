---
name: acceptance-review
description: "実装結果を受け入れ条件（AC）と照合し、適合 / 不足を明確化する。Use when: WF-05 Verify & Handoff で要件適合確認が必要な時、PR の受入基準チェックを網羅的に実施したい時。"
---

# Acceptance Review

実装差分と AC（受け入れ条件）を突き合わせ、**適合 / 不足 / 保留** を判定する Skill。
PlanGate v8.3 では、本 Skill の出力が `handoff.md § 1` の正本となる（必須 6 要素の 1 つ）。

## カテゴリ

Review

## 想定 Phase

WF-05 Verify & Handoff

## 参照解決順（導入先で必ずこの順に探す）

本 Skill が参照する `.claude/rules/*.md` と `docs/**` は上流リポジトリ基準の相対パス。
導入先ではそのままでは解決できないものがあるため、**次の順で探索する**:

1. 導入先リポジトリの相対パス（例: `.claude/rules/working-context.md`）
2. 無ければ plugin root 配下（例: `<plugin_root>/rules/working-context.md`）。
   `<plugin_root>` は **Bash で `ls "${CLAUDE_PLUGIN_ROOT}/rules/"` を実行して展開・確認した
   絶対パス**（Read ツールは絶対パスを要求し環境変数を展開しないため、`${CLAUDE_PLUGIN_ROOT}/...`
   という文字列をそのまま Read しない）。変数が空・未設定ならキャッシュを glob で推測せず 3 へ進む
3. どちらにも無い場合は **「正本 `<path>` を参照できなかった」と明示**し、推測で内容を補わない

| 参照 | `install.sh --claude` 経由 | plugin（Claude marketplace）経由 | Codex 経由 |
|------|---------------------------|----------------------------------|-----------|
| `rules/*.md` | `.claude/rules/` に着地（解決可） | `<plugin_root>/rules/` で解決 | **未配置（解決不可 → 手順 3 へ）** |
| `docs/**` / `schemas/**` | コピー対象外（解決不可） | バンドル対象外（解決不可） | 未配置（解決不可） |

`install.sh --claude` のコピー対象は `agents` / `skills` / `commands` / `rules` の 4 ディレクトリ
のみ。Codex 経由（`install_codex()`）は `install-plangate-skills.sh` を呼ぶだけで **skills しか
配置されない**ため、rules 参照は解決順 1・2 とも成立せず必ず手順 3 に落ちる。

> **手順 3 に落ちても判定基準は緩めない**: 本 Skill の「判定基準」「禁止」節が
> evidence 要件の代替正本になる。**evidence なき PASS は正本を参照できないことを
> 理由に許容してはならない**（Iron Law #3 / #4）。参照できなかった正本は
> `handoff.md § 1` に「正本 `<path>` 未参照」として明示する。

## PlanGate v8.3 整合（必読）

本 Skill は v8.3 eval framework の以下 3 観点と直接結び付く。判定結果はこれらの観点ラベルで分類すること。

| eval 観点 | 出処 | release blocker |
|----------|------|----------------|
| **AC coverage** | [`eval-cases/ac-coverage.md`](../../../docs/ai/eval-cases/ac-coverage.md) | NO（WARN）|
| **verification honesty** | [`eval-cases/verification-honesty.md`](../../../docs/ai/eval-cases/verification-honesty.md) | **YES** |
| **format adherence** | [`eval-cases/format-adherence.md`](../../../docs/ai/eval-cases/format-adherence.md) | **YES**（schema 準拠率 < 95%）|

### Iron Law との関係

- **Iron Law #3 (NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE)**: 本 Skill の判定は必ず実行ログ / コマンド出力 / evidence ファイルに紐付ける。「PASS と思われる」「動いているはず」は禁止。
- **Iron Law #4 (NO HIDING FAILURES OR UNCERTAINTY)**: 失敗・未実行・未検証の AC は「不足 / 保留」として明示し、verification honesty FAIL を避ける。

## 入力

- AC 一覧（`acceptance-criteria-build` の出力 / `pbi-input.md` の AC セクション / `parent-plan.md` の parent-AC）
- 実装差分（コード変更 + `known-issues-log` の出力）
- テスト実行結果 / CI 結果 / `evidence/` ディレクトリのログ
- schema validation 結果（[`schemas/acceptance-result.schema.json`](../../../schemas/acceptance-result.schema.json) で validate 可能な JSON 出力対象）

## 出力

要件適合確認結果（`handoff.md § 1` に統合される）。可能な限り [`acceptance-result.schema.json`](../../../schemas/acceptance-result.schema.json) に準拠する JSON も併記する。

### 必須要素

- AC ごとの **PASS / FAIL / WARN** 判定（PlanGate では適合 / 不足 / 保留 を PASS / FAIL / WARN で正規化）
- 各判定の **適合根拠**（テストケース ID / evidence ファイルパス / 実行ログ抜粋）
- FAIL / WARN 時の **フォローアップ計画**（次タスク / V2 候補へ振り分け）
- **V2 候補**（scope 外と確認された項目）
- **schema 準拠率**（生成 artifact が schemas/ で validate される割合、format adherence 観点）

### 表形式（handoff §1 と整合）

| 受入基準 | 判定 | 根拠 / コメント |
|---------|------|---------------|
| AC-1 | PASS / FAIL / WARN | テスト結果 / evidence へのリンク |
| AC-2 | ... | ... |

**総合**: `<N>/<M> 基準 PASS`
**FAIL / WARN の扱い**: V1 で許容する理由、V2 候補への移行等

### 親 PBI（Orchestrator Mode）の場合

子 PBI の `covers_parent_ac` フィールドから parent-AC × child PBI のカバレッジ表を作成し、未カバー parent-AC を Gap として明示する（`integration-plan.md` の Gap Tracking と同期）。

## 判定基準

| 判定 | 条件 |
|------|------|
| **PASS** | AC を満たすことを示す evidence（テストログ / 動作確認 / 出力例）が存在 |
| **FAIL** | AC を満たさない / evidence なし / 未実装 |
| **WARN** | 部分的に満たすが、scope の範囲で許容（理由を明記）|

**禁止**:

- evidence なき PASS（verification honesty FAIL → release blocker）
- 「概ね動く」「だいたい OK」の主観判定
- FAIL を WARN に格下げして release blocker を回避（Iron Law #4 違反）

## UI 変更時の visual evidence 規約（UI 専用 V-1 / #797）

UI 変更を含む PR の V-1 では、**PASS 判定でも visual evidence を必須**とする。

> **一般規約への明示的上書き**: `.claude/rules/working-context.md`（→ fallback
> `<plugin_root>/rules/working-context.md`。「参照解決順」参照）の evidence
> 保管ルール（「PASS 判定: evidence は省略可」）に対する**明示的上書き**である。
> UI の見た目の正しさはテストログだけでは示せないため、UI 変更に限り PASS でも
> evidence を要求する。
>
> 正本がどちらでも解決できない環境（Codex 経由等）でも、**本節の要求（UI 変更は
> PASS でも visual evidence 必須）はそれ単体で成立する**。上書き元を確認できなかった
> 場合は `handoff.md § 1` にその旨を記録したうえで、本節を適用する。

### 発火条件

`review-gate` Skill レーン 5 と**同一の発火ヒューリスティック**を参照する
（UI 系パス・拡張子の例示リストと「曖昧時は発火側に倒す」安全側規則。詳細:
`review-gate` Skill の `references/ui-ux-lane.md` §1）。

### 必須 evidence（`evidence/verification/` に保存）

- **before/after スクリーンショット**（変更対象のコンポーネント / 画面）
- **主要ブレークポイント**のスクリーンショット（最低 PC / SP の 2 点）
- **E2E 実行結果**（該当フローの E2E がある場合。ログ or レポート）

### visual regression 業界標準（運用指針）

- **baseline は Git 管理**し、**意図的な UI 変更は同一 PR で baseline を更新**
  する（変更を明示的・レビュー可能にする）
- **コンポーネント単位のスクリーンショットを優先**（full-page は重要フローのみ）
- 動的コンテンツ（timestamp・アバター等）は**マスク**し、**アニメーションは
  無効化**（例: Playwright の `animations: 'disabled'`）
- 実行は PR 時のみ（毎 commit ではない）。描画一貫性は CI / Docker 等の固定
  環境を前提とする

### 取得不能時（unavailable 記録で WARN）

Playwright 等のスクリーンショット手段が環境に無い場合は、
`docs/ai/external-reviewer-interface.md` §10（`review-principles.md` §7-ter）と
同型の **unavailable 記録**（実行不可の理由 / 代替検証 / 未充足リスク）を残して
**WARN** とする。**黙って「該当なし」にしない**（理由・代替・リスクが空欄の
unavailable は無効 = FAIL）。

### doc 専用 V-1 との関係

doc 専用 V-1（`.claude/rules/mode-classification.md` → fallback
`<plugin_root>/rules/mode-classification.md` の doc-light モード内。「参照解決順」参照）とは
**発想が対称・placement は意図的に非対称**: doc 版は mode 機構に結線するため
HO（Hardening Override）対象の rule 層に置かれ、UI 版（本規約）は skill 層 =
非 HO・ソフト強制として置かれている。

正本を解決できない環境では doc-light 側の詳細を推測で補わず、本節は
「UI 版は skill 層のソフト強制である」という本 Skill 内で完結する事実のみを根拠に読む。

### Optional: Figma ↔ 実装の計測突合

環境に Figma MCP + Playwright MCP がある場合のみの optional 手順として、
`review-gate` Skill の `references/ui-ux-lane.md` §5 を参照（必須にしない）。

## 使い方

1. WF-05 で `qa-reviewer` Agent が本 Skill を呼び出す
2. AC 一覧 + 実装 diff + evidence を入力に判定実行
3. 出力を `handoff.md § 1 要件適合確認結果` に統合
4. release blocker（verification honesty FAIL / format adherence FAIL）が発生したら直ちに `qa-reviewer` から `orchestrator` にエスカレーション

## 関連 Skill

- [`acceptance-criteria-build`](../acceptance-criteria-build/SKILL.md): AC 一覧生成（本 Skill の前段）
- [`known-issues-log`](../known-issues-log/SKILL.md): 既知課題抽出（handoff §2、本 Skill と並走）
- [`diff-audit`](../diff-audit/SKILL.md): 実装側の事前 diff-audit（旧 self-review、17 項目 + Iron Law + 8 eval 観点）

## 関連ドキュメント（PlanGate v8.3）

- Workflow: [`docs/workflows/05_verify_and_handoff.md`](../../../docs/workflows/05_verify_and_handoff.md)
- 親 Rule: Rule 5（最終成果物は handoff に集約）— `.claude/rules/hybrid-architecture.md`
  → fallback `<plugin_root>/rules/hybrid-architecture.md`（上記「参照解決順」）。
  相対リンク `../../rules/hybrid-architecture.md` は **skills と rules が同一 root 直下に
  並ぶ配置でのみ**解決する（`.claude/skills/` ↔ `.claude/rules/` / plugin バンドル内）。
  上流リポジトリの `.agents/skills/` と Codex 導入先の `.codex/skills/` には隣接する
  `rules/` が無いため解決しない
- handoff テンプレート: [`docs/working/templates/handoff.md`](../../../docs/working/templates/handoff.md)
- [`docs/ai/eval-plan.md`](../../../docs/ai/eval-plan.md) — 8 eval 観点（AC coverage / verification honesty / format adherence）
- [`docs/ai/eval-cases/ac-coverage.md`](../../../docs/ai/eval-cases/ac-coverage.md)
- [`docs/ai/eval-cases/verification-honesty.md`](../../../docs/ai/eval-cases/verification-honesty.md)
- [`docs/ai/eval-cases/format-adherence.md`](../../../docs/ai/eval-cases/format-adherence.md)
- [`docs/ai/structured-outputs.md`](../../../docs/ai/structured-outputs.md) + [`schemas/acceptance-result.schema.json`](../../../schemas/acceptance-result.schema.json)
- [`docs/ai/contracts/verify.md`](../../../docs/ai/contracts/verify.md) — verify phase contract
- [`docs/ai/contracts/handoff.md`](../../../docs/ai/contracts/handoff.md) — handoff phase contract
- Iron Law #3 / #4 ([`docs/ai/core-contract.md`](../../../docs/ai/core-contract.md))
