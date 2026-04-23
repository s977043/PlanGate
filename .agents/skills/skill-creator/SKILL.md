---
name: skill-creator
description: Design a new Codex skill from a concrete use case and produce a repo-ready skill package. Use when the user asks to create a new skill, define a skill's responsibility, draft SKILL.md, choose frontmatter, design supporting files, or prepare eval criteria for a new skill. Also trigger on "スキルを作りたい", "スキルを作って", "スキルを追加して", "新しいスキル", "SKILL.md生成".
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

## Purpose

Create a new skill only after the use case is concrete enough.

Your job is to:

1. identify the smallest useful responsibility
2. define when the skill should trigger
3. choose safe frontmatter defaults
4. draft a minimal but strong `SKILL.md`
5. propose supporting files only when they add clear value
6. define an initial eval set

## Safety constraints

Write output files only to `.agents/skills/` unless the user explicitly specifies a different path.
Do not modify existing skills without user confirmation.

Note: this skill does not set `disable-model-invocation: true` because file creation is its primary purpose, not an incidental side effect. The settings.json deny list and user confirmation prompts provide sufficient guardrails.

## Core rule

Do not create a broad or fuzzy skill.

Prefer:

- one responsibility
- one primary workflow
- one clear success condition

If the requested scope is too broad, split it into multiple skills.

## Phase 0: Gate（ヒアリング）

Before drafting, confirm the following through interactive dialogue. Ask naturally — do not dump all questions at once.

1. **ゴール**: このスキルで何を達成したいか？
2. **ユースケース**: 具体的な利用シーン（2〜3個）
3. **カテゴリ判定**: 以下のどれに最も近いか？
   - Category 1: ドキュメント・アセット生成（テンプレート型）
   - Category 2: ワークフロー自動化（ステップ型）
   - Category 3: MCP連携強化（ツール活用型）
4. **トリガー**: ユーザーがどんな言葉でこのスキルを呼び出すか？（日本語・英語両方）
5. **入力**: スキルが受け取る情報は何か？
6. **出力**: スキルが生成・実行する成果物は何か？
7. **allowed tools**: 必要なツール
8. **auto vs manual**: 自動起動か手動起動か
9. **品質基準**: 成功をどう判定するか？
10. **definition of done**

If any item is unclear:

- ask the minimum focused questions, or
- inspect available files first if the answer can be found without asking

Do not draft the full skill until the gate passes.

## Phase 1: Skill boundary design

Produce a short working summary with:

- skill name candidate
- single responsibility
- in-scope tasks
- out-of-scope tasks
- likely trigger language
- risk level
- pattern selection:

| パターン | 用途 |
| :--- | :--- |
| Sequential Workflow | 順序固定の多段階プロセス |
| Multi-MCP Coordination | 複数サービスを横断する連携 |
| Iterative Refinement | 品質を反復改善するループ |
| Context-aware Selection | 状況に応じてツール・手法を切り替え |
| Domain Intelligence | 専門知識を判断ロジックに埋め込み |

Reject designs that combine unrelated workflows.

## Phase 2: Frontmatter & Progressive Disclosure設計

Choose frontmatter intentionally.

Defaults:

- include `name`
- include `description`
- omit extra fields unless clearly needed

Use:

- `disable-model-invocation: true` for side-effecting, sensitive, or timing-dependent workflows
- `allowed-tools` only when safe pre-approval is clearly useful
- `model` only when there is a concrete reason to override the default

For every chosen field, state why it is needed.

### Progressive Disclosure（3レベル情報開示）

Design information at three levels:

- **Level 1（Frontmatter）**: 常にロードされる。トリガー判定に必要な最小限の情報
- **Level 2（SKILL.md本文）**: スキル発動時にロードされる。コア指示
- **Level 3（references/）**: 必要時のみ参照される詳細ドキュメント

## Phase 3: Structure design

Draft the skill with this order:

1. purpose
2. gate
3. workflow phases
4. output contract
5. review step
6. failure handling
7. additional resources

Keep the main file compact.
Move heavy references, examples, and templates into separate files.

Use `${CLAUDE_SKILL_ROOT}/assets/basic-skill-template.md` as the starting skeleton.

## Phase 4: Eval design

Create an initial eval plan with:

- 10 to 20 realistic test prompts
- 3 to 6 pass/fail criteria
- likely failure modes
- what should be checked by code vs by reviewer

Include at least:

- one trigger test
- one under-specified request
- one boundary case
- one anti-pattern case

Use `${CLAUDE_SKILL_ROOT}/assets/eval-rubric-template.md` as the rubric structure.

## Phase 5: Review

Check the draft against:

- `${CLAUDE_SKILL_ROOT}/references/review-default.md`
- `${CLAUDE_SKILL_ROOT}/references/design-principles.md`

Fix any issue before finalizing.

## Phase 6: Registration & Quality Gates

After the skill files are written:

1. verify the directory name matches the `name` field in frontmatter
2. verify `description` is under 1024 characters and includes trigger keywords
3. verify SKILL.md is under 500 lines
4. verify all `${CLAUDE_SKILL_ROOT}/` references point to existing files
5. check the repository AGENTS.md or CLAUDE.md for additional registration steps
6. if the repository uses a skills index or registry, update it

### Quality Gates

- SKILL.md本文が5,000語を超えたらreferences/への分離を提案
- descriptionが50文字未満なら「トリガーフレーズが不足」と警告
- descriptionが1024文字を超えたらトリミングを要求
- 利用例（Examples）が0件なら追加を促す

## Phase 7: TDD検証（任意）

スキルの品質をRed→Green→Refactorサイクルで検証する。

### Red: ベースライン確認

1. スキルが解決すべきタスクを、**スキルなしで**エージェントに実行させる
2. 失敗する箇所・品質が低い箇所を記録する
3. これが「スキルが必要な理由」のエビデンスになる

### Green: 効果検証

1. SKILL.mdを配置した状態で同じタスクを再実行する
2. ベースラインとの差分を確認する

### Refactor: 改善サイクル

1. 効果検証の結果を基にSKILL.mdを改善
2. undertrigger（トリガーされるべき時にされない）を確認
3. overtrigger（トリガーされるべきでない時にされる）を確認
4. descriptionのトリガーフレーズを調整

## Output format

Return exactly these sections:

### Skill summary

### Recommended directory structure

### SKILL.md draft

### Supporting files to add

### Eval plan

### Known risks

## Anti-patterns

Do not:

- create a "do everything" skill
- invent company-specific rules
- write a vague description
- skip the gate
- omit eval planning
- hide trade-offs
- put all content in SKILL.md without references/ separation
- create README.md inside skill folder (unnecessary — SKILL.md is the entry point)

## Failure handling

If the request is too broad:

- propose 2 to 4 smaller skills
- explain the split by responsibility
- recommend which one to build first
