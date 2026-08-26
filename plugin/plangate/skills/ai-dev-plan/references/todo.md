# TASK-XXXX EXECUTION TODO

> フェーズ B（Prompt 1）で `plan.md` / `test-cases.md` と**同時生成**する。
> 正本: `working-context.md` の「todo.md（EXECUTION TODO）」節 /
> [`.agents/skills/ai-dev-plan/SKILL.md`](../SKILL.md) の「todo.md 規約」。
> **本テンプレートは規約の実体化であって再定義ではない**。規約を変えるときは正本側を変える。

## 記入規約（チェックリスト）

- [ ] タスク粒度は **2-5 分**（それ以上かかるものは分割する）
- [ ] 各タスクに `Owner:` / `depends_on:` / `files:` / `rollback:` を**すべて**書く
- [ ] `Owner:` は `agent` / `human` のいずれか
- [ ] `depends_on:` は先行タスク ID（無ければ `なし`）
- [ ] `files:` は触るファイルパス（読取のみなら「読取: `path`」と明記）
- [ ] `rollback:` は戻し手順。**必須 = high-risk / critical の実装タスク**。standard 以下は任意、検証・読取のみのタスクは `不要` と明記してよい
- [ ] **L-0 / V-1〜V-4 / PR 作成は含めない**（workflow-conductor が自動制御する）

## Mode

**モード**: {ultra-light | light | standard | high-risk | critical}

> `plan.md` の「Mode判定」と一致させる。high-risk / critical では実装タスクの `rollback:` が必須になる。

## 🤖 Agent タスク

### 1. 準備

- [ ] T-01: {2-5 分で終わる準備作業}
  - Owner: agent
  - depends_on: なし
  - files: 読取: `path/to/reference`
  - rollback: 不要（読取のみ）
  - 🚩 チェックポイント: なし

### 2. 実装

- [ ] T-02: {2-5 分で終わる実装作業}
  - Owner: agent
  - depends_on: T-01
  - files: `path/to/file`
  - rollback: {戻し手順（例: `git checkout -- path/to/file`）}
  - 🚩 チェックポイント: {人間確認が要るなら内容を書く。不要なら「なし」}

### 3. 検証

- [ ] T-03: {テスト・検査の実行}
  - Owner: agent
  - depends_on: T-02
  - files: 読取: `path/to/test`
  - rollback: 不要（検証のみ）
  - 🚩 チェックポイント: なし

> 実行するテストは [`test-cases.md`](./test-cases.md) の TC-ID で指定する（ここでケースを新設しない）。

### 4. 完了

- [ ] T-04: `status.md` / `current-state.md` / `INDEX.md` を更新する
  - Owner: agent
  - depends_on: T-03
  - files: `docs/working/TASK-XXXX/status.md`, `docs/working/TASK-XXXX/current-state.md`, `docs/working/TASK-XXXX/INDEX.md`
  - rollback: 不要（記録のみ）
  - 🚩 チェックポイント: なし

## 👤 Human タスク

- [ ] H-01: **C-3 ゲート**（exec 開始前）— APPROVE / CONDITIONAL / REJECT
  - Owner: human
  - depends_on: T-01
  - files: `docs/working/TASK-XXXX/approvals/c3.json`
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: APPROVED が出るまで exec を開始しない
- [ ] H-02: **C-4 ゲート**（PR レビュー）— APPROVE / REQUEST CHANGES / REJECT
  - Owner: human
  - depends_on: T-04
  - files: GitHub PR
  - rollback: 不要（判断のみ）
  - 🚩 チェックポイント: merge は Human-owned 固定

## ⚠️ 依存関係（Agent ↔ Human）

| タスク | depends_on | 種別 | 備考 |
| --- | --- | --- | --- |
| T-02 | H-01 | Human → Agent | C-3 APPROVED まで実装に入れない |
| H-02 | T-04 | Agent → Human | 完了記録の更新後に PR レビュー |

## 対象外（workflow-conductor が自動制御するため書かない）

- L-0（リンター自動修正）
- V-1（受け入れ検査）/ V-2（コード最適化）/ V-3（外部モデルレビュー）/ V-4（リリース前チェック）
- PR 作成
