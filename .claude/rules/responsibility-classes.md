# 責務 4 分類（正本 / TASK-0081 S4）

> 出典: `docs/working/TASK-0070/direction-codex-gemini.md` C4（Codex×Gemini
> 合意）/ TASK-0071 D-1 第3スライス。本セッションで顕在化した「AI 不可侵領域
> （settings 自己改変 / merge）」の正式責務分界を**単一正本**に集約する。
> 個別ルールは本正本を参照し、具体適用を担う（重複定義しない）。

## 4 分類

| クラス | 担当 | 責務 | 代表例 |
|--------|------|------|--------|
| **AI-owned** | AI（Claude/Codex 等） | 実装・テスト・検証・PR 準備・manual patch / script 生成・設計/レビュー | コード実装、plan/handoff、`apply-claude-settings.sh` の**作成**、doctor 検証実行 |
| **Human-owned** | 人間 | **self-mod guard 対象**（`.claude/settings*.json` 等）の**適用**、C-3 / C-4 ゲート判断、**merge**、権限操作 | `.claude/settings*.json` への wiring 実適用、PR 承認/マージ、ruleset 操作 |
| **CI-owned** | CI（GitHub Actions） | drift 検出、必須 contract 検証、未適用 manual action の機械検出 | `settings-drift`（契約↔settings.example.json）、schema-validate、markdownlint |
| **Workflow-owned** | ワークフロー定義/ゲート | handoff artifact、DoD、未完了 manual action の追跡・ロック | WF-05 DoD タスクロック（doctor --check-settings PASS 必須）、handoff 6要素 |

## 境界の原則

- **AI は「変更を設計・検証し、人間しか担えない操作を明示 Gate として扱う」**。
  AI が物理的に不可能な操作（self-mod ガード対象の settings 適用、merge）は
  AI-owned にしない。AI は script/patch/検証を提供し、適用は Human-owned。
- **merge は Human-owned 固定**（sockpuppet 禁止と一貫。AI は merge-ready
  report と branch 整備まで）。
- **検証は三者分担**: 契約 reference 健全性=CI-owned / 実体 drift=AI-owned
  （doctor）/ 適用待ちの追跡・完了ロック=Workflow-owned。
- 「適用したと誤認できない」構造（Shadow Config 防止）は Workflow-owned の
  タスクロック + CI-owned の drift + AI-owned の doctor 検証 の合成で成立。
- **例外（階層維持）**: orchestrator-mode AS-3（親 PBI 完了宣言）は
  `HumanOrPolicyFinalApprovalPassed`＝Human-owned **または事前定義 policy**。
  本正本は上位集約だが、個別正本（orchestrator-mode）が policy 許容を
  定める箇所はそちらが優先（矛盾でなく委譲）。

## 対外公開アーティファクト publish 責務分界

> 2026-05-19 v8.7.0/v8.8.0/v8.9.0 リリース過去ログ保全の事後 3 者検証
> (qa-reviewer / 責務境界レビュー / Codex) で major 指摘として共通検出され、
> 明文化に至った領域。issue #296 参照。

GitHub Release / git tag push / その他**対外公開告知**は merge と同等の
**不可逆・対外確定操作**として扱い、以下のように分割する:

| 操作 | 担当 | 具体例 |
|------|------|--------|
| release note 整備・tag/release コマンド提示・draft 作成 | **AI-owned** | CHANGELOG 追記、`gh release create <args>` 案の提示、release-manager Agent への委譲 |
| `git push origin <tag>` 実行 | **Human-owned**（または計画段階で明示承認を取得した AI 実行） | 公開タグの確定 |
| `gh release create` 実行 | **Human-owned**（同上） | GitHub Release の発行 |
| 公開告知（ブログ・SNS 等） | **Human-owned** | 対外コミュニケーション |

**例外**: 計画段階で対象 publish 操作の AI 単独実行を**明示的に y で承認**
された場合に限り、その範囲で AI が実行可能。承認スコープを超える操作
（別 tag・別 release・別告知）は再承認を要する。

### 自己設置 Gate 非緩和原則（confirmation-policy 補足）

AI が計画上「Step X は成果物提示後に**再承認**」と自ら明示 Gate を
宣言した場合、**ユーザーの明示解除メッセージが無い限り**、`/goal` 設定
・Stop hook 設定・暗黙の autonomy 指示などの**ゴール記述**は
再承認とは見なさない。Gate 到達時は 1 回明示確認して停止する。

これは AI 運用 4 原則 第1（実行前 y/n）・第2（迂回禁止）・第4
（解釈変更禁止）の運用解釈であり、ユーザー承認後の自律実行 policy の
「計画承認」範囲外の Step（自分で切り分けた再承認 Gate）は別承認領域
として扱う。

## 既存ルール対応

| 既存ルール | 対応する分類観点 |
|-----------|----------------|
| [`hybrid-architecture.md`](./hybrid-architecture.md) Rule 1-5 | Workflow/Skill/Agent/CLAUDE.md/handoff の配置責務（本分類と直交・補完）|
| [`orchestrator-mode.md`](./orchestrator-mode.md) AS-1/2/4/5 | Human-owned ゲート（親 PBI 分解確定 / 子 exec 開始 / scope 変更 / forbidden_files 解除）|
| [`orchestrator-mode.md`](./orchestrator-mode.md) AS-3（親完了宣言 / `ParentDone`）| **Human-owned または事前定義 policy**（`HumanOrPolicyFinalApprovalPassed`。orchestrator-mode 正本に従い Human 固定にしない）|
| [`working-context.md`](./working-context.md) settings タスクロック | Workflow-owned（doctor 未PASS で V-1/handoff 完了不可）|
| [`mode-classification.md`](./mode-classification.md) lite_eligible / C-3 降格 | Human-owned（承認境界）+ Workflow-owned（同期/非同期 opt-in）|
| [`docs/ai/settings-wiring-contract.md`](../../docs/ai/settings-wiring-contract.md) 責務分離表 | CI-owned（reference）/ AI-owned（doctor 実体検証）/ Human-owned（適用）の具体適用例 |
| TASK-0077 AC-4（TASK-0071 との責務境界）| 本正本がその上位集約。Lite/降格は Human-owned 承認境界に従属 |
| [本正本 「対外公開アーティファクト publish 責務分界」節](#対外公開アーティファクト-publish-責務分界) | tag/release publish は AI が draft/コマンド提示まで、実行は Human-owned（または計画段階で明示承認を取得した AI 実行）。issue #296 で正本化 |

## 位置づけ

本正本は責務の**上位集約**。個別ルールは具体適用（矛盾ではなく階層）。
新規 PBI は責務帰属が曖昧なとき本正本を参照し、AI が不可能な操作を
AI-owned に置かない設計とする。
