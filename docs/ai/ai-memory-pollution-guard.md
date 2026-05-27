# AI Memory Pollution Guard (#355 / TASK-0113)

> AI memory ツール (claude-mem 等) による SSoT 汚染を git pre-commit 層で検知。
> Hook 強制化 (PreToolUse 経路) は scope 外、V2 候補。

## 目的

`AGENTS.md` 等の SSoT (Single Source of Truth) ドキュメントに **AI memory ツール (claude-mem 等) が context block を自動挿入** する事象を **git pre-commit 層で検知 + block**。

## 検知パターン (既定)

| Pattern ID | 検知文字列 | 対象 |
|-----------|-----------|------|
| `claude-mem-context` | `<claude-mem-context>` | AGENTS.md (既定) |

設定: `.plangate-pollution-patterns.yaml` で追加可能 (CLAUDE.md / DESIGN.md 等を対象に拡張)。

## 実害背景

本セッション (2026-05-26〜28) で **PR #376 (TASK-0108) / PR #383 (TASK-0117) / PR #383 (TASK-0117)** で AGENTS.md が claude-mem の `<claude-mem-context>` ブロックで dirty 化、`git add -A` で誤混入する事例が複数回発生。本 hook で構造解消。

## install (opt-in)

```sh
# 通常 install
sh scripts/install-pre-commit.sh

# 適用前確認
sh scripts/install-pre-commit.sh --dry-run
```

### install 内容

- `scripts/templates/pre-commit.sample` → `.git/hooks/pre-commit` にコピー
- 既存 hook は `.bak` に退避 (同一内容なら skip = idempotent)
- TASK-0114 install-pre-push.sh と並列構造

## 設定 (`.plangate-pollution-patterns.yaml`)

```yaml
patterns:
  - id: claude-mem-context
    description: claude-mem (AI memory tool) が自動挿入する context block
    regex: '<claude-mem-context>'

target_files:
  - AGENTS.md
  - CLAUDE.md   # 任意追加
  - DESIGN.md   # 任意追加
```

Schema: `schemas/plangate-pollution-patterns.schema.json`

### YAML parser 仕様 (R-003)

- `python3` の `yaml` モジュール (PyYAML) で読む
- PyYAML 不在時は **JSON-like fallback** (config が JSON 互換なら parse 可)
- YAML 自体不在時は埋め込み既定 (`claude-mem-context` / `AGENTS.md`)

## 検知時の挙動

### Default (block)

```text
[ai-mem-guard] ⚠️ AI memory pollution 検出:
  AGENTS.md: pattern_id=claude-mem-context

[ai-mem-guard] 対処:
  1. 検出された pattern を削除:
     git checkout -- AGENTS.md
  2. allowlist marker で個別許可:
     <!-- plangate-pollution-allowlist:<pattern-id> -->
  3. auto-revert mode:
     PLANGATE_POLLUTION_AUTO_REVERT=1 git commit
```

### Auto-revert mode (R-002)

```sh
PLANGATE_POLLUTION_AUTO_REVERT=1 git commit
```

検知時に `git checkout HEAD -- <file>` で **自動 revert**。

**安全機構 (R-002 CRITICAL)**: 対象 file に **unstaged 変更がある場合は auto-revert せず block**。`git diff --name-only` で unstaged check。

## allowlist marker (false positive 対応、R-004)

正規 context として `<claude-mem-context>` を含めたいケース (例: 本 doc 自体) は **allowlist marker** で個別許可:

```markdown
本 doc 末尾等に追加:
<!-- plangate-pollution-allowlist:claude-mem-context -->
```

**適用範囲**: pattern id 単位 + ファイル単位。同一ファイル内で marker があれば該当 pattern のみ無効化、他 pattern は引き続き検出。

<!-- plangate-pollution-allowlist:claude-mem-context -->

## skip 条件 (R-005)

| 条件 | 動作 |
|------|------|
| 巨大 file (> 1MB) | skip (性能保護) |
| binary file (NUL byte in first 512B) | skip |
| rename / deleted | skip (`diff-filter` で対応) |
| 対象 file 不一致 | skip |
| empty staged diff | skip |

## bypass (緊急、非推奨)

```sh
git commit --no-verify
```

git client 標準の全 hook skip。**監査ログに残らない**ため緊急時のみ。

## Defense in Depth (層分離)

| 層 | 機構 | scope |
|----|------|-------|
| **本 hook (git pre-commit)** | 文字列 pattern 検知 | **本 PBI TASK-0113** |
| **TASK-0114 (pre-push hook)** | main 直接 push 物理 block | INC P-1 |
| **TASK-0115 (.claude/rules/ guard)** | AI 行動規範 (Bash 連結 / branch verify) | INC P-3 |

3 層組合せで物理 + 規範 + コンテンツの三段防御。

## PreToolUse 経路は scope 外 (R-009)

本 PBI は **git pre-commit 専用**。Claude Code / Codex CLI / Cursor の PreToolUse hook (JSON プロトコル) には配線しない。

理由: PreToolUse hook は JSON `{hookSpecificOutput: {permissionDecision}}` 形式を要求するが、本 hook は単純な exit code (0/1) で git pre-commit に最適化されている。混在実装は複雑度を増すため別 PBI で扱う (V2 候補)。

## ta-16 (TASK-0113 ユニットテスト)

`tests/extras/ta-16-pollution-guard.sh` (ta-15-codex-hook-bridge 衝突回避済 / R-007 CRITICAL):

| TC | 検証 |
|----|------|
| TC-01 | clean AGENTS.md は通過 |
| TC-02 | `<claude-mem-context>` 検出 → block |
| TC-03 | allowlist marker でスキップ |
| TC-04 | 巨大 file skip |
| TC-05 | binary file skip |
| TC-06 | rename / deleted skip |
| TC-07 | auto-revert mode + unstaged 併存 → block |

## トラブルシューティング

### Q: false positive で正常な commit が block される

1. `<!-- plangate-pollution-allowlist:<pattern-id> -->` で個別許可
2. `.plangate-pollution-patterns.yaml` で対象 file から除外
3. 緊急時 `git commit --no-verify`

### Q: claude-mem の自動挿入を完全に止めたい

本 hook は **検知** で、claude-mem 本体の挙動変更は scope 外。claude-mem の設定で SSoT への挿入を無効化することを推奨 (本 hook と組合せ)。

## 関連

- Issue: [#355](https://github.com/s977043/plangate/issues/355)
- 実害背景: PR #376 (TASK-0108) / PR #383 (TASK-0117) で AGENTS.md 誤混入
- 並列構造: [TASK-0114 (#360) pre-push hook](./direct-push-prevention.md) (INC P-1)
- 行動規範: TASK-0115 (#361) responsibility-classes.md (INC P-3)
