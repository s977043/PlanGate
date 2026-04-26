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

## GitHub Discussions

GitHub Discussions は有効化済みであることを確認した（2026-04-27）。

### カテゴリ構成

| カテゴリ | 用途 | Answerable |
| --- | --- | --- |
| Announcements | リリースノート・重要告知 | No |
| General | 雑談・感想・近況 | No |
| Ideas | 機能提案・将来構想 | No |
| Polls | 意見募集 | No |
| Q&A | 使い方・設定・トラブル相談 | Yes |
| Show and tell | 活用事例・ブログ紹介 | No |

現在のカテゴリは GitHub デフォルト構成で十分。変更は外部コントリビューターが増えてから検討する。

### Discussion Policy（用途の使い分け）

| 用途 | 使う場所 |
| --- | --- |
| バグ、再現可能な問題 | Issue |
| 機能要望、明確な改善提案 | Issue |
| 質問、運用相談、設計議論 | Discussions — Q&A |
| 活用事例・ショーケース | Discussions — Show and tell |
| セキュリティ懸念 | Private vulnerability reporting |

## Deferred Decisions

各項目の判断状況を記録する（2026-04-27 更新）。

| 項目 | 判断 | 着手条件 |
| --- | --- | --- |
| Required approvals `1` | 条件付き着手 | 外部コントリビューターが 3 名以上になったとき |
| CODEOWNERS review required | 条件付き着手 | owner が 2 名以上になったとき |
| Scorecard required check | 条件付き着手 | Scorecard スコアが 5.0 以上で安定したとき |
| GitHub Actions allowlist | 着手しない | SHA pinning で対応済み。リスクが具体化した場合のみ再検討 |

### 各項目の判断根拠

**Required approvals `1`**: 単独メンテナ運用では自己マージが必要なため、現状は `0` を維持する。外部コントリビューターが 3 名以上になり PR がメンテナ以外からも来るようになった段階で `1` に変更する。

**CODEOWNERS review required**: 1 名体制では CODEOWNERS によるレビュー強制が実質的な意味を持たない。複数 owner 体制になってから有効化する。

**Scorecard required check**: Scorecard スコアは外部依存（推奨設定の更新・ツール変更）で変動する。まず 3 ヶ月以上スコアを観測し、5.0 以上で安定することを確認してから required check に昇格させる。

**GitHub Actions allowlist**: `.github/workflows/` の全 Action が SHA pinning 済みのため、現状はサプライチェーンリスクが低い。allowlist 管理はメンテナンスコストが高いため、具体的なリスクが発生した場合のみ対応する。

### Branch Protection 強化ロードマップ

外部コントリビューターが増えた場合の段階的な強化方針:

| 段階 | 条件 | 追加設定 |
| --- | --- | --- |
| 現状 | 単独メンテナ | Pull Request 必須、lint チェック必須 |
| フェーズ 2 | コントリビューター 3 名以上 | Required approvals `1` を有効化 |
| フェーズ 3 | 複数 owner | CODEOWNERS review required を有効化 |
| フェーズ 4 | Scorecard 5.0+ で安定 | Scorecard を required check に昇格 |
