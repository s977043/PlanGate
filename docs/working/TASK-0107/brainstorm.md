# TASK-0107 Brainstorm: PlanGate Setup Command

> **Status**: Brainstorm（PBI 化前の検討ログ）
> **Date**: 2026-05-21
> **Trigger**: Claude cowork の `/setup-cowork` 相当を PlanGate にも用意し、初期設定を楽に進められるようにしたい
> **Note (2026-05-21 C-2 R2 / R-007 対応)**: 本ファイルは設計検討の**履歴文書**。現行正本は [`pbi-input.md`](./pbi-input.md) r1。**§4 責務4分類表 / §7 未決事項 mode 候補（standard/light）は r1 で更新済**（責務4分類は Workflow-owned 永続ロック明示済、mode は high-risk 確定）。phase B 以降は pbi-input.md r1 を正本とすること。


## 1. 背景・目的

PlanGate は導入時に以下のような初期設定が必要だが、現状は手順が散在しており、新規導入時のハードルが高い:

- `.claude/settings.json` の wiring（EH-3 / EH-8 等の Hook 配線）
- `apply-claude-settings.sh` の実行
- `bin/plangate doctor` での検証
- `docs/working/` 構造の理解
- 必要なツール / 依存の確認

Claude cowork の `/setup-cowork` のように、**対話的に初期設定を進められる入口**を PlanGate にも提供したい。

## 2. 検討した配置案（Workflow / Skill / Agent / Command の 4 軸）

PlanGate の責務分類ルール（[`hybrid-architecture.md`](../../../.claude/rules/hybrid-architecture.md) Rule 1〜5、[`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md) AI/Human/CI/Workflow-owned）を基準に、各配置候補を評価:

| 配置 | 適合性 | 理由 |
|------|--------|------|
| **Workflow** (`docs/workflows/`) | × | WF-01〜05 は PBI ライフサイクル。setup はその外（メタ操作）。Rule 1 の「順序と完了条件」とは性質が異なる |
| **Skill** (`.claude/skills/`) | ○ | 手順本体・観点を再利用単位で保持。Rule 2 適合。配布版 plugin への export も容易 |
| **Agent** (`.claude/agents/`) | ○ | **Human action の追跡 / Gate 保持 / 対話**という単一責務を担える。Rule 3 適合 |
| **Command** (`.claude/commands/`) | ○ | `/plangate-setup` のスラッシュ語彙で発見性を上げる入口 |

### 当初案（Agent なし）

検討初期は「Command + Skill の二層」を推奨案としたが、以下の指摘で見直した:

> 「Human が設定する部分が必要なので、その確認などを担当するエージェントは必要ではないか？」

**Skill は手順、Agent は責務**という分離原則から、「Human を待つ」「Gate を保持する」は Agent 側に置くのが正しい。

## 3. 推奨：三層構成

| 層 | 役割 | 配置 |
|---|---|---|
| **Command** `/plangate-setup` | 起動口（薄い）。Agent 呼び出しと初期 context 渡しのみ | `.claude/commands/plangate-setup.md` |
| **Agent** `setup-coordinator` | Human action の追跡・Gate 保持・対話・進捗管理 | `.claude/agents/setup-coordinator.md` |
| **Skill** `plangate-setup` | チェックリスト・検証観点・script 提示テンプレ（再利用単位） | `.claude/skills/plangate-setup/SKILL.md` |
| **CLI**（既存） `bin/plangate doctor` | 機械的検証。Agent から呼ぶ | — |

### 各層の責務境界

```
User ──/plangate-setup──→ Command
                              ↓ 起動
                          Agent: setup-coordinator
                              ↓ 観点読込
                          Skill: plangate-setup（手順・観点）
                              ↓ 検証実行
                          CLI: bin/plangate doctor
                              ↓ 出力解釈
                          Agent: Human への提示・応答待ち
                              ↓ 完了確認
                          Agent: サマリ出力（handoff 風）
```

## 4. 根拠

### Rule 1〜5 との整合

- **Rule 1**（Workflow は順序と完了条件のみ）: setup は PBI ライフサイクル外のため Workflow には置かない
- **Rule 2**（Skill は再利用単位）: チェックリスト・観点は他リポジトリへの export 候補となるため Skill に
- **Rule 3**（Agent は責務のみ）: `setup-coordinator` は「Human action の追跡・Gate 保持」という単一責務
- **Rule 4**（案件固有は CLAUDE.md）: PlanGate 固有の wiring 詳細は CLAUDE.md / settings-wiring-contract.md を参照
- **Rule 5**（最終成果物は handoff）: setup 完了時にサマリを出力（handoff 形式ではないが、完了サマリの責務は明示）

### 責務 4 分類との整合

| 操作 | 分類 | 本構成での担当 |
|------|------|--------------|
| settings.json の wiring 適用 | **Human-owned**（self-mod ガード） | Agent が**提示**、ユーザーが実行 |
| `apply-claude-settings.sh` の実行 | **Human-owned** | Agent が**提示**、ユーザーが実行 |
| doctor による検証 | **AI-owned** | Agent が CLI 呼び出し |
| 適用待ちの追跡 / 完了 lock | **Workflow-owned** | Agent + Skill の責務として記録 |
| drift 検出（reference） | **CI-owned** | 既存 CI（settings-drift workflow） |

### Shadow Config 防止との整合

- AI は settings 自己改変できない（self-mod ガード）
- Agent は「適用しましたか？」を聞くが、**doctor 再実行で実体検証**する
- これにより「AI が適用済みと誤認して完了する」Shadow Configuration を構造的に防ぐ
- [`working-context.md`](../../../.claude/rules/working-context.md) settings タスクロックと整合

### 既存 Agent パターンの踏襲

| 既存 Agent | 責務 | `setup-coordinator` との類似点 |
|-----------|------|-----------------------------|
| `acceptance-tester` | V-1 受け入れ検査 | 機械的検証 + 結果報告 |
| `linter-fixer` | L-0 リンター修正 | autofix → AI 修正 → 抑制の段階的処理 |
| `setup-coordinator`（新規） | setup 進捗管理 | 検知 → 提示 → 確認 → 再検証の段階的処理 |

## 5. 想定フロー

```
/plangate-setup
  ↓
Step 1: 現状検知
  - Agent が bin/plangate doctor 実行
  - 不足項目をリスト化（settings wiring / Hook / scripts 等）
  - Skill のチェックリストと突合

Step 2: 質問・分岐
  - Agent: 「Hook EH-3/EH-8 を wire しますか？」「apply-claude-settings.sh を実行しましたか？」など
  - ユーザー応答に応じて分岐

Step 3: 提示
  - Agent: sh scripts/apply-claude-settings.sh のコマンドを表示
  - 実行はユーザーが行う（AI は実行しない）

Step 4: 検証
  - ユーザー: 「やりました」と報告
  - Agent: doctor 再実行で実体検証
  - PASS → 次へ / FAIL → 失敗内容を提示し再依頼

Step 5: 完了サマリ
  - 完了項目 / 残項目 / 次のアクション候補（最初の PBI 作成 / /ai-dev-workflow 等）を出力
```

## 6. トレードオフ

### Pros（採用理由）

- Agent を分離することで「Human action 追跡」責務が明確化
- Skill 単独より発見性・再利用性が両立
- 既存 Agent パターン（`acceptance-tester` / `linter-fixer`）と一貫
- doctor を中核に据えることで Shadow Config 防止が自然に成立

### Cons（採用しなかった選択肢）

| 選択肢 | 不採用理由 |
|--------|----------|
| Command 単独 | 状態管理・Gate 保持が弱い。Agent 責務を Command に書き込むと Rule 1 違反気味 |
| Skill 単独 | Human 応答を待つ「対話・追跡」責務を Skill に書くと Rule 2（再利用単位）逸脱 |
| Agent 単独（Command なし） | スラッシュ起動の発見性が下がる。Claude cowork `/setup-cowork` 同型 UX が出せない |
| Workflow 追加（WF-00 等） | PBI ライフサイクル外のため Workflow の枠組みに合わない |

### 残るトレードオフ

- **完全自動化は不可**: settings self-mod ガードがある以上「ガイド型」止まり。代わりに doctor / CI で未適用を機械検出
- **三層になり管理対象が増える**: が、setup は重要な入口なので妥当
- **Claude cowork `/setup-cowork` の実体**: 調査済み（§6.5 参照）。Cowork 公式に組み込みの `/setup-cowork` は**存在しない**。PlanGate 版は公式仕様に縛られず独自設計で進める

## 6.5 Claude Cowork 実体調査結果（2026-05-21）

公式ドキュメント + 複数の解説記事を確認した結果:

| 項目 | 実態 |
|------|------|
| Cowork 組み込み slash command | `/schedule`、`/plugin` 等は存在。**setup 専用コマンドは無い** |
| 初期セットアップ方法 | **GUI ベース**（Settings > Cowork、フォルダ選択ダイアログ、コネクタ画面） |
| セットアップで整える 5 要素 | Context files / Global instructions / Folder instructions / Plugins / Connectors |
| `/setup-cowork` の正体 | コミュニティ/個人が作ったカスタムスキル、または UX イメージとしての例示 |

### PlanGate 版への含意

Cowork 公式仕様に縛られる必要はない。ただし「5 要素を整える」という観点は転用可能:

| Cowork 5 要素 | PlanGate 対応物 |
|--------------|----------------|
| Context files | `CLAUDE.md` / `AGENTS.md`（既存）|
| Global instructions | `.claude/settings.json` wiring（Human-owned）|
| Folder/Project instructions | `docs/working/` 構造 |
| Plugins | `.claude/{agents,skills,commands}` |
| Connectors | Hook / CI / MCP 等 |

→ **三層構成（Command + Agent + Skill）の方針は確定**。doctor を中核に、上記 5 要素の検知・提示・確認を Agent が担う設計で進める。

### 参照（調査ソース）

- [Get started with Claude Cowork — Anthropic Help Center](https://support.claude.com/en/articles/13345190-get-started-with-claude-cowork)
- [Cowork: Claude Code power for knowledge work — Claude.com](https://claude.com/product/cowork)
- [Claude Cowork Setup Guide — The AI Corner](https://www.the-ai-corner.com/p/claude-cowork-setup-guide)
- [Complete Claude Setup Checklist — Medium](https://medium.com/nginity/the-complete-claude-setup-checklist-72-steps-from-default-to-power-user-082d8bf0d390)

## 7. 未決事項

- [x] ~~Claude cowork `/setup-cowork` の実体~~（2026-05-21 調査完了。§6.5 参照）
- [ ] `plangate-setup` Skill のチェックリスト具体項目（doctor 検査項目 12 種類 + Cowork 5 要素対応の対応関係）
- [ ] `setup-coordinator` Agent の tools 設定（Bash / Read 中心？ Edit は不要？）
- [ ] 初回 setup 以外の用途（再設定 / 部分再適用 / 健康診断）も担うか、それとも setup 専用とするか
- [ ] PBI 化する場合のモード判定（standard 想定だが、Agent 新規追加 + Hook 影響なしのため light でも可？）
- [ ] handoff 風の完了サマリは PBI handoff.md と紛らわしくないか命名検討

## 8. 次のアクション候補

| 選択肢 | 内容 |
|--------|------|
| **A. PBI 化して実装** | 本 brainstorm.md を pbi-input.md に昇格 → plan 生成 → C-3 ゲート → exec |
| **B. Claude cowork 実体調査が先** | `/setup-cowork` の挙動確認 → 同等性要件を pbi-input に反映してから PBI 化 |
| **C. Skill のみ先行実装** | Agent / Command は後段。Skill だけ用意して既存 Agent から呼べる状態にする（最小投資） |
| **D. brainstorm のまま保留** | 他優先 PBI を消化してから戻る |

**選択履歴**: 2026-05-21 ユーザー指示「B→Aの順」。B 完了（§6.5 反映済）→ A 着手（pbi-input.md 生成へ）。

## 9. 参照

- [`hybrid-architecture.md`](../../../.claude/rules/hybrid-architecture.md): Rule 1〜5
- [`responsibility-classes.md`](../../../.claude/rules/responsibility-classes.md): AI/Human/CI/Workflow-owned 4 分類
- [`working-context.md`](../../../.claude/rules/working-context.md): settings タスクロック / Shadow Config 防止
- [`docs/ai/settings-wiring-contract.md`](../../ai/settings-wiring-contract.md): wiring 契約
- 既存 Agent: `.claude/agents/acceptance-tester.md` / `.claude/agents/linter-fixer.md`
- 既存 CLI: `bin/plangate doctor`
