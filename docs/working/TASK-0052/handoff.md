---
task_id: TASK-0052
artifact_type: handoff
schema_version: 1
status: final
issued_at: 2026-05-01
author: qa-reviewer
v1_release: ""
related_issue: 171
---

# Handoff: TASK-0052 / Issue #171 — gh CLI active account 自動固定 shim

## 1. 要件適合確認結果

| AC | 判定 | 根拠 |
|----|------|------|
| AC-1: 冪等性 | PASS | 2 回実行で問題なし、結果一致 |
| AC-2: already pinned 検出 | PASS | `gh api user --jq .login` で現在 user 取得、一致時に "already pinned" |
| AC-3: switched 通知 | PASS | 別 user → `gh auth switch -u $DESIRED_USER` 成功時 "switched to" |
| AC-4: 不在 user で exit 1 | PASS | `gh auth status` に該当 user がなければ "not in gh auth status" + exit 1 |
| AC-5: gh 不在で exit 1 | PASS | `command -v gh` で検出、stderr "not installed" |
| AC-6: SessionStart hook 登録 | PASS | `.claude/settings.example.json` に SessionStart entry |

**総合**: **6 / 6 PASS**

## 2. 既知課題一覧

| 課題 | Severity | 状態 |
|------|---------|------|
| `gh api user` が API rate limit で失敗する可能性 | minor | accepted（fallback あり）|
| 切替後すぐの API 呼び出しは時々遅延 | info | accepted（運用で気にならないレベル）|
| 上流 gh CLI の自動切替バグの根本解消はしていない | info | accepted（workaround アプローチ）|

## 3. V2 候補

| V2 候補 | 理由 | 優先度 |
|--------|------|--------|
| Codex / Gemini 用の同等 hook 提供 | クロスツール対応 | Low |
| gh CLI 上流バグの調査 + report | 根本解消 | Low |
| direnv / mise との統合 | 自動化深化 | Low |

## 4. 妥協点

| 選択 | 諦めた代替 | 理由 |
|------|-----------|------|
| `.claude/settings.example.json` opt-in | 実 `.claude/settings.json` 直接登録 | 開発者環境の差異を尊重、自動適用しない |
| `gh api user` で active 取得 | `gh auth status` のみ解析 | API call なら確実、parse の脆さ回避 |
| デフォルト `s977043` ハードコード | repo config から動的取得 | git remote URL から取得は複雑、env override で十分 |

## 5. 引き継ぎ文書

### 概要

plangate での作業中に gh CLI active account が想定外に kominem-unilabo へ切り戻る現象（retrospective 2026-05-01 P-1、本セッションで 4 回以上発生）への workaround。`scripts/gh-pin-account.sh` で現在 user を確認し、必要時のみ `s977043` に切替。SessionStart hook として `.claude/settings.example.json` に opt-in 登録。

主要成果:
- `scripts/gh-pin-account.sh`（POSIX sh、冪等、`PLANGATE_GH_USER` で override 可能）
- `.claude/settings.example.json` に SessionStart hook 追加

### 触れないでほしいファイル

- `scripts/gh-pin-account.sh` の `gh api user` fallback 順序: 環境差異対応で重要

### 次に手を入れるなら

- 実 `.claude/settings.json` への登録は開発者の手動 opt-in
- 他 fork の開発者は `PLANGATE_GH_USER` を export してから session 開始

## 6. テスト結果サマリ

| レイヤー | 件数 | PASS | FAIL / SKIP |
|---------|------|------|-----------|
| Manual smoke | 4 | 4 | 0 / 0 |

検証コマンド:
```sh
sh scripts/gh-pin-account.sh                                # already pinned / switched
PLANGATE_GH_USER=non-existent sh scripts/gh-pin-account.sh  # exit 1
grep -E '"SessionStart"' .claude/settings.example.json      # match
```
