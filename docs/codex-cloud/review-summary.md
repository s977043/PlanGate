# Codex Cloud導入計画 レビューサマリ

> 作成日: 2026-03-22
> 実行ハンドオフ正本: `.codex/manual-cloud-task.md`

## 概要

AI駆動開発ワークフロー v3を OpenAI Codex Cloud 版でも並行運用できるようにする計画。
Claude Code（Codex CLI v0.115.0 / gpt-5.4）による3回のイテレーティブレビューを実施。
最終方針として、**GitHub上の自動レビューは `@codex review` のみ採用し、Cloud task は人間が手動起動する**。
Cloud task の実行入力は tracked な handoff packet に集約し、`docs/working/STRATEGY-XXXX/` は人間の準備用ソースとして扱う。

## レビュー経緯

| バージョン | レビュー結果 | 主要変更 |
|-----------|-------------|---------|
| v1 | 全4観点FAIL | 初期案。Docker前提衝突、二重管理、max_depth=2、API仕様不整合 |
| v2 | 2FAIL+2WARN | 環境中立化、max_depth=1、.env.githubactions再利用。ただしCloud/Action混同、API名誤り |
| v3 | 1FAIL+3WARN | 公式API準拠、prompt-file化、symlink化。Phase 3（exec）のみFAIL残存 |

## v3 最終判定

| 観点 | 判定 | 根拠 |
|------|------|------|
| 技術的実現可能性 | **WARN** | 自動exec案はFAILだったが、Cloud taskを手動起動に変更することで主要ブロッカーを回避可能 |
| 二重管理リスク | **WARN** | self-review symlink化で改善。plan-generatorのドリフトリスク、self-review中身のDocker前提が残存 |
| Codex Cloud制約整合性 | **WARN** | max_depth=1/Review guidelines/openai-api-keyはPASS。CODEX_SANDBOX環境変数が公式未確認、下位ルールがDocker前提のまま |
| 改善提案 | **PASS** | 段階的導入は妥当。Phase 1-2を先行実装し、Phase 3は手動Cloud task運用として開始可能 |

## 採用方針

- GitHub上の自動化は `@codex review` のみに限定する
- `exec` 相当の実装作業は GitHubコメント起動にしない
- Codex Cloud task は人間が UI から手動起動する
- 実行入力は `.codex/manual-cloud-task.md` の tracked packet にまとめる
- packet には approved plan / todo / test-cases / status の要点だけを転記する
- `prepare-cloud` 実行前に `status.md` へ `## C-3 Gate: APPROVED` を記録する
- 実装結果は PR コメントまたはローカル差分として人間が回収する

## Phase別の実装可否

| Phase | 状態 | 備考 |
|-------|------|------|
| Phase 1: 基盤整備 + @codex review | **実装可能** | CLAUDE.md環境中立化、AGENTS.md拡張、.codex/config.toml、setup.sh |
| Phase 2: Plan生成のCodex対応 | **実装可能** | .agents/skills/、plan-generator、self-review symlink |
| Phase 3: 手動Cloud task実行フロー | **実装可能** | 自動execは採用しない。Cloud UIから手動起動し、成果物連携と手順整備に絞る |

## Phase 3 で自動execを採用しない理由

1. **未文書トリガー依存を避けるため**
   - `@codex review` は公式導線だが、`@codex exec` 前提は採用しない
2. **checkout問題を避けるため**
   - `issue_comment` ベースの PR head checkout 制御を不要にする
3. **bootstrap複雑化を避けるため**
   - GitHub Action側にPHP/Composer/pnpm/PostgreSQLを積む必要をなくす
4. **Cloud環境設定の責務を明確にするため**
   - setup script は Codex settings 側で登録し、Cloud task 実行時だけ使う

## 追加で必要な修正（WARN項目）

- `CODEX_SANDBOX`環境変数依存を削除（公式未確認）
- `.claude/rules/backend-commands.md` と `frontend-commands.md` を環境中立化
- AI運用5原則 第5原則にも自動化タスク例外を追加
- `gh pr view --json reviewDecision --jq .reviewDecision` に変更（より安全）
- `self-review/SKILL.md` の中身を環境中立化
- Cloud task 手動起動手順を `docs/ai-driven-development.md` または専用ガイドに追記
- `./scripts/ai-dev-workflow STRATEGY-XXXX plan|prepare-cloud|sync-cloud` を入口にして半自動化を進める
