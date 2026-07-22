# PBI INPUT PACKAGE — TASK-0868

> Issue: [#868](https://github.com/s977043/plangate/issues/868)（サブエージェント委譲に model × effort × role の明示的ルーティングを導入する）
> 作成: 2026-07-22（worktree 実測・裏取り済み。AC は issue verbatim + In scope 対応 1 項）

## Context / Why

上位モデルをオーケストレータに固定し、サブタスクごとに **実行モデル・reasoning effort・役割** を選定理由付きで明示委譲する考え方を、PlanGate の既存委譲基盤（#710 委譲プロトコル / Model Profile / subagent-dispatch）へ**接続する差分**として導入する。新しい委譲機構は作らない（issue 本文の方針）。

実測（2026-07-22・worktree）:

- **model tier は静的 2 tier のみ**: `docs/ai/model-profiles.md` §11（L184〜）が正本。`.claude/agents/*.md` frontmatter は **sonnet 6 / inherit 11**（README 除く 17 agent・実測）。タスク単位のルーティング判断層は存在しない
- **effort のタスク単位指定機構は Claude 側 0 件**: Codex 側は `.codex/agents/*.toml` の `model_reasoning_effort` **静的値**（定型=low / 判断系=medium、§11 写像）のみ。per-dispatch の effort 選択は両ランタイムとも未定義
- **dispatch-template 要素 2 は自由記述まで**: 「なぜこのモデルに格上げされたか」（`dispatch-template.md` L31/L46-50）の一言記載であり、`role × profile × effort × tools × verifier` の構造化契約ではない。`plangate-flow-integration.md` / `outcome-contract.md` に "model" 出現 **0 件**（実測）
- **skills 4 本に model/effort/tier 言及 0**: `.agents/skills/{subagent-dispatch, subagent-team-design, subagent-driven-development, codex-multi-agent}/SKILL.md` の grep 0 件（実測）。ルーティング判断は skill 層にも不在
- **role 正本が dead reference**: `plugin/plangate/rules/subagent-roles.md`（6 ロール定義）は現ツリーに**不存在**（dd9ccab の plugin 自動同期導入以降）だが、`.agents/skills/` の 3 SKILL（subagent-dispatch ×4 行 / subagent-team-design L31 / context-packager L100）とその sync 先（`.claude/skills/` / `.codex/skills/` / `plugin/plangate/skills/`）が参照し続けている（実測）。**role 正本の再建を本 PBI に含める**

## What（Scope）

### In scope

1. **routing contract 正本の新設**: `docs/ai/subagent-delegation/routing-contract.md`（非 HO）。`routing_decision = role × model_profile × reasoning_effort × tool_policy/write_scope × verifier × escalation` の最小スキーマと選定理由（reasons）を定義。issue 検討方針 1 の YAML 形式をベースに、`model-profiles.yaml` と重複する値は再定義せず参照解決とする
2. **role 正本の再建**: 旧 `subagent-roles.md` の 6 ロール（planner / implementer / reviewer / security-reviewer / test-reviewer / documentation-reviewer）を土台に researcher / architect / verifier 系を整理し、`.agents/skills/` 側正本 + sync 供給（#862 の「正本を `.agents/skills/` に置き sync/drift check の担保下へ」の流れと整合）。配置の最終確定は C-3 論点 1
3. **dead reference 解消**: `.agents/skills/` の 3 SKILL（subagent-dispatch / subagent-team-design / context-packager）の `plugin/plangate/rules/subagent-roles.md` 参照を再建後の role 正本へ張り替え（sync で `.claude/skills/` / `.codex/skills/` / `plugin/` へ伝播）
4. **dispatch-template への routing decision 参照欄追加**: 要素 2「格上げ理由」を routing contract 参照へ拡張（自由記述→構造化。既存 8 要素は削らない additive）
5. **plangate-flow-integration へのルーティング判断フロー追記**: mode / role / verifier 要否 / escalation のオーケストレータ判断責務（issue 検討方針 2）と、mode 別の既定値継承 vs 明示必須の境界（検討方針 3: ultra-light/light は mode 既定値許容、standard+write / high-risk / critical は明示必須、critical で unknown profile は fail closed / human escalation）
6. **verifier 分離ルールと escalation 条件の定義**（issue 検討方針 4/5）: high-risk / critical・security・破壊的変更等での実行者/検証者分離原則、retry と model escalation の区別を routing-contract 内に定義
7. **model-profiles §11 への additive 拡張**: 静的 2 tier を「既定値」と位置づけ、routing contract がタスク単位で override する関係を追記（§11 の tier 定義・toml 静的値優先の不変条件は変更しない）
8. **routing 記録フィールド案の定義まで**（issue 検討方針 6 の v1 範囲）: requested/resolved profile・effort・role・reasons・verifier・escalation・outcome のフィールド案を routing-contract に定義。実記録先は #874 RunEvidence `routing_decisions[]` / #811 Trust Ledger が未実装のため**接続は後続**（C-3 論点 2）

### Out of scope（issue Non-goals verbatim + v1 判断）

- 特定ベンダーのモデル序列を固定すること / 固有モデル名の Core Contract 埋め込み
- 既存の C-3 / C-4 / Parent Gate（AS-1〜5）を変更すること（`subagent-delegation/README.md` §5 と issue Non-goals の双方が Gate 直交を宣言済み）
- AI に Human-owned の承認権限を移すこと
- すべてのタスクで上位モデル・verifier を必須にすること
- 既存 `subagent-dispatch` の置き換え
- **`.claude/agents/*.md` frontmatter / `schemas/*.schema.json` の変更**（HO のため v1 では触らない。tier 実適用が必要になる場合は apply-script（`scripts/apply-agent-model-tiers.sh` 型）+ Human 実行の HO 導線へ分離）
- #874 RunEvidence / #811 Trust Ledger への実記録実装（フィールド案定義まで。実装は各 issue 側）

## 受入基準（issue #868 verbatim・9 項目 + In scope 対応 1 項）

- AC-1: サブタスクごとに role・model profile・reasoning effort・選定理由を説明できる
- AC-2: high-risk / critical で軽量 profile が誤選択された場合に block または escalation できる
- AC-3: write scope と tool policy が routing decision から確認できる
- AC-4: verifier の要否と割り当て理由が記録される
- AC-5: retry と model escalation が区別される
- AC-6: 実行ログまたは Trust Ledger から routing decision と outcome を追跡できる（v1 はフィールド案定義 + 記録先接続 IF の明示まで。C-3 論点 2）
- AC-7: 既存の #710 委譲プロトコル、Model Profile、Gate 条件を置き換えず接続している
- AC-8: 既存利用者に破壊的変更を与えない
- AC-9: 3 種類以上の代表シナリオ（issue 評価シナリオ A 定型調査 / B 通常実装 / C 高リスク設計変更）で、コスト過剰・品質不足・権限過剰を検出できる

### In scope↔AC 対応（issue AC に無いが In scope 実装物に紐づく検証条件）

- AC-10（In scope 2/3 対応）: role 正本が再建され、`plugin/plangate/rules/subagent-roles.md` への dead reference が正本ツリー（`.agents/skills/` およびその sync 先）で 0 件になる

## Notes from Refinement（調査で確定した設計方針）

- **v1 は非 HO 構成で完結**（推奨・C-3 で確定）: 変更対象は `docs/ai/subagent-delegation/**`・`docs/ai/model-profiles.md`・`.agents/skills/**` のいずれも Hardening Override 9 カテゴリ（`mode-classification.md` 正本）の**対象外**（`.claude/skills/` と同様、`.agents/skills/` も override パターン外・sync 経由伝播）。`.claude/agents/*.md` / `schemas/**` は HO のため v1 で触らず、実適用は apply-script + Human の HO 導線へ分離
- **R1（設計論点）: Claude Code に per-dispatch effort 指定機構がない**。Codex は toml 静的値（low/medium、high/xhigh 不採用が §11 ユーザー判断）。routing contract 上の `reasoning_effort` は「Codex = toml/exec フラグで実効・Claude = tier 選択 + プロンプト内推論深度指示で近似」という**両ランタイム parity の表現方法**を plan で確定する（機構がない側に嘘のフィールドを持たせない）
- **R2（注記必須）: plugin 配布版は `model: inherit` に正規化**される（`sync-plugin-plangate.sh`・§11 不変条件）。配布先では tier 選択が効かないため、routing-contract に「配布環境では profile 解決が inherit に縮退する」旨の degradation 注記を入れる
- **Gate 直交性は二重に宣言済み**: issue Non-goals と `docs/ai/subagent-delegation/README.md` §5 の双方が AS-1〜5 / C-3 / C-4 不変を明記。本 PBI の routing はすべて Gate の**内側**（AI-owned の委譲判断層）で完結し、承認境界を動かさない
- **記録先の依存関係**: #874 RunEvidence（`routing_decisions[]` を要求・pbi-input 作成済み）と #811 Trust Ledger はいずれも未実装・OPEN。v1 はフィールド案を routing-contract に定義し、#874/#811 側が consumer として取り込む構造（本 PBI からの実装依存を作らない）
- **評価は 3 シナリオ dry-run**（issue TODO）: A（researcher / light / low / read-only）・B（implementer / standard / medium / write 限定 + verifier）・C（architect / high-risk / high / verifier 必須・別セッション）を routing-contract の fixture 的サンプルとして収録し、AC-9 の検出（コスト過剰・品質不足・権限過剰）を机上検証で通す

## Estimation Evidence

### Risks

| リスク | 検証手段 | Fallback |
|--------|---------|----------|
| 「委譲制御 = 承認境界周辺」の解釈で Mode / HO 判定が割れる | C-3 で v1 非 HO 構成を確定（変更パスは HO 9 カテゴリ外を実測済み）。安全側で最低 high-risk 起点 | HO パスに触る必要が出たら当該変更を分離し apply-script + Human 適用 |
| Claude 側に effort 機構がなく parity が名目化する（R1） | plan で「実効値 vs 近似指示」の表現を確定し、routing-contract に機構差を明記 | effort は Codex 限定フィールドとし Claude は tier のみで v1 完結 |
| plugin 配布先で tier 選択が縮退する（R2） | routing-contract に degradation 注記 + sync 正規化の実測確認 | 配布版は routing contract を「判断記録の様式」としてのみ提供 |
| role 正本再建が旧 6 ロール定義と #58 期の設計から乖離する | CHANGELOG L935 / TASK-0033 handoff の旧定義を突合してから再建 | 旧 6 ロールを最小再建し、researcher/architect 追加は V2 |
| 記録先（#874/#811）未実装でフィールド案が宙に浮く | #874 pbi-input の `routing_decisions[]`（粒度暫定・後日整合の明記あり）と相互参照 | フィールド案は routing-contract 内に閉じ、接続は後続 issue |

### Unknowns

- role 正本の配置先（`.agents/skills/` 配下の SKILL か `docs/ai/subagent-delegation/` 配下の契約文書か）→ **C-3 論点 1 で確定**
- routing 記録の実記録先と粒度（#874 `routing_decisions[]` / #811 Trust Ledger）→ **C-3 論点 2**（v1 はフィールド案定義まで）
- effort parity の表現（実効値フィールド vs ランタイム別解決規則）→ plan で確定（R1）

### Assumptions

- 新設: `docs/ai/subagent-delegation/routing-contract.md` + role 正本 1 本。修正: `.agents/skills/` 3 SKILL・`dispatch-template.md`・`plangate-flow-integration.md`・`model-profiles.md` §11（additive）。sync 先（`.claude/skills/` / `.codex/skills/` / `plugin/`）は sync スクリプト経由で追従（手編集しない）
- **Mode: high-risk で確定**（`mode-classification.md` 機械判定）:
  - 受入基準数: **10**（issue verbatim 9 + AC-10）→ 6-10 = **高**
  - 変更ファイル数: 直接編集 7 前後（新設 2 + 修正 5）、sync 追従含めても 6-15 帯 → **高**
  - 定性: 委譲判断層の機能追加・複数レイヤー（contract / skill / profile）波及 → **高**。アーキテクチャ変更・ワークフロー定義変更ではない（WF-00〜07 / Gate 不変）ため超高には該当しない
  - 例外ルール: 変更パスは HO 9 カテゴリ**対象外**（実測）だが、「委譲制御は承認境界周辺」との解釈余地に対し**安全側**で「最低でも高」を適用 → high-risk と一致
  - **最終判定: high-risk**（定量・定性・例外の最大値一致）。**autonomous APPROVE 不可・人間 C-3 必須**（high-risk は判定マトリクスで一律不可）。`lite_eligible=false`

## C-3 先行判断論点（人間レビュー時に確定）

1. **role 正本の置き場所**: `.agents/skills/` 正本 + sync（#862 の orphan SKILL 移設と同じ流れ・推奨）か、`docs/ai/subagent-delegation/` の契約文書か
2. **routing 記録先**: #874 RunEvidence `routing_decisions[]` / #811 Trust Ledger のいずれも未実装のため、v1 は「フィールド案の定義まで」とする範囲確定（実記録の接続は #874/#811 側）
3. **v1 非 HO 構成の承認**: `.claude/agents/*.md` / `schemas/**` に触らない構成（HO 導線は apply-script 分離）で AC-1〜10 を満たすことの確認
