# Retrospective — 2026-05-04 〜 2026-05-06 (v8.6.0 リリース + 改善 7 PR)

> **期間**: 2026-05-04（v8.6.0 完成）〜 2026-05-06（PR #214 マージで懸案クリア）
> **形式**: 1 セッション横断（複数日跨ぎ）
> **トリガー**: 「v8.6.0 完成まで進めて」→「v8.6.0 リリース」→「v8.6.0 範囲で深掘り」x4 + Issue #191 対応 + PR #214 整理

## 1. セッション概要

| 観点 | 値 |
|------|---|
| マージ済 PR | **9 件** (#208 / #209 / #210 / #214〜#221) |
| Close 済 Issue | 4 件 (#194 / #195 / #201 / #202) |
| GitHub Release | **v8.6.0**（[release notes](https://github.com/s977043/plangate/releases/tag/v8.6.0)）|
| Milestone 完走 | **v8.6.0**（P0 4 PBI、closed）|
| Test 累計 | 74 → **100 PASS**（regression 0、+22 / +35%）|

## 2. KPT

### Keep（継続）

#### K-1: 依存順守の連続実装パターン
v8.6.0 milestone を Phase A (#194 Baseline / #201 Governance / #202 Privacy) → Phase B (#195 Metrics v1) の順で実装。Privacy policy (#202) を先に置いたことで、Metrics v1 schema (#195) が `additionalProperties: false` + 物理排除設計を最初から採用でき、後付けにならなかった。

#### K-2: 改善 7 PR の段階的多層化
リリース後の v8.6.0 範囲改善で、privacy 強制を **1 層 → 4 層** に拡張:

| 層 | 仕組み | 導入 PR |
|----|--------|---------|
| 1 | `.gitignore` | v8.6.0 リリース時 |
| 2 | Hook EH-8 (local) | PR #215 |
| 3 | Schema additionalProperties:false + negative test | PR #215 |
| 4 | CI workflow (Hook EH-8 strict + tracked detection) | PR #219 |

各層が独立に動くため、1 層が緩んでも他 3 層が補う。

#### K-3: TDD と regression 0 の維持
全 PR で先にテストを書く（または既存テストの拡張）→ コード実装 → 全 100 PASS で完了。1 件も regression を出さなかった。

#### K-4: handoff の毎回必須運用
`docs/working/TASK-00{59〜68}/handoff.md` で 9 PBI すべて 6 要素を記録。レビュー時の根拠と V2 候補が常に見える状態を保てた。

### Problem（課題）

#### P-1: markdown lint MD060（table compact style）が複数 PR で発生
- PR #210 / PR #216 で「全角括弧 `）` 直後に pipe `|`」が markdownlint MD060 違反になり、CI 失敗 → 修正 push
- 原因: 半角 `)` 後はスペース不要だが、全角 `）` 後はスペース必須という方言
- **影響**: 2 回の追加 push、その都度 thread resolve / merge 再試行が発生

#### P-2: my-blog 別リポジトリの記事数値ズレ
- v8.6.0 改善 7 PR で CLI tests 32 → 52、Hook 42 → 48 に進化したが、Zenn 記事は 32 PASS / 42 PASS のまま
- 別 repo 作業のため本セッションでは未対応 → Issue #191 にコメントで明示

#### P-3: collector mode regex が template フォーマットの差異に弱かった
- `**モード**: light` 形式しか拾えず、`## Mode 判定` / `## Mode\nlight` 形式（最近の TASK で多数）から mode が抽出できなかった
- PR #220 で 3 形式対応 + fallback regex に強化、TASK-0059/0061 で正しく抽出可能に

#### P-4: gh auth の自動切替で kominem-unilabo になる場面
- `git push` 後に `gh pr create` / `gh pr merge` で 2 回 `must be a collaborator` / `does not have permissions` エラー
- 都度 `gh auth switch -u s977043` で復旧、影響は軽微だが手数が増える
- memory には三点セット必須と記録済み（auth switch + git config + remote SSH）

### Try（次に試す）

#### T-1: v8.7.0 #196 Eval expansion 着手
本セッションで privacy 4 層 + metrics 自動化 + baseline schema + by_mode 集計が揃ったため、`bin/plangate eval` の比較 (baseline ↔ target、mode 別 release blocker 判定、metrics 連携) を実装する素地が整った。次回着手の最有力候補。

#### T-2: markdown lint を local pre-commit で走らせる
`markdownlint-cli` を `pre-commit` hook に組み込み、CI 失敗を local で先に拾う。MD060 の方言を毎回 push してから気付くのを防ぐ。

#### T-3: handoff §7 を自動 inject する CLI を実装
PR #221 で `metrics --markdown-section` を作ったので、次は `bin/plangate metrics --inject-handoff <TASK>` で handoff.md §7 を直接書き込み（手作業の貼り付けを排除）。

#### T-4: baseline drift 検知 CI（cron weekly）
PR #218 / #219 で baseline schema + snapshot script + validate-schemas 統合まで完了。次は GitHub Actions cron で週次 baseline-snapshot.py を走らせ、aggregate の差分が閾値を超えたら Issue を自動起票する。

#### T-5: my-blog 記事の数値同期
v8.6.0 改善 7 PR の状況を Zenn 記事に反映する update PR を別 repo で作成。タイトルもアップデート候補（「v8.6.0 のその後」「Hook EH-8 / privacy 4 層」など）。

#### T-6: `gh auth pin` の自動化
session start hook で `gh auth switch -u s977043` を強制する仕組みは既に `scripts/gh-pin-account.sh` で導入済（settings.example.json）。今回これを有効化していなかったので、無効化された設定を確認して常時 pinning を担保する。

## 3. 数値サマリ

### マージ済 PR と関連 Issue

| PR | タイトル | Closes |
|----|---------|--------|
| #208 | feat(eval): v8.5.0 baseline を固定 | #194 |
| #209 | feat(metrics): Metrics v1 を実装 | #195 |
| #210 | chore(release): v8.6.0 — Harness Improvement Roadmap Phase 0/1 + Governance 完走 | - |
| #214 | docs: add lightweight plan quality checks to roadmap | - |
| #215 | feat(privacy): metrics privacy 強制 + governance 完結 | - |
| #216 | docs(metrics): v8.6.0 利用者向けドキュメント強化 | - |
| #217 | feat(metrics): metrics 自動化進化 — hook_violation + pr_created 自動取得 | - |
| #218 | feat(eval): baseline 正式化 — schema + 自動再生成 script + tests | - |
| #219 | feat(integrity): v8.6.0 整合性検査強化 — doctor + metrics --validate + CI | - |
| #220 | feat(observability): v8.6.0 workflow 統合 + observability | - |
| #221 | feat(machine-readable): v8.6.0 機械可読化 + 自動化 | - |

### 機能拡張サマリ

| 領域 | リリース時 (v8.6.0) | セッション終了時 |
|------|-------------------|----------------|
| Hook 数 | 10 | 11（EH-8 追加） |
| Privacy 強制層 | 1 | **4** |
| Metrics 自動 emit events | 6 種 | 8 種（hook_violation + pr_created） |
| schema 化された artifacts | event のみ | event + baseline |
| `bin/plangate metrics` フラグ | 4 個 | **7 個**（+`--validate` / `--markdown-section` / `--since`） |
| `bin/plangate doctor` JSON 出力 | 不可 | **可能**（v8.6.0 16 check） |
| `validate-schemas` 対応 | task artifact のみ | + baseline.json |
| Reporter 集計粒度 | 全体 | + mode 別 + V-1 PASS rate % |
| Template 統合 | なし | handoff §7 / current-state Metrics 節 |
| AI agent 入口 | 未統合 | CLAUDE.md v8.6.0 セクション |
| CI workflow | 既存 4 件 | + `metrics-privacy.yml` |
| Test 合計 | 74 | **100 PASS** |

### 累積 TASK ディレクトリ

新規作成: TASK-0059 (#201) / 0060 (#202) / 0061 (#194) / 0062 (#195) / 0063 (PR1) / 0064 (PR3) / 0065 (PR4) / 0066 (PR5) / 0067 (PR6) / 0068 (PR7) — **計 10 PBI、全件 handoff.md を 6 要素で完走**。

## 4. 学び（permanent knowledge）

### L-1: Privacy policy を schema 設計の前に固定するべき
PR #202 (Privacy policy) を PR #195 (Metrics v1) の前にマージしたことで、event schema が `additionalProperties: false` + Forbidden field を最初から物理排除する設計になった。**policy → schema → 実装** の順は再現すべきパターン。

### L-2: 多層強制は 4 層あれば現実的に十分
- 1 層 (gitignore のみ) では事故の余地が残る
- 2 層 (gitignore + hook) でも CI で誰か bypass する余地
- 3 層 (gitignore + hook + schema) で物理的に大半が阻止
- 4 層 (gitignore + hook + schema + CI workflow) で残った最後の人為ミスも検出
- 5 層目はコストに見合わない（暗号化 / 完全 DLP は明示 Non-goal）

### L-3: 機械可読出力は CI gate に直結できる
`bin/plangate doctor --json` / `metrics --validate` / `metrics --markdown-section` のように、JSON 出力 / exit code を仕様化することで、後の CI 統合が劇的に楽になる。実装初期から考慮すべき。

### L-4: handoff の必須運用は議論を減らす
全 PBI で handoff §1（受入基準照合）を必ず書く運用にしたことで、レビュー時の「これ確認した？」が消滅。Rule 5（最終成果物は handoff に集約）の効果を実体験で確認。

## 5. 残課題（次セッション候補）

### v8.6.0 範囲（追加深掘り、優先順）
1. **T-3 handoff inject CLI**（小、高 ROI）
2. **T-4 baseline drift 検知 CI**（中、長期で効く）
3. **T-2 markdown lint pre-commit**（小、開発体験向上）
4. **T-5 my-blog 記事数値同期**（別 repo 作業）

### v8.7.0 milestone（推奨着手順）
1. **#196 Eval expansion**（中核、本セッションの全成果が活きる）
2. **#203 Tool Error Taxonomy**（Metrics v1 連動）
3. **#197 Model Profile v2**（独立着手可）
4. **#213 Lightweight Plan Quality Checks**（PR #214 で roadmap 統合済み、実装は #213 で）
5. **#204 PlanGateBench Fixtures**（#196 完了後）

### Issue #191 認知獲得（起票者判断）
- Phase 4 SNS 告知文作成・投稿
- Phase 5/6 Qiita / note 公開
- Phase 7 効果測定（GitHub Stars / Traffic）

## 6. クロージング

v8.6.0 milestone P0 4 件を完走 → リリース → 改善 7 PR + roadmap 統合 1 PR で v8.6.0 範囲を **設計 / 実装 / 強制 / 観測 / 自動化 / 機械可読化** の 6 軸で実用レベルに完成。Test 100 PASS / Open PR 0 件 / main クリーン状態でセッション終了。

次セッションは **v8.7.0 #196 Eval expansion** から開始するのが、本セッション成果（baseline schema + metrics 自動化 + by_mode 集計）を最も活用できる。
