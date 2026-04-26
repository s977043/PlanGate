# OSS Governance

PlanGate を OSS として公開・運用するための設定と判断基準を記録する。

## 公開状態

| 項目 | 状態 |
| --- | --- |
| Repository visibility | Public |
| License | MIT License |
| GitHub Pages | `main` / `docs` |
| Pages URL | <https://s977043.github.io/plangate/> |
| Issues | Enabled |
| Discussions | Enabled |
| Wiki | Disabled |
| Security policy | `SECURITY.md` |
| Contributing guide | `CONTRIBUTING.md` |
| Code of conduct | `CODE_OF_CONDUCT.md` |

## Repository Metadata

| 項目 | 値 |
| --- | --- |
| Description | `Gate-based workflow for AI coding agents` |
| Topics | `ai`, `ai-agents`, `ai-driven-development`, `claude-code`, `codex`, `harness-engineering`, `workflow` |
| Homepage | <https://s977043.github.io/plangate/> |

## Branch Protection

Default branch ruleset `Protect default branch` を使用する。

現在の必須ルール:

- default branch の削除禁止
- force push 禁止
- Pull Request 必須
- review thread resolution 必須
- `Markdown lint` 必須

現在は単独メンテナ運用を想定し、required approvals は `0` のままにしている。

## Required Checks

| Check | 目的 |
| --- | --- |
| `Markdown lint` | README、コミュニティファイル、Workflow docs の Markdown 品質確認 |

OpenSSF Scorecard は定期実行と main push で実行するが、現時点では required check にはしない。Scorecard は外部要因や推奨設定の変更で結果が揺れる可能性があるため、まずは観測用として扱う。

## Pages Publishing Policy

GitHub Pages は `docs/index.md` を公開入口にする。

公開サイトの主要導線に含める:

- `docs/philosophy.md`
- `docs/plangate.md`
- `docs/plangate-v7-hybrid.md`
- `docs/workflows/README.md`
- `docs/plangate-plugin-migration.md`

主要導線から外す:

- `docs/working/`
- チケット単位のレビュー記録
- セッション振り返り
- 一時的な handoff や evidence

`docs/_config.yml` では `working/` を除外する。

## Discussion Policy

Discussions は Issue と用途を分ける。

| 用途 | 使う場所 |
| --- | --- |
| バグ、再現可能な問題 | Issue |
| 機能要望、明確な改善提案 | Issue |
| 質問、運用相談、設計議論 | Discussions |
| セキュリティ懸念 | Private vulnerability reporting |

## docs/working/ 公開方針

### 方針：意図的に Public 公開する

`docs/working/TASK-XXXX/` 配下のチケット単位の作業ログ（plan.md / todo.md / review-self.md / handoff.md 等）は、リポジトリが Public のためだれでも閲覧可能な状態にある。これは **意図的な判断**である。

PlanGate は「AIが計画と承認の証跡を残しながら開発する」ことを原則としており、その証跡を公開することはプロジェクトの透明性・監査可能性を高める。

### 個人情報・機密情報を含まないことの確認方針

`docs/working/` にコミットするファイルに含めてはならない情報:

- 個人名・メールアドレス・連絡先
- API キー・トークン・パスワード・認証情報
- 内部システムの URL や IP アドレス
- 社外秘の仕様・契約情報

コミット前に作成者が上記を含まないことを確認する。CI による自動検出（secret scanning）は GitHub の機能として有効化済み。

### GitHub Pages 除外の理由

`docs/_config.yml` で `working/` を除外しているのは、Pages のナビゲーションに作業ログが露出すると閲覧体験が損なわれるためであり、機密保護が目的ではない。

リポジトリ直接アクセスでは引き続き閲覧可能であることを前提として運用する。

### .gitignore 対象にするか

現時点では **しない**。証跡の公開はプロジェクトの設計思想であり、除外することは透明性を損なう。将来的に個人情報を含むケースが生じた場合は、該当ファイルのみを削除（`git rm`）する運用とする。

### AGENT_LEARNINGS.md の位置づけ

`AGENT_LEARNINGS.md` は AI エージェントの内部運用ノートとして維持する。

- リポジトリに含める（Public 公開）
- 個人情報・機密情報を含まないことを作成・更新のたびに確認する
- GitHub Pages の主要導線からは除外する（ナビゲーションに含めない）

## Deferred Decisions

次の設定は、運用体制が固まってから有効化を検討する。

| 項目 | 現状 | 保留理由 |
| --- | --- | --- |
| Required approvals `1` | 未設定 | 単独メンテナ運用では自己マージが詰まる可能性がある |
| CODEOWNERS review required | 未設定 | 現時点では owner が 1 名で実効性が低い |
| Scorecard required check | 未設定 | 観測用途として先に運用する |
| GitHub Actions allowlist | 未設定 | workflow 側で SHA pinning 済み。必要に応じて後で制限する |
