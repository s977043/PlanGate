---
name: engineer-skill-creator
description: 新しいClaude Codeスキルを対話的に設計・生成するワークフロー。Use when user says "スキルを作りたい", "skill作成", "create a skill", "新しいスキル", "SKILL.md生成", or wants to build a reusable Claude workflow.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
metadata:
  author: ai-dev-lab
  version: 1.0.0
  category: developer-tools
---

# Engineer Skill Creator

## Purpose

新しいClaude Codeスキルを対話的にヒアリング → 設計 → 生成 → 検証するワークフロー。
Anthropic公式ガイド「The Complete Guide to Building Skills for Claude」に準拠。

## Important Rules

- SKILL.mdは**大文字で正確に** `SKILL.md`（case-sensitive）
- フォルダ名は**kebab-case**のみ（スペース・大文字・アンダースコア禁止）
- name フィールドもkebab-case、フォルダ名と一致させる
- descriptionに**XMLタグ（< >）を含めない**（セキュリティ制限）
- "claude" "anthropic" をスキル名に使わない（予約語）
- descriptionは**何をするか + いつ使うか（トリガー条件）** の両方を含める
- SKILL.md本文は5,000語以下を目標にし、詳細はreferences/に分離

## Process

### Phase 1: ヒアリング（Use Case Discovery）

ユーザーに以下を対話的に質問する。一度に全部聞かず、会話の流れで自然に引き出す。

1. **ゴール**: このスキルで何を達成したいか？
2. **ユースケース**: 具体的な利用シーン（2〜3個）
3. **カテゴリ判定**: 以下のどれに最も近いか？
   - Category 1: ドキュメント・アセット生成（テンプレート型）
   - Category 2: ワークフロー自動化（ステップ型）
   - Category 3: MCP連携強化（ツール活用型）
4. **トリガー**: ユーザーがどんな言葉でこのスキルを呼び出すか？（日本語・英語両方）
5. **入力**: スキルが受け取る情報は何か？
6. **出力**: スキルが生成・実行する成果物は何か？
7. **ツール依存**: MCP、外部スクリプト、特定ツールが必要か？
8. **品質基準**: 成功をどう判定するか？

### Phase 2: 設計（Design）

ヒアリング結果から以下を決定する。

#### 2-1. フォルダ構成の決定

```
<skill-name>/
├── SKILL.md          # 必須 — メインスキルファイル
├── scripts/          # 任意 — 実行スクリプト
├── references/       # 任意 — 参照ドキュメント
└── assets/           # 任意 — テンプレート等
```

#### 2-2. YAML Frontmatter の設計

必須フィールド:
- `name`: kebab-case、フォルダ名と一致
- `description`: 1024文字以内、WHAT + WHEN + トリガーフレーズ

任意フィールド:
- `allowed-tools`: 使用ツールの制限（例: `Read, Edit, Bash`）
- `license`: OSSの場合（MIT, Apache-2.0）
- `compatibility`: 環境要件（1-500文字）
- `metadata`: author, version, mcp-server, category, tags

#### 2-3. Progressive Disclosure 設計

3レベルの情報開示を設計する:
- **Level 1（Frontmatter）**: 常にロードされる。トリガー判定に必要な最小限の情報
- **Level 2（SKILL.md本文）**: スキル発動時にロードされる。コア指示
- **Level 3（references/）**: 必要時のみ参照される詳細ドキュメント

#### 2-4. パターン選択

ユースケースに応じて最適なパターンを選択する:

| パターン | 用途 |
|:---|:---|
| Sequential Workflow | 順序固定の多段階プロセス |
| Multi-MCP Coordination | 複数サービスを横断する連携 |
| Iterative Refinement | 品質を反復改善するループ |
| Context-aware Selection | 状況に応じてツール・手法を切り替え |
| Domain Intelligence | 専門知識を判断ロジックに埋め込み |

### Phase 3: 生成（Generation）

設計を元にSKILL.mdを生成する。以下の構成テンプレートに従う:

```markdown
---
name: <skill-name>
description: <WHAT> + <WHEN trigger phrases>
allowed-tools: <tool list>
metadata:
  author: ai-dev-lab
  version: 1.0.0
---

# <Skill Display Name>

## Purpose
<1〜2文でスキルの目的を明示>

## When to use
<箇条書きで利用シーンを列挙>

## Input
<スキルが受け取る情報>

## Output
<スキルが生成する成果物>

## Instructions

### Step 1: <最初のステップ>
<具体的・アクション可能な指示>

### Step 2: <次のステップ>
<依存関係・バリデーションも含む>

(ステップを必要数追加)

## Examples

### Example 1: <一般的なシナリオ>
User says: "<典型的なリクエスト>"
Actions:
1. <アクション1>
2. <アクション2>
Result: <期待結果>

## Troubleshooting

### <よくあるエラー>
Cause: <原因>
Solution: <対処法>
```

### Phase 4: 検証（Validation）

生成したスキルを以下のチェックリストで検証する:

#### 構造チェック
- [ ] ファイル名が正確に `SKILL.md`
- [ ] フォルダ名がkebab-case
- [ ] YAML frontmatterに `---` デリミタがある
- [ ] `name` がkebab-case、フォルダ名と一致
- [ ] `description` にWHATとWHENの両方が含まれる
- [ ] XMLタグ（< >）がfrontmatterに含まれていない

#### 内容チェック
- [ ] 指示が具体的でアクション可能
- [ ] エラーハンドリングが含まれている
- [ ] 利用例が含まれている
- [ ] 参照ファイルへのリンクが正しい

#### トリガーチェック
- [ ] 明示的なリクエストでトリガーされるか
- [ ] 言い換えたリクエストでもトリガーされるか
- [ ] 無関係なクエリではトリガーされないか

### Phase 5: 配置（Deployment）

1. `.claude/skills/<skill-name>/SKILL.md` に配置
2. 必要に応じて `references/`, `scripts/`, `assets/` も配置
3. スラッシュコマンドとして登録する場合は `.claude/commands/` にもエントリを作成

## Quality Gates

- SKILL.md本文が5,000語を超えたら references/ への分離を提案
- description が50文字未満なら「トリガーフレーズが不足」と警告
- description が1024文字を超えたらトリミングを要求
- 利用例（Examples）が0件なら追加を促す

## Anti-patterns（避けるべきこと）

- 曖昧なdescription（例: "プロジェクトを手伝う"）
- トリガーフレーズのないdescription
- 1つのスキルに複数の無関係な責務を詰め込む
- references/ に分離せず巨大なSKILL.mdを作る
- README.mdをスキルフォルダ内に作る（不要 — SKILL.mdに集約）

## TDD Approach for Skills（スキルのTDD開発）

obra/superpowersの品質保証パターンに基づく。スキルをいきなり書くのではなく、「スキルなしで失敗する」ベースラインを確認してから書く。

### Red: ベースライン確認

1. スキルが解決すべきタスクを、**スキルなしで**エージェントに実行させる
2. 失敗する箇所・品質が低い箇所を記録する
3. これが「スキルが必要な理由」のエビデンスになる

```
ベースライン記録:
□ タスク: {スキルが解決すべきタスク}
□ スキルなしの結果: {何が起きたか}
□ 失敗箇所: {具体的な問題点}
□ 期待される改善: {スキルがあれば何が変わるか}
```

### Green: スキル作成と効果検証

1. SKILL.mdを作成する（Phase 1-5の通常フロー）
2. 同じタスクを**スキルありで**再実行する
3. ベースラインとの差分を確認する

```
効果検証:
□ スキルありの結果: {何が起きたか}
□ 改善された点: {ベースラインとの差分}
□ まだ改善が必要な点: {残課題}
```

### Refactor: 改善サイクル

1. 効果検証の結果を基にSKILL.mdを改善
2. undertrigger（トリガーされるべき時にされない）を確認
3. overtrigger（トリガーされるべきでない時にされる）を確認
4. descriptionのトリガーフレーズを調整
