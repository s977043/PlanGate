# PBI INPUT PACKAGE — TASK-0956

> Issue: [#956](https://github.com/s977043/plangate/issues/956)（bug / **priority:P2** / area:workflow）
> 由来: #943 の修正作業（PR [#955](https://github.com/s977043/plangate/pull/955)）中に、ワーカーが codex 同期スクリプトの素実行で検出しスコープ外として除外した drift の後始末 + 構造対応（CI 検出機構の新設）
> 作成: 2026-08-02（**main `cda229b` で実測**）
> 関連: [#954](https://github.com/s977043/plangate/issues/954)（26 skill の参照解決不能。同じ「正本 `.agents/skills/` → 派生」同期構造に依存。**#954 の exec は同期スクリプトを再実行するため、本 PBI の drift 2 件を先に解消しないと巻き込みが発生する — Notes 参照**）

## Context / Why

`.codex/skills/` は `.agents/skills/`（正本）からの同期生成物だが、**CI に drift 検出が無い**ため commit 済みの乖離が 2 件残っている。

構造原因: `.github/workflows/sync-plugin-plangate.yml` の drift-check は **`plugin/plangate/` 側しか検証しない**。`.codex/skills/` は誰も検査しないため、正本更新漏れも派生への直接編集も無言で残り続ける（issue #956）。

### 裏取り結果（作成時点 main = `cda229b`・2026-08-02）

| # | issue の主張 | 実測（コマンド / 参照） | 結果 | 判定 |
|---|------|------|------|------|
| 1 | 同期スクリプト素実行で drift 2 件（`ai-loop-cycle` / `plan-review-gate`） | `sh scripts/install-plangate-skills-to-codex.sh`（worktree 内・素実行） | **exit 0**・`installed_count=2 / skipped_count=36 / total_processed=38`、installed = `ai-loop-cycle`, `plan-review-gate`。直後の `git status --short` = `M .codex/skills/ai-loop-cycle/SKILL.md` / `M .codex/skills/plan-review-gate/SKILL.md` の**ちょうど 2 件** | 一致 |
| 2 | `ai-loop-cycle` は `description` と適用制限節の乖離 | `git diff --stat -- .codex/` | `ai-loop-cycle/SKILL.md` = **15 行変化**（追加・削除の混在） | 一致 |
| 3 | `plan-review-gate` は `.codex/` 側にだけ 36 行の節 | 同上 + diff 本文 | `plan-review-gate/SKILL.md` = **36 deletions / 0 insertions**。同期すると「### C-1 追加品質ゲート: Plan 実行可能性」（Superpowers `writing-plans` 由来と自己記述する節）がまるごと消える = `.codex/` 側固有の追記 | 一致 |
| 4 | CI は `.codex/skills/` を検査しない | `.github/workflows/sync-plugin-plangate.yml` | drift 判定は `git diff --quiet -- plugin/plangate/`（L52 / L81）のみ。codex に触れるのは L73 `check-codex-skill-spec.sh --warn-only` で、これは spec 検査（warn-only）であり drift 検出ではない | 一致 |
| 5 | HO patch 提示の前例（TASK-0871 / TASK-0872） | `ls docs/working/TASK-0871/approvals/` / `ls docs/working/TASK-0872/patches/` | `ho-apply-approval.md`（0871）、`*.patch` + `*.new` + `ho-apply-approval.md`（0872）が実在 | 一致 |

実測後は `git restore .codex/` で working tree を clean に復元済み（`git status --short` = 0 行。本 pbi-input のコミットに drift 差分は含めない）。

## 前提（責務分界 — issue の記述を保持）

`.github/workflows/**` は **Hardening Override 対象**（mode-classification 9 カテゴリ / `scripts/hooks/check-plan-hash.sh` L124-134 で常時 block）のため、CI job の追加は AI が直接適用できない。**設計・patch 提示までを AI-owned とし、適用は Human-owned** とする（前例: TASK-0871 の `approvals/ho-apply-approval.md` / TASK-0872 の `patches/`）。

## What（Scope）

### In scope

1. **検出済み drift 2 件の判定と解消**:

   | skill | 乖離の内容 | 判定が必要な論点 |
   |---|---|---|
   | `ai-loop-cycle` | `description` と適用制限節が正本と異なる | 正本更新が派生に反映されていない（更新漏れ）か、派生を意図的に分岐させたか |
   | `plan-review-gate` | `.codex/` 側にだけ 36 行の節「C-1 追加品質ゲート: Plan 実行可能性」が存在 | 正本へ取り込むべき内容が派生にだけ入った（直接編集）可能性が高い。取り込み要否の判断が要る |

2. **構造対応**: `.codex/skills/` の drift を CI で検出する検査を設計し、`.github/workflows/` への patch を Human 適用可能な形で提示する
3. **検出力の実証**: 意図的に drift を注入した状態で検査が FAIL することを実証する（空振り検査でないこと）

### Out of scope（issue verbatim）

- `ai-dev-plan`（#943 / PR #955 で対応済み。本 issue の作業時に混ぜないこと）
- `plugin/plangate/` 側の drift-check（既に `sync-plugin-plangate.yml` が担当）

### Non-goals（issue verbatim）

- `.codex/skills/` を生成物でなく正本に格上げすること（生成関係は維持する）
- 同期スクリプト自体の再設計
- drift 検出を merge blocker（required check）に昇格させること（issue 記載では現状 required は `Markdown lint` 1 本のみ。昇格は別途判断）

## 受入基準

> issue #956 の AC 6 項目を保持し、検証方法を付与。plan で最終確定する。

- **AC-1**: `ai-loop-cycle` の drift について、正本更新漏れか意図的分岐かが判定され、根拠（git log 突合等の一次証跡）が decision-log / plan に記録されている
- **AC-2**: `plan-review-gate` の `.codex/` 側 36 行について、正本へ取り込むか削除するかが判定され、根拠が記録されている（内容判断を含むため C-3 で人間確認）
- **AC-3**: 上記 2 件の drift が解消し、`sh scripts/install-plangate-skills-to-codex.sh` を素で実行しても `git status` が clean である（本 pbi-input の裏取り #1 と同一手順で再検証）
- **AC-4**: `.codex/skills/` の drift を検出する CI 検査が設計され、`.github/workflows/` への patch が **Human 適用可能な形**（TASK-0871/0872 前例に倣う `patches/` + 適用手順）で提示されている（AI は適用しない）
- **AC-5**: 検査が実際に drift を検出できることが、意図的に drift を注入した状態で実証されている（負側テスト。空振り検査でないこと）
- **AC-6**: `sh tests/run-tests.sh` が baseline（issue 記載 **453 passed / 0 failed**。exec 開始時に現 main で再実測した値を正とする）を維持している

## Notes from Refinement

### Mode 判定案（plan で確定）

- **承認境界周辺 → 最低でも high-risk**: 本 PBI は HO 対象パス `.github/workflows/**` への patch **提示**を含む。適用は Human-owned で AI は HO パスに touch しないが、mode-classification の例外ルール「承認境界周辺の変更 → 最低でも高」と「該当不確実な場合は該当扱い（安全側）」に従い、**最低 high-risk** とする
- 定量: AI が直接編集するのは `.codex/skills/` 2 ファイル + 検査スクリプト/テスト + 提示物（`docs/working/TASK-0956/patches/` 等）で 3-5 帯。受入基準 6 → **high 帯（6-10）**。判定ロジック（各軸最大値）でも high
- `plan-review-gate` の 36 行を「正本へ取り込む」判定になった場合、正本 `.agents/skills/plan-review-gate/SKILL.md` の変更 + 派生再同期（`.codex/` / `plugin/`）が加わる（それでも high 帯の範囲）
- 最終判定案: **high-risk**。`lite_eligible=false`・**同期 C-3（人間）必須**（HO 対象パスを含む PBI は autonomous APPROVE 不可）

### drift 判定の材料（実測から）

- `plan-review-gate` の 36 行節は「Superpowers の `writing-plans` から取り込む観点」と自己記述する**内容追加**であり、正本に存在しない。派生への直接編集（正本取り込みの判断が要る）という issue の見立てと整合
- `ai-loop-cycle` は description / 適用制限節の差。正本 `.agents/skills/ai-loop-cycle/SKILL.md` と `.codex/` 側それぞれの git log（最終変更コミット）を突合し、どちらが先行しているかで「更新漏れ / 意図的分岐」を判定する（exec T-01）
- 検査設計の注意: 同期スクリプトは「source に `references/` が無い skill の dest `references/` を触らない」管理外規則を持つ（`install-plangate-skills-to-codex.sh` L99-101、gemini HIGH #805 対応）。drift 検査はこの仕様を誤検出しないよう設計する

### #954 との順序調整（重要）

issue #954 の AC-4 は同期スクリプトによる派生再生成を要求するため、本 PBI の drift 2 件が未解消のまま #954 が exec すると無関係 drift が #954 の PR へ混入する（PR #955 で実際に発生し、ワーカーが除外した前例 = 本 issue の検出契機）。**本 PBI の drift 解消（AC-1〜3）を #954 の exec より先に完了させる**ことを推奨。逆順にする場合は #954 側の stage 除外運用が前提。

## Estimation Evidence

### Risks

| Risk | 影響 | 一次緩和 |
|------|------|---------|
| CI patch を AI が誤って直接適用（HO 違反） | 承認境界侵害・EH-3 常時 block に接触 | patch は `docs/working/TASK-0956/patches/` への提示のみ。前例（TASK-0871/0872）の `ho-apply-approval.md` 形式を踏襲し、適用手順を Human 向けに明記 |
| drift 判定を誤り、必要な内容（36 行節）を消失させる | plan 実行可能性ゲート観点の喪失 | AC-2 を「取り込み vs 削除」の二択 + 根拠記録 + C-3 人間確認とする。削除する場合も節の全文を decision-log / evidence に保全 |
| 検査が空振り（drift を検出できない） | 再発を検出できず構造対応が名目化 | AC-5 の変異注入（意図的 drift）で FAIL を実証（負側テスト） |
| 検査の誤検出（`references/` 管理外仕様・`openai.yaml` 生成差・assets） | CI が常時 FAIL し required でなくてもノイズ化 | 同期スクリプトの管理外規則（L99-101）と生成物範囲を検査設計に反映。比較対象を SKILL.md ベースにする等の絞りを plan で確定（U-4） |
| 正本取り込み判定時の派生再同期が #954 と衝突 | 同一ファイル群の conflict | 順序調整（上記 Notes）。取り込み時の再同期範囲を最小（該当 skill のみ）に留める |

### Unknowns

- **U-1**: `ai-loop-cycle` drift の原因（更新漏れ vs 意図的分岐）— exec T-01 の git log 突合で確定
- **U-2**: `plan-review-gate` 36 行の取り込み要否 — 内容判断（C-3 で人間確認）
- **U-3**: CI 検査の実装形態 — 既存 `sync-plugin-plangate.yml` への job 追加か、新規 workflow か。いずれも HO パスのため Human 適用。検査スクリプト本体（`scripts/check-*.sh` 等、HO 対象外）と workflow patch（HO 対象）の分割設計
- **U-4**: 検査の比較方式 — 同期スクリプト素実行 + `git status` 検査（本 pbi-input の裏取りと同じ・実装最小）か、ハッシュ比較の専用スクリプト新設か。誤検出リスク（Risks 4 行目）とのトレードオフ

### Assumptions

- 同期スクリプト `install-plangate-skills-to-codex.sh` の仕様（差分時のみ更新 / `references/` 管理外規則 / `openai.yaml` 生成）が現状のまま維持されること（Non-goals: 再設計しない）
- `sh tests/run-tests.sh` baseline = 453 passed / 0 failed（issue 記載。exec 開始時に再実測して正とする）
- #954 との順序調整（本 PBI 先行 or #954 側 stage 除外）が可能であること
- TASK-0871/0872 の HO patch 提示形式（`patches/` + `ho-apply-approval.md`）が引き続き有効な前例であること
