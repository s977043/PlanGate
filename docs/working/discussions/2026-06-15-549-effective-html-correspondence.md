# effective-html ↔ PlanGate render 対応表（#549）

> **Status**: 設計 / 参考ドキュメント（2026-06-15）
> **位置づけ**: #547 受入条件「effective-html との対応表を残すこと」を満たす成果物。本ドキュメントは #549（#547 の残部）として、effective-html の skill 群と PlanGate `plangate render` 実装の対応関係・採否・設計差分を単一正本として記録する。
> **対象実装**: `bin/plangate cmd_render`（L2209-2231）→ `scripts/render_review.py`（Markdown→自己完結 HTML レンダラ）

## 1. サマリ

PlanGate の `plangate render` は、effective-html の **html-plan**（プラン文章を実用的・自己完結 HTML にする）と **html**（汎用 1 ファイル HTML）の中核思想を採用し、C-3 レビュー成果物（7 種の Markdown アーティファクト）を 1 つのオフライン閲覧可能な HTML に集約する。一方、**html-diagram**（SVG アーキテクチャ図）は本実装の範囲外とし、別 issue #548 に切り出す。

実装方針の最大の差分は、effective-html が **agent skill（外部配布・npx 等での明示呼び出し前提）** であるのに対し、PlanGate render は **Python 標準ライブラリのみの CLI 内製** とした点。これはユーザー方針「依存を増やさない」と、Codex 相談で確認した「公式成果物のレンダリングは CLI 責務」という整理に基づく。

> **effective-html 記述の出典範囲**: 本ドキュメントの effective-html 側の記述は、`accessible=true` で実体到達した各 `SKILL.md`（frontmatter + 本文指示文）に依拠する。**各 skill が実際に生成する HTML の見た目・挙動そのものは本調査で実行検証していない**（SKILL.md の指示文＝設計意図の引用）。未精読範囲は §6 を参照。

## 2. 対応表

| effective-html skill / 概念 | PlanGate render の対応 | 採否 | 備考 |
|---|---|---|---|
| **html-plan**（SKILL.md 指示文: プラン文章を改変せず実用的・視覚整理された自己完結 HTML プランページにする。`disable-model-invocation: true`、SKILL.md 749B） | `render_review.py` の Markdown→自己完結 HTML 変換 + **承認観点ナビ**（Goal/Scope/Risk/Test/Stop/承認 の 6 観点を見出しスキャンでアンカー化、`build_perspective_nav`）+ sticky TOC。plan.md / pbi-input.md / todo.md 等の計画系 MD をそのまま「読める HTML」に整える | **採用** | html-plan の「原文を大きく改変せず文法清書レベルで視覚整理する」思想（SKILL.md 記載）を踏襲。render は MD を加工せず構造化表示するため、改変ゼロは render の方がさらに厳格 |
| **html**（SKILL.md 指示文: ダイアグラム/プランに限定されない汎用 1 ファイル HTML。レポート・解説・比較・デック等。`disable-model-invocation: true`、SKILL.md 783B） | 出力は **単一 self-contained HTML**（CSS は単一 `<style>` にインライン、外部 CDN/script なし、JS なし、オフライン完結）。7 アーティファクトを `<section class="doc">` で集約し、GitHub 風の light テーマで描画 | **概念採用** | 「1 つの HTML ファイルとして届けるのが最適」という汎用思想（SKILL.md 記載）を、C-3 レビュー成果物の集約という具体用途に限定して採用。SKILL.md が必須要件として記述するダークモード（CSS 変数 / トグル / localStorage / apply-before-paint）は render では未実装（light 固定） |
| **html-diagram**（SKILL.md 指示文: フルスクリーン高品質 SVG でアーキテクチャを可視化。SVG は CSS 変数でテーマ追従、hex ハードコード禁止と指示。SKILL.md 1526B） | 未対応（render は SVG ダイアグラム生成機能を持たない） | **別 issue #548** | SVG アーキテクチャ図解は render のスコープ外。`render_review.py` は MD→HTML の line parser であり、図解生成は別系統の責務。#548 で扱う |
| `disable-model-invocation: true`（モデル自動起動を無効化、明示呼び出し前提） | `plangate render <TASK-XXXX>` という明示 CLI 呼び出しでのみ起動。モデルが自動で render を呼ぶ経路はない | **採用（思想一致）** | effective-html と同じく「明示呼び出し前提」。CLI コマンドとして人間/ワークフローが意図的に起動する設計 |
| `references/html-effectiveness/` をレビューしてスタイル踏襲（SKILL.md 指示） | 該当機構なし。render は固定の GitHub 風インライン CSS テーマ（`build_html` 内 CSS 文字列 L228-259）を持つ | **不採用（別設計）** | effective-html は references を都度参照して密度/トーンを合わせる（SKILL.md 記載。references 実体は未精読）が、render は決定論的な固定テーマで再現性を優先（同じ入力→同じ出力） |
| ダークモード（SKILL.md が必須要件として記述: CSS 変数 / テーマ切替トグル / localStorage 永続化 / apply-before-paint） | 未実装（light テーマ固定、JS なし） | **不採用（残課題候補）** | render は「JS なし・完全オフライン・決定論」を優先したため、JS 依存のテーマ切替を持たない。将来 CSS のみのダークモード対応は検討余地あり（残課題 §5 参照） |

> 上表 effective-html 側セルは SKILL.md の指示文（設計意図）の引用であり、出力 HTML の見た目そのものは未検証。

## 3. 設計差分（なぜ CLI 内製にしたか）

| 観点 | effective-html | PlanGate render |
|---|---|---|
| 配布形態 | agent skill（リポジトリ配布、明示呼び出し前提） | `bin/plangate` 内蔵 CLI サブコマンド + `scripts/render_review.py` |
| 依存 | skill 実体に依存（references 群のレビューを伴う） | **Python 標準ライブラリのみ**（argparse / html / os / re / sys）。新規 pip/npm 依存ゼロ |
| Markdown 変換 | （skill の生成能力に委ねる） | 手書き正規表現 line parser（`md_to_html`）。markdown ライブラリ非依存 |
| 出力決定性 | references 参照によりスタイルが文脈依存 | 固定テーマで決定論的（同一入力→同一 HTML） |
| ランタイム要件 | skill 実行環境 | `python3` が PATH にあること（local env は Python 3.14.2） |

### 採用理由

- **ユーザー方針「依存を増やさない」**: effective-html を skill として取り込むと外部 skill 実体・references・配布メタへの依存が増える。render は標準ライブラリのみで自己完結し、追加 pip/npm パッケージをゼロに保つ。
- **Codex 相談での整理「公式成果物のレンダリングは CLI 責務」**: C-3 レビュー成果物（plan / todo / test-cases / review-self / review-external / handoff / pbi-input）は PlanGate の公式アーティファクトであり、その HTML 化はワークフロー基盤（CLI）の責務とする方が、生成系 skill に委ねるより再現性・監査性・オフライン性で有利。
- **決定論性**: 同じ 7 ファイルから常に同じ HTML を出力できることが、レビュー証跡・監査の観点で重要。固定テーマ・JS なしの設計はこの要件と整合する。

## 4. セキュリティ受入条件（#547）の充足状況

#547 が求めるセキュリティ受入条件に対する `render_review.py` の充足状況:

| 受入条件（#547） | render の充足状況 | 充足 | 根拠 |
|---|---|---|---|
| 外部 script / CDN を参照しない | 全 CSS を単一 `<style>` にインライン化、JavaScript ゼロ、外部 stylesheet/script/CDN 参照なし。完全オフライン閲覧可能 | ✅ 充足 | `build_html`、`bin/plangate` L2208「外部 CDN 依存なし」明記。実出力の grep でも `<script>`/`<link rel=stylesheet>`/外部 CSS・JS の読み込みゼロを確認 |
| 外部画像を参照しない | レンダリング時/出力に一切のネットワーク fetch・リモートリソース読み込みなし。読むのは work-dir 配下のローカル MD のみ | ✅ 充足 | 外部参照ゼロ設計 |
| innerHTML 直挿し禁止（XSS 防止） | そもそも JS を含まないため innerHTML 直挿しの経路が存在しない。全テキストは `html.escape` 適用後にインライン整形、code span/block も escape。リンクは scheme allowlist（http/https/mailto のみ）で `javascript:` / `data:` をリンク化せずラベルのみ描画（script 注入なし）、href は `html.escape(quote=True)` | ✅ 充足 | `_inline` / `_link_sub` / `_ALLOWED_SCHEMES`。なお `_LINK` 正規表現は href 内の最初の `)` で打ち切るため、括弧を含む URL は末尾が素テキスト化する場合があるが、無害化（許可外スキームのリンク無効化）は成立する |
| 機密情報の混入禁止 | render は固定 7 ファイル allowlist（`C3_ARTIFACTS`）のみ読み込み、glob/任意ファイル取り込みなし。task id は `^TASK-[0-9]{4}$` で厳格検証してからファイルアクセス | ✅ 充足（入力範囲を限定） | `C3_ARTIFACTS` allowlist。strict 4 桁検証＝ファイルアクセスを gate するのは `scripts/render_review.py`（L317-319）。wrapper（`bin/plangate`）の `plangate_validate_task_id` は `TASK-[A-Za-z0-9-]*` の緩い形式チェックのみで、4 桁限定の厳格性は script 側が担う |

### 注意（hard sandbox ではない点）

- `--out` / `--work-dir` のパスは制約されない。呼び出し元が指定した出力パスはそのまま書き込まれる（path-traversal ガードなし）。攻撃者制御の MD 内容は escape されるため script は注入できないが、ファイル自身の untrusted text はそのまま描画される。出力パスの妥当性は呼び出し側（人間/ワークフロー）の責務。
- なお `bin/plangate` wrapper は `--html` を受理するが Python へ転送しない（no-op。HTML が唯一の出力のため）。`--work-dir` は wrapper の引数解釈にケースが無く転送されない（直接 `python3 scripts/render_review.py --work-dir DIR` でのみ指定可能）。

## 5. 残課題

| 課題 | 区分 | 内容 |
|---|---|---|
| html-diagram（SVG アーキテクチャ図解） | **別 issue #548** | effective-html の html-diagram に相当する SVG 図解生成は render のスコープ外。#548 で別途検討する |
| 固定セクションテンプレ強制の是非 | 要検討 | render は 7 アーティファクトを固定表示順（`C3_ARTIFACTS`）・固定セクション構造で出力する。これは決定論・監査性に寄与する一方、テンプレ強制が柔軟性を損なう懸念がある。固定強制を継続するか、任意セクション追加を許すかは未決 |
| ダークモード対応 | 検討余地 | SKILL.md 上は effective-html の必須要件と記述されるが、render は light 固定（JS なし優先）。CSS のみ（`prefers-color-scheme`）でのダークモード対応は JS 非依存のまま実現可能なため、将来的な追加余地として残す |
| render の単体テスト不在 | 技術負債 | `tests/` に `render_review` 専用のユニットテストが存在しない（codex-log fixtures が偶然 "render" 語を含むのみ）。XSS escape・リンク allowlist・table/checklist 変換の回帰テスト整備は今後の課題 |

## 6. 出典と不確実性の明示

- **effective-html の skill 実体**: `plannotator/effective-html`（public / MIT / default_branch=main）の `skills/html-plan/SKILL.md`（sha fbd3b66, 749B）/ `skills/html-diagram/SKILL.md`（sha e21ecc2, 1526B）/ `skills/html/SKILL.md`（sha f2a2e27, 783B）を実体到達（`accessible=true`）し、frontmatter（name/description）と本文指示文から事実ベースで抽出した。**抽出したのは SKILL.md の指示文（設計意図）であり、各 skill が出力する HTML の実際の見た目・挙動そのものは本調査で実行検証していない**。
- **未精読・断定回避**: html-diagram が参照する `references/architecture-example.html` の中身、`references/html-effectiveness/` 配下の個別ファイル内容、配布メタ（skills.sh.json / .claude-plugin / .codex-plugin）は本調査で精読していない（ディレクトリ存在のみ確認）。各 skill が「具体的にどんな視覚スタイルを出力するか」の詳細は SKILL.md 記載範囲を超えて断定していない。3 skill とも厳密な引数スキーマは frontmatter に未定義（`disable-model-invocation: true` で明示呼び出し前提）。
- **PlanGate render の実体**: `bin/plangate`（cmd_render, L2209-2231）/ `scripts/render_review.py`（行番号は調査時点の実装に基づく）の実コードから抽出。本検証では実際に `python3 scripts/render_review.py` を実行し、自己完結性（外部 script/CSS/CDN 読み込みゼロ・JS ゼロ）、scheme allowlist による `javascript:`/`data:` 無害化、`html.escape` による `<script>` 注入防止を実測で確認した。
- effective-html の各 skill は本調査時点で `accessible=true`（実体到達成功）のため、本対応表の effective-html 記述は SKILL.md 実ファイル由来であり「出典: issue #547 記載」のみに依拠する断定は含まない。ただし上記のとおり、出力結果の挙動までは検証していない（SKILL.md の設計意図の引用）。
