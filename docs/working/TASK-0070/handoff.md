---
task_id: TASK-0070
artifact_type: handoff
schema_version: 1
status: draft
---

# HANDOFF — TASK-0070 (P4(d) EH-3 ファイルパス感応型 SKIP)

## 1. 要件適合確認結果

| AC | 内容 | 判定 | 根拠 |
|----|------|------|------|
| AC-1 | no-task + plan.md → BLOCK exit2 + VIOLATION 監査 | PASS | V-1 実機: rc=2, BLOCK msg, _audit に VIOLATION |
| AC-2 | no-task + 非plan → SKIP exit0 + 監査 | PASS | V-1: rc=0, SKIP ログ |
| AC-3 | STRICT=1 + no-task → exit2（対象不問） | PASS | V-1: rc=2 |
| AC-4 | TASK ctx ありはハッシュ検査不変 | PASS | 既存 EH-3 4テスト全 PASS（回帰なし） |
| AC-5 | PLANGATE_HOOK_FILE > $2 > stdin JSON 解決 | PASS | V-1: arg2/stdin 双方で正しく解決 |
| AC-6 | PLANGATE_BYPASS_HOOK=1 不変 | PASS | V-1: rc=0 BYPASS |
| AC-7 | dash -n POSIX 構文 | PASS | syntax OK |
| AC-8 | EH-3 wiring が PLANGATE_HOOK_FILE を渡す（F1-b） | **WARN / 保留** | Claude 自己改変ガードにより `.claude/settings*.json` を Claude が編集不可。ユーザー手動適用待ち（§2） |

V-3（Gemini）: critical2/major2 を検出 → **全件修正・回帰テスト化**（TC-9〜13、60/60 green）。Codex は PR #242 マージ後に補完（非ブロッキング）

テスト: `tests/hooks/run-tests.sh` **60 passed / 0 failed**（P4d TC-1〜13、V-3 修正の回帰含む）

V-3 外部レビュー（Gemini）: 初回 REJECT（critical2/major2）→ 全 critical/major 修正・回帰テスト化済み。詳細 review-external.md

## 2. 既知課題一覧

- **AC-8 wiring 未適用**: `.claude/settings.json` / `.claude/settings.example.json` の
  EH-3 command 末尾に `${PLANGATE_HOOK_FILE:-}` を追加する必要あり。Claude Code の
  自己改変ガードにより Claude では適用不可。ユーザーが以下を手動適用:
  ```
  sed -i '' 's#check-plan-hash.sh ${PLANGATE_HOOK_TASK:-}"#check-plan-hash.sh ${PLANGATE_HOOK_TASK:-} ${PLANGATE_HOOK_FILE:-}"#' .claude/settings.json .claude/settings.example.json
  ```
  未適用でも実運用では Claude Code が PreToolUse stdin に JSON を渡すため stdin
  fallback で target_file は解決される（AC-5 stdin 経路で検証済み）。wiring 追加は
  env 経由の二重化（belt-and-suspenders）。

- **stdin 消費の残留懸念（V-3#3）**: `_stdin=$(cat)` は PreToolUse stdin を消費する。
  Claude Code は hook ごとに event JSON のコピーを渡すため実害は確認されていないが、
  パイプライン共有実装に変わった場合に後続ツールへ影響し得る。env/`$2` 優先設計で
  通常は stdin を読まないため低リスク。将来 stdin 共有が判明したら一時ファイル方式へ。

## 3. V2 候補

- **方針レビュー派生 V2（Codex×Gemini 合意, direction-codex-gemini.md）**:
  (1) AC-8 Manual Gate 化 + Shadow Config ロック (2) settings drift check CI required
  (3) EH-3 バイパス不要化（メンテモード/除外タグ）+ SKIP_REASON 例外申請プロトコル
  (4) 責務 4 分類（AI/Human/CI/Workflow-owned）の正式文書化

- 他 Hook（EH-1/2/4-8）への同種ファイルパス感応ロジック横展開の要否評価
- stdin JSON パーサの共通関数化（現状 sed inline、各 hook 重複）

## 4. 妥協点

- F-1 で F1-a（fail-safe=BLOCK）/F1-c（残留リスク受容）ではなく **F1-b**（wiring
  In scope 化）を C-3 採用。理由: セキュリティ強制 Hook 改修でセキュリティ穴を
  残すのは本末転倒。ただし AC-8 wiring は Claude 適用不可のためユーザー手動に委譲。
- 草案パッチ /tmp/p4d-check-plan-hash.patch をベースに、stdin JSON 抽出の堅牢化
  と監査ログ文言を本 PBI で再検証して反映（草案を鵜呑みにせず）。

## 5. 引き継ぎ文書（5分サマリ）

EH-3 (check-plan-hash.sh) が TASK 文脈なし汎用 Edit を一律 exit2 ブロックし
heredoc 回避が常態化していた問題を、Gemini 推奨の P4(d)「plan.md 編集だけは
no-task で BLOCK、それ以外は SKIP」ロジックで解決。実装・テスト（55/55）・
V-1（AC-1〜7 PASS）完了。残作業は (a) ユーザーによる wiring 2行手動適用、
(b) V-3 外部レビュー（Codex は PR #242 マージ後に復活）、(c) C-4 PR レビュー。

## 6. テスト結果サマリ

- `sh tests/hooks/run-tests.sh`: 55 passed, 0 failed
- 新規: P4d TC-1〜8（red→green 確認済み）
- 回帰: 既存 EH-1〜EH-8 / EHS-1 全 PASS
- 静的: `dash -n` PASS
