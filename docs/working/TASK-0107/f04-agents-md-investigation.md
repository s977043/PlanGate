# F-04 調査レポート: AGENTS.md 自動更新の根本原因と対処案

> **Phase**: TASK-0107 post-merge follow-up（F-04 / Codex+Gemini follow-up advisory）
> **Date**: 2026-05-22
> **対象**: AGENTS.md ファイルに `<claude-mem-context>` ブロックが session 中に自動追加される現象
> **目的**: 根本原因の特定と対処案の提示（実装は Human-owned のため設定変更案まで）

---

## 1. 現象

PlanGate プロジェクトの `AGENTS.md` に、Claude Code セッション中に以下のようなブロックが自動追加される:

```
<claude-mem-context>
# Memory Context

# [plangate] recent context, YYYY-MM-DD HH:MMam GMT+9
...（observation サマリ）
</claude-mem-context>
```

TASK-0107 セッション中、本現象は **複数回** 発生し、その都度 `git restore AGENTS.md` で revert する必要があった。

## 2. 根本原因の特定

### 原因元

**claude-mem plugin v13.2.0** が AGENTS.md に直接書き込んでいる。

該当箇所:

- **`~/.claude/plugins/cache/thedotmack/claude-mem/13.2.0/scripts/worker-service.cjs`**
  - `writeFileSync(<tmpPath>, content)` → `renameSync(<tmpPath>, <agentsPath>)` の atomic 書き込みパターン
  - ログタグ: `AGENTS_MD` → 「Failed to write AGENTS.md」エラーメッセージ
  - API endpoint: `/api/context/inject?projects=...` → デフォルト書き込み先 `${cwd}/AGENTS.md`

### 起動 hook

claude-mem の以下の hook が AGENTS.md context inject を起動している可能性:

- **SessionStart hook**: `worker-service.cjs hook claude-code context` （`startup|clear|compact` matcher）
- **UserPromptSubmit hook**: `worker-service.cjs hook claude-code session-init`
- **PostToolUse hook**: `worker-service.cjs hook claude-code observation`

### 既存 ON/OFF フラグ

`~/.claude-mem/settings.json` の関連フラグ:

| フラグ | 現状 | 役割 |
|--------|------|------|
| `CLAUDE_MEM_FOLDER_CLAUDEMD_ENABLED` | `false` | フォルダ CLAUDE.md 機能 |
| `CLAUDE_MEM_FOLDER_USE_LOCAL_MD` | `false` | ローカル MD 使用 |
| `CLAUDE_MEM_SEMANTIC_INJECT` | `false` | セマンティック注入 |

→ **`CLAUDE_MEM_FOLDER_CLAUDEMD_ENABLED=false` でも AGENTS.md への書き込みが発生している**。フォルダ機能とは別ルート（context inject API）で書き込みが起きている可能性が高い。

## 3. 影響範囲

- **PlanGate コミットへの混入リスク**: 開発者が `git add .` する際に AGENTS.md の変更を巻き込むリスク
- **PR ノイズ**: PR diff に意図しない `<claude-mem-context>` ブロックが含まれる可能性
- **他開発者との衝突**: 異なるセッションで異なる context block が書き込まれた場合の merge conflict
- **ユーザー指示違反**: 過去にユーザーが「AGENTS.md は変更しない」と明示指示したルールへの違反リスク

## 4. 対処案（5 案）

### 案 A: `.gitattributes` で `merge=ours`（推奨度: 高）

```gitattributes
# AGENTS.md は claude-mem plugin による自動追記対象。merge 時はローカル版を保持
AGENTS.md merge=ours
```

- **Pros**: シンプル、git レベルで対処、他開発者にも自動適用
- **Cons**: 意図的な AGENTS.md 変更時に手動マージが必要、ローカルでの自動追記は防げない

### 案 B: pre-commit hook で strip（推奨度: 高）

`scripts/hooks/strip-claude-mem-context.sh` 等を新設し、commit 前に `<claude-mem-context>...</claude-mem-context>` ブロックを自動 strip。

```sh
# pre-commit hook 内
if grep -q '<claude-mem-context>' AGENTS.md 2>/dev/null; then
  sed -i.bak '/<claude-mem-context>/,/<\/claude-mem-context>/d' AGENTS.md
  rm -f AGENTS.md.bak
fi
```

- **Pros**: commit に確実に混入を防げる、PlanGate の他 EH-x hook パターンと整合
- **Cons**: 新規 Hook 追加 = `.claude/settings.json` 変更 = Human-owned 操作

### 案 C: claude-mem plugin 機能を完全無効化（要環境変数特定）

claude-mem の AGENTS.md inject を制御する環境変数を特定して `false` にする。

調査必要項目:
- `worker-service.cjs` の `/api/context/inject` API call 条件
- このセッションでは特定できなかった（minified cjs のため）

- **Pros**: 根本対処
- **Cons**: 該当 env が特定できない場合は採用不可

### 案 D: AGENTS.md を symlink → CLAUDE.md にする（推奨度: 中）

```sh
mv AGENTS.md AGENTS.md.bak
ln -s CLAUDE.md AGENTS.md
```

claude-mem が `CLAUDE_MEM_FOLDER_CLAUDEMD_ENABLED=false` で CLAUDE.md を変更しないなら、symlink で AGENTS.md も間接的に保護される。

- **Pros**: 単一ファイル管理
- **Cons**: claude-mem が symlink を辿るか、新規 AGENTS.md を作成するかは不明（実機検証要）

### 案 E: 運用ルール（推奨度: 低・既に運用中）

各 commit / PR push 前に手動で `git restore AGENTS.md` を実行。

- **Pros**: ゼロコスト、即適用可
- **Cons**: 人為的ミスのリスク、本 TASK-0107 セッションでも複数回発生した「割れ窓」問題

## 5. 推奨採用案

**案 A（`.gitattributes` merge=ours）+ 案 B（pre-commit strip hook）の併用**を推奨。

| レイヤー | 案 | 効果 |
|---------|-----|------|
| **コミット前防御** | 案 B（strip hook） | ローカルから AGENTS.md 汚染が外に出ない |
| **マージ後防御** | 案 A（merge=ours） | 万一汚染した branch を merge する際の保険 |

### 案 C の追加調査メモ

将来的に claude-mem 設定で根本無効化できる場合は案 A/B より望ましい。次の調査:

1. claude-mem 公式ドキュメント / リポジトリ（thedotmack/claude-mem）の env reference 確認
2. `/api/context/inject` API を無効化する env flag の特定
3. 上記が判明したら `~/.claude-mem/settings.json` を更新

## 6. 実装責任分担（責務 4 分類）

| 対処 | 分類 | 担当 |
|------|------|------|
| 案 A: `.gitattributes` 新規/追記 | **AI-owned** | AI が PR で提案可能 |
| 案 B: `scripts/hooks/strip-claude-mem-context.sh` 新規 | **AI-owned** | スクリプト本体は AI 作成可 |
| 案 B: `.claude/settings.json` の pre-commit hook 登録 | **Human-owned**（self-mod ガード） | Human が `apply-claude-settings.sh` 経由で適用 |
| 案 C: `~/.claude-mem/settings.json` 編集 | **Human-owned** | グローバル設定のため Human が判断 |
| 案 D: symlink 化 | **Human-owned** | 既存ファイル構造変更のため Human 判断 |

## 7. 次のアクション

1. **Human** が案 A〜E から採用案を選択
2. AI が案 A + B のスクリプト/`.gitattributes` を別 PR で実装提示
3. Human が `.claude/settings.json` への hook 登録を `apply-claude-settings.sh` で実行
4. 採用後しばらく観察し、AGENTS.md 汚染が再発しないことを確認

## 8. 参照

- claude-mem plugin: `~/.claude/plugins/cache/thedotmack/claude-mem/13.2.0/`
- 設定: `~/.claude-mem/settings.json`
- 主要 cjs:
  - `scripts/worker-service.cjs`（AGENTS.md 書き込み実体）
  - `scripts/context-generator.cjs`（context block 生成）
  - `scripts/mcp-server.cjs` / `scripts/server-beta-service.cjs`（API endpoint）
- PlanGate ルール:
  - `.claude/rules/responsibility-classes.md`（AI/Human/CI/Workflow-owned 4 分類）
  - `docs/ai/settings-wiring-contract.md`（settings 適用契約）

---

**結論**: 根本原因は claude-mem plugin v13.2.0 の context inject API による直接書き込み。`CLAUDE_MEM_FOLDER_CLAUDEMD_ENABLED=false` 設定では止まらない。推奨対処は **案 A + 案 B 併用**。実装は Human 承認後の別 PR で進める。
