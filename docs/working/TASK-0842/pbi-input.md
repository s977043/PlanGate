---
task_id: TASK-0842
artifact_type: pbi-input
schema_version: 1
status: draft
related_issue:
  - https://github.com/s977043/plangate/issues/842
  - https://github.com/s977043/plangate/issues/843
created_by: orchestrator
---

# PBI INPUT PACKAGE — TASK-0842

> #842 governance: HO リストの二重管理を整合する（EH-3 9 カテゴリ vs ai-loop
> ho-paths の `plugin/**` 乖離）。#843（#840 arbiter 変更の plugin bundled 同期）は
> 本 issue の governance 判断に従属する後続タスク。

## Context / Why

Hardening Override (HO) 対象パスのリストが 2 箇所に独立して存在し、範囲が
食い違っている（実測: `.claude/rules/mode-classification.md` 「承認境界周辺の
変更」節 = EH-3 9 カテゴリ正本、実装 `scripts/hooks/check-plan-hash.sh`
L124-134 の `case` 文と一致確認済み。9 カテゴリに `plugin/**` は**含まれない**）。

一方 `docs/ai/ai-loop/ho-paths.md` の HO パス一覧には `plugin/plangate/**`
（分類 `HO-plugin`）が独立に列挙されている。

実害（2026-07-12 セッションで顕在化・#842 issue 本文より引用）:

- PR #830 / #831 は `plugin/plangate/**` 配下の bundled resources を EH-3 に
  掛からず直接編集してマージできた（EH-3 は `plugin/**` を対象外にしているため）
- run-024 の ai-loop cycle では `plugin/plangate/**` への変更が ho-paths.md 上の
  HO-plugin に該当し、arbiter が escalate。PR #840 の worker は plugin 同期
  （`scripts/sync-plugin-plangate.sh`）を見送った
- 結果、同一パス `plugin/plangate/**` に対し「EH-3 経由なら素通り」「ai-loop
  経由なら escalate」という運用上の非対称が発生。#840 の arbiter.py /
  test_arbiter.py / metrics.py / test_metrics.py が plugin bundled 側に
  未同期のまま残存（#843 で追跡）

一方、既存の CI（`.github/workflows/sync-plugin-plangate.yml`、実測確認済み）は
`.claude/**` / `.agents/skills/**` / `CHANGELOG.md` への main push をトリガに
`scripts/sync-plugin-plangate.sh` を実行し、`plugin/plangate/` との差分が
あれば自動で同期 PR を作成する（merge は Human-owned C-4、workflow 内コメント
「merge は Human-owned (C-4)」で明記）。すなわち `.claude/**` 等の**正本側**は
既に EH-3 の 9 カテゴリで保護されており、`plugin/plangate/**` はその**派生
成果物**として CI drift ゲートで別途担保される構造が既に稼働している。

## What — Scope

### In scope

1. `docs/ai/ai-loop/ho-paths.md` から `plugin/plangate/**`（HO-plugin 行、
   分類定義表の `HO-plugin` 行、判定アルゴリズムのパターン例
   `plugin/plangate/index.js → HO-plugin` を含む）を削除する差分をテキストで
   提案する（**AI は ho-paths.md を直接編集しない** — 同ファイルは
   ho-paths.md 自身が HO-contract として自己登録しており AI 直接編集不可。
   本 PBI では Human が適用するパッチ相当の差分を plan.md / handoff.md に
   明示するところまでを AI-owned とする）
2. `docs/ai/ai-loop/concept.md` §3 等、`plugin/**` の HO 扱いに言及する記述が
   他にないか横断確認し、あれば同様に差分候補を提示する
3. EH-3（`.claude/rules/mode-classification.md` 9 カテゴリ /
   `scripts/hooks/check-plan-hash.sh` 実装）は**変更しない**ことを明記する
   （A案不採用の帰結。9 カテゴリへの `plugin/**` 追加は行わない）
4. #843（PR #840 由来の arbiter.py / test_arbiter.py / metrics.py /
   test_metrics.py の plugin bundled 同期）を、B案確定後の実施可能タスクとして
   本 PBI の最終段に位置づける — `sh scripts/sync-plugin-plangate.sh
   --dry-run` で対象差分を確認し、`sh scripts/sync-plugin-plangate.sh`
   （dry-run なし）を実行して同期 PR を作成する（AI-owned・PR 作成まで。
   merge は Human-owned C-4 で #843 と同様）
5. 決定の記録: `.claude/rules/responsibility-classes.md` の
   「対外公開アーティファクト publish 責務分界」に類する形で、`plugin/**`
   の担保が CI-owned（sync-plugin-plangate.yml drift 検出）に一本化された旨を
   どこに記録するか（`docs/ai/ai-loop/ho-paths.md` 内の
   `関連ドキュメント`/`Arbiter 固有の追加原則` 節、または
   `docs/ai/ai-loop/asset-inventory.md`）を plan.md で決定する

### Out of scope

- EH-3 9 カテゴリへの `plugin/**` 追加（A案。不採用候補として記録するのみ）
- `ho-paths.md` と EH-3 の統一リスト化・対応表の新規正本作成（issue #842
  論点3。B案採用によりこの分岐は不要と判断するが、pbi-input では選択肢として
  記録し、plan.md で最終確定する）
- `plugin/**` 配下ファイルの内容自体の変更（同期以外の編集）
- ai-loop Phase 2（arbiter 本実装）への機能追加

## 二択構造（Human C-3 で最終確定）

| 案 | 内容 | 採用可否（本 PBI 起草時点の推奨） |
|----|------|------------------------------|
| **B案（推奨）** | `ho-paths.md` から HO-plugin（`plugin/plangate/**`）を削除。plugin 同期の担保は既存 CI（`sync-plugin-plangate.yml` の drift 検出 → 同期 PR → Human C-4 merge）に一本化 | 推奨 |
| A案（不採用候補） | EH-3 9 カテゴリに `plugin/**` を追加し、EH-3 側でも直接編集を block する | 不採用推奨（根拠は下記） |

**A案不採用の根拠（実測ベース）**:

1. `plugin/` は `.claude/**` 等の派生成果物であり、正本は `.claude/**` 側。
   正本側は既に EH-3 の 9 カテゴリ（`.claude/rules/*.md` /
   `.claude/commands/*.md` / `.claude/agents/*.md` 等）で保護済み
   （`scripts/hooks/check-plan-hash.sh` L125-133 で実測確認）
2. A案は AI による正規の sync スクリプト実行（`scripts/sync-plugin-plangate.sh`
   経由の `plugin/plangate/` への書き込み）も EH-3 で block してしまい、
   #843 のような同期作業が恒久的に Human 手動作業化する
   （sync スクリプト自体は `.claude/**` 変更の反映のみを行う安全な
   自動化であり、EH-3 が意図する「AI が任意ロジックを直接改変する」ケースとは
   性質が異なる）
3. CI-owned の drift ゲート（`sync-plugin-plangate.yml`）が既に物理稼働して
   おり、`plugin/plangate/` への差分は必ず PR 経由・Human C-4 merge を通る
   構造になっている（実測: workflow 内 `git diff --quiet -- plugin/plangate/`
   による差分検出 → `gh pr create` の実装を確認）。EH-3 側の追加保護は
   二重ゲート化にとどまり限界便益が小さい一方、コスト（2 の恒久 Human 化）が
   大きい

## 受入基準

- [ ] AC-1: `docs/ai/ai-loop/ho-paths.md` の `plugin/plangate/**`（HO-plugin）
      関連 3 箇所（HO パス一覧の表の行 / 分類定義表の `HO-plugin` 行 / 判定
      アルゴリズムのパターン例）を削除する差分がテキスト（unified diff 相当）で
      plan.md または handoff.md に明示されている。AI 自身は `ho-paths.md`
      を編集しない（Write/Edit しない）
- [ ] AC-2: `docs/ai/ai-loop/concept.md` §3 その他 `docs/ai/ai-loop/` 配下で
      `plugin/**` を HO 扱いとする記述の有無を横断確認した結果（grep 実行
      ログ含む）が記録され、該当があれば同様の差分候補が提示されている
- [ ] AC-3: `.claude/rules/mode-classification.md`（EH-3 9 カテゴリ正本）と
      `scripts/hooks/check-plan-hash.sh`（EH-3 実装）に**変更が加えられて
      いない**ことが diff（変更なし）で確認できる
- [ ] AC-4: `plugin/plangate/**` の担保が CI-owned
      （`.github/workflows/sync-plugin-plangate.yml` の drift 検出 → 同期 PR →
      Human C-4 merge）に一本化されている旨が `docs/ai/ai-loop/ho-paths.md`
      の関連セクション（Human 適用後）または `docs/ai/ai-loop/asset-inventory.md`
      に記録される計画になっている
- [ ] AC-5: #843（PR #840 由来 arbiter.py / test_arbiter.py / metrics.py /
      test_metrics.py の plugin bundled 同期）について、
      `sh scripts/sync-plugin-plangate.sh --dry-run` で対象差分ゼロ化を確認する
      手順、および本番同期（dry-run なし）→ 同期 PR 作成 → Human C-4 merge
      までの完了条件が plan.md / todo.md に明記されている
- [ ] AC-6: 本 PBI の最終確定（B案採用の可否）が **C-3（同期・Human 承認）**
      を経ることが todo.md の Human タスクとして明示されている（AI による
      autonomous APPROVE 対象外）
- [ ] AC-7: 受入基準と #842 / #843 の論点との対応関係が明示されている
      （トレーサビリティ表 — 下記参照）

### トレーサビリティ（AC ↔ issue 論点）

| AC | 対応する issue 論点 |
|----|-------------------|
| AC-1, AC-2 | #842 論点2（ai-loop ho-paths から HO-plugin を外す） |
| AC-3 | #842 論点1 の不採用確認（EH-3 9 カテゴリへの `plugin/**` 追加をしない） |
| AC-4 | #842 論点3（ドメイン別リスト明文化・対応関係の記録） |
| AC-5 | #843（#840 由来ファイルの plugin bundled 同期・完了条件） |
| AC-6 | #842 issue 本文「判断主体: 本 issue の方針決定は Human-owned」 |

## Notes from Refinement

- **2026-07-12 決定（オーガナイザー）**: 推奨は B 案（`ho-paths.md` から
  HO-plugin を削除し、plugin 同期の担保を既存 CI drift ゲートに一本化）。
  A 案（EH-3 に `plugin/**` を追加）は比較対象として記録するが不採用候補。
  **最終確定は C-3（同期・Human 承認）を経る**。AI は差分提案（テキスト）
  までを担当し、`ho-paths.md` への適用は Human のワンアクションとする
  （`.claude/rules/responsibility-classes.md` 責務 4 分類 — AI-owned は
  「設計・検証・パッチ生成」まで、Human-owned は「self-mod guard 対象
  ファイルへの適用」）
- ho-paths.md 自体が HO-contract（`docs/ai/ai-loop/ho-paths.md` の
  「Arbiter 固有の追加原則」節に「本ファイル自身を HO パス一覧に
  HO-contract として登録済み」と明記されている）ため、AI による直接編集は
  構造的に block される（実測: `docs/ai/ai-loop/ho-paths.md` 本文で自己参照
  確認済み）
- **Known Fact**: `docs/ai/ai-loop/concept.md` に `plugin` への言及なし
  （grep 実測 0 件・2026-07-12）。In scope 2 / AC-2 の横断確認は concept.md
  以外の `docs/ai/ai-loop/` 配下ファイルの網羅確認として実施する
- #843（arbiter/metrics 等の plugin bundled 未同期）は本 PBI の governance
  判断に従属する後続実施タスク。同期自体（`sync-plugin-plangate.sh` 実行）は
  スクリプト経由のためAI実施可能であり、B案確定後は本 PBI の後段
  （または本 PBI 完了後の独立 PR）で実施してよい。plan.md で実施順序
  （本 PBI 内 vs 別チケット）を最終決定する

## Estimation Evidence

**Risks**:
- `ho-paths.md` は HO-contract のため AI 直接編集不可。パッチ提案と実適用の
  タイムラグで一時的に「提案済みだが未適用」状態が生じうる → todo.md で
  Human 適用タスクを明示し、settings タスクロック的に完了未確定を追跡する
- 差分提案が `ho-paths.md` の他セクション（判定アルゴリズムのパターン例・
  分類定義表）に散在するため、削除漏れが起きるリスク → AC-1 で 3 箇所を
  明示列挙し grep で網羅確認する
- #843 の同期作業（dry-run 実測済み・2026-07-12 オーガナイザー独立再実行で
  一致確認: 差分対象は arbiter.py / test_arbiter.py / test_metrics.py に加え
  `rules/orchestrator-mode.md` / `rules/responsibility-classes.md` /
  `skills/ai-loop-cycle/references/decision-table.md`。metrics.py は差分なし）
  が本 PBI 実施までの間に他の main push（`.claude/**` 変更）で状態が変わる
  可能性 → 実施直前に再度 `--dry-run` で確認する。また #843 の同期 PR は
  sync スクリプトの性質上 **#840 由来（arbiter 系）以外の drift も同時に
  含まれる**点に留意する（PR レビュー時に差分の出自を区別して確認する）

**Unknowns**:
- B案採用後、`docs/ai/ai-loop/ho-paths.md` の変更差分適用と #843 の同期実施の
  実施順序（先に ho-paths.md 適用 → 同期、または並行）は plan.md で確定する

**Assumptions**:
- Mode = **high-risk**（`.claude/rules/mode-classification.md` の例外ルール
  「承認境界周辺の変更 → 最低でも高」に該当。`docs/ai/ai-loop/ho-paths.md` は
  HO 対象パスの 9 カテゴリそのものには含まれないが、承認境界（HO 判定基準）
  の定義変更という性質上、安全側で high-risk とする。`lite_eligible=false`・
  Standard・同期 C-3 固定）
- 本 PBI の C-3 は **Autonomous APPROVE 対象外**（mode-classification.md
  autonomous APPROVE 判定マトリクスで high-risk / critical は「❌ 不可
  （人間 C-3 必須）」に該当）
