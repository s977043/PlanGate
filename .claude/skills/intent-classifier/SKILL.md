---
name: intent-classifier
description: "ユーザーの依頼文から開発 Intent を 8 分類し、structured JSON で返す。Use when: ユーザーの依頼を受け取った直後に意図を分類したい時。「この依頼は何を求めているか判定して」「Intent を分類して」「依頼の種別を教えて」。"
---

# Intent Classifier

> 正本（sync 元）: `.agents/skills/intent-classifier/SKILL.md`。`scripts/sync-plugin-plangate.sh` が
> `.agents/skills/` を読み取り `plugin/plangate/skills/` を機械生成する。`.claude/skills/` と
> `.codex/skills/` は sync 対象外の配布先のため、正本更新時に同一内容を手動で追従させる。

ユーザーの依頼文を読み取り、開発 Intent を 8 分類のいずれかに判定して structured JSON で返す。

## Iron Law

`CLASSIFY BASED ON EXPLICIT SIGNALS, NOT ASSUMPTIONS`

依頼文に存在しないシグナルで分類を変えてはならない。
曖昧な場合は confidence を下げて reasoning に根拠を示せ。

## Common Rationalizations

| こう思ったら | 現実 |
|---|---|
| 「文脈から明らかだから confidence=1.0 でいい」 | 曖昧さは必ず confidence に反映しろ |
| 「どちらにも取れるが多分 feature だろう」 | 複数候補時は上位 2 件を candidates に列挙しろ |
| 「short な依頼文だから判定できない」 | 情報不足でも最良推定で判定し、confidence を下げる |

## Intent 分類定義

| Intent | 説明 | キーワード例 |
|--------|------|------------|
| `feature` | 新機能・新動作の追加 | 追加, 実装, 作成, 新しい, 追加してほしい |
| `bug` | 既存機能の欠陥修正 | 直す, 修正, エラー, バグ, 壊れている, 失敗する |
| `refactor` | 動作を変えずにコード構造を改善 | リファクタ, 整理, 整頓, 分割, 綺麗にする, 改善 |
| `research` | 技術調査・設計調査・情報収集 | 調査, 調べる, 比較, 評価, どうすべきか, 方針 |
| `review` | コード・設計・ドキュメントのレビュー | レビュー, 確認, チェック, 問題ないか, 品質 |
| `docs` | ドキュメント・コメント・README の追加・更新 | ドキュメント, README, コメント, 説明, 記述 |
| `ops` | CI/CD・デプロイ・監視・インフラ・設定変更・**PlanGate CLI 操作**（render/approve/exec/doctor） | デプロイ, CI, CD, インフラ, 設定, 環境, リリース, render, HTML 確認, C-3 確認, C-3 HTML, approve, plangate render, plangate approve, doctor |
| `exploratory` | 要件が未確定な探索的デバッグ・仮説検証ループ（「やってみて初めて問題が露呈する」タスク）→ **WF-07 を推奨** | 探索, デバッグ, 原因不明, 試す, 仮説, 段階的に, 入れ子, ビルド失敗, 何度も失敗, 検証しながら |

## PlanGate CLI 操作の認識（ops 補足）

「C-3 の確認を HTML で行いたい」「render して」「plangate render」「C-3 HTML を出して」などは `ops` に分類し、検出したら即座に以下を実行する:

| ユーザー表現 | 実行コマンド |
|-------------|------------|
| C-3 確認を HTML / render / HTML 出力 | `plangate render <TASK>` |
| C-3 承認 / approve | `plangate approve <TASK>`（別ターミナル必須） |
| doctor / 健全性確認 | `plangate doctor` |
| exec 開始 / exec して | `plangate exec <TASK>`（C-3 APPROVED 確認後） |

`<TASK>` はコンテキストから推定（不明なら確認）。**intent=ops と判定した時点で plangate コマンドの候補を提示し、承認を待たずに実行する**（render は読み取り専用）。

> **呼び出し表記は実行環境で変わる**。上表は導入先で PATH を通した場合のコマンド名
> （**`plangate`**）。**上流リポジトリ（`s977043/plangate`）を clone した cwd では
> `bin/plangate render` のように相対パス形式で呼ぶ**（導入先に `bin/` は配置されない）。
> なお `<TASK>` 位置引数は cwd ではなく **CLI 本体の位置**を基準に
> `<CLI の repo root>/docs/working/<TASK>` へ解決されるため、PATH 上の `plangate` で
> **導入先の TASK を対象にすることはできない**（`render` / `approve` / `doctor` / `exec` に
> `--dir` 相当のオプションは無い）。

### CLI 不在時の degrade

`plangate` が PATH に無い環境（**導入先では既定**）でも **Intent 分類そのものは CLI に依存しない**
ため、本 skill の判定手順・出力フォーマットは不変。変わるのは上表の「実行コマンド提示」だけで、
以下に置き換える（**分類を `ops` 以外にすり替えない**）:

- **render** → `plan.md` / `review-self.md` / `review-external.md` を直接読んでレビューする
- **approve** → 人間が `approvals/c3.json` を発行する（AI は代理発行しない）
- **doctor** → `.claude/settings.json` 等を直接確認する（**未検証を「doctor PASS」と書かない**。
  検証観点の正本は `plangate-setup` skill）
- **exec** → 手動で TDD 実行（ゲート確認の正本は `ai-dev-exec` skill）

**ゲートの厳密な強制には CLI + hooks が必要**であり、CLI 不在時は機械的な block が成立しない。
代替手順を実施した事実は `status.md` に記録し、**CLI が無いことを理由にゲートを省略しない**。

## 手順

### Step 1: 依頼文の読み取り

ユーザーの依頼文（または直前の会話コンテキスト）を入力として受け取る。
依頼文が複数文の場合は全体を読み取り、主目的を抽出する。

### Step 2: シグナル抽出

依頼文から以下のシグナルを特定する:

1. **動詞シグナル**: 「追加する」「修正する」「調査する」「レビューする」等
2. **名詞シグナル**: 「バグ」「機能」「ドキュメント」「設定」等
3. **状態シグナル**: 「壊れている」「存在しない」「改善したい」等

### Step 3: 分類判定

シグナルを Intent 分類定義と照合し、最も一致する Intent を選択する。

**優先順位ルール**:

- bug シグナル（エラー・壊れている・失敗）が明示されていれば `bug` を優先
- 「追加」+ 「新しい」の組み合わせは `feature` を優先
- 動作変更なしの「整理」「分割」は `refactor` を優先
- 「どうすべきか」「比較」「評価」は `research` を優先
- ドキュメント・コメントのみの変更は `docs` を優先
- CI/CD・デプロイ・インフラ変更は `ops` を優先
- 「原因不明」「試してみる」「何度も失敗」「段階的に調べる」は `exploratory` を優先（WF-07 を推奨する旨を出力に添える）

### Step 4: confidence 算定

| シグナル強度 | confidence 範囲 |
|------------|----------------|
| 複数の一致シグナルあり | 0.85 〜 1.0 |
| 1 つの明確なシグナルあり | 0.65 〜 0.84 |
| シグナルが弱い / 複数候補 | 0.40 〜 0.64 |
| ほぼ判断不能 | 0.10 〜 0.39 |

### Step 5: 出力生成

以下のフォーマットで structured JSON を出力する。

## 出力フォーマット

```json
{
  "intent": "<feature|bug|refactor|research|review|docs|ops|exploratory>",
  "confidence": <0.0〜1.0>,
  "reasoning": "<判定根拠を1〜2文で説明>",
  "candidates": [
    {
      "intent": "<第2候補>",
      "confidence": <0.0〜1.0>
    }
  ]
}
```

**フィールド仕様**:

- `intent`: 8 分類のいずれか（必須）
- `confidence`: 0.0〜1.0 の実数（必須）
- `reasoning`: 判定根拠の説明（必須）
- `candidates`: confidence < 0.7 の場合は上位 2 件まで列挙（任意、省略時は空配列）

## 使用例

**入力**: 「ログイン機能を追加してほしい」

**出力**:

```json
{
  "intent": "feature",
  "confidence": 0.95,
  "reasoning": "「追加してほしい」という動詞と「機能」という名詞から、新機能追加の依頼と判定した。",
  "candidates": []
}
```

**入力**: 「認証画面でエラーが出ているのを直してほしい」

**出力**:

```json
{
  "intent": "bug",
  "confidence": 0.92,
  "reasoning": "「エラー」「直してほしい」というバグ修正シグナルが明示されている。",
  "candidates": []
}
```

## 責務境界（Mode / lite_eligible は判定しない）

intent-classifier は **Intent 8 分類のみ**を担う。Mode 判定・`lite_eligible` 算定は行わない（それらは [`mode-classification.md`](../../rules/mode-classification.md) 正本 + 後段の mode 判定ステップが担当）。本スキルの出力 Intent は skill-policy-router の入力の一部となる（WF-00 advisory）。

## 関連 Skill

- **skill-policy-router**: Intent + Mode を受け取り GatePolicy を返す。intent-classifier の出力をそのまま渡せる
- **breakdown-gate**: タスク粒度の intake ゲート。intent-classifier のさらに前段で、分割が必要な粗粒度タスクを検出する（`.agents/skills/breakdown-gate/`）
