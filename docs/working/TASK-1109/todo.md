# EXECUTION TODO — TASK-1109 (#1109)

> mode=**high-risk**。L-0 / V-1〜V-4 / PR 作成は workflow-conductor が制御するため本表に含めない。
> **AI は `.github/workflows/*` を編集しない**（HO。patch 提示まで）。
> **AI は `sh tests/run-tests.sh`（フルスイート）を実行しない**（並走ワーカー保護）。

## 🤖 Agent タスク

### 準備

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|-----|
| T-01 | 呼び出し元の全数確認 | agent | — | 不要（読取のみ） | `grep -rn "check-codex-skill-spec"` の非 docs ヒットが workflow / `ta-30` の 2 経路のみ |
| T-02 | `install-plangate-skills.sh` の `agents/` 扱いを実読 + 実走で確認 | agent | — | 不要（読取のみ） | 一時 target への展開物が spec check **PASS**（欠落 4 件が再生成される）ことを実測 |
| T-03 | 配布物 / `.codex` 両 root の `SKILL.md` 集合と `openai.yaml` 集合の差を実測 | agent | — | 不要（読取のみ） | 差分が名前で列挙できる（件数だけで語らない） |

### 実装

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|-----|
| T-04 | `.codex/skills` の 8 violations を `install-plangate-skills-to-codex.sh --force` で解消 | agent | T-03 | `git checkout -- .codex/skills` | `--target .codex/skills` が rc=0。**openai.yaml 以外の差分（SKILL.md stale 4 件）は revert** |
| T-05 | 配布物の欠落 4 件 `agents/openai.yaml` を新規作成 | agent | T-03 | `git rm` した 4 ファイル | 既存の手書き英語 description スタイルを踏襲。`short_description` が 25–64 文字 |
| T-06 | 配布物 `diff-audit` の 66 文字 `short_description` を短縮 | agent | T-03 | `git checkout -- <path>` | 64 文字以下 |
| T-07 | presence 同値照合 + ignored の理由出力を実装 | agent | T-01 | `git checkout -- scripts/check-codex-skill-spec.sh` | 判定に絶対件数を使っていない（集合演算のみ）ことを diff で確認 |
| T-08 | 既定 target を 2 root 化（`--target` は既定を置換・複数可） | agent | T-07 | 同上 | `ta-30` の `--target <tmp>` 呼び出しが壊れない |
| T-09 | target 不在の扱い（明示=violation / 既定=理由付き skip / 全滅=violation） | agent | T-07 | 同上 | traceback を出さない。`--warn-only` で rc=0 |
| T-10 | rc 方針を shell 1 箇所へ集約（python は violation→exit 1 のみ） | agent | T-09 | 同上 | `grep -c "warn_only" ` で python 側に rc 分岐が残っていない |

### 検証

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|-----|
| T-11 | `tests/extras/ta-68-skill-spec-presence.sh` を新設（extras 実行契約に初日から準拠） | agent | T-10 | `git rm tests/extras/ta-68-*.sh` | standalone 実行で 12 TC 全 PASS / rc=0 |
| T-12 | 変異 M-1（presence の silent skip 復元）を **call site** に注入 → 復元 | agent | T-11 | 変異は必ず復元（バックアップと `diff` で同一性確認） | TC-03 が FAIL → 復元後 12 PASS |
| T-13 | 変異 M-2（`--warn-only` rc=0 保証の削除）を注入 → 復元 | agent | T-11 | 同上 | TC-05 / TC-06 が FAIL → 復元後 12 PASS |
| T-14 | 変異 M-3（target 不在ガードの無効化）を注入 → 復元 | agent | T-11 | 同上 | TC-07 が FAIL → 復元後 12 PASS |
| T-15 | 既存呼び出し元の回帰（`ta-30` / `sync-plugin-plangate.sh --dry-run` / `check-skill-frontmatter.py`） | agent | T-10 | 不要（読取のみ） | `ta-30` 9 TC 全 PASS / dry-run が `no changes` |

### 完了

| ID | タスク | Owner | depends_on | rollback | 🚩 |
|----|-------|-------|-----------|----------|-----|
| T-16 | workflow patch 作成 + **隔離コピーへの実適用テスト** | agent | T-15 | `git rm` patch | `git apply` が成功し、適用後ファイルに `--warn-only` が無い |
| T-17 | Plan Package + C-1 + evidence を確定 | agent | T-16 | — | 6 ファイル + evidence がそろう |
| T-18 | ブランチ `fix/1109-skill-spec-presence-check` に commit + push | agent | T-17 | `git reset --hard origin/main` | push 前に current branch を verify |

## 👤 Human タスク

| ID | タスク | Owner | 依存 |
|----|-------|-------|------|
| H-1 | **C-3 ゲート**（mode=high-risk / HO 隣接につき **autonomous APPROVE 不可・同期必須**） | human | T-17 完了後 |
| H-2 | **C-4 ゲート**（PR レビュー / merge） | human | PR 作成後 |
| H-3 | **HO 適用**: merge 後の main で rc=0 を確認してから `patches/0001-*.patch` を適用し、`--warn-only` を外す別 PR を出す | human | H-2 完了後 |
| H-4 | **Q-1 判断**: 配布物 openai.yaml の生成を sync 経路へ組み込むか（follow-up issue 化） | human | 任意 |

## ⚠️ 依存関係

- T-04〜T-06（既存 violation 解消）は T-07〜T-10（検出器強化）より**前**でなくてよいが、
  **H-3（`--warn-only` 除去）は T-04〜T-06 の merge より後**でなければならない（順序制約）
- **`c3.json` は本ワーカーが発行しない**（H-1 が Human-owned）
