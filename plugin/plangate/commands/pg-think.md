# /pg-think

実装前の論点整理と設計整理を行う。

## 目的

曖昧なまま実装に入ることを防ぐ。「何を・なぜ・どう作るか」を明確にしてから実装へ進む。

## Iron Law

`NO CODE WITHOUT APPROVED DESIGN FIRST`

think フェーズで論点が整理されるまで実装を開始しない。

## 引数

`$ARGUMENTS` に問題・タスクの説明を渡す。省略時はカレントのタスク文脈から取得。

## 実行フロー

以下を順番に実行し、構造化レポートを出力する。

1. **Problem Restatement**: 依頼を自分の言葉で言い換え、本当の問題を確認する
2. **Assumptions**: 前提条件を列挙する
3. **Options**: 少なくとも 2〜3 の実装アプローチを列挙する
4. **Recommended Approach**: 推奨アプローチと選択理由を述べる
5. **Risks**: 推奨アプローチのリスクを列挙する
6. **Open Questions**: 未解決の疑問点・確認事項を列挙する

## 出力フォーマット

### Problem Restatement

\<問題の言い換え\>

### Assumptions

- \<前提 1\>
- \<前提 2\>

### Options

| オプション | メリット | デメリット |
|-----------|--------|---------|
| \<案 1\> | ... | ... |
| \<案 2\> | ... | ... |

### Recommended Approach

\<推奨アプローチの説明と理由\>

### Risks

| リスク | 影響 | 対策 |
|-------|------|------|
| \<リスク 1\> | ... | ... |

### Open Questions

- [ ] \<未解決事項 1\>
- [ ] \<未解決事項 2\>

## GatePolicy との連携

`standard` 以上のモードでは `think` スキルが `requiredSkills` に含まれる。
`skill-policy-router` から自動要求される。
